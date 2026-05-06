class_name UI_aide
extends Node

# =========================
# UI_aide
# Affiche un panneau d'aide récapitulatif des commandes et mécaniques du jeu.
# Accessible à tout moment en solo et en multi via un bouton "?" fixe en jeu.
#
# STRUCTURE :
#   - Un bouton "?" ancré en bas à gauche de l'écran
#   - Un panneau semi-transparent centré qui liste toutes les commandes
#   - Le panneau se ferme en recliquant sur "?" ou en appuyant sur Échap
# =========================

var ui_layer: CanvasLayer

# Bouton d'ouverture permanent
var btn_aide: Button

# Panneau principal d'aide
var panel: PanelContainer
var panel_visible: bool = false

# =========================
# CONSTANTES VISUELLES
# =========================
const COLOR_BG:    Color = Color(0.0,  0.15, 0.3,  0.93)
const COLOR_TITLE: Color = Color(1.0,  1.0,  1.0)
const COLOR_TEXT:  Color = Color(0.5,  0.85, 1.0)
const COLOR_KEY:   Color = Color(1.0,  0.85, 0.4)

# =========================
# CONTENU DE L'AIDE
# Chaque entrée = [icône + action, description]
# =========================
const COMMANDES: Array = [
	["🖱️ Clic gauche sur case", "Déplacer le navire sélectionné (1⚡ par case)"],
	["🖱️ Clic droit sur navire", "Ouvrir le menu d'actions"],
	["🖱️ Clic droit sur case", "Attaquer la case ciblée (10⚡)"],
	["Tab / Maj+Tab", "Navire suivant / précédent"],
	["1 / 2 / 3", "Sélectionner le navire 1, 2 ou 3"],
	["Échap", "Annuler l'action en cours"],
	["", ""],  # Séparateur visuel
	["⬆️⬇️⬅️➡️ Touches fléchées", "Déplacer la caméra sur la carte"],
	["🖱️ Molette souris", "Zoomer / dézoomer"],
	["", ""],  # Séparateur visuel
	["⚓ Menu → Déplacer", "Activer le mode déplacement"],
	["⚔️ Menu → Attaquer", "Activer le mode attaque"],
	["🔍 Menu → Inspecter", "Inspecter une case (poissons, navires)"],
	["📊 I ou Menu → Stats", "Afficher / masquer les statistiques"],
	["🐟 F ou Menu → Pêcher", "Pêcher sur la case actuelle (1⚡)"],
	["🔄 Menu → Changer", "Passer au navire suivant"],
	["", ""],  # Séparateur visuel
	["❤️  Vie", "Points de vie du navire"],
	["⚡ Énergie", "Actions restantes ce tour"],
	["🐟 Nourriture", "Stock de poissons accumulés"],
	["👥 Équipage", "Nombre de membres d'équipage"],
	["", ""],  # Séparateur visuel
	["🏆 Victoire", "150 poissons OU 30 navires OU dernier survivant"],
]

# =========================
# INITIALISATION
# =========================
func _init() -> void:
	pass


func setup() -> void:
	await get_tree().process_frame
	ui_layer = get_tree().get_first_node_in_group("ui_layer")
	if not ui_layer:
		DEBUG.log("[UI_aide] ui_layer introuvable !", DEBUG.ERROR)
		return
	_build_ui()
	DEBUG.log("[UI_aide] Panneau d'aide initialisé")


func _build_ui() -> void:
	_create_btn_aide()
	_create_panel_aide()


# =========================
# BOUTON "?"
# Ancré en bas à gauche, toujours visible en jeu
# =========================
func _create_btn_aide() -> void:
	btn_aide = Button.new()
	btn_aide.text = "?"
	btn_aide.custom_minimum_size = Vector2(44, 44)
	btn_aide.add_theme_font_size_override("font_size", 20)

	# Ancrage bas-gauche
	btn_aide.anchor_left   = 0.0
	btn_aide.anchor_right  = 0.0
	btn_aide.anchor_top    = 1.0
	btn_aide.anchor_bottom = 1.0
	btn_aide.offset_left   = 16
	btn_aide.offset_right  = 60
	btn_aide.offset_top    = -60
	btn_aide.offset_bottom = -16

	btn_aide.pressed.connect(_on_btn_aide_pressed)
	ui_layer.add_child(btn_aide)


# =========================
# PANNEAU D'AIDE
# Centré, semi-transparent, scrollable
# =========================
func _create_panel_aide() -> void:
	panel = PanelContainer.new()
	panel.visible = false

	# Ancrage au-dessus du bouton "?" en bas à gauche
	panel.anchor_left   = 0.0
	panel.anchor_right  = 0.0
	panel.anchor_top    = 1.0
	panel.anchor_bottom = 1.0
	panel.custom_minimum_size = Vector2(520, 560)
	panel.offset_left   = 16
	panel.offset_right  = 536
	panel.offset_top    = -596
	panel.offset_bottom = -60

	# Style de fond
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BG
	style.set_corner_radius_all(10)
	style.content_margin_left   = 20
	style.content_margin_right  = 20
	style.content_margin_top    = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)

	# VBox principale
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL

	# Titre du panneau
	var title := Label.new()
	title.text = "📖 Aide — Commandes et mécaniques"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COLOR_TITLE)
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	# Séparateur sous le titre
	vbox.add_child(HSeparator.new())

	# Zone scrollable pour les commandes
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 420)
	vbox.add_child(scroll)

	var inner_vbox := VBoxContainer.new()
	inner_vbox.add_theme_constant_override("separation", 4)
	inner_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inner_vbox)

	# Remplissage des lignes de commandes
	for commande in COMMANDES:
		var action: String = commande[0]
		var description: String = commande[1]

		# Ligne vide = séparateur visuel
		if action == "" and description == "":
			inner_vbox.add_child(HSeparator.new())
			continue

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)

		# Colonne gauche : touche / action
		var lbl_key := Label.new()
		lbl_key.text = action
		lbl_key.custom_minimum_size = Vector2(220, 0)
		lbl_key.add_theme_color_override("font_color", COLOR_KEY)
		lbl_key.add_theme_font_size_override("font_size", 13)
		hbox.add_child(lbl_key)

		# Colonne droite : description
		var lbl_desc := Label.new()
		lbl_desc.text = description
		lbl_desc.add_theme_color_override("font_color", COLOR_TEXT)
		lbl_desc.add_theme_font_size_override("font_size", 13)
		lbl_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hbox.add_child(lbl_desc)

		inner_vbox.add_child(hbox)

	# Bouton de fermeture en bas
	var sep_bas := HSeparator.new()
	vbox.add_child(sep_bas)

	var btn_close := Button.new()
	btn_close.text = "Fermer (Échap)"
	btn_close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_close.pressed.connect(_on_btn_close_pressed)
	vbox.add_child(btn_close)

	panel.add_child(vbox)
	ui_layer.add_child(panel)


# =========================
# GESTION INPUT
# Fermeture via Échap si le panneau est ouvert
# =========================
func _unhandled_input(event: InputEvent) -> void:
	if panel_visible and event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_close_panel()
			get_viewport().set_input_as_handled()


# =========================
# API PUBLIQUE
# =========================
## Ouvre ou ferme le panneau d'aide
func toggle() -> void:
	if panel_visible:
		_close_panel()
	else:
		_open_panel()


## Ouvre le panneau d'aide
func _open_panel() -> void:
	if not panel:
		return
	panel.visible = true
	panel_visible = true
	btn_aide.visible = false  # Cache le bouton quand le panneau est ouvert
	DEBUG.log("[UI_aide] Panneau ouvert")


## Ferme le panneau d'aide
func _close_panel() -> void:
	if not panel:
		return
	panel.visible = false
	panel_visible = false
	btn_aide.visible = true  # Réaffiche le bouton à la fermeture
	DEBUG.log("[UI_aide] Panneau fermé")


# =========================
# CALLBACKS
# =========================
func _on_btn_aide_pressed() -> void:
	toggle()


func _on_btn_close_pressed() -> void:
	_close_panel()
