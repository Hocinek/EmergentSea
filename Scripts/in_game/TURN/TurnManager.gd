extends Node
class_name TurnManager

signal turn_started(player: Player)
signal turn_ended(player: Player)
signal active_player_changed(player: Player)
signal game_over(winner: Player)

var players: Array[Player] = []
var current_player_index: int = 0
var current_player: Player = null

var state: TurnState.State = TurnState.State.IDLE
var game_over_panel : UI_game_over


func _enter_tree() -> void:
	add_to_group("turn_manager")


# =========================================================
# Public API
# =========================================================

func start_game(players_list: Array[Player]) -> void:
	var label = get_tree().get_first_node_in_group("ai_turn_label")
	if label:
		label.visible = false

	players = _filter_alive_players(players_list)
	current_player_index = 0

	if players.is_empty():
		state = TurnState.State.GAME_OVER
		game_over.emit(null)
		return

	current_player = players[current_player_index]
	_start_turn()


func end_turn() -> void:
	# On n'accepte le clic que si c'est un tour jouable
	if state != TurnState.State.PLAYER_ACTION:
		return

	# 1) Fin du tour du joueur courant
	state = TurnState.State.ENDING_TURN
	turn_ended.emit(current_player)

	# Appliquer les effets de fin de tour de l'équipage (soin, poissons passifs…)
	for n in current_player.get_navires():
		if is_instance_valid(n) and n.is_alive():
			n.apply_crew_end_of_turn()

	# Attaques des ports ennemis/neutres ---
	_ports_attack_current_player()
	
	# 2) On vérifie si les conditions de fin de partie sont atteintes.
	fin_de_partie()

	# 3) Passer au joueur suivant
	_advance_to_next_player()

	if current_player == null:
		state = TurnState.State.GAME_OVER
		game_over.emit(null)
		return

	# 4) Démarrer son tour
	_start_turn()

	# 5) SI c'est une IA, on joue automatiquement son tour,
	#    puis on boucle jusqu'à retomber sur un humain.
	await _auto_run_non_human_turns_until_human()


func can_navire_act(navire: Navires) -> bool:
	if state != TurnState.State.PLAYER_ACTION:
		return false
	if navire == null or not is_instance_valid(navire):
		return false
	if not navire.is_alive():
		return false
	if navire.player_owner == null:
		return false

	return navire.player_owner == current_player


# =========================================================
# Internals
# =========================================================

func _start_turn() -> void:
	state = TurnState.State.STARTING_TURN

	# Reset énergie des navires du joueur actif
	for n in current_player.get_navires():
		if is_instance_valid(n) and n.is_alive():
			n.reset_energie()
	
	DEBUG.log("[TURNMANAGER] Tour du joueur %s" % current_player.player_name)

	state = TurnState.State.PLAYER_ACTION
	active_player_changed.emit(current_player)
	turn_started.emit(current_player)


func _auto_run_non_human_turns_until_human() -> void:
	# Si tu n'as pas de propriété is_human sur Player, c'est ici que ça plantera.
	# Dans ton projet, tu l'utilises déjà (Navires / GameManager), donc c'est OK.
	while current_player != null and state == TurnState.State.PLAYER_ACTION and (not current_player.is_human):
		# "Freeze" : le joueur humain ne doit rien pouvoir faire pendant ce temps
		# -> on met l'état à ENDING_TURN pour bloquer can_navire_act / inputs
		state = TurnState.State.ENDING_TURN

		# Simuler le tour IA (remplacer par ton vrai code IA plus tard)
		await _simulate_ai_turn(current_player)

		# Fin du tour IA
		turn_ended.emit(current_player)

		# Appliquer les effets de fin de tour de l'équipage IA (soin, poissons passifs…)
		for n in current_player.get_navires():
			if is_instance_valid(n) and n.is_alive():
				n.apply_crew_end_of_turn()

		fin_de_partie()
		
		# Joueur suivant
		_advance_to_next_player()

		if current_player == null:
			state = TurnState.State.GAME_OVER
			game_over.emit(null)
			return

		# Démarrer le tour suivant (peut être humain ou IA)
		_start_turn()


func _simulate_ai_turn(ai_player: Player) -> void:
	# Récupérer le label qui affiche "Tour de l'IA..."
	var label = get_tree().get_first_node_in_group("ai_turn_label")

	# Afficher le message à l'écran
	if label:
		label.visible = true
	var navires_ia = ai_player.get_navires()
	
	for navire in navires_ia:
		if is_instance_valid(navire) and navire.is_alive():
			# On cherche le noeud IA enfant du navire (adapte le nom selon ton arbre)
			var noeud_ia = navire.get_node_or_null("IA") 
			if noeud_ia:
				if noeud_ia.has_method("jouer_tour"):
					noeud_ia.jouer_tour()
					
					# Attendre un tout petit peu entre chaque action de navire 
					# pour que le joueur humain ait le temps de voir ce qu'il se passe
					await get_tree().create_timer(1.0).timeout
				else:
					DEBUG.log("[TURNMANAGER] Seems like the IA's script is missing a method, please fix it (missing (jouer_tour())",DEBUG.ERROR)
			else:
				DEBUG.log("[TURNMANAGER] Can't find AI node attached to the ship",DEBUG.ERROR)

	# Masquer le message une fois le tour terminé
	if label:
		label.visible = false


func _advance_to_next_player() -> void:
	players = _filter_alive_players(players)

	if players.is_empty():
		current_player = null
		return

	# Sécurité : si l'index dépasse après filtrage
	if current_player_index >= players.size():
		current_player_index = 0

	# next
	current_player_index = (current_player_index + 1) % players.size()
	current_player = players[current_player_index]


func _filter_alive_players(list_in: Array[Player]) -> Array[Player]:
	var out: Array[Player] = []
	for p in list_in:
		if p != null and is_instance_valid(p) and p.has_alive_navires():
			out.append(p)
	return out


# =========================================================
# Fin de partie
# =========================================================
func somme_poisson(player: Player) -> int:
	var total := 0
	for navire in player.navires:
		total += navire.nourriture
	return total


func somme_navire(player: Player) -> int:
	return player.navires.size()


func somme_port_joueur(player: Player) -> int:
	return player.ports.size()

# Calcul le nombre de ports sur toute la carte
func calcul_nb_port() -> int:
	var total := 0
	for p in players:
		total += somme_port_joueur(p)
	return total


func fin_de_partie() -> void:
	players = _filter_alive_players(players)
	for player in players:
		var raison := ""
		if somme_poisson(player) >= 300 :
			raison = "accumulation de 300 poissons"
		elif somme_navire(player) >= 30:
			raison = "accumulation de 30 navires"
		#elif somme_port_joueur(player) >= int(calcul_nb_port() * 2.0 / 3.0):
		#	raison = "conquête des deux tiers des ports"
		if raison != "":
			DEBUG.log("Le joueur %s a gagné par %s." % [player.player_name, raison])
			_trigger_game_over(player, raison)
			return
	if players.size() == 1:
		_trigger_game_over(players[0], "annihilation des adversaires")


func _trigger_game_over(winner: Player, raison: String) -> void:
	state = TurnState.State.GAME_OVER
	game_over.emit(winner)
	if game_over_panel != null:
		game_over_panel.show_game_over(winner, raison)
	else:
		DEBUG.log("[TURNMANAGER] game_over_panel est null — assigne-le depuis le GameManager.", DEBUG.ERROR)


# =========================================================
# Attaque des ports
# =========================================================

## Tous les ports neutres ou ennemis attaquent les navires du joueur qui vient de finir son tour.
func _ports_attack_current_player() -> void:
	var all_ports = get_tree().get_nodes_in_group("ports")
	for port in all_ports:
		if port is Ports and is_instance_valid(port):
			port.attack_nearby_ships(current_player)
