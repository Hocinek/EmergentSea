class_name ShipManager
extends Node

var gm : GameManager
@onready var data

# Modèles 3D disponibles pour les navires
const SHIP_MODEL_PLAYER := "res://Assets/navire/pirateShip.glb"
const SHIP_MODEL_ENEMY  := "res://Assets/navire/smolPirateShip_red_sails.glb"

## Joueur actuel, mis à jour par le TurnManager
var current_player : Player

## Bateau actuellement sélectionné
var selected_ship: Navires = null

## Scène du navire préchargée
var navire_scene := preload("res://Scenes/in_game/ENTITIES/Navires.tscn")

## Initialisation du ShipManager, requiert un GameManager auquel se raccrocher
func _init(gamemanager : GameManager) -> void:
	gm = gamemanager
	gm.add_child(self)
	
	data = get_tree().get_first_node_in_group("shared_entities")
	if not data:
		DEBUG.log("Aucune donnée partagée n'est accessible !",DEBUG.ERROR)

func update_current_player(new_player : Player):
	self.current_player = new_player
	var silent = false
	select_next_ship(silent)

#region spawn des navires

func _get_model_for_player(player: Player) -> String:
	if player == null:
		return SHIP_MODEL_PLAYER
	if player.is_human:
		return SHIP_MODEL_PLAYER
	return SHIP_MODEL_ENEMY

## Faire apparaître un bateau sur la carte
func spawn_navire(player: Player, position: Vector2, is_player_controlled: bool = false, model_path: String = "") -> Navires:
	if player == null:
		DEBUG.log("Impossible de créer un navire sans joueur propriétaire !", DEBUG.ERROR)
		return null

	if model_path == "":
		model_path = _get_model_for_player(player)

	var navire: Navires = navire_scene.instantiate()
	navire.global_position = position
	navire.is_player_controlled = is_player_controlled
	navire.ship_model_path = model_path
	add_child(navire)
	navire.set_owner_player(player)

	if not navire.is_in_group("ships"):
		navire.add_to_group("ships")

	if navire.has_signal("ship_clicked"):
		navire.ship_clicked.connect(gm._on_ship_clicked)

	if navire.has_signal("ship_destroyed"):
		navire.ship_destroyed.connect(gm._on_ship_destroyed)

	if navire.has_signal("sig_open_hex_menu"):
		navire.sig_open_hex_menu.connect(gm._on_open_hex_menu)

	if navire.has_signal("sig_switch_ship"):
		navire.sig_switch_ship.connect(select_next_ship)

	if navire.has_signal("sig_inspect_case"):
		navire.sig_inspect_case.connect(gm._on_inspect_case)

	if data and data.has_method("addNavireToData"):
		data.addNavireToData(navire)
	DEBUG.log("Navire créé avec ID : %d — modèle : %s" % [navire.id, model_path] if navire.has_method("get") else "N/A")
	return navire

## Faire apparaître un bateau à un emplacement aléatoire sur la carte
func spawn_navire_random(player: Player, is_player_controlled: bool = false, model_path: String = "") -> Navires:
	var pos = Map_utils.get_random_ocean_position()
	return spawn_navire(player, pos, is_player_controlled, model_path)

## Faire apparaître un bateau à une case précise
func spawn_navire_at(player: Player, case_pos: Vector2i, is_player_controlled: bool = false, model_path: String = "") -> Navires:
	var wpos = Map_utils.case_vers_monde(case_pos)
	return spawn_navire(player, wpos, is_player_controlled, model_path)

#endregion spawn des navires



#region gestion de la selection
func select_ship_by_index(index: int) -> void:
	if not current_player:
		return
	var player_ships = current_player.get_navires()
	if index >= 0 and index < player_ships.size():
		select_ship(player_ships[index])



func select_ship(ship: Navires, silent:bool = false) -> void:
	if selected_ship == ship:
		return
	if selected_ship:
		selected_ship.set_selected(false)
	selected_ship = ship
	if selected_ship:
		selected_ship.set_selected(true,silent)
		gm.ship_selected.emit(ship)
		DEBUG.log("Navire sélectionné : %s" % str(ship.id) if ship.has_method("get") else "N/A")
		if gm.fog_manager:
			gm.fog_manager.update_fog()
		# Mettre à jour les snapshots après chaque changement de fog
		if gm.fish_manager and gm.fog_of_war and current_player:
			gm.fish_manager.update_all_visible_snapshots_for_player(current_player, gm.fog_of_war)


func deselect_ship() -> void:
	if selected_ship:
		DEBUG.log("Désélection du navire : %s" % str(selected_ship.id) if selected_ship.has_method("get") else "N/A")
		selected_ship.set_selected(false)
		selected_ship = null
		gm.ship_deselected.emit()


func get_selected_ship() -> Navires:
	return selected_ship


func _on_ship_clicked(ship: Navires) -> void:
	if ship.player_owner == current_player:
		select_ship(ship)


func destroy_ship(ship: Navires) -> void:
	DEBUG.log("Navire détruit détecté : %s" % str(ship.id) if ship.has_method("get") else "N/A")
	if selected_ship == ship:
		DEBUG.log("Le navire sélectionné a été détruit, désélection...")
		deselect_ship()
		if current_player:
			var remaining_ships = current_player.get_navires()
			DEBUG.log("Navires restants: " +str(remaining_ships.size()))
			if remaining_ships.size() > 0:
				DEBUG.log("Sélection automatique du navire suivant")
				select_ship(remaining_ships[0])
			else:
				DEBUG.log("Aucun navire restant pour le joueur")


func select_next_ship(silent:bool=false) -> void:
	if not current_player:
		return
	var player_ships = current_player.get_navires()
	if player_ships.is_empty():
		DEBUG.log("Aucun navire restant pour le joueur")
		return
	var current_index = -1
	if selected_ship:
		current_index = player_ships.find(selected_ship)
	var next_index = (current_index + 1) % player_ships.size()
	select_ship(player_ships[next_index],silent)


func select_previous_ship() -> void:
	if not current_player:
		return
	var player_ships = current_player.get_navires()
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
	if current_player:
		var navires = current_player.get_navires()
		if navires.size() > 0:
			return navires[0]
	var all_ships = get_tree().get_nodes_in_group("ships")
	for navire in all_ships:
		if navire is Navires and navire.is_player_controlled:
			return navire
	return null


func get_enemy_ships() -> Array[Navires]:
	var enemies: Array[Navires] = []
	if not current_player:
		return enemies
	if not gm.players_manager:
		return enemies
	var enemy_players = gm.players_manager.get_enemy_players(current_player)
	for enemy_player in enemy_players:
		enemies.append_array(enemy_player.get_navires())
	return enemies
