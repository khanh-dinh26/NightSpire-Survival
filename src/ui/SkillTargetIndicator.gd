class_name SkillTargetIndicator
extends Node2D
## Dynamic world-space visual indicator for aiming skills (e.g. Magic Cocktail AOE blast radius, Marking Dash vector).

var skill_type: String = "magic_cocktail"
var player: CharacterBody2D = null
var aoe_radius: float = 140.0
var _pulse_timer: float = 0.0


func _process(delta: float) -> void:
	_pulse_timer += delta * 4.0
	global_position = get_global_mouse_position()
	queue_redraw()


func _draw() -> void:
	if skill_type == "magic_cocktail":
		_draw_magic_cocktail_indicator()
	elif skill_type == "marking_dash":
		_draw_marking_dash_indicator()


func _draw_magic_cocktail_indicator() -> void:
	var pulse: float = sin(_pulse_timer) * 2.0
	var current_rad: float = aoe_radius + pulse

	# Translucent orange/purple filled circular area
	draw_circle(Vector2.ZERO, current_rad, Color(1.0, 0.45, 0.12, 0.16))

	# Bright glowing outer boundary showing the EXACT blast radius
	draw_arc(Vector2.ZERO, current_rad, 0, TAU, 64, Color(1.0, 0.72, 0.2, 0.85), 2.5)

	# Inner concentric ring
	draw_arc(Vector2.ZERO, current_rad * 0.5, 0, TAU, 48, Color(1.0, 0.5, 0.1, 0.35), 1.5)

	# Center crosshairs
	draw_line(Vector2(-14, 0), Vector2(14, 0), Color(1.0, 0.95, 0.4, 0.9), 2.0)
	draw_line(Vector2(0, -14), Vector2(0, 14), Color(1.0, 0.95, 0.4, 0.9), 2.0)

	# 4 compass tick marks on perimeter
	draw_line(Vector2(0, -current_rad - 6), Vector2(0, -current_rad + 6), Color(1.0, 0.9, 0.3, 0.95), 2.5)
	draw_line(Vector2(0, current_rad - 6), Vector2(0, current_rad + 6), Color(1.0, 0.9, 0.3, 0.95), 2.5)
	draw_line(Vector2(-current_rad - 6, 0), Vector2(-current_rad + 6, 0), Color(1.0, 0.9, 0.3, 0.95), 2.5)
	draw_line(Vector2(current_rad - 6, 0), Vector2(current_rad + 6, 0), Color(1.0, 0.9, 0.3, 0.95), 2.5)

	# Trajectory line from player to aim point
	if player != null and is_instance_valid(player):
		var p_local: Vector2 = to_local(player.global_position)
		draw_line(p_local, Vector2.ZERO, Color(1.0, 0.65, 0.2, 0.35), 1.5)


func _draw_marking_dash_indicator() -> void:
	if player == null or not is_instance_valid(player):
		return

	var p_local: Vector2 = to_local(player.global_position)
	var aim_dir: Vector2 = (-p_local).normalized()
	if aim_dir == Vector2.ZERO:
		aim_dir = Vector2.RIGHT

	var dash_dist: float = 110.0
	var dest_local: Vector2 = p_local + aim_dir * dash_dist

	# Dash trajectory line
	draw_line(p_local, dest_local, Color(0.3, 0.8, 1.0, 0.75), 3.0)

	# Dash destination landing circle
	draw_circle(dest_local, 16.0, Color(0.2, 0.7, 1.0, 0.25))
	draw_arc(dest_local, 16.0, 0, TAU, 32, Color(0.4, 0.9, 1.0, 0.85), 2.0)

	# 5 radial arrow direction indicators (360 degrees)
	for i: int in range(5):
		var ang: float = aim_dir.angle() + float(i) * TAU / 5.0
		var ray_end: Vector2 = dest_local + Vector2.from_angle(ang) * 42.0
		draw_line(dest_local, ray_end, Color(0.6, 1.0, 1.0, 0.85), 2.0)
