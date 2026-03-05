extends Button

var turn_manager: TurnManager = null

func _ready():
	text = "Fin du tour"
	turn_manager = get_tree().get_first_node_in_group("turn_manager")
	pressed.connect(_on_pressed)


func _on_pressed():
	if turn_manager and is_instance_valid(turn_manager):
		turn_manager.end_turn()
