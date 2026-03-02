class_name FogManager
extends Node

# =========================
# RÉFÉRENCES
# =========================
var fog_of_war: FogOfWar
var players_manager: PlayersManager
var game_manager: Node

## Fréquence de mise à jour du brouillard (en secondes)
## Mettre à 0 pour mise à jour continue chaque frame
@export var update_interval: float = 0.0

var update_timer: float = 0.0
var is_ready := false

# Signal émis quand le fog change
signal fog_updated()

# =========================
# INITIALISATION
# =========================
func _ready():
	add_to_group("fog_manager")
	
	DEBUG.log("[FOGMGR] FogManager _ready() - Système Civ6")
	
	# Attendre que tout soit prêt
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Récupérer les références
	fog_of_war = get_tree().get_first_node_in_group("fog_of_war")
	players_manager = get_tree().get_first_node_in_group("players_manager")
	game_manager = get_tree().get_first_node_in_group("game_manager")
	
	if not fog_of_war:
		DEBUG.log("[FOGMGR] ERREUR: FogOfWar non trouvé!",DEBUG.ERROR)
		return
	else:
		DEBUG.log("[FOGMGR] FogOfWar trouvé: "+ str(fog_of_war))
	
	if not players_manager:
		DEBUG.log("[FOGMGR] ERREUR: PlayersManager non trouvé!",DEBUG.ERROR)
		return
	else:
		DEBUG.log("[FOGMGR] PlayersManager trouvé: "+ str(players_manager))
	
	# Attendre que la map soit générée
	var map_manager = get_tree().get_first_node_in_group("Map_manager")
	if map_manager:
		DEBUG.log("[FOGMGR] MapManager trouvé, connexion au signal...")
		if not map_manager.is_connected("map_generated", _on_map_generated):
			map_manager.connect("map_generated", _on_map_generated)
			DEBUG.log("[FOGMGR] Signal map_generated connecté")
	else:
		DEBUG.log("[FOGMGR] ERREUR: MapManager non trouvé!",DEBUG.ERROR)
	
	# Connecter aux signaux des navires
	_connect_to_ship_signals()
	
	DEBUG.log("[FOGMGR] FogManager initialisé")

func _on_map_generated():
	"""Appelé quand la map est générée"""
	DEBUG.log("[FOGMGR] Signal map_generated reçu!")
	
	# Passer is_ready à true immédiatement
	is_ready = true
	DEBUG.log("[FOGMGR] is_ready mis à TRUE")
	
	# Attendre quelques frames pour que les navires soient créés
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Reconnecter aux navires (au cas où ils ont été créés après)
	_connect_to_ship_signals()
	
	# Première mise à jour immédiate
	DEBUG.log("[FOGMGR] Première mise à jour du brouillard...")
	update_fog()

func _connect_to_ship_signals():
	"""Connecte le FogManager aux signaux des navires"""
	# Attendre que les navires soient créés
	await get_tree().process_frame
	
	var ships = get_tree().get_nodes_in_group("ships")
	DEBUG.log("[FOGMGR] Connexion aux navires: "+ str(ships.size())+ " navires trouvés")
	
	for ship in ships:
		# Si le navire a un signal "moved", s'y connecter
		if ship.has_signal("sig_navire_moved"):
			if not ship.is_connected("sig_navire_moved", _on_ship_moved):
				ship.connect("sig_navire_moved", _on_ship_moved)
				DEBUG.log("[FOGMGR] Connecté au navire "+str(ship.id))

# =========================
# UPDATE
# =========================
func _process(delta):
	if not is_ready:
		return
	
	if not fog_of_war or not players_manager:
		return
	
	# Si update_interval = 0, mise à jour chaque frame
	if update_interval <= 0.0:
		update_fog()
		return
	
	# Sinon, utiliser le timer
	update_timer += delta
	
	if update_timer >= update_interval:
		update_timer = 0.0
		update_fog()

func update_fog():
	"""Met à jour le brouillard pour le joueur humain (système Civ6)"""
	if not players_manager:
		return
	
	# Récupérer le joueur humain
	var human_player = players_manager.get_human_player()
	if not human_player:
		return
	
	# Vérifier que fog_of_war existe
	if not fog_of_war:
		return
	
	# Mettre à jour la vision
	fog_of_war.update_vision_for_player(human_player)
	
	# Émettre le signal
	emit_signal("fog_updated")

# =========================
# ÉVÉNEMENTS
# =========================
func _on_ship_moved(ship: Navires):
	"""Appelé quand un navire se déplace"""
	if not fog_of_war:
		return
	
	# Mise à jour immédiate si c'est un navire du joueur
	if ship.player_owner and ship.player_owner.is_human:
		print(">>> [FOGMGR] Navire [%d] bougé, mise à jour du fog" % ship.id)
		force_update()

func on_ship_moved(ship: Navires):
	"""Appelé quand un navire se déplace (méthode publique)"""
	_on_ship_moved(ship)

# =========================
# FONCTIONS PUBLIQUES
# =========================
func force_update():
	"""Force une mise à jour immédiate du brouillard"""
	if not fog_of_war or not players_manager:
		return
	
	update_fog()

func reveal_area(center: Vector2i, radius: int):
	"""Révèle une zone spécifique (pour événements spéciaux, etc.)"""
	if not fog_of_war:
		return
	
	fog_of_war.reveal_area(center, radius)
	emit_signal("fog_updated")

func reveal_all():
	"""Révèle toute la carte (mode debug/éditeur)"""
	if not fog_of_war:
		return
	
	fog_of_war.reveal_all()
	emit_signal("fog_updated")

func hide_all():
	"""Cache toute la carte (reset)"""
	if not fog_of_war:
		return
	
	fog_of_war.reset_fog()
	emit_signal("fog_updated")

func is_position_visible(pos: Vector2i) -> bool:
	"""Vérifie si une position est actuellement visible pour le joueur"""
	if not fog_of_war:
		return false
	return fog_of_war.is_tile_visible(pos)

func is_position_explored(pos: Vector2i) -> bool:
	"""Vérifie si une position a été explorée"""
	if not fog_of_war:
		return false
	return fog_of_war.is_tile_explored(pos)

func get_fog_state_at(pos: Vector2i):
	"""Obtient l'état du fog à une position"""
	if not fog_of_war:
		return null
	return fog_of_war.get_fog_state(pos)

# =========================
# DEBUG
# =========================
func print_fog_stats():
	"""Affiche les statistiques du fog"""
	if not fog_of_war:
		return
	
	fog_of_war.print_fog_stats()
