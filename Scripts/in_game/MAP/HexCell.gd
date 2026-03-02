# HexCell.gd
class_name HexCell

# Coordonnées Axiales (pour les maths, pathfinding, voisins)
var q : int
var r : int
var s : int

# Coordonnées Offset (pour l'affichage et le stockage tableau 2D)
var offset_coords : Vector2i 

var terrain_type : String = "default"

func _init(q: int, r: int, s: int, offset_coords: Vector2i, terrain_type: String = "default"):
	self.q = q
	self.r = r
	self.s = s
	self.offset_coords = offset_coords
	self.terrain_type = terrain_type
