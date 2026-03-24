class_name MapManager
extends Node2D


# Permettra de signaler la fin de la génération de la map
signal map_generated
## Permet de signaler qu'une case a été cliquée
signal cell_clicked(cell: HexCell)

@export var map_gen : Map_gen
@export var map_utils : Map_utils

var grid : HexGrid

func _enter_tree():
	add_to_group("Map_manager")
	grid = HexGrid.new()
	add_child(grid)
	Map_data.new()
	map_gen = Map_gen.new()
	map_utils = Map_utils.new()
	add_child(map_gen)
	
func _ready():
	await get_tree().process_frame
	var is_map_gen = map_gen.generate()
	if(is_map_gen):
		DEBUG.log("Map générée")
		grid.generate_hex_grid_rectangular()
		grid.import_from_map_data()
		render_map_from_grid()
		#grid.spawn_all_tiles(self)
		#render_map()
		DEBUG.log("Rendu de la map effectué")
		#permet de signaler au moteur que la map est générée
		await get_tree().process_frame
		emit_signal("map_generated")
	pass

# =========================
# Rendering Refactorisé
# =========================
func render_map_from_grid():
	# On itère sur toutes les cellules stockées dans le dictionnaire
	for cell in grid.cells.values():
		spawn_tile_object(cell)

func spawn_tile_object(cell: HexCell):
	var s := Sprite2D.new()
	
	s.centered = true
	# On récupère le type depuis la cellule, plus besoin de Map_data.tiles[y][x]
	s.texture = cell.getTileTexture()
	if(s.texture == Map_data.TileMissing):
		DEBUG.log("Texture manquante pour le terrain '%s'" % cell.getTypeTerrain(),DEBUG.WARNING)
	
	var scale_x = Map_data.hex_width / s.texture.get_width()
	var scale_y = Map_data.hex_height / s.texture.get_height()
	s.scale = Vector2(scale_x, scale_y)

	# Utilisation des coordonnées offset stockées dans la cellule
	var offset_coords = cell.getTabCoordinates()
	var pixel_pos = Map_utils.hex_to_pixel_iso(offset_coords.x, offset_coords.y)
	s.position = pixel_pos
	
	add_child(s)
	
	if cell.getTypeTerrain() == "port":
		var port_node = Map_data.port_scene.instantiate()
		port_node.position = pixel_pos
		port_node.setCell(cell)
		add_child(port_node)
		
		cell.port_instance = port_node

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_global_mouse_position()
		
		var clicked_cell = grid.get_cell_from_world(mouse_pos)
		
		if clicked_cell != null:
			emit_signal("cell_clicked", clicked_cell)
			var terrain = clicked_cell.getTypeTerrain()
			# Si c'est un port et qu'il y a bien une instance de port attachée
			if terrain == "port" and clicked_cell.port_instance != null:
				clicked_cell.port_instance.on_clicked()
				get_viewport().set_input_as_handled()
