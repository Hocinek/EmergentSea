# HexCell.gd
class_name HexCell

# Coordonnées Axiales (pour les maths, pathfinding, voisins)
var _q : int
var _r : int
var _s : int

# Coordonnées Offset (pour l'affichage et le stockage tableau 2D)
var _offset_coords : Vector2i 

var _terrain_type : String = "default"
var _underlying_terrain : String = ""  # Terrain sous-jacent (utile pour les cases fish)

var port_instance: Node2D = null

func _init(q: int, r: int, s: int, offset_coords: Vector2i, terrain_type: String = "default"):
	self._q = q
	self._r = r
	self._s = s
	self._offset_coords = offset_coords
	self._terrain_type = terrain_type
	# Récupérer le terrain sous-jacent si c'est une case fish
	if terrain_type == "fish":
		_underlying_terrain = Map_data.fish_underlying.get(offset_coords, "water")

func getCoordinates() -> Vector3:
	return Vector3(_q,_r,_s)

func getTypeTerrain() -> String :
	return _terrain_type

func getTabCoordinates() -> Vector2i :
	return _offset_coords

func getTileTexture() -> Texture2D :
	match _terrain_type:
		"deepwater": return Map_data.TileDeepWater
		"water":     return Map_data.TileWater
		"sand":      return Map_data.TileSand
		"earth":     return Map_data.TileEarth
		"forest":    return Map_data.TileForest
		"mountain":  return Map_data.TileMountain
		"port":      return Map_data.TilePort
		"fish":
			if _underlying_terrain == "deepwater":
				return Map_data.TileFish
			return Map_data.TileFishNotDeep
	return Map_data.TileMissing
