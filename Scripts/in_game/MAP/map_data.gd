class_name Map_data
extends Node

# taille d'un sprite de case
static var TILE_WIDTH : int = 256
static var TILE_HEIGHT : int = 128

# data :
static var tiles := []
static var ocean_cases: Array = []	#liste des cases navigables
static var ports := []  # liste des positions des ports (Vector2i)

# =========================
# Textures
# =========================
static var TileWater: Texture2D = preload("res://textures/tiles/TileWater.png")
static var TileDeepWater: Texture2D = preload("res://textures/tiles/TileDeepWater.png")
static var TileSand: Texture2D = preload("res://textures/tiles/TileSand.png")
static var TileEarth: Texture2D = preload("res://textures/tiles/TileEarth.png")
static var TileForest: Texture2D = preload("res://textures/tiles/TileForest.png")
static var TileMountain: Texture2D = preload("res://textures/tiles/TileMountain.png")
static var TilePort: Texture2D = preload("res://textures/tiles/TilePort.png")


# =========================
# Map parameters
# =========================
static var map_width : int = 32
static var map_height : int = 16
static var hex_width : int = 512
static var hex_height : int = 256

# =========================
# Noise parameters
# =========================
static var noise_scale := 0.035
static var octaves := 4
static var lacunarity := 2.0
static var gain := 0.5
static var gen_seed := 0

# =========================
# Island counts 
# =========================
static var small_island_count := 20
static var medium_island_count := 30
static var large_island_count := 40

# =========================
# Island size ranges 
# =========================
static var small_radius := Vector2(22.0, 36.0)
static var medium_radius := Vector2(48.0, 70.0)
static var large_radius := Vector2(85.0, 120.0)

static var small_power := Vector2(1.4, 1.9)
static var medium_power := Vector2(1.1, 1.5)
static var large_power := Vector2(0.75, 1.05)

# =========================
# Port parameters
# =========================
static var port_count: int = 8  # Nombre de ports à générer
static var min_port_distance: int = 15  # Distance minimale entre deux ports (en tiles)

func _init():
	add_to_group("map_data")
