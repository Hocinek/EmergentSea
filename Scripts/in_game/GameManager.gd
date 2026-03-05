###===================================================================###
##								GameManager							   ##
# Ce script permet de coordonner le reste du jeu						#
# VERSION CORRIGÉE avec support Fog of War							#
###===================================================================###
extends Node


# Scène du navire
var navire_scene := preload("res://Scenes/in_game/Navires.tscn")

@onready var map
@onready var data
@onready var map_manager
var players_manager: PlayersManager = null

# NOUVEAU : Références fog of war
var fog_of_war: FogOfWar = null
var fog_manager: FogManager = null

# Stockage des joueurs créés
var player1: Player = null
var player2: Player = null

# NOUVEAU : Gestion de la sélection
var selected_ship: Navires = null
signal ship_selected(ship: Navires)
signal ship_deselected()

var turn_manager: TurnManager = null

# Ce qui sera dans cette fonction sera exécuté en premier (avant que le reste soit prêt)
func _enter_tree():
	add_to_group("game_manager")  # Important pour que les navires puissent trouver le GameManager
	
	map_manager = get_tree().get_first_node_in_group("Map_manager")
	data = get_tree().get_first_node_in_group("shared_entities")
	
	if not map_manager:
		DEBUG.log("Aucune carte trouvée dans le groupe 'Map_manager' !",DEBUG.ERROR)
		return
	# Connecter le signal de génération de map
	map_manager.map_generated.connect(_on_map_generated)
	
	if not data:
		DEBUG.log("Aucune donnée partagée n'est accessible !",DEBUG.ERROR)


func _ready():
	# Attendre un frame pour que tout soit bien initialisé
	await get_tree().process_frame
	
	turn_manager = get_tree().get_first_node_in_group("turn_manager")
	if not turn_manager:
		DEBUG.log("TurnManager introuvable !",DEBUG.ERROR)
	
	# Créer le système de fog of war
	_setup_fog_of_war()
	
	# Récupérer le PlayersManager
	_try_get_players_manager()

#region fonctions d'initialisation
## Setup du fog of war
func _setup_fog_of_war():
	"""Créé et configure le système de fog of war"""
	DEBUG.log("[GAMEMANAGER] Setup Fog of War...")
	
	# Vérifier si le fog existe déjà dans la scène
	fog_of_war = get_tree().get_first_node_in_group("fog_of_war")
	fog_manager = get_tree().get_first_node_in_group("fog_manager")
	
	# Si pas trouvé, créer dynamiquement
	if not fog_of_war:
		DEBUG.log("[GAMEMANAGER] Création dynamique de FogOfWar...")
		fog_of_war = FogOfWar.new()
		fog_of_war.name = "FogOfWar"
		add_child(fog_of_war)
	else:
		DEBUG.log("[GAMEMANAGER] FogOfWar trouvé dans la scène")
	
	if not fog_manager:
		DEBUG.log("[GAMEMANAGER] Création dynamique de FogManager...")
		fog_manager = FogManager.new()
		fog_manager.name = "FogManager"
		add_child(fog_manager)
	else:
		DEBUG.log("[GAMEMANAGER] FogManager trouvé dans la scène")
	
	DEBUG.log("[GAMEMANAGER] Fog of War configuré")

# Fonction utilitaire pour récupérer le PlayersManager
func _try_get_players_manager() -> void:
	if players_manager:
		return
	
	players_manager = get_tree().get_first_node_in_group("players_manager")
	if not players_manager:
		DEBUG.log("[GAMEMANAGER] Players_manager introuvable !",DEBUG.ERROR)
	return

#endregion fonctions d'initialisation

# Cette fonction se déclenche à la réception d'un signal
func _on_map_generated():
	await get_tree().process_frame
	
	if not players_manager:
		DEBUG.log("PlayersManager introuvable dans l'arbre de scène !",DEBUG.ERROR)
		DEBUG.log("Assurez-vous que le nœud PlayerManager existe et est ajouté à un groupe",DEBUG.ERROR)
		return
	
	player1 = players_manager.create_player(1, "Joueur 1", true)
	player2 = players_manager.create_player(2, "IA", false)
	
	if not player1 or not player2:
		DEBUG.log("Échec de la création des joueurs !",DEBUG.ERROR)
		return
	
	DEBUG.log("Joueurs créés avec succès")
	
	var ship1 = spawn_navire_random(player1, true)
	var ship2 = spawn_navire_random(player1, true)
	
	if ship1:
		ship1.id = 1
		DEBUG.log("Ship1 créé avec succès")
	if ship2:
		ship2.id = 2
		DEBUG.log("Ship2 créé avec succès")
	
	var enemy1 = spawn_navire_random(player2, false)
	if enemy1:
		enemy1.id = 101
		DEBUG.log("Enemy1 créé avec succès avec l'id "+str(enemy1.id))
	
	players_manager.set_current_player(player1)
	
	# Fog update
	await get_tree().process_frame
	await get_tree().process_frame
	if fog_manager:
		DEBUG.log("[GAMEMANAGER] Forcing fog update after ships creation")
		fog_manager.update_fog()
	else:
		DEBUG.log("[GAMEMANAGER] FogManager non trouvé, impossible de mettre à jour le fog",DEBUG.WARNING)
	
	# Sélection
	if ship1:
		select_ship(ship1)
	
	# Attacher l'IA EN DERNIER, hors de tout bloc if avec await
	await get_tree().process_frame
	await get_tree().process_frame
	if enemy1 and is_instance_valid(enemy1):
		# À la toute fin de _on_map_generated() :
		DEBUG.log("[GAMEMANAGER] Avant _attach_ai, enemy1 valide: "+ str(is_instance_valid(enemy1)))
		await get_tree().process_frame
		await get_tree().process_frame
		DEBUG.log("[GAMEMANAGER] Après await, appel _attach_ai...")
		if enemy1 and is_instance_valid(enemy1):
			_attach_ai(enemy1)
		else:
			DEBUG.log("[GAMEMANAGER] enemy1 invalide ou null !")
			_attach_ai(enemy1)
	
		
	turn_manager.start_game([player1, player2])


#region gestion des navires
# Faire apparaître un bateau sur la carte
func spawn_navire(player: Player, position: Vector2, is_player_controlled: bool = false) -> Navires:
	if player == null:
		DEBUG.log("Impossible de créer un navire sans joueur propriétaire !",DEBUG.ERROR)
		return null
	
	var navire: Navires = navire_scene.instantiate()
	
	navire.global_position = position
	navire.is_player_controlled = is_player_controlled
	
	add_child(navire)
	
	navire.set_owner_player(player)
	
	if not navire.is_in_group("ships"):
		navire.add_to_group("ships")
	
	if navire.has_signal("ship_clicked"):
		navire.ship_clicked.connect(_on_ship_clicked)
	
	if navire.has_signal("ship_destroyed"):
		navire.ship_destroyed.connect(_on_ship_destroyed)
	
	if data and data.has_method("addNavireToData"):
		data.addNavireToData(navire)
	
	DEBUG.log("Navire créé avec ID : %d" % navire.id if navire.has_method("get") else "N/A")
	
	return navire


func spawn_navire_random(player: Player, is_player_controlled: bool = false) -> Navires:
	var pos = Map_utils.get_random_ocean_position()
	return spawn_navire(player, pos, is_player_controlled)


func spawn_navire_at(player: Player, case_pos: Vector2i, is_player_controlled: bool = false) -> Navires:
	var world_pos = Map_utils.case_vers_monde(case_pos)
	return spawn_navire(player, world_pos, is_player_controlled)
#endregion gestion des navires

func _attach_ai(navire_ennemi: Navires) -> void:
	DEBUG.log("[ATTACH_AI] Début")
	
	# Teste plusieurs chemins possibles
	var ai_script = load("res://Scripts/in_game/navires/EnemyAI.gd")
	if ai_script == null:
		DEBUG.log("[ATTACH_AI] ERREUR : EnemyAI.gd introuvable dans aucun chemin !",DEBUG.ERROR)
		return
	
	DEBUG.log("[ATTACH_AI] Création du nœud IA...")
	var ai = Node.new()
	ai.set_script(ai_script)
	ai.name = "IA"
	navire_ennemi.add_child(ai)
	DEBUG.log("[ATTACH_AI] IA attachée à navire id=%d" % navire_ennemi.id)


# ===============================
# INPUT HANDLING
# ===============================

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_focus_next") or (event is InputEventKey and event.pressed and event.keycode == KEY_TAB and not event.shift_pressed):
		select_next_ship()
		get_viewport().set_input_as_handled()
	
	elif event is InputEventKey and event.pressed and event.keycode == KEY_TAB and event.shift_pressed:
		select_previous_ship()
		get_viewport().set_input_as_handled()
	
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				_select_ship_by_index(0)
				get_viewport().set_input_as_handled()
			KEY_2:
				_select_ship_by_index(1)
				get_viewport().set_input_as_handled()
			KEY_3:
				_select_ship_by_index(2)
				get_viewport().set_input_as_handled()


func _select_ship_by_index(index: int) -> void:
	if not player1:
		return
	
	var player_ships = player1.get_navires()
	if index >= 0 and index < player_ships.size():
		select_ship(player_ships[index])


# ===============================
# GESTION DE LA SÉLECTION
# ===============================
#region gestion de la selection
func select_ship(ship: Navires) -> void:
	if selected_ship == ship:
		return
	
	if selected_ship:
		selected_ship.set_selected(false)
	
	selected_ship = ship
	if selected_ship:
		selected_ship.set_selected(true)
		emit_signal("ship_selected", ship)
		DEBUG.log("Navire sélectionné: "+ str(ship.id if ship.has_method("get") else "N/A"))
		
		# NOUVEAU : Mettre à jour le fog quand un navire est sélectionné
		if fog_manager:
			fog_manager.update_fog()


func deselect_ship() -> void:
	if selected_ship:
		DEBUG.log("Désélection du navire: "+str(selected_ship.id if selected_ship.has_method("get") else "N/A"))
		selected_ship.set_selected(false)
		selected_ship = null
		emit_signal("ship_deselected")


func get_selected_ship() -> Navires:
	return selected_ship


func _on_ship_clicked(ship: Navires) -> void:
	if ship.player_owner == player1:
		select_ship(ship)


func _on_ship_destroyed(ship: Navires) -> void:
	DEBUG.log("Navire détruit détecté: "+str( ship.id if ship.has_method("get") else "N/A"))
	
	if selected_ship == ship:
		DEBUG.log("Le navire sélectionné a été détruit, désélection...")
		deselect_ship()
		
		if player1:
			var remaining_ships = player1.get_navires()
			DEBUG.log("Navires restants: " +str(remaining_ships.size()))
			
			if remaining_ships.size() > 0:
				DEBUG.log("Sélection automatique du navire suivant")
				select_ship(remaining_ships[0])
			else:
				DEBUG.log("Aucun navire restant pour le joueur")


func select_next_ship() -> void:
	if not player1:
		return
	
	var player_ships = player1.get_navires()
	if player_ships.is_empty():
		return
	
	var current_index = -1
	if selected_ship:
		current_index = player_ships.find(selected_ship)
	
	var next_index = (current_index + 1) % player_ships.size()
	select_ship(player_ships[next_index])


func select_previous_ship() -> void:
	if not player1:
		return
	
	var player_ships = player1.get_navires()
	if player_ships.is_empty():
		return
	
	var current_index = -1
	if selected_ship:
		current_index = player_ships.find(selected_ship)
	
	var prev_index = (current_index - 1) if current_index > 0 else (player_ships.size() - 1)
	select_ship(player_ships[prev_index])
#endregion gestion de la selection

# ===============================
# FONCTIONS UTILITAIRES
# ===============================

func get_player_ship() -> Navires:
	if player1:
		var navires = player1.get_navires()
		if navires.size() > 0:
			return navires[0]
	
	var all_ships = get_tree().get_nodes_in_group("ships")
	for navire in all_ships:
		if navire is Navires and navire.is_player_controlled:
			return navire
	
	return null


func get_enemy_ships() -> Array[Navires]:
	var enemies: Array[Navires] = []
	
	if not player1:
		return enemies

	if not players_manager:
		return enemies
	
	var enemy_players = players_manager.get_enemy_players(player1)
	
	for enemy_player in enemy_players:
		enemies.append_array(enemy_player.get_navires())
	
	return enemies


func get_player_ships(player: Player) -> Array[Navires]:
	if player:
		return player.get_navires()
	return []


func get_player_by_id(player_id: int) -> Player:
	if players_manager:
		return players_manager.get_player_by_id(player_id)
	return null
