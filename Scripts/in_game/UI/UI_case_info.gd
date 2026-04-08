class_name UI_case_info
extends Node


var ui_layer: CanvasLayer
var panel: Control
var bg_texture: TextureRect
var label: Label
var timer: float = 0.0
const DURATION: float = 3.5

# Position monde de la case inspectée — mise à jour à chaque _process
var _world_pos: Vector2 = Vector2.ZERO

const COLOR_TXT_VISIBLE: Color = Color(1.0, 1.0, 1.0, 1.0)
const COLOR_TXT_EXPLORED:Color = Color(0.65, 0.65, 0.65)

const TILE_INFO: Dictionary = {
	"water":     { "label": "🌊 Eau",          "navigable": true  },
	"deepwater": { "label": "🌊 Eau profonde",  "navigable": true  },
	"port":      { "label": "⚓ Port",           "navigable": false  },
	"fish":      { "label": "🐟 Zone de pêche", "navigable": true  },
	"sand":      { "label": "🏖️ Sable",         "navigable": false },
	"earth":     { "label": "🌿 Terre",          "navigable": false },
	"forest":    { "label": "🌲 Forêt",          "navigable": false },
	"mountain":  { "label": "⛰️ Montagne",       "navigable": false },
}

func _init() -> void:
	pass

func setup() -> void:
	await get_tree().process_frame
	ui_layer = get_tree().get_first_node_in_group("ui_layer")
	if not ui_layer:
		DEBUG.log("[UI_case_info] ui_layer introuvable !", DEBUG.ERROR)
		return
	ui_layer.follow_viewport_enabled = false
	_build_ui()

func _build_ui() -> void:
	# Charger la texture en premier pour connaître sa taille native
	var tex: Texture2D = load("res://textures/CarteInspection.png")
	
	if not tex:
		DEBUG.log("[UI_case_info] CarteInspection.png introuvable dans textures/ !", DEBUG.ERROR)

	# TextureRect affiché à sa taille native — c'est lui le "panel"
	bg_texture = TextureRect.new()
	bg_texture.texture = tex
	bg_texture.stretch_mode = TextureRect.STRETCH_KEEP  # taille native, pas de redim
	bg_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_texture.visible = false

	# Label positionné en absolu par-dessus, aux mêmes dimensions que la texture
	label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", COLOR_TXT_VISIBLE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 18)
	# Le label recouvre exactement la texture
	if tex:
		label.size = tex.get_size()
	label.position = Vector2.ZERO

	bg_texture.add_child(label)
	ui_layer.add_child(bg_texture)

	# On pointe panel sur bg_texture pour que le reste du code fonctionne sans changement
	panel = bg_texture

func _process(delta: float) -> void:
	if timer <= 0.0:
		return
	timer -= delta
	if timer <= 0.0:
		panel.visible = false
		return
	# Recalculer la position écran à chaque frame depuis la position monde
	_update_panel_position()

func _update_panel_position() -> void:
	if not panel:
		return
	var viewport := get_viewport()
	if not viewport:
		return
	var spos: Vector2 = viewport.get_canvas_transform() * _world_pos
	var panel_size := panel.size if panel.size.x > 0 else Vector2(160, 80)
	panel.position = spos - Vector2(panel_size.x * 0.5, panel_size.y + 20)

## Affiche si la case est naviguable et son type, si c'est une case poisson, affiche aussi le nombre de poissons
func show_tile_info(tile_type: String, case_pos: Vector2i, is_visible: bool, fish_count: int = -1) -> void:
	if not panel or not label:
		return

	var info: Dictionary = TILE_INFO.get(tile_type, {
		"label": "❓ " + tile_type,
		"navigable": false
	})

	var lines: Array[String] = []
	lines.append(info["label"])
	if info["navigable"]:
		lines.append("⚓ Navigable")
	else:
		lines.append("✗ Non navigable")
	if fish_count >= 0:
		lines.append("🐟 %d poissons" % fish_count)
	if not is_visible:
		lines.append("(dernière observation)")

	label.text = "\n".join(lines)

	# Teinte du texte selon visibilité (la texture reste la même)
	if is_visible:
		label.add_theme_color_override("font_color", COLOR_TXT_VISIBLE)
	else:
		label.add_theme_color_override("font_color", COLOR_TXT_EXPLORED)

	_world_pos = Map_utils.case_vers_monde(case_pos)
	panel.visible = true
	timer = DURATION
	_update_panel_position()

func hide_info() -> void:
	if panel:
		panel.visible = false
	timer = 0.0
