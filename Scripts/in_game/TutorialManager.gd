class_name TutorialManager
extends Node

# =========================
# TutorialManager
# Gère le tutoriel guidé du jeu Emergent-Sea.
#
# FONCTIONNEMENT :
#   - Le flag is_tutorial_mode est activé depuis le menu principal
#   - Une fois la scène Main.tscn chargée, le tutoriel démarre automatiquement
#   - Chaque étape affiche une popup et attend une action précise du joueur
#   - Le tutoriel avance automatiquement quand l'action attendue est détectée
#     via les signaux existants du jeu (navire déplacé, tir, pêche, fin de tour)
#
# ÉTAPES :
#   0 - But du jeu (popup, avance sur clic)
#   1 - Déplacer un navire (attend le déplacement)
#   2 - Ouvrir le menu hexagonal (attend clic droit)
#   3 - Pêcher (attend la fin d'une pêche)
#   4 - Attaquer un ennemi (attend un tir)
#   5 - Fin de tour (attend le clic sur le bouton)
#   6 - Brouillard de guerre (popup, avance sur clic)
#   7 - Fin du tutoriel
# =========================

# =========================
# FLAG TUTORIEL
# Mis à true depuis le menu principal avant de charger Main.tscn
# =========================
var is_tutorial_mode: bool = false

# Étape courante du tutoriel
var current_step: int = 0

# Indique si le tutoriel est en cours (scène de jeu chargée)
var _started: bool = false

# =========================
# UI
# =========================
var ui_layer: CanvasLayer = null
var panel: PanelContainer = null
var label_title: Label = null
var label_body: Label = null
var btn_next: Button = null

# =========================
# CONSTANTES VISUELLES
# =========================
const COLOR_BG:    Color = Color(0.0,  0.15, 0.3,  0.95)
const COLOR_TITLE: Color = Color(1.0,  1.0,  1.0)
const COLOR_TEXT:  Color = Color(0.5,  0.85, 1.0)
const COLOR_BTN:   Color = Color(0.0,  0.4,  0.6,  1.0)

# =========================
# CONTENU DES ÉTAPES
# Chaque entrée = [titre, texte explicatif, bouton_visible]
# bouton_visible = true si le joueur doit cliquer pour avancer
#                 false si on attend une action en jeu
# =========================
const ETAPES: Array = [
	[
		"⚓ Bienvenue dans Emergent-Sea !",
		"Vous commandez une flotte de navires sur une carte maritime hexagonale.\n\nObjectif : dominer les mers en accumulant 150 🐟 poissons, 30 navires, ou en éliminant tous vos adversaires.\n\nCliquez sur « Suivant » pour commencer.",
		true
	],
	[
		"🚢 Déplacer un navire",
		"Cliquez gauche sur une case bleue (navigable) pour déplacer votre navire sélectionné.\n\nVous pouvez aussi faire un clic droit sur votre navire → « Déplacer ».\n\n➡️ Déplacez votre navire pour continuer.",
		false
	],
	[
		"📋 Le menu d'actions",
		"Faites un clic droit sur votre navire pour ouvrir le menu hexagonal.\n\nIl vous donne accès à toutes les actions : Déplacer, Attaquer, Inspecter, Stats, Pêcher, Changer de navire.\n\n➡️ Ouvrez le menu hexagonal pour continuer.",
		false
	],
	[
		"🐟 Pêcher",
		"La pêche vous permet de collecter de la nourriture (🐟).\n\nOuvrez le menu hexagonal → « Pêcher », ou utilisez la touche dédiée.\n\nLes zones de pêche rapportent plus que l'eau libre.\n\n➡️ Pêchez pour continuer.",
		false
	],
	[
		"⚔️ Attaquer un ennemi",
		"Faites un clic droit sur une case ennemie pour tirer dessus.\n\nVous pouvez aussi passer par le menu → « Attaquer » puis cliquer sur la case cible.\n\nAttention : tirer coûte de l'énergie ⚡.\n\n➡️ Attaquez un navire ennemi pour continuer.",
		false
	],
	[
		"🔄 Fin de tour",
		"Quand vous avez terminé vos actions, cliquez sur le bouton « Fin du tour » en bas de l'écran.\n\nL'énergie ⚡ de vos navires sera restaurée au début de votre prochain tour.\n\n➡️ Terminez votre tour pour continuer.",
		false
	],
	[
		"🌫️ Brouillard de guerre",
		"La carte est couverte d'un brouillard de guerre.\n\n⬛ Noir : zone jamais explorée.\n🔲 Gris : zone déjà vue mais hors de portée actuelle.\n⬜ Clair : zone visible par un de vos navires.\n\nExplorez la carte pour découvrir les ressources et l'ennemi.\n\nCliquez sur « Terminer » pour finir le tutoriel.",
		true
	],
]

# =========================
# INITIALISATION
# =========================
func _enter_tree() -> void:
	add_to_group("tutorial_manager")


func _ready() -> void:
	# On écoute le changement de scène pour démarrer le tuto au bon moment
	get_tree().tree_changed.connect(_on_tree_changed)


# =========================
# DÉTECTION DU CHARGEMENT DE LA SCÈNE DE JEU
# =========================
func _on_tree_changed() -> void:
	# On ne démarre qu'une seule fois et uniquement en mode tutoriel
	if not is_tutorial_mode or _started:
		return

	# On attend que le GameManager soit présent dans l'arbre
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager == null:
		return

	_started = true
	# On attend quelques frames que tout soit bien initialisé
	await get_tree().create_timer(1.5).timeout
	_start_tutorial()


# =========================
# DÉMARRAGE DU TUTORIEL
# =========================
func _start_tutorial() -> void:
	DEBUG.log("[TUTORIAL] Démarrage du tutoriel")
	current_step = 0

	# Récupérer le ui_layer
	ui_layer = get_tree().get_first_node_in_group("ui_layer")
	if not ui_layer:
		DEBUG.log("[TUTORIAL] ui_layer introuvable !", DEBUG.ERROR)
		return

	# Construire le panneau de popup
	_build_ui()

	# Connecter les signaux du jeu pour détecter les actions du joueur
	_connect_game_signals()

	# Afficher la première étape
	_show_step(current_step)


# =========================
# CONSTRUCTION DU PANNEAU DE POPUP
# =========================
func _build_ui() -> void:
	panel = PanelContainer.new()
	panel.visible = false

	# Ancrage au centre de l'écran
	panel.anchor_left   = 0.5
	panel.anchor_right  = 0.5
	panel.anchor_top    = 0.5
	panel.anchor_bottom = 0.5
	panel.custom_minimum_size = Vector2(520, 0)
	panel.offset_left   = -260
	panel.offset_right  = 260
	panel.offset_top    = -150
	panel.offset_bottom = 150

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
	vbox.add_theme_constant_override("separation", 10)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Titre de l'étape
	label_title = Label.new()
	label_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_title.add_theme_color_override("font_color", COLOR_TITLE)
	label_title.add_theme_font_size_override("font_size", 17)
	vbox.add_child(label_title)

	# Séparateur
	vbox.add_child(HSeparator.new())

	# Corps du texte
	label_body = Label.new()
	label_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_body.add_theme_color_override("font_color", COLOR_TEXT)
	label_body.add_theme_font_size_override("font_size", 14)
	vbox.add_child(label_body)

	# Bouton "Suivant" / "Terminer" (visible uniquement sur les étapes manuelles)
	btn_next = Button.new()
	btn_next.text = "Suivant"
	btn_next.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_next.pressed.connect(_on_btn_next_pressed)
	vbox.add_child(btn_next)

	panel.add_child(vbox)
	ui_layer.add_child(panel)
	DEBUG.log("[TUTORIAL] Panneau construit")


# =========================
# CONNEXION AUX SIGNAUX DU JEU
# On écoute les signaux existants pour détecter les actions du joueur
# =========================
func _connect_game_signals() -> void:
	# Déplacement d'un navire → étape 1
	var ships = get_tree().get_nodes_in_group("ships")
	for ship in ships:
		if ship is Navires and ship.is_player_controlled:
			if ship.has_signal("sig_navire_moved") and not ship.sig_navire_moved.is_connected(_on_navire_moved):
				ship.sig_navire_moved.connect(_on_navire_moved)

	# Menu hexagonal ouvert → étape 2
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager and game_manager.has_signal("ship_selected"):
		# On utilise sig_open_hex_menu via GameManager
		pass

	# Fin de pêche → étape 3
	# On connecte directement sur les navires du joueur
	_reconnect_ship_signals()

	# Fin de tour → étape 5
	var turn_manager = get_tree().get_first_node_in_group("turn_manager")
	if turn_manager and turn_manager.has_signal("turn_ended"):
		if not turn_manager.turn_ended.is_connected(_on_turn_ended):
			turn_manager.turn_ended.connect(_on_turn_ended)

	DEBUG.log("[TUTORIAL] Signaux connectés")


func _reconnect_ship_signals() -> void:
	# Reconnecte les signaux sur tous les navires du joueur
	# (appelé aussi après spawn pour attraper les nouveaux navires)
	var ships = get_tree().get_nodes_in_group("ships")
	for ship in ships:
		if ship is Navires and ship.is_player_controlled:
			# Pêche terminée
			if ship.has_signal("sig_show_fishing") and not ship.sig_show_fishing.is_connected(_on_fishing_done):
				ship.sig_show_fishing.connect(_on_fishing_done)
			# Tir effectué → on écoute les dégâts infligés
			if ship.has_signal("sig_navire_damaged"):
				pass  # géré via _on_navire_damaged sur les navires ennemis
		# Dégâts reçus par n'importe quel navire → étape 4
		if ship is Navires and not ship.is_player_controlled:
			if ship.has_signal("sig_navire_damaged") and not ship.sig_navire_damaged.is_connected(_on_navire_damaged):
				ship.sig_navire_damaged.connect(_on_navire_damaged)

	# Menu hexagonal → étape 2
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager:
		for ship in ships:
			if ship is Navires and ship.is_player_controlled:
				if ship.has_signal("sig_open_hex_menu") and not ship.sig_open_hex_menu.is_connected(_on_hex_menu_opened):
					ship.sig_open_hex_menu.connect(_on_hex_menu_opened)


# =========================
# AFFICHAGE D'UNE ÉTAPE
# =========================
func _show_step(step: int) -> void:
	if step >= ETAPES.size():
		_end_tutorial()
		return

	var etape: Array = ETAPES[step]
	var titre: String       = etape[0]
	var texte: String       = etape[1]
	var btn_visible: bool   = etape[2]

	label_title.text   = titre
	label_body.text    = texte
	btn_next.visible   = btn_visible

	# Adapter le texte du bouton selon l'étape
	if step == ETAPES.size() - 1:
		btn_next.text = "Terminer"
	else:
		btn_next.text = "Suivant"

	panel.visible = true
	DEBUG.log("[TUTORIAL] Étape %d : %s" % [step, titre])


# =========================
# PASSAGE À L'ÉTAPE SUIVANTE
# =========================
func _advance_step() -> void:
	current_step += 1
	_show_step(current_step)


# =========================
# FIN DU TUTORIEL
# =========================
func _end_tutorial() -> void:
	if panel:
		panel.visible = false
	is_tutorial_mode = false
	_started = false
	DEBUG.log("[TUTORIAL] Tutoriel terminé")


# =========================
# CALLBACKS — ACTIONS DU JOUEUR
# =========================

## Bouton "Suivant" / "Terminer" cliqué
func _on_btn_next_pressed() -> void:
	_advance_step()


## Navire du joueur déplacé → valide l'étape 1
func _on_navire_moved(_ship) -> void:
	if current_step == 1:
		_advance_step()


## Menu hexagonal ouvert → valide l'étape 2
func _on_hex_menu_opened(_navire, _screen_pos) -> void:
	if current_step == 2:
		_advance_step()


## Pêche déclenchée → valide l'étape 3
func _on_fishing_done() -> void:
	if current_step == 3:
		_advance_step()


## Navire ennemi touché → valide l'étape 4
func _on_navire_damaged(_navire, _damage) -> void:
	if current_step == 4:
		_advance_step()


## Fin de tour → valide l'étape 5
func _on_turn_ended(_player) -> void:
	if current_step == 5:
		_advance_step()
