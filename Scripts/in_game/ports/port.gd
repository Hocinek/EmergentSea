class_name Ports
extends Node2D

# Permettra de signaler au moteur différents évènements
signal sig_show_port
signal port_clicked(port: Ports)
signal open_boutique_requested(port: Ports)

# =========================
# PROPRIÉTAIRE ET IDENTITÉ
# =========================
## Référence directe au joueur propriétaire (remplace joueur_id)
@export var player_owner: Player = null

## ID unique du port
@export var id: int = 0

## Détermine si le port est contrôlé par le joueur humain actuel
var is_player_controlled: bool = false

## Case liée à ce port
var _cell : HexCell

## AJOUT : Visibilité basée sur le fog of war
var is_visible_to_human: bool = true  # true par défaut pour les ports du joueur
var fog_of_war_ref: FogOfWar = null


# =========================
# STATS
# =========================
var stats_panel : UI_stats_port

@export var Nom_port: String = 'Nom du Port'
@export var interaction_radius: float = 80.0
@export var stats_duration: float = 2.5

@onready var ui_layer: CanvasLayer = get_tree().get_first_node_in_group("ui_layer")
@onready var data := get_tree().get_first_node_in_group("shared_entities")

@export var max_hp: int = 20
var current_hp: int = 20
var is_under_attack: bool = false  # true quand le port neutre est attaqué (force l'affichage ennemi)
@export var attack_damage: int = 1
@export var attack_range: int = 3  # en cases
signal port_captured(port: Ports, new_owner: Player, old_owner: Player)

# AJOUT : Référence au fog manager pour mise à jour en temps réel
var fog_manager: FogManager = null
var match_context: MatchContext = null

# Case du port
var case_actuelle: Vector2i

# Référence à la zone de clic (pour pouvoir la recréer si le propriétaire change)
var _click_area: Area2D = null


# =========================
# SÉLECTION VISUELLE
# =========================
@export var selection_color: Color = Color(0, 1, 0, 0.7)  # Vert
@export var selection_thickness: float = 4.0
@export var selection_radius: float = 50.0


# =========================
# INITIALIZATION
# =========================
func _init() -> void:
	add_to_group("ports")
	case_actuelle = Map_utils.monde_vers_case(global_position)


func _ready():
	await get_tree().process_frame
	
	match_context = get_tree().get_first_node_in_group("match_context")
	case_actuelle = Map_utils.monde_vers_case(global_position)
	current_hp = max_hp
	
	# Initialisation de l'UI
	_init_stats_ui()

	# Configuration de la zone de clic
	_setup_click_area()
	
	# Debug
	var owner_name = player_owner.player_name if player_owner else "AUCUN"
	var control_type = "CONTRÔLÉ" if is_player_controlled else "IA/ENNEMI"
	DEBUG.log("Port [%s] initialisé - Propriétaire: %s - Type: %s - Position: %s" % [
		id, owner_name, control_type, case_actuelle
	])


func _setup_click_area() -> void:
	"""Configure la gestion des inputs selon le type de port.
	Utilise un Area2D + CircleShape2D à la place de _unhandled_input,
	car Node2D n'a pas de zone de clic native."""
	# Supprime l'ancienne zone si elle existe (ex : changement de propriétaire)
	if is_instance_valid(_click_area):
		_click_area.queue_free()
		_click_area = null

	if not _is_local_human_owner():
		return

	_click_area = Area2D.new()
	_click_area.input_pickable = true

	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = interaction_radius
	shape.shape = circle

	_click_area.add_child(shape)
	add_child(_click_area)

	_click_area.input_event.connect(_on_area_input_event)


# =========================
# INPUT
# =========================
func _on_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return

	if event.button_index == MOUSE_BUTTON_LEFT:
		DEBUG.log("Port [%d] — clic gauche" % id)
		port_clicked.emit(self)
		get_viewport().set_input_as_handled()

	elif event.button_index == MOUSE_BUTTON_RIGHT:
		if not _is_local_human_owner():
			DEBUG.log("Port [%d] — boutique refusée (non propriétaire)" % id)
			return
		DEBUG.log("Port [%d] — clic droit → ouverture boutique" % id)
		_open_boutique()
		get_viewport().set_input_as_handled()


func _open_boutique() -> void:
	if not _is_local_human_owner():
		DEBUG.log("Port [%d] — boutique refusée (non propriétaire)" % id, DEBUG.WARNING)
		return

	# Récupère le navire actuellement sélectionné par le joueur
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	var docked_ship: Node = null
	if game_manager and game_manager.has_method("get_selected_ship"):
		docked_ship = game_manager.get_selected_ship()

	# Vérifie que le navire sélectionné appartient bien au propriétaire du port
	if docked_ship == null or not is_instance_valid(docked_ship):
		DEBUG.log("Port [%d] — boutique refusée (aucun navire sélectionné)" % id)
		return
	if docked_ship.player_owner != player_owner:
		DEBUG.log("Port [%d] — boutique refusée (navire sélectionné n'appartient pas au propriétaire)" % id)
		return

	# Vérifie que le navire sélectionné est sur une case adjacente au port
	var neighbors := Map_utils.get_neighbors(case_actuelle)
	if not docked_ship.case_actuelle in neighbors:
		DEBUG.log("Port [%d] — boutique refusée (navire non adjacent, case navire=%s, voisins=%s)" % [id, str(docked_ship.case_actuelle), str(neighbors)])
		return

	var boutique = UI_boutique.new(self, player_owner, docked_ship)
	boutique.buy_ship_requested.connect(_on_boutique_buy_ship)
	boutique.heal_ship_requested.connect(_on_boutique_heal_ship)
	boutique.heal_port_requested.connect(_on_boutique_heal_port)

	ui_layer.add_child(boutique)
	open_boutique_requested.emit(self)
	DEBUG.log("Port [%d] — boutique ouverte (navire amarré : %s)" % [
		id,
		str(docked_ship.id) if docked_ship else "aucun"
	])


# -- Callbacks boutique --

## Achat d'un nouveau navire :
## - Déduit le coût du navire acheteur (docked_ship)
## - Spawne un nouveau navire adjacent au port via le ShipManager
## - Rafraîchit la boutique
func _on_boutique_buy_ship(port: Ports, buyer: Player, buying_ship: Node) -> void:
	DEBUG.log("Port [%d] — achat navire demandé par %s" % [port.id, buyer.player_name])

	# Vérifie que le navire acheteur a assez de poissons
	if buying_ship == null or not is_instance_valid(buying_ship):
		DEBUG.log("Port [%d] — achat refusé (navire acheteur invalide)" % id, DEBUG.WARNING)
		return
	if buying_ship.nourriture < UI_boutique.SHIP_COST:
		DEBUG.log("Port [%d] — achat refusé (poissons insuffisants : %d/%d)" % [
			id, buying_ship.nourriture, UI_boutique.SHIP_COST
		], DEBUG.WARNING)
		return

	# Récupère le ShipManager via le GameManager
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager == null or game_manager.ship_manager == null:
		DEBUG.log("Port [%d] — achat refusé (ShipManager introuvable)" % id, DEBUG.ERROR)
		return

	# Trouve une case navigable adjacente au port pour spawner le navire
	var spawn_case: Vector2i = Vector2i(-1, -1)
	for neighbor in Map_utils.get_neighbors(case_actuelle):
		# Vérifie qu'aucun autre navire n'occupe déjà la case
		var occupied := false
		for ship in get_tree().get_nodes_in_group("ships"):
			if is_instance_valid(ship) and ship.case_actuelle == neighbor:
				occupied = true
				break
		if not occupied:
			spawn_case = neighbor
			break

	if spawn_case == Vector2i(-1, -1):
		DEBUG.log("Port [%d] — achat refusé (aucune case libre autour du port)" % id, DEBUG.WARNING)
		return

	# Déduit le coût du navire acheteur
	buying_ship.nourriture -= UI_boutique.SHIP_COST
	DEBUG.log("Port [%d] — %d poissons déduits du navire [%d] (reste : %d)" % [
		id, UI_boutique.SHIP_COST, buying_ship.id, buying_ship.nourriture
	])

	# Spawne le nouveau navire
	var new_ship = game_manager.ship_manager.spawn_navire_at(buyer, spawn_case, true)
	if new_ship:
		DEBUG.log("Port [%d] — nouveau navire [%d] spawné en %s" % [id, new_ship.id, str(spawn_case)])
	else:
		# Rembourse si le spawn a échoué
		buying_ship.nourriture += UI_boutique.SHIP_COST
		DEBUG.log("Port [%d] — spawn échoué, remboursement effectué" % id, DEBUG.ERROR)

## Soin du navire amarré :
## - Déduit le coût du navire soigné (c'est lui qui paie avec ses propres poissons)
## - Restaure des PV au navire
func _on_boutique_heal_ship(port: Ports, ship: Node, buyer: Player) -> void:
	DEBUG.log("Port [%d] — soin navire [%d] demandé par %s" % [port.id, ship.id, buyer.player_name])

	if ship == null or not is_instance_valid(ship):
		DEBUG.log("Port [%d] — soin refusé (navire invalide)" % id, DEBUG.WARNING)
		return
	if not "nourriture" in ship or not "vie" in ship or not "maxvie" in ship:
		DEBUG.log("Port [%d] — soin refusé (propriétés manquantes sur le navire)" % id, DEBUG.WARNING)
		return
	if ship.nourriture < UI_boutique.HEAL_SHIP_COST:
		DEBUG.log("Port [%d] — soin refusé (poissons insuffisants : %d/%d)" % [
			id, ship.nourriture, UI_boutique.HEAL_SHIP_COST
		], DEBUG.WARNING)
		return
	if ship.vie >= ship.maxvie:
		DEBUG.log("Port [%d] — soin refusé (navire déjà au maximum)" % id)
		return

	# Déduit le coût et soigne
	ship.nourriture -= UI_boutique.HEAL_SHIP_COST
	var soin := 5
	ship.vie = min(ship.vie + soin, ship.maxvie)
	DEBUG.log("Port [%d] — navire [%d] soigné (+%d PV → %d/%d), %d poissons déduits" % [
		id, ship.id, soin, ship.vie, ship.maxvie, UI_boutique.HEAL_SHIP_COST
	])


## Soin du port :
## - Déduit le coût du navire amarré (c'est lui qui paie)
## - Restaure des PV au port
func _on_boutique_heal_port(port: Ports, buyer: Player, paying_ship: Node) -> void:
	DEBUG.log("Port [%d] — soin port demandé par %s" % [port.id, buyer.player_name])

	if paying_ship == null or not is_instance_valid(paying_ship):
		DEBUG.log("Port [%d] — soin port refusé (navire payeur invalide)" % id, DEBUG.WARNING)
		return
	if not "nourriture" in paying_ship:
		DEBUG.log("Port [%d] — soin port refusé (propriété nourriture manquante)" % id, DEBUG.WARNING)
		return
	if paying_ship.nourriture < UI_boutique.HEAL_PORT_COST:
		DEBUG.log("Port [%d] — soin port refusé (poissons insuffisants : %d/%d)" % [
			id, paying_ship.nourriture, UI_boutique.HEAL_PORT_COST
		], DEBUG.WARNING)
		return
	if port.current_hp >= port.max_hp:
		DEBUG.log("Port [%d] — soin port refusé (port déjà au maximum)" % id)
		return

	# Déduit le coût et soigne
	paying_ship.nourriture -= UI_boutique.HEAL_PORT_COST
	var soin := 5
	port.current_hp = min(port.current_hp + soin, port.max_hp)
	DEBUG.log("Port [%d] — port soigné (+%d PV → %d/%d), %d poissons déduits du navire [%d]" % [
		id, soin, port.current_hp, port.max_hp, UI_boutique.HEAL_PORT_COST, paying_ship.id
	])


# =========================
# GESTION DU PROPRIÉTAIRE
# =========================
## PErmet de définir un joueur en tant que propriétaire du port
func set_as_owner(player: Player) -> void:
	if player_owner != null and player_owner.has_method("remove_port"):
		player_owner.remove_port(self)
	
	player_owner = player
	
	if player != null and player.has_method("add_port"):
		player.add_port(self)

	# Reconfigure la zone de clic si le propriétaire change
	_setup_click_area()

## Permet de récupérer le propriétaire du port
func get_port_owner() -> Player:
	return player_owner


func _is_local_human_owner() -> bool:
	if player_owner == null:
		return false
	
	if not player_owner.is_human:
		return false
	
	if match_context == null:
		match_context = get_tree().get_first_node_in_group("match_context")
	
	if match_context == null:
		return true
	
	if match_context.mode == MatchContext.MatchMode.MULTI:
		return player_owner.is_local
	
	return true


## Vérifie si tel joueur est le propriétaire du port
func is_owned_by(player: Player) -> bool:
	return player_owner == player


# =========================
# UI INITIALIZATION
# =========================
func _init_stats_ui():
	if not ui_layer:
		DEBUG.log("ui_layer est null, impossible de créer l'UI des stats!", DEBUG.ERROR)
		return
	# ---------- UI STATS (pour TOUS les ports) ----------
	# On vérifie si le panel existe déjà avant d'en créer un nouveau
	if stats_panel == null: 
		stats_panel = UI_stats_port.new(self)
	
	DEBUG.log("UI Stats créée pour port [%d]" % id)


# =========================
# COMBAT
# =========================

func take_damage(amount: int, attacker: Player) -> void:
	current_hp -= amount
	DEBUG.log("Port [%d] reçoit %d dégâts → %d/%d PV" % [id, amount, current_hp, max_hp])
	is_under_attack = true
	sig_show_port.emit()
	if current_hp <= 0:
		current_hp = 0
		_on_captured(attacker)

func _on_captured(new_owner: Player) -> void:
	var old_owner = player_owner
	set_as_owner(new_owner)
	# Le port est capturé à moitié endommagé
	current_hp = max_hp / 2
	port_captured.emit(self, new_owner, old_owner)
	DEBUG.log("Port [%d] capturé par %s ! (PV : %d/%d)" % [id, new_owner.player_name if new_owner else "NEUTRE", current_hp, max_hp])

func repair_ship(navire) -> void:
	navire.current_hp = min(navire.current_hp + 5, navire.max_hp)
	DEBUG.log("Navire [%d] réparé au port [%d]" % [navire.id, id])

func can_attack_position(target_pos: Vector2i) -> bool:
	var map_manager = get_tree().get_first_node_in_group("Map_manager")
	if not map_manager:
		return false
	
	var a1 = map_manager.grid.offset_to_axial(case_actuelle.x, case_actuelle.y)
	var a2 = map_manager.grid.offset_to_axial(target_pos.x, target_pos.y)
	
	var dq = int(a2.x) - int(a1.x)
	var dr = int(a2.y) - int(a1.y)
	var ds = (-dq - dr)  
	var dist = int((abs(dq) + abs(dr) + abs(ds)) / 2)
	
	return dist <= attack_range

func try_attack_ship(navire) -> void:
	if can_attack_position(navire.case_actuelle):
		navire.take_damage(attack_damage)
		DEBUG.log("Port [%d] attaque navire [%d] pour %d dégâts" % [id, navire.id, attack_damage])

func is_neutral() -> bool:
	return player_owner == null

func heal(amount: int) -> void:
	current_hp = min(current_hp + amount, max_hp)
	

## Attaque tous les navires à portée qui n'appartiennent pas au propriétaire du port.
## Appelé une fois à la fin de chaque tour.
func attack_nearby_ships(current_player: Player) -> void:
	if player_owner != null and player_owner == current_player:
		return  # Port ami => pas d'attaque
	
	var all_ships = get_tree().get_nodes_in_group("ships")
	for navire in all_ships:
		if not is_instance_valid(navire) or not navire.is_alive():
			continue
		if navire.player_owner != current_player:
			continue
		if can_attack_position(navire.case_actuelle):
			navire.take_damage(attack_damage)
			DEBUG.log("Port [%d] (%s) attaque navire [%d] pour %d dégâts" % [
				id,
				"NEUTRE" if is_neutral() else player_owner.player_name,
				navire.id,
				attack_damage
			])


# =========================
# HELPER FUNCTIONS
# =========================
## Cache les stats de tous les ports
func hide_all_ports_stats():
	var all_ports = get_tree().get_nodes_in_group("ports")
	
	for port in all_ports:
		if port is Ports:
			port.hide_all_stats()


# =========================
# UTILS
# =========================

## Permet de récupérer les coordonnées du port
func getPosition() -> Vector2i:
	return case_actuelle

func setCell(cell : HexCell):
	self._cell = cell
