extends Node
class_name MultiplayerPlayerManager

var players: Array[Player] = []
var current_player: Player = null
var current_player_id: int = 0

var match_context: MatchContext = null


func _ready() -> void:
	add_to_group("players_manager")
	players.clear()
	match_context = get_tree().get_first_node_in_group("match_context")


func create_player(
	player_id: int,
	player_name: String,
	is_human: bool = true
) -> Player:
	var player_scene := preload("res://Scenes/in_game/ENTITIES/Player.tscn")
	var player: Player = player_scene.instantiate()

	player.player_id = player_id
	player.player_name = player_name
	player.is_human = is_human
	player.is_local = false

	if match_context == null:
		match_context = get_tree().get_first_node_in_group("match_context")

	if match_context != null:
		player.is_local = match_context.is_local_player(player_id)

	add_child(player)
	players.append(player)

	if current_player == null:
		current_player = player
		current_player_id = 0

	return player


func get_player_by_id(player_id: int) -> Player:
	for p in players:
		if p.player_id == player_id:
			return p
	return null


func get_all_players() -> Array[Player]:
	return players


func get_enemy_players(of_player: Player) -> Array[Player]:
	var enemies: Array[Player] = []
	for p in players:
		if p != of_player:
			enemies.append(p)
	return enemies


func get_human_player() -> Player:
	for player in players:
		if player.is_human:
			return player
	return null


func get_local_player() -> Player:
	for player in players:
		if player.is_local:
			return player
	return null


func get_current_player() -> Player:
	if match_context == null:
		match_context = get_tree().get_first_node_in_group("match_context")

	if match_context != null and match_context.active_player_id != -1:
		var active = get_player_by_id(match_context.active_player_id)
		if active != null:
			current_player = active
			current_player_id = players.find(active)

	return current_player


func set_current_player(player: Player) -> void:
	if players.has(player):
		current_player = player
		current_player_id = players.find(player)

		if match_context == null:
			match_context = get_tree().get_first_node_in_group("match_context")

		if match_context != null:
			match_context.set_active_player(player.player_id)


func next_turn() -> Player:
	if players.is_empty():
		return null

	current_player_id = (current_player_id + 1) % players.size()
	current_player = players[current_player_id]

	if match_context == null:
		match_context = get_tree().get_first_node_in_group("match_context")

	if match_context != null:
		match_context.set_active_player(current_player.player_id)

	return current_player
