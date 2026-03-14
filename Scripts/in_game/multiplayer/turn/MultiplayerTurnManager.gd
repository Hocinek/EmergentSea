extends Node
class_name MultiplayerTurnManager

signal turn_started(player)
signal turn_ended(player)
signal active_player_changed(player)
signal game_over(winner)

var players: Array = []
var current_player = null
var state: MultiplayerTurnState.State = MultiplayerTurnState.State.IDLE
var match_context: MatchContext = null
var network_manager: NetworkManager = null


func _enter_tree() -> void:
	add_to_group("turn_manager")


func _ready() -> void:
	match_context = get_tree().get_first_node_in_group("match_context")
	network_manager = get_tree().get_first_node_in_group("network_manager")


func start_game(players_list: Array) -> void:
	players = players_list.duplicate()

	if players.is_empty():
		state = MultiplayerTurnState.State.GAME_OVER
		game_over.emit(null)
		return

	if match_context == null:
		match_context = get_tree().get_first_node_in_group("match_context")
		if match_context == null:
			push_error("[MULTI TURN] MatchContext introuvable")
			return

	var first_player = players[0]
	current_player = first_player
	match_context.set_active_player(first_player.player_id)
	_reset_player_ships(current_player)
	state = MultiplayerTurnState.State.PLAYER_ACTION
	active_player_changed.emit(current_player)
	turn_started.emit(current_player)


# =============================================================
# DEMANDE DE FIN DE TOUR (appelée par UI_end_turn)
# Le joueur local envoie une demande à l'hôte.
# =============================================================

func request_end_turn() -> void:
	if network_manager == null:
		network_manager = get_tree().get_first_node_in_group("network_manager")

	if match_context == null:
		match_context = get_tree().get_first_node_in_group("match_context")

	# Vérification locale : est-ce bien mon tour ?
	if not match_context.is_local_turn():
		return

	if state != MultiplayerTurnState.State.PLAYER_ACTION:
		return

	if network_manager != null and network_manager.is_host():
		# L'hôte peut traiter directement
		_process_end_turn()
	else:
		# Le client envoie la demande à l'hôte (peer_id 1)
		_rpc_request_end_turn.rpc_id(1, match_context.local_player_id)


# =============================================================
# RPC : le client demande à l'hôte de finir le tour
# =============================================================

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_end_turn(requesting_player_id: int) -> void:
	# Seul l'hôte exécute cette fonction
	if network_manager == null:
		network_manager = get_tree().get_first_node_in_group("network_manager")
	if not network_manager.is_host():
		return

	if match_context == null:
		match_context = get_tree().get_first_node_in_group("match_context")

	# Vérifier que c'est bien le tour du joueur qui demande
	if match_context.active_player_id != requesting_player_id:
		push_warning("[MULTI TURN] Demande de fin de tour refusée : ce n'est pas le tour du joueur %d" % requesting_player_id)
		return

	_process_end_turn()


# =============================================================
# TRAITEMENT RÉEL DE LA FIN DE TOUR (hôte uniquement)
# =============================================================

func _process_end_turn() -> void:
	if players.is_empty() or current_player == null:
		return

	if state != MultiplayerTurnState.State.PLAYER_ACTION:
		return

	var previous_player = current_player
	turn_ended.emit(previous_player)

	var current_index := players.find(current_player)
	if current_index == -1:
		current_index = 0

	var next_index := (current_index + 1) % players.size()
	current_player = players[next_index]

	# Broadcaster le nouveau joueur actif à tous (y compris l'hôte lui-même)
	_rpc_sync_active_player.rpc(current_player.player_id)


# =============================================================
# RPC : l'hôte broadcaste le nouveau joueur actif à tous
# =============================================================

@rpc("authority", "call_local", "reliable")
func _rpc_sync_active_player(active_player_id: int) -> void:
	if match_context == null:
		match_context = get_tree().get_first_node_in_group("match_context")

	# Trouver le joueur correspondant dans la liste locale
	var players_manager = get_tree().get_first_node_in_group("players_manager")
	if players_manager == null:
		push_error("[MULTI TURN] PlayersManager introuvable")
		return

	var new_active_player = players_manager.get_player_by_id(active_player_id)
	if new_active_player == null:
		push_error("[MULTI TURN] Joueur %d introuvable" % active_player_id)
		return

	# Si la liste locale est vide (client), la reconstruire depuis le players_manager
	if players.is_empty():
		players = players_manager.get_all_players().duplicate()

	current_player = new_active_player
	match_context.set_active_player(active_player_id)
	_reset_player_ships(current_player)
	_update_selection_for_active_player()
	state = MultiplayerTurnState.State.PLAYER_ACTION
	active_player_changed.emit(current_player)
	turn_started.emit(current_player)


# =============================================================
# ANCIENNE MÉTHODE end_turn() conservée pour le mode solo
# NE PAS APPELER EN MODE MULTI — passe par request_end_turn()
# =============================================================

func end_turn() -> void:
	if players.is_empty():
		return
	if current_player == null:
		return
	if match_context == null:
		match_context = get_tree().get_first_node_in_group("match_context")
		if match_context == null:
			push_error("[MULTI TURN] MatchContext introuvable")
			return
	if state != MultiplayerTurnState.State.PLAYER_ACTION:
		return

	var previous_player = current_player
	turn_ended.emit(previous_player)

	var current_index := players.find(current_player)
	if current_index == -1:
		current_index = 0

	var next_index := (current_index + 1) % players.size()
	current_player = players[next_index]
	match_context.set_active_player(current_player.player_id)
	_reset_player_ships(current_player)
	_update_selection_for_active_player()
	state = MultiplayerTurnState.State.PLAYER_ACTION
	active_player_changed.emit(current_player)
	turn_started.emit(current_player)


# =============================================================
# HELPERS
# =============================================================

func _reset_player_ships(player) -> void:
	if player == null:
		return
	if not player.has_method("get_navires"):
		return
	var ships = player.get_navires()
	for ship in ships:
		if ship != null and is_instance_valid(ship) and ship.has_method("reset_energie"):
			ship.reset_energie()


func _update_selection_for_active_player() -> void:
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager == null:
		return

	if match_context != null and match_context.is_local_turn():
		if current_player != null and current_player.has_method("get_navires"):
			var ships = current_player.get_navires()
			if not ships.is_empty():
				var first_ship = ships[0]
				if first_ship != null and is_instance_valid(first_ship) and game_manager.has_method("select_ship"):
					game_manager.select_ship(first_ship)
					return

	if game_manager.has_method("deselect_ship"):
		game_manager.deselect_ship()


func can_navire_act(navire) -> bool:
	if state != MultiplayerTurnState.State.PLAYER_ACTION:
		return false
	if navire == null or not is_instance_valid(navire):
		return false
	if not navire.has_method("is_alive") or not navire.is_alive():
		return false
	if navire.player_owner == null:
		return false
	if match_context == null:
		match_context = get_tree().get_first_node_in_group("match_context")
		if match_context == null:
			return false
	return (
		match_context.is_local_player(navire.player_owner.player_id)
		and match_context.is_local_turn()
	)
