extends Node
class_name MultiplayerGameManager

signal ship_selected(ship)
signal ship_deselected()
signal port_selected(port)
signal port_deselected()

var navire_scene := preload("res://Scenes/in_game/ENTITIES/Navires.tscn")

var players_manager = null
var turn_manager = null
var match_context: MatchContext = null
var network_manager: NetworkManager = null
var bootstrap: MultiplayerMatchBootstrap = null
var command_router: CommandRouter = null
var data = null

var fog_of_war: FogOfWar = null
var fog_manager: FogManager = null
var hex_menu: HexContextMenu = null
var fish_manager: FishManager = null

# UI d'inspection de case
var case_info_ui: UI_case_info = null

# UI d'aide — bouton "?" et panneau des commandes
var aide_ui: UI_aide = null

var player1 = null
var player2 = null

var selected_ship = null
var selected_port = null

var host_match_initialized: bool = false

# Proxy minimal exposant spawn_navire_at pour la compatibilité avec port.gd
# (port.gd appelle game_manager.ship_manager.spawn_navire_at(...))
var ship_manager: _MultiShipManagerProxy = null


class _MultiShipManagerProxy:
	var _gm: WeakRef

	func _init(gm) -> void:
		_gm = weakref(gm)

	func spawn_navire_at(player, case_pos: Vector2i, is_player_controlled: bool = false, ship_id: int = 0):
		var gm = _gm.get_ref()
		if gm == null:
			return null
		return gm.spawn_navire_at(player, case_pos, is_player_controlled, ship_id)


func _enter_tree() -> void:
	name = "MultiplayerGameManager"
	add_to_group("game_manager")

	var map_manager = get_tree().get_first_node_in_group("Map_manager")
	if map_manager and map_manager.has_signal("map_generated"):
		if not map_manager.map_generated.is_connected(_on_map_generated):
			map_manager.map_generated.connect(_on_map_generated)


func _ready() -> void:
	ship_manager = _MultiShipManagerProxy.new(self)
	_refresh_refs()
	_setup_fog_of_war()
	_setup_fish_manager()
	_setup_hex_menu()
	_setup_case_info_ui()
	_setup_aide_ui()
	await _setup_game_over_ui()

func _setup_game_over_ui() -> void:
	var ui_game_over := UI_game_over.new()
	ui_game_over.name = "UI_game_over"
	add_child(ui_game_over)
	await ui_game_over.init()

	if turn_manager == null:
		turn_manager = get_tree().get_first_node_in_group("turn_manager")

	if turn_manager:
		turn_manager.game_over_panel = ui_game_over
	else:
		push_error("[MULTI GM] Impossible d'assigner UI_game_over : TurnManager null")

func _refresh_refs() -> void:
	players_manager = get_tree().get_first_node_in_group("players_manager")
	turn_manager = get_tree().get_first_node_in_group("turn_manager")
	match_context = get_tree().get_first_node_in_group("match_context")
	network_manager = get_tree().get_first_node_in_group("network_manager")
	bootstrap = get_tree().get_first_node_in_group("multiplayer_bootstrap")
	command_router = get_tree().get_first_node_in_group("command_router")
	data = get_tree().get_first_node_in_group("shared_entities")
	if fish_manager == null:
		fish_manager = get_tree().get_first_node_in_group("fish_manager")


func _setup_fog_of_war() -> void:
	fog_of_war = get_tree().get_first_node_in_group("fog_of_war")
	fog_manager = get_tree().get_first_node_in_group("fog_manager")

	if not fog_of_war:
		fog_of_war = FogOfWar.new()
		fog_of_war.name = "FogOfWar"
		add_child(fog_of_war)

	if not fog_manager:
		fog_manager = FogManager.new()
		fog_manager.name = "FogManager"
		add_child(fog_manager)


func _setup_hex_menu() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	canvas.name = "HexMenuLayer"
	add_child(canvas)
	hex_menu = HexContextMenu.new()
	hex_menu.name = "HexContextMenu"
	hex_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(hex_menu)
	hex_menu.action_selected.connect(_on_hex_menu_action)


func _setup_fish_manager() -> void:
	fish_manager = get_tree().get_first_node_in_group("fish_manager")
	if not fish_manager:
		DEBUG.log("[MULTI GM] Création dynamique de FishManager...")
		fish_manager = FishManager.new()
		fish_manager.name = "FishManager"
		add_child(fish_manager)
	else:
		DEBUG.log("[MULTI GM] FishManager trouvé dans la scène")


func _setup_case_info_ui() -> void:
	case_info_ui = UI_case_info.new()
	case_info_ui.name = "UI_case_info"
	add_child(case_info_ui)
	case_info_ui.setup()
	DEBUG.log("[MULTI GM] UI_case_info créé")


func _setup_aide_ui() -> void:
	aide_ui = UI_aide.new()
	aide_ui.name = "UI_aide"
	add_child(aide_ui)
	await aide_ui.setup()
	DEBUG.log("[MULTI GM] UI_aide créé")


func _on_map_generated() -> void:
	_refresh_refs()
	if bootstrap == null or network_manager == null:
		push_error("[MULTI GM] Bootstrap ou NetworkManager introuvable")
		return
	if network_manager.is_host():
		await get_tree().create_timer(1.5).timeout
		bootstrap.configure_host_lobby()
		await _initialize_host_match()
	else:
		_ensure_client_match_context()


func _ensure_client_match_context() -> void:
	if network_manager == null:
		network_manager = get_tree().get_first_node_in_group("network_manager")
	if match_context == null:
		match_context = get_tree().get_first_node_in_group("match_context")

	if network_manager != null and network_manager.local_player_id != -1:
		match_context.configure_multi(network_manager.local_player_id)
	else:
		push_warning("[MULTI GM] local_player_id pas encore assigné, on patiente...")
		await get_tree().create_timer(0.2).timeout
		_ensure_client_match_context()


func _initialize_host_match() -> void:
	if host_match_initialized:
		return

	_refresh_refs()

	if players_manager == null or turn_manager == null:
		push_error("[MULTI GM] PlayersManager ou TurnManager introuvable")
		return

	var existing_p1 = players_manager.get_player_by_id(1)
	var existing_p2 = players_manager.get_player_by_id(2)

	if existing_p1 != null or existing_p2 != null:
		host_match_initialized = true
		return

	player1 = players_manager.create_player(1, "Joueur 1", true)
	player2 = players_manager.create_player(2, "Joueur 2", true)

	if player1 == null or player2 == null:
		push_error("[MULTI GM] Échec de création des joueurs")
		return

# Assigner un port de départ à chaque joueur
	var all_ports = get_tree().get_nodes_in_group("ports")
	if all_ports.size() > 1:
		all_ports[0].set_as_owner(player1)
		all_ports[0].current_hp = all_ports[0].max_hp
		all_ports[1].set_as_owner(player2)
		all_ports[1].current_hp = all_ports[1].max_hp

	for port in all_ports:
		if port.has_signal("port_captured"):
			port.port_captured.connect(_on_port_captured)

	# Initialiser les stocks de poissons via le FishManager
	if fish_manager:
		fish_manager.initialize_fish_tiles()

	var ship1 = spawn_navire_random(player1, true, 1)
	var ship2 = spawn_navire_random(player2, false, 101)

	if ship1 == null or ship2 == null:
		push_error("[MULTI GM] Échec du spawn des navires")
		return

	players_manager.set_current_player(player1)
	turn_manager.start_game([player1, player2])

	host_match_initialized = true

	await get_tree().process_frame
	await get_tree().process_frame

	if fog_manager and fog_manager.has_method("update_fog"):
		fog_manager.update_fog()

	select_ship(ship1)
	_sync_initial_state_to_clients()


func _sync_initial_state_to_clients() -> void:
	var players_data: Array = []
	for p in players_manager.get_all_players():
		players_data.append({
			"player_id": p.player_id,
			"player_name": p.player_name,
			"is_human": p.is_human
		})
	
	#Assignation des ports
	var ports_data: Array = []
	for port in get_tree().get_nodes_in_group("ports"):
		if port is Ports:
			ports_data.append({
				"port_id": port.id,
				"player_id": port.player_owner.player_id if port.player_owner else -1,
				"pos_x": port.global_position.x,
				"pos_y": port.global_position.y
			})
	
	var ships_data: Array = []
	for ship in get_tree().get_nodes_in_group("ships"):
		if ship is Navires and ship.player_owner != null:
			ships_data.append({
				"ship_id": ship.id,
				"player_id": ship.player_owner.player_id,
				"pos_x": ship.global_position.x,
				"pos_y": ship.global_position.y
			})

	var turn_order: Array = []
	for p in players_manager.get_all_players():
		turn_order.append(p.player_id)

	_rpc_receive_initial_state.rpc(players_data, ships_data, turn_order, ports_data)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_receive_initial_state(players_data: Array, ships_data: Array, turn_order: Array, ports_data: Array) -> void:
	_refresh_refs()

	if players_manager == null or turn_manager == null or match_context == null:
		push_error("[MULTI GM CLIENT] Refs introuvables à la réception de l'état initial")
		return

	if network_manager != null and network_manager.local_player_id != -1:
		match_context.configure_multi(network_manager.local_player_id)
	else:
		push_error("[MULTI GM CLIENT] local_player_id toujours -1 à la réception de l'état initial !")
		return

	var created_players: Array = []
	for pd in players_data:
		var p = players_manager.create_player(pd["player_id"], pd["player_name"], pd["is_human"])
		if p != null:
			created_players.append(p)

	if created_players.is_empty():
		push_error("[MULTI GM CLIENT] Aucun joueur créé")
		return

	var local_ship = null
	for sd in ships_data:
		var owner_player = players_manager.get_player_by_id(sd["player_id"])
		if owner_player == null:
			push_error("[MULTI GM CLIENT] Joueur introuvable pour player_id=%d" % sd["player_id"])
			continue

		var pos = Vector2(sd["pos_x"], sd["pos_y"])
		var is_local_controlled = match_context.is_local_player(sd["player_id"])
		var ship = spawn_navire(owner_player, pos, is_local_controlled, sd["ship_id"])

		if ship != null and is_local_controlled:
			local_ship = ship

	var ordered_players: Array = []
	for pid in turn_order:
		var p = players_manager.get_player_by_id(pid)
		if p != null:
			ordered_players.append(p)

	if not ordered_players.is_empty():
		players_manager.set_current_player(ordered_players[0])
		turn_manager.start_game(ordered_players)

	await get_tree().process_frame
	await get_tree().process_frame

	if fog_manager and fog_manager.has_method("update_fog"):
		fog_manager.update_fog()

	var all_ports = get_tree().get_nodes_in_group("ports")
	for port in all_ports:
		if port.has_signal("port_captured"):
			if not port.port_captured.is_connected(_on_port_captured):
				port.port_captured.connect(_on_port_captured)

	for pd in ports_data:
		for port in get_tree().get_nodes_in_group("ports"):
			if port is Ports and port.global_position.x == pd["pos_x"] and port.global_position.y == pd["pos_y"]:
				if pd["player_id"] != -1:
					var owner = players_manager.get_player_by_id(pd["player_id"])
					if owner:
						port.set_as_owner(owner)
						port.current_hp = port.max_hp
					
	if local_ship != null:
		select_ship(local_ship)


func spawn_navire(player, position: Vector2, is_player_controlled: bool = false, ship_id: int = 0):
	if player == null:
		push_error("[MULTI GM] Impossible de créer un navire sans joueur propriétaire")
		return null

	var navire = navire_scene.instantiate()

	navire.id = ship_id
	navire.global_position = position
	navire.is_player_controlled = is_player_controlled

	add_child(navire)
	navire.set_owner_player(player)

	if not navire.is_in_group("ships"):
		navire.add_to_group("ships")

	if navire.has_signal("ship_clicked"):
		navire.ship_clicked.connect(_on_ship_clicked)

	if navire.has_signal("ship_destroyed"):
		navire.ship_destroyed.connect(_on_ship_destroyed)

	if navire.has_signal("sig_open_hex_menu"):
		navire.sig_open_hex_menu.connect(_on_open_hex_menu)

	if navire.has_signal("sig_inspect_case"):
		navire.sig_inspect_case.connect(_on_inspect_case)

	if navire.has_signal("sig_inspect_fish"):
		navire.sig_inspect_fish.connect(_inspect_fish_on_case)

	if data == null:
		data = get_tree().get_first_node_in_group("shared_entities")

	if data and data.has_method("addNavireToData"):
		data.addNavireToData(navire)

	# Connecter le nouveau navire au FogManager pour que le fog se mette à jour
	if fog_manager and fog_manager.has_method("_connect_to_ship_signals"):
		fog_manager._connect_to_ship_signals()

	return navire


func spawn_navire_random(player, is_player_controlled: bool = false, ship_id: int = 0):
	var pos = Map_utils.get_random_ocean_position()
	return spawn_navire(player, pos, is_player_controlled, ship_id)


func spawn_navire_at(player, case_pos: Vector2i, is_player_controlled: bool = false, ship_id: int = 0):
	var pos: Vector2 = Map_utils.case_vers_monde(case_pos)
	# Générer un ID unique si non fourni
	var final_id := ship_id if ship_id != 0 else (Time.get_ticks_msec() % 100000 + randi() % 1000)
	var navire = spawn_navire(player, pos, is_player_controlled, final_id)
	# Synchroniser le nouveau navire chez tous les clients
	if navire and multiplayer.has_multiplayer_peer() and network_manager and network_manager.is_host():
		_rpc_spawn_navire.rpc(
			player.player_id,
			pos.x, pos.y,
			is_player_controlled,
			final_id
		)
	return navire


@rpc("any_peer", "call_remote", "reliable")
func _rpc_spawn_navire(player_id: int, pos_x: float, pos_y: float, is_player_controlled: bool, ship_id: int) -> void:
	_refresh_refs()
	if players_manager == null:
		push_error("[MULTI GM] _rpc_spawn_navire : PlayersManager introuvable")
		return
	var owner_player = players_manager.get_player_by_id(player_id)
	if owner_player == null:
		push_error("[MULTI GM] _rpc_spawn_navire : joueur %d introuvable" % player_id)
		return
	var local_controlled = match_context != null and match_context.is_local_player(player_id)
	var pos := Vector2(pos_x, pos_y)
	var navire = spawn_navire(owner_player, pos, local_controlled, ship_id)
	if navire == null:
		push_error("[MULTI GM] _rpc_spawn_navire : spawn échoué pour joueur %d" % player_id)
		return
	# Mettre à jour le fog pour le joueur local
	if fog_manager:
		fog_manager.update_fog()
	DEBUG.log("[MULTI GM] Navire [%d] reçu via RPC pour joueur %d" % [ship_id, player_id])


func select_ship(ship) -> void:
	if selected_ship == ship:
		return

	if selected_ship and selected_ship.has_method("set_selected"):
		selected_ship.set_selected(false)

	selected_ship = ship

	if selected_ship and selected_ship.has_method("set_selected"):
		selected_ship.set_selected(true)
		ship_selected.emit(ship)

		if fog_manager and fog_manager.has_method("update_fog"):
			fog_manager.update_fog()


func deselect_ship() -> void:
	if selected_ship and selected_ship.has_method("set_selected"):
		selected_ship.set_selected(false)

	selected_ship = null
	ship_deselected.emit()


func get_selected_ship():
	return selected_ship


func _on_ship_clicked(ship) -> void:
	if ship == null or ship.player_owner == null:
		return

	if ship.player_owner.is_local:
		select_ship(ship)


func _on_ship_destroyed(ship) -> void:
	if selected_ship == ship:
		deselect_ship()


func _on_open_hex_menu(navire: Navires, screen_pos: Vector2) -> void:
	if hex_menu:
		hex_menu.show_for(navire, screen_pos)


func _on_hex_menu_action(action: String, navire: Navires) -> void:
	if not navire or not is_instance_valid(navire):
		return
	match action:
		"move":
			select_ship(navire)
			navire.set_input_mode(Navires.InputMode.MOVE)
		"attack":
			select_ship(navire)
			navire.set_input_mode(Navires.InputMode.ATTACK)
		"inspect":
			select_ship(navire)
			navire.set_input_mode(Navires.InputMode.INSPECT)
		"stats":
			navire.toggle_stats()
		"switch":
			var local_player = players_manager.get_local_player()
			if local_player:
				var ships = local_player.get_navires()
				if ships.size() > 1:
					var idx = ships.find(navire)
					select_ship(ships[(idx + 1) % ships.size()])
		"fish":
			navire.try_start_fishing()


func select_port(port) -> void:
	selected_port = port
	port_selected.emit(port)


func deselect_port() -> void:
	selected_port = null
	port_deselected.emit()
	
	
# ===============================
# Gestion Port
# ===============================
	
## Appelé par un navire local pour synchroniser sa position chez les autres peers.
func sync_ship_position(ship_id: int, case_x: int, case_y: int, world_x: float, world_y: float, rotation_angle: float) -> void:
	_rpc_sync_ship_position.rpc(ship_id, case_x, case_y, world_x, world_y, rotation_angle)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_sync_ship_position(ship_id: int, case_x: int, case_y: int, world_x: float, world_y: float, rotation_angle: float) -> void:
	for ship in get_tree().get_nodes_in_group("ships"):
		if ship is Navires and ship.id == ship_id:
			ship.case_actuelle = Vector2i(case_x, case_y)
			ship.global_position = Vector2(world_x, world_y)
			ship.target_rotation_angle = rotation_angle
			ship._set_visual_rotation(rotation_angle)
			ship._update_visibility_in_fog()
			return


## Appelé par un navire attaquant pour synchroniser les dégâts en multi.
## L'hôte applique localement + broadcaste aux clients.
## Le client envoie la demande à l'hôte qui se charge de tout.
func apply_damage_networked(target_ship_id: int, damage: int) -> void:
	if network_manager == null:
		network_manager = get_tree().get_first_node_in_group("network_manager")
	if network_manager != null and network_manager.is_host():
		# Hôte : applique localement d'abord, puis broadcaste aux clients seulement
		_apply_damage_local(target_ship_id, damage)
		_rpc_apply_damage.rpc(target_ship_id, damage)
	else:
		# Client : envoie la demande à l'hôte
		_rpc_request_damage.rpc(target_ship_id, damage)


# Le client demande à l'hôte d'appliquer les dégâts.
@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_damage(target_ship_id: int, damage: int) -> void:
	if network_manager == null:
		network_manager = get_tree().get_first_node_in_group("network_manager")
	if network_manager == null or not network_manager.is_host():
		return
	# L'hôte applique localement + envoie aux clients (call_remote = pas de boucle)
	_apply_damage_local(target_ship_id, damage)
	_rpc_apply_damage.rpc(target_ship_id, damage)


# L'hôte broadcaste les dégâts aux clients uniquement (call_remote pour eviter double application)
@rpc("any_peer", "call_remote", "reliable")
func _rpc_apply_damage(target_ship_id: int, damage: int) -> void:
	_apply_damage_local(target_ship_id, damage)


# Application locale des degats (utilise par l'hote ET les clients via RPC)
func _apply_damage_local(target_ship_id: int, damage: int) -> void:
	for ship in get_tree().get_nodes_in_group("ships"):
		if ship is Navires and ship.id == target_ship_id:
			ship.take_damage(damage)
			return
	push_error("[MULTI GM] _apply_damage_local : navire %d introuvable" % target_ship_id)


# ── DÉGÂTS SUR PORT ──────────────────────────────────────────────────────────

## Point d'entrée réseau pour les dégâts sur un port.
## Même pattern que apply_damage_networked pour les navires.
func apply_port_damage_networked(port_id: int, damage: int, attacker_player_id: int) -> void:
	if network_manager == null:
		network_manager = get_tree().get_first_node_in_group("network_manager")
	if network_manager != null and network_manager.is_host():
		# Hôte : applique localement d'abord, puis broadcaste aux clients seulement
		_apply_port_damage_local(port_id, damage, attacker_player_id)
		_rpc_apply_port_damage.rpc(port_id, damage, attacker_player_id)
	else:
		# Client : envoie la demande à l'hôte
		_rpc_request_port_damage.rpc(port_id, damage, attacker_player_id)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_port_damage(port_id: int, damage: int, attacker_player_id: int) -> void:
	if network_manager == null:
		network_manager = get_tree().get_first_node_in_group("network_manager")
	if network_manager == null or not network_manager.is_host():
		return
	# L'hôte applique localement + envoie aux clients (call_remote = pas de boucle)
	_apply_port_damage_local(port_id, damage, attacker_player_id)
	_rpc_apply_port_damage.rpc(port_id, damage, attacker_player_id)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_apply_port_damage(port_id: int, damage: int, attacker_player_id: int) -> void:
	_apply_port_damage_local(port_id, damage, attacker_player_id)


func _apply_port_damage_local(port_id: int, damage: int, attacker_player_id: int) -> void:
	_refresh_refs()
	var target_port: Ports = null
	for port in get_tree().get_nodes_in_group("ports"):
		if port is Ports and port.id == port_id:
			target_port = port
			break
	if target_port == null:
		push_error("[MULTI GM] _apply_port_damage_local : port %d introuvable" % port_id)
		return
	var attacker: Player = players_manager.get_player_by_id(attacker_player_id) if players_manager else null
	target_port.take_damage(damage, attacker)


func _on_port_captured(port: Ports, new_owner: Player, old_owner: Player) -> void:
	DEBUG.log("Port [%d] capturé : %s -> %s" % [
		port.id,
		old_owner.player_name if old_owner else "NEUTRE",
		new_owner.player_name if new_owner else "NEUTRE"
	])
	# Synchroniser la capture chez tous les peers
	if network_manager == null:
		network_manager = get_tree().get_first_node_in_group("network_manager")
	var new_owner_id := new_owner.player_id if new_owner else -1
	_rpc_sync_port_capture.rpc(port.id, new_owner_id)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_sync_port_capture(port_id: int, new_owner_id: int) -> void:
	_refresh_refs()
	var target_port: Ports = null
	for port in get_tree().get_nodes_in_group("ports"):
		if port is Ports and port.id == port_id:
			target_port = port
			break
	if target_port == null:
		push_error("[MULTI GM] _rpc_sync_port_capture : port %d introuvable" % port_id)
		return
	if new_owner_id == -1:
		target_port.set_as_owner(null)
	else:
		var owner = players_manager.get_player_by_id(new_owner_id) if players_manager else null
		if owner == null:
			push_error("[MULTI GM] _rpc_sync_port_capture : joueur %d introuvable" % new_owner_id)
			return
		target_port.set_as_owner(owner)
	if fog_manager:
		fog_manager.update_fog()


# ===============================
# INPUT HANDLING
# ===============================

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_focus_next") or (event is InputEventKey and event.pressed and event.keycode == KEY_TAB and not event.shift_pressed):
		var local_player = players_manager.get_local_player() if players_manager else null
		if local_player and match_context and match_context.is_local_turn():
			var ships = local_player.get_navires()
			if ships.size() > 1:
				var cur = get_selected_ship()
				var idx = ships.find(cur) if cur else -1
				select_ship(ships[(idx + 1) % ships.size()])
		get_viewport().set_input_as_handled()

	elif event is InputEventKey and event.pressed and event.keycode == KEY_TAB and event.shift_pressed:
		var local_player = players_manager.get_local_player() if players_manager else null
		if local_player and match_context and match_context.is_local_turn():
			var ships = local_player.get_navires()
			if ships.size() > 1:
				var cur = get_selected_ship()
				var idx = ships.find(cur) if cur else 0
				select_ship(ships[(idx - 1 + ships.size()) % ships.size()])
		get_viewport().set_input_as_handled()

	elif event is InputEventKey and event.pressed:
		var local_player = players_manager.get_local_player() if players_manager else null
		if local_player and match_context and match_context.is_local_turn():
			var ships = local_player.get_navires()
			match event.keycode:
				KEY_1:
					if ships.size() > 0: select_ship(ships[0])
					get_viewport().set_input_as_handled()
				KEY_2:
					if ships.size() > 1: select_ship(ships[1])
					get_viewport().set_input_as_handled()
				KEY_3:
					if ships.size() > 2: select_ship(ships[2])
					get_viewport().set_input_as_handled()


# ===============================
# INSPECTION DE CASE
# ===============================

## Action : lorsqu'une case est inspectée
func _on_inspect_case(case_pos: Vector2i) -> void:
	DEBUG.log("[MULTI GM] Inspection de la case %s" % str(case_pos))

	var local_player = players_manager.get_local_player() if players_manager else null
	if not local_player:
		DEBUG.log("[INSPECT] Joueur local introuvable, inspection ignorée")
		return

	# Si le fog n'est pas initialisé, on inspecte quand même (pas de restriction brouillard)
	var fog_state: int = FogOfWar.FogState.VISIBLE
	if fog_of_war:
		fog_state = fog_of_war.get_fog_state(case_pos)
		DEBUG.log("[INSPECT] Fog state pour %s : %d" % [str(case_pos), fog_state])
		if fog_state == FogOfWar.FogState.UNEXPLORED:
			DEBUG.log("[INSPECT] Case %s jamais vue, inspection ignorée" % str(case_pos))
			return

	# Navires sur la case
	var ships_on_case: Array = []
	if data and data.has_method("getNavireByPosition"):
		ships_on_case = data.getNavireByPosition(case_pos)
	if not ships_on_case.is_empty():
		var target: Navires = ships_on_case[0]
		if target and is_instance_valid(target) and target.stats_panel:
			target.stats_panel.show_stats()

	_inspect_tile_info(case_pos, fog_state)


func _inspect_tile_info(case_pos: Vector2i, fog_state: int) -> void:
	if not case_info_ui:
		DEBUG.log("[INSPECT] case_info_ui est null !", DEBUG.ERROR)
		return
	var map_manager = get_tree().get_first_node_in_group("Map_manager")
	if not map_manager:
		DEBUG.log("[INSPECT] Map_manager introuvable !", DEBUG.ERROR)
		return

	var axial: Vector2 = map_manager.grid.offset_to_axial(case_pos.x, case_pos.y)
	var q := int(axial.x)
	var r := int(axial.y)
	var cell: HexCell = map_manager.grid.get_cell(q, r, -q - r)

	if not cell:
		DEBUG.log("[INSPECT] Cellule introuvable pour %s" % str(case_pos))
		return

	var tile_type: String = cell.getTypeTerrain()
	var is_visible: bool = (fog_state == FogOfWar.FogState.VISIBLE)

	var local_player = players_manager.get_local_player() if players_manager else null
	var fish_count: int = -1
	if tile_type == "fish" and fish_manager and local_player:
		var info: Dictionary = fish_manager.get_stock_for_player(local_player, case_pos, fog_of_war)
		if info["known"]:
			fish_count = info["stock"]

	DEBUG.log("[INSPECT] Case %s → type='%s' visible=%s" % [str(case_pos), tile_type, str(is_visible)])
	case_info_ui.show_tile_info(tile_type, case_pos, is_visible, fish_count)

	# Si c'est un port, afficher ses stats en mode inspection
	if tile_type == "port":
		for port in get_tree().get_nodes_in_group("ports"):
			if port is Ports and port.case_actuelle == case_pos:
				if port.has_method("show_stats_inspect") or (port.get_node_or_null("UI_stats_port") != null):
					for child in port.get_children():
						if child is UI_stats_port:
							child.show_stats_inspect()
				break


## Action : lorsqu'une case de pêche est inspectée
func _inspect_fish_on_case(case_pos: Vector2i) -> void:
	var local_player = players_manager.get_local_player() if players_manager else null
	if not case_info_ui or not fish_manager or not fog_of_war or not local_player:
		return

	var info: Dictionary = fish_manager.get_stock_for_player(local_player, case_pos, fog_of_war)

	if not info["known"]:
		return

	var wpos: Vector2 = Map_utils.case_vers_monde(case_pos)
	var spos: Vector2 = _world_to_screen(wpos)

	case_info_ui.show_fish_info(info["stock"], spos, info["is_live"])

	if info["is_live"]:
		DEBUG.log("[INSPECT] Case %s → %d 🐟 (vue directe)" % [str(case_pos), info["stock"]])
	else:
		DEBUG.log("[INSPECT] Case %s → %d 🐟 (dernière observation, tour %d)" % [
			str(case_pos), info["stock"], info["turn"]
		])


## Fonction de conversion de coordonnées
func _world_to_screen(world_pos: Vector2) -> Vector2:
	var viewport := get_viewport()
	if not viewport:
		return world_pos
	var cam := viewport.get_camera_2d()
	if not cam:
		return world_pos
	return viewport.get_canvas_transform() * world_pos
