class_name UI_stats_port
extends Node

var port: Ports
var ui_layer: CanvasLayer

var stats_visible := false

# =========================
# UI STATS - DEUX PANNEAUX
# =========================
# Panneau pour port allié (à droite)
var stats_panel_ally: Panel
var label_list_ally:Dictionary

# Panneau pour port ennemi (à gauche)
var stats_panel_enemy: Panel
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


func _init(port : Ports) -> void:
	self.port = port
	port.add_child(self)
	port.sig_show_port.connect(handler)
	
	build_ui()

func _process(delta):
	if isVisible():
		stats_timer -= delta
		update()
		if stats_timer <= 0:
			hide_all_stats()

func handler():
	if isVisible():
		hide_all_stats()
	else:
		stats_timer = stats_duration
		show_ally()

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
	"""Crée le panneau de stats pour les ports alliés (à droite)"""
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
	"""Crée le panneau de stats pour les ports ennemis (à gauche)"""
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
func build_base()->Panel:
	var panel = Panel.new()
	panel.visible = false
	return panel

func attach_panel_to_left(panel:Panel):
	panel.anchor_left = 0
	panel.anchor_right = 0
	panel.offset_left = 20
	panel.offset_right = 180

func attach_panel_to_right(panel:Panel):
	panel.anchor_left = 1
	panel.anchor_right = 1
	panel.offset_left = -180
	panel.offset_right = -20

func attach_panel_to_top(panel:Panel):
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
	var labels_names = ["Nom du port"]
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
	var owner_name = port.player_owner.player_name if port.player_owner else "???"
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
	stats_panel_enemy.visible=true

func show_ally():
	update_stats(label_list_ally)
	if(stats_panel_ally):
		stats_panel_ally.visible=true
		stats_visible=true

func hide_enemy():
	stats_panel_enemy.visible=false

func hide_ally():
	stats_panel_ally.visible=false
	stats_visible=false

func show_stats():
	"""Affiche les stats du port dans le bon panneau"""
	stats_timer = stats_duration
	
	# Déterminer si ce port est allié ou ennemi
	var is_ally = (port.player_owner and port.player_owner.is_human)
	
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
	"""Masque tous les panneaux de stats de ce port"""
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
		if(label_list.has("Nom du Port")):
			label_list["Nom du Port"].text = "%d" [port.Nom_Port]
#endregion updates
