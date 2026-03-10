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

var player1 = null
var player2 = null

var selected_ship = null
var selected_port = null

var host_match_initialized: bool = false


func _enter_tree() -> void:
	add_to_group("game_manager")

	var map_manager = get_tree().get_first_node_in_group("Map_manager")
	if map_manager and map_manager.has_signal("map_generated"):
		if not map_manager.map_generated.is_connected(_on_map_generated):
			map_manager.map_generated.connect(_on_map_generated)


func _ready() -> void:
	_refresh_refs()
	_setup_fog_of_war()


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


func _on_map_generated() -> void:
	_refresh_refs()

	if bootstrap == null or network_manager == null:
		push_error("[MULTI GM] Bootstrap ou NetworkManager introuvable")
		return

	if network_manager.is_host():
		bootstrap.configure_host_lobby()
		await _initialize_host_debug_match()
	else:
		bootstrap.configure_client_lobby()


func _initialize_host_debug_match() -> void:
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


func select_port(port) -> void:
	selected_port = port
	port_selected.emit(port)


func deselect_port() -> void:
	selected_port = null
	port_deselected.emit()
