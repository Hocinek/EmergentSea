extends Control

const SOLO_SCENE_PATH := "res://Scenes/in_game/Main.tscn"
const MULTI_SCENE_PATH := "res://Scenes/in_game/MainMulti.tscn"

@export var action_prefix := "input_"
@export var allowed_actions: Array[StringName] = [
	&"ui_up",
	&"ui_down",
	&"ui_left",
	&"ui_right"
]

var waiting_action: StringName = &""

var screen_main: Control
var screen_lobby: Control
var screen_options: Control
var screen_controls: Control

var hint_label: Label
var actions_box: VBoxContainer

var lobby_title_label: Label
var lobby_players_label: Label
var lobby_status_label: Label
var lobby_start_button: Button
var lobby_cancel_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_connect_network_signals()
	_build_ui()
	_show_main()


func _connect_network_signals() -> void:
	if not network_manager.join_succeeded.is_connected(_on_join_succeeded):
		network_manager.join_succeeded.connect(_on_join_succeeded)
	if not network_manager.join_failed.is_connected(_on_join_failed):
		network_manager.join_failed.connect(_on_join_failed)
	if not network_manager.peer_joined.is_connected(_on_peer_joined):
		network_manager.peer_joined.connect(_on_peer_joined)
	if not network_manager.peer_left.is_connected(_on_peer_left):
		network_manager.peer_left.connect(_on_peer_left)
	if not network_manager.host_started.is_connected(_on_host_started):
		network_manager.host_started.connect(_on_host_started)
	if not network_manager.player_count_updated.is_connected(_on_player_count_updated):
		network_manager.player_count_updated.connect(_on_player_count_updated)


func _build_ui() -> void:
	for c in get_children():
		c.queue_free()

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.043, 0.063, 0.125)
	add_child(bg)

	screen_main = _make_main_screen()
	screen_lobby = _make_lobby_screen()
	screen_options = _make_options_screen()
	screen_controls = _make_controls_screen()

	add_child(screen_main)
	add_child(screen_lobby)
	add_child(screen_options)
	add_child(screen_controls)


func _make_panel(title_text: String) -> Dictionary:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)

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


func _make_line_edit(placeholder: String, default_text: String = "") -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.text = default_text
	e.custom_minimum_size = Vector2(0, 40)
	return e


func _make_main_screen() -> Control:
	var d := _make_panel("EmergentSea")
	var v: VBoxContainer = d["vbox"]

	var btn_solo := _make_button("Solo contre IA")
	var btn_multi := _make_button("Multijoueur")
	var btn_options := _make_button("Options")
	var btn_quit := _make_button("Quitter")

	var btn_tuto := _make_button("Tutoriel")

	btn_solo.pressed.connect(_on_solo_pressed)
	btn_multi.pressed.connect(_on_multi_pressed)
	btn_tuto.pressed.connect(_on_tuto_pressed)
	btn_options.pressed.connect(_show_options)
	btn_quit.pressed.connect(func(): get_tree().quit())

	v.add_child(btn_solo)
	v.add_child(btn_multi)
	v.add_child(btn_tuto)
	v.add_child(btn_options)
	v.add_child(btn_quit)

	var wrapper := Control.new()
	wrapper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrapper.add_child(d["root"])
	return wrapper


func _make_lobby_screen() -> Control:
	var d := _make_panel("Salon d'attente")
	var v: VBoxContainer = d["vbox"]

	lobby_title_label = Label.new()
	lobby_title_label.text = "Connexion au serveur..."
	lobby_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lobby_title_label.add_theme_font_size_override("font_size", 18)
	v.add_child(lobby_title_label)

	lobby_players_label = Label.new()
	lobby_players_label.text = "Joueurs connectés : 1"
	lobby_players_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lobby_players_label)

	lobby_status_label = Label.new()
	lobby_status_label.text = ""
	lobby_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lobby_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lobby_status_label)

	lobby_start_button = _make_button("Lancer la partie")
	lobby_start_button.disabled = true
	lobby_start_button.visible = false
	lobby_start_button.pressed.connect(_on_lobby_start_pressed)
	v.add_child(lobby_start_button)

	lobby_cancel_button = _make_button("Annuler")
	lobby_cancel_button.pressed.connect(_on_lobby_cancel_pressed)
	v.add_child(lobby_cancel_button)

	var wrapper := Control.new()
	wrapper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrapper.visible = false
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
	hint_label.text = "Clique sur « Changer », puis appuie sur une touche. (Échap = annuler)"
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


func _set_visible_screen(active: Control) -> void:
	screen_main.visible = active == screen_main
	screen_lobby.visible = active == screen_lobby
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


func _show_lobby() -> void:
	lobby_title_label.text = "Connexion au serveur en cours..."
	lobby_status_label.text = ""
	lobby_start_button.visible = false
	lobby_start_button.disabled = true
	_update_lobby_player_count()
	_set_visible_screen(screen_lobby)


func _update_lobby_player_count() -> void:
	if lobby_players_label == null:
		return
	if multiplayer.has_multiplayer_peer():
		var peers = Array(multiplayer.get_peers())
		var real_peers = peers.filter(func(p): return p != 1)
		var total: int = real_peers.size() + 1
		lobby_players_label.text = "Joueurs connectés : %d" % total
		if network_manager.is_host() and lobby_start_button != null:
			lobby_start_button.disabled = real_peers.size() < 1


func _on_solo_pressed() -> void:
	network_manager.shutdown()
	get_tree().change_scene_to_file(SOLO_SCENE_PATH)


func _on_tuto_pressed() -> void:
	network_manager.shutdown()
	tutorial_manager.is_tutorial_mode = true
	get_tree().change_scene_to_file(SOLO_SCENE_PATH)


func _on_multi_pressed() -> void:
	network_manager.shutdown()
	_show_lobby()
	network_manager.join_dedicated_server()


func _on_join_succeeded() -> void:
	if network_manager.is_host():
		lobby_title_label.text = "En attente de joueurs... (vous êtes l'hôte)"
		lobby_status_label.text = "Le bouton « Lancer » sera disponible dès qu'un joueur vous rejoint."
		lobby_start_button.visible = true
	else:
		lobby_title_label.text = "Connecté ! En attente du lancement par l'hôte..."
		lobby_status_label.text = "L'hôte va bientôt lancer la partie."
	_update_lobby_player_count()


func _on_host_started() -> void:
	lobby_title_label.text = "En attente de joueurs... (vous êtes l'hôte)"
	lobby_status_label.text = "Le bouton « Lancer » sera disponible dès qu'un joueur vous rejoint."
	lobby_start_button.visible = true
	_update_lobby_player_count()


func _on_join_failed() -> void:
	lobby_status_label.text = "Connexion échouée. Le serveur est peut-être hors ligne."


func _on_peer_joined(_peer_id: int) -> void:
	if screen_lobby.visible:
		_update_lobby_player_count()
		if network_manager.is_host():
			lobby_status_label.text = "Un joueur a rejoint ! Vous pouvez lancer la partie."


func _on_peer_left(_peer_id: int) -> void:
	if screen_lobby.visible:
		_update_lobby_player_count()


func _on_lobby_start_pressed() -> void:
	if not network_manager.is_host():
		return
	network_manager.broadcast_start_game()


func _on_lobby_cancel_pressed() -> void:
	network_manager.shutdown()
	_show_main()


func _on_player_count_updated(count: int) -> void:
	if screen_lobby.visible:
		lobby_players_label.text = "Joueurs connectés : %d" % count
		if network_manager.is_host() and lobby_start_button != null:
			lobby_start_button.disabled = count < 2


func _on_reset_pressed() -> void:
	key_config_manager.reset_to_defaults(_get_rebindable_actions())
	_rebuild_actions_ui()


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
	for e in InputMap.action_get_events(action_name):
		if e is InputEventKey:
			InputMap.action_erase_event(action_name, e)
	var new_ev := InputEventKey.new()
	new_ev.keycode = event.keycode
	new_ev.physical_keycode = event.physical_keycode
	new_ev.ctrl_pressed = event.ctrl_pressed
	new_ev.alt_pressed = event.alt_pressed
	new_ev.shift_pressed = event.shift_pressed
	new_ev.meta_pressed = event.meta_pressed
	InputMap.action_add_event(action_name, new_ev)


func _cancel_waiting() -> void:
	waiting_action = &""
	hint_label.text = "Clique sur « Changer », puis appuie sur une touche. (Échap = annuler)"


func _pretty_action(a: StringName) -> String:
	var key_str = String(a).to_upper()
	var translated = tr(key_str)
	var clean_str: String
	if translated == key_str:
		clean_str = String(a).trim_prefix(action_prefix)
		var tmp = tr(clean_str.to_upper())
		if tmp != translated:
			translated = tmp
		else:
			if clean_str.begins_with("ui_"):
				clean_str = clean_str.trim_prefix("ui_")
			translated = clean_str.replace("_", " ").capitalize()
	return translated


func _keys_text(action_name: StringName) -> String:
	var keys: Array[String] = []
	for e in InputMap.action_get_events(action_name):
		if e is InputEventKey:
			var k := e as InputEventKey
			var code = k.keycode if k.keycode != 0 else k.physical_keycode
			if code != 0:
				keys.append(OS.get_keycode_string(code))
	return "-" if keys.is_empty() else ", ".join(keys)
