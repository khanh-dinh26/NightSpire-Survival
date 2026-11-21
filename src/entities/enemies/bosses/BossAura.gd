class_name BossAura
extends Node2D
## Dynamic glowing demonic rune circle drawn beneath Bosses for unmistakable visibility.

var is_final: bool = false
var is_enraged: bool = false

var _rotation_angle: float = 0.0
var _pulse_timer: float = 0.0


func _ready() -> void:
	z_index = -1
	show_behind_parent = true


func _process(delta: float) -> void:
	var rot_speed: float = 2.4 if is_enraged else 1.2
	_rotation_angle = wrapf(_rotation_angle + delta * rot_speed, 0.0, TAU)
	_pulse_timer += delta * (5.0 if is_enraged else 2.5)
	queue_redraw()


func _draw() -> void:
	# 1. Dark grounding shadow oval
	draw_set_transform(Vector2(0, 10), 0.0, Vector2(1.0, 0.42))
	draw_circle(Vector2.ZERO, 19.0, Color(0.0, 0.0, 0.0, 0.55))

	# 2. Glowing inner aura disc
	var pulse_val: float = (sin(_pulse_timer) + 1.0) * 0.5 # 0.0 to 1.0
	var alpha: float = lerpf(0.25, 0.45, pulse_val)
	var glow_col: Color
	if is_enraged:
		glow_col = Color(1.0, 0.15, 0.05, alpha * 1.3)
	elif is_final:
		glow_col = Color(0.75, 0.15, 1.0, alpha)
	else:
		glow_col = Color(0.95, 0.25, 0.15, alpha)
	draw_circle(Vector2.ZERO, 17.0 + pulse_val * 2.0, glow_col)

	# 3. Outer rotating demonic rune circle
	draw_set_transform(Vector2(0, 10), _rotation_angle, Vector2(1.0, 0.48))
	var ring_col: Color
	if is_enraged:
		ring_col = Color(1.0, 0.3, 0.1, 0.85 + pulse_val * 0.15)
	elif is_final:
		ring_col = Color(0.85, 0.3, 1.0, 0.8 + pulse_val * 0.2)
	else:
		ring_col = Color(1.0, 0.4, 0.2, 0.75 + pulse_val * 0.2)

	draw_arc(Vector2.ZERO, 18.0, 0, TAU, 32, ring_col, 1.8)

	# 4. Radiating mystical spikes on the rune ring
	var spike_count: int = 8 if is_final else 6
	for i in range(spike_count):
		var ang: float = float(i) * TAU / float(spike_count)
		var p_inner: Vector2 = Vector2.RIGHT.rotated(ang) * 14.5
		var p_outer: Vector2 = Vector2.RIGHT.rotated(ang) * (21.0 + (pulse_val * 2.5 if is_enraged else 0.0))
		draw_line(p_inner, p_outer, ring_col, 1.5)
