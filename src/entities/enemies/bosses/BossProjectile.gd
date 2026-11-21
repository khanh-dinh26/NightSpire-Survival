class_name BossProjectile
extends Area2D
## Hazardous projectile fired by bosses towards the player.

var damage: int = 15
var speed: float = 140.0
var direction: Vector2 = Vector2.RIGHT
var _consumed: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	$LifetimeTimer.timeout.connect(queue_free)


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


func _on_area_entered(area: Area2D) -> void:
	if _consumed:
		return
	if area.name == "Hurtbox" and area.get_parent() is Player:
		_consumed = true
		(area.get_parent() as Player).take_damage(damage)
		set_deferred(&"monitoring", false)
		set_deferred(&"monitorable", false)
		queue_free()
