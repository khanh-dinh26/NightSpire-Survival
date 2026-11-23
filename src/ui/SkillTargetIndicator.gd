class_name SkillTargetIndicator
extends Node2D
## Dynamic world-space visual indicator for aiming hero abilities:
## - Knight Leap: Ground target circle (100px) clamped to max leap range (200px) from player.
## - Ranger Spear: Piercing direction corridor (44px width) & guide arrow towards mouse.
## - Wizard Siphon: 120px aura boundary centered on player (siphons strictly inside).

var skill_type: String = "knight_leap"
var player: CharacterBody2D = null
var aoe_radius: float = 100.0
var max_leap_range: float = 200.0
var _pulse_timer: float = 0.0


func _process(delta: float) -> void:
	_pulse_timer += delta * 4.0
	if player != null and is_instance_valid(player):
		if skill_type in ["ranger_piercing_spear", "single_shot", "marking_dash", "wizard_blood_siphon", "soulblood_song"]:
			global_position = player.global_position
		else:
			# Knight leap: clamp mouse target to max_leap_range around player
			var mouse_pos: Vector2 = get_global_mouse_position()
			var offset: Vector2 = mouse_pos - player.global_position
			if offset.length() > max_leap_range:
				offset = offset.normalized() * max_leap_range
			global_position = player.global_position + offset
	else:
		global_position = get_global_mouse_position()
	queue_redraw()


func _draw() -> void:
	match skill_type:
		"knight_leap", "onslaught_stake", "magic_cocktail":
			_draw_knight_leap_indicator()
		"ranger_piercing_spear", "single_shot", "marking_dash":
			_draw_ranger_spear_indicator()
		"wizard_blood_siphon", "soulblood_song":
			_draw_wizard_siphon_indicator()
		_:
			_draw_knight_leap_indicator()


func _draw_knight_leap_indicator() -> void:
	var pulse: float = sin(_pulse_timer) * 2.0
	var current_rad: float = aoe_radius + pulse

	# Max leap range boundary circle centered around player
	if player != null and is_instance_valid(player):
		var p_local: Vector2 = to_local(player.global_position)
		draw_arc(p_local, max_leap_range, 0, TAU, 64, Color(1.0, 0.65, 0.2, 0.25), 1.5)
		draw_line(p_local, Vector2.ZERO, Color(1.0, 0.7, 0.2, 0.45), 2.0)
		draw_circle(p_local, 6.0, Color(1.0, 0.8, 0.3, 0.5))

	# Translucent fiery orange filled landing circle (100px radius)
	draw_circle(Vector2.ZERO, current_rad, Color(1.0, 0.45, 0.12, 0.22))

	# Glowing outer boundary showing exact blast radius
	draw_arc(Vector2.ZERO, current_rad, 0, TAU, 56, Color(1.0, 0.8, 0.25, 0.95), 2.5)

	# Inner concentric ring
	draw_arc(Vector2.ZERO, current_rad * 0.5, 0, TAU, 40, Color(1.0, 0.55, 0.15, 0.4), 1.5)

	# Center crosshairs
	draw_line(Vector2(-14, 0), Vector2(14, 0), Color(1.0, 0.95, 0.4, 0.95), 2.0)
	draw_line(Vector2(0, -14), Vector2(0, 14), Color(1.0, 0.95, 0.4, 0.95), 2.0)

	# 4 compass tick marks on perimeter
	draw_line(Vector2(0, -current_rad - 6), Vector2(0, -current_rad + 6), Color(1.0, 0.9, 0.3, 0.95), 2.5)
	draw_line(Vector2(0, current_rad - 6), Vector2(0, current_rad + 6), Color(1.0, 0.9, 0.3, 0.95), 2.5)
	draw_line(Vector2(-current_rad - 6, 0), Vector2(-current_rad + 6, 0), Color(1.0, 0.9, 0.3, 0.95), 2.5)
	draw_line(Vector2(current_rad - 6, 0), Vector2(current_rad + 6, 0), Color(1.0, 0.9, 0.3, 0.95), 2.5)


func _draw_ranger_spear_indicator() -> void:
	var mouse_world: Vector2 = get_global_mouse_position()
	var to_mouse: Vector2 = mouse_world - global_position
	var aim_dir: Vector2 = to_mouse.normalized()
	if aim_dir == Vector2.ZERO:
		aim_dir = Vector2.RIGHT

	var beam_len: float = 850.0
	var beam_end: Vector2 = aim_dir * beam_len
	var half_width: float = 22.0 # Compact corridor (44px total width)
	var perp: Vector2 = aim_dir.orthogonal()

	# Corridor polygon (transparent cyan beam area)
	var poly_pts: PackedVector2Array = PackedVector2Array([
		perp * half_width,
		beam_end + perp * half_width,
		beam_end - perp * half_width,
		-perp * half_width
	])
	draw_colored_polygon(poly_pts, Color(0.2, 0.8, 1.0, 0.12))

	# Boundary rails
	draw_line(perp * half_width, beam_end + perp * half_width, Color(0.3, 0.85, 1.0, 0.55), 1.5)
	draw_line(-perp * half_width, beam_end - perp * half_width, Color(0.3, 0.85, 1.0, 0.55), 1.5)

	# Core laser aim line
	var pulse: float = sin(_pulse_timer) * 0.5
	draw_line(Vector2.ZERO, beam_end, Color(0.4, 0.95, 1.0, 0.85 + pulse * 0.15), 2.5)

	# Direction arrow at mouse position
	var m_local: Vector2 = to_local(mouse_world)
	var arrow_size: float = 20.0
	var left_wing: Vector2 = m_local - aim_dir * arrow_size + perp * (arrow_size * 0.5)
	var right_wing: Vector2 = m_local - aim_dir * arrow_size - perp * (arrow_size * 0.5)
	draw_line(left_wing, m_local, Color(0.6, 1.0, 1.0, 0.95), 2.5)
	draw_line(right_wing, m_local, Color(0.6, 1.0, 1.0, 0.95), 2.5)
	draw_circle(m_local, 4.0, Color(1.0, 1.0, 0.5, 0.9))


func _draw_wizard_siphon_indicator() -> void:
	var radius: float = 120.0 # Compact 120px radius
	var pulse: float = sin(_pulse_timer) * 1.5
	var cur_rad: float = radius + pulse

	# Translucent blood-crimson filled area (strictly inside zone)
	draw_circle(Vector2.ZERO, cur_rad, Color(0.75, 0.08, 0.22, 0.22))

	# Glowing crimson perimeter ring
	draw_arc(Vector2.ZERO, cur_rad, 0, TAU, 56, Color(1.0, 0.2, 0.38, 0.95), 2.5)

	# Inner ritual circle
	draw_arc(Vector2.ZERO, cur_rad * 0.55, 0, TAU, 40, Color(0.9, 0.15, 0.3, 0.4), 1.5)

	# 8 radial rune ticks on perimeter
	var tick_count: int = 8
	for i: int in range(tick_count):
		var ang: float = float(i) * TAU / float(tick_count)
		var tick_dir: Vector2 = Vector2(cos(ang), sin(ang))
		var p_in: Vector2 = tick_dir * (cur_rad - 8.0)
		var p_out: Vector2 = tick_dir * (cur_rad + 8.0)
		draw_line(p_in, p_out, Color(1.0, 0.4, 0.5, 0.95), 2.0)
