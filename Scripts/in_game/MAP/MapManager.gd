class_name MapManager
extends Node

signal map_generated

@export var map_gen : Map_gen
@export var map_utils : Map_utils

var grid : HexGrid


func _enter_tree():
	add_to_group("Map_manager")
	grid = HexGrid.new()
	add_child(grid)
	Map_data.new()
	map_gen = Map_gen.new()
	map_utils = Map_utils.new()
	add_child(map_gen)


func _ready():
	var network_manager: NetworkManager = get_tree().get_first_node_in_group("network_manager")

	if network_manager == null or not network_manager.multiplayer.has_multiplayer_peer():
		# Mode solo : génération immédiate comme avant
		await _generate_and_render()
	elif network_manager.is_host():
		# Mode multi hôte : générer puis envoyer la seed aux clients
		await _generate_and_render()
		_rpc_sync_seed.rpc(Map_data.gen_seed)
	else:
		# Mode multi client : attendre la seed de l'hôte, ne pas générer tout de suite
		pass


# =============================================================
# GÉNÉRATION ET RENDU (commun hôte + solo)
# =============================================================

func _generate_and_render() -> void:
	await get_tree().process_frame
	var is_map_gen = map_gen.generate()
	if is_map_gen:
		DEBUG.log("Map générée")
		grid.generate_hex_grid_rectangular()
		grid.import_from_map_data()
		render_map_from_grid()
		DEBUG.log("Rendu de la map effectué")
		await get_tree().process_frame
		emit_signal("map_generated")


# =============================================================
# RPC SYNC SEED (hôte → clients)
# =============================================================

@rpc("any_peer", "call_remote", "reliable")
func _rpc_sync_seed(seed: int) -> void:
	# Le client reçoit la seed, l'applique et génère la même map
	Map_data.gen_seed = seed
	await _generate_and_render()


# =============================================================
# RENDU
# =============================================================

func render_map_from_grid():
	for cell in grid.cells.values():
		spawn_tile_object(cell)


func spawn_tile_object(cell: HexCell):
	var s := Sprite2D.new()
	s.centered = true

	match cell.terrain_type:
		"deepwater": s.texture = Map_data.TileDeepWater
		"water":     s.texture = Map_data.TileWater
		"sand":      s.texture = Map_data.TileSand
		"earth":     s.texture = Map_data.TileEarth
		"forest":    s.texture = Map_data.TileForest
		"mountain":  s.texture = Map_data.TileMountain
		"port":
			if "TilePort" in Map_data:
				s.texture = Map_data.TilePort
			else:
				s.texture = Map_data.TileSand
				DEBUG.log("TilePort non trouvé, utilisation de TileSand", DEBUG.WARNING)

	var scale_x = Map_data.hex_width / s.texture.get_width()
	var scale_y = Map_data.hex_height / s.texture.get_height()
	s.scale = Vector2(scale_x, scale_y)
	s.position = Map_utils.hex_to_pixel_iso(cell.offset_coords.x, cell.offset_coords.y)

	add_child(s)
