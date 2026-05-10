class_name Navires
extends Node2D

# Permettra de signaler au moteur différents évènements
#region signaux
signal sig_show_stats
signal sig_navire_died(navire: Navires)
signal sig_navire_damaged(navire: Navires, damage: int)
signal ship_clicked(ship: Navires)
signal ship_destroyed(ship: Navires)
signal sig_show_fishing
signal sig_inspect_case(case_pos: Vector2i)
signal sig_open_hex_menu(navire: Navires, screen_pos: Vector2)
signal sig_switch_ship()
signal sig_navire_moved(navire: Navires)

#endregion signaux

@export var attack_sound: AudioStream = null
var _audio_player: AudioStreamPlayer2D = null
# =========================
# MODE D'INPUT (menu contextuel)
# =========================
enum InputMode { NONE, MOVE, ATTACK, INSPECT }
var current_input_mode: InputMode = InputMode.NONE

# =========================
# PROPRIÉTAIRE ET IDENTITÉ
# =========================
#region identité
## Référence directe au joueur propriétaire
@export var player_owner: Player = null

## ID unique du navire
@export var id: int = 0

## Détermine si c'est le navire contrôlé par le joueur humain actuel
var is_player_controlled: bool = false

## Indique si ce navire est actuellement sélectionné
var is_selected: bool = false
var is_visible_to_human: bool = true
var fog_of_war_ref: FogOfWar = null
var pending_path := []
var _confirm_ui: UI_confirm_deplacement = null
#endregion identité

# =========================
# MODÈLE 3D
# =========================
## Chemin vers le fichier .glb à charger pour ce navire.
## Doit être défini AVANT add_child() pour que _setup_node3d_instance()
## puisse charger le bon modèle dès le _ready().
## Par défaut : pirateShip (grand navire joueur).
@export var ship_model_path: String = "res://Assets/navire/pirateShip.glb"

# =========================
# STATS
# =========================
#region stats
var stats_panel : UI_stats_navire
@export var vie: int = 10
@export var maxvie: int = 10
@export var energie: int = 30
@export var maxenergie: int = 30
@export var vitesse: float = 800.0
@export var nrbequipage: int = 0   # (gardé pour compatibilité pêche)
var equipage: Array[CrewMember] = []

# Bonus de synergies actifs (recalculés après chaque recrutement/congédiement)
var _synergy_dgt_bonus: int              = 0
var _synergy_peche_mult: float           = 1.0
var _synergy_regen_mult: float           = 1.0
var _synergy_move_cost_reduction: float  = 0.0  # Réduction du coût de déplacement par synergie (0.0–1.0)
var _synergy_full_crew: bool             = false
@export var interaction_radius: float = 80.0
@export var stats_duration: float = 2.5
@export var tir: int = 4		# Portée d'un tir
@export var dgt_tir: int = 2	# Dégâts d'un tir

## Indique si ce navire a déjà attaqué ce tour (interdit le switch bateau)
var has_attacked_this_turn: bool = false

@onready var ui_layer: CanvasLayer = get_tree().get_first_node_in_group("ui_layer")
@onready var data := get_tree().get_first_node_in_group("shared_entities")

# Référence au fog manager pour mise à jour en temps réels
var fog_manager: FogManager = null
var match_context: MatchContext = null
var network_manager: NetworkManager = null

var drawable : Drawable
#endregion stats

# =========================
# PÊCHE
# =========================
#region pêche
@export var nourriture: int = 0
@export var fish_energy_cost: int = 1
@export var fish_duration: float = 1.2
@export var fish_yield_min: int = 1
@export var fish_yield_max: int = 3
var _arrow_overlay: ArrowOverlay = null
var is_fishing := false
var fish_timer := 0.0
#endregion pêche

# =========================
# FEEDBACK PÊCHE
# =========================
#region feedback pêche
var fish_feedback_label: UI_fish_navires
@export var fish_feedback_duration: float = 0.8
var fish_feedback_timer: float = 0.0

# =========================
# FEEDBACK COMBAT
# =========================
#region feedback combat
## Label flottant partagé par TOUS les navires de la scène (un seul nœud suffit)
var combat_feedback_label: UI_combat_navires
#endregion feedback combat

var stats_timer := 0.0
# stats_visible = true signifie que le joueur a VOLONTAIREMENT activé l'affichage
# Les stats restent visibles même si on change de sélection, jusqu'à désactivation manuelle
var stats_visible := false
#endregion feedback pêche

# =========================
# DÉPLACEMENT
# =========================
#region déplacement
var path := []
var is_moving := false
var case_actuelle: Vector2i
var target_position: Vector2 = Vector2.ZERO
var show_arrow: bool = false
#endregion déplacement

# =========================
# ROTATION DU BATEAU
# =========================
#region rotation du bateau
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
#endregion rotation du bateau

# =========================
# DÉCALAGE VISUEL DU SPRITE
# =========================
## Décale le Sprite2D pour que le centre VISUEL du bateau coïncide avec
## global_position (= l'ancre logique utilisée pour déterminer la case occupée).
@export var hull_offset: Vector2 = Vector2.ZERO

var rpc_navire : RPC_Navires = null

# =========================
# CAMÉRA 2D
# =========================
@onready var camera: Camera2D = get_node_or_null("Camera2D")

#region initialisation
func _init() -> void:
	add_to_group("ships")


func _ready():
	await get_tree().process_frame
	print_tree()
	match_context = get_tree().get_first_node_in_group("match_context")
	network_manager = get_tree().get_first_node_in_group("network_manager")
	#rpc_navire = RPC_Navires.new(self)
  
	case_actuelle = Map_utils.monde_vers_case(global_position)

	# Résoudre le nœud visuel (Sprite2D) et configurer la rotation 3D
	# ship_model_path a déjà été défini par GameManager avant add_child()
	_setup_node3d_instance()

	# Configuration de la caméra pour le navire contrôlé par le joueur
	_setup_camera()

	# Configuration des inputs selon le type de contrôle
	_setup_input_handling()

	# Initialisation de l'UI

	_init_stats_ui()
	_init_crew()
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
	attack_sound = load("res://son/sf_canon_01.mp3")
	_audio_player = AudioStreamPlayer2D.new()
	_audio_player.stream = attack_sound
	_audio_player.volume_db = 10.0
	add_child(_audio_player)
	# Debug
	var owner_name = player_owner.player_name if player_owner else "AUCUN"
	var control_type = "CONTRÔLÉ" if is_player_controlled else "IA/ENNEMI"
	DEBUG.log("Navire [%s] initialisé - Propriétaire: %s - Type: %s - Position: %s - Modèle: %s" % [
		id, owner_name, control_type, case_actuelle, ship_model_path
	])
	if _arrow_overlay == null:
		_arrow_overlay = ArrowOverlay.new()
		_arrow_overlay.navire = self
		ui_layer.add_child(_arrow_overlay)


func _setup_node3d_instance() -> void:
	"""
	SOLUTION FINALE — doc Godot Transform3D + own_world_3d :

	1. own_world_3d = true sur le SubViewport → chaque navire a son propre
	   monde 3D isolé, les rotations ne se partagent plus entre instances.

	2. On charge dynamiquement le modèle défini dans ship_model_path,
	   ce qui permet d'avoir des modèles différents selon le joueur propriétaire.
	   Le modèle est nommé "pirateShip" après instanciation pour que le reste
	   du code (rotation, etc.) fonctionne de manière uniforme.

	3. Le Sprite2D n'est jamais tourné → pas de problème de pivot 2D.
	"""
	# Isoler le monde 3D de ce SubViewport pour éviter le partage entre instances
	var subviewport = get_node_or_null("Sprite2D/SubViewport")
	if subviewport:
		subviewport.own_world_3d = true
		DEBUG.log("Navire [%d] - SubViewport.own_world_3d = true" % id)

	# Récupérer le Node3D parent qui contiendra notre modèle
	var node3d = get_node_or_null("Sprite2D/SubViewport/Node3D")
	if not node3d:
		DEBUG.log("Navire [%d] - ERREUR : Node3D introuvable" % id)
		return

	# Supprimer le modèle par défaut présent dans la scène de base
	# (free() immédiat : on est dans _ready avant que le modèle soit utilisé)
	var existing = node3d.get_node_or_null("pirateShip")
	if existing:
		existing.free()
		DEBUG.log("Navire [%d] - Modèle par défaut supprimé" % id)

	# Charger et instancier le bon modèle selon ship_model_path
	var model_scene: PackedScene = load(ship_model_path)
	if model_scene:
		var model_instance: Node3D = model_scene.instantiate()
		# Nom uniforme "pirateShip" pour que toute la logique de rotation
		# reste identique quel que soit le modèle chargé
		model_instance.name = "pirateShip"
		node3d.add_child(model_instance)
		_pirate_ship_3d = model_instance
		target_rotation_angle = model_instance.rotation.y
		DEBUG.log("Navire [%d] - Modèle chargé avec succès : '%s'" % [id, ship_model_path])
	else:
		DEBUG.log("Navire [%d] - ERREUR : Impossible de charger le modèle '%s'" % [id, ship_model_path])

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
	# UI_fish_navires extends Control → new() sans argument obligatoire
	# On l'ajoute au ui_layer (comme HexContextMenu) pour qu'il s'affiche par-dessus tout
	if fish_feedback_label == null:
		fish_feedback_label = UI_fish_navires.new()
		ui_layer.add_child(fish_feedback_label)
		# Connecter le signal du navire à l'UI fish
		sig_show_fishing.connect(func(): fish_feedback_label.on_show_fishing(self))

	# ── Feedback combat : un label par navire (comme UI_fish_navires) ──
	if combat_feedback_label == null:
		combat_feedback_label = UI_combat_navires.new()
		ui_layer.add_child(combat_feedback_label)

	DEBUG.log("UI Stats créée pour navire [%d]" % id)
#endregion initialisation


#region camera
## Configure la caméra pour suivre le navire si c'est celui du joueur
func _setup_camera() -> void:
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
## Définit le joueur propriétaire de ce navire
func set_owner_player(player: Player) -> void:
	if player_owner != null and player_owner.has_method("remove_navire"):
		player_owner.remove_navire(self)
	player_owner = player
	if player != null and player.has_method("add_navire"):
		player.add_navire(self)
	_setup_input_handling()

## Retourne le joueur propriétaire du navire
func get_owner_player() -> Player:
	return player_owner

func _is_local_human_owner() -> bool:
	if player_owner == null:
		return false
	if not player_owner.is_human:
		return false
	if match_context == null:
		match_context = get_tree().get_first_node_in_group("match_context")
	if match_context == null:
		return true
	if match_context.mode == MatchContext.MatchMode.MULTI:
		return player_owner.is_local
	return true

## Vérifie si ce navire appartient au joueur spécifié
func is_owned_by(player: Player) -> bool:
	return player_owner == player

## Vérifie si ce navire est ennemi d'un autre navire
func is_enemy_of(other_navire: Navires) -> bool:
	if player_owner == null or other_navire.player_owner == null:
		return false
	return player_owner != other_navire.player_owner
#endregion gestion proprietaire


#region gestion selection
## Définit si ce navire est sélectionné
func set_selected(selected: bool, silent:bool = false) -> void:
	"""Définit si ce navire est sélectionné"""
	is_selected = selected
	queue_redraw()
	# Activer/désactiver la caméra selon la sélection
	if selected and player_owner and player_owner.is_human:
		if(!silent):
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
## Vérifie si le navire est encore en vie
func is_alive() -> bool:
	return vie > 0

## Applique des dégâts au navire
func take_damage(damage: int, show_ui: bool = true) -> void:
	if not is_alive():
		return
	vie = max(vie - damage, 0)
	emit_signal("sig_navire_damaged", self, damage)

	if show_ui:
		stats_panel.show_stats()
	# ── Feedback visuel : "-X ❤️" flottant au-dessus du navire touché ──
	if combat_feedback_label and is_instance_valid(combat_feedback_label):
		combat_feedback_label.show_damage(self, damage)

	if vie <= 0:
		die()

## Gère la mort du navire
func die() -> void:
	DEBUG.log("Navire [%d] en train de mourir..." % id)
	# IMPORTANT : Émettre le signal AVANT toute modification
	emit_signal("ship_destroyed", self)
	emit_signal("sig_navire_died", self)
	# Désélectionner visuellement le navire
	if is_selected:
		set_selected(false)
	# Masquer TOUS les panneaux de stats
	stats_panel.hide_all_stats()
	# Masquer le feedback de pêche — close() au lieu de hide() car UI_fish_navires est un Control
	if fish_feedback_label and is_instance_valid(fish_feedback_label):
		fish_feedback_label.close()
	# Masquer le feedback de combat pour ce navire
	if combat_feedback_label and is_instance_valid(combat_feedback_label):
		combat_feedback_label.close_for(self)
	# Notifier le propriétaire
	if player_owner != null and player_owner.has_method("remove_navire"):
		player_owner.remove_navire(self)
	DEBUG.log("Navire [%d] détruit" % id)
	queue_free()
	if _arrow_overlay == null:
		_arrow_overlay = ArrowOverlay.new()
		_arrow_overlay.navire = self
		ui_layer.add_child(_arrow_overlay)

## Soigne le navire
func heal(amount: int) -> void:
	if not is_alive():
		return
	vie = min(vie + amount, maxvie)
	if is_selected:
		stats_panel.show_ally()

## Réinitialise l'énergie au maximum
func reset_energie() -> void:
	energie = maxenergie
	has_attacked_this_turn = false
#endregion gestion etat navire


#region gestion input
func _setup_input_handling() -> void:
	if _is_local_human_owner():
		set_process_input(true)
		set_process_unhandled_input(true)
	else:
		set_process_input(false)
		set_process_unhandled_input(false)


func _unhandled_input(event: InputEvent) -> void:
	if not _is_local_human_owner():
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

		if event.button_index == MOUSE_BUTTON_RIGHT:
			# MODE ACTIF
			# Seulement le navire sélectionné exécute l'action ET absorbe le clic.
			# Les navires non-sélectionnés ignorent complètement ce bloc.

			if is_selected and current_input_mode != InputMode.NONE:
				match current_input_mode:

					InputMode.MOVE:
						var clicked_ship := get_ship_at_position(mouse_pos)
						if not clicked_ship:
							if energie <= 0:
								DEBUG.log("Navire [%d] — Pas assez d'énergie pour se déplacer!" % id)
							else:
								var target_case: Vector2i = Map_utils.monde_vers_case(mouse_pos)
								if Map_utils.is_case_navigable(target_case):
									var computed_path = Pathfinder.calculer_chemin(case_actuelle, target_case)
									if not computed_path.is_empty():
										DEBUG.log("Chemin: " + str(computed_path))
										_request_move_confirmation(computed_path)
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

			# ── PAS DE MODE ACTIF ─────────────────────────────────────
			# Si N'IMPORTE QUEL navire (allié OU ennemi) a un mode actif,
			if not is_selected:
				for _s in get_tree().get_nodes_in_group("ships"):
					if _s is Navires and _s.is_selected:
						if _s.current_input_mode != InputMode.NONE:
							return
						break

			# Sélection normale du navire
			if distance <= interaction_radius:
				emit_signal("ship_clicked", self)
				get_viewport().set_input_as_handled()
				return

			# Comportement original : déplacement libre (clic gauche sans mode)
			if is_selected and energie > 0 and not is_moving and not is_fishing:
				var clicked_ship := get_ship_at_position(mouse_pos)
				if clicked_ship:
					return
				var target_case: Vector2i = Map_utils.monde_vers_case(mouse_pos)
				if Map_utils.is_case_navigable(target_case):
					var computed_path = Pathfinder.calculer_chemin(case_actuelle, target_case)
					if not computed_path.is_empty():
						DEBUG.log("Chemin: " + str(computed_path))
						_request_move_confirmation(computed_path)
						get_viewport().set_input_as_handled()
					else:
						DEBUG.log("Chemin vide !")
				else:
					DEBUG.log("Case cible NON navigable !")

		elif event.button_index == MOUSE_BUTTON_LEFT:

			# Seul le navire sélectionné traite le clic droit
			if not is_selected:
				return

			# Annuler une confirmation en attente
			if not pending_path.is_empty():
				_cancel_pending_move()
				get_viewport().set_input_as_handled()
				return

			# Annuler un mode en cours
			if current_input_mode != InputMode.NONE:
				set_input_mode(InputMode.NONE)
				get_viewport().set_input_as_handled()
				return

			# Sur le navire → ouvrir le menu hexagonal
			if distance <= interaction_radius:
				var canvas_xform := get_canvas_transform()
				var screen_pos: Vector2 = canvas_xform * global_position
				emit_signal("sig_open_hex_menu", self, screen_pos)
				get_viewport().set_input_as_handled()
				return

			# En dehors → tir direct (clic droit hors menu)
			var target_case: Vector2i = Map_utils.monde_vers_case(mouse_pos)
			attempt_shoot(target_case)
			get_viewport().set_input_as_handled()

	# ══════════════════════════════════════════════════════════════════
	# CLAVIER
	# ══════════════════════════════════════════════════════════════════
	if not is_selected:
		return

	# Echap → annuler la confirmation en attente ou le mode actif
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if not pending_path.is_empty():
			_cancel_pending_move()
			get_viewport().set_input_as_handled()
			return
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
	# Vérifications de base
	if energie < 10:
		DEBUG.log("Pas assez d'énergie pour tirer!")
		return
	if not is_in_range(target_case):
		DEBUG.log("Cible hors de portée!")
		# ── Feedback visuel : ennemi trop loin ──
		if combat_feedback_label and is_instance_valid(combat_feedback_label):
			combat_feedback_label.show_out_of_range(self)
		return
			
	# Tenter d'attaquer un port sur cette case
	var port = _get_port_at(target_case)
	if port != null and port.player_owner != player_owner:
		energie = max(energie - 10, 0)
		has_attacked_this_turn = true
		if _audio_player and attack_sound:
			_audio_player.play()
		stats_panel.show_ally()
		if combat_feedback_label and is_instance_valid(combat_feedback_label):
			combat_feedback_label.show_energy_cost(self, 10)
		DEBUG.log("Navire [%d] attaque port [%d] pour %d dégâts" % [id, port.id, dgt_tir])
		if match_context != null and match_context.mode == MatchContext.MatchMode.MULTI:
			var game_manager = get_tree().get_first_node_in_group("game_manager")
			if game_manager and game_manager.has_method("apply_port_damage_networked"):
				game_manager.apply_port_damage_networked(port.id, dgt_tir, player_owner.player_id)
			else:
				push_error("[NAVIRE %d] GameManager introuvable pour apply_port_damage_networked" % id)
		else:
			port.take_damage(dgt_tir, player_owner)
		return
		
	# Récupérer les navires sur la case cible
	var target_ships = get_ships_at_position(target_case)
	if target_ships.is_empty():
		DEBUG.log("Aucune cible sur cette case!")
		return
		
	# Tirer sur tous les navires ennemis présents
	var hit_count = 0
	for target_ship in target_ships:
		if target_ship.is_enemy_of(self):
			shoot_at(target_ship)
			hit_count += 1
			
	if hit_count > 0:
		energie = max(energie - 10, 0)
		has_attacked_this_turn = true
		DEBUG.log("Tir effectué sur %d cible(s)!" % hit_count)
		stats_panel.show_ally()
		# ── Feedback visuel : coût en énergie sur l'attaquant ──
		if combat_feedback_label and is_instance_valid(combat_feedback_label):
			combat_feedback_label.show_energy_cost(self, 10)
	else:
		DEBUG.log("Aucun ennemi sur cette case!")
	

## Tire sur un navire spécifique
func shoot_at(target: Navires) -> void:
	if target == null or not target.is_alive():
		return
	DEBUG.log("Tir sur navire [%d]" % target.id)
	print("[DMG] shoot_at — tireur id=%d owner=%s | cible id=%d | dgt_tir=%d | match_context null=%s" % [
		id,
		player_owner.player_name if player_owner else "NULL",
		target.id,
		dgt_tir,
		str(match_context == null)
	])
	# ── SON D'ATTAQUE ──────────────────────────────────────────────
	if _audio_player and attack_sound:
		_audio_player.stream = attack_sound
		_audio_player.play()

	# En mode multi : déléguer au GameManager qui a un nœud réseau stable
	if match_context != null and match_context.mode == MatchContext.MatchMode.MULTI:
		var game_manager = get_tree().get_first_node_in_group("game_manager")
		print("[DMG] shoot_at MULTI — game_manager null=%s" % str(game_manager == null))
		if game_manager and game_manager.has_method("apply_damage_networked"):
			game_manager.apply_damage_networked(target.id, dgt_tir)
		else:
			push_error("[NAVIRE %d] GameManager introuvable pour apply_damage_networked" % id)
	else:
		# Mode solo : application directe
		print("[DMG] shoot_at SOLO — target.vie avant=%d" % target.vie)
		target.take_damage(dgt_tir)
#endregion gestion combat

#region sync réseau
#endregion sync réseau

#region utils
func is_in_range(target_case: Vector2i) -> bool:
	# Pour les ports (cases non navigables), on cherche la case navigable
	# adjacente la plus proche et on mesure depuis elle
	if not Map_utils.is_case_navigable(target_case):
		var neighbors := Map_utils.get_neighbors(target_case)
		var min_dist := 999
		for neighbor in neighbors:
			if Map_utils.is_case_navigable(neighbor):
				# +1 car on doit encore traverser la case du port lui-même
				min_dist = mini(min_dist, _hex_distance(case_actuelle, neighbor) + 1)
		return min_dist <= tir
	# Pour les navires, on utilise la distance hexagonale directe
	return _hex_distance(case_actuelle, target_case) <= tir


## Calcule la distance hexagonale en cases entre deux positions (sans tenir compte des obstacles).
func _hex_distance(a: Vector2i, b: Vector2i) -> int:
	var map_manager = get_tree().get_first_node_in_group("Map_manager")
	if not map_manager:
		return 999
	var a1 = map_manager.grid.offset_to_axial(a.x, a.y)
	var a2 = map_manager.grid.offset_to_axial(b.x, b.y)
	var dq = int(a2.x) - int(a1.x)
	var dr = int(a2.y) - int(a1.y)
	return int((abs(dq) + abs(dr) + abs(dq + dr)) / 2)

## Récupère tous les navires présents sur une case
func get_ships_at_position(target_case: Vector2i) -> Array[Navires]:
	var ships: Array[Navires] = []
	if data and data.has_method("getNavireByPosition"):
		var raw_ships = data.getNavireByPosition(target_case)
		for ship in raw_ships:
			if ship is Navires and is_instance_valid(ship) and ship.is_alive():
				ships.append(ship)
	return ships

## Récupère le navire à une position donnée (dans le rayon d'interaction)
func get_ship_at_position(pos: Vector2) -> Navires:
	var all_ships = get_tree().get_nodes_in_group("ships")
	for ship in all_ships:
		if ship is Navires and ship != self:
			var distance = pos.distance_to(ship.global_position)
			if distance <= ship.interaction_radius:
				return ship
	return null

## Retourne la position du navire en coordonnées de case
func getPosition() -> Vector2i:
	return case_actuelle
	
## Retourne le port présent sur la case donnée, ou null si aucun port n'y est.
func _get_port_at(target_case: Vector2i) -> Node2D:
	# Vérification rapide du type de terrain dans le tableau brut
	if Map_data.tiles[target_case.y][target_case.x] != "port":
		return null

	# Récupérer le MapManager et sa grille
	var map_manager = get_tree().get_first_node_in_group("Map_manager")
	if map_manager == null or not "grid" in map_manager:
		DEBUG.log("Navire [%d] - _get_port_at : Map_manager/grid introuvable !" % id, DEBUG.ERROR)
		return null

	var grid: HexGrid = map_manager.grid

	# Convertir offset → axial pour accéder à la bonne clé dans cells{}
	var axial: Vector2 = grid.offset_to_axial(target_case.x, target_case.y)
	var q := int(axial.x)
	var r := int(axial.y)
	var cell: HexCell = grid.get_cell(q, r, -q - r)

	if cell == null:
		DEBUG.log("Navire [%d] - _get_port_at : cellule axiale (%d,%d) introuvable" % [id, q, r], DEBUG.WARNING)
		return null

	return cell.port_instance
	
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
	if player_owner and not _is_local_human_owner():
		_update_visibility_in_fog()

## Gère le déplacement du navire
func _process_movement(delta: float) -> void:
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
		energie = max(energie - roundi(get_effective_move_cost()), 0)

		DEBUG.log("Navire [%d] arrivé à %s - Cases restantes: %d" % [id, case_actuelle, path.size()])
		DEBUG.log("old_case: %s, case_actuelle: %s, changé: %s" % [old_case, case_actuelle, old_case != case_actuelle])
		if energie <= 0:
			is_moving  = false
			show_arrow = false
			path.clear()
			queue_redraw()
			DEBUG.log("Navire [%d] — Énergie épuisée, arrêt du déplacement" % id)
			return
		if player_owner:
			DEBUG.log("player_owner existe: %s, is_human: %s, is_local: %s" % [player_owner.player_name, player_owner.is_human, player_owner.is_local])
		else:
			DEBUG.log("player_owner est NULL !")

	# Actualiser le fog si c'est un navire du joueur humain et qu'il a changé de case
		if old_case != case_actuelle:
			if _is_local_human_owner():
				DEBUG.log("✓ CONDITIONS OK - Appel de _update_fog_of_war()")
				_update_fog_of_war()
				# Synchroniser la nouvelle position vers tous les autres peers via le GameManager
				if multiplayer.has_multiplayer_peer():
					var game_manager = get_tree().get_first_node_in_group("game_manager")
					if game_manager and game_manager.has_method("sync_ship_position"):
						game_manager.sync_ship_position(id, case_actuelle.x, case_actuelle.y, global_position.x, global_position.y, target_rotation_angle)
			else:
				DEBUG.log("✗ CONDITIONS PAS OK - Pas de mise à jour du fog")
				if old_case == case_actuelle:
					DEBUG.log("    Raison: case n'a pas changé")
				if not player_owner:
					DEBUG.log("    Raison: pas de player_owner")
				elif not _is_local_human_owner():
					DEBUG.log("    Raison: propriétaire non humain local")

		if player_owner and not _is_local_human_owner():
			_update_visibility_in_fog()

		if path.is_empty():
			is_moving = false
			show_arrow = false
			queue_redraw()
			DEBUG.log("Navire [%d] DESTINATION FINALE atteinte!" % id)
			emit_signal("sig_navire_moved", self)  # Signale la fin du déplacement (utilisé par le tutoriel)
	else:
		global_position += direction.normalized() * vitesse * delta
#endregion process

#region confirmation déplacement
func _request_move_confirmation(computed_path: Array) -> void:
	# Fermer une confirmation précédente si elle traîne
	_cancel_pending_move()

	# ── TRONQUER le chemin si l'énergie est insuffisante ──
	# Le joueur ne peut avancer que d'autant de cases qu'il a d'énergie.
	var affordable_path: Array = computed_path
	var cost_per_case := get_effective_move_cost()
	var max_cases := int(float(energie) / cost_per_case)
	if computed_path.size() > max_cases:
		affordable_path = computed_path.slice(0, max_cases)
		DEBUG.log("Navire [%d] — Chemin tronqué à %d cases (énergie: %d, coût/case: %.2f)" % [id, affordable_path.size(), energie, cost_per_case])

	pending_path = affordable_path
	var cost: int = roundi(float(affordable_path.size()) * cost_per_case)  # coût réel en énergie

	if not _confirm_ui:
		_confirm_ui = UI_confirm_deplacement.new()
		_confirm_ui.confirmed.connect(_on_move_confirmed)
		_confirm_ui.cancelled.connect(_on_move_cancelled)
		ui_layer.add_child(_confirm_ui)

	# Positionner la bulle près du navire (en coordonnées écran)
	var canvas_xform := get_canvas_transform()
	var screen_pos: Vector2 = canvas_xform * global_position
	_confirm_ui.show_for(affordable_path.size(), cost, screen_pos)

	# Dessiner la flèche vers la destination réellement atteignable
	show_arrow = true
	target_position = Map_utils.case_vers_monde(affordable_path.back())
	queue_redraw()
	DEBUG.log("Navire [%d] — Confirmation demandée : %d case(s) pour %d ⚡" % [id, affordable_path.size(), cost])

func _on_move_confirmed() -> void:
	if pending_path.is_empty():
		return
	path           = pending_path
	pending_path   = []
	is_moving      = true
	show_arrow     = true
	target_position = Map_utils.case_vers_monde(path.back())
	queue_redraw()
	DEBUG.log("Navire [%d] — Déplacement confirmé, %d cases" % [id, path.size()])

func _on_move_cancelled() -> void:
	_cancel_pending_move()
	DEBUG.log("Navire [%d] — Déplacement annulé" % id)

func _cancel_pending_move() -> void:
	pending_path = []
	if _confirm_ui and is_instance_valid(_confirm_ui):
		_confirm_ui.hide_ui()
	show_arrow = false
	queue_redraw()
#endregion confirmation déplacement



#region UI
## Cache les stats de tous les navires
func hide_all_ships_stats():
	var all_ships = get_tree().get_nodes_in_group("ships")
	for ship in all_ships:
		if ship is Navires:
			ship.hide_all_stats()

## Met à jour le fog of war autour de ce navire
func _update_fog_of_war() -> void:
	DEBUG.log("[NAVIRE %d] _update_fog_of_war() APPELÉE !" % id)
	if not _is_local_human_owner():
		DEBUG.log("[NAVIRE %d] SKIP - pas de propriétaire local humain" % id)
		return
	DEBUG.log("[NAVIRE %d] Actualisation du fog à la position %s" % [id, case_actuelle])
	if not fog_manager:
		DEBUG.log("[NAVIRE %d] ERREUR - fog_manager est NULL, tentative de récupération..." % id,DEBUG.WARNING)
		fog_manager = get_tree().get_first_node_in_group("fog_manager")
		if fog_manager:
			DEBUG.log("[NAVIRE %d] fog_manager récupéré avec succès" % id)
		else:
			DEBUG.log("[NAVIRE %d] ERREUR CRITIQUE - fog_manager introuvable !" % id, DEBUG.ERROR)
	if fog_manager:
		DEBUG.log("[NAVIRE %d] fog_manager existe, vérification de force_update..." % id)
		if fog_manager.has_method("force_update"):
			DEBUG.log("[NAVIRE %d] ✓ Appel de fog_manager.force_update()" % id)
			fog_manager.force_update()
			return
		else:
			DEBUG.log("[NAVIRE %d] ✗ fog_manager n'a pas la méthode force_update !" % id,DEBUG.WARNING)
	DEBUG.log("[NAVIRE %d] Fallback - tentative via FogOfWar direct" % id)
	var fog_of_war = get_tree().get_first_node_in_group("fog_of_war")
	if fog_of_war:
		DEBUG.log("[NAVIRE %d] FogOfWar trouvé" % id)
		if fog_of_war.has_method("reveal_around_position"):
			DEBUG.log("[NAVIRE %d] ✓ Appel de fog_of_war.reveal_around_position(%s)" % [id, case_actuelle])
			fog_of_war.reveal_around_position(case_actuelle)
		else:
			DEBUG.log("[NAVIRE %d] ✗ FogOfWar n'a pas la méthode reveal_around_position !" % id, DEBUG.WARNING)
	else:
		DEBUG.log("[NAVIRE %d] ✗ FogOfWar introuvable !" % id,DEBUG.ERROR)

## Met à jour la visibilité de ce navire basée sur le fog of war
func _update_visibility_in_fog() -> void:
  # Met à jour la visibilité de ce navire basée sur le fog of war
	if _is_local_human_owner():
		is_visible_to_human = true
		visible = true
		return
	if not fog_of_war_ref or not fog_of_war_ref.has_method("is_tile_visible"):
		is_visible_to_human = true
		visible = true
		return
	var is_case_visible = fog_of_war_ref.is_tile_visible(case_actuelle)
	is_visible_to_human = is_case_visible
	visible = is_case_visible

func _draw():
	var cam_zoom = _get_camera_zoom()
	var scale_factor = sqrt(1.0 / cam_zoom)
	if is_selected and _is_local_human_owner():
		drawable.selection_circle(scale_factor)

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
	if not Map_utils.is_on_water(global_position):
		return

	# Zone de pêche épuisée → on signale mais on ne bloque pas (eau ordinaire possible)
	if fish_manager.is_fish_tile(case_actuelle) and not fish_manager.can_fish_at(case_actuelle):
		DEBUG.log("Navire [%d] - Cette zone de pêche est épuisée !" % id)
		if fish_feedback_label:
			fish_feedback_label.finished_fishing(self, 0)
		return

	sig_show_fishing.emit()
	is_fishing = true
	fish_timer = fish_duration
	energie = max(energie - fish_energy_cost, 0)
	stats_panel.show_ally()

	var zone_type = "zone de pêche" if fish_manager.is_fish_tile(case_actuelle) else "eau libre"
	DEBUG.log("Navire [%d] - Début de pêche sur case %s (%s)" % [id, case_actuelle, zone_type])

func finish_fishing() -> void:
	is_fishing = false

	var fish_manager: FishManager = _get_fish_manager()
	if not fish_manager:
		return

	var gain: int = 0

	if fish_manager.is_fish_tile(case_actuelle):
		# Zone de pêche : rendement élevé (6-7, +bonus équipage et synergies)
		var wanted := randi_range(6, 7)
		wanted += get_crew_fishing_bonus()
		wanted = int(float(wanted) * _synergy_peche_mult)
		gain = fish_manager.harvest_fish(case_actuelle, wanted)
	else:
		# Eau libre (peu profonde ou profonde) : rendement faible (1-2)
		gain = randi_range(1, 2)
		gain += get_crew_fishing_bonus()
		gain = mini(int(float(gain) * _synergy_peche_mult), 5)

	nourriture += gain

	if fish_feedback_label:
		# Passer self en premier argument — UI_fish_navires.finished_fishing(navire, gain)
		fish_feedback_label.finished_fishing(self, gain)
		sig_show_stats.emit()

	var zone_type = "zone de pêche" if fish_manager.is_fish_tile(case_actuelle) else "eau libre"
	DEBUG.log("Navire [%d] - Pêche terminée : +%d poissons sur %s (case %s)" % [id, gain, zone_type, case_actuelle])
#endregion peche


#region equipage

# =========================
# CONSTANTES DE SYNERGIES
# =========================
const MAX_CREW: int = 6

## Synergie "Flotte de guerre" : Canonnier + Corsaire + Tireur d'élite → dgt_tir ×1.5
const SYNERGIE_GUERRE := [CrewMember.Role.CANONNIER, CrewMember.Role.CORSAIRE, CrewMember.Role.TIREUR_ELITE]

## Synergie "Navire de pêche" : Pêcheur + Cuisinier → bonus_peche ×2
const SYNERGIE_PECHE := [CrewMember.Role.PECHEUR, CrewMember.Role.CUISINIER]

## Synergie "Duo de soins" : Médecin + Cuisinier → regen_vie doublée
const SYNERGIE_SOINS := [CrewMember.Role.MEDECIN, CrewMember.Role.CUISINIER]

## Synergie "Vitesse maximale" : Navigateur + Éclaireur → +200 vitesse
const SYNERGIE_VITESSE := [CrewMember.Role.NAVIGATEUR, CrewMember.Role.ECLAIREUR]

## Synergie "Équipage complet" : 6 membres → +10% sur toutes les stats
const SYNERGIE_FULL_CREW_SIZE: int = 6


## Initialise l'équipage avec le capitaine par défaut.
func _init_crew() -> void:
	if equipage.is_empty():
		var capitaine = CrewMember.new(CrewMember.Role.CAPITAINE)
		equipage.append(capitaine)
		nrbequipage = equipage.size()
		DEBUG.log("Navire [%d] — Capitaine ajouté, équipage initialisé." % id)


## Retourne le coût d'un rôle après réduction Diplomate.
func get_hire_cost(role: CrewMember.Role) -> int:
	var base_cost: int = CrewMember.ROLE_COSTS[role]
	var reduction: float = 0.0
	for member in equipage:
		reduction = maxf(reduction, member.reduction_cout)
	return maxi(1, int(float(base_cost) * (1.0 - reduction)))


## Ajoute un membre d'équipage et applique ses bonus.
func add_crew_member(member: CrewMember) -> void:
	if equipage.size() >= MAX_CREW:
		DEBUG.log("Navire [%d] — Équipage plein, impossible d'ajouter %s." % [id, member.nom], DEBUG.WARNING)
		return

	equipage.append(member)
	nrbequipage = equipage.size()
	_apply_crew_bonus(member)
	compute_crew_synergies()
	DEBUG.log("Navire [%d] — %s rejoint l'équipage (total : %d)" % [id, member.nom, nrbequipage])


## Retire un membre à un index donné (0 = capitaine, protégé).
func remove_crew_member(index: int) -> void:
	if index <= 0 or index >= equipage.size():
		DEBUG.log("Navire [%d] — Impossible de retirer le membre à l'index %d." % [id, index], DEBUG.WARNING)
		return

	var member: CrewMember = equipage[index]
	_remove_crew_bonus(member)
	equipage.remove_at(index)
	nrbequipage = equipage.size()
	compute_crew_synergies()
	DEBUG.log("Navire [%d] — %s a quitté l'équipage (total : %d)" % [id, member.nom, nrbequipage])


## Vérifie si un rôle est déjà occupé dans l'équipage.
func has_crew_role(role: CrewMember.Role) -> bool:
	for member in equipage:
		if member.role == role:
			return true
	return false


## Retourne le nombre de membres ayant un rôle donné.
func count_crew_role(role: CrewMember.Role) -> int:
	var count := 0
	for member in equipage:
		if member.role == role:
			count += 1
	return count


## Applique les bonus individuels d'un membre au navire.
func _apply_crew_bonus(member: CrewMember) -> void:
	dgt_tir    += member.bonus_dgt_tir
	tir        += member.bonus_tir
	maxvie     += member.bonus_maxvie
	vie         = min(vie + member.bonus_maxvie, maxvie)
	maxenergie += member.bonus_maxenergie
	energie     = min(energie + member.bonus_maxenergie, maxenergie)
	# bonus_vitesse supprimé — la vitesse est purement visuelle (px/s)
	# reduction_cout_deplacement géré via get_effective_move_cost()
	# bonus_vision géré via get_crew_vision_bonus() → FogOfWar
	DEBUG.log("Navire [%d] — Bonus appliqués [%s] : dgt+%d tir+%d vie+%d nrj+%d mvt-%.0f%% vis+%d cases" % [
		id, member.nom, member.bonus_dgt_tir, member.bonus_tir,
		member.bonus_maxvie, member.bonus_maxenergie,
		member.reduction_cout_deplacement * 100.0, member.bonus_vision
	])


## Retire les bonus individuels d'un membre du navire (congédiement).
func _remove_crew_bonus(member: CrewMember) -> void:
	dgt_tir    = max(dgt_tir    - member.bonus_dgt_tir,    1)
	tir        = max(tir        - member.bonus_tir,         1)
	maxvie     = max(maxvie     - member.bonus_maxvie,      1)
	vie         = min(vie, maxvie)
	maxenergie = max(maxenergie - member.bonus_maxenergie,  5)
	energie     = min(energie, maxenergie)
	# bonus_vitesse supprimé — la vitesse est purement visuelle (px/s)
	# reduction_cout_deplacement géré via get_effective_move_cost()
	# bonus_vision géré via get_crew_vision_bonus() → FogOfWar
	DEBUG.log("Navire [%d] — Bonus retirés [%s] : dgt-%d tir-%d vie-%d nrj-%d mvt-%.0f%% vis-%d cases" % [
		id, member.nom, member.bonus_dgt_tir, member.bonus_tir,
		member.bonus_maxvie, member.bonus_maxenergie,
		member.reduction_cout_deplacement * 100.0, member.bonus_vision
	])


## Retourne le coût en énergie d'un déplacement d'une case (après réductions équipage + synergies).
func get_effective_move_cost() -> float:
	var reduction := _synergy_move_cost_reduction
	for member in equipage:
		reduction = maxf(reduction, member.reduction_cout_deplacement)
	return maxf(1.0 - reduction, 0.5)  # plancher à 0.5 → roundi() donnera toujours au moins 1


## Calcule et applique toutes les synergies d'équipage.
## Appelée après chaque add/remove pour recalculer l'état courant.
func compute_crew_synergies() -> void:
	# Retire les anciens bonus de synergie avant recalcul
	dgt_tir   = max(dgt_tir   - _synergy_dgt_bonus, 1)
	_synergy_dgt_bonus            = 0
	_synergy_peche_mult           = 1.0
	_synergy_regen_mult           = 1.0
	_synergy_move_cost_reduction  = 0.0
	_synergy_full_crew            = false

	var roles_presents: Array = equipage.map(func(m): return m.role)

	# ── Flotte de guerre : Canonnier + Corsaire + Tireur d'élite → dgt_tir ×1.5 ──
	if _has_all_roles(SYNERGIE_GUERRE, roles_presents):
		var bonus := int(float(dgt_tir) * 0.5)
		_synergy_dgt_bonus += bonus
		dgt_tir += bonus
		DEBUG.log("Navire [%d] — ⚔️ Synergie Flotte de guerre active (+%d dgt)" % [id, bonus])

	# ── Navire de pêche : Pêcheur + Cuisinier → bonus_peche ×2 ──
	if _has_all_roles(SYNERGIE_PECHE, roles_presents):
		_synergy_peche_mult = 2.0
		DEBUG.log("Navire [%d] — 🎣 Synergie Navire de pêche active (pêche ×2)" % id)

	# ── Duo de soins : Médecin + Cuisinier → regen_vie doublée ──
	if _has_all_roles(SYNERGIE_SOINS, roles_presents):
		_synergy_regen_mult = 2.0
		DEBUG.log("Navire [%d] — ⚕️ Synergie Duo de soins active (regen ×2)" % id)

	# ── Vitesse maximale : Navigateur + Éclaireur → -25% coût de déplacement ──
	if _has_all_roles(SYNERGIE_VITESSE, roles_presents):
		_synergy_move_cost_reduction = 0.25
		DEBUG.log("Navire [%d] — 🧭 Synergie Vitesse maximale active (-25%% coût déplacement)" % id)

	# ── Équipage complet : 6 membres → +10% toutes stats ──
	if equipage.size() >= SYNERGIE_FULL_CREW_SIZE:
		_synergy_full_crew = true
		DEBUG.log("Navire [%d] — 👥 Synergie Équipage complet active (+10%% stats)" % id)


## Vérifie que tous les rôles de la liste sont présents dans l'équipage.
func _has_all_roles(required: Array, present: Array) -> bool:
	for r in required:
		if not r in present:
			return false
	return true


## Retourne le bonus total de vision de l'équipage (en cases, pour FogOfWar).
func get_crew_vision_bonus() -> int:
	var bonus := 0
	for member in equipage:
		bonus += member.bonus_vision
	return bonus


## Retourne le bonus total de pêche de l'équipage (hors synergies mult).
func get_crew_fishing_bonus() -> int:
	var bonus := 0
	for member in equipage:
		bonus += member.bonus_peche
	return bonus


## Retourne les dégâts de tir effectifs (bonus équipage complet inclus).
func get_effective_dgt_tir() -> int:
	var base := dgt_tir
	if _synergy_full_crew:
		base = int(float(base) * 1.1)
	return base


## À appeler en fin de tour (par le TurnManager) pour régénération et revenus passifs.
func apply_crew_end_of_turn() -> void:
	# Régénération PV (Médecin, ×2 si synergie Duo de soins)
	for member in equipage:
		if member.regen_vie_par_tour > 0 and vie < maxvie:
			var regen := int(float(member.regen_vie_par_tour) * _synergy_regen_mult)
			vie = min(vie + regen, maxvie)
			DEBUG.log("Navire [%d] — Regen PV +%d → %d/%d" % [id, regen, vie, maxvie])

	# Poissons passifs (Cuisinier)
	var poissons_passifs := 0
	for member in equipage:
		poissons_passifs += member.poissons_par_tour
	if _synergy_full_crew:
		poissons_passifs = int(float(poissons_passifs) * 1.1)
	if poissons_passifs > 0:
		nourriture += poissons_passifs
		DEBUG.log("Navire [%d] — Revenus passifs : +%d poissons" % [id, poissons_passifs])


## Retourne un résumé des synergies actives pour l'UI.
func get_active_synergies() -> Array[String]:
	var result: Array[String] = []
	var roles_presents: Array = equipage.map(func(m): return m.role)
	if _has_all_roles(SYNERGIE_GUERRE,  roles_presents): result.append("⚔️ Flotte de guerre")
	if _has_all_roles(SYNERGIE_PECHE,   roles_presents): result.append("🎣 Navire de pêche")
	if _has_all_roles(SYNERGIE_SOINS,   roles_presents): result.append("⚕️ Duo de soins")
	if _has_all_roles(SYNERGIE_VITESSE, roles_presents): result.append("🧭 Vitesse maximale")
	if _synergy_full_crew:                               result.append("👥 Équipage complet")
	return result

#endregion equipage
