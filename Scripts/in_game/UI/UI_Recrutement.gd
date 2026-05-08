class_name UI_recrutement
extends CanvasLayer

# =========================
# SIGNAUX
# =========================
signal crew_hired(ship: Navires, member: CrewMember)
signal recrutement_closed()

# =========================
# RÉFÉRENCES
# =========================
var _port: Ports = null
var _player: Player = null
var _ship: Navires = null

# =========================
# NOEUDS UI
# =========================
var _panel: Panel
var _fish_label: Label
var _crew_slots_container: HBoxContainer
var _available_container: VBoxContainer
var _synergy_label: Label
var _feedback_label: Label
var _feedback_timer: Timer

# Panel de détail des synergies (affiché/masqué via le bouton "Synergies")
var _synergy_panel: PanelContainer = null

# Slots visuels de l'équipage (4 slots)
# Chaque entrée est un dictionnaire { panel, icon, name_lbl, fire_btn }
var _slot_panels: Array = []

# Membres disponibles à l'achat (tous les rôles sauf capitaine)
const HIREABLE_ROLES: Array = [
	CrewMember.Role.CANONNIER,
	CrewMember.Role.NAVIGATEUR,
	CrewMember.Role.MEDECIN,
	CrewMember.Role.PECHEUR,
	CrewMember.Role.CORSAIRE,
	CrewMember.Role.TIREUR_ELITE,
	CrewMember.Role.ECLAIREUR,
	CrewMember.Role.INGENIEUR,
	CrewMember.Role.CUISINIER,
	CrewMember.Role.MATELOT,
	CrewMember.Role.DIPLOMATE,
]

const MAX_CREW: int = 6  # Capitaine + 5 membres

# Limite maximale par rôle (-1 ou absent = pas de limite)
const ROLE_MAX: Dictionary = {
	CrewMember.Role.DIPLOMATE:  1,
	CrewMember.Role.INGENIEUR:  2,
	CrewMember.Role.NAVIGATEUR: 1,
}

# =========================
# DONNÉES DES SYNERGIES (pour le panel d'info)
# Chaque entrée : { icon, nom, membres_requis, effet }
# Les noms correspondent exactement aux chaînes retournées par get_active_synergies()
# =========================
const SYNERGY_DATA: Array = [
	{
		"icon":           "⚔️",
		"nom":            "Flotte de guerre",
		"membres_requis": ["💣 Canonnier", "🏴 Corsaire", "🎯 Tireur d'élite"],
		"effet":          "dgt_tir × 1.5 (bonus proportionnel aux dégâts déjà accumulés)",
	},
	{
		"icon":           "🎣",
		"nom":            "Navire de pêche",
		"membres_requis": ["🎣 Pêcheur", "🍳 Cuisinier"],
		"effet":          "Rendement de pêche × 2",
	},
	{
		"icon":           "⚕️",
		"nom":            "Duo de soins",
		"membres_requis": ["⚕️ Médecin", "🍳 Cuisinier"],
		"effet":          "Régénération de PV du Médecin × 2 par tour",
	},
	{
		"icon":           "🧭",
		"nom":            "Vitesse maximale",
		"membres_requis": ["🧭 Navigateur", "🔭 Éclaireur"],
		"effet":          "-25% coût de déplacement",
	},
	{
		"icon":           "👥",
		"nom":            "Équipage complet",
		"membres_requis": ["6 membres à bord (Capitaine inclus)"],
		"effet":          "+10% sur les dégâts de tir et les poissons passifs par tour",
	},
]


func _init(port: Ports, player: Player, ship: Navires) -> void:
	_port = port
	_player = player
	_ship = ship
	layer = 11


func _ready() -> void:
	_build_ui()
	await get_tree().process_frame
	_refresh_ui()


# =========================
# CONSTRUCTION DE L'INTERFACE
# =========================
func _build_ui() -> void:
	# Fond semi-transparent
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.5)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Panel principal (plus large pour afficher slots + boutique)
	_panel = Panel.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(620, 720)
	_panel.position = -_panel.custom_minimum_size / 2.0
	add_child(_panel)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	vbox.offset_left   = 18
	vbox.offset_top    = 16
	vbox.offset_right  = -18
	vbox.offset_bottom = -16
	_panel.add_child(vbox)

	# Titre
	var title = Label.new()
	title.text = "⚓ Recrutement d'équipage — %s" % (_port.Nom_port if _port else "Port")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 19)
	vbox.add_child(title)

	# Solde poissons
	_fish_label = Label.new()
	_fish_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fish_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vbox.add_child(_fish_label)

	vbox.add_child(_separator())

	# ── Section : Équipage actuel ──
	var crew_title = Label.new()
	crew_title.text = "👥  Équipage actuel  (max %d membres)" % MAX_CREW
	crew_title.add_theme_font_size_override("font_size", 15)
	vbox.add_child(crew_title)

	_crew_slots_container = HBoxContainer.new()
	_crew_slots_container.add_theme_constant_override("separation", 8)
	_crew_slots_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_crew_slots_container)

	_build_crew_slots()

	# ── Ligne : synergies actives + bouton d'info ──
	var synergy_hbox = HBoxContainer.new()
	synergy_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	synergy_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(synergy_hbox)

	_synergy_label = Label.new()
	_synergy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_synergy_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_synergy_label.add_theme_font_size_override("font_size", 12)
	_synergy_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))
	_synergy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_synergy_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_synergy_label.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	synergy_hbox.add_child(_synergy_label)

	# Bouton qui ouvre/ferme le panel de détail des synergies
	var synergy_info_btn = Button.new()
	synergy_info_btn.text = "✨ Synergies"
	synergy_info_btn.add_theme_font_size_override("font_size", 11)
	synergy_info_btn.pressed.connect(_on_synergy_info_pressed)
	synergy_hbox.add_child(synergy_info_btn)

	vbox.add_child(_separator())

	# ── Section : Recruter ──
	var hire_title = Label.new()
	hire_title.text = "🪙  Recruter un membre"
	hire_title.add_theme_font_size_override("font_size", 15)
	vbox.add_child(hire_title)

	_available_container = VBoxContainer.new()
	_available_container.add_theme_constant_override("separation", 6)
	vbox.add_child(_available_container)

	_build_hire_list()

	vbox.add_child(_separator())

	# Feedback
	_feedback_label = Label.new()
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.add_theme_font_size_override("font_size", 13)
	_feedback_label.visible = false
	vbox.add_child(_feedback_label)

	# Bouton fermer
	var close_btn = Button.new()
	close_btn.text = "Fermer"
	close_btn.pressed.connect(_on_close_pressed)
	vbox.add_child(close_btn)

	# Timer feedback
	_feedback_timer = Timer.new()
	_feedback_timer.one_shot = true
	_feedback_timer.wait_time = 2.5
	_feedback_timer.timeout.connect(func(): _feedback_label.visible = false)
	add_child(_feedback_timer)


func _build_crew_slots() -> void:
	# Vider les anciens slots
	for child in _crew_slots_container.get_children():
		child.queue_free()
	_slot_panels.clear()

	for i in range(MAX_CREW):
		var slot_panel = PanelContainer.new()
		slot_panel.custom_minimum_size = Vector2(90, 100)

		var slot_vbox = VBoxContainer.new()
		slot_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		slot_vbox.add_theme_constant_override("separation", 4)
		slot_panel.add_child(slot_vbox)

		var slot_icon = Label.new()
		slot_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_icon.add_theme_font_size_override("font_size", 24)
		slot_icon.name = "SlotIcon"
		slot_vbox.add_child(slot_icon)

		var slot_name = Label.new()
		slot_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_name.add_theme_font_size_override("font_size", 10)
		slot_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		slot_name.name = "SlotName"
		slot_vbox.add_child(slot_name)

		# Bouton congédier (masqué pour capitaine et slots vides)
		var fire_btn = Button.new()
		fire_btn.text = "Congédier"
		fire_btn.add_theme_font_size_override("font_size", 9)
		fire_btn.name = "FireBtn"
		fire_btn.visible = false
		fire_btn.pressed.connect(_on_fire_crew.bind(i))
		slot_vbox.add_child(fire_btn)

		_crew_slots_container.add_child(slot_panel)
		_slot_panels.append({
			"panel":    slot_panel,
			"icon":     slot_icon,
			"name_lbl": slot_name,
			"fire_btn": fire_btn,
		})


func _build_hire_list() -> void:
	# Vider
	for child in _available_container.get_children():
		child.queue_free()

	for role in HIREABLE_ROLES:
		var member_proto = CrewMember.new(role)

		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)

		# Icône + nom
		var info_label = Label.new()
		info_label.text = "%s  %s" % [member_proto.get_icon(), CrewMember.ROLE_NAMES[role]]
		info_label.add_theme_font_size_override("font_size", 13)
		info_label.custom_minimum_size = Vector2(130, 0)
		hbox.add_child(info_label)

		# Description du bonus
		var desc_label = Label.new()
		desc_label.text = CrewMember.ROLE_DESCRIPTIONS[role]
		desc_label.add_theme_font_size_override("font_size", 12)
		desc_label.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
		desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(desc_label)

		# Coût (mis à jour dans _refresh_ui selon diplomate présent)
		var cost_label = Label.new()
		cost_label.add_theme_font_size_override("font_size", 13)
		cost_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		cost_label.custom_minimum_size = Vector2(60, 0)
		cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cost_label.name = "CostLabel"
		hbox.add_child(cost_label)

		# Bouton recruter
		var hire_btn = Button.new()
		hire_btn.text = "Recruter"
		hire_btn.custom_minimum_size = Vector2(80, 0)
		hire_btn.name = "HireBtn_%d" % role
		hire_btn.pressed.connect(_on_hire_pressed.bind(role))
		hbox.add_child(hire_btn)

		_available_container.add_child(hbox)


# =========================
# PANEL DE DÉTAIL DES SYNERGIES
# =========================

## Construit et affiche le panel d'information sur toutes les synergies disponibles.
## Appuyer à nouveau sur le bouton ferme le panel (toggle).
func _on_synergy_info_pressed() -> void:
	# Toggle : ferme le panel s'il est déjà ouvert
	if _synergy_panel != null and is_instance_valid(_synergy_panel):
		_synergy_panel.queue_free()
		_synergy_panel = null
		return

	_synergy_panel = PanelContainer.new()
	# Positionné à droite du panel principal (largeur 620, centré → bord droit à +310)
	# On ajoute 10px de marge pour ne pas coller les deux panels
	_synergy_panel.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_synergy_panel.custom_minimum_size = Vector2(480, 0)
	_synergy_panel.position = Vector2(320, -360)

	# StyleBox entièrement opaque pour que le contenu soit lisible sans transparence
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.12, 0.13, 0.16, 1.0)
	bg_style.border_color = Color(0.35, 0.35, 0.45)
	bg_style.set_border_width_all(1)
	bg_style.set_corner_radius_all(6)
	_synergy_panel.add_theme_stylebox_override("panel", bg_style)

	add_child(_synergy_panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.offset_left   = 16
	vbox.offset_top    = 14
	vbox.offset_right  = -16
	vbox.offset_bottom = -14
	_synergy_panel.add_child(vbox)

	# Titre du panel
	var title = Label.new()
	title.text = "✨ Toutes les synergies"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 17)
	vbox.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "S'activent automatiquement quand les membres requis sont tous à bord."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(subtitle)

	vbox.add_child(_separator())

	# ── Une carte par synergie ──
	for data in SYNERGY_DATA:
		var active: bool = _is_synergy_active(data["nom"])

		var card = PanelContainer.new()
		# Bordure verte si la synergie est active, style par défaut sinon
		if active:
			var style = StyleBoxFlat.new()
			style.bg_color = Color(0.1, 0.25, 0.12)
			style.border_color = Color(0.3, 0.9, 0.4)
			style.set_border_width_all(2)
			style.set_corner_radius_all(4)
			card.add_theme_stylebox_override("panel", style)
		vbox.add_child(card)

		var card_vbox = VBoxContainer.new()
		card_vbox.add_theme_constant_override("separation", 4)
		card_vbox.offset_left   = 10
		card_vbox.offset_top    = 8
		card_vbox.offset_right  = -10
		card_vbox.offset_bottom = -8
		card.add_child(card_vbox)

		# Ligne titre : icône + nom de la synergie + badge "ACTIVE" éventuel
		var header_hbox = HBoxContainer.new()
		card_vbox.add_child(header_hbox)

		var name_lbl = Label.new()
		name_lbl.text = "%s  %s" % [data["icon"], data["nom"]]
		name_lbl.add_theme_font_size_override("font_size", 14)
		if active:
			name_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header_hbox.add_child(name_lbl)

		if active:
			var badge = Label.new()
			badge.text = "✅ ACTIVE"
			badge.add_theme_font_size_override("font_size", 11)
			badge.add_theme_color_override("font_color", Color(0.3, 1.0, 0.45))
			header_hbox.add_child(badge)

		# Membres requis pour déclencher la synergie
		var req_lbl = Label.new()
		var membres_str: String = "  +  ".join(data["membres_requis"])
		req_lbl.text = "Requis : %s" % membres_str
		req_lbl.add_theme_font_size_override("font_size", 11)
		req_lbl.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
		req_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card_vbox.add_child(req_lbl)

		# Effet de la synergie
		var effet_lbl = Label.new()
		effet_lbl.text = "Effet : %s" % data["effet"]
		effet_lbl.add_theme_font_size_override("font_size", 12)
		effet_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
		effet_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card_vbox.add_child(effet_lbl)

	vbox.add_child(_separator())

	# Bouton pour fermer le panel synergies
	var close_btn = Button.new()
	close_btn.text = "Fermer"
	close_btn.pressed.connect(func():
		if _synergy_panel != null and is_instance_valid(_synergy_panel):
			_synergy_panel.queue_free()
			_synergy_panel = null
	)
	vbox.add_child(close_btn)


## Vérifie si une synergie (identifiée par son nom) est actuellement active sur le navire.
## On compare avec les chaînes de get_active_synergies() : "⚔️ Flotte de guerre", etc.
func _is_synergy_active(synergy_nom: String) -> bool:
	if _ship == null or not is_instance_valid(_ship):
		return false
	var actives: Array[String] = _ship.get_active_synergies()
	for s in actives:
		if s.contains(synergy_nom):
			return true
	return false


# =========================
# RAFRAÎCHISSEMENT
# =========================
func _refresh_ui() -> void:
	if _ship == null or not is_instance_valid(_ship):
		return

	# Solde poissons
	_fish_label.text = "Poissons disponibles : %d 🐟" % _ship.nourriture

	# ── Slots équipage ──
	var crew: Array = _ship.equipage
	for i in range(MAX_CREW):
		var slot: Dictionary = _slot_panels[i]
		var icon_lbl: Label  = slot["icon"]
		var name_lbl: Label  = slot["name_lbl"]
		var fire_btn: Button = slot["fire_btn"]

		if i < crew.size():
			var member: CrewMember = crew[i]
			icon_lbl.text = member.get_icon()
			name_lbl.text = member.nom
			# Le capitaine (slot 0) ne peut pas être congédié
			fire_btn.visible = (member.role != CrewMember.Role.CAPITAINE)
		else:
			icon_lbl.text = "➕"
			name_lbl.text = "Slot libre"
			fire_btn.visible = false

	# ── Synergies actives ──
	var synergies := _ship.get_active_synergies()
	if synergies.is_empty():
		_synergy_label.text = "Aucune synergie active"
		_synergy_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	else:
		_synergy_label.text = "✨ " + "  |  ".join(synergies)
		_synergy_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))

	# ── Boutons recruter ──
	var crew_full: bool = _ship.equipage.size() >= MAX_CREW
	var fish_count: int = _ship.nourriture

	var btn_idx = 0
	for role in HIREABLE_ROLES:
		var hbox: HBoxContainer = _available_container.get_child(btn_idx)
		var hire_btn: Button = hbox.get_node("HireBtn_%d" % role)
		var cost_lbl: Label  = hbox.get_node("CostLabel")
		var info_lbl: Label  = hbox.get_child(0)

		# Coût réel après éventuelle réduction Diplomate
		var real_cost: int = _ship.get_hire_cost(role)
		var base_cost: int = CrewMember.ROLE_COSTS[role]
		cost_lbl.text = "%d 🐟" % real_cost
		if real_cost < base_cost:
			cost_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
		else:
			cost_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))

		var can_afford: bool = fish_count >= real_cost

		# Vérifier si la limite de ce rôle est atteinte
		var role_limit: int = ROLE_MAX.get(role, -1)  # -1 = pas de limite
		var role_count: int = 0
		if role_limit > 0:
			for m in _ship.equipage:
				if m.role == role:
					role_count += 1
		var limit_reached: bool = (role_limit > 0 and role_count >= role_limit)

		hire_btn.disabled = crew_full or not can_afford or limit_reached
		info_lbl.add_theme_color_override("font_color", Color.WHITE)
		hire_btn.text = "Max atteint" if limit_reached else "Recruter"

		btn_idx += 1

	# Si le panel synergies est ouvert, le reconstruire pour refléter l'état actuel
	# (une synergie peut s'être activée/désactivée suite au recrutement/congédiement)
	if _synergy_panel != null and is_instance_valid(_synergy_panel):
		_synergy_panel.queue_free()
		_synergy_panel = null
		_on_synergy_info_pressed()


# =========================
# CALLBACKS
# =========================
func _on_hire_pressed(role: CrewMember.Role) -> void:
	if _ship == null or not is_instance_valid(_ship):
		return

	var member = CrewMember.new(role)
	var real_cost: int = _ship.get_hire_cost(role)

	if _ship.nourriture < real_cost:
		_show_feedback("❌ Pas assez de poissons ! (besoin : %d 🐟)" % real_cost, Color(1, 0.3, 0.3))
		return

	if _ship.equipage.size() >= MAX_CREW:
		_show_feedback("❌ L'équipage est complet ! (max %d)" % MAX_CREW, Color(1, 0.3, 0.3))
		return

	# Transaction
	_ship.nourriture -= real_cost
	_ship.add_crew_member(member)
	crew_hired.emit(_ship, member)

	# Mettre à jour le fog immédiatement si le membre apporte un bonus de vision
	if member.bonus_vision > 0:
		var fog_manager = _ship.get_tree().get_first_node_in_group("fog_manager")
		if fog_manager:
			fog_manager.force_update()

	_show_feedback("✅ %s recruté(e) pour %d 🐟 !" % [member.nom, real_cost], Color(0.4, 1.0, 0.5))
	DEBUG.log("UI_recrutement — %s recruté(e) sur navire [%d] (-%d 🐟)" % [member.nom, _ship.id, real_cost])
	_refresh_ui()


func _on_fire_crew(slot_index: int) -> void:
	if _ship == null or not is_instance_valid(_ship):
		return
	if slot_index <= 0 or slot_index >= _ship.equipage.size():
		return

	var member: CrewMember = _ship.equipage[slot_index]
	_ship.remove_crew_member(slot_index)

	# Mettre à jour le fog si on congédie un membre avec bonus de vision
	if member.bonus_vision > 0:
		var fog_manager = _ship.get_tree().get_first_node_in_group("fog_manager")
		if fog_manager:
			fog_manager.force_update()

	_show_feedback("👋 %s a quitté l'équipage." % member.nom, Color(1.0, 0.8, 0.4))
	DEBUG.log("UI_recrutement — %s congédié du navire [%d]" % [member.nom, _ship.id])
	_refresh_ui()


func _on_close_pressed() -> void:
	recrutement_closed.emit()
	queue_free()


# =========================
# FEEDBACK
# =========================
func _show_feedback(msg: String, color: Color = Color.WHITE) -> void:
	_feedback_label.text = msg
	_feedback_label.add_theme_color_override("font_color", color)
	_feedback_label.visible = true
	_feedback_timer.start()


# =========================
# UTILITAIRES
# =========================
func _separator() -> HSeparator:
	return HSeparator.new()
