class_name Map_gen
extends Node2D

@export var water_ratio := 0.55
@export var port_count: int = 8
@export var min_port_distance: int = 15

# =========================
# Fish tile parameters
# =========================
@export var fish_tile_count: int = 12
@export var min_fish_distance: int = 4   # Distance min entre deux cases de pêche

# =========================
# Internal data
# =========================
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var noise: FastNoiseLite = FastNoiseLite.new()
var height_map := []
var islands := []
var ports := [] # Liste des ports générés

func _init():
	pass
func _enter_tree():
	pass
func _ready():
	pass

func generate() -> bool:
	init_maps()
	init_noise()
	generate_island_centers()
	generate_islands()
	generate_tiles()
	compute_ocean_cases()
	generate_ports()  # Génération des ports après les autres éléments
	sync_ports_to_map_data()  # Synchroniser avec Map_data
	generate_fish_tiles()  # Cases de pêche sur l'eau
	return true

func init_maps():
	height_map.clear()
	Map_data.tiles.clear()
	ports.clear()
	for y in range(Map_data.map_height):
		height_map.append([])
		Map_data.tiles.append([])
		for x in range(Map_data.map_width):
			height_map[y].append(0.0)
			Map_data.tiles[y].append("water")

func init_noise():
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	if Map_data.gen_seed != 0:
		noise.seed = Map_data.gen_seed
	else:
		var new_seed := randi()
		noise.seed = new_seed
		Map_data.gen_seed = new_seed
	# RNG utilise la même seed que noise -> génération 100% déterministe
	rng.seed = Map_data.gen_seed
	noise.frequency = Map_data.noise_scale
	noise.fractal_octaves = Map_data.octaves
	noise.fractal_lacunarity = Map_data.lacunarity
	noise.fractal_gain = Map_data.gain

func add_island(radius_range: Vector2, power_range: Vector2):
	islands.append({
		"pos": Vector2(
			rng.randf_range(25, Map_data.map_width - 25),
			rng.randf_range(25, Map_data.map_height - 25)
		),
		"radius": rng.randf_range(radius_range.x, radius_range.y),
		"power": rng.randf_range(power_range.x, power_range.y)
	})

func generate_island_centers():
	islands.clear()
	for i in range(Map_data.small_island_count):
		add_island(Map_data.small_radius, Map_data.small_power)
	for i in range(Map_data.medium_island_count):
		add_island(Map_data.medium_radius, Map_data.medium_power)
	for i in range(Map_data.large_island_count):
		add_island(Map_data.large_radius, Map_data.large_power)

func generate_islands():
	for y in range(Map_data.map_height):
		for x in range(Map_data.map_width):
			var n: float = noise.get_noise_2d(x, y)
			n = (n + 1.0) * 0.5
			var mask := 0.0
			for island in islands:
				var pos: Vector2 = island["pos"]
				var radius: float = island["radius"]
				var power: float = island["power"]
				var dx := x - pos.x
				var dy := y - pos.y
				var d := sqrt(dx * dx + dy * dy)
				if d < radius:
					var local := 1.0 - (d / radius)
					mask = max(mask, pow(local, power))
			height_map[y][x] = clamp(n * mask, 0.0, 1.0)

func generate_tiles():
	for y in range(Map_data.map_height):
		for x in range(Map_data.map_width):
			var h: float = height_map[y][x]
			if h < water_ratio - 0.08:
				Map_data.tiles[y][x] = "deepwater"
			elif h < water_ratio:
				Map_data.tiles[y][x] = "water"
			elif h < water_ratio + 0.07:
				Map_data.tiles[y][x] = "sand"
			elif h < 0.72:
				Map_data.tiles[y][x] = "earth"
			elif h < 0.85:
				Map_data.tiles[y][x] = "forest"
			else:
				Map_data.tiles[y][x] = "mountain"

## Computes and stores all water tiles connected to the map borders (ocean).
func compute_ocean_cases() -> void:
	Map_data.ocean_cases.clear()
	var visited := {}
	var queue := []
	for x in range(Map_data.map_width):
		queue.append(Vector2i(x, 0))
		queue.append(Vector2i(x, Map_data.map_height - 1))
	for y in range(Map_data.map_height):
		queue.append(Vector2i(0, y))
		queue.append(Vector2i(Map_data.map_width - 1, y))
	while queue.size() > 0:
		var c: Vector2i = queue.pop_front()
		if visited.has(c): continue
		visited[c] = true
		if not Map_utils.is_case_water(c): continue
		Map_data.ocean_cases.append(c)
		var neighbors = Map_utils.get_neighbors_water_only(c)
		for n in neighbors:
			if not visited.has(n):
				queue.append(n)

## Génère des ports sur les côtes avec distance minimale entre eux
func generate_ports() -> void:
	ports.clear()
	var coastal_tiles: Array = []
	for y in range(Map_data.map_height):
		for x in range(Map_data.map_width):
			if is_coastal_tile(x, y):
				coastal_tiles.append(Vector2i(x, y))
	if coastal_tiles.is_empty():
		DEBUG.log("Aucune case côtière trouvée pour placer des ports", DEBUG.WARNING)
		return
	DEBUG.log("Cases côtières trouvées: " + str(coastal_tiles.size()))
	var attempts: int = 0
	var max_attempts: int = port_count * 100
	while ports.size() < port_count and attempts < max_attempts:
		attempts += 1
		var random_index: int = rng.randi_range(0, coastal_tiles.size() - 1)
		var candidate: Vector2i = coastal_tiles[random_index]
		if is_valid_port_location(candidate):
			ports.append(candidate)
			Map_data.tiles[candidate.y][candidate.x] = "port"
			DEBUG.log("Port placé à : " + str(candidate))
	DEBUG.log("Ports générés : " + str(ports.size()) + "/" + str(port_count))

## Synchronise les ports avec Map_data (appelé après generate_ports)
func sync_ports_to_map_data() -> void:
	Map_data.ports.clear()
	for port in ports:
		Map_data.ports.append(port)

## Vérifie si une case est côtière (terre avec eau adjacente)
func is_coastal_tile(x: int, y: int) -> bool:
	var pos: Vector2i = Vector2i(x, y)
	if not Map_utils.is_case_valid(pos):
		return false
	var tile_type: String = Map_data.tiles[y][x]
	if tile_type == "water" or tile_type == "deepwater":
		return false
	var water_neighbor: Array[Vector2i] = Map_utils.get_neighbors(pos)
	if water_neighbor != []:
		return true
	return false

## Vérifie si un emplacement de port respecte la distance minimale
func is_valid_port_location(candidate: Vector2i) -> bool:
	for existing_port in ports:
		if calculate_distance(candidate, existing_port) < min_port_distance:
			return false
	return true

## Calcule la distance euclidienne entre deux positions
func calculate_distance(a: Vector2i, b: Vector2i) -> float:
	var dx: float = a.x - b.x
	var dy: float = a.y - b.y
	return sqrt(dx * dx + dy * dy)


# =========================
# GÉNÉRATION DES CASES DE PÊCHE
# =========================
func generate_fish_tiles() -> void:
	"""Place des cases de pêche sur des cases d'eau navigables, loin des ports."""
	Map_data.fish_cases.clear()

	# Candidats : cases d'eau navigables qui ne sont pas déjà des ports
	var candidates: Array = []
	for pos in Map_data.ocean_cases:
		var tile = Map_data.tiles[pos.y][pos.x]
		if tile == "water" or tile == "deepwater":
			candidates.append(pos)

	# Mélanger aléatoirement
	candidates.shuffle()

	var placed = 0
	for candidate in candidates:
		if placed >= fish_tile_count:
			break

		# Vérifier distance minimale avec les autres cases de pêche
		if not _is_valid_fish_location(candidate):
			continue

		# Vérifier qu'on n'est pas sur un port
		if Map_data.tiles[candidate.y][candidate.x] == "port":
			continue

		# Placer la case de pêche
		Map_data.tiles[candidate.y][candidate.x] = "fish"
		Map_data.fish_cases.append(candidate)
		# La case reste navigable : on la garde dans ocean_cases
		# (elle y est déjà puisqu'on pioche dedans)
		placed += 1

	# Recalculer ocean_cases maintenant que "fish" est reconnu comme eau
	# Cela garantit que les cases fish sont bien navigables
	compute_ocean_cases()

	DEBUG.log("[FISH] %d cases de pêche générées sur %d demandées" % [placed, fish_tile_count])


func _is_valid_fish_location(candidate: Vector2i) -> bool:
	"""Vérifie que le candidat respecte la distance minimale avec les autres cases de pêche."""
	for existing in Map_data.fish_cases:
		if calculate_distance(candidate, existing) < min_fish_distance:
			return false
	return true
