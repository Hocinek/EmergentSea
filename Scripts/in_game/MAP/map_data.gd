class_name Map_data
extends Node

# taille d'un sprite de case
static var TILE_WIDTH : int = 256
static var TILE_HEIGHT : int = 128

# data :
static var tiles := []
static var ocean_cases: Array = []	#liste des cases navigables
static var ports := []  # liste des positions des ports (Vector2i)
static var fish_cases: Array = []   # liste des cases de pêche (Vector2i)
static var fish_underlying: Dictionary = {}  # {Vector2i: String} terrain sous-jacent des cases fish

# =========================
# RESSOURCES DE PÊCHE
# Dictionnaire {Vector2i: int} — nombre de poissons par case de pêche
# Rempli par le MapGenerator lors de la génération
# =========================
static var fish_counts: Dictionary = {}

# =========================
# Textures
# =========================
static var TileWater: Texture2D = preload("res://Assets/textures/tiles/TileWater.png")
static var TileDeepWater: Texture2D = preload("res://Assets/textures/tiles/TileDeepWater.png")
static var TileSand: Texture2D = preload("res://Assets/textures/tiles/TileSand.png")
static var TileEarth: Texture2D = preload("res://Assets/textures/tiles/TileEarth.png")
static var TileForest: Texture2D = preload("res://Assets/textures/tiles/TileForest.png")
static var TileMountain: Texture2D = preload("res://Assets/textures/tiles/TileMountain.png")
static var TilePort: Texture2D = preload("res://Assets/textures/tiles/TilePort.png")
static var TileFish: Texture2D = preload("res://Assets/textures/tiles/TileFish.png")
static var TileFishNotDeep: Texture2D = preload("res://Assets/textures/tiles/TileFishNotDeep.png")
static var TileMissing : Texture2D = preload("res://Assets/textures/tiles/TileMissing.png")


static var port_scene = preload("res://Scenes/in_game/ENTITIES/Port.tscn")

# =========================
# Map parameters
# =========================
static var map_width : int = 64
static var map_height : int = 32
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
static var small_island_count : int = 60
static var medium_island_count : int = 60
static var large_island_count : int = 60

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
