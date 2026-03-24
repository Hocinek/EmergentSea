class_name Navires
extends Node2D

# Permettra de signaler au moteur différents évènements
signal sig_show_stats
signal sig_navire_died(navire: Navires)
signal sig_navire_damaged(navire: Navires, damage: int)
signal ship_clicked(ship: Navires)
signal ship_destroyed(ship: Navires)
signal sig_show_fishing
signal sig_inspect_case(case_pos: Vector2i)
signal sig_open_hex_menu(navire: Navires, screen_pos: Vector2)
signal sig_switch_ship()

# =========================
# MODE D'INPUT (menu contextuel)
# =========================
enum InputMode { NONE, MOVE, ATTACK, INSPECT }
var current_input_mode: InputMode = InputMode.NONE

# =========================
# PROPRIÉTAIRE ET IDENTITÉ
# =========================
## Référence directe au joueur propriétaire (remplace joueur_id)
@export var player_owner: Player = null

## ID unique du navire
@export var id: int = 0

## Détermine si c'est le navire contrôlé par le joueur humain actuel
var is_player_controlled: bool = false

## Indique si ce navire est actuellement sélectionné
var is_selected: bool = false

# AJOUT : Visibilité basée sur le fog of war
var is_visible_to_human: bool = true  # true par défaut pour les navires du joueur
var fog_of_war_ref: FogOfWar = null


# =========================
# STATS
# =========================
var stats_panel : UI_stats_navire
@export var vie: int = 10
@export var maxvie: int = 10
@export var energie: int = 3000
@export var maxenergie: int = 3000
@export var vitesse: float = 800.0
@export var nrbequipage: int = 0
@export var interaction_radius: float = 80.0
@export var stats_duration: float = 2.5
@export var tir: int = 10		# Portée d'un tir
@export var dgt_tir: int = 2	# Dégâts d'un tir

@onready var ui_layer: CanvasLayer = get_tree().get_first_node_in_group("ui_layer")
@onready var data := get_tree().get_first_node_in_group("shared_entities")
@onready var players_manager: PlayersManager = get_tree().get_first_node_in_group("players_manager")

# Référence au fog manager pour mise à jour en temps réel
var fog_manager: FogManager = null

var drawable : Drawable

# =========================
# PÊCHE
# =========================
@export var nourriture: int = 0
@export var fish_energy_cost: int = 1
@export var fish_duration: float = 1.2
@export var fish_yield_min: int = 1
@export var fish_yield_max: int = 3

var is_fishing := false
var fish_timer := 0.0


# =========================
# FEEDBACK PÊCHE
# =========================
var fish_feedback_label: UI_fish_navires
@export var fish_feedback_duration: float = 0.8
var fish_feedback_timer: float = 0.0


var stats_timer := 0.0
# stats_visible = true signifie que le joueur a VOLONTAIREMENT activé l'affichage
# Les stats restent visibles même si on change de sélection, jusqu'à désactivation manuelle
var stats_visible := false


# =========================
# DÉPLACEMENT
# =========================
var path := []
var is_moving := false
var case_actuelle: Vector2i
var target_position: Vector2 = Vector2.ZERO
var show_arrow: bool = false

# =========================
# ROTATION DU BATEAU
# =========================
## Angle cible vers lequel le bateau doit se tourner (en radians)
var target_rotation_angle: float = 0.0
## Vitesse de rotation en radians/seconde
@export var rotation_speed: float = 5.0
## Correction d'angle selon l'orientation par défaut de votre asset (en degrés).
@export var rotation_offset_deg: float = -90.0
## Inverser le sens de rotation si le bateau tourne à l'envers
@export var rotation_invert: bool = false

## Nœud visuel à tourner (Sprite2D) — résolu dans _ready
var _visual_node: Node2D = null

## Décalage du centre visuel réel du bateau par rapport au centre de la texture.
@export var pivot_offset_y: float = 0.0

## Centre visuel du bateau en coordonnées locales du Node2D racine (calculé au _ready).
var _pivot_local: Vector2 = Vector2.ZERO

## Référence au Node3D pirateShip — tourné via Transform3D axe Y uniquement
var _pirate_ship_3d: Node3D = null

# =========================
# DÉCALAGE VISUEL DU SPRITE
# =========================
## Décale le Sprite2D pour que le centre VISUEL du bateau coïncide avec
## global_position (= l'ancre logique utilisée pour déterminer la case occupée).
@export var hull_offset: Vector2 = Vector2.ZERO

# =========================
# CAMÉRA 2D
# =========================
@onready var camera: Camera2D = get_node_or_null("Camera2D")


#region initialisation
func _init() -> void:
	add_to_group("ships")


func _ready():
	await get_tree().process_frame

	case_actuelle = Map_utils.monde_vers_case(global_position)

	# Résoudre le nœud visuel (Sprite2D) et configurer la rotation 3D
	_setup_node3d_instance()

	# Configuration de la caméra pour le navire contrôlé par le joueur
	_setup_camera()

	# Configuration des inputs selon le type de contrôle
	_setup_input_handling()

	# Initialisation de l'UI
	_init_stats_ui()
	drawable = Drawable.new(self)
	add_child(drawable)

	# Récupérer le FogManager
	fog_manager = get_tree().get_first_node_in_group("fog_manager")
	if fog_manager:
		DEBUG.log("Navire [%d] - FogManager connecté" % id)

	# Récupérer le FogOfWar pour vérifier la visibilité
	fog_of_war_ref = get_tree().get_first_node_in_group("fog_of_war")
	if fog_of_war_ref:
		DEBUG.log("Navire [%d] - FogOfWar connecté pour visibilité" % id)

	# Debug
	var owner_name = player_owner.player_name if player_owner else "AUCUN"
	var control_type = "CONTRÔLÉ" if is_player_controlled else "IA/ENNEMI"
	DEBUG.log("Navire [%s] initialisé - Propriétaire: %s - Type: %s - Position: %s" % [
		id, owner_name, control_type, case_actuelle
	])


func _setup_node3d_instance() -> void:
	"""
	SOLUTION FINALE — doc Godot Transform3D + own_world_3d :

	1. own_world_3d = true sur le SubViewport → chaque navire a son propre
	   monde 3D isolé, les rotations ne se partagent plus entre instances.

	2. On récupère le pirateShip et on tourne uniquement son axe Y via
	   Transform3D.basis — les axes X et Z restent intacts → pas de surrélevement.

	3. Le Sprite2D n'est jamais tourné → pas de problème de pivot 2D.
	"""
	# Isoler le monde 3D de ce SubViewport pour éviter le partage entre instances
	var subviewport = get_node_or_null("Sprite2D/SubViewport")
	if subviewport:
		subviewport.own_world_3d = true
		DEBUG.log("Navire [%d] - SubViewport.own_world_3d = true" % id)

	# Récupérer le pirateShip — c'est lui qu'on tourne sur Y uniquement
	var pirate = get_node_or_null("Sprite2D/SubViewport/Node3D/pirateShip")
	if pirate and pirate is Node3D:
		_pirate_ship_3d = pirate
		target_rotation_angle = pirate.rotation.y
		DEBUG.log("Navire [%d] - pirateShip ciblé (Transform3D, axe Y)" % id)
	else:
		DEBUG.log("Navire [%d] - ERREUR : pirateShip introuvable" % id)

	# Le Sprite2D reste en place — on ne le tourne pas.
	# hull_offset décale le sprite pour que le centre VISUEL du bateau
	# coïncide avec global_position (ancre logique = case occupée).
	_visual_node = get_node_or_null("Sprite2D")
	if _visual_node:
		_visual_node.position = hull_offset
		DEBUG.log("Navire [%d] - hull_offset appliqué : %s" % [id, hull_offset])


func _resolve_visual_node() -> void:
	pass


func _get_visual_rotation() -> float:
	if _pirate_ship_3d:
		return _pirate_ship_3d.rotation.y
	return target_rotation_angle


func _set_visual_rotation(angle: float) -> void:
	"""
	Tourne le pirateShip UNIQUEMENT sur l'axe Y via Transform3D.basis.
	Les axes X et Z restent intacts → pas de surrélevement quelle que soit
	la position du modèle dans le SubViewport.
	own_world_3d = true garantit que cette rotation n'affecte pas les autres navires.
	"""
	if _pirate_ship_3d == null:
		return
	var new_basis = Basis.from_euler(Vector3(0.0, angle, 0.0))
	_pirate_ship_3d.transform = Transform3D(new_basis, _pirate_ship_3d.transform.origin)


func set_input_mode(mode: InputMode) -> void:
	current_input_mode = mode
	match mode:
		InputMode.MOVE:
			Input.set_default_cursor_shape(Input.CURSOR_CROSS)
			DEBUG.log("Navire [%d] — Mode DÉPLACEMENT actif" % id)
		InputMode.ATTACK:
			Input.set_default_cursor_shape(Input.CURSOR_CROSS)
			DEBUG.log("Navire [%d] — Mode ATTAQUE actif" % id)
		InputMode.INSPECT:
			Input.set_default_cursor_shape(Input.CURSOR_HELP)
			DEBUG.log("Navire [%d] — Mode INSPECTION actif" % id)
		InputMode.NONE:
			Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _init_stats_ui():
	if not ui_layer:
		DEBUG.log("ui_layer est null, impossible de créer l'UI des stats!", DEBUG.ERROR)
		return
# On vérifie si le panel existe déjà avant d'en créer un nouveau
	if stats_panel == null:
		stats_panel = UI_stats_navire.new(self)
	if fish_feedback_label == null:
		fish_feedback_label = UI_fish_navires.new(self)
	DEBUG.log("UI Stats créée pour navire [%d]" % id)
#endregion initialisation


#region camera
func _setup_camera() -> void:
	"""Configure la caméra pour suivre le navire si c'est celui du joueur"""
	if not is_selected:
		return
	var cam = get_tree().get_first_node_in_group("camera_controller")
	if cam and cam.has_method("set_target"):
		cam.set_target(self)

func _get_camera_zoom() -> float:
	var cameras = get_tree().get_nodes_in_group("camera_controller")
	if cameras.size() > 0:
		return cameras[0].zoom.x
	return 1.0
#endregion camera


#region gestion proprietaire
func set_owner_player(player: Player) -> void:
	"""Définit le joueur propriétaire de ce navire"""
	if player_owner != null and player_owner.has_method("remove_navire"):
		player_owner.remove_navire(self)
	player_owner = player
	if player != null and player.has_method("add_navire"):
		player.add_navire(self)
	_setup_input_handling()

func get_owner_player() -> Player:
	"""Retourne le joueur propriétaire"""
	return player_owner

func is_owned_by(player: Player) -> bool:
	"""Vérifie si ce navire appartient au joueur spécifié"""
	return player_owner == player

func is_enemy_of(other_navire: Navires) -> bool:
	"""Vérifie si ce navire est ennemi d'un autre navire"""
	if player_owner == null or other_navire.player_owner == null:
		return false
	return player_owner != other_navire.player_owner
#endregion gestion proprietaire


#region gestion selection
func set_selected(selected: bool) -> void:
	"""Définit si ce navire est sélectionné"""
	is_selected = selected
	queue_redraw()
# Activer/désactiver la caméra selon la sélection
	if selected and player_owner and player_owner.is_human:
		_setup_camera()
		if stats_panel:
			stats_panel.show_ally()
	else:
		stats_visible = false
		if stats_panel:
			stats_panel.hide_all_stats()
	DEBUG.log("Navire %d %s" % [id, "SÉLECTIONNÉ" if selected else "désélectionné"])

func toggle_stats() -> void:
	"""Bascule les stats depuis le menu hex."""
	if not stats_panel:
		return
	stats_panel.handler_ally_persistent()
#endregion gestion selection


#region gestion etat navire
func is_alive() -> bool:
	"""Vérifie si le navire est encore en vie"""
	return vie > 0

func take_damage(damage: int) -> void:
	"""Applique des dégâts au navire"""
	if not is_alive():
		return
	vie = max(vie - damage, 0)
	emit_signal("sig_navire_damaged", self, damage)
	stats_panel.show_stats()
	if vie <= 0:
		die()

func die() -> void:
	"""Gère la mort du navire"""
	DEBUG.log("Navire [%d] en train de mourir..." % id)
# IMPORTANT : Émettre le signal AVANT toute modification
	emit_signal("ship_destroyed", self)
	emit_signal("sig_navire_died", self)
# Désélectionner visuellement le navire
	if is_selected:
		set_selected(false)
# Masquer TOUS les panneaux de stats
	stats_panel.hide_all_stats()
# Masquer le feedback de pêche
	if fish_feedback_label and is_instance_valid(fish_feedback_label):
		fish_feedback_label.hide()
# Notifier le propriétaire
	if player_owner != null and player_owner.has_method("remove_navire"):
		player_owner.remove_navire(self)
	DEBUG.log("Navire [%d] détruit" % id)
	queue_free()

func heal(amount: int) -> void:
	"""Soigne le navire"""
	if not is_alive():
		return
	vie = min(vie + amount, maxvie)
	if is_selected:
		stats_panel.show_ally()

func reset_energie() -> void:
	"""Réinitialise l'énergie au maximum"""
	energie = maxenergie
#endregion gestion etat navire


#region gestion input
func _setup_input_handling() -> void:
	"""Configure la gestion des inputs selon le type de navire"""
	if player_owner and player_owner.is_human:
		set_process_input(true)
		set_process_unhandled_input(true)
	else:
		set_process_input(false)
		set_process_unhandled_input(false)


func _unhandled_input(event: InputEvent) -> void:
	if not player_owner or not player_owner.is_human:
		return

	var turn_manager = get_tree().get_first_node_in_group("turn_manager")
	if turn_manager and not turn_manager.can_navire_act(self):
		return

# ══════════════════════════════════════════════════════════════════
	# CLICS SOURIS
	# ══════════════════════════════════════════════════════════════════
	if event is InputEventMouseButton and event.pressed:
		var mouse_pos: Vector2 = get_global_mouse_position()
		var distance: float    = global_position.distance_to(mouse_pos)

		if event.button_index == MOUSE_BUTTON_LEFT:
			if is_selected and current_input_mode != InputMode.NONE:
				match current_input_mode:
					InputMode.MOVE:
						var clicked_ship := get_ship_at_position(mouse_pos)
						if not clicked_ship:
							var target_case: Vector2i = Map_utils.monde_vers_case(mouse_pos)
							if Map_utils.is_case_navigable(target_case):
								path = Pathfinder.calculer_chemin(case_actuelle, target_case)
								if not path.is_empty():
									DEBUG.log("Chemin: " + str(path))
									is_moving       = true
									target_position = mouse_pos
									show_arrow      = true
									queue_redraw()
								else:
									DEBUG.log("Chemin vide !")
							else:
								DEBUG.log("Case non navigable !")
						set_input_mode(InputMode.NONE)
						get_viewport().set_input_as_handled()
						return
					InputMode.ATTACK:
						var target_case: Vector2i = Map_utils.monde_vers_case(mouse_pos)
						attempt_shoot(target_case)
						set_input_mode(InputMode.NONE)
						get_viewport().set_input_as_handled()
						return
					InputMode.INSPECT:
						var target_case: Vector2i = Map_utils.monde_vers_case(mouse_pos)
						emit_signal("sig_inspect_case", target_case)
						DEBUG.log("Inspection de la case %s" % str(target_case))
						set_input_mode(InputMode.NONE)
						get_viewport().set_input_as_handled()
						return

			if not is_selected:
				for _s in get_tree().get_nodes_in_group("ships"):
					if _s is Navires and _s.player_owner == player_owner and _s.is_selected:
						if _s.current_input_mode != InputMode.NONE:
							return
						break

			if distance <= interaction_radius:
				emit_signal("ship_clicked", self)
				get_viewport().set_input_as_handled()
				return

			if is_selected and energie > 0 and not is_moving and not is_fishing:
				var clicked_ship := get_ship_at_position(mouse_pos)
				if clicked_ship:
					return
				var target_case: Vector2i = Map_utils.monde_vers_case(mouse_pos)
				if Map_utils.is_case_navigable(target_case):
					path = Pathfinder.calculer_chemin(case_actuelle, target_case)
					if not path.is_empty():
						DEBUG.log("Chemin: " + str(path))
						is_moving       = true
						target_position = mouse_pos
						show_arrow      = true
						queue_redraw()
						get_viewport().set_input_as_handled()
					else:
						DEBUG.log("Chemin vide !")
				else:
					DEBUG.log("Case cible NON navigable !")

		elif event.button_index == MOUSE_BUTTON_RIGHT:

			if not is_selected:
				return

			if current_input_mode != InputMode.NONE:
				set_input_mode(InputMode.NONE)
				get_viewport().set_input_as_handled()
				return

			if distance <= interaction_radius:
				var canvas_xform := get_canvas_transform()
				var screen_pos: Vector2 = canvas_xform * global_position
				emit_signal("sig_open_hex_menu", self, screen_pos)
				get_viewport().set_input_as_handled()
				return

			var target_case: Vector2i = Map_utils.monde_vers_case(mouse_pos)
			attempt_shoot(target_case)
			get_viewport().set_input_as_handled()

	if not is_selected:
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if current_input_mode != InputMode.NONE:
			set_input_mode(InputMode.NONE)
			get_viewport().set_input_as_handled()
			return

	if Input.is_action_just_pressed("input_toggle_stats"):
		if is_selected:
			stats_panel.handler_ally_persistent()

	if event.is_action_pressed("input_fish"):
		try_start_fishing()
		return
#endregion gestion input


#region gestion combat
func attempt_shoot(target_case: Vector2i) -> void:
	"""Tente de tirer sur une case cible"""
	if energie < 20:
		DEBUG.log("Pas assez d'énergie pour tirer!")
		return
	if not is_in_range(target_case):
		DEBUG.log("Cible hors de portée!")
		return
	var target_ships = get_ships_at_position(target_case)
	if target_ships.is_empty():
		DEBUG.log("Aucune cible sur cette case!")
		return
	var hit_count = 0
	for target_ship in target_ships:
		if target_ship.is_enemy_of(self):
			shoot_at(target_ship)
			hit_count += 1
	if hit_count > 0:
		energie = max(energie - 20, 0)
		DEBUG.log("Tir effectué sur %d cible(s)!" % hit_count)
		stats_panel.show_ally()
	else:
		DEBUG.log("Aucun ennemi sur cette case!")

func shoot_at(target: Navires) -> void:
	"""Tire sur un navire spécifique"""
	if target == null or not target.is_alive():
		return
	DEBUG.log("Tir sur navire [%d]" % target.id)
	target.take_damage(dgt_tir)
#endregion gestion combat


#region utils
func is_in_range(target_case: Vector2i) -> bool:
	"""Vérifie si une case est à portée de tir (distance hexagonale directe)"""
	var dx = abs(target_case.x - case_actuelle.x)
	var dy = abs(target_case.y - case_actuelle.y)
	var dist := maxi(dx, dy)
	return dist <= tir

func get_ships_at_position(target_case: Vector2i) -> Array[Navires]:
	"""Récupère tous les navires présents sur une case"""
	var ships: Array[Navires] = []
	if data and data.has_method("getNavireByPosition"):
		var raw_ships = data.getNavireByPosition(target_case)
		for ship in raw_ships:
			if ship is Navires and is_instance_valid(ship) and ship.is_alive():
				ships.append(ship)
	return ships

func get_ship_at_position(pos: Vector2) -> Navires:
	"""Récupère le navire à une position donnée (dans le rayon d'interaction)"""
	var all_ships = get_tree().get_nodes_in_group("ships")
	for ship in all_ships:
		if ship is Navires and ship != self:
			var distance = pos.distance_to(ship.global_position)
			if distance <= ship.interaction_radius:
				return ship
	return null

func getPosition() -> Vector2i:
	"""Retourne la position du navire en coordonnées de case"""
	return case_actuelle
#endregion utils


#region rotation
func _update_ship_rotation(delta: float) -> void:
	if _pirate_ship_3d == null:
		return
	var current = _pirate_ship_3d.rotation.y
	var diff    = angle_difference(current, target_rotation_angle)
	if abs(diff) < 0.009:
		_set_visual_rotation(target_rotation_angle)
		return
	_set_visual_rotation(lerp_angle(current, target_rotation_angle, rotation_speed * delta))


func _compute_target_rotation(direction: Vector2) -> float:
	# Le SubViewport 3D a son axe X miroir par rapport au 2D :
	# → haut/bas sont corrects, mais gauche/droite sont inversés.
	# On négative uniquement X pour corriger ce miroir horizontal.
	var mirrored := Vector2(-direction.x, direction.y)
	var angle = mirrored.angle() + deg_to_rad(rotation_offset_deg)
	if rotation_invert:
		angle += PI
	return angle
#endregion rotation


#region process
func _process(delta):
	# Animation de la sélection et de la flèche
	if is_selected or show_arrow:
		queue_redraw()

	# Pêche
	_update_fishing(delta)

	# Déplacement (pour TOUS les navires en mouvement, pas juste le sélectionné)
	if is_moving and not path.is_empty():
		_process_movement(delta)

	# Rotation progressive du bateau (uniquement pendant le déplacement)
	if is_moving:
		_update_ship_rotation(delta)

	# Mettre à jour la visibilité dans le fog (pour navires ennemis)
	if player_owner and not player_owner.is_human:
		_update_visibility_in_fog()

func _process_movement(delta: float) -> void:
	"""Gère le déplacement du navire"""
	if path.is_empty():
		DEBUG.log("Navire [%d] - Chemin vide, arrêt du mouvement" % id)
		is_moving  = false
		show_arrow = false
		queue_redraw()
		return

	var next_case = path[0]
	var next_pos: Vector2 = Map_utils.case_vers_monde(next_case)
	var direction := next_pos - global_position
	var distance = direction.length()

	# --- ROTATION ANTICIPÉE ---
	# Dès qu'on approche d'un waypoint intermédiaire, on regarde déjà
	# vers le suivant pour amorcer le virage avant d'y arriver.
	if distance > 0.5:
		var look_dir := direction.normalized()
		if distance < 60.0 and path.size() >= 2:
			var next_next_pos: Vector2 = Map_utils.case_vers_monde(path[1])
			var next_dir := (next_next_pos - next_pos).normalized()
			if next_dir.length() > 0.1:
				var blend := 1.0 - clampf(distance / 60.0, 0.0, 1.0)
				look_dir = look_dir.lerp(next_dir, blend).normalized()
		target_rotation_angle = _compute_target_rotation(look_dir)

	# --- DÉPLACEMENT À VITESSE CONSTANTE ---
	# Pas de décélération entre waypoints : le bateau garde sa vitesse pleine
	# tout au long du trajet. Le snap ne se déclenche qu'au dernier moment
	# (une frame de déplacement max) pour éviter tout overshooting.
	var snap_threshold: float = vitesse * delta + 2.0
	if distance <= snap_threshold:
		var old_case = case_actuelle

		global_position = next_pos
		path.remove_at(0)
		case_actuelle = next_case
		energie = max(energie - 1, 0)

		DEBUG.log("Navire [%d] arrivé à %s - Cases restantes: %d" % [id, case_actuelle, path.size()])
		DEBUG.log("old_case: %s, case_actuelle: %s, changé: %s" % [old_case, case_actuelle, old_case != case_actuelle])
		if player_owner:
			DEBUG.log("player_owner existe: %s, is_human: %s" % [player_owner.player_name, player_owner.is_human])
		else:
			DEBUG.log("player_owner est NULL !")

# Actualiser le fog si c'est un navire du joueur humain et qu'il a changé de case
		if old_case != case_actuelle and player_owner and player_owner.is_human:
			DEBUG.log("✓ CONDITIONS OK - Appel de _update_fog_of_war()")
			_update_fog_of_war()
		else:
			DEBUG.log("✗ CONDITIONS PAS OK - Pas de mise à jour du fog")
			if old_case == case_actuelle:
				DEBUG.log("    Raison: case n'a pas changé")
			if not player_owner:
				DEBUG.log("    Raison: pas de player_owner")
			if player_owner and not player_owner.is_human:
				DEBUG.log("    Raison: player_owner n'est pas humain")
# Mise à jour de la visibilité pour navires ennemis
		if player_owner and not player_owner.is_human:
			_update_visibility_in_fog()

		if path.is_empty():
			is_moving  = false
			show_arrow = false
			queue_redraw()
			DEBUG.log("Navire [%d] DESTINATION FINALE atteinte!" % id)
	else:
		global_position += direction.normalized() * vitesse * delta
#endregion process


#region UI
func hide_all_ships_stats():
	"""Cache les stats de tous les navires"""
	var all_ships = get_tree().get_nodes_in_group("ships")
	for ship in all_ships:
		if ship is Navires:
			ship.hide_all_stats()


# =========================
# FOG OF WAR UPDATE
# =========================
func _update_fog_of_war() -> void:
	"""Met à jour le fog of war autour de ce navire (pour joueur humain uniquement)"""
	DEBUG.log("[NAVIRE %d] _update_fog_of_war() APPELÉE !" % id)

	if not player_owner or not player_owner.is_human:
		DEBUG.log("[NAVIRE %d] SKIP - pas de player_owner ou pas humain" % id)
		return

	DEBUG.log("[NAVIRE %d] Actualisation du fog à la position %s" % [id, case_actuelle])

	if not fog_manager:
		DEBUG.log("[NAVIRE %d] ERREUR - fog_manager est NULL, tentative de récupération..." % id)
		fog_manager = get_tree().get_first_node_in_group("fog_manager")
		if fog_manager:
			DEBUG.log("[NAVIRE %d] fog_manager récupéré avec succès" % id)
		else:
			DEBUG.log("[NAVIRE %d] ERREUR CRITIQUE - fog_manager introuvable !" % id)

	if fog_manager:
		DEBUG.log("[NAVIRE %d] fog_manager existe, vérification de force_update..." % id)
		if fog_manager.has_method("force_update"):
			DEBUG.log("[NAVIRE %d] ✓ Appel de fog_manager.force_update()" % id)
			fog_manager.force_update()
			return
		else:
			DEBUG.log("[NAVIRE %d] ✗ fog_manager n'a pas la méthode force_update !" % id)

	DEBUG.log("[NAVIRE %d] Fallback - tentative via FogOfWar direct" % id)
	var fog_of_war = get_tree().get_first_node_in_group("fog_of_war")
	if fog_of_war:
		DEBUG.log("[NAVIRE %d] FogOfWar trouvé" % id)
		if fog_of_war.has_method("reveal_around_position"):
			DEBUG.log("[NAVIRE %d] ✓ Appel de fog_of_war.reveal_around_position(%s)" % [id, case_actuelle])
			fog_of_war.reveal_around_position(case_actuelle)
		else:
			DEBUG.log("[NAVIRE %d] ✗ FogOfWar n'a pas la méthode reveal_around_position !" % id)
	else:
		DEBUG.log("[NAVIRE %d] ✗ FogOfWar introuvable !" % id)


# =========================
# VISIBILITÉ DANS LE FOG
# =========================
func _update_visibility_in_fog() -> void:
	"""Met à jour la visibilité de ce navire basée sur le fog of war"""
# Les navires du joueur humain sont toujours visibles
	if player_owner and player_owner.is_human:
		is_visible_to_human = true
		visible = true
		return
# Pour les navires ennemis, vérifier s'ils sont dans le fog
	if not fog_of_war_ref or not fog_of_war_ref.has_method("is_tile_visible"):
		is_visible_to_human = true
		visible = true
		return
	var is_case_visible = fog_of_war_ref.is_tile_visible(case_actuelle)
	is_visible_to_human = is_case_visible
	visible = is_case_visible


# =========================
# DRAW
# =========================
func _draw():
	var cam_zoom = _get_camera_zoom()
	var scale_factor = sqrt(1.0 / cam_zoom)

	if is_selected and player_owner and player_owner.is_human:
		drawable.selection_circle(scale_factor)

# Flèche de déplacement (seulement pour le navire sélectionné)
	if not show_arrow or not is_selected:
		return
	var local_target = target_position - global_position
	drawable.arrow(local_target, scale_factor)
#endregion UI


#region peche
func _get_fish_manager() -> FishManager:
	"""Cherche le FishManager : d'abord par groupe, puis comme enfant du MapManager."""
	var fm = get_tree().get_first_node_in_group("fish_manager")
	if fm:
		return fm
	# Fallback : enfant du MapManager
	var map_manager = get_tree().get_first_node_in_group("Map_manager")
	if map_manager:
		for child in map_manager.get_children():
			if child is FishManager:
				return child
	return null

func _update_fishing(delta: float) -> void:
	if not is_fishing:
		return
	fish_timer -= delta
	if fish_timer <= 0.0:
		finish_fishing()

func try_start_fishing() -> void:
	if is_moving or is_fishing:
		return
	if energie < fish_energy_cost:
		DEBUG.log("Navire [%d] - Pas assez d'énergie pour pêcher" % id)
		return

	var fish_manager: FishManager = _get_fish_manager()
	if not fish_manager:
		DEBUG.log("Navire [%d] - FishManager introuvable !" % id, DEBUG.ERROR)
		return

	if not fish_manager.is_fish_tile(case_actuelle):
		DEBUG.log("Navire [%d] - Cette case n'est pas une zone de pêche" % id)
		DEBUG.log("  → case_actuelle = %s" % str(case_actuelle))
		DEBUG.log("  → Map_data.tiles[%d][%d] = '%s'" % [case_actuelle.y, case_actuelle.x, Map_data.tiles[case_actuelle.y][case_actuelle.x]])
		DEBUG.log("  → Map_data.fish_cases (%d cases) = %s" % [Map_data.fish_cases.size(), str(Map_data.fish_cases)])
		DEBUG.log("  → fish_manager.fish_stocks keys (%d) = %s" % [fish_manager.fish_stocks.size(), str(fish_manager.fish_stocks.keys())])
		return

	if not fish_manager.can_fish_at(case_actuelle):
		DEBUG.log("Navire [%d] - Cette zone de pêche est épuisée !" % id)
		if fish_feedback_label:
			fish_feedback_label.finished_fishing(0)
		return

	sig_show_fishing.emit()
	is_fishing = true
	fish_timer = fish_duration
	energie = max(energie - fish_energy_cost, 0)
	stats_panel.show_ally()
	DEBUG.log("Navire [%d] - Début de pêche sur case %s" % [id, case_actuelle])

func finish_fishing() -> void:
	is_fishing = false

	var fish_manager: FishManager = _get_fish_manager()
	if not fish_manager:
		return

	var wanted := randi_range(fish_yield_min, fish_yield_max)
	if nrbequipage >= 6:
		wanted += 1

	var gain := fish_manager.harvest_fish(case_actuelle, wanted)

	nourriture += gain

	if fish_feedback_label:
		fish_feedback_label.finished_fishing(gain)
		sig_show_stats.emit()

	DEBUG.log("Navire [%d] - Pêche terminée : +%d poissons (case %s)" % [id, gain, case_actuelle])
#endregion peche
