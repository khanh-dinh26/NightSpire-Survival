class_name WeaponBase
extends Node2D
## A single weapon that orbits the player and attacks nearby enemies quickly and responsively.

var item_data: ItemData = null

var _target: Node2D = null
var _is_lunging: bool = false
var _home_position: Vector2 = Vector2.ZERO
var _cooldown_left: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var attack_timer: Timer = $AttackTimer

var _projectile_scene: PackedScene = preload("res://src/entities/weapons/Projectile.tscn")


func _ready() -> void:
	# Disable old timer in favor of responsive frame-based cooldown
	attack_timer.stop()


func setup(data: ItemData) -> void:
	item_data = data
	sprite.region_rect = data.sprite_region
	_cooldown_left = 0.0


func _process(delta: float) -> void:
	if item_data == null:
		return

	# Tick cooldown
	if _cooldown_left > 0.0:
		_cooldown_left -= delta

	# Look at closest enemy
	_target = _find_closest_enemy()
	if _target != null and not _is_lunging:
		var target_angle: float = (_target.global_position - global_position).angle()
		rotation = lerp_angle(rotation, target_angle, 18.0 * delta)

	# Ready to strike the moment an enemy is within range
	if _cooldown_left <= 0.0 and _target != null and not _is_lunging:
		_execute_attack()


func _find_closest_enemy() -> Node2D:
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	var closest: Node2D = null
	var closest_dist: float = item_data.attack_range if item_data != null else 80.0
	for enemy: Node in enemies:
		var e: Node2D = enemy as Node2D
		if e == null or not is_instance_valid(e):
			continue
		var dist: float = global_position.distance_to(e.global_position)
		if dist <= closest_dist:
			closest_dist = dist
			closest = e
	return closest


func _execute_attack() -> void:
	if item_data == null:
		return
	_cooldown_left = 1.0 / item_data.attack_speed
	AudioManager.play_sfx("slash")

	match item_data.weapon_style:
		ItemData.WeaponStyle.MELEE_ORBIT:
			_attack_melee()
		ItemData.WeaponStyle.RANGED_PROJECTILE:
			_attack_ranged()


func _attack_melee() -> void:
	if _is_lunging or _target == null:
		return
	_is_lunging = true
	_home_position = position

	var target_ref: Node2D = _target
	var direction: Vector2 = (target_ref.global_position - global_position).normalized()
	var lunge_offset: Vector2 = direction * (item_data.attack_range * 0.55)

	# Snappy lunge forward and bounce back
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, ^"position", _home_position + lunge_offset, 0.05).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, ^"scale", Vector2(1.35, 1.35), 0.05)

	tw.chain().tween_callback(func(): _deal_melee_damage(target_ref))
	tw.chain().tween_property(self, ^"position", _home_position, 0.06).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(self, ^"scale", Vector2(1.0, 1.0), 0.06)
	tw.chain().tween_callback(_on_lunge_finished)


func _deal_melee_damage(target: Node2D) -> void:
	if not is_instance_valid(target) or not target.has_method("take_damage") or item_data == null:
		return

	var final_damage: int = item_data.base_damage

	# Berserk Low HP check
	var players: Array[Node] = get_tree().get_nodes_in_group(&"player")
	var player_ref: Player = players[0] as Player if players.size() > 0 else null

	if item_data.special_effect == "berserk_low_hp" and player_ref != null:
		if float(player_ref.current_hp) / float(maxi(player_ref.max_hp, 1)) <= 0.35:
			final_damage = roundi(final_damage * 1.5)

	target.take_damage(final_damage)

	if target.has_method("apply_knockback"):
		var kb_dir: Vector2 = (target.global_position - global_position).normalized()
		target.apply_knockback(kb_dir * item_data.knockback)

	# Lifesteal check
	if item_data.special_effect == "lifesteal" and player_ref != null:
		if randf() <= 0.25:
			player_ref.heal(3)

	# Greed Gold check
	if item_data.special_effect == "greed_gold":
		if randf() <= 0.35:
			GameManager.add_gold(1)

	# Radius Instakill Shockwave
	if item_data.special_effect == "radius_execute":
		if randf() <= 0.10:
			_trigger_radius_execute(target.global_position)


func _trigger_radius_execute(center_pos: Vector2) -> void:
	# Eliminate regular enemies within 150px radius
	var radius: float = 150.0
	for enemy: Node in get_tree().get_nodes_in_group(&"enemies"):
		var e: Node2D = enemy as Node2D
		if e == null or not is_instance_valid(e):
			continue
		if e.is_in_group(&"boss"):
			continue # Bosses resist instakill shockwave
		if center_pos.distance_to(e.global_position) <= radius:
			if e.has_method("take_damage"):
				e.take_damage(9999) # Instant execute
	AudioManager.play_sfx("enemy_death")


func _on_lunge_finished() -> void:
	_is_lunging = false


func _attack_ranged() -> void:
	if _target == null:
		return
	var projectile: Projectile = _projectile_scene.instantiate() as Projectile
	projectile.damage = item_data.base_damage
	projectile.speed = item_data.projectile_speed
	projectile.direction = (_target.global_position - global_position).normalized()
	projectile.knockback_force = item_data.knockback
	projectile.item_data = item_data
	projectile.global_position = global_position
	get_tree().current_scene.add_child(projectile)

	# Quick recoil effect
	var tw: Tween = create_tween()
	tw.tween_property(self, ^"scale", Vector2(0.8, 1.2), 0.04)
	tw.tween_property(self, ^"scale", Vector2(1.0, 1.0), 0.06)
