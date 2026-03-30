class_name FogOfWar
extends Node2D

enum FogState {
	UNEXPLORED,
	EXPLORED,
	VISIBLE
}

# =========================
# CONFIGURATION
# =========================
@export var vision_radius: int = 5
@export var unexplored_opacity: float = 0.95
@export var explored_opacity: float = 0.5

# =========================
# DONNÉES INTERNES
# =========================
var fog_states := {}
var explored_snapshots := {}
var fog_texture: Texture2D = null
var is_initialized := false

# =========================
# INITIALISATION
# =========================
func _ready():
	add_to_group("fog_of_war")
	z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	z_as_relative = false
	DEBUG.log("[FOG] FogOfWar initialisé")
	fog_texture = Map_data.TileMountain
	if not fog_texture:
		DEBUG.log("[FOG] ERREUR: Texture de montagne non trouvée!", DEBUG.ERROR)
		return
	var map_manager = get_tree().get_first_node_in_group("Map_manager")
	if map_manager:
		if not map_manager.is_connected("map_generated", _on_map_generated):
			map_manager.connect("map_generated", _on_map_generated)
	else:
		DEBUG.log("[FOG] ERREUR: MapManager non trouvé!", DEBUG.ERROR)

func _on_map_generated():
	await get_tree().process_frame
	await get_tree().process_frame
	initialize_fog()

# =========================
# CRÉATION DU BROUILLARD
# =========================
func initialize_fog():
	fog_states.clear()
	explored_snapshots.clear()
	for y in range(Map_data.map_height):
		for x in range(Map_data.map_width):
			fog_states[Vector2i(x, y)] = FogState.UNEXPLORED
	is_initialized = true
	queue_redraw()
	DEBUG.log("[FOG] Brouillard initialisé sur %d cases" % fog_states.size())

# =========================
# RENDU
# =========================
func _draw():
	if not is_initialized or not fog_texture:
		return
	for pos in fog_states.keys():
		match fog_states[pos]:
			FogState.UNEXPLORED:
				draw_fog_tile(pos, unexplored_opacity, Color.BLACK)
			FogState.EXPLORED:
				draw_fog_tile(pos, explored_opacity, Color(0.3, 0.3, 0.3))
			FogState.VISIBLE:
				pass

func draw_fog_tile(pos: Vector2i, opacity: float, tint: Color):
	var world_pos = Map_utils.case_vers_monde(pos)
	var local_pos = world_pos - global_position
	var scale_x = Map_data.hex_width / fog_texture.get_width()
	var scale_y = Map_data.hex_height / fog_texture.get_height()
	var final_color = Color(tint.r, tint.g, tint.b, opacity)
	draw_set_transform(local_pos, 0, Vector2(scale_x, scale_y))
	draw_texture(fog_texture, -fog_texture.get_size() / 2, final_color)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

# =========================
# MISE À JOUR DE LA VISION
# =========================
func update_vision_for_player(player: Player):
	if not is_initialized or player == null or not player.is_human:
		return
	var player_ships = player.get_navires()
	var explored_count = 0
	for pos in fog_states.keys():
		if fog_states[pos] == FogState.VISIBLE:
			fog_states[pos] = FogState.EXPLORED
			explored_count += 1
	var revealed_count = 0
	for ship in player_ships:
		if ship is Navires and ship.is_alive():
			revealed_count += reveal_around_position(ship.case_actuelle)
	if explored_count > 0 or revealed_count > 0:
		DEBUG.log("[FOG] Révélé %d nouvelles cases" % revealed_count)
		queue_redraw()

func reveal_around_position(center: Vector2i) -> int:
	var count = 0
	for dy in range(-vision_radius, vision_radius + 1):
		for dx in range(-vision_radius, vision_radius + 1):
			var pos = Vector2i(center.x + dx, center.y + dy)
			if not Map_utils.is_case_valid(pos):
				continue
			if sqrt(dx * dx + dy * dy) > vision_radius:
				continue
			if reveal_tile(pos):
				count += 1
	return count

func reveal_tile(pos: Vector2i) -> bool:
	if not fog_states.has(pos):
		return false
	var old_state = fog_states[pos]
	if old_state == FogState.VISIBLE:
		return false
	if old_state == FogState.UNEXPLORED:
		capture_snapshot(pos)
	fog_states[pos] = FogState.VISIBLE
	return true

# =========================
# SNAPSHOTS
# =========================
func capture_snapshot(pos: Vector2i):
	if pos.y >= Map_data.tiles.size() or pos.x >= Map_data.tiles[pos.y].size():
		return
	explored_snapshots[pos] = {
		"terrain": Map_data.tiles[pos.y][pos.x],
		"timestamp": Time.get_ticks_msec()
	}

# =========================
# REQUÊTES
# =========================
func is_tile_visible(pos: Vector2i) -> bool:
	if not fog_states.has(pos):
		return false
	return fog_states[pos] == FogState.VISIBLE

func is_tile_explored(pos: Vector2i) -> bool:
	if not fog_states.has(pos):
		return false
	return fog_states[pos] in [FogState.EXPLORED, FogState.VISIBLE]

func get_fog_state(pos: Vector2i) -> FogState:
	return fog_states.get(pos, FogState.UNEXPLORED)

# =========================
# UTILITAIRES
# =========================
func reset_fog():
	for pos in fog_states.keys():
		fog_states[pos] = FogState.UNEXPLORED
	explored_snapshots.clear()
	queue_redraw()

func reveal_all():
	for pos in fog_states.keys():
		if fog_states[pos] == FogState.UNEXPLORED:
			capture_snapshot(pos)
		fog_states[pos] = FogState.VISIBLE
	queue_redraw()

func reveal_area(center: Vector2i, radius: int):
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var pos = Vector2i(center.x + dx, center.y + dy)
			if not Map_utils.is_case_valid(pos):
				continue
			if sqrt(dx * dx + dy * dy) > radius:
				continue
			reveal_tile(pos)
	queue_redraw()

# =========================
# DEBUG (F1/F2/F3)
# =========================
func print_fog_stats():
	var unexplored = 0
	var explored = 0
	var visible = 0
	for state in fog_states.values():
		match state:
			FogState.UNEXPLORED: unexplored += 1
			FogState.EXPLORED: explored += 1
			FogState.VISIBLE: visible += 1
	var total = unexplored + explored + visible
	
	return {
		"unexplored": unexplored,
		"explored": explored,
		"visible": visible,
		"total": total,
		"unexplored_percent": (unexplored * 100.0 / total) if total > 0 else 0.,
		"explored_percent": (explored * 100.0 / total) if total > 0 else 0.,
		"visible_percent": (visible * 100.0 / total) if total > 0 else 0.
	}

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F1:
				reveal_all()
				DEBUG.log("[FOG] TEST - RÉVÉLATION TOTALE (F1)")
			KEY_F2:
				reset_fog()
				DEBUG.log("[FOG] TEST - RESET TOTAL (F2)")
			KEY_F3:
				print_fog_stats()
