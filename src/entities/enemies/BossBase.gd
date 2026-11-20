class_name BossBase
extends CharacterBody2D
## Imposing Boss entity with multi-phase attack patterns, charge, summons, and projectiles.

signal boss_hp_changed(current_hp: int, max_hp: int)
signal boss_died(boss_name: String)

enum State { CHASE, TELEGRAPH_CHARGE, CHARGING, CASTING, STUNNED }

@export var data: EnemyData = null

var max_hp: int = 200
var current_hp: int = 200
var damage: int = 15
var speed: float = 55.0
var hp_mult: float = 1.0
var dmg_mult: float = 1.0
var spd_mult: float = 1.0

var current_state: State = State.CHASE
var is_enraged: bool = false
var charge_direction: Vector2 = Vector2.ZERO
var charge_speed: float = 280.0

var _state_timer: float = 0.0
var _attack_cooldown_timer: float = 2.0
var _walk_phase: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var hitbox: Area2D = $Hitbox
@onready var damage_cooldown: Timer = $DamageCooldown

var _proj_scene: PackedScene = preload("res://src/entities/enemies/bosses/BossProjectile.tscn")
var _enemy_base_scene: PackedScene = preload("res://src/entities/enemies/EnemyBase.tscn")
var _gold_pickup_scene: PackedScene = preload("res://src/entities/pickups/GoldPickup.tscn")
var _spider_data: EnemyData = preload("res://src/data/enemies/spider.tres")


func setup(enemy_data: EnemyData, p_hp_mult: float = 1.0, p_dmg_mult: float = 1.0, p_spd_mult: float = 1.0) -> void:
	data = enemy_data
	hp_mult = p_hp_mult
	dmg_mult = p_dmg_mult
	spd_mult = p_spd_mult


func _ready() -> void:
	add_to_group(&"enemies")
	add_to_group(&"bosses")

	if data != null:
		max_hp = roundi(data.max_hp * hp_mult)
		damage = roundi(data.damage * dmg_mult)
		speed = data.speed * spd_mult
		sprite.texture = preload("res://assets/sprites/monsters.png")
		sprite.region_enabled = true
		sprite.region_rect = data.sprite_region

	current_hp = max_hp
	boss_hp_changed.emit(current_hp, max_hp)

	hitbox.body_entered.connect(_on_hitbox_body_entered)
	_attack_cooldown_timer = 2.0


func _physics_process(delta: float) -> void:
	var player: Player = _get_player()
	if player == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Face player horizontally
	var to_player: Vector2 = global_position.direction_to(player.global_position)
	if to_player.x > 0.05:
		sprite.flip_h = true
	elif to_player.x < -0.05:
		sprite.flip_h = false

	# State timer tick
	if _state_timer > 0.0:
		_state_timer -= delta

	# Attack cooldown tick
	if _attack_cooldown_timer > 0.0:
		_attack_cooldown_timer -= delta

	match current_state:
		State.CHASE:
			_process_chase(delta, player, to_player)
		State.TELEGRAPH_CHARGE:
			_process_telegraph(delta)
		State.CHARGING:
			_process_charging(delta)
		State.CASTING:
			_process_casting(delta)
		State.STUNNED:
			_process_stunned(delta)

	move_and_slide()


func _process_chase(delta: float, player: Player, to_player: Vector2) -> void:
	velocity = to_player * speed
	_walk_phase += delta * 8.0
	sprite.position.y = -roundf(abs(sin(_walk_phase)) * 2.0)

	# Pick next special attack when cooldown ready
	if _attack_cooldown_timer <= 0.0:
		_choose_attack(player)


func _choose_attack(player: Player) -> void:
	var cooldown_base: float = data.attack_cooldown if data != null else 3.0
	_attack_cooldown_timer = cooldown_base * (0.65 if is_enraged else 1.0)

	var roll: float = randf()
	if data != null and data.attack_pattern == "charge":
		_start_charge(player)
	elif data != null and data.attack_pattern == "projectile":
		_start_projectile_attack(player)
	elif data != null and data.attack_pattern == "summon":
		_start_summon()
	else:
		# Multi-boss mixed pattern
		if roll < 0.4:
			_start_charge(player)
		elif roll < 0.75:
			_start_projectile_attack(player)
		else:
			_start_summon()


# ── Special Skill 1: Charge Dash ────────────────────────────────────────
func _start_charge(player: Player) -> void:
	current_state = State.TELEGRAPH_CHARGE
	_state_timer = 0.6
	velocity = Vector2.ZERO
	charge_direction = (player.global_position - global_position).normalized()

	# Red telegraph flash
	var tw: Tween = create_tween()
	tw.set_loops(3)
	tw.tween_property(sprite, ^"modulate", Color(2.5, 0.4, 0.4, 1.0), 0.1)
	tw.tween_property(sprite, ^"modulate", Color.WHITE, 0.1)


func _process_telegraph(_delta: float) -> void:
	velocity = Vector2.ZERO
	if _state_timer <= 0.0:
		# Launch dash
		current_state = State.CHARGING
		_state_timer = 0.55


func _process_charging(_delta: float) -> void:
	velocity = charge_direction * (charge_speed * (1.2 if is_enraged else 1.0))
	if _state_timer <= 0.0:
		current_state = State.STUNNED
		_state_timer = 0.4


func _process_stunned(_delta: float) -> void:
	velocity = Vector2.ZERO
	if _state_timer <= 0.0:
		current_state = State.CHASE


# ── Special Skill 2: Projectile Volley ──────────────────────────────────
func _start_projectile_attack(player: Player) -> void:
	current_state = State.CASTING
	_state_timer = 0.4
	velocity = Vector2.ZERO

	# Channel glow
	var tw: Tween = create_tween()
	tw.tween_property(sprite, ^"modulate", Color(0.5, 2.5, 0.5, 1.0), 0.2)
	tw.tween_property(sprite, ^"modulate", Color.WHITE, 0.2)
	tw.tween_callback(func(): _fire_projectiles(player))


func _fire_projectiles(player: Player) -> void:
	if not is_instance_valid(player):
		return
	var base_dir: Vector2 = (player.global_position - global_position).normalized()

	# Fire 3 spread projectiles (or 6 if enraged!)
	var count: int = 6 if is_enraged else 3
	var spread_angle: float = PI * 0.4

	for i: int in range(count):
		var proj: BossProjectile = _proj_scene.instantiate() as BossProjectile
		var angle_offset: float = -spread_angle / 2.0 + (float(i) / float(maxi(count - 1, 1))) * spread_angle
		proj.direction = base_dir.rotated(angle_offset)
		proj.damage = roundi(damage * 0.8)
		proj.speed = data.projectile_speed if data != null else 150.0
		proj.global_position = global_position
		get_tree().current_scene.add_child(proj)


# ── Special Skill 3: Summon Minions ─────────────────────────────────────
func _start_summon() -> void:
	current_state = State.CASTING
	_state_timer = 0.6
	velocity = Vector2.ZERO

	var tw: Tween = create_tween()
	tw.tween_property(sprite, ^"scale", Vector2(1.8, 1.8), 0.3)
	tw.tween_property(sprite, ^"scale", Vector2(1.4, 1.4), 0.3)
	tw.tween_callback(_spawn_minions)


func _spawn_minions() -> void:
	var count: int = 3 if is_enraged else 2
	for i: int in range(count):
		var minion: EnemyBase = _enemy_base_scene.instantiate() as EnemyBase
		minion.setup(_spider_data, 0.8, 0.8, 1.1)
		var offset: Vector2 = Vector2(randf_range(-30, 30), randf_range(-30, 30))
		minion.global_position = global_position + offset
		get_tree().current_scene.add_child(minion)


func _process_casting(_delta: float) -> void:
	velocity = Vector2.ZERO
	if _state_timer <= 0.0:
		current_state = State.CHASE


# ── Contact Damage ──────────────────────────────────────────────────────
func _on_hitbox_body_entered(body: Node2D) -> void:
	if body is Player:
		var final_dmg: int = damage if current_state != State.CHARGING else roundi(damage * 1.5)
		(body as Player).take_damage(final_dmg)


# ── Damage & Enrage ─────────────────────────────────────────────────────
func take_damage(amount: int) -> void:
	current_hp = maxi(current_hp - amount, 0)
	boss_hp_changed.emit(current_hp, max_hp)

	# White hit flash
	var tw: Tween = create_tween()
	tw.tween_property(sprite, ^"modulate", Color(3.0, 3.0, 3.0, 1.0), 0.0)
	tw.tween_property(sprite, ^"modulate", Color.WHITE if not is_enraged else Color(1.2, 0.7, 0.7), 0.08)

	# Enrage check at 50% HP
	if not is_enraged and current_hp <= max_hp * 0.5:
		_trigger_enrage()

	if current_hp <= 0:
		die()


func _trigger_enrage() -> void:
	is_enraged = true
	speed *= 1.25
	sprite.modulate = Color(1.2, 0.7, 0.7, 1.0)
	# Shout shockwave pulse
	var tw: Tween = create_tween()
	tw.tween_property(self, ^"scale", Vector2(1.6, 1.6), 0.15)
	tw.tween_property(self, ^"scale", Vector2(1.3, 1.3), 0.15)


# ── Death ───────────────────────────────────────────────────────────────
func die() -> void:
	remove_from_group(&"enemies")
	remove_from_group(&"bosses")
	set_physics_process(false)
	hitbox.set_deferred(&"monitoring", false)
	collision_layer = 0
	collision_mask = 0

	var boss_id: String = data.enemy_id if data != null else "boss"
	EventBus.boss_killed.emit(boss_id)
	EventBus.floor_cleared.emit(GameManager.current_floor_index)
	boss_died.emit(boss_id)

	# Spawn wealth of gold
	var gold_count: int = randi_range(data.gold_drop_min, data.gold_drop_max) if data != null else 35
	for i: int in range(mini(gold_count / 3, 10)):
		var gold_pickup: GoldPickup = _gold_pickup_scene.instantiate() as GoldPickup
		gold_pickup.gold_amount = 3
		var offset: Vector2 = Vector2(randf_range(-25, 25), randf_range(-25, 25))
		gold_pickup.global_position = global_position + offset
		get_tree().current_scene.add_child(gold_pickup)

	# Dramatic slow scale-down and explode
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, ^"scale", Vector2(2.0, 2.0), 0.2)
	tw.tween_property(self, ^"modulate", Color(4.0, 4.0, 4.0, 1.0), 0.2)
	tw.chain().tween_property(self, ^"scale", Vector2.ZERO, 0.3)
	tw.parallel().tween_property(self, ^"modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(queue_free)


func _get_player() -> Player:
	var players: Array[Node] = get_tree().get_nodes_in_group(&"player")
	if players.size() > 0:
		return players[0] as Player
	return null
