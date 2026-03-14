extends Node
class_name NetworkManager

signal host_started
signal join_succeeded
signal join_failed
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)

var peer: ENetMultiplayerPeer = null
var local_peer_id: int = -1
var local_player_id: int = -1

# Mapping peer_id -> player_id, géré par l'hôte et communiqué aux clients
# L'hôte = peer_id 1 = player_id 1 toujours
var _peer_to_player_id: Dictionary = {}
var _next_player_id: int = 2  # L'hôte prend le 1, les clients commencent à 2


func _enter_tree() -> void:
	add_to_group("network_manager")


func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func host_game(port: int = 7777) -> void:
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_server(port)
	if error != OK:
		push_error("Impossible de créer le serveur : " + str(error))
		return
	multiplayer.multiplayer_peer = peer
	local_peer_id = multiplayer.get_unique_id()  # = 1 pour l'hôte
	local_player_id = 1
	_peer_to_player_id[local_peer_id] = local_player_id
	_next_player_id = 2
	host_started.emit()


func join_game(ip: String, port: int = 7777) -> void:
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_client(ip, port)
	if error != OK:
		push_error("Impossible de rejoindre le serveur : " + str(error))
		join_failed.emit()
		return
	multiplayer.multiplayer_peer = peer


func shutdown() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	peer = null
	local_peer_id = -1
	local_player_id = -1
	_peer_to_player_id.clear()
	_next_player_id = 2
	Map_data.gen_seed = 0


func is_host() -> bool:
	return multiplayer.has_multiplayer_peer() and multiplayer.is_server()


func get_connected_peer_count() -> int:
	return multiplayer.get_peers().size()


# =============================================================
# CALLBACKS RÉSEAU
# =============================================================

func _on_connected_to_server() -> void:
	local_peer_id = multiplayer.get_unique_id()
	# Le player_id local sera assigné dynamiquement par l'hôte via RPC
	# On attend le RPC _rpc_assign_player_id avant d'émettre join_succeeded
	# (l'hôte va appeler ce RPC dès qu'il reçoit peer_connected)


func _on_connection_failed() -> void:
	join_failed.emit()


func _on_peer_connected(peer_id: int) -> void:
	if is_host():
		# Vérifier qu'on n'a pas dépassé 4 joueurs
		if _next_player_id > 4:
			push_warning("[NETWORK] Maximum de 4 joueurs atteint, peer %d ignoré" % peer_id)
			return

		# Assigner un player_id à ce nouveau peer
		var assigned_id := _next_player_id
		_peer_to_player_id[peer_id] = assigned_id
		_next_player_id += 1

		# Informer ce peer de son player_id
		_rpc_assign_player_id.rpc_id(peer_id, assigned_id)

	peer_joined.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	if is_host():
		_peer_to_player_id.erase(peer_id)
	peer_left.emit(peer_id)


# =============================================================
# RPC ASSIGNATION PLAYER_ID
# =============================================================

# Appelé par l'hôte sur le client pour lui communiquer son player_id
@rpc("authority", "call_remote", "reliable")
func _rpc_assign_player_id(assigned_player_id: int) -> void:
	local_player_id = assigned_player_id

	# Mettre à jour le MatchContext si déjà disponible
	var match_context = get_tree().get_first_node_in_group("match_context")
	if match_context != null:
		match_context.configure_multi(local_player_id)

	# Maintenant que l'on connaît son player_id, on peut signaler que la connexion est réussie
	join_succeeded.emit()


# =============================================================
# UTILITAIRES
# =============================================================

func get_player_id_for_peer(peer_id: int) -> int:
	return _peer_to_player_id.get(peer_id, -1)
