class_name UI_stats_navire
extends Node

var navire : Navires
var ui_layer: CanvasLayer

var stats_visible := false

# =========================
# UI STATS - DEUX PANNEAUX
# =========================
# Panneau pour navire allié (à droite)
var stats_panel_ally: PanelContainer
var label_list_ally:Dictionary

# Panneau pour navire ennemi (à gauche)
var stats_panel_enemy: PanelContainer
var label_list_enemy:Dictionary

# timer pour faire disparaître les panels
const stats_duration: float = 2.5
var stats_timer := 0.0

#Couleurs Player
const color_bg_player : Color = Color(0, 0.2, 0.4, 0.9)  # Bleu pour le joueur
const color_txt_player : Color = Color(0.5, 0.8, 1)

#Couleurs Enemy
const color_bg_enemy : Color = Color(0.4, 0, 0, 0.8)  # Rouge pour l'ennemi
const color_txt_enemy : Color = Color(1, 0.5, 0.5)


func _init(ship : Navires) -> void:
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

#region crafting
func build_ui():
	await get_tree().process_frame
	ui_layer = get_tree().get_first_node_in_group("ui_layer")
	if not ui_layer:
		DEBUG.log("ui_layer est null, impossible de créer l'UI des stats!",DEBUG.ERROR)
		return
	# Créer le panneau allié (à droite)
	_create_ally_stats_panel()
	# Créer le panneau ennemi (à gauche)
	_create_enemy_stats_panel()

func _create_ally_stats_panel():
	"""Crée le panneau de stats pour les navires alliés (à droite)"""
	stats_panel_ally=build_base()
	attach_panel_to_right(stats_panel_ally)
	attach_panel_to_top(stats_panel_ally)
	var style := style_box(color_bg_player)
	stats_panel_ally.add_theme_stylebox_override("panel", style)
	var vbox := build_vbox()
	# Titre
	create_vbox_title(vbox,color_txt_player)
	# Labels de stats
	label_list_ally=add_stats_to_vbox(vbox)
	# On ajoute tout ça dans l'arbre des noeuds
	stats_panel_ally.add_child(vbox)
	ui_layer.add_child(stats_panel_ally)

func _create_enemy_stats_panel():
	"""Crée le panneau de stats pour les navires ennemis (à gauche)"""
	stats_panel_enemy=build_base()
	attach_panel_to_left(stats_panel_enemy)
	attach_panel_to_top(stats_panel_enemy)
	var style := style_box(color_bg_enemy)
	stats_panel_enemy.add_theme_stylebox_override("panel", style)
	var vbox = build_vbox()
	# Titre
	create_vbox_title(vbox,color_txt_enemy)
	# Labels de stats
	label_list_enemy=add_stats_to_vbox(vbox)
	# On ajoute tout ça dans l'arbre des noeuds
	stats_panel_enemy.add_child(vbox)
	ui_layer.add_child(stats_panel_enemy)
#endregion crafting

#region build panel tools
func build_base()->PanelContainer:
	var panel = PanelContainer.new()
	panel.visible = false
	return panel

func attach_panel_to_left(panel:PanelContainer):
	panel.anchor_left = 0
	panel.anchor_right = 0
	panel.offset_left = 20
	panel.offset_right = 180

func attach_panel_to_right(panel:PanelContainer):
	panel.anchor_left = 1
	panel.anchor_right = 1
	panel.offset_left = -180
	panel.offset_right = -20

func attach_panel_to_top(panel:PanelContainer):
	panel.anchor_top = 0
	panel.anchor_bottom = 0
	panel.offset_top = 20
	panel.offset_bottom = 110

func style_box(color:Color)->StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	
	return style

func build_vbox()->VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return vbox

func add_stats_to_vbox(vbox:VBoxContainer) -> Dictionary:
	# Labels de stats
	var labels_names = ["vie", "energie", "nourriture", "equipage"]
	var labels : Dictionary = create_labels(labels_names)
	for label:Label in labels.values():
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(label)
	return labels

func create_labels(names: Array) -> Dictionary:
	var labels := {}
	for element in names:
		var label := Label.new()
		labels[element] = label
	return labels

func create_vbox_title(vbox:VBoxContainer,color:Color):
	var title_label := Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var owner_name = navire.player_owner.player_name if navire.player_owner else "???"
	var text = ""
	if(color == color_txt_enemy):
		text += "☠️ "
	elif(color == color_txt_player):
		text += "🚢 "
	else:
		text += "❓ "
	text+= owner_name
	title_label.text = text
	title_label.add_theme_color_override("font_color", color)
	vbox.add_child(title_label)
#endregion build panel tools

#region show/hide
func show_enemy():
	update_stats(label_list_enemy)
	if stats_panel_enemy:
		stats_panel_enemy.visible = true
		stats_visible = true          # permet à _process de décompter le timer
		stats_timer = stats_duration

func show_ally_persistent() -> void:
	"""Affiche les stats alliées SANS timer — restent jusqu'à hide_all_stats()"""
	update_stats(label_list_ally)
	if stats_panel_ally:
		stats_panel_ally.visible = true
		stats_visible = true
		stats_timer = INF  # Désactive le countdown


func show_ally():
	update_stats(label_list_ally)
	if(stats_panel_ally):
		stats_panel_ally.visible=true
		stats_visible=true

func hide_enemy():
	if stats_panel_enemy:
		stats_panel_enemy.visible = false
	# Remettre stats_visible à false seulement si le panel allié est aussi caché
	if not (stats_panel_ally and stats_panel_ally.visible):
		stats_visible = false
		
func hide_ally():
	stats_panel_ally.visible=false
	stats_visible=false

func show_stats():
	"""Affiche les stats du navire dans le bon panneau"""
	stats_timer = stats_duration
	
	# Déterminer si ce navire est allié ou ennemi
	var is_ally = (navire.player_owner and navire.player_owner.is_human)
	
	if is_ally:
		# Afficher dans le panneau allié (droite)
		if stats_panel_ally:
			show_ally()
			update_stats(label_list_ally)
	else:
		# Afficher dans le panneau ennemi (gauche)
		if stats_panel_enemy:
			show_enemy()
			update_stats(label_list_enemy)

func hide_all_stats():
	"""Masque tous les panneaux de stats de ce navire"""
	stats_visible = false
	
	if stats_panel_ally:
		hide_ally()
	
	if stats_panel_enemy:
		hide_enemy()
#endregion show/hide

#region updates
func update():
	update_stats(label_list_ally)
	update_stats(label_list_enemy)

func update_stats(label_list:Dictionary):
	"""Met à jour l'affichage des stats"""	
	if label_list:
		if(label_list.has("vie")):
			label_list["vie"].text = "❤️ %d / %d" % [navire.vie, navire.maxvie]
		if(label_list.has("energie")):
			label_list["energie"].text = "⚡ %d / %d" % [navire.energie, navire.maxenergie]
		if(label_list.has("equipage")):
			label_list["equipage"].text = "👥 %d" % navire.nrbequipage
		if(label_list.has("nourriture")):
			label_list["nourriture"].text = "🐟 %d" % navire.nourriture
#endregion updates
