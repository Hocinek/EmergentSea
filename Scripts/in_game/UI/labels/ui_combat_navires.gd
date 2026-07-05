###===================================================================###
##                      UI_combat_navires                              ##
# Feedback visuel du combat - calqué sur UI_fish_navires              ##
# Affiche sur le navire :                                             ##
#   • les dégâts reçus   -> "-X ❤️"  (rouge)                          ##
#   • le coût en énergie -> "-X ⚡"  (jaune)                          ##
#   • ennemi trop loin   -> "🚫 Ennemi trop loin !"  (orange)         ##
# Ajouté dans la scène via ui_layer.add_child() depuis Navires.gd    ##
###===================================================================###
class_name UI_combat_navires
extends Control

# ================================
# CONSTANTES
# ================================
const FONT_SIZE := 22

# Décalage vertical de base au-dessus du navire
const OFFSET_Y_DMG    := -50.0   # dégâts   -> légèrement au-dessus
const OFFSET_Y_ENERGY := -50.0  # énergie  -> encore plus haut
const OFFSET_Y_MSG    := -80.0   # message  -> même niveau que dégâts

# Durée d'affichage (secondes)
const DURATION := 1.2

# ================================
# ÉTAT INTERNE
# ================================
## Entrée active { navire, text, color, timer, offset_y }
var _slots: Array[Dictionary] = []

# ================================
# READY
# ================================
func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	hide()

# ================================
# PROCESS
# ================================
func _process(delta: float) -> void:
	var still_active := false
	var i := 0
	while i < _slots.size():
		var s: Dictionary = _slots[i]
		s["timer"] -= delta
		if s["timer"] <= 0.0:
			_slots.remove_at(i)
		else:
			still_active = true
			i += 1

	if still_active:
		show()
		queue_redraw()
	else:
		hide()
		queue_redraw()

# ================================
# DRAW
# ================================
func _draw() -> void:
	if not visible:
		return

	var canvas_xform: Transform2D = get_viewport().get_canvas_transform()
	var font := ThemeDB.fallback_font
	var shadow := Color(0.0, 0.0, 0.0, 0.6)

	for s in _slots:
		var navire: Navires = s["navire"]
		if navire == null or not is_instance_valid(navire):
			continue

		var screen_pos: Vector2 = canvas_xform * navire.global_position
		screen_pos.y += s["offset_y"]

		# Centrer le texte horizontalement sur le navire
		var text_w: float = font.get_string_size(s["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		var draw_pos := Vector2(screen_pos.x - text_w * 0.5, screen_pos.y)

		# Ombre unique (1 seule copie décalée -> pas de fantômes)
		draw_string(font, draw_pos + Vector2(1.0, 1.0),
			s["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, shadow)

		# Texte coloré
		draw_string(font, draw_pos,
			s["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, s["color"])

# ================================
# HELPERS
# ================================
func _push(navire: Navires, text: String, color: Color, offset_y: float) -> void:
	# Remplace un slot existant pour ce navire + offset, sinon en crée un
	for s in _slots:
		if s["navire"] == navire and s["offset_y"] == offset_y:
			s["text"]  = text
			s["color"] = color
			s["timer"] = DURATION
			queue_redraw()
			return
	_slots.append({
		"navire":   navire,
		"text":     text,
		"color":    color,
		"timer":    DURATION,
		"offset_y": offset_y
	})
	show()
	queue_redraw()

# ================================
# API PUBLIQUE
# ================================

## Dégâts reçus par ce navire  ->  "-X ❤️"  (rouge vif)
func show_damage(navire: Navires, amount: int) -> void:
	_push(navire,
		"-%d ❤️" % amount,
		Color(1.0, 0.25, 0.25), OFFSET_Y_DMG)

## Coût en énergie du tir  ->  "-X ⚡"  (jaune)
func show_energy_cost(navire: Navires, amount: int) -> void:
	_push(navire,
		"-%d ⚡ " % amount,
		Color(1.0, 0.85, 0.15),
		OFFSET_Y_ENERGY)

## Ennemi hors de portée  ->  "🚫 Ennemi trop loin !"  (orange)
func show_out_of_range(navire: Navires) -> void:
	_push(navire,
		"🚫 Ennemi trop loin !",
		Color(1.0, 0.55, 0.05),
		OFFSET_Y_MSG)

## Ferme toutes les entrées liées à ce navire (ex. à la mort)
func close_for(navire: Navires) -> void:
	_slots = _slots.filter(func(s): return s["navire"] != navire)
	if _slots.is_empty():
		hide()
	queue_redraw()
