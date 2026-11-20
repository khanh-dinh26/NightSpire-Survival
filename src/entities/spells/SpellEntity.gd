class_name SpellEntity
extends Area2D
## Universal Spell projectile / area effect in world space.
## Handles Fireball, Molten Spear, Tornado, Earth Spike, and Explosions.

enum SpellType { FIREBALL, MOLTEN_SPEAR, TORNADO, EARTH_SPIKE, EXPLOSION }

var spell_type: SpellType = SpellType.FIREBALL
var damage: int = 30
var speed: float = 250.0
var direction: Vector2 = Vector2.RIGHT
var lifetime: float = 3.0
var level: int = 1

var _time_alive: float = 0.0
var _hit_enemies: Dictionary = {}
var _tick_timer: float = 0.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _fb_frames: SpriteFrames = preload("res://src/entities/spells/fireball_frames.tres")
var _exp_frames: SpriteFrames = preload("res://src/entities/spells/explosion_frames.tres")
var _ms_frames: SpriteFrames = preload("res://src/entities/spells/molten_spear_frames.tres")
var _tor_frames: SpriteFrames = preload("res://src/entities/spells/tornado_frames.tres")
var _es_frames: SpriteFrames = preload("res://src/entities/spells/earth_spike_frames.tres")


func _ready() -> void:
	collision_layer = 0
	collision_mask = 5  # Enemies layer & hurtboxes
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_setup_visuals()


func _setup_visuals() -> void:
	match spell_type:
		SpellType.FIREBALL:
			animated_sprite.sprite_frames = _fb_frames
			animated_sprite.play(&"fly")
			rotation = direction.angle()
			lifetime = 2.2
		SpellType.MOLTEN_SPEAR:
			animated_sprite.sprite_frames = _ms_frames
			animated_sprite.play(&"fly")
			rotation = direction.angle()
			speed = 420.0
			lifetime = 2.0
		SpellType.TORNADO:
			animated_sprite.sprite_frames = _tor_frames
			animated_sprite.play(&"swirl")
			speed = 35.0
			lifetime = 3.5 + float(level) * 0.5
		SpellType.EARTH_SPIKE:
			animated_sprite.sprite_frames = _es_frames
			animated_sprite.play(&"erupt")
			speed = 0.0
			lifetime = 0.8
			animated_sprite.animation_finished.connect(queue_free)
		SpellType.EXPLOSION:
			animated_sprite.sprite_frames = _exp_frames
			animated_sprite.play(&"explode")
			speed = 0.0
			lifetime = 0.6
			animated_sprite.animation_finished.connect(queue_free)


func _physics_process(delta: float) -> void:
	_time_alive += delta
	if _time_alive >= lifetime:
		if spell_type == SpellType.FIREBALL:
			_explode()
		else:
			queue_free()
		return

	if speed > 0.0:
		global_position += direction * speed * delta

	# Tornado suction & continuous tick damage
	if spell_type == SpellType.TORNADO:
		_process_tornado(delta)


func _process_tornado(delta: float) -> void:
	_tick_timer += delta
	var radius: float = 80.0 + float(level) * 20.0
	var suction_strength: float = 70.0 + float(level) * 25.0

	for enemy: Node in get_tree().get_nodes_in_group(&"enemies"):
		var e: Node2D = enemy as Node2D
		if e == null or not is_instance_valid(e):
			continue
		var dist: float = global_position.distance_to(e.global_position)
		if dist <= radius:
			# Pull enemy toward tornado center
			var pull_dir: Vector2 = (global_position - e.global_position).normalized()
			if e.has_method("apply_knockback"):
				e.apply_knockback(pull_dir * suction_strength * delta)
			elif "velocity" in e:
				e.velocity += pull_dir * suction_strength * delta

			# Periodic tick damage
			if _tick_timer >= 0.25:
				if e.has_method("take_damage"):
					e.take_damage(maxi(damage / 4, 3))

	if _tick_timer >= 0.25:
		_tick_timer = 0.0


func _on_body_entered(body: Node2D) -> void:
	_handle_hit(body)


func _on_area_entered(area: Area2D) -> void:
	if area.has_method("take_damage"):
		_handle_hit(area)
	elif area.owner != null and area.owner.has_method("take_damage"):
		_handle_hit(area.owner)


func _handle_hit(target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	if target.is_in_group(&"player") or target is Player:
		return

	var id: int = target.get_instance_id()
	if _hit_enemies.has(id):
		return
	_hit_enemies[id] = true

	if target.has_method("take_damage"):
		target.take_damage(damage)
		if target.has_method("apply_knockback"):
			target.apply_knockback(direction * 80.0)

	match spell_type:
		SpellType.FIREBALL:
			_explode()
		SpellType.MOLTEN_SPEAR:
			# Pierces through, does not queue_free
			pass
		SpellType.EARTH_SPIKE:
			# Hits and stays for animation
			pass


func _explode() -> void:
	var exp_spell: SpellEntity = duplicate() as SpellEntity
	exp_spell.spell_type = SpellType.EXPLOSION
	exp_spell.damage = roundi(damage * 0.8)
	exp_spell.global_position = global_position
	get_tree().current_scene.add_child(exp_spell)
	AudioManager.play_sfx("enemy_death")
	queue_free()
