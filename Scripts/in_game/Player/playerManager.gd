extends Node
class_name PlayersManager

## Liste de tous les joueurs de la partie
var players: Array[Player] = []

## Joueur dont c'est le tour
var current_player: Player = null
var current_player_id: int = 0


# ===============================
# INITIALISATION
# ===============================
func _ready():
	# S'ajouter au groupe pour être trouvable
	add_to_group("players_manager")
	
	players.clear()
	DEBUG.log("PlayersManager initialisé")


# ===============================
# CREATION DES JOUEURS
# ===============================
func create_player(
	player_id: int,
	player_name: String,
	is_human: bool = true
) -> Player:
	
	var player_scene := preload("res://Scenes/in_game/ENTITIES/Player.tscn")
	var player: Player = player_scene.instantiate()
	
	player.player_id = player_id
	player.player_name = player_name
	player.is_human = is_human
	
	add_child(player)
	players.append(player)
	
	
	# Si c'est le premier joueur créé, on le définit comme joueur courant
	if current_player == null:
		current_player = player
		current_player_id = 0
	
	return player


# ===============================
# ACCES AUX JOUEURS
# ===============================
func get_player_by_id(player_id: int) -> Player:
	for p in players:
		if p.player_id == player_id:
			return p
	return null


func get_all_players() -> Array[Player]:
	return players


func get_enemy_players(of_player: Player) -> Array[Player]:
	var enemies: Array[Player] = []
	for p in players:
		if p != of_player:
			enemies.append(p)
	return enemies


func get_human_player() -> Player:
	"""Retourne le premier joueur humain trouvé"""
	for player in players:
		if player.is_human:
			return player
	return null


# ===============================
# GESTION DES TOURS
# ===============================
func get_current_player() -> Player:
	return current_player


func next_turn() -> Player:
	if players.is_empty():
		return null
	
	current_player_id = (current_player_id + 1) % players.size()
	current_player = players[current_player_id]
	
	return current_player


func set_current_player(player: Player):
	if players.has(player):
		current_player = player
		current_player_id = players.find(player)
