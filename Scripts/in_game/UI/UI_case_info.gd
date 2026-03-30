class_name UI_case_info
extends Node

# =========================
# UI_case_info
# Affiche une bulle d'info flottante sur une case inspectée.
#
# VISIBLE  → valeur exacte, bleu  "🐟 42 poissons"
# EXPLORED → dernière valeur vue, gris  "🐟 42 poissons (dernière observation)"
# UNEXPLORED → rien (jamais appelé depuis GameManager)
# =========================

var ui_layer: CanvasLayer
var panel: PanelContainer
var label: Label

var timer: float = 0.0
const DURATION: float = 3.5

const COLOR_BG_VISIBLE:  Color = Color(0.0,  0.25, 0.35, 0.92)
const COLOR_TXT_VISIBLE: Color = Color(0.5,  0.9,  1.0)
const COLOR_BG_EXPLORED: Color = Color(0.18, 0.18, 0.18, 0.88)
const COLOR_TXT_EXPLORED:Color = Color(0.65, 0.65, 0.65)

func _init() -> void:
	pass

func setup() -> void:
	await get_tree().process_frame
	ui_layer = get_tree().get_first_node_in_group("ui_layer")
	if not ui_layer:
		DEBUG.log("[UI_case_info] ui_layer introuvable !", DEBUG.ERROR)
		return
	_build_ui()

func _build_ui() -> void:
	panel = PanelContainer.new()
	panel.visible = false
	_apply_style(COLOR_BG_VISIBLE)

	label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", COLOR_TXT_VISIBLE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 18)

	panel.add_child(label)
	ui_layer.add_child(panel)

func _apply_style(bg: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.corner_radius_top_left    = 8
	style.corner_radius_top_right   = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right= 8
	style.content_margin_left   = 12
	style.content_margin_right  = 12
	style.content_margin_top    = 7
	style.content_margin_bottom = 7
	panel.add_theme_stylebox_override("panel", style)

func _process(delta: float) -> void:
	if timer > 0.0:
		timer -= delta
		if timer <= 0.0:
			panel.visible = false

# =========================
# API publique
# =========================

## Affiche le nombre de poissons à la position écran donnée.
## is_visible = true  → case VISIBLE  (valeur exacte, style bleu)
## is_visible = false → case EXPLORED (dernière valeur, style gris)
func show_fish_info(fish_count: int, screen_pos: Vector2, is_visible: bool) -> void:
	if not panel or not label:
		return

	if is_visible:
		label.text = "🐟 %d poissons" % fish_count
		_apply_style(COLOR_BG_VISIBLE)
		label.add_theme_color_override("font_color", COLOR_TXT_VISIBLE)
	else:
		label.text = "🐟 %d poissons\n(dernière observation)" % fish_count
		_apply_style(COLOR_BG_EXPLORED)
		label.add_theme_color_override("font_color", COLOR_TXT_EXPLORED)

	panel.visible = true
	await get_tree().process_frame  # laisser Godot calculer la taille du panel
	panel.position = screen_pos - Vector2(panel.size.x * 0.5, panel.size.y + 20)
	timer = DURATION

func hide_info() -> void:
	if panel:
		panel.visible = false
	timer = 0.0
