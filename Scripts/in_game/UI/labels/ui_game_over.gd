class_name UI_game_over
extends Node

var turn_manager : TurnManager
var ui_layer: CanvasLayer

var game_over_visible := false

var Text_winner

#Couleurs game_over
const color_game_over : Color = Color(0, 0.2, 0.4, 0.9)
const color_game_over_text : Color = Color(0.5, 0.8, 1)

# =========================
# UI PANNEAU FIN DE PARTIE
# =========================
# Panneau pour la fin de partie au centre
var game_over_panel: PanelContainer
var label_winner : Dictionary

func init():
	turn_manager.game_over.connect(Text_winner)
	build_ui()

func show_game_over():
	if(game_over_panel):
		game_over_panel.visible=true
		game_over_visible=true


func build_ui():
	await get_tree().process_frame
	ui_layer = get_tree().get_first_node_in_group("ui_layer")
	if not ui_layer:
		DEBUG.log("ui_layer est null, impossible de créer l'UI des stats!",DEBUG.ERROR)
		return


func _create_end_game_panel():
	"""Crée le panneau de stats pour les navires alliés (à droite)"""
	game_over_panel=build_base()
	attach_panel_to_center(game_over_panel)
	var style := style_box(color_game_over)
	game_over_panel.add_theme_stylebox_override("panel", style)
	var vbox := build_vbox()
	# Titre
	create_vbox_title(vbox,color_game_over_text)
	# On ajoute tout ça dans l'arbre des noeuds
	label_winner = add_winner_to_vbox(vbox)
	game_over_panel.add_child(vbox)
	ui_layer.add_child(game_over_panel)


func build_base()->PanelContainer:
	var panel = PanelContainer.new()
	panel.visible = false
	return panel


func attach_panel_to_center(panel:PanelContainer):
	panel.anchor_top = 0
	panel.anchor_bottom = 0
	panel.offset_top = 0
	panel.offset_bottom = 0
	panel.anchor_left = 0
	panel.anchor_right = 0
	panel.offset_left = 0
	panel.offset_right = 0


func build_vbox()->VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return vbox


func style_box(color:Color)->StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	
	return style


func create_vbox_title(vbox:VBoxContainer,color:Color):
	var title_label := Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.text = "La partie est terminée"
	title_label.add_theme_color_override("font_color", color)
	vbox.add_child(title_label)


func add_winner_to_vbox(vbox:VBoxContainer) -> Dictionary:
	# Ajout du gagnant
	var label_winner = Text_winner
	label_winner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label_winner)
	return label_winner
