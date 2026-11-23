class_name EnemyBase
extends CharacterBody2D
## Base enemy — chases player, deals contact damage, drops gold on death.
## Rare/elite creeps can cast small fireballs; beast creeps can pounce and bite.

enum ActionState {
	NORMAL,
	TELEGRAPH_FIREBALL,
	TELEGRAPH_POUNCE,
	POUNCING,
	ACTION_RECOVERY
}

# ── Data & Runtime Stats ───────────────────────────────────────────────
var data: EnemyData = null
var current_hp: int = 0
var hp_mult: float = 1.0
var dmg_mult: float = 1.0
var speed_mult: float = 1.0
var is_elite: bool = false
var base_scale: Vector2 = Vector2.ONE

# ── Preloaded textures & scenes ────────────────────────────────────────
var _monsters_tex: Texture2D = preload("res://assets/sprites/monsters.png")
var _animals_tex: Texture2D = preload("res://assets/sprites/animals.png")
var _gold_pickup_scene: PackedScene = preload("res://src/entities/pickups/GoldPickup.tscn")
var _boss_proj_scene: PackedScene = preload("res://src/entities/enemies/bosses/BossProjectile.tscn")

# ── Node references ───────────────────────────────────────────────────
@onready var sprite: Sprite2D = $Sprite2D
@onready var hitbox: Area2D = $Hitbox
@onready var damage_cooldown: Timer = $DamageCooldown

# ── Internal ──────────────────────────────────────────────────────────
var _walk_tween: Tween = null
var _can_damage: bool = true
var _knockback_velocity: Vector2 = Vector2.ZERO
var _is_dying: bool = false

var _action_state: ActionState = ActionState.NORMAL
var _action_timer: float = 0.0
var _fireball_cooldown: float = 0.0
var _pounce_cooldown: float = 0.0
var _pounce_direction: Vector2 = Vector2.ZERO
var _pounce_hit_player: bool = false


func setup(enemy_data: EnemyData, p_hp_mult: float = 1.0, p_dmg_mult: float = 1.0, p_spd_mult: float = 1.0, p_is_elite: bool = false) -> void:
	data = enemy_data
	hp_mult = p_hp_mult
	dmg_mult = p_dmg_mult
	speed_mult = p_spd_mult
	is_elite = p_is_elite


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

	# Elite setup: bigger, beefier, glowing aura
	if is_elite:
		base_scale = Vector2(1.65, 1.65)
		scale = base_scale
		current_hp = roundi(current_hp * 2.6)
		dmg_mult *= 1.3
		modulate = Color(1.35, 0.75, 0.5, 1.0)
		_start_elite_aura()

	# Connect hitbox
	hitbox.body_entered.connect(_on_hitbox_body_entered)

	# Connect damage cooldown
	damage_cooldown.timeout.connect(_on_damage_cooldown_timeout)

	# Start walk oscillation tween
	_start_walk_animation()

	# Cooldowns staggered initially
	_fireball_cooldown = randf_range(3.5, 6.5)
	_pounce_cooldown = randf_range(3.0, 5.5)


func _start_elite_aura() -> void:
	var tw: Tween = create_tween()
	tw.set_loops()
	tw.tween_property(self, ^"modulate", Color(1.5, 0.55, 0.35, 1.0), 0.45)
	tw.tween_property(self, ^"modulate", Color(1.3, 0.85, 0.55, 1.0), 0.45)


func _physics_process(delta: float) -> void:
	if _is_dying:
		return

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

	# Cooldown timers
	if _fireball_cooldown > 0.0:
		_fireball_cooldown -= delta
	if _pounce_cooldown > 0.0:
		_pounce_cooldown -= delta
	if _action_timer > 0.0:
		_action_timer -= delta

	match _action_state:
		ActionState.NORMAL:
			_process_normal_movement(delta, player)
		ActionState.TELEGRAPH_FIREBALL:
			velocity = _knockback_velocity
			if _action_timer <= 0.0:
				_cast_fireball(player)
		ActionState.TELEGRAPH_POUNCE:
			velocity = _knockback_velocity
			if is_instance_valid(player):
				_pounce_direction = global_position.direction_to(player.global_position)
			if _action_timer <= 0.0:
				_execute_pounce()
		ActionState.POUNCING:
			velocity = _pounce_direction * 260.0 + _knockback_velocity
			if not _pounce_hit_player and is_instance_valid(player):
				if global_position.distance_to(player.global_position) <= 30.0:
					_pounce_hit_player = true
					var bite_dmg: int = roundi(data.damage * 1.25 * dmg_mult)
					player.take_damage(bite_dmg)
					player.velocity += _pounce_direction * 180.0
			if _action_timer <= 0.0:
				_action_state = ActionState.ACTION_RECOVERY
				_action_timer = 0.2
				scale = base_scale
				modulate = Color(1.35, 0.75, 0.5, 1.0) if is_elite else Color.WHITE
		ActionState.ACTION_RECOVERY:
			velocity = _knockback_velocity * 0.5
			if _action_timer <= 0.0:
				_action_state = ActionState.NORMAL

	move_and_slide()


func _process_normal_movement(_delta: float, player: Player) -> void:
	var direction: Vector2 = global_position.direction_to(player.global_position)
	if direction.x > 0.05:
		sprite.flip_h = true
	elif direction.x < -0.05:
		sprite.flip_h = false

	velocity = (direction * data.speed * speed_mult) + _knockback_velocity

	var dist: float = global_position.distance_to(player.global_position)

	# 1. Pounce check for beast / fast creeps (spiders, hounds, bats)
	var is_beast: bool = data != null and data.enemy_id in ["spider", "bone_rat", "bat", "vampire_bat", "lava_mite", "abyssal_crawler"]
	if is_beast and _pounce_cooldown <= 0.0 and dist >= 65.0 and dist <= 140.0:
		_start_pounce_telegraph(player)
		return

	# 2. Fireball check for rare / elite creeps or magic creeps
	var can_shoot_fireball: bool = (is_elite or (data != null and data.enemy_id in ["dark_cultist", "fire_imp", "shadow_demon", "shadow_wisp"]))
	if can_shoot_fireball and _fireball_cooldown <= 0.0 and dist >= 95.0 and dist <= 220.0:
		_start_fireball_telegraph(player)
		return


func _start_fireball_telegraph(_player: Player) -> void:
	_action_state = ActionState.TELEGRAPH_FIREBALL
	_action_timer = 0.45
	_fireball_cooldown = randf_range(6.5, 9.5)

	# Telegraph amber glow
	var tw: Tween = create_tween()
	tw.tween_property(self, ^"modulate", Color(2.8, 1.3, 0.4, 1.0), 0.22)
	tw.tween_property(self, ^"modulate", Color.WHITE if not is_elite else Color(1.35, 0.75, 0.5, 1.0), 0.23)


func _cast_fireball(player: Player) -> void:
	_action_state = ActionState.ACTION_RECOVERY
	_action_timer = 0.2
	if not is_instance_valid(player):
		return

	var dir: Vector2 = global_position.direction_to(player.global_position)
	var proj: BossProjectile = _boss_proj_scene.instantiate() as BossProjectile
	var fb_dmg: int = maxi(5, roundi(data.damage * 0.7 * dmg_mult))
	proj.setup_type(BossProjectile.ProjectileType.FIREBALL, fb_dmg, 115.0, dir, true)
	proj.global_position = global_position
	get_tree().current_scene.call_deferred(&"add_child", proj)
	AudioManager.play_sfx("slash")


func _start_pounce_telegraph(player: Player) -> void:
	_action_state = ActionState.TELEGRAPH_POUNCE
	_action_timer = 0.35
	_pounce_cooldown = randf_range(5.0, 7.5)
	_pounce_direction = global_position.direction_to(player.global_position)
	_pounce_hit_player = false

	# Crouch and squash telegraph
	var tw: Tween = create_tween()
	tw.tween_property(self, ^"scale", base_scale * Vector2(1.25, 0.75), 0.18)
	tw.parallel().tween_property(self, ^"modulate", Color(2.5, 0.4, 0.4, 1.0), 0.18)
	tw.tween_property(self, ^"scale", base_scale * Vector2(0.85, 1.25), 0.17)


func _execute_pounce() -> void:
	_action_state = ActionState.POUNCING
	_action_timer = 0.28
	AudioManager.play_sfx("slash")


func apply_knockback(force: Vector2) -> void:
	if GameManager.current_tower != null and GameManager.current_tower.enemy_knockback_resist > 0.0:
		force *= (1.0 - clampf(GameManager.current_tower.enemy_knockback_resist, 0.0, 0.95))
	_knockback_velocity = force


# ── Contact Damage ────────────────────────────────────────────────────
func _on_hitbox_body_entered(body: Node2D) -> void:
	if _is_dying:
		return
	if body is Player and _can_damage:
		_deal_contact_damage(body as Player)


func _deal_contact_damage(player: Player) -> void:
	if _is_dying or not _can_damage:
		return
	var final_damage: int = roundi(data.damage * dmg_mult)
	player.take_damage(final_damage)
	_can_damage = false
	damage_cooldown.start()


func _on_damage_cooldown_timeout() -> void:
	if _is_dying or not hitbox.monitoring:
		return
	_can_damage = true
	# Check if player is still overlapping the hitbox
	for body: Node2D in hitbox.get_overlapping_bodies():
		if body is Player:
			_deal_contact_damage(body as Player)
			break


# ── Take Damage ───────────────────────────────────────────────────────
func take_damage(amount: int) -> void:
	if _is_dying:
		return
	if has_meta("marked"):
		amount = roundi(float(amount) * 1.6)
	EventBus.player_dealt_damage.emit(amount)
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
	var restore_color: Color = Color(1.35, 0.75, 0.5, 1.0) if is_elite else Color(1.0, 1.0, 1.0, 1.0)
	tw.tween_property(self, ^"modulate", restore_color, 0.08).set_delay(0.08)
	# Squash relative to base_scale
	tw.tween_property(self, ^"scale", base_scale * Vector2(1.25, 0.75), 0.04)
	tw.tween_property(self, ^"scale", base_scale, 0.08).set_delay(0.04)


# ── Death ─────────────────────────────────────────────────────────────
func die() -> void:
	if _is_dying:
		return
	_is_dying = true
	remove_from_group(&"enemies")
	set_physics_process(false)
	hitbox.set_deferred(&"monitoring", false)
	set_deferred(&"collision_layer", 0)
	set_deferred(&"collision_mask", 0)

	var players: Array[Node] = get_tree().get_nodes_in_group(&"player")
	var p: Player = players[0] as Player if players.size() > 0 else null
	var luck: float = p.luck_stat if p != null else 0.0

	var current_floor: int = maxi(1, GameManager.current_floor_index)
	var base_drop_chance: float = clampf(0.75 - (float(current_floor - 1) / 99.0) * 0.65, 0.10, 0.75)
	var drop_chance: float = base_drop_chance + (luck * 0.20)
	var drops_gold: bool = (randf() <= drop_chance) or (is_elite and randf() <= 0.75)
	var gold_value: int = 1
	if is_elite:
		gold_value = randi_range(3, 5)
	else:
		gold_value = 2 if (luck > 0.0 and randf() <= 0.25) else 1

	EventBus.enemy_killed.emit(global_position, gold_value if drops_gold else 0)
	if drops_gold:
		if is_elite:
			var split_count: int = randi_range(2, 3)
			var per_coin: int = maxi(1, gold_value / split_count)
			for i: int in range(split_count):
				var offset: Vector2 = Vector2(randf_range(-12.0, 12.0), randf_range(-12.0, 12.0))
				_spawn_gold(per_coin, global_position + offset)
		else:
			_spawn_gold(gold_value, global_position)

	if p != null:
		if p.has_vampire_chalice:
			p.kills_counter += 1
			if p.kills_counter >= 8:
				p.kills_counter = 0
				p.heal(6)

		if luck > 0.0 and randf() <= (0.10 + luck * 0.10):
			if randf() <= 0.35:
				p.heal(5)
			else:
				_spawn_gold(1, global_position)

	if _walk_tween != null and _walk_tween.is_valid():
		_walk_tween.kill()
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, ^"scale", Vector2.ZERO, 0.3)
	tw.tween_property(self, ^"modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(queue_free)


func _spawn_gold(gold_value: int, pos: Vector2 = Vector2.ZERO) -> void:
	var gold_pickup: GoldPickup = _gold_pickup_scene.instantiate() as GoldPickup
	gold_pickup.gold_amount = gold_value
	gold_pickup.global_position = pos if pos != Vector2.ZERO else global_position
	get_tree().current_scene.call_deferred(&"add_child", gold_pickup)


func _start_walk_animation() -> void:
	_walk_tween = create_tween()
	_walk_tween.set_loops()
	_walk_tween.tween_property(self, ^"rotation_degrees", -4.0, 0.06)
	_walk_tween.tween_property(self, ^"rotation_degrees", 4.0, 0.12)
	_walk_tween.tween_property(self, ^"rotation_degrees", 0.0, 0.06)


func _get_player() -> Player:
	var players: Array[Node] = get_tree().get_nodes_in_group(&"player")
	if players.size() > 0:
		return players[0] as Player
	return null
