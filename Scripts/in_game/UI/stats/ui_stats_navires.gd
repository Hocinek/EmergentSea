class_name UI_stats_navire
extends Node

var navire : Navires
var ui_layer: CanvasLayer
var stats_visible := false

# =========================
# UI STATS - DEUX PANNEAUX
# =========================
var stats_panel_ally: PanelContainer
var cadre_ally: TextureRect
var label_list_ally: Dictionary

var stats_panel_enemy: PanelContainer
var cadre_enemy: TextureRect
var label_list_enemy: Dictionary

const stats_duration: float = 2.5
var stats_timer := 0.0

# Textures Player
const texture_bg_player_path: String = "res://textures/BoisFond.png"
const texture_cadre_bois_path: String = "res://textures/CadreBois.png"

# Textures Enemy
const texture_bg_enemy_path: String = "res://textures/BoisNoirFond.png"
const texture_cadre_bois_noir_path: String = "res://textures/CadreBoisNoir.png"

# Couleurs
const color_txt_enemy: Color = Color(1, 0.5, 0.5)
const color_txt_player: Color = Color(0.5, 0.8, 1)

# CanvasLayer dédié au cadre, au-dessus de tout
var cadre_layer: CanvasLayer


func _init(ship: Navires) -> void:
	self.navire = ship
	navire.add_child(self)
	navire.sig_show_stats.connect(handler)
	build_ui()


func _process(delta):
	if isVisible():
		if stats_timer != INF:
			stats_timer -= delta
			if stats_timer <= 0:
				hide_all_stats()
		update()


func handler():
	if isVisible():
		hide_all_stats()
	else:
		stats_timer = stats_duration
		show_ally()


func handler_ally_persistent():
	if isVisible():
		hide_all_stats()
		DEBUG.log("Navire [%d] — Stats CACHÉES" % navire.id)
	else:
		stats_timer = stats_duration
		show_ally_persistent()
		DEBUG.log("Navire [%d] — Stats AFFICHÉES (persistant)" % navire.id)


func isVisible() -> bool:
	return stats_visible


# =========================
# CRAFTING
# =========================
func build_ui():
	await get_tree().process_frame
	ui_layer = get_tree().get_first_node_in_group("ui_layer")
	if not ui_layer:
		DEBUG.log("ui_layer est null, impossible de créer l'UI des stats!", DEBUG.ERROR)
		return
	_create_cadre_layer()
	_create_ally_stats_panel()
	_create_enemy_stats_panel()


func _create_cadre_layer():
	"""Crée un CanvasLayer au-dessus du ui_layer pour le cadre bois"""
	cadre_layer = CanvasLayer.new()
	cadre_layer.layer = ui_layer.layer + 1
	get_tree().root.add_child(cadre_layer)


func _create_ally_stats_panel():
	"""Crée le panneau de stats pour les navires alliés (à droite)"""
	stats_panel_ally = build_base()
	attach_panel_to_right(stats_panel_ally)
	attach_panel_to_top(stats_panel_ally)
	var style := style_box_texture(texture_bg_player_path)
	stats_panel_ally.add_theme_stylebox_override("panel", style)
	var vbox := build_vbox()
	create_vbox_title(vbox, color_txt_player)
	label_list_ally = add_stats_to_vbox(vbox)
	stats_panel_ally.add_child(vbox)
	ui_layer.add_child(stats_panel_ally)

	# Cadre bois dans son propre CanvasLayer, par-dessus tout
	cadre_ally = TextureRect.new()
	var texture = load(texture_cadre_bois_path)
	if not texture:
		DEBUG.log("Texture cadre introuvable : %s" % texture_cadre_bois_path, DEBUG.ERROR)
	else:
		cadre_ally.texture = texture
	cadre_ally.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	cadre_ally.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cadre_ally.custom_minimum_size = Vector2(256*1.55, 144*1.55)
	cadre_ally.size = Vector2(128, 72)
	cadre_ally.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre_ally.visible = false
	cadre_ally.anchor_left   = 1.0
	cadre_ally.anchor_right  = 1.0
	cadre_ally.anchor_top    = 0.0
	cadre_ally.anchor_bottom = 0.0
	cadre_ally.offset_left   = -300
	cadre_ally.offset_right  = -120
	cadre_ally.offset_top    = -6
	cadre_ally.offset_bottom = 110
	cadre_layer.add_child(cadre_ally)


func _create_enemy_stats_panel():
	"""Crée le panneau de stats pour les navires ennemis (sous le panneau allié, à droite)"""
	stats_panel_enemy = build_base()
	attach_panel_to_right(stats_panel_enemy)
	attach_panel_to_below_ally(stats_panel_enemy)
	var style := style_box_texture(texture_bg_enemy_path)
	stats_panel_enemy.add_theme_stylebox_override("panel", style)
	var vbox = build_vbox()
	create_vbox_title(vbox, color_txt_enemy)
	label_list_enemy = add_stats_to_vbox(vbox)
	stats_panel_enemy.add_child(vbox)
	ui_layer.add_child(stats_panel_enemy)

	# Cadre bois noir dans son propre CanvasLayer, par-dessus tout
	cadre_enemy = TextureRect.new()
	var texture = load(texture_cadre_bois_noir_path)
	if not texture:
		DEBUG.log("Texture cadre introuvable : %s" % texture_cadre_bois_noir_path, DEBUG.ERROR)
	else:
		cadre_enemy.texture = texture
	cadre_enemy.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	cadre_enemy.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cadre_enemy.custom_minimum_size = Vector2(256*1.55, 144*1.55)
	cadre_enemy.size = Vector2(128, 72)
	cadre_enemy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre_enemy.visible = false
	cadre_enemy.anchor_left   = 1.0
	cadre_enemy.anchor_right  = 1.0
	cadre_enemy.anchor_top    = 0.0
	cadre_enemy.anchor_bottom = 0.0
	cadre_enemy.offset_left   = -300
	cadre_enemy.offset_right  = -120
	cadre_enemy.offset_top    = 220
	cadre_enemy.offset_bottom = 266
	cadre_layer.add_child(cadre_enemy)


# =========================
# BUILD PANEL TOOLS
# =========================
func build_base() -> PanelContainer:
	var panel = PanelContainer.new()
	panel.visible = false
	return panel


func attach_panel_to_left(panel: PanelContainer):
	panel.anchor_left = 0
	panel.anchor_right = 0
	panel.offset_left = 0
	panel.offset_right = 180


func attach_panel_to_right(panel: PanelContainer):
	panel.anchor_left = 1
	panel.anchor_right = 1
	panel.offset_left = -240
	panel.offset_right = -40


func attach_panel_to_top(panel: PanelContainer):
	panel.anchor_top = 0
	panel.anchor_bottom = 0
	panel.offset_top = 40
	panel.offset_bottom = 130


func attach_panel_to_below_ally(panel: PanelContainer):
	panel.anchor_top = 0
	panel.anchor_bottom = 0
	panel.offset_top = 266
	panel.offset_bottom = 300


func style_box(color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style


func style_box_texture(texture_path: String) -> StyleBoxTexture:
	var style = StyleBoxTexture.new()
	var texture = load(texture_path)
	if texture:
		style.texture = texture
	else:
		DEBUG.log("Texture introuvable : %s" % texture_path, DEBUG.ERROR)
	return style


func build_vbox() -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return vbox


func add_stats_to_vbox(vbox: VBoxContainer) -> Dictionary:
	var labels_names = ["vie", "energie", "nourriture", "equipage"]
	var labels: Dictionary = create_labels(labels_names)
	for label: Label in labels.values():
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(label)
	return labels


func create_labels(names: Array) -> Dictionary:
	var labels := {}
	for element in names:
		var label := Label.new()
		labels[element] = label
	return labels


func create_vbox_title(vbox: VBoxContainer, color: Color):
	var title_label := Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var owner_name = navire.player_owner.player_name if navire.player_owner else "???"
	var text = ""
	if color == color_txt_enemy:
		text += "☠️ "
	elif color == color_txt_player:
		text += "🚢 "
	else:
		text += "❓ "
	text += owner_name
	title_label.text = text
	title_label.add_theme_color_override("font_color", color)
	vbox.add_child(title_label)


# =========================
# SHOW / HIDE
# =========================
func show_enemy():
	update_stats(label_list_enemy)
	if stats_panel_enemy:
		stats_panel_enemy.visible = true
		if cadre_enemy:
			cadre_enemy.visible = true
		stats_visible = true
		stats_timer = stats_duration


func show_ally_persistent() -> void:
	update_stats(label_list_ally)
	if stats_panel_ally:
		stats_panel_ally.visible = true
		if cadre_ally:
			cadre_ally.visible = true
		stats_visible = true
		stats_timer = INF


func show_ally():
	update_stats(label_list_ally)
	if stats_panel_ally:
		stats_panel_ally.visible = true
		if cadre_ally:
			cadre_ally.visible = true
		stats_visible = true


func hide_enemy():
	if stats_panel_enemy:
		stats_panel_enemy.visible = false
	if cadre_enemy:
		cadre_enemy.visible = false
	if not (stats_panel_ally and stats_panel_ally.visible):
		stats_visible = false


func hide_ally():
	stats_panel_ally.visible = false
	if cadre_ally:
		cadre_ally.visible = false
	stats_visible = false


func show_stats():
	stats_timer = stats_duration
	var is_ally = (navire.player_owner and navire.player_owner.is_human)
	if is_ally:
		if stats_panel_ally:
			show_ally()
			update_stats(label_list_ally)
	else:
		if stats_panel_enemy:
			show_enemy()
			update_stats(label_list_enemy)


func hide_all_stats():
	stats_visible = false
	if stats_panel_ally:
		hide_ally()
	if stats_panel_enemy:
		hide_enemy()


# =========================
# UPDATES
# =========================
func update():
	update_stats(label_list_ally)
	update_stats(label_list_enemy)


func update_stats(label_list: Dictionary):
	if label_list:
		if label_list.has("vie"):
			label_list["vie"].text = "❤️ %d / %d" % [navire.vie, navire.maxvie]
		if label_list.has("energie"):
			label_list["energie"].text = "⚡ %d / %d" % [navire.energie, navire.maxenergie]
		if label_list.has("equipage"):
			label_list["equipage"].text = "👥 %d" % navire.nrbequipage
		if label_list.has("nourriture"):
			label_list["nourriture"].text = "🐟 %d" % navire.nourriture
