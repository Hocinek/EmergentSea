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

## Indique si ce port est actuellement sélectionné
var is_selected: bool = false

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
@onready var players_manager: PlayersManager = get_tree().get_first_node_in_group("players_manager")

# AJOUT : Référence au fog manager pour mise à jour en temps réel
var fog_manager: FogManager = null

# Case du port
var case_actuelle: Vector2i


# =========================
# SÉLECTION VISUELLE
# =========================
@export var selection_color: Color = Color(0, 1, 0, 0.7)  # Vert
@export var selection_thickness: float = 4.0
@export var selection_radius: float = 50.0


# =========================
# CAMÉRA
# =========================
@onready var camera: Camera2D = get_node_or_null("Camera2D")


# =========================
# INITIALIZATION
# =========================
func _init() -> void:
	add_to_group("ports")


func _ready():
	await get_tree().process_frame
	
	
	case_actuelle = Map_utils.monde_vers_case(global_position)

	# Configuration de la caméra pour le port contrôlé par le joueur
	_setup_camera()
	
	# Configuration des inputs selon le type de contrôle
	_setup_input_handling()
	
	# Initialisation de l'UI
	_init_stats_ui()
	
	# AJOUT : Récupérer le FogManager
	fog_manager = get_tree().get_first_node_in_group("fog_manager")
	if fog_manager:
		DEBUG.log("Port [%d] - FogManager connecté" % id)
	
	# AJOUT : Récupérer le FogOfWar pour vérifier la visibilité
	fog_of_war_ref = get_tree().get_first_node_in_group("fog_of_war")
	if fog_of_war_ref:
		DEBUG.log("Port [%d] - FogOfWar connecté pour visibilité" % id)
	
	# Debug
	var owner_name = player_owner.player_name if player_owner else "AUCUN"
	var control_type = "CONTRÔLÉ" if is_player_controlled else "IA/ENNEMI"
	DEBUG.log("Port [%s] initialisé - Propriétaire: %s - Type: %s - Position: %s" % [
		id, owner_name, control_type, case_actuelle
	])


func _setup_camera() -> void:
	"""Configure la caméra pour suivre le port si c'est celui du joueur"""
	if not is_selected:
		return
		
	var cam = get_tree().get_first_node_in_group("camera_controller")
	if cam and cam.has_method("set_target"):
		cam.set_target(self)


func _setup_input_handling() -> void:
	"""Configure la gestion des inputs selon le type de port"""
	# Tous les ports du joueur peuvent recevoir des inputs pour être sélectionnés
	if player_owner and player_owner.is_human:
		set_process_input(true)
		set_process_unhandled_input(true)
	else:
		set_process_input(false)
		set_process_unhandled_input(false)

# =========================
# GESTION DU PROPRIÉTAIRE
# =========================
func set_owner_player(player: Player) -> void:
	"""Définit le joueur propriétaire de ce port"""
	if player_owner != null and player_owner.has_method("remove_port"):
		player_owner.remove_port(self)
	
	player_owner = player
	
	if player != null and player.has_method("add_port"):
		player.add_port(self)
	
	# Reconfigurer les inputs
	_setup_input_handling()


func get_owner_player() -> Player:
	"""Retourne le joueur propriétaire"""
	return player_owner


func is_owned_by(player: Player) -> bool:
	"""Vérifie si ce port appartient au joueur spécifié"""
	return player_owner == player
	

# =========================
# SÉLECTION
# =========================
func set_selected(selected: bool) -> void:
	"""Définit si ce port est sélectionné"""
	is_selected = selected
	queue_redraw()
	
	# Activer/désactiver la caméra selon la sélection
	if selected and player_owner and player_owner.is_human:
		_setup_camera()
		# Afficher les stats du port sélectionné
		if(stats_panel):
			stats_panel.show_ally()
	else:
		stats_panel.hide_all_stats()
	
	DEBUG.log("Port %d %s" % [id, "SÉLECTIONNÉ" if selected else "désélectionné"])
	

# =========================
# UI INITIALIZATION
# =========================
func _init_stats_ui():
	if not ui_layer:
		DEBUG.log("ui_layer est null, impossible de créer l'UI des stats!",DEBUG.ERROR)
		return
	# ---------- UI STATS (pour TOUS les navires) ----------
	# On vérifie si le panel existe déjà avant d'en créer un nouveau
	if stats_panel == null: 
		stats_panel = UI_stats_port.new(self)
	
	DEBUG.log("UI Stats créée pour port [%d]" % id)


# =========================
# INPUT
# =========================
func _unhandled_input(event: InputEvent) -> void:
	# Vérifier que ce port appartient au joueur humain
	if not player_owner or not player_owner.is_human:
		return
	
	# Détecter le clic sur ce port pour le sélectionner
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_global_mouse_position()
		var distance = global_position.distance_to(mouse_pos)
		
		# Si on clique sur ce port
		if distance <= interaction_radius:
			emit_signal("ship_clicked", self)
			get_viewport().set_input_as_handled()
			return
	
	# Le reste des inputs uniquement pour le port sélectionné
	if not is_selected:
		return
	
	# Toggle stats
	if Input.is_action_just_pressed("toggle_stats"):
		#envoie un signal qui est récupéré par l'UI_stats_ports associé à ce port
		if(self.is_selected):
			#sig_show_stats.emit()
			emit_signal("sig_show_stats")
	



# =========================
# COMBAT
# =========================
### Réfléchir à l'implémentation d'une attaque/défense de la part des villes ?


# =========================
# HELPER FUNCTIONS
# =========================
func hide_all_ports_stats():
	"""Cache les stats de tous les ports"""
	var all_ports = get_tree().get_nodes_in_group("ports")
	
	for port in all_ports:
		if port is Ports:
			port.hide_all_stats()


# =========================
# UTILS
# =========================


func getPosition() -> Vector2i:
	"""Retourne la position du navire en coordonnées de case"""
	return case_actuelle
