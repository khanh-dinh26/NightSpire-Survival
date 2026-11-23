class_name BossGroundAoe
extends Node2D
## Telegraphed magical ground hazard spawned by caster bosses.

var damage: int = 22
var radius: float = 48.0
var delay: float = 0.8
var _elapsed: float = 0.0
var _exploded: bool = false

var _exp_frames: SpriteFrames = preload("res://src/entities/spells/explosion_frames.tres")
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	z_index = 5
	queue_redraw()


func _draw() -> void:
	if _exploded:
		return
	var progress: float = clampf(_elapsed / delay, 0.0, 1.0)
	# Translucent warning fill
	draw_circle(Vector2.ZERO, radius, Color(1.0, 0.2, 0.2, 0.22 + progress * 0.2))
	# Outer warning ring
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(1.0, 0.3, 0.3, 0.85), 2.0)
	# Inner expanding charge ring
	draw_arc(Vector2.ZERO, radius * progress, 0.0, TAU, 28, Color(1.0, 0.8, 0.2, 0.9), 1.5)


func _process(delta: float) -> void:
	if _exploded:
		return
	_elapsed += delta
	queue_redraw()
	if _elapsed >= delay:
		_detonate()


func _detonate() -> void:
	_exploded = true
	queue_redraw()
	AudioManager.play_sfx("explosion")

	# Damage player if inside radius
	var players: Array[Node] = get_tree().get_nodes_in_group(&"player")
	if players.size() > 0:
		var p: Player = players[0] as Player
		if is_instance_valid(p) and global_position.distance_to(p.global_position) <= radius:
			p.take_damage(damage)
			var push_dir: Vector2 = (p.global_position - global_position).normalized()
			if push_dir == Vector2.ZERO:
				push_dir = Vector2.DOWN
			p.velocity += push_dir * 180.0

	# Play magical explosion animation
	if anim_sprite != null:
		anim_sprite.visible = true
		anim_sprite.sprite_frames = _exp_frames
		anim_sprite.scale = Vector2(1.2, 1.2)
		anim_sprite.play(&"explode")
		anim_sprite.animation_finished.connect(queue_free)
	else:
		# Fallback timer
		get_tree().create_timer(0.4).timeout.connect(queue_free)
