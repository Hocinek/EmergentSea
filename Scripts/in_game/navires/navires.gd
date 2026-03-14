class_name Navires
extends Node2D

signal sig_show_stats
signal sig_navire_died(navire: Navires)
signal sig_navire_damaged(navire: Navires, damage: int)
signal ship_clicked(ship: Navires)
signal ship_destroyed(ship: Navires)
signal sig_show_fishing

# =========================
# PROPRIÉTAIRE ET IDENTITÉ
# =========================
@export var player_owner: Player = null
@export var id: int = 0
var is_player_controlled: bool = false
var is_selected: bool = false
var is_visible_to_human: bool = true
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
@export var tir: int = 10
@export var dgt_tir: int = 2

@onready var ui_layer: CanvasLayer = get_tree().get_first_node_in_group("ui_layer")
@onready var data := get_tree().get_first_node_in_group("shared_entities")
@onready var players_manager = get_tree().get_first_node_in_group("players_manager")

var fog_manager: FogManager = null
var match_context: MatchContext = null
var network_manager: NetworkManager = null

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
# CAMÉRA
# =========================
@onready var camera: Camera2D = get_node_or_null("Camera2D")

#region initialisation
func _init() -> void:
	add_to_group("ships")


func _ready():
	await get_tree().process_frame

	match_context = get_tree().get_first_node_in_group("match_context")
	network_manager = get_tree().get_first_node_in_group("network_manager")
	case_actuelle = Map_utils.monde_vers_case(global_position)

	_setup_camera()
	_setup_input_handling()
	_init_stats_ui()
	drawable = Drawable.new(self)
	add_child(drawable)

	fog_manager = get_tree().get_first_node_in_group("fog_manager")
	if fog_manager:
		DEBUG.log("Navire [%d] - FogManager connecté" % id)

	fog_of_war_ref = get_tree().get_first_node_in_group("fog_of_war")
	if fog_of_war_ref:
		DEBUG.log("Navire [%d] - FogOfWar connecté pour visibilité" % id)

	var owner_name = player_owner.player_name if player_owner else "AUCUN"
	var control_type = "CONTRÔLÉ" if is_player_controlled else "IA/ENNEMI"
	DEBUG.log("Navire [%s] initialisé - Propriétaire: %s - Type: %s - Position: %s" % [
		id, owner_name, control_type, case_actuelle
	])

func _init_stats_ui():
	if not ui_layer:
		DEBUG.log("ui_layer est null, impossible de créer l'UI des stats!", DEBUG.ERROR)
		return
	if stats_panel == null:
		stats_panel = UI_stats_navire.new(self)
	if fish_feedback_label == null:
		fish_feedback_label = UI_fish_navires.new(self)
	DEBUG.log("UI Stats créée pour navire [%d]" % id)
#endregion initialisation

#region camera
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
func set_owner_player(player: Player) -> void:
	if player_owner != null and player_owner.has_method("remove_navire"):
		player_owner.remove_navire(self)
	player_owner = player
	if player != null and player.has_method("add_navire"):
		player.add_navire(self)
	_setup_input_handling()

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

func is_owned_by(player: Player) -> bool:
	return player_owner == player

func is_enemy_of(other_navire: Navires) -> bool:
	if player_owner == null or other_navire.player_owner == null:
		return false
	return player_owner != other_navire.player_owner
#endregion gestion proprietaire

#region gestion selection
func set_selected(selected: bool) -> void:
	is_selected = selected
	queue_redraw()
	if selected and _is_local_human_owner():
		_setup_camera()
		if(stats_panel):
			stats_panel.show_ally()
	else:
		stats_panel.hide_all_stats()
	DEBUG.log("Navire %d %s" % [id, "SÉLECTIONNÉ" if selected else "désélectionné"])
#endregion gestion selection

#region gestion etat navire
func is_alive() -> bool:
	return vie > 0

func take_damage(damage: int) -> void:
	if not is_alive():
		return
	vie = max(vie - damage, 0)
	emit_signal("sig_navire_damaged", self, damage)
	stats_panel.show_stats()
	if vie <= 0:
		die()

func die() -> void:
	DEBUG.log("Navire [%d] en train de mourir..." % id)
	emit_signal("ship_destroyed", self)
	emit_signal("sig_navire_died", self)
	if is_selected:
		set_selected(false)
	stats_panel.hide_all_stats()
	if fish_feedback_label and is_instance_valid(fish_feedback_label):
		fish_feedback_label.hide()
	if player_owner != null and player_owner.has_method("remove_navire"):
		player_owner.remove_navire(self)
	DEBUG.log("Navire [%d] détruit" % id)
	queue_free()

func heal(amount: int) -> void:
	if not is_alive():
		return
	vie = min(vie + amount, maxvie)
	if is_selected:
		stats_panel.show_ally()

func reset_energie() -> void:
	energie = maxenergie
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
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_global_mouse_position()
		var distance = global_position.distance_to(mouse_pos)
		if distance <= interaction_radius:
			emit_signal("ship_clicked", self)
			get_viewport().set_input_as_handled()
			return
	if not is_selected:
		return
	if Input.is_action_just_pressed("input_toggle_stats"):
		if(self.is_selected):
			emit_signal("sig_show_stats")
	if event.is_action_pressed("input_fish"):
		try_start_fishing()
		return
	if event is InputEventMouseButton and event.pressed:
		var mouse_pos := get_global_mouse_position()
		if event.button_index == MOUSE_BUTTON_LEFT:
			var clicked_ship = get_ship_at_position(mouse_pos)
			if clicked_ship:
				return
			if energie > 0 and not is_moving and not is_fishing:
				var target_case = Map_utils.monde_vers_case(mouse_pos)
				if Map_utils.is_case_navigable(target_case):
					path = Pathfinder.calculer_chemin(case_actuelle, target_case)
					if not path.is_empty():
						DEBUG.log("Chemin: "+ str(path))
						is_moving = true
						target_position = mouse_pos
						show_arrow = true
						queue_redraw()
						get_viewport().set_input_as_handled()
					else:
						DEBUG.log("Chemin vide !")
				else:
					DEBUG.log("Case cible NON navigable !")
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			var target_case = Map_utils.monde_vers_case(mouse_pos)
			attempt_shoot(target_case)
#endregion gestion input

#region gestion combat
func attempt_shoot(target_case: Vector2i) -> void:
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
	if target == null or not target.is_alive():
		return
	DEBUG.log("Tir sur navire [%d]" % target.id)

	# En mode multi : synchroniser les dégâts via l'hôte
	if match_context != null and match_context.mode == MatchContext.MatchMode.MULTI:
		if network_manager != null and network_manager.is_host():
			# L'hôte applique et broadcaste directement
			_rpc_apply_damage.rpc(target.id, dgt_tir)
		else:
			# Le client envoie la demande à l'hôte
			_rpc_sync_damage.rpc_id(1, target.id, dgt_tir)
	else:
		# Mode solo : application directe comme avant
		target.take_damage(dgt_tir)
#endregion gestion combat

#region sync réseau
# Synchronise la position d'un navire sur tous les autres peers
@rpc("any_peer", "call_remote", "reliable")
func _rpc_sync_position(case_x: int, case_y: int, world_x: float, world_y: float) -> void:
	# Ne pas appliquer sur le navire local (déjà à jour)
	if _is_local_human_owner():
		return
	case_actuelle = Vector2i(case_x, case_y)
	global_position = Vector2(world_x, world_y)
	_update_visibility_in_fog()

# Le client envoie une demande de dégât à l'hôte
@rpc("any_peer", "call_remote", "reliable")
func _rpc_sync_damage(target_ship_id: int, damage: int) -> void:
	if network_manager == null:
		network_manager = get_tree().get_first_node_in_group("network_manager")
	if network_manager == null or not network_manager.is_host():
		return
	# L'hôte valide et broadcaste
	_rpc_apply_damage.rpc(target_ship_id, damage)

# Appliqué sur tous les peers : infliger les dégâts au navire cible
@rpc("authority", "call_local", "reliable")
func _rpc_apply_damage(target_ship_id: int, damage: int) -> void:
	var all_ships = get_tree().get_nodes_in_group("ships")
	for ship in all_ships:
		if ship is Navires and ship.id == target_ship_id:
			ship.take_damage(damage)
			return
#endregion sync réseau

#region utils
func is_in_range(target_case: Vector2i) -> bool:
	var chemin := Pathfinder.calculer_chemin(case_actuelle, target_case)
	return chemin.size() <= tir

func get_ships_at_position(target_case: Vector2i) -> Array[Navires]:
	var ships: Array[Navires] = []
	if data and data.has_method("getNavireByPosition"):
		var raw_ships = data.getNavireByPosition(target_case)
		for ship in raw_ships:
			if ship is Navires and is_instance_valid(ship) and ship.is_alive():
				ships.append(ship)
	return ships

func get_ship_at_position(pos: Vector2) -> Navires:
	var all_ships = get_tree().get_nodes_in_group("ships")
	for ship in all_ships:
		if ship is Navires and ship != self:
			var distance = pos.distance_to(ship.global_position)
			if distance <= ship.interaction_radius:
				return ship
	return null

func getPosition() -> Vector2i:
	return case_actuelle
#endregion utils

#region process
func _process(delta):
	if is_selected or show_arrow:
		queue_redraw()
	_update_fishing(delta)
	if is_moving and not path.is_empty():
		_process_movement(delta)
	if player_owner and not _is_local_human_owner():
		_update_visibility_in_fog()

func _process_movement(delta: float) -> void:
	if path.is_empty():
		DEBUG.log("Navire [%d] - Chemin vide, arrêt du mouvement" % id)
		is_moving = false
		show_arrow = false
		queue_redraw()
		return

	var next_case = path[0]
	var next_pos: Vector2 = Map_utils.case_vers_monde(next_case)
	var direction := next_pos - global_position
	var distance = direction.length()

	if distance < 10:
		var old_case = case_actuelle
		global_position = next_pos
		path.remove_at(0)
		case_actuelle = next_case
		energie = max(energie - 1, 0)

		DEBUG.log("Navire [%d] arrivé à %s - Cases restantes: %d" % [id, case_actuelle, path.size()])
		DEBUG.log("old_case: %s, case_actuelle: %s, changé: %s" % [old_case, case_actuelle, old_case != case_actuelle])
		if player_owner:
			DEBUG.log("player_owner existe: %s, is_human: %s, is_local: %s" % [player_owner.player_name, player_owner.is_human, player_owner.is_local])
		else:
			DEBUG.log("player_owner est NULL !")

		if old_case != case_actuelle:
			if _is_local_human_owner():
				DEBUG.log("✓ CONDITIONS OK - Appel de _update_fog_of_war()")
				_update_fog_of_war()
				# Synchroniser la nouvelle position vers tous les autres peers
				_rpc_sync_position.rpc(case_actuelle.x, case_actuelle.y, global_position.x, global_position.y)
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
	else:
		global_position += direction.normalized() * vitesse * delta
#endregion process

#region UI
func hide_all_ships_stats():
	var all_ships = get_tree().get_nodes_in_group("ships")
	for ship in all_ships:
		if ship is Navires:
			ship.hide_all_stats()

func _update_fog_of_war() -> void:
	DEBUG.log("[NAVIRE %d] _update_fog_of_war() APPELÉE !" % id)
	if not _is_local_human_owner():
		DEBUG.log("[NAVIRE %d] SKIP - pas de propriétaire local humain" % id)
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

func _update_visibility_in_fog() -> void:
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
	if not show_arrow or not is_selected:
		return
	var local_target = target_position - global_position
	drawable.arrow(local_target, scale_factor)
#endregion UI

#region peche
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
		return
	if not Map_utils.is_on_water(global_position):
		return
	sig_show_fishing.emit()
	is_fishing = true
	fish_timer = fish_duration
	energie = max(energie - fish_energy_cost, 0)
	stats_panel.show_ally()

func finish_fishing() -> void:
	is_fishing = false
	var gain := randi_range(fish_yield_min, fish_yield_max)
	if nrbequipage >= 6:
		gain += 1
	nourriture += gain
	if fish_feedback_label:
		fish_feedback_label.finished_fishing(gain)
		sig_show_stats.emit()
		DEBUG.log("fishing finished")
#endregion peche
