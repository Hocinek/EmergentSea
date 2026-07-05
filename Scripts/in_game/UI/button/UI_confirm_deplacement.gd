class_name UI_confirm_deplacement
extends Control

signal confirmed
signal cancelled

const W         := 230.0
const H         := 72.0
const BTN_W     := 84.0
const BTN_H     := 30.0
const PADDING   := 12.0
const FONT_SIZE := 13

var _screen_pos : Vector2 = Vector2.ZERO
var _label_text : String  = ""
var _hover_btn  : int     = -1   # 0 = Confirmer, 1 = Annuler, -1 = rien

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_input(true)
	hide()

# -----------------------------------------
# API
# -----------------------------------------
func show_for(nb_cases: int, energy_cost: int, screen_pos: Vector2) -> void:
	_label_text = "Déplacement : %d case(s) - %d ⚡" % [nb_cases, energy_cost]
	# Clamp dans le viewport
	var vp := get_viewport_rect().size
	_screen_pos = Vector2(
		clamp(screen_pos.x - W * 0.5, 8.0, vp.x - W - 8.0),
		clamp(screen_pos.y - H - 20.0, 8.0, vp.y - H - 8.0)
	)
	_hover_btn = -1
	show()
	queue_redraw()

func hide_ui() -> void:
	_hover_btn = -1
	hide()
	queue_redraw()

# -----------------------------------------
# DESSIN
# -----------------------------------------
func _draw() -> void:
	if not visible:
		return

	var box := Rect2(_screen_pos, Vector2(W, H))

	# Fond principal
	draw_rect(box, Color(0.05, 0.10, 0.16, 0.96))
	# Contour
	draw_rect(box, Color(0.42, 0.71, 0.85, 0.7), false, 1.5)

	# Label
	draw_string(
		ThemeDB.fallback_font,
		_screen_pos + Vector2(PADDING, PADDING + FONT_SIZE),
		_label_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1,
		FONT_SIZE,
		Color(0.78, 0.87, 0.93)
	)

# Bouton Confirmer
	var btn_confirm := _btn_rect(0)
	var bg_confirm  := Color(0.10, 0.35, 0.15) if _hover_btn != 0 else Color(0.18, 0.55, 0.25)
	draw_rect(btn_confirm, bg_confirm)
	draw_rect(btn_confirm, Color(0.30, 0.80, 0.47, 0.8), false, 1.5)
	draw_string(ThemeDB.fallback_font,
		Vector2(btn_confirm.position.x, btn_confirm.position.y + BTN_H * 0.5 + FONT_SIZE * 0.35),
		"Confirmer",
		HORIZONTAL_ALIGNMENT_CENTER,
		int(BTN_W),
		FONT_SIZE,
		Color(0.70, 1.0, 0.75))

	# Bouton Annuler
	var btn_cancel := _btn_rect(1)
	var bg_cancel  := Color(0.30, 0.08, 0.08) if _hover_btn != 1 else Color(0.50, 0.12, 0.12)
	draw_rect(btn_cancel, bg_cancel)
	draw_rect(btn_cancel, Color(0.88, 0.31, 0.31, 0.8), false, 1.5)
	draw_string(ThemeDB.fallback_font,
		Vector2(btn_cancel.position.x, btn_cancel.position.y + BTN_H * 0.5 + FONT_SIZE * 0.35),
		"Annuler",
		HORIZONTAL_ALIGNMENT_CENTER,
		int(BTN_W),
		FONT_SIZE,
		Color(1.0, 0.65, 0.65))

# -----------------------------------------
# INPUT
# -----------------------------------------
func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventMouseMotion:
		var new_hover := _get_hover(event.position)
		if new_hover != _hover_btn:
			_hover_btn = new_hover
			queue_redraw()

	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				var idx := _get_hover(event.position)
				if idx == 0:
					hide_ui()
					emit_signal("confirmed")
					get_viewport().set_input_as_handled()
				elif idx == 1:
					hide_ui()
					emit_signal("cancelled")
					get_viewport().set_input_as_handled()
			MOUSE_BUTTON_RIGHT:
				hide_ui()
				emit_signal("cancelled")
				get_viewport().set_input_as_handled()

# -----------------------------------------
# HELPERS
# -----------------------------------------
func _btn_rect(index: int) -> Rect2:
	# index 0 = Confirmer (gauche), 1 = Annuler (droite)
	var gap    := (W - BTN_W * 2 - PADDING * 2) / 1.0
	var btn_y  := _screen_pos.y + H - BTN_H - PADDING * 0.5
	var btn_x  := _screen_pos.x + PADDING + index * (BTN_W + gap)
	return Rect2(Vector2(btn_x, btn_y), Vector2(BTN_W, BTN_H))

func _get_hover(mouse_pos: Vector2) -> int:
	if _btn_rect(0).has_point(mouse_pos):
		return 0
	if _btn_rect(1).has_point(mouse_pos):
		return 1
	return -1
