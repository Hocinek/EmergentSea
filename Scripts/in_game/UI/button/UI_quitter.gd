class_name UI_quitter
extends Node

# =========================
# UI_quitter
# Affiche un bouton "🚪" permanent en bas à gauche, à côté du bouton "?"
# Permet de quitter la partie et retourner au menu principal.
# =========================

var ui_layer: CanvasLayer

# Bouton de sortie permanent
var btn_quitter: Button

# =========================
# INITIALISATION
# =========================
func _init() -> void:
	pass


func setup() -> void:
	await get_tree().process_frame
	ui_layer = get_tree().get_first_node_in_group("ui_layer")
	if not ui_layer:
		DEBUG.log("[UI_quitter] ui_layer introuvable !", DEBUG.ERROR)
		return
	_build_ui()
	DEBUG.log("[UI_quitter] Bouton quitter initialisé")


func _build_ui() -> void:
	_create_btn_quitter()


# =========================
# BOUTON "🚪"
# Ancré en bas à gauche, à droite du bouton "?" (offset_left = 64)
# =========================
func _create_btn_quitter() -> void:
	btn_quitter = Button.new()
	btn_quitter.text = "🚪"
	btn_quitter.custom_minimum_size = Vector2(44, 44)
	btn_quitter.add_theme_font_size_override("font_size", 20)
	btn_quitter.tooltip_text = "Quitter la partie"

	# Ancrage bas-gauche, décalé de 48px à droite du bouton "?" (qui occupe 16->60)
	btn_quitter.anchor_left   = 0.0
	btn_quitter.anchor_right  = 0.0
	btn_quitter.anchor_top    = 1.0
	btn_quitter.anchor_bottom = 1.0
	btn_quitter.offset_left   = 64   # 16 (marge) + 44 (largeur btn "?") + 4 (espace)
	btn_quitter.offset_right  = 108
	btn_quitter.offset_top    = -60
	btn_quitter.offset_bottom = -16

	btn_quitter.pressed.connect(_on_btn_quitter_pressed)
	ui_layer.add_child(btn_quitter)


# =========================
# CALLBACKS
# =========================
func _on_btn_quitter_pressed() -> void:
	DEBUG.log("[UI_quitter] Quitter la partie")

	var network_manager = get_tree().get_first_node_in_group("network_manager")

	# Multi
	if multiplayer.has_multiplayer_peer() and network_manager:
		network_manager.handle_local_player_quit()

	get_tree().change_scene_to_file("res://Scenes/accueil/MainMenu.tscn")
