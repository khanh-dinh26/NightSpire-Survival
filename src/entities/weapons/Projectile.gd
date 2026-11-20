class_name Projectile
extends Area2D
## A projectile fired by a ranged weapon that damages enemies on contact.

var damage: int = 10
var speed: float = 200.0
var direction: Vector2 = Vector2.RIGHT
var knockback_force: float = 50.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	$LifetimeTimer.timeout.connect(_on_lifetime_timer_timeout)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies") and body.has_method("take_damage"):
		body.take_damage(damage)
		if body.has_method("apply_knockback"):
			var kb_dir: Vector2 = (body.global_position - global_position).normalized()
			body.apply_knockback(kb_dir * knockback_force)
	queue_free()


func _on_lifetime_timer_timeout() -> void:
	queue_free()
