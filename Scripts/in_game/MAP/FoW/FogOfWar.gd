class_name FogOfWar
extends Node2D

# =========================
# ÉTATS DU FOG (système Civ6)
# =========================
enum FogState {
	UNEXPLORED,  # Jamais vu (noir complet)
	EXPLORED,    # Vu mais hors de portée (gris, figé)
	VISIBLE      # Actuellement visible (clair)
}

# =========================
# CONFIGURATION
# =========================
## Rayon de vision des navires (en cases)
@export var vision_radius: int = 5

## Opacité du brouillard non exploré (0.0 = transparent, 1.0 = opaque)
@export var unexplored_opacity: float = 0.95

## Opacité du brouillard exploré (0.0 = transparent, 1.0 = opaque)
@export var explored_opacity: float = 0.5

# =========================
# DONNÉES INTERNES
# =========================
## Grille d'états : {Vector2i: FogState}
var fog_states := {}

## Snapshots des tuiles explorées (pour l'effet "figé")
var explored_snapshots := {}  # {Vector2i: Dictionary}

## Textures pour le rendu
var fog_texture: Texture2D = null
var is_initialized := false

# =========================
# INITIALISATION
# =========================
func _ready():
	add_to_group("fog_of_war")
	
	# Z-index très haut pour être au-dessus de tout
	z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	z_as_relative = false
	
	DEBUG.log("[FOG] FogOfWar _ready() - Système Civ6 à 3 états")
	
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
	"""Initialise la grille d'états du fog"""
	DEBUG.log("[FOG] ========================================")
	DEBUG.log("[FOG] INITIALISATION - Système Civ6")
	DEBUG.log("[FOG] ========================================")
	DEBUG.log("[FOG] Dimensions carte: "+str(Map_data.map_width) + "x" +str(Map_data.map_height))
	
	# Réinitialiser
	fog_states.clear()
	explored_snapshots.clear()
	
	var fog_count = 0
	
	# Créer la grille d'états (tout UNEXPLORED au départ)
	for y in range(Map_data.map_height):
		for x in range(Map_data.map_width):
			var pos = Vector2i(x, y)
			fog_states[pos] = FogState.UNEXPLORED
			fog_count += 1
	
	is_initialized = true
	
	# Forcer le redraw pour afficher le fog
	queue_redraw()
	
	DEBUG.log("[FOG] ========================================")
	DEBUG.log("[FOG] BROUILLARD INITIALISÉ SUR "+str(fog_count)+ " CASES")
	DEBUG.log("[FOG] États: UNEXPLORED (noir) / EXPLORED (gris) / VISIBLE (clair)")
	DEBUG.log("[FOG] ========================================")

# =========================
# RENDU DYNAMIQUE
# =========================
func _draw():
	"""Dessine le fog of war avec 3 états différents"""
	if not is_initialized or not fog_texture:
		return
	
	# Dessiner selon l'état de chaque case
	for pos in fog_states.keys():
		var state = fog_states[pos]
		
		match state:
			FogState.UNEXPLORED:
				# Noir complet
				draw_fog_tile(pos, unexplored_opacity, Color.BLACK)
			
			FogState.EXPLORED:
				# Gris semi-transparent (effet "figé")
				draw_fog_tile(pos, explored_opacity, Color(0.3, 0.3, 0.3))
			
			FogState.VISIBLE:
				# Pas de fog (ne rien dessiner)
				pass

func draw_fog_tile(pos: Vector2i, opacity: float, tint: Color):
	"""Dessine une case de brouillard avec une opacité et teinte données"""
	var world_pos = Map_utils.case_vers_monde(pos)
	
	# Position relative au node
	var local_pos = world_pos - global_position
	
	# Calculer l'échelle pour couvrir la case
	var scale_x = Map_data.hex_width / fog_texture.get_width()
	var scale_y = Map_data.hex_height / fog_texture.get_height()
	var scale_factor = Vector2(scale_x, scale_y)
	
	# Dessiner la texture avec la couleur et l'opacité
	var final_color = Color(tint.r, tint.g, tint.b, opacity)
	draw_set_transform(local_pos, 0, scale_factor)
	draw_texture(fog_texture, -fog_texture.get_size() / 2, final_color)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)  # Reset transform

# =========================
# MISE À JOUR DE LA VISION
# =========================
func update_vision_for_player(player: Player):
	"""Met à jour la vision pour un joueur (système Civ6)"""
	if not is_initialized:
		return
	
	if player == null:
		return
		
	if not player.is_human:
		return
	
	# Récupérer tous les navires du joueur
	var player_ships = player.get_navires()
	
	# ÉTAPE 1 : Toutes les cases VISIBLE deviennent EXPLORED
	var explored_count = 0
	for pos in fog_states.keys():
		if fog_states[pos] == FogState.VISIBLE:
			fog_states[pos] = FogState.EXPLORED
			explored_count += 1
	
	# ÉTAPE 2 : Révéler autour de chaque navire
	var revealed_count = 0
	for ship in player_ships:
		if ship is Navires and ship.is_alive():
			var ship_pos = ship.case_actuelle
			# Rayon de base + bonus équipage (bonus_vision est en unités monde → on convertit en cases)
			var ship_vision_bonus: int = 0
			if ship.has_method("get_crew_vision_bonus"):
				ship_vision_bonus = ship.get_crew_vision_bonus()
			var ship_radius := vision_radius + ship_vision_bonus
			var count = reveal_around_position(ship_pos, ship_radius)
			revealed_count += count
			
	# ÉTAPE 3 : Révéler autour des ports possédés
	var all_ports = get_tree().get_nodes_in_group("ports")
	for port in all_ports:
		if port is Ports and port.player_owner == player:
			reveal_around_position(port.case_actuelle)
			
	# Redessiner si des changements ont eu lieu
	if explored_count > 0 or revealed_count > 0:
		DEBUG.log("[FOG] ✓ Révélé %d nouvelles cases" % revealed_count)
		queue_redraw()

## Calcule la vraie distance hexagonale — grille Odd-Q Pointy-Top
func _hex_distance(a: Vector2i, b: Vector2i) -> int:
	# Conversion Odd-Q entière : forcer int pour éviter dérive float
	var aq: int = a.x
	var ar: int = a.y - (a.x - (a.x & 1)) / 2
	var bq: int = b.x
	var br: int = b.y - (b.x - (b.x & 1)) / 2
	var dq: int = bq - aq
	var dr: int = br - ar
	return (abs(dq) + abs(dr) + abs(dq + dr)) / 2

func reveal_around_position(center: Vector2i, radius_override: int = -1) -> int:
	"""Révèle les cases atteignables depuis center en au plus `radius` déplacements hex.
	Utilise un BFS sur les voisins réels (get_neighbors_all) pour coller
	exactement à la topologie de la grille — sans compter la case de départ."""
	var radius := radius_override if radius_override >= 0 else vision_radius

	var visited: Dictionary = {}
	var queue: Array = []

	visited[center] = 0
	queue.append([center, 0])

	var count := 0
	var head := 0

	while head < queue.size():
		var current = queue[head]
		head += 1
		var pos: Vector2i = current[0]
		var depth: int = current[1]

		# Révéler la case 
		if reveal_tile(pos):
			count += 1

		# Continuer à explorer si on n'a pas atteint la limite
		if depth < radius:
			for neighbor in Map_utils.get_neighbors_all(pos):
				if not visited.has(neighbor):
					visited[neighbor] = depth + 1
					queue.append([neighbor, depth + 1])

	return count

func reveal_tile(pos: Vector2i) -> bool:
	"""Révèle une case (passe de UNEXPLORED/EXPLORED à VISIBLE)"""
	if not fog_states.has(pos):
		return false
	
	var old_state = fog_states[pos]
	
	# Si déjà visible, rien à faire
	if old_state == FogState.VISIBLE:
		return false
	
	# Capturer un snapshot si c'est la première découverte
	if old_state == FogState.UNEXPLORED:
		capture_snapshot(pos)
	
	# Marquer comme visible
	fog_states[pos] = FogState.VISIBLE
	return true

func hide_tile(pos: Vector2i):
	"""Cache une case (remet le brouillard - UNEXPLORED)"""
	if not Map_utils.is_case_valid(pos):
		return
	
	if not fog_states.has(pos):
		return
	
	# Marquer comme non explorée
	fog_states[pos] = FogState.UNEXPLORED
	
	# Supprimer le snapshot
	if explored_snapshots.has(pos):
		explored_snapshots.erase(pos)
	
	# Redessiner
	queue_redraw()

# =========================
# GESTION DES SNAPSHOTS
# =========================
func capture_snapshot(pos: Vector2i):
	"""Capture l'état actuel d'une tuile pour l'effet "figé" """
	if pos.y >= Map_data.tiles.size() or pos.x >= Map_data.tiles[pos.y].size():
		return
	
	explored_snapshots[pos] = {
		"terrain": Map_data.tiles[pos.y][pos.x],
		"timestamp": Time.get_ticks_msec(),
		"units": []  # Pourra être étendu pour sauvegarder les unités visibles
	}

func get_snapshot(pos: Vector2i) -> Dictionary:
	"""Récupère le snapshot d'une tuile"""
	return explored_snapshots.get(pos, {})

# =========================
# REQUÊTES
# =========================
func is_tile_visible(pos: Vector2i) -> bool:
	"""Vérifie si une case est actuellement visible"""
	if not fog_states.has(pos):
		return false
	return fog_states[pos] == FogState.VISIBLE

func is_tile_explored(pos: Vector2i) -> bool:
	"""Vérifie si une case a déjà été explorée (EXPLORED ou VISIBLE)"""
	if not fog_states.has(pos):
		return false
	return fog_states[pos] in [FogState.EXPLORED, FogState.VISIBLE]

func is_tile_unexplored(pos: Vector2i) -> bool:
	"""Vérifie si une case n'a jamais été explorée"""
	if not fog_states.has(pos):
		return true
	return fog_states[pos] == FogState.UNEXPLORED

func get_fog_state(pos: Vector2i) -> FogState:
	"""Retourne l'état du fog à une position"""
	return fog_states.get(pos, FogState.UNEXPLORED)

func is_world_position_visible(world_pos: Vector2) -> bool:
	"""Vérifie si une position monde est visible"""
	var case_pos = Map_utils.monde_vers_case(world_pos)
	return is_tile_visible(case_pos)

# =========================
# UTILITAIRES
# =========================
func reset_fog():
	"""Remet le brouillard partout (UNEXPLORED)"""
	DEBUG.log("[FOG] ========================================")
	DEBUG.log("[FOG] RESET DU BROUILLARD - TOUT REDEVIENT NOIR")
	DEBUG.log("[FOG] ========================================")
	for pos in fog_states.keys():
		fog_states[pos] = FogState.UNEXPLORED
	explored_snapshots.clear()
	queue_redraw()

func reveal_all():
	"""Révèle toute la carte (mode triche/spectateur)"""
	DEBUG.log("[FOG] ========================================")
	DEBUG.log("[FOG] RÉVÉLATION TOTALE - TOUT DEVIENT VISIBLE")
	DEBUG.log("[FOG] ========================================")
	for pos in fog_states.keys():
		if fog_states[pos] == FogState.UNEXPLORED:
			capture_snapshot(pos)
		fog_states[pos] = FogState.VISIBLE
	queue_redraw()

func reveal_area(center: Vector2i, radius: int):
	"""Révèle une zone spécifique"""
	var cq: int = center.x
	var cr: int = center.y - (center.x - (center.x & 1)) / 2

	for dq in range(-radius, radius + 1):
		var r_min = max(-radius, -dq - radius)
		var r_max = min(radius, -dq + radius)
		for dr in range(r_min, r_max + 1):
			var q: int = cq + dq
			var r: int = cr + dr
			var col: int = q
			var row: int = r + (q - (q & 1)) / 2
			var pos = Vector2i(col, row)

			if not Map_utils.is_case_valid(pos):
				continue

			reveal_tile(pos)

	queue_redraw()

# =========================
# STATISTIQUES (DEBUG)
# =========================
func get_fog_stats() -> Dictionary:
	"""Retourne des statistiques sur l'état du fog"""
	var unexplored = 0
	var explored = 0
	var visible = 0
	
	for state in fog_states.values():
		match state:
			FogState.UNEXPLORED:
				unexplored += 1
			FogState.EXPLORED:
				explored += 1
			FogState.VISIBLE:
				visible += 1
	
	var total = unexplored + explored + visible
	
	return {
		"unexplored": unexplored,
		"explored": explored,
		"visible": visible,
		"total": total,
		"unexplored_percent": (unexplored * 100.0 / total) if total > 0 else 0,
		"explored_percent": (explored * 100.0 / total) if total > 0 else 0,
		"visible_percent": (visible * 100.0 / total) if total > 0 else 0
	}

func print_fog_stats():
	"""Affiche les statistiques du fog"""
	var stats = get_fog_stats()
	DEBUG.log("[FOG] ========================================")
	DEBUG.log("[FOG] STATISTIQUES DU FOG OF WAR")
	DEBUG.log("[FOG] ========================================")
	DEBUG.log("[FOG] UNEXPLORED: %d (%.1f%%)" % [stats.unexplored, stats.unexplored_percent])
	DEBUG.log("[FOG] EXPLORED: %d (%.1f%%)" % [stats.explored, stats.explored_percent])
	DEBUG.log("[FOG] VISIBLE: %d (%.1f%%)" % [stats.visible, stats.visible_percent])
	DEBUG.log("[FOG] TOTAL: %d" % stats.total)
	DEBUG.log("[FOG] ========================================")

# =========================
# TESTS MANUELS
# =========================
func _input(event):
	# F1 : Révéler tout
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		reveal_all()
		DEBUG.log("[FOG] TEST - RÉVÉLATION TOTALE (F1)")
	
	# F2 : Reset
	if event is InputEventKey and event.pressed and event.keycode == KEY_F2:
		reset_fog()
		DEBUG.log("[FOG] TEST - RESET TOTAL (F2)")
	
	# F3 : Afficher les stats
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		print_fog_stats()
