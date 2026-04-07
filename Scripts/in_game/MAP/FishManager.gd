class_name FishManager
extends Node

# =========================
# CONFIGURATION
# =========================
## Stock initial de poissons par case
@export var fish_max_stock: int = 25

## Stock de départ (peut être différent du max)
@export var fish_initial_stock: int = 18

## Régénération par tour (très lente)
@export var fish_regen_per_turn: float = 0.5

## Nombre de cases de pêche à générer
@export var fish_tile_count: int = 12

# =========================
# DONNÉES INTERNES
# =========================
## Stock réel de chaque case : { Vector2i: float }
var fish_stocks: Dictionary = {}

## Snapshots par joueur : { player_id: { Vector2i: { stock, turn } } }
## Mémorise ce que chaque joueur a VU la dernière fois qu'il était à portée
var player_snapshots: Dictionary = {}

## Tour actuel (pour savoir quand les snapshots ont été pris)
var current_turn: int = 0

# =========================
# SIGNAUX
# =========================
signal fish_stock_changed(pos: Vector2i, new_stock: float)

# =========================
# INITIALISATION
# =========================
func _ready() -> void:
	add_to_group("fish_manager")
	DEBUG.log("[FISH] FishManager initialisé")


func initialize_fish_tiles() -> void:
	"""Initialise les stocks pour toutes les cases de pêche déjà générées dans Map_data"""
	fish_stocks.clear()

	for pos in Map_data.fish_cases:
		fish_stocks[pos] = float(fish_initial_stock)

	DEBUG.log("[FISH] %d cases de pêche initialisées avec un stock de %d" % [
		fish_stocks.size(), fish_initial_stock
	])


# =========================
# RÉGÉNÉRATION (appelée à chaque fin de tour)
# =========================
func on_turn_end() -> void:
	"""Régénère lentement toutes les cases de pêche. À appeler depuis le TurnManager."""
	current_turn += 1
	for pos in fish_stocks.keys():
		var current = fish_stocks[pos]
		if current < fish_max_stock:
			fish_stocks[pos] = minf(current + fish_regen_per_turn, float(fish_max_stock))
			emit_signal("fish_stock_changed", pos, fish_stocks[pos])

	DEBUG.log("[FISH] Tour %d - Régénération terminée" % current_turn)


# =========================
# PÊCHE
# =========================
func can_fish_at(pos: Vector2i) -> bool:
	"""Vérifie si on peut pêcher sur cette case (existe et a du stock)"""
	if not fish_stocks.has(pos):
		return false
	return fish_stocks[pos] >= 1.0


func is_open_water_fishable(pos: Vector2i) -> bool:
	"""Vérifie si la case est de l'eau ordinaire (pas une zone de pêche) mais pêchable quand même."""
	return not fish_stocks.has(pos)


func harvest_fish(pos: Vector2i, amount: int) -> int:
	"""Prélève des poissons. Retourne la quantité réellement pêchée."""
	if not fish_stocks.has(pos):
		return 0

	var available = int(fish_stocks[pos])
	var harvested = mini(amount, available)

	fish_stocks[pos] = float(available - harvested)
	emit_signal("fish_stock_changed", pos, fish_stocks[pos])

	DEBUG.log("[FISH] Case %s : pêche de %d poissons (reste %d)" % [
		pos, harvested, int(fish_stocks[pos])
	])
	return harvested


# =========================
# SNAPSHOTS PAR JOUEUR (Fog of War)
# =========================
func update_snapshot_for_player(player: Player, pos: Vector2i) -> void:
	"""Met à jour le snapshot d'un joueur sur une case de pêche visible."""
	if not fish_stocks.has(pos):
		return

	var pid = player.player_id
	if not player_snapshots.has(pid):
		player_snapshots[pid] = {}

	player_snapshots[pid][pos] = {
		"stock": int(fish_stocks[pos]),
		"turn": current_turn
	}


func update_all_visible_snapshots_for_player(player: Player, fog: FogOfWar) -> void:
	"""Parcourt toutes les cases de pêche visibles par ce joueur et met à jour leurs snapshots."""
	for pos in fish_stocks.keys():
		if fog.is_tile_visible(pos):
			update_snapshot_for_player(player, pos)


# =========================
# LECTURE (selon le fog)
# =========================
func get_stock_for_player(player: Player, pos: Vector2i, fog: FogOfWar) -> Dictionary:
	"""
	Retourne les infos de stock à afficher selon l'état du fog :
	- VISIBLE     → stock réel en temps réel
	- EXPLORED    → dernier snapshot connu du joueur
	- UNEXPLORED  → rien (case inconnue)
	Retourne { "known": bool, "stock": int, "is_live": bool, "turn": int }
	"""
	if not fish_stocks.has(pos):
		return { "known": false, "stock": 0, "is_live": false, "turn": -1 }

	var fog_state = fog.get_fog_state(pos)

	match fog_state:
		FogOfWar.FogState.VISIBLE:
			# Données en temps réel — mettre à jour le snapshot au passage
			update_snapshot_for_player(player, pos)
			return {
				"known": true,
				"stock": int(fish_stocks[pos]),
				"is_live": true,
				"turn": current_turn
			}

		FogOfWar.FogState.EXPLORED:
			# Dernier snapshot connu
			var pid = player.player_id
			if player_snapshots.has(pid) and player_snapshots[pid].has(pos):
				var snap = player_snapshots[pid][pos]
				return {
					"known": true,
					"stock": snap["stock"],
					"is_live": false,
					"turn": snap["turn"]
				}
			# Jamais observé de près (exploré mais pas regardé)
			return { "known": false, "stock": 0, "is_live": false, "turn": -1 }

		_: # UNEXPLORED
			return { "known": false, "stock": 0, "is_live": false, "turn": -1 }


# =========================
# UTILITAIRES
# =========================
func get_real_stock(pos: Vector2i) -> int:
	"""Stock réel (sans filtre fog — usage interne / IA)"""
	return int(fish_stocks.get(pos, 0.0))


func is_fish_tile(pos: Vector2i) -> bool:
	return fish_stocks.has(pos)


func get_all_fish_positions() -> Array:
	return fish_stocks.keys()


func get_stats() -> Dictionary:
	var total = 0.0
	var depleted = 0
	for v in fish_stocks.values():
		total += v
		if v < 1.0:
			depleted += 1
	return {
		"tiles": fish_stocks.size(),
		"total_stock": int(total),
		"depleted_tiles": depleted,
		"current_turn": current_turn
	}
