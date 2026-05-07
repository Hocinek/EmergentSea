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
var _feedback_label: Label
var _feedback_timer: Timer

# Slots visuels de l'équipage (4 slots)
# Chaque entrée est un dictionnaire { panel, icon, name_lbl, fire_btn }
var _slot_panels: Array = []

# Membres disponibles à l'achat (tous les rôles sauf capitaine)
const HIREABLE_ROLES: Array = [
	CrewMember.Role.CANONNIER,
	CrewMember.Role.NAVIGATEUR,
	CrewMember.Role.MEDECIN,
	CrewMember.Role.PECHEUR,
]

const MAX_CREW: int = 4  # Capitaine + 3 membres


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
	_panel.custom_minimum_size = Vector2(580, 640)
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
		slot_panel.custom_minimum_size = Vector2(120, 110)

		var slot_vbox = VBoxContainer.new()
		slot_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		slot_vbox.add_theme_constant_override("separation", 4)
		slot_panel.add_child(slot_vbox)

		var slot_icon = Label.new()
		slot_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_icon.add_theme_font_size_override("font_size", 28)
		slot_icon.name = "SlotIcon"
		slot_vbox.add_child(slot_icon)

		var slot_name = Label.new()
		slot_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_name.add_theme_font_size_override("font_size", 11)
		slot_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		slot_name.name = "SlotName"
		slot_vbox.add_child(slot_name)

		# Bouton congédier (masqué pour capitaine et slots vides)
		var fire_btn = Button.new()
		fire_btn.text = "Congédier"
		fire_btn.add_theme_font_size_override("font_size", 10)
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

		# Coût
		var cost_label = Label.new()
		cost_label.text = "%d 🐟" % member_proto.cost
		cost_label.add_theme_font_size_override("font_size", 13)
		cost_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		cost_label.custom_minimum_size = Vector2(60, 0)
		cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
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

	# ── Boutons recruter ──
	var crew_full: bool = _ship.equipage.size() >= MAX_CREW
	var fish_count: int = _ship.nourriture

	var btn_idx = 0
	for role in HIREABLE_ROLES:
		var hbox: HBoxContainer = _available_container.get_child(btn_idx)
		var hire_btn: Button = hbox.get_node("HireBtn_%d" % role)
		var cost: int = CrewMember.ROLE_COSTS[role]

		var already_in_crew: bool = _ship.has_crew_role(role)
		var can_afford: bool = fish_count >= cost

		hire_btn.disabled = crew_full or not can_afford or already_in_crew

		# Indication visuelle si déjà recruté
		var info_lbl: Label = hbox.get_child(0)
		if already_in_crew:
			info_lbl.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
			hire_btn.text = "✅ Recruté"
		else:
			info_lbl.add_theme_color_override("font_color", Color.WHITE)
			hire_btn.text = "Recruter"

		btn_idx += 1


# =========================
# CALLBACKS
# =========================
func _on_hire_pressed(role: CrewMember.Role) -> void:
	if _ship == null or not is_instance_valid(_ship):
		return

	var member = CrewMember.new(role)

	if _ship.nourriture < member.cost:
		_show_feedback("❌ Pas assez de poissons ! (besoin : %d 🐟)" % member.cost, Color(1, 0.3, 0.3))
		return

	if _ship.equipage.size() >= MAX_CREW:
		_show_feedback("❌ L'équipage est complet ! (max %d)" % MAX_CREW, Color(1, 0.3, 0.3))
		return

	if _ship.has_crew_role(role):
		_show_feedback("❌ Ce rôle est déjà occupé !", Color(1, 0.5, 0.3))
		return

	# Transaction
	_ship.nourriture -= member.cost
	_ship.add_crew_member(member)
	crew_hired.emit(_ship, member)

	_show_feedback("✅ %s recruté(e) pour %d 🐟 !" % [member.nom, member.cost], Color(0.4, 1.0, 0.5))
	DEBUG.log("UI_recrutement — %s recruté(e) sur navire [%d] (-{cost} 🐟)" % [member.nom, _ship.id])
	_refresh_ui()


func _on_fire_crew(slot_index: int) -> void:
	if _ship == null or not is_instance_valid(_ship):
		return
	if slot_index <= 0 or slot_index >= _ship.equipage.size():
		return

	var member: CrewMember = _ship.equipage[slot_index]
	_ship.remove_crew_member(slot_index)
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
