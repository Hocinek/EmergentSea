class_name MapManager
extends Node


# Permettra de signaler la fin de la génération de la map
signal map_generated

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
	match cell.terrain_type:
		"deepwater": s.texture = Map_data.TileDeepWater
		"water": s.texture = Map_data.TileWater
		"sand": s.texture = Map_data.TileSand
		"earth": s.texture = Map_data.TileEarth
		"forest": s.texture = Map_data.TileForest
		"mountain": s.texture = Map_data.TileMountain
		"port": 
			#cell.set_script(load("res://Scripts/in_game/ports/port.gd"))
			# Vérifier si TilePort existe dans Map_data
			if "TilePort" in Map_data:
				s.texture = Map_data.TilePort
			else:
				# Fallback: utiliser une texture de sable si TilePort n'existe pas
				s.texture = Map_data.TileSand
				DEBUG.log("TilePort non trouvé, utilisation de TileSand",DEBUG.WARNING)
	var scale_x = Map_data.hex_width / s.texture.get_width()
	var scale_y = Map_data.hex_height / s.texture.get_height()
	s.scale = Vector2(scale_x, scale_y)

	# Utilisation des coordonnées offset stockées dans la cellule
	s.position = Map_utils.hex_to_pixel_iso(cell.offset_coords.x, cell.offset_coords.y)
	#print(cell.offset_coords)
	
	# Optionnel : Stocker une référence du sprite dans la cellule pour y accéder plus tard
	# cell.visual_node = s 
	
	add_child(s)

# =========================
# Rendering
# =========================
func render_map():
	
	for y in range(Map_data.map_height):
		for x in range(Map_data.map_width):
			spawn_tile(Map_data.tiles[y][x], x, y)

func spawn_tile(t: String, col: int, row: int):
	var s := Sprite2D.new()
	match t:
		"deepwater": s.texture = Map_data.TileDeepWater
		"water": s.texture = Map_data.TileWater
		"sand": s.texture = Map_data.TileSand
		"earth": s.texture = Map_data.TileEarth
		"forest": s.texture = Map_data.TileForest
		"mountain": s.texture = Map_data.TileMountain
		"port": 
			# Vérifier si TilePort existe dans Map_data
			if "TilePort" in Map_data:
				s.texture = Map_data.TilePort
			else:
				# Fallback: utiliser une texture de sable si TilePort n'existe pas
				s.texture = Map_data.TileSand
				DEBUG.log("TilePort non trouvé, utilisation de TileSand",DEBUG.WARNING)
	
	s.position = Map_utils.hex_to_pixel_iso(col, row)
	var scale_x = Map_data.hex_width / s.texture.get_width()
	var scale_y = Map_data.hex_height / s.texture.get_height()
	s.scale = Vector2(scale_x, scale_y)
	add_child(s)
