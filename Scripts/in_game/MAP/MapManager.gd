class_name MapManager
extends Node2D

## Permettra de signaler la fin de la génération de la map
signal map_generated
## Permet de signaler qu'une case a été cliquée
signal cell_clicked(cell: HexCell)

@export var map_gen : Map_gen
@export var map_utils : Map_utils

var grid : HexGrid
var fish_manager : FishManager


func _enter_tree():
	add_to_group("Map_manager")
	grid = HexGrid.new()
	add_child(grid)
	Map_data.new()
	map_gen = Map_gen.new()
	map_utils = Map_utils.new()
	add_child(map_gen)
	# Instancier le FishManager ici pour qu'il soit disponible dès la scène
	fish_manager = FishManager.new()
	add_child(fish_manager)
	
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
		# Initialiser les stocks de pêche MAINTENANT que fish_cases est rempli
		fish_manager.initialize_fish_tiles()
		DEBUG.log("FishManager initialisé (%d cases)" % Map_data.fish_cases.size())
		# Signaler que la map est générée
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
	# On récupère le type de terrain depuis la cellule
	s.texture = cell.getTileTexture()
	if(s.texture == Map_data.TileMissing):
		DEBUG.log("Texture manquante pour le terrain '%s'" % cell.getTypeTerrain(),DEBUG.WARNING)
	
	var scale_x = Map_data.hex_width / s.texture.get_width()
	var scale_y = Map_data.hex_height / s.texture.get_height()
	s.scale = Vector2(scale_x, scale_y)

	# Utilisation des coordonnées offset stockées dans la cellule
	var offset_coords = cell.getTabCoordinates()
	var pixel_pos = Map_utils.hex_to_pixel_iso(offset_coords.x, offset_coords.y)
	s.position = pixel_pos
				
	add_child(s)
	
	if cell.getTypeTerrain() == "port":
		var port_node = Map_data.port_scene.instantiate()
		port_node.position = pixel_pos
		port_node.setCell(cell)
		add_child(port_node)
		
		cell.port_instance = port_node
		
		

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_global_mouse_position()
		
		var clicked_cell = grid.get_cell_from_world(mouse_pos)
		
		if clicked_cell != null:
			emit_signal("cell_clicked", clicked_cell)
			var terrain = clicked_cell.getTypeTerrain()
			# Si c'est un port et qu'il y a bien une instance de port attachée
			if terrain == "port" and clicked_cell.port_instance != null:
				clicked_cell.port_instance.on_clicked()
				get_viewport().set_input_as_handled()
