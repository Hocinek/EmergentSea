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

func arrow(target : Vector2, scale_factor:float):
	var arrow_scale = sqrt(scale_factor)  
	var distance = target.length()
	if distance < 10:
		return
	
	var pulse = sin(Time.get_ticks_msec() * 0.005) * 0.2 + 1.0
	var offset_y = (-80.0 + sin(Time.get_ticks_msec() * 0.003) * 15.0) * arrow_scale
	var arrow_base = target + Vector2(0, offset_y - arrow_height * arrow_scale)
	var arrow_tip  = target + Vector2(0, offset_y)
	
	# Contour noir
	obj.draw_line(arrow_base, arrow_tip, arrow_outline_color, (arrow_width + 8) * arrow_scale)
	var outline_size = (arrow_head_size + 8) * arrow_scale
	var left_outline  = arrow_tip + Vector2(-outline_size * 0.5, -outline_size * 0.7)
	var right_outline = arrow_tip + Vector2( outline_size * 0.5, -outline_size * 0.7)
	obj.draw_colored_polygon(PackedVector2Array([arrow_tip, left_outline, right_outline]), arrow_outline_color)

	# Flèche principale
	obj.draw_line(arrow_base, arrow_tip, arrow_color, arrow_width * pulse * arrow_scale)
	var head_size   = arrow_head_size * pulse * arrow_scale
	var left_point  = arrow_tip + Vector2(-head_size * 0.5, -head_size * 0.7)
	var right_point = arrow_tip + Vector2( head_size * 0.5, -head_size * 0.7)
	obj.draw_colored_polygon(PackedVector2Array([arrow_tip, left_point, right_point]), arrow_color)
	
	# Cercle lumineux
	var glow_color = Color(arrow_color.r, arrow_color.g, arrow_color.b, 0.3)
	obj.draw_circle(arrow_base, 16.0 * pulse * arrow_scale, glow_color)
	obj.draw_circle(arrow_base, 8.0 * arrow_scale, arrow_color)

func selection_circle(scale_factor:float):
	var pulse = sin(Time.get_ticks_msec() * 0.003) * 5.0 * scale_factor
	var current_radius = selection_radius + pulse
	obj.draw_arc(Vector2.ZERO, current_radius, 0, TAU, 32, Color.BLACK, (selection_thickness + 2) * scale_factor)
	obj.draw_arc(Vector2.ZERO, current_radius, 0, TAU, 32, selection_color, selection_thickness * scale_factor)
	var glow_alpha = (sin(Time.get_ticks_msec() * 0.004) * 0.15) + 0.2
	var glow_color = Color(selection_color.r, selection_color.g, selection_color.b, glow_alpha)
	var base_offset = 80.0 * scale_factor
	var base_thickness = 80.0 * scale_factor
	obj.draw_arc(Vector2.ZERO, current_radius + base_offset, 0, TAU, 32, glow_color, base_thickness)
	
