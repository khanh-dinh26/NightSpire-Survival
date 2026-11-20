class_name EnemyBase
extends CharacterBody2D
## Base enemy — chases player, deals contact damage, drops gold on death.

# ── Data & Runtime Stats ───────────────────────────────────────────────
var data: EnemyData = null
var current_hp: int = 0
var hp_mult: float = 1.0
var dmg_mult: float = 1.0
var speed_mult: float = 1.0

# ── Preloaded textures ────────────────────────────────────────────────
var _monsters_tex: Texture2D = preload("res://assets/sprites/monsters.png")
var _animals_tex: Texture2D = preload("res://assets/sprites/animals.png")

# ── Scenes ─────────────────────────────────────────────────────────────
var _gold_pickup_scene: PackedScene = preload("res://src/entities/pickups/GoldPickup.tscn")

# ── Node references ───────────────────────────────────────────────────
@onready var sprite: Sprite2D = $Sprite2D
@onready var hitbox: Area2D = $Hitbox
@onready var damage_cooldown: Timer = $DamageCooldown

# ── Internal ──────────────────────────────────────────────────────────
var _walk_tween: Tween = null
var _can_damage: bool = true
var _knockback_velocity: Vector2 = Vector2.ZERO


func setup(enemy_data: EnemyData, p_hp_mult: float = 1.0, p_dmg_mult: float = 1.0, p_spd_mult: float = 1.0) -> void:
	data = enemy_data
	hp_mult = p_hp_mult
	dmg_mult = p_dmg_mult
	speed_mult = p_spd_mult


func _ready() -> void:
	add_to_group(&"enemies")
	if data == null:
		push_error("EnemyBase: data not set before adding to tree!")
		queue_free()
		return

	current_hp = roundi(data.max_hp * hp_mult)

	# Configure sprite
	if data.sprite_sheet == "animals":
		sprite.texture = _animals_tex
	else:
		sprite.texture = _monsters_tex
	sprite.region_enabled = true
	sprite.region_rect = data.sprite_region

	# Connect hitbox
	hitbox.body_entered.connect(_on_hitbox_body_entered)

	# Connect damage cooldown
	damage_cooldown.timeout.connect(_on_damage_cooldown_timeout)

	# Start walk oscillation tween
	_start_walk_animation()


func _physics_process(delta: float) -> void:
	# Decay knockback
	if _knockback_velocity.length() > 5.0:
		_knockback_velocity = _knockback_velocity.lerp(Vector2.ZERO, 10.0 * delta)
	else:
		_knockback_velocity = Vector2.ZERO

	var player: Player = _get_player()
	if player == null:
		velocity = _knockback_velocity
		move_and_slide()
		return

	var direction: Vector2 = global_position.direction_to(player.global_position)
	if direction.x > 0.05:
		sprite.flip_h = true
	elif direction.x < -0.05:
		sprite.flip_h = false

	velocity = (direction * data.speed * speed_mult) + _knockback_velocity
	move_and_slide()


func apply_knockback(force: Vector2) -> void:
	_knockback_velocity = force


# ── Contact Damage ────────────────────────────────────────────────────
func _on_hitbox_body_entered(body: Node2D) -> void:
	if body is Player and _can_damage:
		_deal_contact_damage(body as Player)


func _deal_contact_damage(player: Player) -> void:
	if not _can_damage:
		return
	var final_damage: int = roundi(data.damage * dmg_mult)
	player.take_damage(final_damage)
	_can_damage = false
	damage_cooldown.start()


func _on_damage_cooldown_timeout() -> void:
	_can_damage = true
	# Check if player is still overlapping the hitbox
	for body: Node2D in hitbox.get_overlapping_bodies():
		if body is Player:
			_deal_contact_damage(body as Player)
			break


# ── Take Damage ───────────────────────────────────────────────────────
func take_damage(amount: int) -> void:
	current_hp -= amount
	_hit_flash()
	if current_hp <= 0:
		current_hp = 0
		die()


func _hit_flash() -> void:
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	# White flash
	tw.tween_property(self, ^"modulate", Color(3.0, 3.0, 3.0, 1.0), 0.0)
	tw.tween_property(self, ^"modulate", Color(1.0, 1.0, 1.0, 1.0), 0.08).set_delay(0.08)
	# Squash
	tw.tween_property(self, ^"scale", Vector2(1.3, 0.7), 0.04)
	tw.tween_property(self, ^"scale", Vector2(1.0, 1.0), 0.08).set_delay(0.04)


# ── Death ─────────────────────────────────────────────────────────────
func die() -> void:
	remove_from_group(&"enemies")
	# Disable further interactions
	set_physics_process(false)
	hitbox.set_deferred(&"monitoring", false)
	collision_layer = 0
	collision_mask = 0

	# Emit signal & spawn gold
	var gold_value: int = randi_range(data.gold_drop_min, data.gold_drop_max)
	EventBus.enemy_killed.emit(global_position, gold_value)
	_spawn_gold(gold_value)

	# Check player buffs (Vampire chalice & Lucky drops)
	var players: Array[Node] = get_tree().get_nodes_in_group(&"player")
	if players.size() > 0:
		var p: Player = players[0] as Player
		if p != null:
			if p.has_vampire_chalice:
				p.kills_counter += 1
				if p.kills_counter >= 8:
					p.kills_counter = 0
					p.heal(6)

			# Lucky bonus drop
			if p.luck_stat > 0.0 and randf() <= (0.15 + p.luck_stat * 0.15):
				# Spawn extra high-value gold or heal drop
				_spawn_gold(gold_value + 3)
				if randf() <= 0.35:
					p.heal(5)

	# Death tween: scale to 0 + fade
	if _walk_tween != null and _walk_tween.is_valid():
		_walk_tween.kill()
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, ^"scale", Vector2.ZERO, 0.3)
	tw.tween_property(self, ^"modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(queue_free)


func _spawn_gold(gold_value: int) -> void:
	var gold_pickup: GoldPickup = _gold_pickup_scene.instantiate() as GoldPickup
	gold_pickup.gold_amount = gold_value
	gold_pickup.global_position = global_position
	get_tree().current_scene.add_child(gold_pickup)


# ── Walk Animation ────────────────────────────────────────────────────
func _start_walk_animation() -> void:
	_walk_tween = create_tween()
	_walk_tween.set_loops()
	_walk_tween.tween_property(self, ^"rotation_degrees", -4.0, 0.06)
	_walk_tween.tween_property(self, ^"rotation_degrees", 4.0, 0.12)
	_walk_tween.tween_property(self, ^"rotation_degrees", 0.0, 0.06)


# ── Helpers ───────────────────────────────────────────────────────────
func _get_player() -> Player:
	var players: Array[Node] = get_tree().get_nodes_in_group(&"player")
	if players.size() > 0:
		return players[0] as Player
	return null
