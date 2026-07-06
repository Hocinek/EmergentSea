###===================================================================###
##								GameManager							   ##
# Ce script permet de coordonner le reste du jeu						#
# VERSION CORRIGÉE avec support Fog of War							#
###===================================================================###
class_name GameManager
extends Node


@onready var map
@onready var data


# Références fog of war
var fog_of_war: FogOfWar = null
var fog_manager: FogManager = null
var hex_menu: HexContextMenu = null

# Stockage des joueurs créés
var player1: Player = null
var player2: Player = null

#signaux émis indirectement par ship_manager
signal ship_selected(ship: Navires)
signal ship_deselected()

# Gestion de la sélection des ports
var selected_port: Ports = null
signal port_selected(port: Ports)
signal port_deselected()


#gestion des différents gestionnaires du programme
var turn_manager: TurnManager = null
@onready var map_manager
var players_manager: PlayersManager = null
var fish_manager: FishManager = null
var ship_manager: ShipManager = null

# UI d'inspection de case
var case_info_ui: UI_case_info = null

# UI d'aide - bouton "?" et panneau des commandes
var aide_ui: UI_aide = null

# UI quitter - bouton "🚪" à côté du bouton "?"
var quitter_ui: UI_quitter = null


# Ce qui sera dans cette fonction sera exécuté en premier (avant que le reste soit prêt)
func _enter_tree():
	add_to_group("game_manager") # Important pour que les navires puissent trouver le GameManager
	
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
	_setup_fish_manager()
	# Créer le HexContextMenu 
	_setup_hex_menu()
	_setup_case_info_ui()
	_setup_aide_ui()
	_setup_quitter_ui()
	# Préparer la fin de partie
	_setup_game_over_ui()
	# Récupérer le PlayersManager
	_try_get_players_manager()
	
	# À exécuter après que le turn_manager ait été créé
	_setup_ship_manager()

#region fonctions d'initialisation
## Créé et configure le système de fog of war
func _setup_fog_of_war():
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

func _setup_ship_manager() -> void:
	if not turn_manager:
		DEBUG.log("[GAMEMANAGER] TurnManager manquant, impossible de continuer !",DEBUG.ERROR)
		return
	if not ship_manager:
		DEBUG.log("[GAMEMANAGER] Création dynamique de ShipManager...")
		ship_manager = ShipManager.new(self)
		ship_manager.name = "ShipManager"
	
	turn_manager.active_player_changed.connect(ship_manager.update_current_player)

func _setup_fish_manager() -> void:
	fish_manager = get_tree().get_first_node_in_group("fish_manager")
	if not fish_manager:
		DEBUG.log("[GAMEMANAGER] Création dynamique de FishManager...")
		fish_manager = FishManager.new()
		fish_manager.name = "FishManager"
		add_child(fish_manager)
	else:
		DEBUG.log("[GAMEMANAGER] FishManager trouvé dans la scène")


func _try_get_players_manager() -> void:
	if players_manager:
		return
	players_manager = get_tree().get_first_node_in_group("players_manager")
	if not players_manager:
		DEBUG.log("[GAMEMANAGER] Players_manager introuvable !",DEBUG.ERROR)
	return


## Créé le menu contextuel hexagonal sur un CanvasLayer dédié
func _setup_hex_menu() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	canvas.name = "HexMenuLayer"
	add_child(canvas)
	hex_menu = HexContextMenu.new()
	hex_menu.name = "HexContextMenu"
	hex_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(hex_menu)
	hex_menu.action_selected.connect(_on_hex_menu_action)
	DEBUG.log("[GAMEMANAGER] HexContextMenu créé")


func _setup_case_info_ui() -> void:
	case_info_ui = UI_case_info.new()
	case_info_ui.name = "UI_case_info"
	add_child(case_info_ui)
	case_info_ui.setup()
	DEBUG.log("[GAMEMANAGER] UI_case_info créé")


func _setup_aide_ui() -> void:
	aide_ui = UI_aide.new()
	aide_ui.name = "UI_aide"
	add_child(aide_ui)
	await aide_ui.setup()
	DEBUG.log("[GAMEMANAGER] UI_aide créé")


func _setup_quitter_ui() -> void:
	quitter_ui = UI_quitter.new()
	quitter_ui.name = "UI_quitter"
	add_child(quitter_ui)
	await quitter_ui.setup()
	DEBUG.log("[GAMEMANAGER] UI_quitter créé")


func _setup_game_over_ui() -> void:
	var ui_game_over := UI_game_over.new()
	ui_game_over.name = "UI_game_over"
	add_child(ui_game_over)
	ui_game_over.init()
	
	if turn_manager:
		turn_manager.game_over_panel = ui_game_over
		DEBUG.log("[GAMEMANAGER] UI_game_over assigné au TurnManager")
	else:
		DEBUG.log("[GAMEMANAGER] Impossible d'assigner UI_game_over : TurnManager null", DEBUG.ERROR)

#endregion fonctions d'initialisation


func _on_map_generated():
	await get_tree().process_frame
	
	if not players_manager:
		DEBUG.log("PlayersManager introuvable dans l'arbre de scène !",DEBUG.ERROR)
		return
	
	player1 = players_manager.create_player(1, "Joueur 1", true)
	player2 = players_manager.create_player(2, "IA", false)
	
	if not player1 or not player2:
		DEBUG.log("Échec de la création des joueurs !",DEBUG.ERROR)
		return
	
	DEBUG.log("Joueurs créés avec succès")
	
# Assigner un port de départ à chaque joueur
	var all_ports = get_tree().get_nodes_in_group("ports")
	if all_ports.size() > 1:
		all_ports[0].set_as_owner(player1)
		all_ports[0].current_hp = all_ports[0].max_hp
		all_ports[1].set_as_owner(player2)
		all_ports[1].current_hp = all_ports[1].max_hp
		DEBUG.log("Ports de départ assignés")

	for port in all_ports:
		if port.has_signal("port_captured"):
			port.port_captured.connect(_on_port_captured)
	
	# Initialiser les stocks de poissons via le FishManager
	if fish_manager:
		fish_manager.initialize_fish_tiles()

	# Navires du joueur humain -> pirateShip (grand navire)
	#var ship1 = spawn_navire_random(player1, true, SHIP_MODEL_PLAYER)
	#var ship2 = spawn_navire_random(player1, true, SHIP_MODEL_PLAYER)

	var ship1 = ship_manager.spawn_navire_random(player1, true)
	var ship2 = ship_manager.spawn_navire_random(player1, true)
	
	if ship1:
		ship1.id = 1
		DEBUG.log("Ship1 créé avec succès")
	if ship2:
		ship2.id = 2
		DEBUG.log("Ship2 créé avec succès")
	

	# Navire ennemi -> smolPirateShip (petit navire)
	# En mode tutoriel : spawner l'ennemi près du joueur pour faciliter l'apprentissage
	# En mode normal : spawn aléatoire comme avant
	var enemy1
	if tutorial_manager.is_tutorial_mode:
		var case_ship1 = Map_utils.monde_vers_case(ship1.global_position)
		var case_proche = case_ship1 + Vector2i(2, 0)
		if Map_utils.is_case_navigable(case_proche):
			enemy1 = ship_manager.spawn_navire_at(player2, case_proche, false)
		else:
			enemy1 = ship_manager.spawn_navire_random(player2, false)
	else:
		enemy1 = ship_manager.spawn_navire_random(player2, false)
	if enemy1:
		enemy1.id = 101
		DEBUG.log("Enemy1 créé avec succès avec l'id "+str(enemy1.id))
	
	players_manager.set_current_player(player1)
	await get_tree().process_frame
	await get_tree().process_frame
	if fog_manager:
		DEBUG.log("[GAMEMANAGER] Forcing fog update after ships creation")
		fog_manager.update_fog()
	else:
		DEBUG.log("[GAMEMANAGER] FogManager non trouvé, impossible de mettre à jour le fog",DEBUG.WARNING)
	
	# Snapshot initial des cases visibles au spawn
	if fish_manager and fog_of_war and player1:
		fish_manager.update_all_visible_snapshots_for_player(player1, fog_of_war)
	
	if ship1:
		ship_manager.select_ship(ship1)
	await get_tree().process_frame
	await get_tree().process_frame
	if enemy1 and is_instance_valid(enemy1):
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


func _attach_ai(navire_ennemi: Navires) -> void:
	DEBUG.log("[ATTACH_AI] Début")
	var ai_script = load("res://Scripts/in_game/navires/IA/EnemyAI.gd")
	if ai_script == null:
		DEBUG.log("[ATTACH_AI] ERREUR : EnemyAI.gd introuvable !",DEBUG.ERROR)
		return
	var ai = Node.new()
	ai.set_script(ai_script)
	ai.name = "IA"
	navire_ennemi.add_child(ai)
	DEBUG.log("[ATTACH_AI] IA attachée à navire id=%d" % navire_ennemi.id)

func _on_start_of_turn():
	ship_manager.select_next_ship()

# ===============================
# INPUT HANDLING
# ===============================

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_focus_next") or (event is InputEventKey and event.pressed and event.keycode == KEY_TAB and not event.shift_pressed):
		ship_manager.select_next_ship()
		get_viewport().set_input_as_handled()
	
	elif event is InputEventKey and event.pressed and event.keycode == KEY_TAB and event.shift_pressed:
		ship_manager.select_previous_ship()
		get_viewport().set_input_as_handled()
	
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				ship_manager.select_ship_by_index(0)
				get_viewport().set_input_as_handled()
			KEY_2:
				ship_manager.select_ship_by_index(1)
				get_viewport().set_input_as_handled()
			KEY_3:
				ship_manager.select_ship_by_index(2)
				get_viewport().set_input_as_handled()



# ===============================
# GESTION DE LA SÉLECTION
# ===============================
#region gestion de la selection
## Permet de connaître le bateau actuellement sélectionné
func get_selected_ship() -> Navires:
	return ship_manager.get_selected_ship()

## Action : Si le bateau cliqué appartient au joueur courant, il est sélectionné
func _on_ship_clicked(ship: Navires) -> void:
	ship_manager._on_ship_clicked(ship)

## Si le navire est détruit, cette méthode est appelée (sûrement par un signal)
func _on_ship_destroyed(ship: Navires) -> void:
	ship_manager.destroy_ship(ship)

#endregion gestion de la selection

#region utilitaires
## Permet de récupérer un navire de joueur, de préférence du joueur actuel, mais c'est pas sûr, j'ai aps compris l'utilité de cette méthode
func get_player_ship() -> Navires:
	return ship_manager.get_player_ship()

## Permet de récupérer la liste des bateaux ennemis
func get_enemy_ships() -> Array[Navires]:
	return ship_manager.get_enemy_ships()

## Permet de récupérer tous les bateaux d'un joueur
func get_player_ships(player: Player) -> Array[Navires]:
	if player:
		return player.get_navires()
	return []

## Permet de récupérer un objet joueur à partir de son id, renvoie null si aucun joueur ne peut être trouvé
func get_player_by_id(player_id: int) -> Player:
	if players_manager:
		return players_manager.get_player_by_id(player_id)
	return null
#endregion utilitaires

#region interface click
## Ouvre le menu contextuel pour le navire donné
func _on_open_hex_menu(navire: Navires, screen_pos: Vector2) -> void:
	if hex_menu:
		hex_menu.show_for(navire, screen_pos)

## Routeur d'action pour le menu contextuel hexagonal
func _on_hex_menu_action(action: String, navire: Navires) -> void:
	if not navire or not is_instance_valid(navire):
		return
	DEBUG.log("[GAMEMANAGER] Action menu : '%s' sur navire %d" % [action, navire.id])
	match action:
		"move":
			ship_manager.select_ship(navire)
			navire.set_input_mode(Navires.InputMode.MOVE)
		"attack":
			ship_manager.select_ship(navire)
			navire.set_input_mode(Navires.InputMode.ATTACK)
		"inspect":
			ship_manager.select_ship(navire)
			navire.set_input_mode(Navires.InputMode.INSPECT)
		"stats":
			navire.toggle_stats()
		"switch":
			ship_manager.select_next_ship()
		"fish":
			navire.try_start_fishing()


# ===============================
# INSPECTION DE CASE
# ===============================

## Action : lorsqu'une case est inspectée
func _on_inspect_case(case_pos: Vector2i) -> void:
	DEBUG.log("[GAMEMANAGER] Inspection de la case %s" % str(case_pos))

	if not fog_of_war or not player1:
		return

	var fog_state: int = fog_of_war.get_fog_state(case_pos)
	
	if fog_state == FogOfWar.FogState.UNEXPLORED:
		DEBUG.log("[INSPECT] Case %s jamais vue, inspection ignorée" % str(case_pos))
		return
		
	# Navires sur la case
	var ships_on_case: Array = []
	if data and data.has_method("getNavireByPosition"):
		ships_on_case = data.getNavireByPosition(case_pos)
	if not ships_on_case.is_empty():
		var target: Navires = ships_on_case[0]
		if target and is_instance_valid(target) and target.stats_panel:
			target.stats_panel.show_stats()

	_inspect_tile_info(case_pos, fog_state)



func _inspect_tile_info(case_pos: Vector2i, fog_state: int) -> void:
	if not case_info_ui or not map_manager:
		return

	var axial: Vector2 = map_manager.grid.offset_to_axial(case_pos.x, case_pos.y)
	var q := int(axial.x)
	var r := int(axial.y)
	var cell: HexCell = map_manager.grid.get_cell(q, r, -q - r)

	if not cell:
		DEBUG.log("[INSPECT] Cellule introuvable pour %s" % str(case_pos))
		return
		
	var tile_type: String = cell.getTypeTerrain()
	var is_visible: bool = (fog_state == FogOfWar.FogState.VISIBLE)
	
	var fish_count: int = -1
	if tile_type == "fish" and fish_manager:
		var info: Dictionary = fish_manager.get_stock_for_player(player1, case_pos, fog_of_war)
		if info["known"]:
			fish_count = info["stock"]

	# screen_pos vient directement du clic - pas de conversion, pas de dérive caméra
	case_info_ui.show_tile_info(tile_type, case_pos, is_visible, fish_count)
	DEBUG.log("[INSPECT] Case %s -> type='%s' visible=%s" % [str(case_pos), tile_type, str(is_visible)])

## Action : lorsqu'une case de pêche est inspectée
func _inspect_fish_on_case(case_pos: Vector2i) -> void:
	if not case_info_ui or not fish_manager or not fog_of_war or not player1:
		return

	# FishManager gère lui-même la logique fog -> valeur réelle ou snapshot
	var info: Dictionary = fish_manager.get_stock_for_player(player1, case_pos, fog_of_war)

	if not info["known"]:
		return  # Case inconnue ou pas une case de pêche

	var wpos: Vector2 = Map_utils.case_vers_monde(case_pos)
	var spos: Vector2 = _world_to_screen(wpos)

	case_info_ui.show_fish_info(info["stock"], spos, info["is_live"])

	if info["is_live"]:
		DEBUG.log("[INSPECT] Case %s -> %d 🐟 (vue directe)" % [str(case_pos), info["stock"]])
	else:
		DEBUG.log("[INSPECT] Case %s -> %d 🐟 (dernière observation, tour %d)" % [
			str(case_pos), info["stock"], info["turn"]
		])

## Fonction de conversion de coordonnées
func _world_to_screen(world_pos: Vector2) -> Vector2:
	var viewport := get_viewport()
	if not viewport:
		return world_pos
	var cam := viewport.get_camera_2d()
	if not cam:
		return world_pos
	return viewport.get_canvas_transform() * world_pos


# ===============================
# Gestion Port
# ===============================
	
func _on_port_captured(port: Ports, new_owner: Player, old_owner: Player) -> void:
	DEBUG.log("Port [%d] capturé : %s -> %s" % [
		port.id,
		old_owner.player_name if old_owner else "NEUTRE",
		new_owner.player_name if new_owner else "NEUTRE"
	])
	if fog_manager:
		fog_manager.update_fog()
		
#endregion interface click
