extends Node
class_name MultiplayerTurnManager

signal turn_started(player)
signal turn_ended(player)
signal active_player_changed(player)
signal game_over(winner)

var players: Array = []
var current_player = null
var state: MultiplayerTurnState.State = MultiplayerTurnState.State.IDLE

var match_context: MatchContext = null


func _enter_tree() -> void:
	add_to_group("turn_manager")


func _ready() -> void:
	match_context = get_tree().get_first_node_in_group("match_context")


func start_game(players_list: Array) -> void:
	players = players_list.duplicate()

	if players.is_empty():
		state = MultiplayerTurnState.State.GAME_OVER
		game_over.emit(null)
		return

	if match_context == null:
		match_context = get_tree().get_first_node_in_group("match_context")
		if match_context == null:
			push_error("[MULTI TURN] MatchContext introuvable")
			return

	var first_player = players[0]
	current_player = first_player
	match_context.set_active_player(first_player.player_id)

	_reset_player_ships(current_player)

	state = MultiplayerTurnState.State.PLAYER_ACTION
	active_player_changed.emit(current_player)
	turn_started.emit(current_player)


func end_turn() -> void:
	if players.is_empty():
		return

	if current_player == null:
		return

	if match_context == null:
		match_context = get_tree().get_first_node_in_group("match_context")
		if match_context == null:
			push_error("[MULTI TURN] MatchContext introuvable")
			return

	if state != MultiplayerTurnState.State.PLAYER_ACTION:
		return

	var previous_player = current_player
	turn_ended.emit(previous_player)

	var current_index := players.find(current_player)
	if current_index == -1:
		current_index = 0

	var next_index := (current_index + 1) % players.size()
	current_player = players[next_index]

	match_context.set_active_player(current_player.player_id)
	_reset_player_ships(current_player)
	_update_selection_for_active_player()

	state = MultiplayerTurnState.State.PLAYER_ACTION
	active_player_changed.emit(current_player)
	turn_started.emit(current_player)


func _reset_player_ships(player) -> void:
	if player == null:
		return

	if not player.has_method("get_navires"):
		return

	var ships = player.get_navires()
	for ship in ships:
		if ship != null and is_instance_valid(ship) and ship.has_method("reset_energie"):
			ship.reset_energie()


func _update_selection_for_active_player() -> void:
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager == null:
		return

	if match_context != null and match_context.is_local_turn():
		if current_player != null and current_player.has_method("get_navires"):
			var ships = current_player.get_navires()
			if not ships.is_empty():
				var first_ship = ships[0]
				if first_ship != null and is_instance_valid(first_ship) and game_manager.has_method("select_ship"):
					game_manager.select_ship(first_ship)
					return

	if game_manager.has_method("deselect_ship"):
		game_manager.deselect_ship()


func can_navire_act(navire) -> bool:
	if state != MultiplayerTurnState.State.PLAYER_ACTION:
		return false

	if navire == null or not is_instance_valid(navire):
		return false

	if not navire.has_method("is_alive") or not navire.is_alive():
		return false

	if navire.player_owner == null:
		return false

	if match_context == null:
		match_context = get_tree().get_first_node_in_group("match_context")
		if match_context == null:
			return false

	return (
		match_context.is_local_player(navire.player_owner.player_id)
		and match_context.is_local_turn()
	)
