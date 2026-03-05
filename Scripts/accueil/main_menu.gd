extends Control

const SOLO_SCENE_PATH := "res://Scenes/in_game/Main.tscn"

# Configuration : seules les actions commençant par ceci seront affichées
@export var action_prefix := "input_"
@export var allowed_actions: Array[StringName] = [
	&"ui_up",
	&"ui_down",
	&"ui_left",
	&"ui_right"
]

# UI state
var waiting_action: StringName = &""

# Screens
var screen_main: Control
var screen_options: Control
var screen_controls: Control

# Controls screen refs
var hint_label: Label
var actions_box: VBoxContainer


# =========================================================
# Lifecycle
# =========================================================

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_show_main()


# =========================================================
# UI BUILD
# =========================================================

func _build_ui() -> void:
	for c in get_children():
		c.queue_free()

	# Background
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.043, 0.063, 0.125)
	add_child(bg)

	screen_main = _make_main_screen()
	screen_options = _make_options_screen()
	screen_controls = _make_controls_screen()

	add_child(screen_main)
	add_child(screen_options)
	add_child(screen_controls)


func _make_panel(title_text: String) -> Dictionary:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)

	v.add_child(title)
	panel.add_child(v)
	center.add_child(panel)

	return { "root": center, "vbox": v }


func _make_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	return b


# =========================================================
# SCREENS
# =========================================================

func _make_main_screen() -> Control:
	var d := _make_panel("EmergentSea")
	var v: VBoxContainer = d["vbox"]

	var btn_solo := _make_button("Solo")
	var btn_multi := _make_button("Multijoueur")
	var btn_options := _make_button("Options")
	var btn_quit := _make_button("Quitter")

	btn_solo.pressed.connect(_on_solo_pressed)
	btn_options.pressed.connect(_show_options)
	btn_quit.pressed.connect(func(): get_tree().quit())

	btn_multi.pressed.connect(func():
		btn_multi.text = "Multijoueur (bientôt)"
		btn_multi.disabled = true
	)

	v.add_child(btn_solo)
	v.add_child(btn_multi)
	v.add_child(btn_options)
	v.add_child(btn_quit)

	var wrapper := Control.new()
	wrapper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrapper.add_child(d["root"])
	return wrapper


func _make_options_screen() -> Control:
	var d := _make_panel("Options")
	var v: VBoxContainer = d["vbox"]

	var btn_controls := _make_button("Contrôles")
	var btn_back := _make_button("Retour")

	btn_controls.pressed.connect(_show_controls)
	btn_back.pressed.connect(_show_main)

	v.add_child(btn_controls)
	v.add_child(btn_back)

	var wrapper := Control.new()
	wrapper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrapper.visible = false
	wrapper.add_child(d["root"])
	return wrapper


func _make_controls_screen() -> Control:
	var d := _make_panel("Contrôles")
	var v: VBoxContainer = d["vbox"]

	hint_label = Label.new()
	hint_label.text = "Clique sur “Changer”, puis appuie sur une touche. (Échap = annuler)"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 300)
	v.add_child(scroll)

	actions_box = VBoxContainer.new()
	actions_box.add_theme_constant_override("separation", 10)
	actions_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(actions_box)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	v.add_child(h)

	var btn_reset := _make_button("Reset")
	var btn_back := _make_button("Retour")

	btn_reset.pressed.connect(_on_reset_pressed)
	btn_back.pressed.connect(_show_options)

	h.add_child(btn_reset)
	h.add_child(btn_back)

	_rebuild_actions_ui()

	var wrapper := Control.new()
	wrapper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrapper.visible = false
	wrapper.add_child(d["root"])
	return wrapper


# =========================================================
# NAVIGATION
# =========================================================

func _set_visible_screen(active: Control) -> void:
	screen_main.visible = active == screen_main
	screen_options.visible = active == screen_options
	screen_controls.visible = active == screen_controls


func _show_main() -> void:
	waiting_action = &""
	_set_visible_screen(screen_main)


func _show_options() -> void:
	waiting_action = &""
	_set_visible_screen(screen_options)


func _show_controls() -> void:
	waiting_action = &""
	_rebuild_actions_ui()
	_set_visible_screen(screen_controls)


# =========================================================
# ACTIONS
# =========================================================

func _on_solo_pressed() -> void:
	get_tree().change_scene_to_file(SOLO_SCENE_PATH)


func _on_reset_pressed() -> void:
	key_config_manager.reset_to_defaults(_get_rebindable_actions())
	_rebuild_actions_ui()


# =========================================================
# REBIND UI
# =========================================================

## Récupère dynamiquement les actions depuis l'InputMap du projet
func _get_rebindable_actions() -> Array[StringName]:
	var list: Array[StringName] = []
	for action in allowed_actions:
		if InputMap.has_action(action):
			list.append(action)
	for action in InputMap.get_actions():
		if String(action).begins_with(action_prefix):
			list.append(action)
	return list

func _rebuild_actions_ui() -> void:
	if actions_box == null:
		return

	for c in actions_box.get_children():
		c.queue_free()

	for a in _get_rebindable_actions():
		if not InputMap.has_action(a):
			continue

		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var lbl := Label.new()
		lbl.text = _pretty_action(a)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var key_lbl := Label.new()
		key_lbl.text = _keys_text(a)
		key_lbl.custom_minimum_size = Vector2(220, 0)

		var btn := _make_button(tr("BTN_REBIND") if tr("BTN_REBIND") != "BTN_REBIND" else "Changer")
		btn.pressed.connect(func():
			waiting_action = a
			hint_label.text = "Appuie sur une touche pour : %s (Échap = annuler)" % _pretty_action(a)
		)

		row.add_child(lbl)
		row.add_child(key_lbl)
		row.add_child(btn)
		actions_box.add_child(row)


func _unhandled_input(event: InputEvent) -> void:
	if waiting_action == &"":
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_cancel_waiting()
			return

		_apply_new_bind(waiting_action, event)
		key_config_manager.save_binds(_get_rebindable_actions())
		
		_cancel_waiting()
		_rebuild_actions_ui()

func _apply_new_bind(action_name: StringName, event: InputEventKey) -> void:
	# Supprimer l'ancienne touche
	for e in InputMap.action_get_events(action_name):
		if e is InputEventKey:
			InputMap.action_erase_event(action_name, e)
	
	# Créer le nouvel événement
	var new_ev := InputEventKey.new()
	new_ev.keycode = event.keycode
	new_ev.physical_keycode = event.physical_keycode
	new_ev.ctrl_pressed = event.ctrl_pressed
	new_ev.alt_pressed = event.alt_pressed
	new_ev.shift_pressed = event.shift_pressed
	new_ev.meta_pressed = event.meta_pressed # utile pour Mac
	
	InputMap.action_add_event(action_name, new_ev)


func _cancel_waiting() -> void:
	waiting_action = &""
	hint_label.text = "Clique sur “Changer”, puis appuie sur une touche. (Échap = annuler)"

## Traduction et formatage dynamique
func _pretty_action(a: StringName) -> String:
	var key_str = String(a).to_upper()
	var translated = tr(key_str)
	var clean_str : String
	
	if translated == key_str:
		clean_str = String(a).trim_prefix(action_prefix)
		var tmp = tr(clean_str.to_upper())
		if(tmp!=translated):
			translated = tmp
		else :
			if clean_str.begins_with("ui_"):
				clean_str = clean_str.trim_prefix("ui_")
			# Fallback si pas de traduction : "input_fish" -> "Fish" ou "ui_up" -> "Ui Up"
			translated = clean_str.replace("_", " ").capitalize()
		
	return translated

func _keys_text(action_name: StringName) -> String:
	var keys: Array[String] = []
	for e in InputMap.action_get_events(action_name):
		if e is InputEventKey:
			var k := e as InputEventKey
			# On récupère le code non-nul (priorité au physique si le logique est à 0)
			var code = k.keycode if k.keycode != 0 else k.physical_keycode
			if code != 0:
				keys.append(OS.get_keycode_string(code))
	return "-" if keys.is_empty() else ", ".join(keys)
