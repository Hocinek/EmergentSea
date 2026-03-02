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


# =========================
# INITIALISATION
# =========================
func _ready():
	add_to_group("fog_manager")
	DEBUG.log("[FOGMGR] FogManager _ready() appelé")
	
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
	
	DEBUG.log("[FOGMGR] FogManager initialisé")


func _on_map_generated():
	"""Appelé quand la map est générée"""
	DEBUG.log("[FOGMGR] Signal map_generated reçu!")
	
	# CORRECTION : Passer is_ready à true IMMÉDIATEMENT au lieu d'attendre
	is_ready = true
	DEBUG.log("[FOGMGR] is_ready mis à TRUE")
	
	# Attendre quelques frames pour que les navires soient créés
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Première mise à jour immédiate
	DEBUG.log("[FOGMGR] Première mise à jour du brouillard...")
	update_fog()


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
	"""Met à jour le brouillard pour le joueur humain"""
	DEBUG.log("[FOGMGR] update_fog() APPELÉE")
	
	if not players_manager:
		DEBUG.log("[FOGMGR] ✗ Pas de PlayersManager")
		return
	
	# Récupérer le joueur humain
	var human_player = players_manager.get_human_player()
	if not human_player:
		DEBUG.log("[FOGMGR] ✗ Pas de joueur humain trouvé")
		return
	
	var ships = human_player.get_navires()
	DEBUG.log("[FOGMGR] Joueur humain trouvé: %s, navires: %d" % [human_player.player_name, ships.size()])
	
	# CORRECTION : Vérifier que fog_of_war existe avant de l'utiliser
	if not fog_of_war:
		DEBUG.log("[FOGMGR] ✗ ERREUR: FogOfWar n'existe plus!")
		return
	DEBUG.log("[FOGMGR] ✓ Appel de fog_of_war.update_vision_for_player()")
	# Mettre à jour la vision (sans print à chaque frame)
	fog_of_war.update_vision_for_player(human_player)


# =========================
# FONCTIONS PUBLIQUES
# =========================
func force_update():
	"""Force une mise à jour immédiate du brouillard"""
	DEBUG.log("[FOGMGR] force_update() APPELÉE !")
	DEBUG.log("[FOGMGR] is_ready: %s" % is_ready)
	DEBUG.log("[FOGMGR] fog_of_war existe: %s" % (fog_of_war != null))
	DEBUG.log("[FOGMGR] players_manager existe: %s" % (players_manager != null))
	
	# CORRECTION : Ne PAS vérifier is_ready pour force_update
	# C'est une mise à jour FORCÉE, on doit toujours l'exécuter
	if not fog_of_war or not players_manager:
		DEBUG.log("[FOGMGR] ✗ SKIP - fog_of_war ou players_manager manquant")
		return
	DEBUG.log("[FOGMGR] ✓ Mise à jour FORCÉE du brouillard (bypass is_ready)")
	update_fog()


# =========================
# ÉVÉNEMENTS
# =========================
func on_ship_moved(ship: Navires):
	"""Appelé quand un navire se déplace"""
	if not fog_of_war:
		return
	
	# Mise à jour immédiate de la vision autour du navire
	if ship.player_owner and ship.player_owner.is_human:
		DEBUG.log("[FOGMGR] Navire bougé, mise à jour vision")
		fog_of_war.reveal_around_position(ship.case_actuelle)
