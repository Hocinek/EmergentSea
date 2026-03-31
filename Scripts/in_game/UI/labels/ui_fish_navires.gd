###===================================================================###
##                        UI_fish_navires                             ##
# Affichage pêche — calqué sur HexContextMenu                        ##
# Ajouté dans la scène via ui_layer.add_child() depuis Navires.gd    ##
###===================================================================###
class_name UI_fish_navires
extends Control

# ================================
# CONSTANTES
# ================================
const FONT_SIZE   := 22
const OUTLINE_OFF := 3.0
const OFFSET_Y    := -80.0

# ================================
# STATE
# ================================
var _navire:   Navires = null
var _text:     String  = ""
var _color:    Color   = Color.WHITE
var _timer:    float   = 0.0
var _duration: float   = 0.8

# ================================
# READY — identique à HexContextMenu
# ================================
func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	hide()

# ================================
# PROCESS — timer feedback + redraw
# ================================
func _process(delta: float) -> void:
	if not visible:
		return
	if _timer > 0.0:
		_timer -= delta
		if _timer <= 0.0:
			close()
			return
	queue_redraw()

# ================================
# DRAW — coords écran comme HexContextMenu
# ================================
func _draw() -> void:
	if not visible or _navire == null:
		return

	var screen_pos: Vector2 = get_viewport().get_canvas_transform() * _navire.global_position
	screen_pos.y += OFFSET_Y

	# Outline
	var outline := Color(0.0, 0.0, 0.0, 0.9)
	for dx in [-OUTLINE_OFF, OUTLINE_OFF]:
		for dy in [-OUTLINE_OFF, OUTLINE_OFF]:
			draw_string(ThemeDB.fallback_font, screen_pos + Vector2(dx, dy),
				_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, outline)

	# Texte
	draw_string(ThemeDB.fallback_font, screen_pos,
		_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, _color)

# ================================
# API PUBLIQUE — appelée depuis Navires.gd
# ================================

# Appelée quand sig_show_fishing est émis
func on_show_fishing(navire: Navires) -> void:
	if _navire == navire and visible:
		close()
		return
	_navire = navire
	_text   = "🎣 Pêche..."
	_color  = Color(0.25, 0.85, 0.95)
	_timer  = 0.0
	show()
	queue_redraw()

# Appelée quand la pêche se termine
func finished_fishing(navire: Navires, gain: int) -> void:
	_navire = navire
	_text   = "+%d 🐟" % gain
	_color  = Color(0.30, 0.95, 0.50)
	_timer  = _duration
	show()
	queue_redraw()

func close() -> void:
	_navire = null
	_timer  = 0.0
	hide()
	queue_redraw()
