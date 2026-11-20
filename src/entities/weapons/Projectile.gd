class_name Projectile
extends Area2D
## A projectile fired by ranged weapons that flies straight towards target and deals damage.

var damage: int = 10
var speed: float = 240.0
var knockback_force: float = 50.0

var direction: Vector2 = Vector2.RIGHT:
	set(val):
		direction = val
		_update_rotation()


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	$LifetimeTimer.timeout.connect(queue_free)
	_update_rotation()


func _physics_process(delta: float) -> void:
	position += direction * speed * delta


func _update_rotation() -> void:
	if direction != Vector2.ZERO:
		# The arrow sprite in items.png natively points North-West (-135° / Up-Left).
		# Adding 135° (+3*PI/4) rotates the tip straight to 0 rad (East / flight direction).
		rotation = direction.angle() + deg_to_rad(135.0)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies") and body.has_method("take_damage"):
		body.take_damage(damage)
		if body.has_method("apply_knockback"):
			var kb_dir: Vector2 = direction.normalized()
			body.apply_knockback(kb_dir * knockback_force)
		queue_free()
