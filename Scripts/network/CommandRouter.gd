extends Node
class_name CommandRouter

signal move_requested(ship_id: int, target_case: Vector2i)
signal shoot_requested(ship_id: int, target_case: Vector2i)
signal fish_requested(ship_id: int)
signal end_turn_requested(player_id: int)


func _enter_tree() -> void:
	add_to_group("command_router")


func request_move(ship_id: int, target_case: Vector2i) -> void:
	move_requested.emit(ship_id, target_case)


func request_shoot(ship_id: int, target_case: Vector2i) -> void:
	shoot_requested.emit(ship_id, target_case)


func request_fish(ship_id: int) -> void:
	fish_requested.emit(ship_id)


func request_end_turn(player_id: int) -> void:
	end_turn_requested.emit(player_id)
