class_name UI_game_over
extends Node

var ui_layer: CanvasLayer

# Panneau principal
var game_over_panel: PanelContainer
var label_title:  Label   # <- référence ajoutée pour pouvoir changer "Victoire" / "Défaite"
var label_winner: Label
var label_raison: Label

# Chemin vers la scène d'accueil - modifie selon ton projet
@export var main_menu_scene: String = "res://Scenes/accueil/MainMenu.tscn"

const COLOR_BG      : Color = Color(0, 0.2, 0.4, 0.9)
const COLOR_TEXT    : Color = Color(0.5, 0.8, 1)
const COLOR_TITLE   : Color = Color(1, 1, 1)
const COLOR_DEFEAT  : Color = Color(1, 0.3, 0.3)   # rouge pour la défaite


# =========================================================
# Initialisation
# =========================================================

func init() -> void:
	_build_ui()


func _build_ui() -> void:
	await get_tree().process_frame

	ui_layer = get_tree().get_first_node_in_group("ui_layer")
	if not ui_layer:
		DEBUG.log("[UI_GAME_OVER] ui_layer introuvable.", DEBUG.ERROR)
		return

	_create_end_game_panel()


# =========================================================
# Affichage - Victoire
# =========================================================

func show_game_over(winner: Player, raison: String) -> void:
	if not game_over_panel:
		DEBUG.log("[UI_GAME_OVER] Panneau non construit.", DEBUG.ERROR)
		return

	# Titre en blanc (couleur neutre)
	label_title.text = "Partie terminée"
	label_title.add_theme_color_override("font_color", COLOR_TITLE)

	if winner != null:
		label_winner.text = "🏆 Vainqueur : %s" % winner.player_name
		label_raison.text  = "Victoire par %s" % raison
	else:
		label_winner.text = "Match nul"
		label_raison.text  = "Aucun survivant"

	game_over_panel.visible = true


# =========================================================
# Affichage - Défaite
# =========================================================

func show_defeat(winner: Player, raison: String) -> void:
	if not game_over_panel:
		DEBUG.log("[UI_GAME_OVER] Panneau non construit.", DEBUG.ERROR)
		return

	# Titre en rouge pour signaler la défaite
	label_title.text = "Défaite !"
	label_title.add_theme_color_override("font_color", COLOR_DEFEAT)

	if winner != null:
		label_winner.text = "🏆 %s a gagné" % winner.player_name
		label_raison.text  = "Victoire adverse par %s" % raison
	else:
		label_winner.text = "Partie terminée"
		label_raison.text  = "Résultat indéterminé"

	game_over_panel.visible = true


# =========================================================
# Construction du panneau
# =========================================================

func _create_end_game_panel() -> void:
	# --- Conteneur principal ---
	game_over_panel = PanelContainer.new()
	game_over_panel.visible = false

	# Centrage via ancres
	game_over_panel.set_anchors_preset(Control.PRESET_CENTER)
	game_over_panel.custom_minimum_size = Vector2(420, 260)

	# Couleur de fond
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BG
	style.set_corner_radius_all(10)
	style.content_margin_left   = 24
	style.content_margin_right  = 24
	style.content_margin_top    = 20
	style.content_margin_bottom = 20
	game_over_panel.add_theme_stylebox_override("panel", style)

	# --- VBox centrale ---
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL

	# Titre - stocké dans label_title pour pouvoir le modifier à l'affichage
	label_title = Label.new()
	label_title.text = "Partie terminée"
	label_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_title.add_theme_color_override("font_color", COLOR_TITLE)
	label_title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(label_title)

	# Séparateur visuel
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Nom du vainqueur / message principal
	label_winner = Label.new()
	label_winner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_winner.add_theme_color_override("font_color", COLOR_TEXT)
	label_winner.add_theme_font_size_override("font_size", 18)
	vbox.add_child(label_winner)

	# Raison du résultat
	label_raison = Label.new()
	label_raison.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_raison.add_theme_color_override("font_color", COLOR_TEXT)
	label_raison.add_theme_font_size_override("font_size", 14)
	vbox.add_child(label_raison)

	# Bouton retour au menu
	var btn := Button.new()
	btn.text = "Retour au menu principal"
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(_on_back_to_menu_pressed)
	vbox.add_child(btn)

	game_over_panel.add_child(vbox)
	ui_layer.add_child(game_over_panel)


func _on_back_to_menu_pressed() -> void:
	get_tree().change_scene_to_file(main_menu_scene)
