extends Node
class_name MultiplayerMatchBootstrap

func _enter_tree() -> void:
	add_to_group("multiplayer_bootstrap")

var network_manager: NetworkManager = null
var match_context: MatchContext = null


func _ready() -> void:
	network_manager = get_tree().get_first_node_in_group("network_manager")
	match_context = get_tree().get_first_node_in_group("match_context")


func configure_host_lobby() -> void:
	if network_manager == null:
		network_manager = get_tree().get_first_node_in_group("network_manager")
	if match_context == null:
		match_context = get_tree().get_first_node_in_group("match_context")

	if network_manager == null or match_context == null:
		push_error("[MULTI BOOTSTRAP] NetworkManager ou MatchContext introuvable")
		return

	match_context.configure_multi(network_manager.local_player_id)
	match_context.register_player(1, MatchContext.PlayerKind.HUMAN, network_manager.local_peer_id)


func configure_client_lobby() -> void:
	if network_manager == null:
		network_manager = get_tree().get_first_node_in_group("network_manager")
	if match_context == null:
		match_context = get_tree().get_first_node_in_group("match_context")

	if network_manager == null or match_context == null:
		push_error("[MULTI BOOTSTRAP] NetworkManager ou MatchContext introuvable")
		return

	match_context.configure_multi(network_manager.local_player_id)


func register_remote_player(player_id: int, peer_id: int) -> void:
	if match_context == null:
		match_context = get_tree().get_first_node_in_group("match_context")

	if match_context == null:
		push_error("[MULTI BOOTSTRAP] MatchContext introuvable")
		return

	match_context.register_player(player_id, MatchContext.PlayerKind.HUMAN, peer_id)
