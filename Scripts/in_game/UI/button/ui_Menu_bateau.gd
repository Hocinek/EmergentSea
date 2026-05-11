###===================================================================###
##                        HexContextMenu                              ##
# Menu contextuel hexagonal — 6 actions fonctionnelles + retour       #
###===================================================================###
class_name HexContextMenu
extends Control

# ================================
# SIGNAUX
# ================================
signal action_selected(action: String, navire: Navires)

# ================================
# CONSTANTES VISUELLES
# ================================
const ORBIT_RADIUS    := 145.0
const HEX_SIZE        := 48.0
const CENTER_HEX_SIZE := 58.0
const ANIM_DURATION   := 0.25

# ================================
# ACTIONS — 6 boutons, répartis sur 6 angles symétriques
# ================================
const ACTIONS: Array = [
	{ "id": "move",    "label": "Déplacer\n 1 ⚡ /case",     "icon": "\u27A4",  "color": Color(0.30, 0.80, 0.47), "bg": Color(0.07, 0.18, 0.10), "tip": "Puis clic gauche = destination",  "cursor": "CURSOR_CROSS"          },
	{ "id": "attack",  "label": "Attaquer\n  10 ⚡ ",     "icon": "\u2694",  "color": Color(0.88, 0.31, 0.31), "bg": Color(0.18, 0.07, 0.07), "tip": "Puis clic sur un ennemi",         "cursor": "CURSOR_CROSS"          },
	{ "id": "inspect", "label": "Inspecter",    "icon": "\u25CE",  "color": Color(0.63, 0.44, 0.91), "bg": Color(0.14, 0.08, 0.22), "tip": "Puis clic sur une case",          "cursor": "CURSOR_HELP"           },
	{ "id": "stats",   "label": "Statistiques", "icon": "\u2261",  "color": Color(0.31, 0.69, 0.82), "bg": Color(0.07, 0.12, 0.20), "tip": "Affiche / cache les stats",       "cursor": "CURSOR_POINTING_HAND"  },
	{ "id": "switch",  "label": "Changer",      "icon": "\u21C4",  "color": Color(0.88, 0.56, 0.25), "bg": Color(0.20, 0.12, 0.05), "tip": "Sélectionne le navire suivant",   "cursor": "CURSOR_POINTING_HAND"  },
	{ "id": "fish",    "label": "Pêcher\n 5 ⚡",       "icon": "",           "color": Color(0.25, 0.75, 0.85), "bg": Color(0.05, 0.18, 0.22), "tip": "Lance une session de pêche", "cursor": "CURSOR_POINTING_HAND"  },
]

# Bouton central retour
const CENTER_ACTION: Dictionary = {
	"id": "close", "label": "Retour", "icon": "\u2715",
	"color": Color(0.80, 0.80, 0.80), "bg": Color(0.10, 0.10, 0.14)
}

# 6 angles répartis uniformément à 60° d'écart
const ANGLES_DEG: Array = [-90.0, -30.0, 30.0, 90.0, 150.0, 210.0]

# ================================
# STATE
# ================================
var _navire: Navires     = null
var _anim_t: float       = 0.0
var _animating: bool     = false
var _hovered_index: int  = -1   # -1 = rien, -2 = centre
var _screen_pos: Vector2 = Vector2.ZERO

# ================================
# INIT
# ================================
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	set_process_input(true)
	hide()

# ================================
# API PUBLIQUE
# ================================
func show_for(navire: Navires, screen_position: Vector2) -> void:
	_navire        = navire
	_anim_t        = 0.0
	_animating     = true
	_hovered_index = -1
	# Clamp pour garder le menu entièrement dans le viewport
	var vp    := get_viewport_rect().size
	var margin := ORBIT_RADIUS + HEX_SIZE + 8.0
	_screen_pos = Vector2(
		clamp(screen_position.x, margin, vp.x - margin),
		clamp(screen_position.y, margin, vp.y - margin)
	)
	show()
	queue_redraw()

func close() -> void:
	_navire        = null
	_hovered_index = -1
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	hide()
	queue_redraw()

func is_open() -> bool:
	return visible and _navire != null

# ================================
# ANIMATION
# ================================
func _process(delta: float) -> void:
	if not visible:
		return
	if _animating:
		_anim_t = min(_anim_t + delta / ANIM_DURATION, 1.0)
		if _anim_t >= 1.0:
			_animating = false
		queue_redraw()

# ================================
# INPUT
# ================================
func _input(event: InputEvent) -> void:
	if not visible or _navire == null:
		return

	if event is InputEventMouseMotion:
		var new_hover: int = _get_hover_at(event.position)
		if new_hover != _hovered_index:
			_hovered_index = new_hover
			# --- Changement de curseur selon l'action survolée ---
			if new_hover >= 0:
				var cursor_name: String = ACTIONS[new_hover]["cursor"]
				match cursor_name:
					"CURSOR_CROSS":
						Input.set_default_cursor_shape(Input.CURSOR_CROSS)
					"CURSOR_HELP":
						Input.set_default_cursor_shape(Input.CURSOR_HELP)
					"CURSOR_POINTING_HAND":
						Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
					_:
						Input.set_default_cursor_shape(Input.CURSOR_ARROW)
			elif new_hover == -2:
				Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
			else:
				Input.set_default_cursor_shape(Input.CURSOR_ARROW)
			queue_redraw()

	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var idx: int = _get_hover_at(event.position)
			if idx >= 0:
				_on_action_clicked(idx)
				get_viewport().set_input_as_handled()
			elif idx == -2:
				# Bouton central = fermer
				close()
				get_viewport().set_input_as_handled()
			else:
				close()
				get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			close()
			get_viewport().set_input_as_handled()

# ================================
# DESSIN PRINCIPAL
# ================================
func _draw() -> void:
	if not visible or _navire == null:
		return
	var scale_t: float = _ease_out_back(_anim_t)
	_draw_connectors(scale_t)
	for i in range(ACTIONS.size()):
		_draw_action_hex(i, scale_t)
	_draw_center_hex(scale_t)
	if _hovered_index >= 0:
		_draw_tooltip(_hovered_index, scale_t)
	elif _hovered_index == -2:
		_draw_tip_box(_screen_pos, "Fermer le menu")

func _draw_connectors(scale_t: float) -> void:
	for i in range(ACTIONS.size()):
		var hex_pos: Vector2 = _get_hex_screen_pos(i, scale_t)
		draw_dashed_line(_screen_pos, hex_pos, Color(0.42, 0.71, 0.85, 0.25 * scale_t), 1.5, 8.0, true)

func _draw_action_hex(index: int, scale_t: float) -> void:
	var action: Dictionary = ACTIONS[index]
	var hex_pos: Vector2   = _get_hex_screen_pos(index, scale_t)
	var is_hover: bool     = (index == _hovered_index)
	var hex_r: float       = HEX_SIZE * scale_t * (1.12 if is_hover else 1.0)

	# --- Fond coloré (lightened au hover) ---
	var bg_color: Color = action["bg"]
	if is_hover:
		bg_color = bg_color.lightened(0.15)
	_draw_hexagon_filled(hex_pos, hex_r, bg_color)

	# --- Contour hexagonal coloré ---
	_draw_hexagon_outline(hex_pos, hex_r, action["color"], 2.5 if is_hover else 2.0)

	# --- Icône + label : bloc remonté vers le haut du hex ---
	var font_size_icon: int  = maxi(int(hex_r * 0.58), 1)
	var font_size_label: int = maxi(int(hex_r * 0.22), 1)
	var gap      := 2.0
	var total_h  := float(font_size_icon) + gap + float(font_size_label)
	var center_y := hex_pos.y - hex_r * 0.10
	var block_top := center_y - total_h * 0.4
	var icon_y   := block_top + font_size_icon * 0.85
	var label_y  := block_top + font_size_icon + gap + font_size_label * 0.85

	if font_size_icon >= 4:
		if action["id"] == "fish":
			var fish_cy := block_top + font_size_icon * 0.5
			_draw_fish_icon(Vector2(hex_pos.x, fish_cy), font_size_icon * 0.52, action["color"])
		else:
			draw_string(
				ThemeDB.fallback_font,
				Vector2(hex_pos.x - hex_r, icon_y),
				action["icon"] as String,
				HORIZONTAL_ALIGNMENT_CENTER,
				int(hex_r * 2),
				font_size_icon,
				Color.WHITE
			)

		if font_size_label >= 5:
			draw_multiline_string(
			ThemeDB.fallback_font,
			Vector2(hex_pos.x - hex_r, label_y),
			action["label"],
			HORIZONTAL_ALIGNMENT_CENTER,
			int(hex_r * 2),   # largeur max
			font_size_label,
			-1,               # nb lignes illimité
			action["color"]
	)

# ================================
# HEXAGONE CENTRAL — Retour
# ================================
func _draw_center_hex(scale_t: float) -> void:
	var hex_r: float   = CENTER_HEX_SIZE * scale_t
	var is_hover: bool = (_hovered_index == -2)

	# Fond
	var bg: Color = CENTER_ACTION["bg"]
	if is_hover:
		bg = bg.lightened(0.18)
	_draw_hexagon_filled(_screen_pos, hex_r, bg)

	# Contour
	var col: Color = CENTER_ACTION["color"]
	if is_hover:
		col = col.lightened(0.2)
	_draw_hexagon_outline(_screen_pos, hex_r, col, 2.5 if is_hover else 2.0)

	# Icône ✕ + label "Retour"
	var font_size_icon: int  = maxi(int(hex_r * 0.52), 1)
	var font_size_label: int = maxi(int(hex_r * 0.20), 1)
	var gap       := 2.0
	var total_h   := float(font_size_icon) + gap + float(font_size_label)
	var center_y  := _screen_pos.y - hex_r * 0.10
	var block_top := center_y - total_h * 0.4
	var icon_y    := block_top + font_size_icon * 0.85
	var label_y   := block_top + font_size_icon + gap + font_size_label * 0.85

	if font_size_icon >= 4:
		draw_string(
			ThemeDB.fallback_font,
			Vector2(_screen_pos.x - hex_r, icon_y),
			CENTER_ACTION["icon"] as String,
			HORIZONTAL_ALIGNMENT_CENTER,
			int(hex_r * 2),
			font_size_icon,
			col
		)
	if font_size_label >= 4:
		draw_string(
			ThemeDB.fallback_font,
			Vector2(_screen_pos.x - hex_r, label_y),
			CENTER_ACTION["label"],
			HORIZONTAL_ALIGNMENT_CENTER,
			int(hex_r * 2),
			font_size_label,
			col
		)

func _draw_tooltip(index: int, scale_t: float) -> void:
	var action: Dictionary = ACTIONS[index]
	var hex_pos: Vector2   = _get_hex_screen_pos(index, scale_t)
	_draw_tip_box(hex_pos, action["tip"])

func _draw_tip_box(anchor: Vector2, tip_text: String) -> void:
	var font_size: int     = 12
	var padding: Vector2   = Vector2(10, 6)
	var text_w: float      = tip_text.length() * font_size * 0.55
	var box_size: Vector2  = Vector2(text_w + padding.x * 2, font_size + padding.y * 2)
	var box_pos: Vector2   = anchor + Vector2(-box_size.x * 0.5, -HEX_SIZE - box_size.y - 6)
	box_pos.x = clamp(box_pos.x, 4.0, get_viewport_rect().size.x - box_size.x - 4.0)
	box_pos.y = clamp(box_pos.y, 4.0, get_viewport_rect().size.y - box_size.y - 4.0)
	draw_rect(Rect2(box_pos, box_size), Color(0.04, 0.10, 0.16, 0.95))
	draw_rect(Rect2(box_pos, box_size), Color(0.42, 0.71, 0.85, 0.5), false, 1.0)
	draw_string(ThemeDB.fallback_font,
		box_pos + padding + Vector2(0, font_size * 0.75),
		tip_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.78, 0.87, 0.93))

# ================================
# HELPERS GÉOMÉTRIQUES
# ================================
func _get_hex_screen_pos(index: int, scale_t: float) -> Vector2:
	var angle_rad: float = deg_to_rad(ANGLES_DEG[index])
	return _screen_pos + Vector2(cos(angle_rad), sin(angle_rad)) * (ORBIT_RADIUS * scale_t)

func _get_hover_at(mouse_pos: Vector2) -> int:
	# Hexagones orbit en priorité
	for i in range(ACTIONS.size()):
		if mouse_pos.distance_to(_get_hex_screen_pos(i, 1.0)) <= HEX_SIZE:
			return i
	# Centre
	if mouse_pos.distance_to(_screen_pos) <= CENTER_HEX_SIZE:
		return -2
	return -1

func _draw_hexagon_filled(center: Vector2, radius: float, color: Color) -> void:
	draw_colored_polygon(_hex_points(center, radius), color)

func _draw_hexagon_outline(center: Vector2, radius: float, color: Color, width: float = 1.5) -> void:
	var pts: PackedVector2Array = _hex_points(center, radius)
	pts.append(pts[0])
	draw_polyline(pts, color, width, true)

func _hex_points(center: Vector2, radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(6):
		var a: float = deg_to_rad(-90.0 + i * 60.0)
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	return pts

func _draw_fish_icon(center: Vector2, size: float, color: Color) -> void:
	# Corps : ellipse aplatie simulée par un polygone 12 points
	var body := PackedVector2Array()
	var bw := size * 1.0   # demi-largeur
	var bh := size * 0.48  # demi-hauteur
	for i in range(12):
		var a := deg_to_rad(i * 30.0)
		body.append(center + Vector2(cos(a) * bw, sin(a) * bh))
	draw_colored_polygon(body, Color(color, 0.9))

	# Queue : double triangle en V à gauche du corps
	var tx := center.x - bw
	var tail := PackedVector2Array([
		Vector2(tx,          center.y),
		Vector2(tx - size * 0.55, center.y - size * 0.42),
		Vector2(tx - size * 0.22, center.y),
		Vector2(tx - size * 0.55, center.y + size * 0.42),
	])
	draw_colored_polygon(tail, Color(color, 0.85))

	# Nageoire dorsale : petit triangle sur le dessus
	var fin := PackedVector2Array([
		Vector2(center.x + size * 0.05, center.y - bh),
		Vector2(center.x + size * 0.35, center.y - bh - size * 0.30),
		Vector2(center.x + size * 0.55, center.y - bh),
	])
	draw_colored_polygon(fin, Color(color, 0.75))

	# Contour corps
	var body_closed := PackedVector2Array(body)
	body_closed.append(body_closed[0])
	draw_polyline(body_closed, Color(Color.WHITE, 0.4), 1.0, true)

	# Œil : petit cercle blanc + pupille sombre
	var eye_pos := center + Vector2(bw * 0.45, -bh * 0.15)
	var eye_r   := size * 0.13
	draw_circle(eye_pos, eye_r,       Color(Color.WHITE, 0.95))
	draw_circle(eye_pos, eye_r * 0.5, Color(0.05, 0.10, 0.15, 0.9))

func _ease_out_back(t: float) -> float:
	var c1: float = 1.70158
	var c3: float = c1 + 1.0
	return 1.0 + c3 * pow(t - 1.0, 3) + c1 * pow(t - 1.0, 2)

# ================================
# CALLBACK ACTION
# ================================
func _on_action_clicked(index: int) -> void:
	var action_id: String = ACTIONS[index]["id"]
	DEBUG.log("[HexMenu] Action : %s sur navire %d" % [action_id, _navire.id if _navire else -1])
	var navire_ref: Navires = _navire  # Garder la référence avant close()
	# switch et fish : fermer D'ABORD puis émettre → action instantanée sans voir le menu
	if action_id == "switch" or action_id == "fish":
		close()
		emit_signal("action_selected", action_id, navire_ref)
	else:
		emit_signal("action_selected", action_id, navire_ref)
		close()
