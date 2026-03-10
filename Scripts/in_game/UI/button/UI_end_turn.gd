extends Button

var turn_manager = null

func _ready() -> void:
	text = "Fin du tour"
	turn_manager = get_tree().get_first_node_in_group("turn_manager")
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	if turn_manager == null or not is_instance_valid(turn_manager):
		turn_manager = get_tree().get_first_node_in_group("turn_manager")
	
	if turn_manager and is_instance_valid(turn_manager) and turn_manager.has_method("end_turn"):
		turn_manager.end_turn()
