class_name Input_manager
extends Node

## Signal émis après un clic gauche (avec les coordonnées monde)
signal clicked_world_coordinates(pos:Vector2)
## Signal émis après un clic gauche (avec les coordonnées case)
signal clicked_cell_coordinates(pos:Vector2i)

## Signal émis après un clic droit (avec les coordonnées monde)
signal interact_world_coordinates(pos:Vector2)
## Signal émis après un clic droit (avec les coordonnées case)
signal interact_cell_coordinates(pos:Vector2i)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mouse_pos = get_viewport().get_mouse_position()
		var cell_pos = Map_utils.monde_vers_case(mouse_pos)
		
		if event.button_index == MOUSE_BUTTON_LEFT:
			clicked_world_coordinates.emit(mouse_pos)
			clicked_cell_coordinates.emit(cell_pos)
			return
		elif event.button_index == MOUSE_BUTTON_RIGHT:			
			interact_world_coordinates.emit(mouse_pos)
			interact_cell_coordinates.emit(cell_pos)
			return
	
	
	#get_viewport().set_input_as_handled()
