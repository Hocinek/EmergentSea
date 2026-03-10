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
	local_peer_id = multiplayer.get_unique_id()
	local_player_id = 1
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


func is_host() -> bool:
	return multiplayer.has_multiplayer_peer() and multiplayer.is_server()


func _on_connected_to_server() -> void:
	local_peer_id = multiplayer.get_unique_id()
	local_player_id = 2
	join_succeeded.emit()


func _on_connection_failed() -> void:
	join_failed.emit()


func _on_peer_connected(peer_id: int) -> void:
	peer_joined.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	peer_left.emit(peer_id)
