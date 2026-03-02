class_name UI_fish_navires
extends Node

var fish_feedback_label: Label
var fish_feedback_duration: float = 0.8
var fish_feedback_timer: float = 0.0

var visibility : bool = false

var navire : Navires

func _init(ship : Navires) -> void:
	self.navire = ship
	navire.add_child(self)
	navire.sig_show_fishing.connect(handler)
	build_ui()

func isVisible() -> bool:
	return visibility

func _process(delta):
	if fish_feedback_timer > 0:
		fish_feedback_timer -= delta
		if fish_feedback_timer <= 0.0:
			hide()

func build_ui():
	fish_feedback_label = Label.new()
	fish_feedback_label.visible = false
	fish_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Apparence simple
	fish_feedback_label.add_theme_color_override("font_color", Color.WHITE)
	fish_feedback_label.add_theme_color_override("font_outline_color", Color.BLACK)
	fish_feedback_label.add_theme_constant_override("outline_size", 6)
	
	# position au-dessus du bateau (ajuste si besoin)
	fish_feedback_label.position = Vector2(-30, -60)
	navire.add_child(fish_feedback_label)
	
func handler():
	if isVisible():
		hide()
	else:
		show()

func finished_fishing(gain:int):
	# Si on vient de finir, on affiche "+X 🐟" pendant fish_feedback_duration
	fish_feedback_label.text = "+%d 🐟" % gain
	fish_feedback_timer = fish_feedback_duration

func show():
	if not fish_feedback_label:
		push_warning("ATTENTION : fish_feedback_label pour afficher la pêche !")
		return
		
	fish_feedback_label.text = "🎣 Pêche..."
	visibility = true
	
	fish_feedback_label.visible = true

func hide():
	if not fish_feedback_label:
		return
	
	fish_feedback_label.visible = false
	visibility = false
	fish_feedback_timer = 0
