extends Button

var turn_manager = null
var match_context: MatchContext = null


func _ready() -> void:
	text = "Fin du tour"
	turn_manager = get_tree().get_first_node_in_group("turn_manager")
	match_context = get_tree().get_first_node_in_group("match_context")
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	if turn_manager == null or not is_instance_valid(turn_manager):
		turn_manager = get_tree().get_first_node_in_group("turn_manager")

	if match_context == null:
		match_context = get_tree().get_first_node_in_group("match_context")

	if turn_manager == null or not is_instance_valid(turn_manager):
		return

	# En mode multi : passer par request_end_turn() qui gère le RPC
	# En mode solo  : appel direct à end_turn() comme avant
	if match_context != null and match_context.mode == MatchContext.MatchMode.MULTI:
		if turn_manager.has_method("request_end_turn"):
			turn_manager.request_end_turn()
	else:
		if turn_manager.has_method("end_turn"):
			turn_manager.end_turn()
