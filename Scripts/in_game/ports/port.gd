class_name Ports
extends Node2D

# Permettra de signaler au moteur différents évènements
signal sig_show_port
signal port_clicked(port: Ports)

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
	
	# Debug
	var owner_name = player_owner.player_name if player_owner else "AUCUN"
	var control_type = "CONTRÔLÉ" if is_player_controlled else "IA/ENNEMI"
	DEBUG.log("Port [%s] initialisé - Propriétaire: %s - Type: %s - Position: %s" % [
		id, owner_name, control_type, case_actuelle
	])


func _setup_input_handling() -> void:
	"""Configure la gestion des inputs selon le type de port"""
	# Tous les ports du joueur local humain peuvent recevoir des inputs pour être sélectionnés
	if _is_local_human_owner():
		set_process_input(true)
		set_process_unhandled_input(true)
	else:
		set_process_input(false)
		set_process_unhandled_input(false)

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
		DEBUG.log("ui_layer est null, impossible de créer l'UI des stats!",DEBUG.ERROR)
		return
	# ---------- UI STATS (pour TOUS les ports) ----------
	# On vérifie si le panel existe déjà avant d'en créer un nouveau
	if stats_panel == null: 
		stats_panel = UI_stats_port.new(self)
	
	DEBUG.log("UI Stats créée pour port [%d]" % id)


# =========================
# INPUT
# =========================
func on_clicked():
	DEBUG.log("Le port a reçu le signal du clic !")
	
	# Toute la logique liée au port est gérée ICI, pas dans le MapManager
	if player_owner != null and player_owner.is_human:
		# On peut émettre le signal si d'autres menus doivent s'ouvrir (ex: interface d'achat)
		port_clicked.emit(self) 
	else:
		DEBUG.log("Ce port ne vous appartient pas ou n'a pas de propriétaire.")
	


# =========================
# COMBAT
# =========================

func take_damage(amount: int, attacker: Player) -> void:
	current_hp -= amount
	DEBUG.log("Port [%d] reçoit %d dégâts → %d/%d PV" % [id, amount, current_hp, max_hp])
	is_under_attack = true
	sig_show_port.emit()  # FIX: affiche l'UI des stats quand le port est attaqué
	if current_hp <= 0:
		current_hp = 0
		_on_captured(attacker)

func _on_captured(new_owner: Player) -> void:
	var old_owner = player_owner
	set_as_owner(new_owner)
	port_captured.emit(self, new_owner, old_owner)
	DEBUG.log("Port [%d] capturé par %s !" % [id, new_owner.player_name if new_owner else "NEUTRE"])

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
	# Le port attaque si : il est neutre OU s'il appartient à un joueur différent du joueur actif
	if player_owner != null and player_owner == current_player:
		return  # Port ami => pas d'attaque
	
	var all_ships = get_tree().get_nodes_in_group("ships")
	for navire in all_ships:
		if not is_instance_valid(navire) or not navire.is_alive():
			continue
		# N'attaque que les navires du joueur actif (ceux qui viennent de jouer)
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


# === VISUEL 3D ===
@onready var _sprite: Sprite2D = $Sprite2D

func _process(_delta: float) -> void:
	if _sprite:
		_sprite.global_position = global_position + Vector2(0, -80)
