class_name ArrowOverlay
extends Control

var navire: Navires = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(_delta: float) -> void:
	if navire :
		queue_redraw()

func _draw() -> void:
	if navire == null or not navire.show_arrow or not navire.is_selected:
		return

	var world_distance := navire.global_position.distance_to(navire.target_position)
	if world_distance < 10:
		return

	# Conversion monde → écran
	var xform      := navire.get_canvas_transform()
	var target_scr := xform * navire.target_position

	var cam_zoom     := navire._get_camera_zoom()
	var scale_factor := sqrt(1.0 / cam_zoom) * 2.0
	var arrow_scale  := sqrt(scale_factor)

	# ── Même calculs que Drawable.arrow(), transposés en pixels écran ──
	var pulse     := sin(Time.get_ticks_msec() * 0.005) * 0.2 + 1.0
	var offset_y  := (-80.0 + sin(Time.get_ticks_msec() * 0.003) * 15.0) * arrow_scale * cam_zoom
	var h         := Drawable.arrow_height * arrow_scale * cam_zoom

	var arrow_base := target_scr + Vector2(0, offset_y - h)
	var arrow_tip  := target_scr + Vector2(0, offset_y)

	# Contour noir
	var w_out := (Drawable.arrow_width + 8) * arrow_scale * cam_zoom
	draw_line(arrow_base, arrow_tip, Drawable.arrow_outline_color, w_out)
	var out_size := (Drawable.arrow_head_size + 8) * arrow_scale * cam_zoom
	draw_colored_polygon(PackedVector2Array([
		arrow_tip,
		arrow_tip + Vector2(-out_size * 0.5, -out_size * 0.7),
		arrow_tip + Vector2( out_size * 0.5, -out_size * 0.7)
	]), Drawable.arrow_outline_color)

	# Flèche principale
	var w_main := Drawable.arrow_width * pulse * arrow_scale * cam_zoom
	draw_line(arrow_base, arrow_tip, Drawable.arrow_color, w_main)
	var head := Drawable.arrow_head_size * pulse * arrow_scale * cam_zoom
	draw_colored_polygon(PackedVector2Array([
		arrow_tip,
		arrow_tip + Vector2(-head * 0.5, -head * 0.7),
		arrow_tip + Vector2( head * 0.5, -head * 0.7)
	]), Drawable.arrow_color)

	# Cercle lumineux
	var glow := Color(Drawable.arrow_color.r, Drawable.arrow_color.g, Drawable.arrow_color.b, 0.3)
	draw_circle(arrow_base, 16.0 * pulse * arrow_scale * cam_zoom, glow)
	draw_circle(arrow_base, 8.0 * arrow_scale * cam_zoom, Drawable.arrow_color)
