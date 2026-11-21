class_name Projectile
extends Area2D
## A projectile fired by ranged weapons that flies straight towards target and deals damage.

var damage: int = 10
var speed: float = 240.0
var knockback_force: float = 50.0
var item_data: ItemData = null

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
		var final_damage: int = damage

		var players: Array[Node] = get_tree().get_nodes_in_group(&"player")
		var player_ref: Player = players[0] as Player if players.size() > 0 else null

		if item_data != null:
			if item_data.special_effect == "berserk_low_hp" and player_ref != null:
				if float(player_ref.current_hp) / float(maxi(player_ref.max_hp, 1)) <= 0.35:
					final_damage = roundi(final_damage * 1.5)

			if item_data.special_effect == "lifesteal" and player_ref != null:
				if randf() <= 0.25:
					player_ref.heal(3)

			if item_data.special_effect == "greed_gold":
				if randf() <= 0.35:
					GameManager.add_gold(1)

			if item_data.special_effect == "radius_execute":
				if randf() <= 0.10:
					for enemy: Node in get_tree().get_nodes_in_group(&"enemies"):
						var e: Node2D = enemy as Node2D
						if e != null and is_instance_valid(e) and not e.is_in_group(&"boss") and not e.is_in_group(&"bosses"):
							if global_position.distance_to(e.global_position) <= 150.0 and e.has_method("take_damage"):
								e.take_damage(9999)

		body.take_damage(final_damage)
		if body.has_method("apply_knockback"):
			var kb_dir: Vector2 = direction.normalized()
			body.apply_knockback(kb_dir * knockback_force)
		set_deferred(&"monitoring", false)
		set_deferred(&"monitorable", false)
		queue_free()
