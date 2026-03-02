class_name FogOfWar
extends Node2D

# =========================
# CONFIGURATION
# =========================
## Rayon de vision des navires (en cases)
@export var vision_radius: int = 5

## Opacité du brouillard (0.0 = transparent, 1.0 = opaque)
@export var fog_opacity: float = 0.95

# =========================
# DONNÉES INTERNES
# =========================
## Grille de visibilité : true = visible, false = brouillard
var visibility_grid := {}

## NOUVEAU : Rendu dynamique au lieu de sprites individuels
var fog_texture: Texture2D = null
var is_initialized := false


# =========================
# INITIALISATION
# =========================
func _ready():
	add_to_group("fog_of_war")
	
	# Z-index très haut pour être au-dessus de tout
	z_index = 10000
	z_as_relative = false
	
	DEBUG.log("[FOG] FogOfWar _ready() appelé - Rendu DYNAMIQUE")
	
	# Charger la texture
	fog_texture = Map_data.TileMountain
	if not fog_texture:
		DEBUG.log("[FOG] ERREUR: Texture de montagne non trouvée!",DEBUG.ERROR)
		return
	
	DEBUG.log("[FOG] Texture chargée: " + str(fog_texture))
	
	# Attendre que la map soit générée
	var map_manager = get_tree().get_first_node_in_group("Map_manager")
	if map_manager:
		DEBUG.log("[FOG] MapManager trouvé, connexion au signal...")
		if not map_manager.is_connected("map_generated", _on_map_generated):
			map_manager.connect("map_generated", _on_map_generated)
			DEBUG.log("[FOG] Signal map_generated connecté")
	else:
		DEBUG.log("[FOG] ERREUR: MapManager non trouvé!",DEBUG.ERROR)


func _on_map_generated():
	"""Appelé quand la map est générée"""
	DEBUG.log("[FOG] Signal map_generated reçu!")
	await get_tree().process_frame
	await get_tree().process_frame
	initialize_fog()


# =========================
# CRÉATION DU BROUILLARD
# =========================
func initialize_fog():
	"""Initialise la grille de visibilité (sans créer de sprites)"""
	DEBUG.log("[FOG] ========================================")
	DEBUG.log("[FOG] INITIALISATION DU BROUILLARD DYNAMIQUE")
	DEBUG.log("[FOG] ========================================")
	DEBUG.log("[FOG] Dimensions carte: "+str(Map_data.map_width) + "x" +str(Map_data.map_height))
	
	# Réinitialiser
	visibility_grid.clear()
	
	var fog_count = 0
	
	# Créer la grille de visibilité (pas de sprites)
	for y in range(Map_data.map_height):
		for x in range(Map_data.map_width):
			var pos = Vector2i(x, y)
			visibility_grid[pos] = false  # Tout est caché au départ
			fog_count += 1
	
	is_initialized = true
	
	# Forcer le redraw pour afficher le fog
	queue_redraw()
	
	DEBUG.log("[FOG] ========================================")
	DEBUG.log("[FOG] BROUILLARD INITIALISÉ SUR "+str(fog_count)+ " CASES")
	DEBUG.log("[FOG] MODE: Rendu dynamique (pas de sprites)")
	DEBUG.log("[FOG] TOUTE LA CARTE DEVRAIT ÊTRE NOIRE !")
	DEBUG.log("[FOG] ========================================")


# =========================
# RENDU DYNAMIQUE
# =========================
func _draw():
	"""Dessine le fog of war directement (pas de sprites)"""
	if not is_initialized or not fog_texture:
		return
	
	# Dessiner seulement les cases NON visibles
	for pos in visibility_grid.keys():
		if not visibility_grid[pos]:  # Si pas visible, dessiner le fog
			draw_fog_tile(pos)


func draw_fog_tile(pos: Vector2i):
	"""Dessine une case de brouillard"""
	var world_pos = Map_utils.case_vers_monde(pos)
	
	# Position relative au node
	var local_pos = world_pos - global_position
	
	# Calculer l'échelle pour couvrir la case
	var scale_x = Map_data.hex_width / fog_texture.get_width()
	var scale_y = Map_data.hex_height / fog_texture.get_height()
	var scale_factor = Vector2(scale_x * 1.1, scale_y * 1.1)  # 10% plus grand
	
	# Dessiner la texture avec modulation noire
	draw_set_transform(local_pos, 0, scale_factor)
	draw_texture(fog_texture, -fog_texture.get_size() / 2, Color(0, 0, 0, fog_opacity))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)  # Reset transform


# =========================
# MISE À JOUR DE LA VISION
# =========================
func update_vision_for_player(player: Player):
	"""Met à jour la vision pour un joueur (basé sur ses navires)"""
	if not is_initialized:
		return
	
	if player == null:
		return
		
	if not player.is_human:
		return
	
	# Récupérer tous les navires du joueur
	var player_ships = player.get_navires()
	
	var revealed_count = 0
	
	# Pour chaque navire, révéler autour de lui
	for ship in player_ships:
		if ship is Navires and ship.is_alive():
			var ship_pos = ship.case_actuelle
			var count = reveal_around_position(ship_pos)
			revealed_count += count
	
	# Redessiner si des cases ont été révélées
	if revealed_count > 0:
		DEBUG.log("[FOG] ✓ Révélé %d nouvelles cases" % revealed_count)
		queue_redraw()


func reveal_around_position(center: Vector2i) -> int:
	"""Révèle les cases autour d'une position - retourne le nombre de cases révélées"""
	var count = 0
	
	# Parcourir toutes les cases dans le rayon de vision
	for dy in range(-vision_radius, vision_radius + 1):
		for dx in range(-vision_radius, vision_radius + 1):
			var pos = Vector2i(center.x + dx, center.y + dy)
			
			# Vérifier que la case est valide
			if not Map_utils.is_case_valid(pos):
				continue
			
			# Vérifier la distance (vision circulaire)
			var distance = sqrt(dx * dx + dy * dy)
			if distance > vision_radius:
				continue
			
			# Révéler la case
			if reveal_tile(pos):
				count += 1
	
	return count


func reveal_tile(pos: Vector2i) -> bool:
	"""Révèle une case spécifique - retourne true si la case a été révélée"""
	if not visibility_grid.has(pos):
		return false
	
	# Si déjà visible, rien à faire
	if visibility_grid[pos]:
		return false
	
	# Marquer comme visible
	visibility_grid[pos] = true
	return true


func hide_tile(pos: Vector2i):
	"""Cache une case (remet le brouillard)"""
	if not Map_utils.is_case_valid(pos):
		return
	
	# Si déjà cachée, rien à faire
	if visibility_grid.has(pos) and not visibility_grid[pos]:
		return
	
	# Marquer comme cachée
	visibility_grid[pos] = false
	
	# Redessiner
	queue_redraw()


# =========================
# REQUÊTES
# =========================
func is_tile_visible(pos: Vector2i) -> bool:
	"""Vérifie si une case est visible"""
	if not visibility_grid.has(pos):
		return false
	return visibility_grid[pos]


func is_world_position_visible(world_pos: Vector2) -> bool:
	"""Vérifie si une position monde est visible"""
	var case_pos = Map_utils.monde_vers_case(world_pos)
	return is_tile_visible(case_pos)


# =========================
# UTILITAIRES
# =========================
func reset_fog():
	"""Remet le brouillard partout"""
	DEBUG.log("[FOG] ========================================")
	DEBUG.log("[FOG] RESET DU BROUILLARD - TOUT REDEVIENT NOIR")
	DEBUG.log("[FOG] ========================================")
	for pos in visibility_grid.keys():
		visibility_grid[pos] = false
	queue_redraw()


func reveal_all():
	"""Révèle toute la carte (mode triche/spectateur)"""
	DEBUG.log("[FOG] ========================================")
	DEBUG.log("[FOG] RÉVÉLATION TOTALE - TOUT DEVIENT VISIBLE")
	DEBUG.log("[FOG] ========================================")
	for pos in visibility_grid.keys():
		visibility_grid[pos] = true
	queue_redraw()


# =========================
# TESTS MANUELS
# =========================
func _input(event):
	# Appuyer sur F1 pour révéler tout (test)
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		reveal_all()
		DEBUG.log("[FOG] TEST - RÉVÉLATION TOTALE (F1)")
	
	# Appuyer sur F2 pour reset (test)
	if event is InputEventKey and event.pressed and event.keycode == KEY_F2:
		reset_fog()
		DEBUG.log("[FOG] TEST - RESET TOTAL (F2)")
	
	# Appuyer sur F3 pour afficher les stats (debug)
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		DEBUG.log("[FOG] ========================================")
		DEBUG.log("[FOG] DEBUG INFO")
		DEBUG.log("[FOG] ========================================")
		DEBUG.log("[FOG] Initialisé: "+str(is_initialized))
		DEBUG.log("[FOG] Mode: Rendu dynamique (_draw)")
		DEBUG.log("[FOG] Z-index node: "+ str(z_index))
		DEBUG.log("[FOG] Z-as-relative: " + str(z_as_relative))
		DEBUG.log("[FOG] Cases visibles: " +str(visibility_grid.values().count(true)))
		DEBUG.log("[FOG] Cases cachées: " +str(visibility_grid.values().count(false)))
		DEBUG.log("[FOG] ========================================")
