extends TextureButton

var turn_manager = null
var match_context: MatchContext = null
var label: Label

func _ready() -> void:
	texture_normal  = load("res://textures/Panneau fin de tour.png")
	texture_pressed = load("res://textures/Panneau fin de tour appuyé.png")
	texture_hover   = load("res://textures/Panneau fin de tour appuyé.png")
	
	ignore_texture_size = false
	stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	scale = Vector2(0.3, 0.3)
	
	label = Label.new()
	label.text = "Fin du tour"
	label.add_theme_font_size_override("font_size", 80)
	label.add_theme_color_override("font_color", Color("#FFE8B0"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.position = Vector2(0, 30)
	add_child(label)
	
	anchor_left   = 0.0
	anchor_top    = 0.0
	anchor_right  = 0.0
	anchor_bottom = -20
	
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	await get_tree().process_frame
	_repositionner()
	
	get_viewport().size_changed.connect(_repositionner)
	
	turn_manager  = get_tree().get_first_node_in_group("turn_manager")
	match_context = get_tree().get_first_node_in_group("match_context")
	pressed.connect(_on_pressed)

func _on_mouse_entered() -> void:
	label.position = Vector2(0, 20)

func _on_mouse_exited() -> void:
	label.position = Vector2(0, 30)

func _repositionner() -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	var real_size = size * scale
	position = Vector2(viewport_size.x / 2.0 - real_size.x / 2.0, -25)

func _on_pressed() -> void:
	if turn_manager == null or not is_instance_valid(turn_manager):
		turn_manager = get_tree().get_first_node_in_group("turn_manager")
	if match_context == null:
		match_context = get_tree().get_first_node_in_group("match_context")
	if turn_manager == null or not is_instance_valid(turn_manager):
		return

	if match_context != null and match_context.mode == MatchContext.MatchMode.MULTI:
		if turn_manager.has_method("request_end_turn"):
			turn_manager.request_end_turn()
	else:
		if turn_manager.has_method("end_turn"):
			turn_manager.end_turn()
