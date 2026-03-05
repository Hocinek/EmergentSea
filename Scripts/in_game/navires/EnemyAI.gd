extends Node

# =========================
# RÉFÉRENCE AU NAVIRE
# =========================
var navire: Navires = null
# =========================
# TIMERS ET INTERVALLES
# =========================
var think_timer: float = 0.0
var think_interval: float = 1.5  # Réfléchit toutes les 1.5 secondes
# =========================
# ÉTAT DE L'IA
# =========================
enum IAState {IDLE,CHASING,ATTACKING,FISHING,RETREATING}
var current_state: IAState = IAState.IDLE
var current_target: Navires = null
# Suivi de l'état de la cible pour détecter sa mort
var target_was_alive: bool = false
# =========================
# PARAMÈTRES DE COMPORTEMENT
# =========================
@export var attack_range_threshold: int = 3       # Distance (en cases) à partir de laquelle l'IA tente de tirer
@export var retreat_health_threshold: float = 0.3  # Fuit si vie < 30% du max
@export var fish_when_idle: bool = true            # Pêche si rien à faire et énergie suffisante
@export var max_chase_steps: int = 3               # Nombre de cases à parcourir par tick de déplacement

# =========================
# INITIALISATION
# =========================
func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	# Récupérer le navire parent
	var p = get_parent()
	while p != null:
		if p is Navires:
			navire = p
			break
		p = p.get_parent()
	if navire == null:
		push_error(">>> [IA] ERREUR CRITIQUE - Aucun Navires trouvé dans les parents !")
		return
	print(">>> [IA] OK - attachée au navire id=", navire.id)
	# Premier cycle de décision après 2 secondes
	await get_tree().create_timer(2.0).timeout
	_think()
	
# =========================
# BOUCLE PRINCIPALE
# =========================
func _process(delta: float) -> void:
	if navire == null or not is_instance_valid(navire):
		return
	# Pas de décision pendant le déplacement
	if navire.is_moving:
		return
	# Détecter si la cible courante vient de mourir → reciblement immédiat
	if _target_just_died():
		print(">>> [IA %d] Cible éliminée ! Recherche d'une nouvelle cible..." % navire.id)
		_invalidate_target()
		think_timer = 0.0  # Force un nouveau cycle immédiatement
	think_timer -= delta
	if think_timer > 0.0:
		return
	think_timer = think_interval
	_think()

# =========================
# CERVEAU DE L'IA
# =========================
func _think() -> void:
	"""Choisit l'action la plus pertinente selon l'état courant"""
	if navire == null or not is_instance_valid(navire) or not navire.is_alive():
		return
	# 1. RETRAITE si vie critique
	if _should_retreat():
		_do_retreat()
		return
	# 2. Toujours réévaluer la cible la plus proche (même si une cible existe déjà)
	var nearest = _find_nearest_enemy()
	if nearest != current_target:
		if nearest != null:
			print(">>> [IA %d] Nouvelle cible plus proche : navire id=%d" % [navire.id, nearest.id])
		_disconnect_target_death_signal()
		current_target = nearest
	if current_target != null:
		var dist_cases = _distance_en_cases(navire.getPosition(), current_target.getPosition())
		# 3. ATTAQUE si à portée
		if dist_cases <= attack_range_threshold:
			_do_attack(current_target)
			current_state = IAState.ATTACKING
			return
		# 4. POURSUITE sinon
		_do_chase(current_target)
		current_state = IAState.CHASING
		return
	# 5. PÊCHE si inactif et conditions remplies
	if fish_when_idle and _can_fish():
		_do_fish()
		current_state = IAState.FISHING
		return
	# 6. IDLE - rien à faire
	current_state = IAState.IDLE
	print(">>> [IA %d] En attente..." % navire.id)
# =========================
# ACTIONS
# =========================

## DÉPLACEMENT VERS UNE CIBLE
func _do_chase(cible: Navires) -> void:
	if navire.is_moving:
		return
	var depart = navire.getPosition()
	var arrivee = cible.getPosition()
	if depart == arrivee:
		return
	var chemin = Pathfinder.calculer_chemin(depart, arrivee)
	if chemin.is_empty():
		print(">>> [IA %d] Aucun chemin vers la cible !" % navire.id)
		return
	# Se déplace de quelques cases seulement pour rester réactif
	var steps = mini(chemin.size(), max_chase_steps)
	navire.path = chemin.slice(0, steps)
	navire.is_moving = true
	navire.show_arrow = false

	# Connecter le signal de mort de la cible
	_connect_target_death_signal(cible)
	current_state = IAState.CHASING
	target_was_alive = cible.is_alive()
	print(">>> [IA %d] Poursuite du navire id=%d - %d cases" % [navire.id, cible.id, steps])

## TIR SUR UNE CIBLE
func _do_attack(cible: Navires) -> void:
	if cible == null or not is_instance_valid(cible) or not cible.is_alive():
		_invalidate_target()
		return
	if navire.energie < 20:
		print(">>> [IA %d] Pas assez d'énergie pour tirer !" % navire.id)
		return
	var target_case = cible.getPosition()
	if not navire.is_in_range(target_case):
		# Pas encore à portée : se rapprocher
		_do_chase(cible)
		return
	# Connecter le signal de mort si pas encore fait
	_connect_target_death_signal(cible)
	# Tirer directement sur le navire cible
	navire.shoot_at(cible)
	navire.energie = max(navire.energie - 20, 0)
	target_was_alive = cible.is_alive()
	current_state = IAState.ATTACKING
	print(">>> [IA %d] TIR sur navire id=%d ! (vie restante: %d)" % [navire.id, cible.id, cible.vie])
## RETRAITE VERS UNE CASE SÛRE (loin des ennemis)

func _do_retreat() -> void:
	if navire.is_moving:
		return
	var safe_case = _find_safe_case()
	if safe_case == Vector2i(-1, -1):
		print(">>> [IA %d] Aucune case sûre trouvée..." % navire.id)
		return
	var chemin = Pathfinder.calculer_chemin(navire.getPosition(), safe_case)
	if chemin.is_empty():
		return
	var steps = mini(chemin.size(), max_chase_steps)
	navire.path = chemin.slice(0, steps)
	navire.is_moving = true
	navire.show_arrow = false
	current_state = IAState.RETREATING
	print(">>> [IA %d] RETRAITE vers %s" % [navire.id, safe_case])

## PÊCHE
func _do_fish() -> void:
	if navire.is_fishing or navire.is_moving:
		return
	navire.try_start_fishing()
	current_state = IAState.FISHING
	print(">>> [IA %d] Pêche en cours..." % navire.id)

# =========================
# CONDITIONS / HELPERS
# =========================
func _should_retreat() -> bool:
	"""Retourne true si le navire doit fuir"""
	if navire.maxvie == 0:
		return false
	return float(navire.vie) / float(navire.maxvie) < retreat_health_threshold

func _can_fish() -> bool:
	"""Retourne true si les conditions de pêche sont remplies"""
	if navire.is_fishing or navire.is_moving:
		return false
	if navire.energie < navire.fish_energy_cost:
		return false
	if not Map_utils.is_on_water(navire.global_position):
		return false
	return true

func _find_nearest_enemy() -> Navires:
	"""Trouve le navire ennemi vivant le plus proche"""
	var cible: Navires = null
	var dist_min = INF
	for ship in get_tree().get_nodes_in_group("ships"):
		if ship is Navires and ship != navire and navire.is_enemy_of(ship) and ship.is_alive():
			var d = navire.global_position.distance_to(ship.global_position)
			if d < dist_min:
				dist_min = d
				cible = ship
	return cible

func _find_safe_case() -> Vector2i:
	"""Cherche une case navigable loin de tous les ennemis"""
	var best_case = Vector2i(-1, -1)
	var best_score = -INF
	var pos = navire.getPosition()
	# Tester les cases dans un rayon de 5
	for dx in range(-5, 6):
		for dy in range(-5, 6):
			var candidate = pos + Vector2i(dx, dy)
			if not Map_utils.is_case_navigable(candidate):
				continue
			# Calculer la distance minimale aux ennemis
			var min_enemy_dist = INF
			for ship in get_tree().get_nodes_in_group("ships"):
				if ship is Navires and navire.is_enemy_of(ship) and ship.is_alive():
					var d = candidate.distance_to(ship.getPosition())
					if d < min_enemy_dist:
						min_enemy_dist = d
			# Préférer les cases loin des ennemis et proches du navire actuel
			var dist_from_self = candidate.distance_to(pos)
			var score = min_enemy_dist - dist_from_self * 0.5
			if score > best_score:
				best_score = score
				best_case = candidate
	return best_case

func _distance_en_cases(a: Vector2i, b: Vector2i) -> int:
	"""Distance de Manhattan entre deux cases"""
	return abs(a.x - b.x) + abs(a.y - b.y)
# =========================
# GESTION DE LA CIBLE
# =========================

func _connect_target_death_signal(cible: Navires) -> void:
	"""Se connecte au signal de mort de la cible pour réagir immédiatement"""
	if cible == null or not is_instance_valid(cible):
		return
	# Éviter les connexions en double
	if not cible.ship_destroyed.is_connected(_on_target_destroyed):
		cible.ship_destroyed.connect(_on_target_destroyed)
		print(">>> [IA %d] Signal mort connecté sur navire id=%d" % [navire.id, cible.id])

func _disconnect_target_death_signal() -> void:
	"""Se déconnecte du signal de mort de l'ancienne cible"""
	if current_target == null or not is_instance_valid(current_target):
		return
	if current_target.ship_destroyed.is_connected(_on_target_destroyed):
		current_target.ship_destroyed.disconnect(_on_target_destroyed)

func _on_target_destroyed(_destroyed_ship: Navires) -> void:
	"""Callback appelé dès qu'une cible suivie est détruite"""
	print(">>> [IA %d] Signal reçu : cible détruite ! Reciblement immédiat." % navire.id)
	_invalidate_target()
	think_timer = 0.0  # Déclenche un nouveau _think() au prochain frame

func _invalidate_target() -> void:
	"""Réinitialise la cible courante proprement"""
	_disconnect_target_death_signal()
	current_target = null
	target_was_alive = false
	current_state = IAState.IDLE
	# Arrêter le déplacement en cours vers l'ancienne cible si possible
	if navire and is_instance_valid(navire) and not navire.is_moving:
		navire.path = []

func _target_just_died() -> bool:
	"""Détecte si la cible suivie vient de mourir (fallback si signal manqué)"""
	if current_target == null:
		return false
	if not is_instance_valid(current_target):
		return true  # L'instance n'existe plus = mort
	if target_was_alive and not current_target.is_alive():
		return true
	return false
