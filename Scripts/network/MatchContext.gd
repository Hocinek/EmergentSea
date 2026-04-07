extends Node
class_name MatchContext

func _enter_tree() -> void:
	add_to_group("match_context")

enum MatchMode {
	SOLO,
	MULTI
}

enum PlayerKind {
	HUMAN,
	AI
}

var mode: MatchMode = MatchMode.SOLO

var local_player_id: int = -1
var active_player_id: int = -1

# peer_id -> player_id
var peer_to_player_id: Dictionary = {}

# player_id -> kind
var player_kinds: Dictionary = {}

# ordre des tours
var turn_order: Array[int] = []


func reset() -> void:
	mode = MatchMode.SOLO
	local_player_id = -1
	active_player_id = -1
	peer_to_player_id.clear()
	player_kinds.clear()
	turn_order.clear()


func configure_solo(local_id: int = 1) -> void:
	reset()
	mode = MatchMode.SOLO
	local_player_id = local_id


func configure_multi(local_id: int) -> void:
	reset()
	mode = MatchMode.MULTI
	local_player_id = local_id


func register_player(player_id: int, kind: PlayerKind, peer_id: int = -1) -> void:
	player_kinds[player_id] = kind

	if not turn_order.has(player_id):
		turn_order.append(player_id)

	if peer_id != -1:
		peer_to_player_id[peer_id] = player_id


func set_active_player(player_id: int) -> void:
	active_player_id = player_id


func get_player_kind(player_id: int) -> PlayerKind:
	return player_kinds.get(player_id, PlayerKind.HUMAN)


func is_ai(player_id: int) -> bool:
	return get_player_kind(player_id) == PlayerKind.AI


func is_local_player(player_id: int) -> bool:
	return player_id == local_player_id


func is_local_turn() -> bool:
	return active_player_id != -1 and active_player_id == local_player_id


func get_player_id_from_peer(peer_id: int) -> int:
	return peer_to_player_id.get(peer_id, -1)


func get_turn_order() -> Array[int]:
	return turn_order.duplicate()
