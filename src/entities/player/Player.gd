class_name Player
extends CharacterBody2D
## Player character — 8-directional movement, responsive attack, walk bobbing/tilting, sprite direction facing.

# ── Stats ──────────────────────────────────────────────────────────────
var max_hp: int = 100
var current_hp: int = 100
var speed: float = 130.0
var defense: int = 0

# ── Node references ────────────────────────────────────────────────────
@onready var sprite: Sprite2D = $Sprite2D
@onready var weapon_orbit: WeaponOrbit = $WeaponOrbit

# ── Procedural animation timers ────────────────────────────────────────
var _walk_phase: float = 0.0
var _idle_phase: float = 0.0
var _facing_right: bool = false
var _is_hit_animating: bool = false


func _ready() -> void:
	add_to_group(&"player")
	current_hp = max_hp

	# Give starter weapon if none equipped
	var starter: ItemData = preload("res://src/data/items/weapons/starter_dagger.tres")
	if weapon_orbit != null:
		weapon_orbit.add_weapon(starter)


# ── Movement & Procedural Animation ─────────────────────────────────────
func _physics_process(delta: float) -> void:
	var input_dir: Vector2 = Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_action_pressed(&"ui_left"):
		input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_action_pressed(&"ui_right"):
		input_dir.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_action_pressed(&"ui_up"):
		input_dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_action_pressed(&"ui_down"):
		input_dir.y += 1.0

	if input_dir != Vector2.ZERO:
		input_dir = input_dir.normalized()

	velocity = input_dir * speed
	move_and_slide()

	# Flip sprite based on movement direction (sprite naturally faces left in spritesheet)
	if input_dir.x > 0.0:
		_facing_right = true
	elif input_dir.x < 0.0:
		_facing_right = false

	sprite.flip_h = _facing_right

	# Handle walking vs idle bounce animation
	_animate_character(delta, input_dir)


func _animate_character(delta: float, input_dir: Vector2) -> void:
	if _is_hit_animating:
		return

	if input_dir != Vector2.ZERO:
		# Walking: pixel-perfect bounce + integer tilt
		_walk_phase += delta * 14.0

		# Step bounce strictly snapped to integer pixels (0, -1, -2, -3, -2, -1, 0)
		var bounce_px: float = -roundf(abs(sin(_walk_phase)) * 3.0)
		sprite.position.y = bounce_px

		# Integer rotation degrees for clean pixel rasterization
		var sway_tilt: float = roundf(sin(_walk_phase) * 6.0)

		# Front / back tilt modifier
		var forward_back_tilt: float = 0.0
		if input_dir.y > 0.1: # moving down (forward)
			forward_back_tilt = 3.0 if _facing_right else -3.0
		elif input_dir.y < -0.1: # moving up (backward)
			forward_back_tilt = -3.0 if _facing_right else 3.0

		sprite.rotation_degrees = sway_tilt + forward_back_tilt
		sprite.scale = Vector2.ONE
	else:
		# Idle: return position and rotation to zero cleanly
		_walk_phase = 0.0
		_idle_phase += delta * 3.5

		sprite.position.y = move_toward(sprite.position.y, 0.0, delta * 20.0)
		sprite.rotation_degrees = move_toward(sprite.rotation_degrees, 0.0, delta * 30.0)

		# Subtle 1-pixel breathing bounce
		var breathe_px: float = -roundf(abs(sin(_idle_phase)) * 1.0)
		sprite.position.y = breathe_px
		sprite.scale = Vector2.ONE


# ── Damage ─────────────────────────────────────────────────────────────
func take_damage(amount: int) -> void:
	var effective: int = maxi(amount - defense, 1)
	current_hp -= effective
	GameManager.player_current_hp = current_hp

	EventBus.player_hit.emit(effective)
	_hit_flash()

	if current_hp <= 0:
		current_hp = 0
		EventBus.player_died.emit()


# ── Hit flash + squash effect ──────────────────────────────────────────
func _hit_flash() -> void:
	_is_hit_animating = true
	var tw: Tween = create_tween()
	tw.set_parallel(true)

	# White flash
	tw.tween_property(sprite, ^"modulate", Color(3.0, 3.0, 3.0, 1.0), 0.0)
	tw.tween_property(sprite, ^"modulate", Color(1.0, 1.0, 1.0, 1.0), 0.1).set_delay(0.08)

	# Squash
	tw.tween_property(sprite, ^"scale", Vector2(1.3, 0.7), 0.05)
	tw.tween_property(sprite, ^"scale", Vector2(1.0, 1.0), 0.1).set_delay(0.05)

	tw.chain().tween_callback(func(): _is_hit_animating = false)
