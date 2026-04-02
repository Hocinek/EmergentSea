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

var player1 = null
var player2 = null

var selected_ship = null
var selected_port = null

var host_match_initialized: bool = false


func _enter_tree() -> void:
	name = "MultiplayerGameManager"
	add_to_group("game_manager")

	var map_manager = get_tree().get_first_node_in_group("Map_manager")
	if map_manager and map_manager.has_signal("map_generated"):
		if not map_manager.map_generated.is_connected(_on_map_generated):
			map_manager.map_generated.connect(_on_map_generated)


func _ready() -> void:
	_refresh_refs()
	_setup_fog_of_war()
	_setup_hex_menu()


func _refresh_refs() -> void:
	players_manager = get_tree().get_first_node_in_group("players_manager")
	turn_manager = get_tree().get_first_node_in_group("turn_manager")
	match_context = get_tree().get_first_node_in_group("match_context")
	network_manager = get_tree().get_first_node_in_group("network_manager")
	bootstrap = get_tree().get_first_node_in_group("multiplayer_bootstrap")
	command_router = get_tree().get_first_node_in_group("command_router")
	data = get_tree().get_first_node_in_group("shared_entities")


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

	_rpc_receive_initial_state.rpc(players_data, ships_data, turn_order)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_receive_initial_state(players_data: Array, ships_data: Array, turn_order: Array) -> void:
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

	if data == null:
		data = get_tree().get_first_node_in_group("shared_entities")

	if data and data.has_method("addNavireToData"):
		data.addNavireToData(navire)

	return navire


func spawn_navire_random(player, is_player_controlled: bool = false, ship_id: int = 0):
	var pos = Map_utils.get_random_ocean_position()
	return spawn_navire(player, pos, is_player_controlled, ship_id)


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
