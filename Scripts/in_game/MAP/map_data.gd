class_name Map_data
extends Node

# =========================
# Taille d'une case
# =========================
static var TILE_WIDTH: int = 256
static var TILE_HEIGHT: int = 128

# =========================
# Données map
# =========================
static var tiles := []
static var ocean_cases: Array = []     # cases navigables
static var ports := []                 # positions des ports (Vector2i)
static var fish_cases: Array = []      # cases de pêche

# =========================
# Ressources de pêche
# =========================
static var fish_counts: Dictionary = {}

# =========================
# Textures des tiles
# =========================
static var TileWater: Texture2D = preload("res://Assets/textures/tiles/TileWater.png")
static var TileDeepWater: Texture2D = preload("res://Assets/textures/tiles/TileDeepWater.png")
static var TileSand: Texture2D = preload("res://Assets/textures/tiles/TileSand.png")
static var TileEarth: Texture2D = preload("res://Assets/textures/tiles/TileEarth.png")
static var TileForest: Texture2D = preload("res://Assets/textures/tiles/TileForest.png")
static var TileMountain: Texture2D = preload("res://Assets/textures/tiles/TileMountain.png")
static var TilePort: Texture2D = preload("res://Assets/textures/tiles/TilePort.png")
static var TileFish: Texture2D = preload("res://Assets/textures/tiles/TileFish.png")
static var TileMissing: Texture2D = preload("res://Assets/textures/tiles/TileMissing.png")

# =========================
# Scene 3D du port
# =========================
static var PortScene: PackedScene = preload("res://Assets/textures/port.tscn")

# =========================
# Paramètres map
# =========================
static var map_width: int = 64
static var map_height: int = 32
static var hex_width: int = 512
static var hex_height: int = 256

# =========================
# Paramètres de génération
# =========================
static var noise_scale := 0.035
static var octaves := 4
static var lacunarity := 2.0
static var gain := 0.5
static var gen_seed := 0

# =========================
# Îles
# =========================
static var small_island_count: int = 60
static var medium_island_count: int = 60
static var large_island_count: int = 60

static var small_radius := Vector2(22.0, 36.0)
static var medium_radius := Vector2(48.0, 70.0)
static var large_radius := Vector2(85.0, 120.0)

static var small_power := Vector2(1.4, 1.9)
static var medium_power := Vector2(1.1, 1.5)
static var large_power := Vector2(0.75, 1.05)

# =========================
# Ports
# =========================
static var port_count: int = 8
static var min_port_distance: int = 15

func _ready():
	add_to_group("map_data")


# =========================
# Convertit coordonnées grille -> écran (isométrique)
# =========================
static func grid_to_world(tile_pos: Vector2i) -> Vector2:
	var world_x = (tile_pos.x - tile_pos.y) * (TILE_WIDTH / 2.0)
	var world_y = (tile_pos.x + tile_pos.y) * (TILE_HEIGHT / 2.0)
	return Vector2(world_x, world_y)


# =========================
# Spawn d'un port 3D
# =========================
static func spawn_port(parent: Node, tile_pos: Vector2i) -> Node2D:
	var port = PortScene.instantiate()

	port.position = grid_to_world(tile_pos)

	parent.add_child(port)

	ports.append(tile_pos)

	return port
