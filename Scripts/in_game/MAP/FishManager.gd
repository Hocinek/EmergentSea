class_name FishManager
extends Node

# =========================
# CONFIGURATION
# =========================
@export var fish_max_stock: int = 20
@export var fish_initial_stock: int = 15
@export var fish_regen_per_turn: float = 0.5

# =========================
# DONNÉES INTERNES
# =========================
var fish_stocks: Dictionary = {}
var player_snapshots: Dictionary = {}
var current_turn: int = 0

signal fish_stock_changed(pos: Vector2i, new_stock: float)

# =========================
# INITIALISATION
# =========================
func _ready() -> void:
	add_to_group("fish_manager")
	DEBUG.log("[FISH] FishManager initialisé")

func initialize_fish_tiles() -> void:
	fish_stocks.clear()
	for pos in Map_data.fish_cases:
		fish_stocks[pos] = float(fish_initial_stock)
	DEBUG.log("[FISH] %d cases de pêche initialisées avec un stock de %d" % [
		fish_stocks.size(), fish_initial_stock
	])

# =========================
# RÉGÉNÉRATION
# =========================
func on_turn_end() -> void:
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
	if not fish_stocks.has(pos):
		return false
	return fish_stocks[pos] >= 1.0

func harvest_fish(pos: Vector2i, amount: int) -> int:
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
	for pos in fish_stocks.keys():
		if fog.is_tile_visible(pos):
			update_snapshot_for_player(player, pos)

# =========================
# LECTURE (selon le fog)
# =========================
func get_stock_for_player(player: Player, pos: Vector2i, fog: FogOfWar) -> Dictionary:
	if not fish_stocks.has(pos):
		return { "known": false, "stock": 0, "is_live": false, "turn": -1 }
	var fog_state = fog.get_fog_state(pos)
	match fog_state:
		FogOfWar.FogState.VISIBLE:
			update_snapshot_for_player(player, pos)
			return { "known": true, "stock": int(fish_stocks[pos]), "is_live": true, "turn": current_turn }
		FogOfWar.FogState.EXPLORED:
			var pid = player.player_id
			if player_snapshots.has(pid) and player_snapshots[pid].has(pos):
				var snap = player_snapshots[pid][pos]
				return { "known": true, "stock": snap["stock"], "is_live": false, "turn": snap["turn"] }
			return { "known": false, "stock": 0, "is_live": false, "turn": -1 }
		_:
			return { "known": false, "stock": 0, "is_live": false, "turn": -1 }

# =========================
# UTILITAIRES
# =========================
func get_real_stock(pos: Vector2i) -> int:
	return int(fish_stocks.get(pos, 0.0))

func is_fish_tile(pos: Vector2i) -> bool:
	return fish_stocks.has(pos)
