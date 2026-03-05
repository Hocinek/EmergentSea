extends Node

const SAVE_PATH := "user://controls.cfg"

func _ready() -> void:
	# On charge la configuration directement
	#TranslationServer.set_locale("fr")
	load_all_binds()

func load_all_binds() -> void:
	var cfg := ConfigFile.new()
	
	# Vérifie que la config existe, si elle n'existe pas, on ne va pas tenter de la charger
	if cfg.load(SAVE_PATH) != OK:
		return

	# On vérifie que la section "binds" existe bien dans le fichier
	if not cfg.has_section("binds"):
		return

	# On récupère automatiquement tous les noms d'actions sauvegardées
	for action_name in cfg.get_section_keys("binds"):
		if not InputMap.has_action(action_name):
			continue

		var saved: Dictionary = cfg.get_value("binds", action_name, {})
		if saved.is_empty():
			continue

		# On nettoie SEULEMENT les événements claviers existants pour cette action
		for e in InputMap.action_get_events(action_name):
			if e is InputEventKey:
				InputMap.action_erase_event(action_name, e)

		# On crée la nouvelle touche (avec "as Key" pour éviter le fameux warning)
		var ev := InputEventKey.new()
		ev.keycode = saved.get("keycode", 0) as Key
		ev.physical_keycode = saved.get("physical_keycode", 0) as Key
		ev.ctrl_pressed = bool(saved.get("ctrl", false))
		ev.alt_pressed = bool(saved.get("alt", false))
		ev.shift_pressed = bool(saved.get("shift", false))
		ev.meta_pressed = bool(saved.get("meta", false))

		InputMap.action_add_event(action_name, ev)

func save_binds(actions_to_save: Array[StringName]) -> void:
	var cfg := ConfigFile.new()

	for a in actions_to_save:
		if not InputMap.has_action(a):
			continue

		for e in InputMap.action_get_events(a):
			if e is InputEventKey:
				var k := e as InputEventKey
				cfg.set_value("binds", String(a), {
					"keycode": int(k.keycode),
					"physical_keycode": int(k.physical_keycode),
					"ctrl": k.ctrl_pressed,
					"alt": k.alt_pressed,
					"shift": k.shift_pressed,
					"meta": k.meta_pressed
				})
				break

	cfg.save(SAVE_PATH)

func reset_to_defaults(actions_to_reset: Array[StringName]) -> void:
		
	# On vide l'InputMap actuelle pour remettre les touches par défaut du projet
	InputMap.load_from_project_settings()
	save_binds(actions_to_reset)
