class_name BossProjectile
extends Area2D
## Hazardous magic spell projectile fired by bosses or elite creeps towards the player.

enum ProjectileType { FIREBALL, DARK_ORB, FROST_ORB }

@export var projectile_type: ProjectileType = ProjectileType.FIREBALL
var damage: int = 15
var speed: float = 140.0
var direction: Vector2 = Vector2.RIGHT
var is_creep_projectile: bool = false
var _consumed: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var lifetime_timer: Timer = $LifetimeTimer

var _dark_orb_tex: Texture2D = preload("res://assets/effects/magic_effects/Icons/tile004.png")
var _fireball_tex: Texture2D = preload("res://assets/effects/magic_effects/Icons/tile000.png")


func setup_type(p_type: ProjectileType, p_damage: int, p_speed: float, p_dir: Vector2, p_is_creep: bool = false) -> void:
	projectile_type = p_type
	damage = p_damage
	speed = p_speed
	direction = p_dir.normalized()
	is_creep_projectile = p_is_creep
	if is_node_ready():
		_apply_visuals()


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	if lifetime_timer != null:
		lifetime_timer.timeout.connect(queue_free)
	_apply_visuals()


func _apply_visuals() -> void:
	if sprite == null:
		return
	var base_sc: Vector2 = Vector2(0.55, 0.55)
	if is_creep_projectile:
		base_sc = Vector2(0.35, 0.35)
		sprite.texture = _fireball_tex
		sprite.modulate = Color(1.3, 0.65, 0.35, 0.9)
	else:
		match projectile_type:
			ProjectileType.DARK_ORB:
				sprite.texture = _dark_orb_tex
				sprite.modulate = Color(1.4, 0.6, 2.0, 1.0)
			_:
				sprite.texture = _fireball_tex
				sprite.modulate = Color(1.4, 0.85, 0.3, 1.0)

	sprite.scale = base_sc
	rotation = direction.angle()

	# Pulsing animation
	var tw: Tween = create_tween().set_loops()
	tw.tween_property(sprite, ^"scale", base_sc * 1.15, 0.16).set_trans(Tween.TRANS_SINE)
	tw.tween_property(sprite, ^"scale", base_sc * 0.90, 0.16).set_trans(Tween.TRANS_SINE)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta


func _on_body_entered(body: Node2D) -> void:
	if _consumed:
		return
	if body is Player:
		_consumed = true
		(body as Player).take_damage(damage)
		set_deferred(&"monitoring", false)
		set_deferred(&"monitorable", false)
		queue_free()
	elif body is TileMap or body is TileMapLayer or body is StaticBody2D:
		_consumed = true
		set_deferred(&"monitoring", false)
		set_deferred(&"monitorable", false)
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if _consumed:
		return
	if area.name == "Hurtbox" and area.get_parent() is Player:
		_consumed = true
		(area.get_parent() as Player).take_damage(damage)
		set_deferred(&"monitoring", false)
		set_deferred(&"monitorable", false)
		queue_free()
