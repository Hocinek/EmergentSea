class_name Interface
extends CanvasLayer

var navire : Navires

# UI stats
var stats_panel: Panel
var vie_label: Label
var energie_label: Label
var equipage_label: Label  # NOUVEAU : Afficher l'équipage
var nourriture_label: Label
var stats_timer := 0.0
var stats_visible := false

# Feedback pêche
var fish_feedback_label: Label
@export var fish_feedback_duration: float = 0.8
var fish_feedback_timer: float = 0.0

func _enter_tree():
	# permet de rajouter des éléments sur l'interface
	add_to_group("ui_layer")

func _ready():
	navire = get_tree().get_first_node_in_group("player")
	if navire:
		# Permet de récupérer le signal plus tard pour pouvoir faire spawn les bateaux
		navire.sig_show_stats.connect(show_player_ui)
			
	else:
		push_error(">>> ERREUR : Aucun navire trouvé dans le groupe 'player' !")

func build_ui():
		
	stats_panel = Panel.new()
	stats_panel.visible = false

	stats_panel.anchor_left = 1
	stats_panel.anchor_top = 0
	stats_panel.anchor_right = 1
	stats_panel.anchor_bottom = 0
	stats_panel.offset_left = -180
	stats_panel.offset_top = 20
	stats_panel.offset_right = -20
	stats_panel.offset_bottom = 110

	var style := StyleBoxFlat.new()
	if navire.is_player_ship:
		style.bg_color = Color(0, 0.2, 0.4, 0.8)  # Bleu pour le joueur
	else:
		style.bg_color = Color(0.4, 0, 0, 0.8)  # Rouge pour l'ennemi
	
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	stats_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stats_panel.add_child(vbox)

	# Titre (JOUEUR ou ENNEMI)
	var title_label := Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if navire.is_player_ship:
		title_label.text = "🚢 JOUEUR"
		title_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1))
	else:
		title_label.text = "☠️ ENNEMI"
		title_label.add_theme_color_override("font_color", Color(1, 0.5, 0.5))
	vbox.add_child(title_label)

	vie_label = Label.new()
	energie_label = Label.new()
	nourriture_label = Label.new()
	equipage_label = Label.new()
	nourriture_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vie_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	energie_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	equipage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	vbox.add_child(vie_label)
	vbox.add_child(energie_label)

	vbox.add_child(equipage_label)

	vbox.add_child(nourriture_label)

	self.add_child(stats_panel)
	
	DEBUG.log("UI Stats créée pour navire " +str("JOUEUR" if navire.is_player_ship else "ENNEMI"))

func _init_fish_feedback() -> void:
	fish_feedback_label = Label.new()
	fish_feedback_label.visible = false
	fish_feedback_label.text = "🎣 Pêche..."
	fish_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Apparence simple
	fish_feedback_label.add_theme_color_override("font_color", Color.WHITE)
	fish_feedback_label.add_theme_color_override("font_outline_color", Color.BLACK)
	fish_feedback_label.add_theme_constant_override("outline_size", 6)

	navire.add_child(fish_feedback_label)
	# position au-dessus du bateau (ajuste si besoin)
	fish_feedback_label.position = Vector2(-30, -60)

func show_player_ui():
	pass
