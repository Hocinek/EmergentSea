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
var game_over_panel : UI_game_over


func _enter_tree() -> void:
	name = "MultiplayerTurnManager" 
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


func request_end_turn() -> void:
	if network_manager == null:
		network_manager = get_tree().get_first_node_in_group("network_manager")

	if match_context == null:
		match_context = get_tree().get_first_node_in_group("match_context")

	if not match_context.is_local_turn():
		return

	if state != MultiplayerTurnState.State.PLAYER_ACTION:
		return

	if network_manager != null and network_manager.is_host():
		_process_end_turn()
	else:
		_rpc_request_end_turn.rpc(match_context.local_player_id)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_end_turn(requesting_player_id: int) -> void:
	if network_manager == null:
		network_manager = get_tree().get_first_node_in_group("network_manager")
	if not network_manager.is_host():
		return

	if match_context == null:
		match_context = get_tree().get_first_node_in_group("match_context")

	if match_context.active_player_id != requesting_player_id:
		push_warning("[MULTI TURN] Demande de fin de tour refusée : ce n'est pas le tour du joueur %d" % requesting_player_id)
		return

	_process_end_turn()


func _process_end_turn() -> void:
	if players.is_empty() or current_player == null:
		return

	if state != MultiplayerTurnState.State.PLAYER_ACTION:
		return

	var previous_player = current_player
	turn_ended.emit(previous_player)

	# Appliquer les effets de fin de tour de l'équipage (soin, poissons passifs…)
	# On broadcaste uniquement le DELTA (diff avant/après) pour ne pas écraser
	# les valeurs absolues que l'hôte ne connaît pas forcément à jour (ex : joueur 2).
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	for n in previous_player.get_navires():
		if is_instance_valid(n) and n.is_alive():
			var vie_avant        : int = n.vie
			var nourriture_avant : int = n.nourriture
			n.apply_crew_end_of_turn()
			var delta_vie        : int = n.vie        - vie_avant
			var delta_nourriture : int = n.nourriture - nourriture_avant
			if (delta_vie != 0 or delta_nourriture != 0) and game_manager \
					and game_manager.has_method("sync_end_of_turn_delta_networked"):
				game_manager.sync_end_of_turn_delta_networked(n.id, delta_vie, delta_nourriture, n.maxvie)

	# Attaques des ports ennemis/neutres
	_ports_attack_current_player(previous_player)

	# Vérification des conditions de victoire — hôte uniquement, puis broadcast si game over
	if network_manager != null and network_manager.is_host():
		fin_de_partie()
		if state == MultiplayerTurnState.State.GAME_OVER:
			return

	var current_index := players.find(current_player)
	if current_index == -1:
		current_index = 0

	var next_index := (current_index + 1) % players.size()
	current_player = players[next_index]

	_rpc_sync_active_player.rpc(current_player.player_id)


@rpc("any_peer", "call_local", "reliable")
func _rpc_sync_active_player(active_player_id: int) -> void:
	if match_context == null:
		match_context = get_tree().get_first_node_in_group("match_context")

	var players_manager = get_tree().get_first_node_in_group("players_manager")
	if players_manager == null:
		push_error("[MULTI TURN] PlayersManager introuvable")
		return

	var new_active_player = players_manager.get_player_by_id(active_player_id)
	if new_active_player == null:
		push_error("[MULTI TURN] Joueur %d introuvable" % active_player_id)
		return

	if players.is_empty():
		players = players_manager.get_all_players().duplicate()

	current_player = new_active_player
	match_context.set_active_player(active_player_id)
	_reset_player_ships(current_player)
	_update_selection_for_active_player()
	state = MultiplayerTurnState.State.PLAYER_ACTION
	active_player_changed.emit(current_player)
	turn_started.emit(current_player)


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

	# Appliquer les effets de fin de tour de l'équipage (soin, poissons passifs…)
	for n in previous_player.get_navires():
		if is_instance_valid(n) and n.is_alive():
			n.apply_crew_end_of_turn()

	# Attaques des ports ennemis/neutres
	_ports_attack_current_player(previous_player)

	fin_de_partie()
	if state == MultiplayerTurnState.State.GAME_OVER:
		return

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


# =========================================================
# Conditions de victoire
# =========================================================

func somme_poisson(player) -> int:
	var total := 0
	for navire in player.navires:
		total += navire.nourriture
	return total


func somme_navire(player) -> int:
	return player.navires.size()


func somme_port_joueur(player) -> int:
	return player.ports.size()


# Calcule le nombre total de ports sur toute la carte
func calcul_nb_port() -> int:
	var total := 0
	for p in players:
		total += somme_port_joueur(p)
	return total


func _filter_alive_players(list_in: Array) -> Array:
	var out: Array = []
	for p in list_in:
		if p != null and is_instance_valid(p) and p.has_method("has_alive_navires") and p.has_alive_navires():
			out.append(p)
	return out


# Appelée uniquement par l'hôte (ou en local via end_turn).
# Si une condition est remplie, broadcaste le game over à tous les peers via RPC.
func fin_de_partie() -> void:
	players = _filter_alive_players(players)

	for player in players:
		var raison := ""
		if somme_poisson(player) >= 300:
			raison = "accumulation de 300 poissons"
		elif somme_navire(player) >= 30:
			raison = "accumulation de 30 navires"
		#elif somme_port_joueur(player) >= int(calcul_nb_port() * 2.0 / 3.0):
		#	raison = "conquête des deux tiers des ports"
		if raison != "":
			DEBUG.log("Le joueur %s a gagné par %s." % [player.player_name, raison])
			_rpc_sync_game_over.rpc(player.player_id, raison)
			return

	if players.size() == 1:
		_rpc_sync_game_over.rpc(players[0].player_id, "annihilation des adversaires")


# =========================================================
# Attaque des ports
# =========================================================

## Tous les ports neutres ou ennemis attaquent les navires du joueur qui vient de finir son tour.
func _ports_attack_current_player(player) -> void:
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	var all_ports = get_tree().get_nodes_in_group("ports")
	for port in all_ports:
		if not (port is Ports and is_instance_valid(port)):
			continue
		if port.player_owner != null and port.player_owner == player:
			continue  # Port ami => pas d'attaque
		var all_ships = get_tree().get_nodes_in_group("ships")
		for navire in all_ships:
			if not is_instance_valid(navire) or not navire.is_alive():
				continue
			if navire.player_owner != player:
				continue
			if port.can_attack_position(navire.case_actuelle):
				DEBUG.log("Port [%d] attaque navire [%d] pour %d dégâts" % [port.id, navire.id, port.attack_damage])
				var attacker_owner_id: int = port.player_owner.player_id if port.player_owner else -1
				if game_manager and game_manager.has_method("apply_damage_networked_port_attack"):
					game_manager.apply_damage_networked_port_attack(navire.id, port.attack_damage, attacker_owner_id)
				else:
					navire.take_damage(port.attack_damage)


## Appelé par NetworkManager quand un peer se déconnecte.
## winner_player_id = le joueur LOCAL qui reste en jeu.
func declare_winner_by_disconnect(winner_player_id: int) -> void:
	if state == MultiplayerTurnState.State.GAME_OVER:
		return
	DEBUG.log("[MULTI TURN] Victoire par forfait — gagnant player_id: %d" % winner_player_id)
	_rpc_sync_game_over.rpc(winner_player_id, "déconnexion de l'adversaire")


# L'hôte broadcaste le game over sur tous les peers + lui-même (call_local).
# Chaque peer compare le winner_player_id à son propre local_player_id
# pour afficher l'écran victoire ou défaite approprié.
@rpc("any_peer", "call_local", "reliable")
func _rpc_sync_game_over(winner_player_id: int, raison: String) -> void:
	if match_context == null:
		match_context = get_tree().get_first_node_in_group("match_context")

	var players_manager = get_tree().get_first_node_in_group("players_manager")
	if players_manager == null:
		push_error("[MULTI TURN] PlayersManager introuvable pour game over")
		_trigger_game_over(null, raison, false)
		return

	var winner = players_manager.get_player_by_id(winner_player_id)
	if winner == null:
		push_error("[MULTI TURN] Joueur gagnant %d introuvable" % winner_player_id)

	# Chaque peer sait s'il a gagné ou perdu en comparant son ID local
	var local_id := match_context.local_player_id if match_context != null else -1
	var is_winner := (local_id == winner_player_id)

	DEBUG.log("[MULTI TURN] Game over reçu — gagnant player_id: %d, local: %d, victoire: %s, raison: %s" % [
		winner_player_id, local_id, str(is_winner), raison
	])
	_trigger_game_over(winner, raison, is_winner)


# Déclenche la fin de partie localement.
# is_winner = true  → écran de victoire
# is_winner = false → écran de défaite
func _trigger_game_over(winner, raison: String, is_winner: bool = true) -> void:
	state = MultiplayerTurnState.State.GAME_OVER
	game_over.emit(winner)
	if game_over_panel != null:
		if is_winner:
			game_over_panel.show_game_over(winner, raison)  # écran victoire
		else:
			game_over_panel.show_defeat(winner, raison)     # écran défaite
	else:
		DEBUG.log("[MULTI TURN] game_over_panel est null — assigne-le depuis le GameManager.", DEBUG.ERROR)
