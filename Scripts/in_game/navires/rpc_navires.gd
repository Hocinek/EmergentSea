class_name RPC_Navires
extends Node

var ship : Navires = null
var network_manager : NetworkManager = null

func _init(navire:Navires):
	self.ship = navire
    if network_manager == null:
		network_manager = get_tree().get_first_node_in_group("network_manager")

func attack(target_ship_id: int, damage: int):
	if multiplayer.has_multiplayer_peer():
		_rpc_apply_damage(target_ship_id, damage)
	pass
	
func move(case_x: int, case_y: int, world_x: float, world_y: float, rotation_angle: float):
	if multiplayer.has_multiplayer_peer():
		_rpc_sync_position(case_x, case_y, world_x, world_y, rotation_angle)
	pass


## Synchronise la position d'un navire sur tous les autres peers
@rpc("any_peer", "call_remote", "reliable")
func _rpc_sync_position(case_x: int, case_y: int, world_x: float, world_y: float, rotation_angle: float) -> void:
	if ship._is_local_human_owner():
		return
	ship.case_actuelle = Vector2i(case_x, case_y)
	ship.global_position = Vector2(world_x, world_y)
	ship.target_rotation_angle = rotation_angle
	ship._set_visual_rotation(rotation_angle)
	ship._update_visibility_in_fog()

## Le client envoie une demande de dégât à l'hôte
@rpc("any_peer", "call_remote", "reliable")
func _rpc_sync_damage(target_ship_id: int, damage: int) -> void:
	if network_manager == null:
		network_manager = get_tree().get_first_node_in_group("network_manager")
	if network_manager == null or not network_manager.is_host():
		return
	# L'hôte valide et broadcaste
	_rpc_apply_damage.rpc(target_ship_id, damage)


## Appliqué sur tous les peers : infliger les dégâts au navire cible
@rpc("any_peer", "call_local", "reliable")
func _rpc_apply_damage(target_ship_id: int, damage: int) -> void:
	var all_ships = get_tree().get_nodes_in_group("ships")
	for a_ship in all_ships:
		if a_ship is Navires and a_ship.id == target_ship_id:
			a_ship.take_damage(damage)
			return
