# HexCell.gd
class_name HexCell

# Coordonnées Axiales (pour les maths, pathfinding, voisins)
var _q : int
var _r : int
var _s : int

# Coordonnées Offset (pour l'affichage et le stockage tableau 2D)
var _offset_coords : Vector2i 

var _terrain_type : String = "default"

var port_instance: Node2D = null

func _init(q: int, r: int, s: int, offset_coords: Vector2i, terrain_type: String = "default"):
	self._q = q
	self._r = r
	self._s = s
	self._offset_coords = offset_coords
	self._terrain_type = terrain_type

func getCoordinates() -> Vector3:
	return Vector3(_q,_r,_s)

func getTypeTerrain() -> String :
	return _terrain_type

func getTabCoordinates() -> Vector2i :
	return _offset_coords

func getTileTexture() -> Texture2D :
	var tile_name = "TileMissing"
	match _terrain_type:
		"deepwater": tile_name = "TileDeepWater"
		"water": tile_name = "TileWater"
		"sand": tile_name = "TileSand"
		"earth": tile_name = "TileEarth"
		"forest": tile_name = "TileForest"
		"mountain": tile_name = "TileMountain"
		"port": tile_name = "TilePort"
		"fish": tile_name = "TileFish" 
	var m_data = Map_data.new()
	var texture =  m_data.get(tile_name)
	if(texture == null):
		texture = Map_data.TileMissing
	return texture
