###===================================================================###
##							Script de Caméra						   ##
# Ce script permet de controller la caméra du joueur					#
# Parmi les fonctions proposées, il y a :								#
#  - la possibilité de déplacer la caméra dans la direction voulue		#
#  - il est possible de zoomer et dézoomer								#
#  - on peut déplacer la caméra à un point voulu						#
#  - click and drag (clic molette ou clic droit maintenu)				#
##																	   ##
###===================================================================###
extends Camera2D

@export var speed := 8000.0
@export var min_zoom := 0.1
@export var max_zoom := 2.0
@export var zoom_step := 0.15
@export var border_margin_height := Map_data.TILE_HEIGHT * 1.5  #La marge de dépassement de la carte
@export var border_margin_width := Map_data.TILE_WIDTH * 1.5

@export_group("Edge Scrolling")
@export var edge_scroll_enabled := true
## Épaisseur de la zone de détection en pixels (depuis le bord de la fenêtre)
@export var edge_margin := 40
## Vitesse du déplacement par les bords (multiplicateur de speed)
@export var edge_speed_factor := 0.6

@export_group("Click and Drag")
## Active/désactive le déplacement par glissement
@export var drag_enabled := true
## Bouton utilisé pour le drag (MIDDLE = molette, RIGHT = clic droit)
@export var drag_button := MOUSE_BUTTON_MIDDLE

var target_zoom := Vector2.ONE
var follow_target: Node2D
var follow_once := true

# Limites de la map en pixels 
var map_rect := Rect2()

# Click and drag
var _is_dragging := false
var _drag_start_mouse_pos := Vector2.ZERO
var _drag_start_cam_pos := Vector2.ZERO

func _enter_tree():
	add_to_group("camera_controller")

func _ready():
	make_current()
	_compute_map_rect()

## Calcule du rectangle de la carte pour définir les limites
func _compute_map_rect():
	var top_left = Map_utils.hex_to_pixel_iso(0, 0)
	var bot_right = Map_utils.hex_to_pixel_iso(Map_data.map_width - 1, Map_data.map_height - 1)
	bot_right += Vector2(Map_data.hex_width * 0.5, Map_data.hex_height)
	map_rect = Rect2(top_left, bot_right - top_left)

func _input(event):
	# Zoom molette
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom += Vector2(zoom_step, zoom_step)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom -= Vector2(zoom_step, zoom_step)
		# On empêche de dézoomer au point de sortir complètement de la map
		var min_zoom_allowed = _get_min_zoom_for_map()
		target_zoom = target_zoom.clamp(
			Vector2(min_zoom_allowed, min_zoom_allowed),
			Vector2(max_zoom, max_zoom)
		)

	# Click and drag — début / fin
	if drag_enabled and event is InputEventMouseButton:
		if event.button_index == drag_button:
			if event.pressed:
				_is_dragging = true
				_drag_start_mouse_pos = get_viewport().get_mouse_position()
				_drag_start_cam_pos = global_position
			else:
				_is_dragging = false

	# Click and drag — mouvement
	if drag_enabled and _is_dragging and event is InputEventMouseMotion:
		var delta_mouse := get_viewport().get_mouse_position() - _drag_start_mouse_pos
		# On divise par le zoom pour que la vitesse soit cohérente quel que soit le niveau de zoom
		global_position = _drag_start_cam_pos - delta_mouse / zoom
		_clamp_camera_to_map()
		get_viewport().set_input_as_handled()

## Calcule le zoom minimum pour que la map couvre toujours l'écran
func _get_min_zoom_for_map() -> float:
	var viewport_size = get_viewport_rect().size
	var zoom_x = viewport_size.x / map_rect.size.x
	var zoom_y = viewport_size.y / map_rect.size.y
	var computed_min = max(zoom_x, zoom_y)
	return max(min_zoom, computed_min)

## Contraint la caméra dans les limites de la map avec un léger dépassement autorisé
func _clamp_camera_to_map():
	var viewport_size = get_viewport_rect().size
	var half_view = viewport_size * 0.5 / zoom
	var min_x = map_rect.position.x + half_view.x - border_margin_width*1.75
	var max_x = map_rect.end.x      - half_view.x + border_margin_width
	var min_y = map_rect.position.y + half_view.y - border_margin_height*2
	var max_y = map_rect.end.y      - half_view.y + border_margin_height

	# Si la map est plus petite que la vue, on centre
	if min_x > max_x:
		global_position.x = map_rect.position.x + map_rect.size.x * 0.5
	else:
		global_position.x = clamp(global_position.x, min_x, max_x)
	if min_y > max_y:
		global_position.y = map_rect.position.y + map_rect.size.y * 0.5
	else:
		global_position.y = clamp(global_position.y, min_y, max_y)

## Retourne un vecteur de déplacement selon la position de la souris près des bords
func _get_edge_scroll_vector(delta: float) -> Vector2:
	if not edge_scroll_enabled:
		return Vector2.ZERO
	# Désactiver si la fenêtre n'a pas le focus (évite les glissements involontaires)
	if not get_viewport().has_focus():
		return Vector2.ZERO

	var mouse_pos = get_viewport().get_mouse_position()
	var screen_size = get_viewport_rect().size
	var move := Vector2.ZERO
	var edge_speed = speed * edge_speed_factor * delta

# rapport 1/8 pour diminuer la vitesse de déplacement de la caméra, en dessous c'est très rapide comme mouvements.
	if mouse_pos.x <= edge_margin:
		# Facteur entre 0 et 1 selon la proximité du bord
		move.x -= edge_speed * (1.0 - mouse_pos.x / edge_margin)/8
	elif mouse_pos.x >= screen_size.x - edge_margin:
		move.x += edge_speed * (1.0 - (screen_size.x - mouse_pos.x) / edge_margin)/8

	if mouse_pos.y <= edge_margin:
		move.y -= edge_speed * (1.0 - mouse_pos.y / edge_margin)/8
	elif mouse_pos.y >= screen_size.y - edge_margin:
		move.y += edge_speed * (1.0 - (screen_size.y - mouse_pos.y) / edge_margin)/8

	return move

func set_target(target: Node2D):
	follow_target = target
	global_position = target.global_position  # caméra centrée au démarrage

func _process(delta):
	# Zoom fluide
	zoom = zoom.lerp(target_zoom, 0.2)

	# Si on doit suivre le navire au tout début
	if follow_once and follow_target:
		global_position = follow_target.global_position
		follow_once = false  # ensuite on arrête de suivre
		_clamp_camera_to_map()
		return

	# Pas de déplacement clavier/edge scrolling pendant un drag
	if _is_dragging:
		return

	# Déplacement libre
	var move := Vector2.ZERO
	if Input.is_action_pressed("ui_up"):    move.y -= speed * delta
	if Input.is_action_pressed("ui_down"):  move.y += speed * delta
	if Input.is_action_pressed("ui_left"):  move.x -= speed * delta
	if Input.is_action_pressed("ui_right"): move.x += speed * delta

	# Déplacement edge scrolling
	move += _get_edge_scroll_vector(delta)
	
	global_position += move

	# Restriction de la caméra sur la map
	_clamp_camera_to_map()
