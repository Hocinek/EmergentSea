extends Node
class_name DedicatedServer

const PORT := 7777
const MAX_PLAYERS := 4

var peer: ENetMultiplayerPeer = null


func _ready() -> void:
	# Ce script ne tourne que si on est en mode serveur dédié
	if not OS.has_feature("dedicated_server") and not "--server" in OS.get_cmdline_args():
		return

	print("[SERVER] Démarrage du serveur dédié sur le port %d..." % PORT)
	_start_server()


func _start_server() -> void:
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_server(PORT, MAX_PLAYERS)
	if error != OK:
		push_error("[SERVER] Impossible de démarrer le serveur : " + str(error))
		return

	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	print("[SERVER] Serveur démarré et en écoute sur le port %d" % PORT)


func _on_peer_connected(peer_id: int) -> void:
	print("[SERVER] Joueur connecté : peer_id=%d — Total : %d joueur(s)" % [
		peer_id, multiplayer.get_peers().size()
	])


func _on_peer_disconnected(peer_id: int) -> void:
	print("[SERVER] Joueur déconnecté : peer_id=%d — Total : %d joueur(s)" % [
		peer_id, multiplayer.get_peers().size()
	])
