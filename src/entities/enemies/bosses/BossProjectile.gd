class_name BossProjectile
extends Area2D
## Hazardous projectile fired by bosses towards the player.

var damage: int = 15
var speed: float = 140.0
var direction: Vector2 = Vector2.RIGHT


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	$LifetimeTimer.timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		(body as Player).take_damage(damage)
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if area.name == "Hurtbox" and area.get_parent() is Player:
		(area.get_parent() as Player).take_damage(damage)
		queue_free()
