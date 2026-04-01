extends Node
class_name DedicatedServer

const PORT := PORT_LA
const MAX_PLAYERS := 2

var peer: ENetMultiplayerPeer = null

var _connected_peers: Array[int] = []
var _game_started: bool = false

func _enter_tree() -> void:
	if OS.has_feature("dedicated_server") or "--server" in OS.get_cmdline_args():
		add_to_group("dedicated_server")

func _ready() -> void:
	print("[SERVER] _ready() appelé, démarrage forcé...")
	_start_server()

func _start_server() -> void:
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_server(PORT, MAX_PLAYERS)
	if error != OK:
		push_error("[SERVER] Impossible de démarrer : " + str(error))
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	print("[SERVER] En écoute sur le port %d" % PORT)

func _on_peer_connected(peer_id: int) -> void:
	if _game_started:
		print("[SERVER] Refus de %d — partie déjà en cours" % peer_id)
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)
		return
	_connected_peers.append(peer_id)
	print("[SERVER] Joueur connecté : %d — Total : %d" % [peer_id, _connected_peers.size()])
	_rpc_update_player_count.rpc(_connected_peers.size())

func _on_peer_disconnected(peer_id: int) -> void:
	_connected_peers.erase(peer_id)
	print("[SERVER] Joueur déconnecté : %d — Total : %d" % [peer_id, _connected_peers.size()])
	if _connected_peers.is_empty():
		_game_started = false
		# Réinitialiser le NetworkManager côté serveur
		var nm = get_tree().get_first_node_in_group("network_manager")
		if nm:
			nm._next_player_id = 1
			nm._peer_to_player_id.clear()
		print("[SERVER] Lobby réinitialisé")
	else:
		if not _game_started:
			_rpc_update_player_count.rpc(_connected_peers.size())

@rpc("any_peer", "call_local", "reliable")
func rpc_request_start_game() -> void:
	var sender = multiplayer.get_remote_sender_id()
	if _connected_peers.is_empty() or sender != _connected_peers[0]:
		push_warning("[SERVER] Lancement non autorisé par peer %d" % sender)
		return
	if _connected_peers.size() < 2:
		push_warning("[SERVER] Pas assez de joueurs")
		return
	_game_started = true
	print("[SERVER] Lancement ! (%d joueurs)" % _connected_peers.size())

@rpc("any_peer", "call_remote", "reliable")
func _rpc_update_player_count(_count: int) -> void:
	pass
