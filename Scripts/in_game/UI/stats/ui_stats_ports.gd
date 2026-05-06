class_name UI_stats_port
extends Node

var _port: Ports
var ui_layer: CanvasLayer
var stats_visible := false
var _ui_ready := false

# =========================
# UI STATS - TROIS PANNEAUX
# =========================
var stats_panel_ally: PanelContainer
var cadre_ally: TextureRect
var label_list_ally: Dictionary
var title_label_ally: Label

var stats_panel_enemy: PanelContainer
var cadre_enemy: TextureRect
var label_list_enemy: Dictionary
var title_label_enemy: Label

var stats_panel_neutral: PanelContainer
var cadre_neutral: TextureRect
var label_list_neutral: Dictionary
var title_label_neutral: Label

const stats_duration: float = 2.5
var stats_timer := 0.0

# true quand affiché via inspection de case (haut gauche), false via attaque (droite)
var _inspect_mode := false

# Textures (mêmes assets que les navires)
const texture_bg_player_path: String       = "res://textures/BoisFond.png"
const texture_cadre_bois_path: String      = "res://textures/CadreBois.png"
const texture_bg_enemy_path: String        = "res://textures/BoisNoirFond.png"
const texture_cadre_bois_noir_path: String = "res://textures/CadreBoisNoir.png"
const texture_bg_neutral_path: String      = "res://textures/BoisFond.png"
const texture_cadre_neutral_path: String   = "res://textures/CadreBois.png"

# Couleurs texte
const color_txt_player:  Color = Color(0.5, 0.8, 1)
const color_txt_enemy:   Color = Color(1, 0.5, 0.5)
const color_txt_neutral: Color = Color(0.85, 0.75, 0.5)

# Teinte grisée pour les assets du panneau neutre
const modulate_neutral: Color = Color(0.6, 0.6, 0.6, 1.0)

# CanvasLayer dédié aux cadres, au-dessus de tout
var cadre_layer: CanvasLayer

# Noms aléatoires pour les ports sans nom défini
const PORT_PREFIXES: Array = ["Port", "Havre", "Anse"]
const PORT_SUFFIXES: Array = [
	"de la Baie", "du Littoral", "des Brumes", "du Nord", "du Sud",
	"des Tempêtes", "des Marées", "de l'Horizon", "du Ponant", "du Levant",
	"des Corsaires", "de la Falaise", "des Récifs", "du Vent", "de l'Aurore"
]
var _nom_affiche: String = ""


func _init(port: Ports) -> void:
	self._port = port
	port.add_child(self)
	port.sig_show_port.connect(handler)
	_generate_nom()
	build_ui()


func _generate_nom():
	"""Génère un nom aléatoire si le port n'en a pas de défini"""
	if self._port.Nom_port != "" and self._port.Nom_port != "Nom du Port":
		_nom_affiche = self._port.Nom_port
	else:
		var prefix = PORT_PREFIXES[randi() % PORT_PREFIXES.size()]
		var suffix = PORT_SUFFIXES[randi() % PORT_SUFFIXES.size()]
		_nom_affiche = "%s %s" % [prefix, suffix]


func _process(delta):
	if isVisible():
		if stats_timer != INF:
			stats_timer -= delta
			if stats_timer <= 0:
				hide_all_stats()
		update()


func handler():
	if not _ui_ready:
		return
	if isVisible():
		hide_all_stats()
	else:
		stats_timer = stats_duration
		show_stats()


func isVisible() -> bool:
	return stats_visible


#region crafting
func build_ui():
	await get_tree().process_frame
	ui_layer = get_tree().get_first_node_in_group("ui_layer")
	if not ui_layer:
		DEBUG.log("ui_layer est null, impossible de créer l'UI des stats!", DEBUG.ERROR)
		return
	_create_cadre_layer()
	_create_ally_stats_panel()
	_create_enemy_stats_panel()
	_create_neutral_stats_panel()
	_ui_ready = true


func _create_cadre_layer():
	cadre_layer = CanvasLayer.new()
	cadre_layer.layer = ui_layer.layer + 1
	get_tree().root.add_child(cadre_layer)


func _create_ally_stats_panel():
	"""Panneau allié — droite, fond BoisFond, cadre CadreBois"""
	stats_panel_ally = build_base()
	attach_panel_to_right(stats_panel_ally)
	attach_panel_to_top(stats_panel_ally)
	stats_panel_ally.add_theme_stylebox_override("panel", style_box_texture(texture_bg_player_path))
	var vbox := build_vbox()
	title_label_ally = create_vbox_title(vbox, color_txt_player)
	label_list_ally = add_stats_to_vbox(vbox)
	stats_panel_ally.add_child(vbox)
	ui_layer.add_child(stats_panel_ally)

	cadre_ally = _build_cadre(texture_cadre_bois_path)
	cadre_ally.offset_left   = -300
	cadre_ally.offset_right  = -120
	cadre_ally.offset_top    = -6
	cadre_ally.offset_bottom = 110
	cadre_layer.add_child(cadre_ally)


func _create_enemy_stats_panel():
	"""Panneau ennemi — droite sous l'allié, fond BoisNoirFond, cadre CadreBoisNoir"""
	stats_panel_enemy = build_base()
	attach_panel_to_right(stats_panel_enemy)
	attach_panel_to_below_ally(stats_panel_enemy)
	stats_panel_enemy.add_theme_stylebox_override("panel", style_box_texture(texture_bg_enemy_path))
	var vbox := build_vbox()
	title_label_enemy = create_vbox_title(vbox, color_txt_enemy)
	label_list_enemy = add_stats_to_vbox(vbox)
	stats_panel_enemy.add_child(vbox)
	ui_layer.add_child(stats_panel_enemy)

	cadre_enemy = _build_cadre(texture_cadre_bois_noir_path)
	cadre_enemy.offset_left   = -300
	cadre_enemy.offset_right  = -120
	cadre_enemy.offset_top    = 230
	cadre_enemy.offset_bottom = 336
	cadre_layer.add_child(cadre_enemy)


func _create_neutral_stats_panel():
	"""Panneau neutre — gauche, assets bois teinté gris"""
	stats_panel_neutral = build_base()
	attach_panel_to_left(stats_panel_neutral)
	attach_panel_to_top(stats_panel_neutral)
	stats_panel_neutral.add_theme_stylebox_override("panel", style_box_texture(texture_bg_neutral_path))
	stats_panel_neutral.modulate = modulate_neutral
	var vbox := build_vbox()
	title_label_neutral = create_vbox_title(vbox, color_txt_neutral)
	label_list_neutral = add_stats_to_vbox(vbox)
	stats_panel_neutral.add_child(vbox)
	ui_layer.add_child(stats_panel_neutral)

	cadre_neutral = _build_cadre(texture_cadre_neutral_path)
	cadre_neutral.modulate      = modulate_neutral
	cadre_neutral.anchor_left   = 0.0
	cadre_neutral.anchor_right  = 0.0
	cadre_neutral.offset_left   = -20
	cadre_neutral.offset_right  = 160
	cadre_neutral.offset_top    = -6
	cadre_neutral.offset_bottom = 110
	cadre_layer.add_child(cadre_neutral)


func _build_cadre(texture_path: String) -> TextureRect:
	"""Construit un TextureRect de cadre avec les réglages communs (ancré à droite par défaut)"""
	var cadre := TextureRect.new()
	var texture = load(texture_path)
	if not texture:
		DEBUG.log("Texture cadre introuvable : %s" % texture_path, DEBUG.ERROR)
	else:
		cadre.texture = texture
	cadre.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT
	cadre.expand_mode         = TextureRect.EXPAND_IGNORE_SIZE
	cadre.custom_minimum_size = Vector2(256 * 1.55, 144 * 1.55)
	cadre.size                = Vector2(128, 72)
	cadre.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	cadre.visible             = false
	cadre.anchor_left         = 1.0
	cadre.anchor_right        = 1.0
	cadre.anchor_top          = 0.0
	cadre.anchor_bottom       = 0.0
	return cadre
#endregion crafting


#region build panel tools
func build_base() -> PanelContainer:
	var panel = PanelContainer.new()
	panel.visible = false
	return panel


func attach_panel_to_left(panel: PanelContainer):
	panel.anchor_left  = 0
	panel.anchor_right = 0
	panel.offset_left  = 20
	panel.offset_right = 220


func attach_panel_to_right(panel: PanelContainer):
	panel.anchor_left  = 1
	panel.anchor_right = 1
	panel.offset_left  = -240
	panel.offset_right = -40


func attach_panel_to_top(panel: PanelContainer):
	panel.anchor_top    = 0
	panel.anchor_bottom = 0
	panel.offset_top    = 34
	panel.offset_bottom = 116


func attach_panel_to_below_ally(panel: PanelContainer):
	panel.anchor_top    = 0
	panel.anchor_bottom = 0
	panel.offset_top    = 280
	panel.offset_bottom = 362


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
	vbox.alignment             = BoxContainer.ALIGNMENT_CENTER
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	return vbox


func add_stats_to_vbox(vbox: VBoxContainer) -> Dictionary:
	var labels_names = ["nom_port", "hp", "attaque", "padding"]
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


func create_vbox_title(vbox: VBoxContainer, color: Color) -> Label:
	var title_label := Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", color)
	vbox.add_child(title_label)
	return title_label
#endregion build panel tools


#region show/hide
func show_ally():
	update_stats(label_list_ally)
	if stats_panel_ally:
		stats_panel_ally.visible = true
		if cadre_ally:
			cadre_ally.visible = true
		stats_visible = true
		stats_timer = stats_duration


func show_enemy():
	update_stats(label_list_enemy)
	if stats_panel_enemy:
		stats_panel_enemy.visible = true
		if cadre_enemy:
			cadre_enemy.visible = true
		stats_visible = true
		stats_timer = stats_duration


func show_neutral():
	update_stats(label_list_neutral)
	if stats_panel_neutral:
		stats_panel_neutral.visible = true
		if cadre_neutral:
			cadre_neutral.visible = true
		stats_visible = true
		stats_timer = stats_duration


func hide_ally():
	if stats_panel_ally:
		stats_panel_ally.visible = false
	if cadre_ally:
		cadre_ally.visible = false
	stats_visible = false


func hide_enemy():
	if stats_panel_enemy:
		stats_panel_enemy.visible = false
	if cadre_enemy:
		cadre_enemy.visible = false
	if not (stats_panel_ally and stats_panel_ally.visible):
		stats_visible = false


func hide_neutral():
	if stats_panel_neutral:
		stats_panel_neutral.visible = false
	if cadre_neutral:
		cadre_neutral.visible = false
	stats_visible = false


func show_stats():
	stats_timer = stats_duration
	if self._port.player_owner == null:
		if self._port.is_under_attack:
			show_enemy()
		else:
			show_neutral()
	elif self._port.player_owner.is_human:
		show_ally()
	else:
		show_enemy()


func hide_all_stats():
	stats_visible = false
	# Si on quitte le mode inspection, remettre les panels à droite
	if _inspect_mode:
		_inspect_mode = false
		_reposition_panels_for_attack()
	hide_ally()
	hide_enemy()
	hide_neutral()


## Appelé depuis UI_case_info lors de l'inspection d'une case port
## Affiche en haut à gauche selon la faction du port
func show_stats_inspect():
	_inspect_mode = true
	_reposition_panels_for_inspect()
	stats_timer = stats_duration
	if self._port.player_owner == null:
		show_neutral()
	elif self._port.player_owner.is_human:
		show_ally()
	else:
		show_enemy()


## Repositionne tous les panneaux en haut à gauche pour le mode inspection
func _reposition_panels_for_inspect():
	_set_panel_top_left(stats_panel_ally)
	_set_panel_top_left(stats_panel_enemy)
	_set_panel_top_left(stats_panel_neutral)
	_set_cadre_top_left(cadre_ally)
	_set_cadre_top_left(cadre_enemy)
	_set_cadre_top_left(cadre_neutral)


## Repositionne tous les panneaux à droite (mode attaque — positions d'origine)
func _reposition_panels_for_attack():
	attach_panel_to_right(stats_panel_ally)
	attach_panel_to_top(stats_panel_ally)
	attach_panel_to_right(stats_panel_enemy)
	attach_panel_to_below_ally(stats_panel_enemy)
	attach_panel_to_left(stats_panel_neutral)
	attach_panel_to_top(stats_panel_neutral)
	cadre_ally.anchor_left  = 1.0; cadre_ally.anchor_right  = 1.0
	cadre_ally.offset_left  = -300; cadre_ally.offset_right  = -120
	cadre_ally.offset_top   = -6;   cadre_ally.offset_bottom = 110
	cadre_enemy.anchor_left = 1.0; cadre_enemy.anchor_right = 1.0
	cadre_enemy.offset_left = -300; cadre_enemy.offset_right = -120
	cadre_enemy.offset_top  = 220;  cadre_enemy.offset_bottom = 336
	cadre_neutral.anchor_left = 0.0; cadre_neutral.anchor_right = 0.0
	cadre_neutral.offset_left = -20; cadre_neutral.offset_right = 160
	cadre_neutral.offset_top  = -6;  cadre_neutral.offset_bottom = 110


func _set_panel_top_left(panel: PanelContainer):
	if not panel:
		return
	panel.anchor_left   = 0; panel.anchor_right  = 0
	panel.anchor_top    = 0; panel.anchor_bottom = 0
	panel.offset_left   = 30; panel.offset_right = 260
	panel.offset_top    = 44; panel.offset_bottom = 116


func _set_cadre_top_left(cadre: TextureRect):
	if not cadre:
		return
	cadre.anchor_left  = 0.0; cadre.anchor_right  = 0.0
	cadre.offset_left  = -20; cadre.offset_right  = 160
	cadre.offset_top   = -6;  cadre.offset_bottom = 110
#endregion show/hide


#region updates
func update():
	update_stats(label_list_ally)
	update_stats(label_list_enemy)
	update_stats(label_list_neutral)


func update_stats(label_list: Dictionary):
	if not label_list:
		return
	var owner := self._port.player_owner
	# Titre dynamique selon le panneau
	if label_list == label_list_neutral and title_label_neutral:
		title_label_neutral.text = "⚓ Port Neutre"
	elif label_list == label_list_enemy and title_label_enemy:
		title_label_enemy.text = "☠️ " + (owner.player_name if owner else "Neutre")
	elif label_list == label_list_ally and title_label_ally:
		title_label_ally.text = "🏰 " + (owner.player_name if owner else "Neutre")
	# Stats
	if label_list.has("nom_port"):
		label_list["nom_port"].text = "⚓ %s" % _nom_affiche
	if label_list.has("hp"):
		label_list["hp"].text = "❤️ %d / %d" % [self._port.current_hp, self._port.max_hp]
	if label_list.has("attaque"):
		label_list["attaque"].text = "⚔️ %d (portée %d)" % [self._port.attack_damage, self._port.attack_range]
	if label_list.has("padding"):
		label_list["padding"].text = ""  # Ligne vide pour remplir le fond jusqu'en bas
#endregion updates
