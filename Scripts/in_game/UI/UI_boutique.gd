class_name UI_boutique
extends CanvasLayer

# =========================
# SIGNAUX
# =========================
signal buy_ship_requested(port: Ports, buyer: Player, buying_ship: Node)
signal heal_ship_requested(port: Ports, ship: Node, buyer: Player)
signal heal_port_requested(port: Ports, buyer: Player, paying_ship: Node)
signal boutique_closed()
signal open_recrutement_requested(port: Ports, player: Player, ship: Node)

# =========================
# CONSTANTES
# =========================
const SHIP_COST: int = 40         # Coût en poissons pour acheter un navire
const HEAL_SHIP_COST: int = 10    # Coût en poissons pour soigner un navire
const HEAL_PORT_COST: int = 15    # Coût en poissons pour soigner le port

# =========================
# RÉFÉRENCES
# =========================
var _port: Ports = null
var _player: Player = null
var _current_ship: Node = null    # Navire sélectionné/amarré à ce port (peut être null)

# =========================
# NOEUDS UI
# =========================
var _panel: Panel
var _title_label: Label
var _fish_label: Label
var _close_button: Button

# -- Section : Acheter un navire --
var _buy_ship_button: Button
var _buy_ship_label: Label
var _buy_ship_cost_label: Label

# -- Section : Soigner le navire --
var _heal_ship_button: Button
var _heal_ship_label: Label
var _heal_ship_cost_label: Label
var _heal_ship_info_label: Label

# -- Section : Soigner le port --
var _heal_port_button: Button
var _heal_port_label: Label
var _heal_port_cost_label: Label
var _heal_port_info_label: Label

# -- Section : Équipage --
var _crew_button: Button
var _crew_info_label: Label

# -- Feedback --
var _feedback_label: Label
var _feedback_timer: Timer


# =========================
# CONSTRUCTEUR
# =========================
func _init(port: Ports, player: Player, docked_ship: Node = null) -> void:
	_port = port
	_player = player
	_current_ship = docked_ship
	layer = 10


# =========================
# READY
# =========================
func _ready() -> void:
	_build_ui()
	# On attend un frame pour que Navires._ready() ait initialisé current_hp/max_hp
	await get_tree().process_frame
	_refresh_ui()

	# Ajoute au ui_layer du joueur si disponible
	var ui_layer = get_tree().get_first_node_in_group("ui_layer")
	if ui_layer and get_parent() == null:
		ui_layer.add_child(self)

	DEBUG.log("UI_boutique ouverte - Port [%d] | Joueur : %s" % [
		_port.id if _port else -1,
		_player.player_name if _player else "?"
	])


# =========================
# CONSTRUCTION DE L'INTERFACE
# =========================
func _build_ui() -> void:
	# -- Fond semi-transparent --
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.45)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# -- Panel principal --
	_panel = Panel.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(420, 700)
	_panel.position = -_panel.custom_minimum_size / 2.0
	add_child(_panel)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 12)
	# Marges internes
	vbox.offset_left   = 20
	vbox.offset_top    = 20
	vbox.offset_right  = -20
	vbox.offset_bottom = -20
	_panel.add_child(vbox)

	# -- Titre --
	_title_label = Label.new()
	_title_label.text = "⚓ Boutique - %s" % _get_port_display_name()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(_title_label)

	# -- Solde poissons --
	_fish_label = Label.new()
	_fish_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fish_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vbox.add_child(_fish_label)

	vbox.add_child(_separator())

	# ---------- ACHETER UN NAVIRE ----------
	vbox.add_child(_section_label("🚢  Acheter un navire"))

	_buy_ship_cost_label = Label.new()
	_buy_ship_cost_label.text = "Coût : %d 🐟" % SHIP_COST
	_buy_ship_cost_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_buy_ship_cost_label)

	_buy_ship_button = Button.new()
	_buy_ship_button.text = "Acheter un navire"
	_buy_ship_button.pressed.connect(_on_buy_ship_pressed)
	vbox.add_child(_buy_ship_button)

	vbox.add_child(_separator())

	# ---------- SOIGNER UN NAVIRE ----------
	vbox.add_child(_section_label("🩹  Soigner le navire"))

	_heal_ship_info_label = Label.new()
	_heal_ship_info_label.add_theme_font_size_override("font_size", 12)
	_heal_ship_info_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	vbox.add_child(_heal_ship_info_label)

	_heal_ship_cost_label = Label.new()
	_heal_ship_cost_label.text = "Coût : %d 🐟" % HEAL_SHIP_COST
	_heal_ship_cost_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_heal_ship_cost_label)

	_heal_ship_button = Button.new()
	_heal_ship_button.text = "Soigner le navire"
	_heal_ship_button.pressed.connect(_on_heal_ship_pressed)
	vbox.add_child(_heal_ship_button)

	vbox.add_child(_separator())

	# ---------- SOIGNER LE PORT ----------
	vbox.add_child(_section_label("🏰  Soigner le port"))

	_heal_port_info_label = Label.new()
	_heal_port_info_label.add_theme_font_size_override("font_size", 12)
	_heal_port_info_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	vbox.add_child(_heal_port_info_label)

	_heal_port_cost_label = Label.new()
	_heal_port_cost_label.text = "Coût : %d 🐟" % HEAL_PORT_COST
	_heal_port_cost_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_heal_port_cost_label)

	_heal_port_button = Button.new()
	_heal_port_button.text = "Soigner le port"
	_heal_port_button.pressed.connect(_on_heal_port_pressed)
	vbox.add_child(_heal_port_button)

	vbox.add_child(_separator())

	# ---------- ÉQUIPAGE ----------
	
	vbox.add_child(_section_label("👥  Gérer l'équipage"))

	_crew_info_label = Label.new()
	_crew_info_label.add_theme_font_size_override("font_size", 12)
	_crew_info_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	vbox.add_child(_crew_info_label)

	_crew_button = Button.new()
	_crew_button.text = "⚓ Ouvrir le recrutement"
	_crew_button.pressed.connect(_on_crew_pressed)
	vbox.add_child(_crew_button)

	# -- Feedback --
	_feedback_label = Label.new()
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.add_theme_font_size_override("font_size", 13)
	_feedback_label.visible = false
	vbox.add_child(_feedback_label)

	# -- Bouton Fermer --
	_close_button = Button.new()
	_close_button.text = "Fermer"
	_close_button.pressed.connect(_on_close_pressed)
	vbox.add_child(_close_button)

	# -- Timer feedback --
	_feedback_timer = Timer.new()
	_feedback_timer.one_shot = true
	_feedback_timer.wait_time = 2.5
	_feedback_timer.timeout.connect(_hide_feedback)
	add_child(_feedback_timer)


# =========================
# RAFRAÎCHISSEMENT
# =========================
func _refresh_ui() -> void:
	if _player == null or _port == null:
		return

	# Les poissons affichés sont ceux du navire qui a ouvert la boutique
	var fish_count: int = 0
	if _current_ship != null and is_instance_valid(_current_ship) and "nourriture" in _current_ship:
		fish_count = _current_ship.nourriture
	elif _player and _player.has_method("get_poissons"):
		fish_count = _player.get_poissons()  # Fallback : total du joueur

	# -- Solde --
	_fish_label.text = "Vos poissons : %d 🐟" % fish_count

	# -- Acheter navire --
	_buy_ship_button.disabled = fish_count < SHIP_COST

	# -- Soigner navire --
	var has_ship := _current_ship != null and is_instance_valid(_current_ship)
	if has_ship:
		var navire := _current_ship as Navires
		var hp_cur: int = navire.vie if navire != null else 0
		var hp_max: int = navire.maxvie if navire != null else 0
		_heal_ship_info_label.text = "PV navire : %d / %d" % [hp_cur, hp_max]
		var already_full_ship: bool = hp_cur >= hp_max
		_heal_ship_button.disabled = fish_count < HEAL_SHIP_COST or already_full_ship
		if already_full_ship:
			_heal_ship_info_label.text += "  ✅ Déjà au maximum"
	else:
		_heal_ship_info_label.text = "Aucun navire amarré à ce port."
		_heal_ship_button.disabled = true

	# -- Soigner port --
	_heal_port_info_label.text = "PV port : %d / %d" % [_port.current_hp, _port.max_hp]
	var already_full_port := _port.current_hp >= _port.max_hp
	_heal_port_button.disabled = fish_count < HEAL_PORT_COST or already_full_port
	if already_full_port:
		_heal_port_info_label.text += "  ✅ Déjà au maximum"

	# -- Équipage --
	if has_ship and _current_ship is Navires:
		var navire: Navires = _current_ship as Navires
		var crew_count: int = navire.get_equipage_size()
		var crew_max: int = 6
		_crew_info_label.text = "Membres d'équipage : %d / %d" % [crew_count, crew_max]
		_crew_button.disabled = false
	else:
		_crew_info_label.text = "Aucun navire amarré."
		_crew_button.disabled = true


# =========================
# CALLBACKS BOUTONS
# =========================
func _on_buy_ship_pressed() -> void:
	DEBUG.log("UI_boutique - Demande d'achat de navire (Port [%d])" % _port.id)
	buy_ship_requested.emit(_port, _player, _current_ship)
	_refresh_ui()


func _on_heal_ship_pressed() -> void:
	if _current_ship == null or not is_instance_valid(_current_ship):
		_show_feedback("❌ Aucun navire à soigner.", Color(1, 0.3, 0.3))
		return
	DEBUG.log("UI_boutique - Demande de soin du navire [%d] (Port [%d])" % [_current_ship.id, _port.id])
	heal_ship_requested.emit(_port, _current_ship, _player)
	_refresh_ui()


func _on_heal_port_pressed() -> void:
	DEBUG.log("UI_boutique - Demande de soin du port [%d]" % _port.id)
	heal_port_requested.emit(_port, _player, _current_ship)
	_refresh_ui()


func _on_close_pressed() -> void:
	boutique_closed.emit()
	DEBUG.log("UI_boutique fermée (Port [%d])" % (_port.id if _port else -1))
	queue_free()


func _on_crew_pressed() -> void:
	if _current_ship == null or not is_instance_valid(_current_ship):
		_show_feedback("❌ Aucun navire pour gérer l'équipage.", Color(1, 0.3, 0.3))
		return
	DEBUG.log("UI_boutique - Ouverture recrutement (Port [%d], navire [%d])" % [_port.id, _current_ship.id])
	open_recrutement_requested.emit(_port, _player, _current_ship)
	# On ferme la boutique principale pour éviter l'empilement d'UI
	queue_free()


# =========================
# FEEDBACK VISUEL
# =========================
func _show_feedback(message: String, color: Color = Color.WHITE) -> void:
	_feedback_label.text = message
	_feedback_label.add_theme_color_override("font_color", color)
	_feedback_label.visible = true
	_feedback_timer.start()


func _hide_feedback() -> void:
	_feedback_label.visible = false


# =========================
# UTILITAIRES
# =========================
func _section_label(text: String) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 15)
	return lbl


func _separator() -> HSeparator:
	return HSeparator.new()


# =========================
# API PUBLIQUE
# =========================

## Retourne le nom affiché du port (généré si vide), en lisant UI_stats_port si disponible
func _get_port_display_name() -> String:
	if _port == null:
		return "Port"
	# Priorité : nom généré par UI_stats_port s'il est attaché au port
	for child in _port.get_children():
		if child is UI_stats_port:
			return child._nom_affiche
	# Fallback : nom brut ou valeur par défaut
	if _port.Nom_port != "" and _port.Nom_port != "Nom du Port":
		return _port.Nom_port
	return "Port"


## Met à jour le navire actuellement amarré (appelable depuis l'extérieur)
func set_docked_ship(ship: Node) -> void:
	_current_ship = ship
	_refresh_ui()


## Force un rafraîchissement depuis l'extérieur (ex: après un achat)
func refresh() -> void:
	_refresh_ui()
