extends Node
class_name NetworkManager

signal host_started
signal join_succeeded
signal join_failed
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
signal player_count_updated(count: int)

var SERVER_IP := "127.0.0.1"
var SERVER_PORT := 666
const MAX_PLAYERS := 2

var peer: ENetMultiplayerPeer = null
var local_peer_id: int = -1
var local_player_id: int = -1
var _peer_to_player_id: Dictionary = {}
var _next_player_id: int = 1

func _enter_tree() -> void:
	add_to_group("network_manager")

func _ready() -> void:
	var config := ConfigFile.new()
	if config:
		var network_cfg = config.load("res://Scripts/config/network.cfg")
		if network_cfg == OK:
			SERVER_PORT = config.get_value("network", "port", 666)
			SERVER_IP = config.get_value("network", "ip", "127.0.0.1")
		else:
			DEBUG.log("Fichier de configuration réseau non lisible, par défaut : %s:%d" % [SERVER_IP, SERVER_PORT],DEBUG.ERROR)
	else:
		DEBUG.log("Impossible de démarrer le lecteur du fichier de config, config par défaut utilisée : %s:%d" % [SERVER_IP, SERVER_PORT],DEBUG.ERROR)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func join_dedicated_server() -> void:
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_client(SERVER_IP, SERVER_PORT)
	if error != OK:
		push_error("[NETWORK] Impossible de se connecter : " + str(error))
		join_failed.emit()
		return
	multiplayer.multiplayer_peer = peer
	print("[NETWORK] Connexion à %s:%d..." % [SERVER_IP, SERVER_PORT])

func shutdown() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	peer = null
	local_peer_id = -1
	local_player_id = -1
	_peer_to_player_id.clear()
	_next_player_id = 1
	Map_data.gen_seed = 0

func is_host() -> bool:
	return local_player_id == 1

func get_connected_peer_count() -> int:
	return multiplayer.get_peers().size()

func broadcast_start_game() -> void:
	if not is_host():
		return
	_rpc_broadcast_start_game.rpc()

@rpc("any_peer", "call_local", "reliable")
func _rpc_broadcast_start_game() -> void:
	get_tree().change_scene_to_file("res://Scenes/in_game/MainMulti.tscn")

func _on_connected_to_server() -> void:
	local_peer_id = multiplayer.get_unique_id()
	print("[NETWORK] Connecté — peer_id=%d" % local_peer_id)
	_rpc_request_player_id.rpc_id(1)

func _on_connection_failed() -> void:
	print("[NETWORK] Connexion échouée")
	join_failed.emit()

func _on_peer_connected(peer_id: int) -> void:
	print("[NETWORK] Nouveau peer : %d" % peer_id)
	if peer_id == 1:
		return
	peer_joined.emit(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	if peer_id == 1:
		print("[NETWORK] Serveur déconnecté !")
		# L'hôte s'est déconnecté : le joueur local gagne par forfait
		_trigger_win_by_disconnect(peer_id)
		return
	_peer_to_player_id.erase(peer_id)
	peer_left.emit(peer_id)
	# Un client s'est déconnecté : le joueur local (hôte) gagne
	_trigger_win_by_disconnect(peer_id)


func _trigger_win_by_disconnect(disconnected_peer_id: int) -> void:
	print("[NETWORK] Déconnexion détectée (peer=%d) → victoire par forfait" % disconnected_peer_id)
	var turn_manager = get_tree().get_first_node_in_group("turn_manager")
	if turn_manager and turn_manager.has_method("declare_winner_by_disconnect"):
		turn_manager.declare_winner_by_disconnect(local_player_id)
	else:
		# Fallback : retour au menu principal
		get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_player_id() -> void:
	var sender = multiplayer.get_remote_sender_id()
	if _next_player_id > MAX_PLAYERS:
		push_warning("[NETWORK] Maximum de joueurs atteint")
		return
	var assigned_id := _next_player_id
	_peer_to_player_id[sender] = assigned_id
	_next_player_id += 1
	print("[NETWORK] Assignation player_id=%d à peer_id=%d" % [assigned_id, sender])
	_rpc_assign_player_id.rpc_id(sender, assigned_id)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_assign_player_id(assigned_player_id: int) -> void:
	local_player_id = assigned_player_id
	print("[NETWORK] Player ID assigné : %d" % local_player_id)
	var match_context = get_tree().get_first_node_in_group("match_context")
	if match_context != null:
		match_context.configure_multi(local_player_id)
	if local_player_id == 1:
		print("[NETWORK] Je suis l'hôte logique")
		host_started.emit()
	else:
		join_succeeded.emit()

func get_player_id_for_peer(peer_id: int) -> int:
	return _peer_to_player_id.get(peer_id, -1)

@rpc("authority", "call_local", "reliable")
func _rpc_update_player_count(count: int) -> void:
	player_count_updated.emit(count)
