class_name Drawable
extends Node2D

# =========================
# FLÈCHE DE DÉPLACEMENT
# =========================
static var arrow_color: Color = Color(1, 1, 0, 1.0)
static var arrow_outline_color: Color = Color(0, 0, 0, 1.0)
static var arrow_width: float = 12.0
static var arrow_head_size: float = 60.0
static var arrow_height: float = 100.0


# =========================
# SÉLECTION VISUELLE
# =========================
static var selection_color: Color = Color(0, 1, 0, 0.7)  # Vert
static var selection_thickness: float = 4.0
static var selection_radius: float = 50.0

var obj : Node

func _init(obj_par:Node):
	obj = obj_par

func arrow(target : Vector2):
	var distance = target.length()
	if distance < 10:
		return
	
	var pulse = sin(Time.get_ticks_msec() * 0.005) * 0.2 + 1.0
	var offset_y = -80 + sin(Time.get_ticks_msec() * 0.003) * 15
	
	var arrow_base = target + Vector2(0, offset_y - arrow_height)
	var arrow_tip = target + Vector2(0, offset_y)
	
	# Contour noir
	obj.draw_line(arrow_base, arrow_tip, arrow_outline_color, arrow_width + 8)
	
	var outline_size = arrow_head_size + 8
	var left_outline = arrow_tip + Vector2(-outline_size * 0.5, -outline_size * 0.7)
	var right_outline = arrow_tip + Vector2(outline_size * 0.5, -outline_size * 0.7)
	var outline_points = PackedVector2Array([arrow_tip, left_outline, right_outline])
	obj.draw_colored_polygon(outline_points, arrow_outline_color)
	
	# Flèche principale
	obj.draw_line(arrow_base, arrow_tip, arrow_color, arrow_width * pulse)
	
	var head_size = arrow_head_size * pulse
	var left_point = arrow_tip + Vector2(-head_size * 0.5, -head_size * 0.7)
	var right_point = arrow_tip + Vector2(head_size * 0.5, -head_size * 0.7)
	var points = PackedVector2Array([arrow_tip, left_point, right_point])
	obj.draw_colored_polygon(points, arrow_color)
	
	# Cercle lumineux
	var glow_color = Color(arrow_color.r, arrow_color.g, arrow_color.b, 0.3)
	obj.draw_circle(arrow_base, 16 * pulse, glow_color)
	obj.draw_circle(arrow_base, 8, arrow_color)

func selection_circle():
	var pulse = sin(Time.get_ticks_msec() * 0.003) * 5.0
	var current_radius = selection_radius + pulse
	obj.draw_arc(Vector2.ZERO, current_radius, 0, TAU, 32, Color.BLACK, selection_thickness + 2)
	obj.draw_arc(Vector2.ZERO, current_radius, 0, TAU, 32, selection_color, selection_thickness)
	var glow_alpha = (sin(Time.get_ticks_msec() * 0.004) * 0.15) + 0.2
	var glow_color = Color(selection_color.r, selection_color.g, selection_color.b, glow_alpha)
	var glow_layers = 1
	var base_offset = 125.0
	var base_thickness =75
	for i in glow_layers:
		var t = float(i) / glow_layers
		obj.draw_arc(Vector2.ZERO, current_radius + base_offset + t * base_offset * 4.0, 0, TAU, 32, glow_color, base_thickness)
