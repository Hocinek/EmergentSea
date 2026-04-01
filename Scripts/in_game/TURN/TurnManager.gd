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

# Durée "freeze" simulée pour l'IA (tant que tu n'as pas le vrai code IA)
@export var ai_turn_delay_sec: float = 1.5


func _enter_tree() -> void:
	add_to_group("turn_manager")


# =========================================================
# Public API
# =========================================================

func start_game(players_list: Array[Player]) -> void:
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

	# Sécurité : si l’index dépasse après filtrage
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


# ===============================
# FIN DE PARTIE
# ===============================

# Regarde combien de poissons un joueur a.
func somme_poisson(player:Player)-> int:
	var nb_total_poissons: int = 0
	for navire in player.navires :
		nb_total_poissons += navire.nourriture
	return nb_total_poissons


# Regarde combien de navires un joueur a.
func somme_navire(player:Player)-> int:
	var nb_total_navires: int = 0
	for navire in player.navires :
		nb_total_navires += 1
	return nb_total_navires


# Regarde le nombre de ports qu'un joueur contrôle.
func somme_port_joueur(player:Player)-> int:
	var nb_total_ports: int = 0
	for port in player.ports :
		nb_total_ports += 1
	return nb_total_ports


# Regarde le nombre total de ports sur la carte
func calcul_nb_port()-> int:
	var nb_ports_carte: int = 0
	for current_player in players:
		nb_ports_carte += somme_port_joueur(current_player)
	return nb_ports_carte


# Regarde si un joueur respecte les conditions de victoire.
func fin_de_partie()-> void:
	players = _filter_alive_players(players)
	for current_player in players :
		if somme_poisson(current_player) >= 150 :
			game_over.emit(current_player)
			DEBUG.log("Le joueur a gagné par accumulation de 150 poissons.")
			game_over_panel.show_game_over()
		elif somme_navire(current_player) >= 30:
			game_over.emit(current_player)
			DEBUG.log("Le joueur a gagné par accumulation de 30 bateaux.")
			game_over_panel.show_game_over()
		elif somme_port_joueur(current_player) >= (2/3)*calcul_nb_port() :
			game_over.emit(current_player)
			DEBUG.log("Le joueur a gagné par conquête des deux tiers des ports de la carte.")
			game_over_panel.show_game_over()
		elif len(players) == 1 :
			game_over.emit(players[0])
			DEBUG.log("Le joueur a gagné par annihilation des autres joueurs.")
			game_over_panel.show_game_over()
