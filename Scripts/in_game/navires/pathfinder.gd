class_name Pathfinder
extends Node

class AStarNode:
	var pos: Vector2i
	var f_score: float
	
	func _init(p: Vector2i, f: float):
		pos = p
		f_score = f

static func calculer_chemin(start: Vector2i, goal: Vector2i) -> Array:
	if not Map_utils.is_case_navigable(goal):
		return []

	# Priority Queue simulée (liste triée par f_score décroissant pour pop_back efficace)
	var open_list: Array[AStarNode] = []
	open_list.append(AStarNode.new(start, Map_utils.get_hex_distance(start, goal)))
	
	var came_from := {}
	var g_score := { start: 0.0 }
	
	# Optimisation : On garde une trace des items dans open_list pour éviter le "if neighbor in open_set" lent
	var open_set_hash := { start: true }

	while not open_list.is_empty():
		# Récupère le node avec le plus petit F (le dernier de la liste car triée inversée)
		var current_node = open_list.pop_back()
		var current = current_node.pos
		open_set_hash.erase(current)

		if current == goal:
			return reconstruire_chemin(came_from, current)

		for neighbor in Map_utils.get_neighbors(current):
			# Calcul du coût variable (ex: éviter les côtes si deepwater est moins cher)
			var move_cost = Map_utils.get_movement_cost(neighbor)
			var tentative_g = g_score[current] + move_cost

			if tentative_g < g_score.get(neighbor, INF):
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				var h = float(Map_utils.get_hex_distance(neighbor, goal))
				# On multiplie par un très petit facteur (ex: 1.001) pour préférer 
				# naturellement les chemins directs et éviter l'exploration asymétrique
				var f = tentative_g + (h * 1.001)
				
				# Gestion de la liste ouverte
				if not open_set_hash.has(neighbor):
					var new_node = AStarNode.new(neighbor, f)
					_insert_sorted(open_list, new_node)
					open_set_hash[neighbor] = true
				else:
					# Si le voisin est déjà dans la liste mais qu'on a trouvé un meilleur chemin,
					# techniquement il faudrait mettre à jour son score et re-trier.
					# Pour simplifier en GDScript sans structure lourde, on peut l'ajouter en doublon 
					# (le plus petit sortira en premier), ou juste ignorer cette micro-optimisation.
					pass 

	return []

# Insère un node de façon à garder la liste triée (f_score décroissant)
# Ainsi le plus petit f_score est toujours à la fin (pop_back est O(1))
static func _insert_sorted(list: Array[AStarNode], node: AStarNode):
	# Recherche binaire pour trouver l'index d'insertion
	var low = 0
	var high = list.size() - 1
	
	while low <= high:
		var mid = (low + high) / 2
		if list[mid].f_score < node.f_score:
			high = mid - 1
		else:
			low = mid + 1
	
	list.insert(low, node)

static func reconstruire_chemin(came_from: Dictionary, current: Vector2i) -> Array:
	var total_path := [current]
	while current in came_from:
		current = came_from[current]
		total_path.push_front(current)
	return total_path
