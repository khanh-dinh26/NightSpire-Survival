class_name BossBase
extends CharacterBody2D
## Imposing Boss entity with smart multi-phase AI, unique skills, and enraged state.

signal boss_hp_changed(current_hp: int, max_hp: int)
signal boss_died(boss_name: String)

enum State {
	CHASE,
	TELEGRAPH_CHARGE,
	CHARGING,
	TELEGRAPH_SLAM,
	CASTING,
	STUNNED
}

@export var data: EnemyData = null

var max_hp: int = 500
var current_hp: int = 500
var damage: int = 15
var speed: float = 55.0
var hp_mult: float = 1.0
var dmg_mult: float = 1.0
var spd_mult: float = 1.0

var current_state: State = State.CHASE
var is_enraged: bool = false
var charge_direction: Vector2 = Vector2.ZERO
var charge_speed: float = 290.0

var _state_timer: float = 0.0
var _attack_cooldown_timer: float = 2.0
var _walk_phase: float = 0.0
var _surge_timer: float = 2.2
var _surge_duration: float = 0.0
var _is_dying: bool = false
var base_scale: Vector2 = Vector2(2.4, 2.4)

@onready var sprite: Sprite2D = $Sprite2D
@onready var hitbox: Area2D = $Hitbox
@onready var damage_cooldown: Timer = $DamageCooldown
@onready var boss_aura: BossAura = $BossAura
@onready var badge_anchor: Node2D = $BadgeAnchor
@onready var boss_badge: Label = $BadgeAnchor/BossBadge

# ── Preloaded textures ────────────────────────────────────────────────
var _monsters_tex: Texture2D = preload("res://assets/sprites/monsters.png")
var _animals_tex: Texture2D = preload("res://assets/sprites/animals.png")

# ── Scenes ─────────────────────────────────────────────────────────────
var _proj_scene: PackedScene = preload("res://src/entities/enemies/bosses/BossProjectile.tscn")
var _enemy_base_scene: PackedScene = preload("res://src/entities/enemies/EnemyBase.tscn")
var _gold_pickup_scene: PackedScene = preload("res://src/entities/pickups/GoldPickup.tscn")
var _spider_data: EnemyData = preload("res://src/data/enemies/spider.tres")


func setup(enemy_data: EnemyData, p_hp_mult: float = 1.0, p_dmg_mult: float = 1.0, p_spd_mult: float = 1.0) -> void:
	data = enemy_data
	hp_mult = p_hp_mult
	dmg_mult = p_dmg_mult
	spd_mult = p_spd_mult
	if is_node_ready():
		_apply_boss_data()


func _ready() -> void:
	add_to_group(&"enemies")
	add_to_group(&"bosses")

	_apply_boss_data()

	# Floating badge animation
	if badge_anchor != null:
		var badge_tw: Tween = create_tween().set_loops()
		badge_tw.tween_property(badge_anchor, ^"position:y", -28.0, 0.75).set_trans(Tween.TRANS_SINE)
		badge_tw.tween_property(badge_anchor, ^"position:y", -23.0, 0.75).set_trans(Tween.TRANS_SINE)

	# Subtle menacing breathing animation
	var breath_tw: Tween = create_tween().set_loops()
	breath_tw.tween_property(sprite, ^"scale", Vector2(1.03, 0.97), 0.55).set_trans(Tween.TRANS_SINE)
	breath_tw.tween_property(sprite, ^"scale", Vector2(0.97, 1.03), 0.55).set_trans(Tween.TRANS_SINE)

	hitbox.body_entered.connect(_on_hitbox_body_entered)
	_attack_cooldown_timer = 2.0


func _apply_boss_data() -> void:
	if sprite == null:
		return

	if data != null:
		max_hp = roundi(data.max_hp * hp_mult)
		damage = roundi(data.damage * dmg_mult)
		speed = data.speed * spd_mult

		if data.sprite_sheet == "animals":
			sprite.texture = _animals_tex
		else:
			sprite.texture = _monsters_tex
		sprite.region_enabled = true
		sprite.region_rect = data.sprite_region

		if data.enemy_type == EnemyData.EnemyType.FINAL_BOSS:
			base_scale = Vector2(2.9, 2.9)
			if boss_badge != null:
				boss_badge.text = "TRÙM CUỐI"
				boss_badge.set("theme_override_colors/font_color", Color(1.0, 0.35, 0.9, 1.0))
			if boss_aura != null:
				boss_aura.is_final = true
		else:
			base_scale = Vector2(2.4, 2.4)
			if boss_badge != null:
				boss_badge.text = "TRÙM"
				boss_badge.set("theme_override_colors/font_color", Color(1.0, 0.85, 0.2, 1.0))
	else:
		sprite.texture = _monsters_tex
		sprite.region_enabled = true
		sprite.region_rect = Rect2(64, 224, 32, 32)
		base_scale = Vector2(2.4, 2.4)

	scale = base_scale
	current_hp = max_hp
	boss_hp_changed.emit(current_hp, max_hp)


func _physics_process(delta: float) -> void:
	if _is_dying:
		return

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
			_process_telegraph_charge(delta)
		State.CHARGING:
			_process_charging(delta)
		State.TELEGRAPH_SLAM:
			_process_telegraph_slam(delta, player)
		State.CASTING:
			_process_casting(delta)
		State.STUNNED:
			_process_stunned(delta)

	move_and_slide()


# ── Smart Movement & Dynamic AI ──────────────────────────────────────────
func _process_chase(delta: float, player: Player, to_player: Vector2) -> void:
	var dist: float = global_position.distance_to(player.global_position)
	var is_caster: bool = (data != null and (
		data.attack_pattern in ["projectile", "spiral_projectile", "summon"] or
		data.enemy_id in ["lich", "shadow_fiend", "necromancer_lord", "void_overlord", "venom_manticore"]
	))

	# Surge / Aggressive Gap-closer timer
	if _surge_timer > 0.0:
		_surge_timer -= delta
	elif dist > 130.0:
		_surge_timer = randf_range(2.6, 3.8)
		_surge_duration = 0.38

	if _surge_duration > 0.0:
		_surge_duration -= delta
		velocity = to_player * speed * (1.85 if not is_enraged else 2.25)
	elif is_caster:
		# Caster bosses maintain strategic combat distance (110 - 180px)
		if dist < 85.0:
			# Fast defensive backstep when player rushes in
			var retreat_dir: Vector2 = (-to_player * 0.9 + to_player.orthogonal() * sin(_walk_phase) * 0.45).normalized()
			velocity = retreat_dir * speed * 1.5
		elif dist < 120.0:
			var retreat_dir: Vector2 = (-to_player * 0.8 + to_player.orthogonal() * sin(_walk_phase) * 0.6).normalized()
			velocity = retreat_dir * speed * 1.15
		elif dist > 195.0:
			# Advance with weaving motion
			var advance_dir: Vector2 = (to_player * 0.85 + to_player.orthogonal() * sin(_walk_phase) * 0.5).normalized()
			velocity = advance_dir * speed
		else:
			# Orbit around player laterally
			var orbit_sign: float = 1.0 if int(_walk_phase * 0.4) % 2 == 0 else -1.0
			var orbit_dir: Vector2 = (to_player.orthogonal() * orbit_sign + to_player * 0.15 * sin(_walk_phase)).normalized()
			velocity = orbit_dir * speed * 0.95
	else:
		# Melee bruiser: Weave and flank dynamically rather than walking straight
		var flank_dir: Vector2 = (to_player * 0.85 + to_player.orthogonal() * sin(_walk_phase * 2.2) * 0.55).normalized()
		velocity = flank_dir * speed

	_walk_phase += delta * (8.0 if not is_enraged else 12.0)
	sprite.position.y = -roundf(abs(sin(_walk_phase)) * 2.0)

	# Special attack check
	if _attack_cooldown_timer <= 0.0:
		_choose_attack(player, dist, is_caster)


func _choose_attack(player: Player, dist: float, is_caster: bool) -> void:
	var cooldown_base: float = data.attack_cooldown if data != null else 2.6
	_attack_cooldown_timer = cooldown_base * (0.65 if is_enraged else 1.0)

	var pattern: String = data.attack_pattern if data != null else "mixed"

	match pattern:
		"ground_slam":
			var roll_gs: float = randf()
			if roll_gs < 0.35:
				_start_spiral_barrage()
			elif roll_gs < 0.75 or dist < 90.0:
				_start_ground_slam(player)
			else:
				_start_charge(player)

		"charge":
			var roll_c: float = randf()
			if roll_c < 0.35:
				_start_projectile_attack(player)
			elif roll_c < 0.75:
				_start_charge(player)
			else:
				_start_ground_slam(player)

		"spiral_projectile":
			if randf() < 0.5:
				_start_spiral_barrage()
			elif randf() < 0.8:
				_start_projectile_attack(player)
			else:
				_start_summon()

		"projectile":
			if randf() < 0.55:
				_start_projectile_attack(player)
			elif randf() < 0.85:
				_start_spiral_barrage()
			else:
				_start_charge(player)

		"summon":
			if randf() < 0.4:
				_start_summon()
			elif randf() < 0.7:
				_start_spiral_barrage()
			else:
				_start_projectile_attack(player)

		_:
			# Mixed / Final bosses (access to full arsenal)
			if dist < 75.0:
				_start_ground_slam(player)
			elif dist > 170.0 and not is_caster:
				_start_charge(player)
			else:
				var roll: float = randf()
				if roll < 0.28:
					_start_spiral_barrage()
				elif roll < 0.55:
					_start_projectile_attack(player)
				elif roll < 0.78:
					_start_ground_slam(player)
				elif roll < 0.90:
					_start_charge(player)
				else:
					_start_summon()


# ── Skill 1: Charge Dash ────────────────────────────────────────────────
func _start_charge(player: Player) -> void:
	current_state = State.TELEGRAPH_CHARGE
	_state_timer = 0.55
	velocity = Vector2.ZERO
	charge_direction = (player.global_position - global_position).normalized()

	# Red telegraph flash
	var tw: Tween = create_tween()
	tw.set_loops(3)
	tw.tween_property(sprite, ^"modulate", Color(3.0, 0.4, 0.4, 1.0), 0.09)
	tw.tween_property(sprite, ^"modulate", Color.WHITE if not is_enraged else Color(1.3, 0.6, 0.6), 0.09)


func _process_telegraph_charge(_delta: float) -> void:
	velocity = Vector2.ZERO
	if _state_timer <= 0.0:
		current_state = State.CHARGING
		_state_timer = 0.5
		AudioManager.play_sfx("slash")


func _process_charging(_delta: float) -> void:
	velocity = charge_direction * (charge_speed * (1.25 if is_enraged else 1.0))
	if _state_timer <= 0.0:
		current_state = State.STUNNED
		_state_timer = 0.35


# ── Skill 2: Ground Slam / Shockwave ────────────────────────────────────
func _start_ground_slam(_player: Player) -> void:
	current_state = State.TELEGRAPH_SLAM
	_state_timer = 0.6
	velocity = Vector2.ZERO

	# Leap up & warning glow
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(sprite, ^"position:y", -16.0, 0.25).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, ^"scale", Vector2(1.25, 1.25), 0.25)
	tw.tween_property(sprite, ^"modulate", Color(3.0, 1.0, 0.3, 1.0), 0.25)


func _process_telegraph_slam(_delta: float, player: Player) -> void:
	velocity = Vector2.ZERO
	if _state_timer <= 0.0:
		_execute_ground_slam(player)


func _execute_ground_slam(player: Player) -> void:
	current_state = State.STUNNED
	_state_timer = 0.4
	velocity = Vector2.ZERO

	# Slam down impact animation
	sprite.position.y = 0.0
	var tw: Tween = create_tween()
	tw.tween_property(sprite, ^"scale", Vector2(1.3, 0.7), 0.08)
	tw.tween_property(sprite, ^"scale", Vector2.ONE, 0.12)
	tw.parallel().tween_property(sprite, ^"modulate", Color.WHITE if not is_enraged else Color(1.3, 0.6, 0.6), 0.15)

	AudioManager.play_sfx("explosion")

	# Area slam damage to nearby player
	if is_instance_valid(player):
		var dist_to_player: float = global_position.distance_to(player.global_position)
		if dist_to_player <= 75.0:
			player.take_damage(roundi(damage * 1.35))
			var knock_dir: Vector2 = (player.global_position - global_position).normalized()
			if knock_dir == Vector2.ZERO:
				knock_dir = Vector2.DOWN
			player.velocity += knock_dir * 240.0

	# 8-Direction Expanding Shockwave Projectiles
	var spike_count: int = 12 if is_enraged else 8
	for i: int in range(spike_count):
		var proj: BossProjectile = _proj_scene.instantiate() as BossProjectile
		var angle: float = (float(i) / float(spike_count)) * TAU
		proj.direction = Vector2.RIGHT.rotated(angle)
		proj.damage = roundi(damage * 0.7)
		proj.speed = 135.0
		proj.global_position = global_position
		get_tree().current_scene.add_child(proj)


# ── Skill 3: Spiral Nova Barrage ────────────────────────────────────────
func _start_spiral_barrage() -> void:
	current_state = State.CASTING
	_state_timer = 0.5
	velocity = Vector2.ZERO

	# Mystic violet glow
	var tw: Tween = create_tween()
	tw.tween_property(sprite, ^"modulate", Color(2.0, 0.5, 3.0, 1.0), 0.2)
	tw.tween_property(sprite, ^"modulate", Color.WHITE if not is_enraged else Color(1.3, 0.6, 0.6), 0.2)
	tw.tween_callback(_fire_spiral_projectiles)


func _fire_spiral_projectiles() -> void:
	AudioManager.play_sfx("slash")
	var count: int = 12 if is_enraged else 8
	var base_offset: float = randf() * TAU
	for i: int in range(count):
		var proj: BossProjectile = _proj_scene.instantiate() as BossProjectile
		var angle: float = base_offset + (float(i) / float(count)) * TAU
		proj.direction = Vector2.RIGHT.rotated(angle)
		proj.damage = roundi(damage * 0.75)
		proj.speed = 145.0
		proj.global_position = global_position
		get_tree().current_scene.add_child(proj)


# ── Skill 4: Targeted Projectile Volley ─────────────────────────────────
func _start_projectile_attack(player: Player) -> void:
	current_state = State.CASTING
	_state_timer = 0.45
	velocity = Vector2.ZERO

	# Emerald channel glow
	var tw: Tween = create_tween()
	tw.tween_property(sprite, ^"modulate", Color(0.4, 3.0, 0.6, 1.0), 0.2)
	tw.tween_property(sprite, ^"modulate", Color.WHITE if not is_enraged else Color(1.3, 0.6, 0.6), 0.2)
	tw.tween_callback(func(): _fire_projectiles(player))


func _fire_projectiles(player: Player) -> void:
	if not is_instance_valid(player):
		return
	var base_dir: Vector2 = (player.global_position - global_position).normalized()
	AudioManager.play_sfx("slash")

	var count: int = 6 if is_enraged else 4
	var spread_angle: float = PI * 0.4

	for i: int in range(count):
		var proj: BossProjectile = _proj_scene.instantiate() as BossProjectile
		var angle_offset: float = -spread_angle / 2.0 + (float(i) / float(maxi(count - 1, 1))) * spread_angle
		proj.direction = base_dir.rotated(angle_offset)
		proj.damage = roundi(damage * 0.8)
		proj.speed = data.projectile_speed if data != null else 150.0
		proj.global_position = global_position
		get_tree().current_scene.add_child(proj)


# ── Skill 5: Summon Minions ─────────────────────────────────────────────
func _start_summon() -> void:
	current_state = State.CASTING
	_state_timer = 0.6
	velocity = Vector2.ZERO

	var tw: Tween = create_tween()
	tw.tween_property(sprite, ^"scale", Vector2(1.25, 1.25), 0.3)
	tw.tween_property(sprite, ^"scale", Vector2.ONE, 0.3)
	tw.tween_callback(_spawn_minions)


func _spawn_minions() -> void:
	AudioManager.play_sfx("enemy_death")
	var count: int = 3 if is_enraged else 2
	for i: int in range(count):
		var minion: EnemyBase = _enemy_base_scene.instantiate() as EnemyBase
		minion.setup(_spider_data, 0.8, 0.8, 1.1)
		var offset: Vector2 = Vector2(randf_range(-35, 35), randf_range(-35, 35))
		minion.global_position = global_position + offset
		get_tree().current_scene.add_child(minion)


func _process_casting(_delta: float) -> void:
	velocity = Vector2.ZERO
	if _state_timer <= 0.0:
		current_state = State.CHASE


func _process_stunned(_delta: float) -> void:
	velocity = Vector2.ZERO
	if _state_timer <= 0.0:
		current_state = State.CHASE


# ── Contact Damage ──────────────────────────────────────────────────────
func _on_hitbox_body_entered(body: Node2D) -> void:
	if _is_dying:
		return
	if body is Player:
		var final_dmg: int = damage if current_state != State.CHARGING else roundi(damage * 1.5)
		(body as Player).take_damage(final_dmg)


# ── Damage & Enrage ─────────────────────────────────────────────────────
func take_damage(amount: int) -> void:
	if _is_dying:
		return

	if has_meta("marked"):
		amount = roundi(float(amount) * 1.6)
	EventBus.player_dealt_damage.emit(amount)

	current_hp = maxi(current_hp - amount, 0)
	boss_hp_changed.emit(current_hp, max_hp)

	# White hit flash
	var tw: Tween = create_tween()
	tw.tween_property(sprite, ^"modulate", Color(3.0, 3.0, 3.0, 1.0), 0.0)
	tw.tween_property(sprite, ^"modulate", Color.WHITE if not is_enraged else Color(1.3, 0.6, 0.6), 0.08)

	# Enrage check at 50% HP
	if not is_enraged and current_hp <= max_hp * 0.5:
		_trigger_enrage()

	if current_hp <= 0:
		die()


func _trigger_enrage() -> void:
	is_enraged = true
	speed *= 1.3
	sprite.modulate = Color(1.35, 0.55, 0.45, 1.0)
	if boss_aura != null:
		boss_aura.is_enraged = true
	if boss_badge != null:
		boss_badge.text = "🔥 NỔI GIẬN! 🔥"
		boss_badge.set("theme_override_colors/font_color", Color(1.0, 0.25, 0.1, 1.0))
	AudioManager.play_sfx("explosion")

	# Enrage roar pulse
	var tw: Tween = create_tween()
	tw.tween_property(self, ^"scale", base_scale * 1.3, 0.15)
	tw.tween_property(self, ^"scale", base_scale, 0.15)


# ── Death ───────────────────────────────────────────────────────────────
func die() -> void:
	if _is_dying:
		return
	_is_dying = true

	remove_from_group(&"enemies")
	remove_from_group(&"bosses")
	set_physics_process(false)
	hitbox.set_deferred(&"monitoring", false)
	set_deferred(&"collision_layer", 0)
	set_deferred(&"collision_mask", 0)

	var boss_id: String = data.enemy_id if data != null else "boss"
	EventBus.boss_killed.emit(boss_id)
	boss_died.emit(boss_id)

	# Spawn wealth of gold
	var gold_count: int = randi_range(data.gold_drop_min, data.gold_drop_max) if data != null else 35
	for i: int in range(mini(gold_count / 3, 10)):
		var gold_pickup: GoldPickup = _gold_pickup_scene.instantiate() as GoldPickup
		gold_pickup.gold_amount = 3
		var offset: Vector2 = Vector2(randf_range(-25, 25), randf_range(-25, 25))
		gold_pickup.global_position = global_position + offset
		get_tree().current_scene.call_deferred(&"add_child", gold_pickup)

	# Dramatic slow scale-down and explode
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, ^"scale", base_scale * 1.4, 0.2)
	tw.tween_property(self, ^"modulate", Color(4.0, 4.0, 4.0, 1.0), 0.2)
	tw.chain().tween_property(self, ^"scale", Vector2.ZERO, 0.3)
	tw.parallel().tween_property(self, ^"modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(queue_free)


func _get_player() -> Player:
	var players: Array[Node] = get_tree().get_nodes_in_group(&"player")
	if players.size() > 0:
		return players[0] as Player
	return null
