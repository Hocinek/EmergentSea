class_name FogManager
extends Node

# =========================
# RÉFÉRENCES
# =========================
var fog_of_war: FogOfWar
var players_manager: PlayersManager

@export var update_interval: float = 0.0
var update_timer: float = 0.0
var is_ready := false

signal fog_updated()

# =========================
# INITIALISATION
# =========================
func _ready():
	add_to_group("fog_manager")
	DEBUG.log("[FOGMGR] FogManager initialisé")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	fog_of_war = get_tree().get_first_node_in_group("fog_of_war")
	players_manager = get_tree().get_first_node_in_group("players_manager")
	if not fog_of_war:
		DEBUG.log("[FOGMGR] ERREUR: FogOfWar non trouvé!", DEBUG.ERROR)
		return
	if not players_manager:
		DEBUG.log("[FOGMGR] ERREUR: PlayersManager non trouvé!", DEBUG.ERROR)
		return
	var map_manager = get_tree().get_first_node_in_group("Map_manager")
	if map_manager:
		if not map_manager.is_connected("map_generated", _on_map_generated):
			map_manager.connect("map_generated", _on_map_generated)
	else:
		DEBUG.log("[FOGMGR] ERREUR: MapManager non trouvé!", DEBUG.ERROR)

func _on_map_generated():
	DEBUG.log("[FOGMGR] map_generated reçu")
	is_ready = true
	await get_tree().process_frame
	await get_tree().process_frame
	update_fog()

# =========================
# UPDATE
# =========================
func _process(delta):
	if not is_ready or not fog_of_war or not players_manager:
		return
	if update_interval <= 0.0:
		update_fog()
		return
	update_timer += delta
	if update_timer >= update_interval:
		update_timer = 0.0
		update_fog()

func update_fog():
	if not players_manager or not fog_of_war:
		return
	var human_player = players_manager.get_human_player()
	if not human_player:
		return
	fog_of_war.update_vision_for_player(human_player)
	emit_signal("fog_updated")

# =========================
# FONCTIONS PUBLIQUES
# =========================
func force_update():
	update_fog()

func reveal_area(center: Vector2i, radius: int):
	if not fog_of_war:
		return
	fog_of_war.reveal_area(center, radius)
	emit_signal("fog_updated")

func reveal_all():
	if not fog_of_war:
		return
	fog_of_war.reveal_all()
	emit_signal("fog_updated")

func print_fog_stats():
	if fog_of_war:
		fog_of_war.print_fog_stats()
