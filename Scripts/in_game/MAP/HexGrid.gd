# HexGrid.gd
class_name HexGrid
extends Node

const SQRT3 := sqrt(3.0)
var cells := {} 

# ============================================================
# Génération Standardisée (Pointy-Top / Odd-Q)
# ============================================================
func generate_hex_grid_rectangular():
	var width = Map_data.map_width
	var height = Map_data.map_height

	DEBUG.log("dimensions : ")
	DEBUG.log(str(offset_to_axial(width, height)))
	# Pour Pointy-Top, on boucle classiquement ligne par ligne
	for row in range(height):
		for col in range(width):
			
			# Utilisation de la formule Odd-R (Pointy-Top)
			var axial = offset_to_axial(col, row)
			var q = int(axial.x)
			var r = int(axial.y)
			var s = -q - r
			
			var cell = HexCell.new(q, r, s, Vector2i(col, row))
			add_cell(cell)

# ============================================================
# Gestion des cellules
# ============================================================

func add_cell(cell: HexCell):
	var key = Vector3(cell.q, cell.r, cell.s)
	cells[key] = cell

func get_cell(q: int, r: int, s: int) -> HexCell:
	return cells.get(Vector3(q, r, s), null)

# ============================================================
# Offset <-> Axial (Configuration Pointy Top / Odd-Q)
# ============================================================
# Convertit les coordonnées de grille (col, row) en mathématiques (q, r)
# Pour une grille Pointy-Top (décalage vertical des colonnes impaires)
func offset_to_axial(col: int, row: int) -> Vector2:
	var q = col
	# La formule magique pour Odd-Q (Pointy Top)
	var r = row - (col - (col & 1)) / 2
	return Vector2(q, r)

func axial_to_offset(q: int, r: int) -> Vector2:
	var col = q
	# Inverse de la formule Odd-Q
	var row = r + (q - (q & 1)) / 2
	return Vector2(col, row)

# Dans generate_hex_grid_rectangular, assure-toi que s est toujours calculé ainsi :
# var s = -q - r

# ============================================================
# Conversion Monde → Offset
# ============================================================

func world_to_offset(pos: Vector2) -> Vector2:
	var hex_w = Map_data.hex_width
	var hex_h = Map_data.hex_height

	var col_width = SQRT3 * hex_w * 0.5
	var row_height = hex_h * 0.75

	var col = int(pos.x / col_width)
	var row = int(pos.y / row_height)

	return Vector2(col, row)

# ============================================================
# Conversion Monde → Cellule
# ============================================================

func get_cell_from_world(pos: Vector2) -> HexCell:
	# On délègue tout à Map_utils pour éviter la duplication de code
	var grid_pos = Map_utils.monde_vers_case(pos)
	return get_cell(grid_pos.x, grid_pos.y, -grid_pos.x - grid_pos.y) # Note: le 's' n'est pas critique ici


func import_from_map_data():
	cells.clear()
	var tiles_data = Map_data.tiles # Ton tableau 2D [row][col]

	for r_idx in range(tiles_data.size()):
		for c_idx in range(tiles_data[r_idx].size()):
			var terrain = tiles_data[r_idx][c_idx]
			
			# Ici, l'offset_coords DOIT être l'index pur du tableau
			var offset = Vector2i(c_idx, r_idx) 
			
			var axial = offset_to_axial(offset.x, offset.y)
			var cell = HexCell.new(axial.x, axial.y, -axial.x-axial.y, offset, terrain)
			add_cell(cell)

func spawn_all_tiles(map_manager: Node):
	for cell in cells.values():
		map_manager.spawn_tile(cell.terrain_type, cell.offset_coords.x, cell.offset_coords.y)
