class_name Map_utils
extends Node



func _init():
	# permet de rajouter l'objet dans le groupe avant le passage du GameManager
	add_to_group("map")


# =========================
# Hex -> Iso conversion (Visuel)
# =========================
static func hex_to_pixel_iso(q: int, r: int) -> Vector2:
	var cx = q * (Map_data.hex_width * 0.5)
	var cy = r * (Map_data.hex_height + 150)
	if q % 2 == 1:
		cy += Map_data.hex_height - 51
	return Vector2(cx, cy)


# =========================
# CONVERSIONS COORDONNEES
static func monde_vers_case(pos: Vector2) -> Vector2i:
	var col_width = Map_data.hex_width * 0.5
	var row_height = Map_data.hex_height + 150
	var offset = Map_data.hex_height - 51
	var q = int(round(pos.x / col_width))
	var y = pos.y
	if q % 2 == 1:
		y -= offset
	var r = int(round(y / row_height))
	return Vector2i(q, r)



static func case_vers_monde(c: Vector2i) -> Vector2:
	return hex_to_pixel_iso(c.x, c.y)

# ============================================================
#  VALIDITY CHECKS
# ============================================================

## Returns true if the given grid coordinate is inside the map boundaries.
# Vérification de la validité d'une case (est-ce que la position est dans la carte)
static func is_case_valid(c: Vector2i) -> bool:
	return c.x >= 0 and c.x < Map_data.map_width and c.y >= 0 and c.y < Map_data.map_height


# ============================================================
#  TERRAIN CHECKS
# ============================================================

## Returns true if the given grid coordinate corresponds to a water tile.
## This avoids checking tiles[][] outside Map.gd.
static func is_case_water(c: Vector2i) -> bool:
	if not is_case_valid(c):
		return false
	return Map_data.tiles[c.y][c.x] in ["water", "deepwater", "fish"]

## Returns true if the given world coordinate corresponds to a water tile.
## This avoids checking tiles[][] outside Map.gd.
static func is_on_water(world_pos: Vector2) -> bool:
	var c = monde_vers_case(world_pos)
	return is_case_water(c)

## Returns true if the given grid coordinate is part of the ocean (i.e., navigable water).
## A navigable tile is a water tile that belongs to the precomputed ocean_cases list.
static func is_case_navigable(c: Vector2i) -> bool:
	if not is_case_valid(c):
		return false
	return c in Map_data.ocean_cases

## Returns true if the given world position corresponds to a navigable ocean tile.
static func is_world_position_navigable(world_pos: Vector2) -> bool:
	var c := monde_vers_case(world_pos)
	return is_case_navigable(c)


# ============================================================
#  CLAMPING / CORRECTION
# ============================================================

## Clamps a grid coordinate so it always stays inside the map.
static func clamp_case(c: Vector2i) -> Vector2i:
	return Vector2i(
		clampi(c.x, 0, Map_data.map_width - 1),
		clampi(c.y, 0, Map_data.map_height - 1)
	)

## Clamps a world position so it always maps to a valid tile.
## Converts world → case (clamped) → world (center of tile).
static func clamp_world_position(world_pos: Vector2) -> Vector2:
	var c := monde_vers_case(world_pos)
	c = clamp_case(c)
	return case_vers_monde(c)


# ============================================================
#  GET RANDOM POS
# ============================================================

## Returns a random world position on ocean water (never lakes).
static func get_random_ocean_position() -> Vector2:
	if Map_data.ocean_cases.is_empty():
		DEBUG.log("Ocean case list is empty. Did you call compute_ocean_cases()?",DEBUG.WARNING)
		return Vector2.ZERO

	var c: Vector2i = Map_data.ocean_cases[randi() % Map_data.ocean_cases.size()]
	var pos = case_vers_monde(c)
	if pos.x < 0 or pos.y < 0:
		DEBUG.log("WORLD POS OUTSIDE MAP: " + str(pos) + " from case " + str(c),DEBUG.ERROR)
	return pos

# Calcule la distance réelle en cases entre deux hexagones (offset coords)
# ============================================================
# CALCUL DE DISTANCE
# ============================================================
static func get_hex_distance(a: Vector2i, b: Vector2i) -> int:
	# 1. Conversion Offset -> Axial (Version Pointy Top / Odd-Q)
	# On doit utiliser la même logique que HexGrid.offset_to_axial
	var aq = a.x
	var ar = a.y - (a.x - (a.x & 1)) / 2.
	var as_coord = -aq - ar
	
	var bq = b.x
	var br = b.y - (b.x - (b.x & 1)) / 2.
	var bs_coord = -bq - br
	
	# 2. Distance Manhattan cubique
	return int((abs(aq - bq) + abs(ar - br) + abs(as_coord - bs_coord)) / 2)


static func get_neighbors(c: Vector2i) -> Array[Vector2i]:
	var res: Array[Vector2i] = []
	
	# Pour du Pointy-Top (Odd-Q), le décalage dépend de la COLONNE (X)
	var directions
	
	if c.x % 2 == 0:
		# Colonne PAIRE (Even)
		# Note: En Odd-Q, les colonnes paires sont "plus hautes" visuellement que les impaires
		
		directions = [
			Vector2i(-1, -1),  # Nord-Ouest
			Vector2i(1, -1),  # Nord-Est
			Vector2i(2, 0),  # Est
			Vector2i(1, 0),   # Sud-Est
			Vector2i(-1, 0),   # Sud-Ouest
			Vector2i(-2, 0)  # Ouest
		]
	else:
		# Colonne IMPAIRE (Odd) - Décalée vers le bas (+Y visuel)
		directions = [
			Vector2i(-1, 0),  # Nord-Ouest
			Vector2i(1, 0),   # Nord-Est
			Vector2i(2, 0),   # Est
			Vector2i(1, 1),   # Sud-Est
			Vector2i(-1, 1),  # Sud-Ouest
			Vector2i(-2, 0)   # Ouest
		]
	for d in directions:
		var neighbor = c + d
		# On utilise votre vérification existante qui est très bien
		if is_case_navigable(neighbor):
			res.append(neighbor)
	return res

# Nouvelle fonction pour gérer le coût du terrain
static func get_movement_cost(c: Vector2i) -> float:
	if not is_case_valid(c): return INF
	
	var type = Map_data.tiles[c.y][c.x]
	
	match type:
		"deepwater": return 1.0 # Autoroute maritime
		"water": return 1.0     # Eau côtière (plus lent, on préfère le large)
		_: return 1.0


# Pour la génération uniquement : on veut savoir si on peut "étendre" l'océan
static func get_neighbors_water_only(c: Vector2i) -> Array[Vector2i]:
	var res: Array[Vector2i] = []
	var directions
	
	if c.x % 2 == 0:
		directions = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(-1, -1), Vector2i(-1, 0)]
	else:
		directions = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(-1, 0), Vector2i(-1, 1)]

	for d in directions:
		var n = c + d
		# ICI : On vérifie juste si c'est dans la map et si c'est de l'eau
		if is_case_valid(n) and is_case_water(n):
			res.append(n)
	return res
