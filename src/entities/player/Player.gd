class_name Player
extends CharacterBody2D
## Player character — 8-directional movement, responsive attack, walk bobbing/tilting, sprite direction facing.

# ── Stats ──────────────────────────────────────────────────────────────
var max_hp: int = 100
var current_hp: int = 100
var speed: float = 130.0
var defense: int = 0
var is_dead: bool = false
var magnet_range: float = 60.0
var luck_stat: float = 0.0
var dodge_chance: float = 0.0
var has_vampire_chalice: bool = false
var kills_counter: int = 0

# ── Node references ────────────────────────────────────────────────────
@onready var sprite: Sprite2D = $Sprite2D
@onready var weapon_orbit: WeaponOrbit = $WeaponOrbit

var _spell_scene: PackedScene = preload("res://src/entities/spells/SpellEntity.tscn")
var _cursor_aim_tex: Texture2D = preload("res://assets/ui/cursors/all_scroll_cursor.png")
var _molten_spear_frames: SpriteFrames = preload("res://src/entities/spells/molten_spear_frames.tres")
var _impact_exp_frames: SpriteFrames = preload("res://assets/fx/impact_fx/impact_explosion_frames.tres")
var _impact_slash_frames: SpriteFrames = preload("res://assets/fx/impact_fx/impact_slash_frames.tres")
var _impact_burst_frames: SpriteFrames = preload("res://assets/fx/impact_fx/impact_burst_frames.tres")
var _target_indicator: SkillTargetIndicator = null

# ── Hero Abilities (Single Ultimate System) ─────────────────────────────
var hero_class: ClassData = null
var skill_cooldown_timer: float = 0.0
var skill_cooldown_max: float = 7.0
var ultimate_charge: int = 0
var ultimate_required_damage: int = 650
var is_stealthed: bool = false
var is_invincible: bool = false
var is_aiming_ability: bool = false
var is_aiming_skill: bool = false # Compatibility
var _is_executing_ability: bool = false
var _block_ult_charge_timer: float = 0.0

# ── Procedural animation timers ────────────────────────────────────────
var _walk_phase: float = 0.0
var _idle_phase: float = 0.0
var _facing_right: bool = false
var _is_hit_animating: bool = false


func _ready() -> void:
	add_to_group(&"player")
	EventBus.spell_cast_requested.connect(_on_spell_cast_requested)
	EventBus.player_dealt_damage.connect(_on_player_dealt_damage)
	ultimate_charge = GameManager.hero_ultimate_charge

	if GameManager.chosen_class == null:
		var default_path: String = "res://src/data/classes/knight.tres"
		if ResourceLoader.exists(default_path):
			GameManager.chosen_class = load(default_path) as ClassData

	if GameManager.chosen_class != null:
		setup_from_class(GameManager.chosen_class)
		if GameManager.player_current_hp > 0:
			current_hp = GameManager.player_current_hp
			max_hp = GameManager.player_max_hp
	else:
		if GameManager.player_current_hp > 0:
			current_hp = GameManager.player_current_hp
			max_hp = GameManager.player_max_hp
		else:
			current_hp = max_hp
		if weapon_orbit != null:
			weapon_orbit.clear_weapons()
			if GameManager.equipped_weapons.is_empty():
				var starter: ItemData = preload("res://src/data/items/weapons/starter_dagger.tres")
				GameManager.equipped_weapons.append(starter)
				weapon_orbit.add_weapon(starter)
			else:
				for w: ItemData in GameManager.equipped_weapons:
					weapon_orbit.add_weapon(w)

	# Apply any existing passives
	for buff: ItemData in GameManager.passive_buffs:
		apply_item(buff)


func _process(delta: float) -> void:
	if skill_cooldown_timer > 0.0:
		skill_cooldown_timer = maxf(skill_cooldown_timer - delta, 0.0)
		EventBus.hero_skill_cooldown_updated.emit(skill_cooldown_timer, skill_cooldown_max)
	if _block_ult_charge_timer > 0.0:
		_block_ult_charge_timer = maxf(_block_ult_charge_timer - delta, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E or event.keycode == KEY_Q or event.keycode == KEY_SPACE:
			cast_ultimate_ability()
		elif event.keycode == KEY_ESCAPE and is_aiming_ability:
			cancel_ability_aiming()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and is_aiming_ability:
			execute_ultimate_ability()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT and is_aiming_ability:
			cancel_ability_aiming()
			get_viewport().set_input_as_handled()


func setup_from_class(p_class: ClassData) -> void:
	if p_class == null:
		return
	hero_class = p_class
	max_hp = p_class.max_hp
	current_hp = max_hp
	speed = p_class.speed
	defense = p_class.defense
	sprite.region_rect = p_class.sprite_region

	if hero_class != null:
		skill_cooldown_max = hero_class.skill_cooldown
		ultimate_required_damage = hero_class.ultimate_required_damage
		EventBus.hero_skill_cooldown_updated.emit(skill_cooldown_timer, skill_cooldown_max)
		EventBus.hero_ultimate_charge_updated.emit(ultimate_charge, ultimate_required_damage)

	if weapon_orbit != null:
		weapon_orbit.clear_weapons()
		for w: ItemData in GameManager.equipped_weapons:
			weapon_orbit.add_weapon(w)


func _on_player_dealt_damage(amount: int) -> void:
	if is_dead or _is_executing_ability or _block_ult_charge_timer > 0.0:
		return
	if ultimate_charge < ultimate_required_damage:
		ultimate_charge = mini(ultimate_charge + amount, ultimate_required_damage)
		GameManager.hero_ultimate_charge = ultimate_charge
		EventBus.hero_ultimate_charge_updated.emit(ultimate_charge, ultimate_required_damage)


# ── Movement & Procedural Animation ─────────────────────────────────────
func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		return

	var input_dir: Vector2 = Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_action_pressed(&"ui_left"):
		input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_action_pressed(&"ui_right"):
		input_dir.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_action_pressed(&"ui_up"):
		input_dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_action_pressed(&"ui_down"):
		input_dir.y += 1.0

	if input_dir != Vector2.ZERO:
		input_dir = input_dir.normalized()

	var current_spd: float = speed
	if GameManager.current_tower != null:
		current_spd *= GameManager.current_tower.player_speed_mult
	velocity = input_dir * current_spd
	move_and_slide()

	# Flip sprite based on movement direction (sprite naturally faces left in spritesheet)
	if input_dir.x > 0.0:
		_facing_right = true
	elif input_dir.x < 0.0:
		_facing_right = false

	sprite.flip_h = _facing_right

	# Handle walking vs idle bounce animation
	_animate_character(delta, input_dir)


func _animate_character(delta: float, input_dir: Vector2) -> void:
	if _is_hit_animating:
		return

	if input_dir != Vector2.ZERO:
		# Walking: pixel-perfect bounce + integer tilt
		_walk_phase += delta * 14.0

		# Step bounce strictly snapped to integer pixels (0, -1, -2, -3, -2, -1, 0)
		var bounce_px: float = -roundf(abs(sin(_walk_phase)) * 3.0)
		sprite.position.y = bounce_px

		# Integer rotation degrees for clean pixel rasterization
		var sway_tilt: float = roundf(sin(_walk_phase) * 6.0)

		# Front / back tilt modifier
		var forward_back_tilt: float = 0.0
		if input_dir.y > 0.1: # moving down (forward)
			forward_back_tilt = 3.0 if _facing_right else -3.0
		elif input_dir.y < -0.1: # moving up (backward)
			forward_back_tilt = -3.0 if _facing_right else 3.0

		sprite.rotation_degrees = sway_tilt + forward_back_tilt
		sprite.scale = Vector2.ONE
	else:
		# Idle: return position and rotation to zero cleanly
		_walk_phase = 0.0
		_idle_phase += delta * 3.5

		sprite.position.y = move_toward(sprite.position.y, 0.0, delta * 20.0)
		sprite.rotation_degrees = move_toward(sprite.rotation_degrees, 0.0, delta * 30.0)

		# Subtle 1-pixel breathing bounce
		var breathe_px: float = -roundf(abs(sin(_idle_phase)) * 1.0)
		sprite.position.y = breathe_px
		sprite.scale = Vector2.ONE


# ── Item & Buff Application ───────────────────────────────────────────
func apply_item(item: ItemData) -> void:
	if item.type == ItemData.ItemType.WEAPON:
		if weapon_orbit != null:
			weapon_orbit.add_weapon(item)
	elif item.type == ItemData.ItemType.PASSIVE_BUFF:
		for stat: String in item.stats_modifier:
			var val: Variant = item.stats_modifier[stat]
			match stat:
				"max_hp":
					var add_hp: int = int(val)
					max_hp += add_hp
					current_hp += add_hp
				"speed":
					speed += float(val)
				"defense":
					defense += int(val)
				"instant_heal":
					current_hp = mini(current_hp + int(val), max_hp)
				"magnet_range":
					magnet_range += 50.0
				"luck":
					luck_stat += float(val)
				"dodge_chance":
					dodge_chance += float(val)
				"vampire_chalice":
					has_vampire_chalice = true
				"damage_mult":
					if weapon_orbit != null:
						for w: WeaponBase in weapon_orbit.weapons:
							if w.item_data != null:
								w.item_data.base_damage = roundi(w.item_data.base_damage * (1.0 + float(val)))

		GameManager.player_max_hp = max_hp
		GameManager.player_current_hp = current_hp
		EventBus.player_hit.emit(0)


# ── Damage ─────────────────────────────────────────────────────────────
func take_damage(amount: int) -> void:
	if is_dead or is_invincible or is_stealthed:
		return

	# Dodge chance
	if dodge_chance > 0.0 and randf() < dodge_chance:
		# Dodged cleanly!
		return

	var final_amount: int = amount
	if GameManager.current_tower != null:
		final_amount = roundi(float(amount) * GameManager.current_tower.player_dmg_taken_mult)
	var effective: int = maxi(final_amount - defense, 1)
	current_hp -= effective
	GameManager.player_current_hp = current_hp

	EventBus.player_hit.emit(effective)
	_hit_flash()

	if current_hp <= 0:
		current_hp = 0
		is_dead = true
		cancel_ability_aiming()
		velocity = Vector2.ZERO
		set_physics_process(false)
		collision_layer = 0
		collision_mask = 0
		_is_hit_animating = false
		sprite.rotation_degrees = 90.0
		sprite.modulate = Color(0.7, 0.2, 0.2, 0.7)

		# Silence all attacking weapons and spells on player
		if weapon_orbit != null:
			weapon_orbit.set_process(false)
			for w: Node in weapon_orbit.get_children():
				w.set_process(false)
				w.set_physics_process(false)

		EventBus.player_died.emit()


func cancel_ability_aiming() -> void:
	if is_aiming_ability or is_aiming_skill:
		is_aiming_ability = false
		is_aiming_skill = false
		Input.set_custom_mouse_cursor(null)
		_cleanup_target_indicator()
		EventBus.hero_skill_aiming_changed.emit(false)


func cancel_skill_aiming() -> void:
	cancel_ability_aiming()


func _spawn_target_indicator(p_skill_id: String) -> void:
	_cleanup_target_indicator()
	_target_indicator = SkillTargetIndicator.new()
	var cls_id: String = hero_class.class_id if hero_class != null else ""
	if cls_id == "knight" or p_skill_id in ["knight_leap", "onslaught_stake", "magic_cocktail", "claw_shot"]:
		_target_indicator.skill_type = "knight_leap"
		_target_indicator.aoe_radius = 150.0
	elif cls_id == "ranger" or p_skill_id in ["ranger_piercing_spear", "single_shot", "marking_dash"]:
		_target_indicator.skill_type = "ranger_piercing_spear"
	elif cls_id == "wizard" or p_skill_id in ["wizard_blood_siphon", "soulblood_song"]:
		_target_indicator.skill_type = "wizard_blood_siphon"
		_target_indicator.aoe_radius = 180.0
	else:
		_target_indicator.skill_type = p_skill_id
	_target_indicator.player = self
	get_tree().current_scene.add_child(_target_indicator)


func _cleanup_target_indicator() -> void:
	if _target_indicator != null and is_instance_valid(_target_indicator):
		_target_indicator.queue_free()
	_target_indicator = null


func _exit_tree() -> void:
	cancel_ability_aiming()


func heal(amount: int) -> void:
	var final_amount: int = amount
	if GameManager.current_tower != null:
		final_amount = maxi(1, roundi(float(amount) * GameManager.current_tower.player_heal_mult))
	current_hp = mini(current_hp + final_amount, max_hp)
	GameManager.player_current_hp = current_hp
	AudioManager.play_sfx("heal")
	EventBus.player_hit.emit(0)


# ── Hit flash + squash effect ──────────────────────────────────────────
func _hit_flash() -> void:
	_is_hit_animating = true
	var tw: Tween = create_tween()
	tw.set_parallel(true)

	# White flash
	tw.tween_property(sprite, ^"modulate", Color(3.0, 3.0, 3.0, 1.0), 0.0)
	tw.tween_property(sprite, ^"modulate", Color(1.0, 1.0, 1.0, 1.0), 0.1).set_delay(0.08)

	# Squash
	tw.tween_property(sprite, ^"scale", Vector2(1.3, 0.7), 0.05)
	tw.tween_property(sprite, ^"scale", Vector2(1.0, 1.0), 0.1).set_delay(0.05)

	tw.chain().tween_callback(func(): _is_hit_animating = false)


# ── Active Spell Casting ────────────────────────────────────────────────
func _on_spell_cast_requested(spell_id: String, p_level: int, target_pos: Vector2) -> void:
	var aim_dir: Vector2 = (target_pos - global_position).normalized()
	if aim_dir == Vector2.ZERO:
		aim_dir = Vector2.RIGHT if _facing_right else Vector2.LEFT

	match spell_id:
		"fireball":
			_cast_fireball(p_level, aim_dir)
		"molten_spear":
			_cast_molten_spear(p_level, aim_dir)
		"tornado":
			_cast_tornado(p_level, aim_dir)
		"earth_spike":
			_cast_earth_spike(p_level, target_pos)
		"water_geyser":
			_cast_water_geyser(p_level, target_pos)
		"void_portal":
			_cast_void_portal(p_level, target_pos)
		"meteor_rock":
			_cast_meteor_rock(p_level, target_pos)


func _cast_fireball(lvl: int, base_dir: Vector2) -> void:
	AudioManager.play_sfx("spell_fire")
	var count: int = lvl
	var spread_angle: float = 0.22 # ~12.5 degrees

	for i: int in range(count):
		var angle_offset: float = 0.0
		if count > 1:
			angle_offset = (float(i) - float(count - 1) / 2.0) * spread_angle

		var fire_dir: Vector2 = base_dir.rotated(angle_offset)
		var spell: SpellEntity = _spell_scene.instantiate() as SpellEntity
		spell.spell_type = SpellEntity.SpellType.FIREBALL
		spell.level = lvl
		spell.damage = 25 + (lvl - 1) * 12
		spell.direction = fire_dir
		spell.global_position = global_position
		get_tree().current_scene.add_child(spell)


func _cast_molten_spear(lvl: int, base_dir: Vector2) -> void:
	AudioManager.play_sfx("spell_fire")
	var count: int = lvl
	for i: int in range(count):
		var offset_perp: Vector2 = base_dir.orthogonal() * ((float(i) - float(count - 1) / 2.0) * 14.0)
		var spell: SpellEntity = _spell_scene.instantiate() as SpellEntity
		spell.spell_type = SpellEntity.SpellType.MOLTEN_SPEAR
		spell.level = lvl
		spell.damage = 35 + (lvl - 1) * 18
		spell.direction = base_dir
		spell.global_position = global_position + offset_perp
		get_tree().current_scene.add_child(spell)


func _cast_tornado(lvl: int, base_dir: Vector2) -> void:
	AudioManager.play_sfx("spell_wind")
	var count: int = mini(lvl, 3)
	for i: int in range(count):
		var angle_offset: float = 0.0
		if count > 1:
			angle_offset = (float(i) - float(count - 1) / 2.0) * 0.35

		var spell: SpellEntity = _spell_scene.instantiate() as SpellEntity
		spell.spell_type = SpellEntity.SpellType.TORNADO
		spell.level = lvl
		spell.damage = 18 + (lvl - 1) * 8
		spell.direction = base_dir.rotated(angle_offset)
		spell.global_position = global_position
		get_tree().current_scene.add_child(spell)


func _cast_earth_spike(lvl: int, target_pos: Vector2) -> void:
	AudioManager.play_sfx("spell_earth")
	var count: int = 1 + (lvl - 1) * 2
	var offsets: Array[Vector2] = [Vector2.ZERO]

	if count >= 3:
		offsets.append(Vector2(24, 0))
		offsets.append(Vector2(-24, 0))
	if count >= 5:
		offsets.append(Vector2(0, 24))
		offsets.append(Vector2(0, -24))

	for offset: Vector2 in offsets:
		var spell: SpellEntity = _spell_scene.instantiate() as SpellEntity
		spell.spell_type = SpellEntity.SpellType.EARTH_SPIKE
		spell.level = lvl
		spell.damage = 40 + (lvl - 1) * 20
		spell.global_position = target_pos + offset
		get_tree().current_scene.add_child(spell)


func _cast_water_geyser(lvl: int, target_pos: Vector2) -> void:
	AudioManager.play_sfx("spell_water")
	var count: int = 1 + (lvl - 1)
	for i: int in range(count):
		var offset: Vector2 = Vector2.ZERO if i == 0 else Vector2(randf_range(-25.0, 25.0), randf_range(-25.0, 25.0))
		var spell: SpellEntity = _spell_scene.instantiate() as SpellEntity
		spell.spell_type = SpellEntity.SpellType.WATER_GEYSER
		spell.level = lvl
		spell.damage = 45 + (lvl - 1) * 22
		spell.global_position = target_pos + offset
		get_tree().current_scene.add_child(spell)


func _cast_void_portal(lvl: int, target_pos: Vector2) -> void:
	AudioManager.play_sfx("spell_earth")
	var spell: SpellEntity = _spell_scene.instantiate() as SpellEntity
	spell.spell_type = SpellEntity.SpellType.VOID_PORTAL
	spell.level = lvl
	spell.damage = 18 + (lvl - 1) * 8
	spell.global_position = target_pos
	get_tree().current_scene.add_child(spell)


func _cast_meteor_rock(lvl: int, target_pos: Vector2) -> void:
	AudioManager.play_sfx("spell_earth")
	AudioManager.play_sfx("impact_heavy")
	var count: int = 1 + (lvl - 1)
	for i: int in range(count):
		var offset: Vector2 = Vector2.ZERO if i == 0 else Vector2(randf_range(-30.0, 30.0), randf_range(-30.0, 30.0))
		var spell: SpellEntity = _spell_scene.instantiate() as SpellEntity
		spell.spell_type = SpellEntity.SpellType.METEOR_ROCK
		spell.level = lvl
		spell.damage = 55 + (lvl - 1) * 25
		spell.global_position = target_pos + offset
		get_tree().current_scene.add_child(spell)


# ── Hero Ultimate Ability System (1 Ultimate Per Class) ───────────────
func cast_ultimate_ability() -> bool:
	if is_dead:
		return false
	if hero_class == null or hero_class.ultimate_id.is_empty():
		return false

	if not is_aiming_ability:
		# Check if ultimate is fully charged
		if ultimate_charge < ultimate_required_damage:
			return false
		# Open aiming mode!
		is_aiming_ability = true
		is_aiming_skill = true
		Input.set_custom_mouse_cursor(_cursor_aim_tex, Input.CURSOR_ARROW, Vector2(16, 16))
		_spawn_target_indicator(hero_class.ultimate_id)
		EventBus.hero_skill_aiming_changed.emit(true)
		return true
	else:
		# 2nd press confirms and executes!
		return execute_ultimate_ability()


func execute_ultimate_ability() -> bool:
	if is_dead or ultimate_charge < ultimate_required_damage:
		cancel_ability_aiming()
		return false
	if hero_class == null or hero_class.ultimate_id.is_empty():
		cancel_ability_aiming()
		return false

	cancel_ability_aiming()

	ultimate_charge = 0
	GameManager.hero_ultimate_charge = 0
	_is_executing_ability = true
	_block_ult_charge_timer = 0.8
	EventBus.hero_ultimate_used.emit(hero_class.ultimate_id)
	EventBus.hero_ultimate_charge_updated.emit(0, ultimate_required_damage)

	var mouse_pos: Vector2 = get_global_mouse_position()
	var aim_dir: Vector2 = (mouse_pos - global_position).normalized()
	if aim_dir == Vector2.ZERO:
		aim_dir = Vector2.LEFT if sprite.flip_h else Vector2.RIGHT

	var ult_id: String = hero_class.ultimate_id
	var cls_id: String = hero_class.class_id

	if cls_id == "knight" or ult_id in ["knight_leap", "onslaught_stake", "claw_shot", "magic_cocktail"]:
		_execute_knight_leap(mouse_pos)
	elif cls_id == "ranger" or ult_id in ["ranger_piercing_spear", "single_shot", "marking_dash"]:
		_execute_ranger_piercing_spear(aim_dir)
	elif cls_id == "wizard" or ult_id in ["wizard_blood_siphon", "soulblood_song"]:
		_execute_wizard_blood_siphon()
	elif ult_id == "wings_of_salvation":
		_execute_wings_of_salvation()
	elif ult_id == "finale":
		_execute_finale()
	elif ult_id == "crucible_beast":
		_execute_crucible_beast()
	else:
		_execute_knight_leap(mouse_pos)

	_is_executing_ability = false
	return true


# Compatibility aliases
func cast_character_skill() -> bool:
	return cast_ultimate_ability()


func cast_ultimate_art() -> bool:
	return cast_ultimate_ability()


# ── Ultimate 1: Hiệp Sĩ (Knight Leap & Magic Cocktail Explosion) ───────
func _execute_knight_leap(target_pos: Vector2) -> void:
	AudioManager.play_sfx("slash")
	_screen_shake(6.0, 0.15)

	# Jump arc tween on player sprite
	var jump_tw: Tween = create_tween()
	jump_tw.tween_property(sprite, ^"position:y", -45.0, 0.12)
	jump_tw.parallel().tween_property(sprite, ^"scale", Vector2(0.7, 1.4), 0.12)
	jump_tw.tween_callback(func():
		global_position = target_pos
	)
	jump_tw.tween_property(sprite, ^"position:y", 0.0, 0.08)
	jump_tw.parallel().tween_property(sprite, ^"scale", Vector2(1.5, 0.6), 0.08)
	jump_tw.tween_property(sprite, ^"scale", Vector2.ONE, 0.10)

	jump_tw.chain().tween_callback(func():
		# Landing impact: massive explosion (Magic Cocktail explosion!)
		AudioManager.play_sfx("impact_heavy")
		AudioManager.play_sfx("explosion")
		AudioManager.play_sfx("burst_splat")
		_screen_shake(16.0, 0.45)

		# 1. Main ImpactFX Explosion (scaled to cover 150px: 150 / 48 ~ 3.2)
		var exp_fx: AnimatedSprite2D = AnimatedSprite2D.new()
		exp_fx.sprite_frames = _impact_exp_frames
		exp_fx.animation = &"play"
		exp_fx.scale = Vector2(3.2, 3.2)
		exp_fx.global_position = target_pos
		get_tree().current_scene.add_child(exp_fx)
		exp_fx.play(&"play")
		exp_fx.animation_finished.connect(exp_fx.queue_free)

		# 2. Elemental burst splatter
		var burst_fx: AnimatedSprite2D = AnimatedSprite2D.new()
		burst_fx.sprite_frames = _impact_burst_frames
		burst_fx.animation = &"play"
		burst_fx.scale = Vector2(3.0, 3.0)
		burst_fx.global_position = target_pos
		burst_fx.modulate = Color(2.2, 0.9, 0.25, 0.95)
		get_tree().current_scene.add_child(burst_fx)
		burst_fx.play(&"play")
		burst_fx.animation_finished.connect(burst_fx.queue_free)

		# 3. Expanding fiery shockwave ring showing 150px radius
		var ring: Line2D = Line2D.new()
		ring.width = 7.0
		ring.default_color = Color(2.4, 1.2, 0.3, 1.0)
		var pts: PackedVector2Array = PackedVector2Array()
		var segs: int = 40
		for i: int in range(segs + 1):
			var ang: float = float(i) * TAU / float(segs)
			pts.append(target_pos + Vector2(cos(ang), sin(ang)) * 150.0)
		ring.points = pts
		get_tree().current_scene.add_child(ring)
		var tw_ring: Tween = create_tween()
		tw_ring.tween_property(ring, ^"width", 0.0, 0.32)
		tw_ring.tween_callback(ring.queue_free)

		# 4. Devastating damage and knockback to enemies within 150px
		var enemies: Array[Node] = get_tree().get_nodes_in_group(&"enemies")
		for e_node: Node in enemies:
			var enemy: CharacterBody2D = e_node as CharacterBody2D
			if enemy == null or not is_instance_valid(enemy):
				continue
			var dist: float = enemy.global_position.distance_to(target_pos)
			if dist <= 150.0:
				var push: Vector2 = (enemy.global_position - target_pos).normalized() * 240.0
				if push == Vector2.ZERO:
					push = Vector2.UP * 240.0
				if "apply_knockback" in enemy:
					enemy.apply_knockback(push)
				enemy.take_damage(850)
	)


# ── Ultimate 2: Cung Thủ (Ranger Elongated Piercing Molten Spear) ──────
func _execute_ranger_piercing_spear(aim_dir: Vector2) -> void:
	AudioManager.play_sfx("spell_fire")
	AudioManager.play_sfx("impact_heavy")
	_screen_shake(12.0, 0.35)

	var start_pos: Vector2 = global_position
	var beam_len: float = 950.0
	var end_pos: Vector2 = start_pos + aim_dir * beam_len

	# Elongated, recolored Molten Spear projectile
	var spear_fx: AnimatedSprite2D = AnimatedSprite2D.new()
	spear_fx.sprite_frames = _molten_spear_frames
	spear_fx.animation = &"fly"
	spear_fx.rotation = aim_dir.angle()
	spear_fx.scale = Vector2(4.8, 1.3) # Elongated along flight direction!
	spear_fx.modulate = Color(0.35, 1.9, 2.5, 1.0) # Radiant cyan energy tint
	spear_fx.global_position = start_pos
	get_tree().current_scene.add_child(spear_fx)
	spear_fx.play(&"fly")

	# Spear projectile flight tween
	var tw_spear: Tween = create_tween()
	tw_spear.tween_property(spear_fx, ^"global_position", end_pos, 0.35)
	tw_spear.parallel().tween_property(spear_fx, ^"modulate:a", 0.0, 0.15).set_delay(0.25)
	tw_spear.tween_callback(spear_fx.queue_free)

	# Radiant beam streak trail along trajectory
	var trail: Line2D = Line2D.new()
	trail.width = 8.0
	trail.default_color = Color(0.4, 2.0, 2.5, 0.85)
	trail.points = PackedVector2Array([start_pos, end_pos])
	get_tree().current_scene.add_child(trail)
	var tw_trail: Tween = create_tween()
	tw_trail.tween_property(trail, ^"width", 0.0, 0.30)
	tw_trail.tween_callback(trail.queue_free)

	# Pierces all enemies along the trajectory corridor
	for e_node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy: CharacterBody2D = e_node as CharacterBody2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var to_e: Vector2 = enemy.global_position - start_pos
		var proj: float = to_e.dot(aim_dir)
		if proj >= 0.0 and proj <= beam_len:
			var closest_point: Vector2 = start_pos + aim_dir * proj
			if enemy.global_position.distance_to(closest_point) <= 48.0:
				# Impact slash FX
				var hit_fx: AnimatedSprite2D = AnimatedSprite2D.new()
				hit_fx.sprite_frames = _impact_slash_frames
				hit_fx.animation = &"play"
				hit_fx.scale = Vector2(2.2, 2.2)
				hit_fx.global_position = enemy.global_position
				hit_fx.modulate = Color(0.4, 2.0, 2.5, 1.0)
				get_tree().current_scene.add_child(hit_fx)
				hit_fx.play(&"play")
				hit_fx.animation_finished.connect(hit_fx.queue_free)

				enemy.take_damage(1100)


# ── Ultimate 3: Pháp Sư (Wizard Radius Blood Siphon) ───────────────────
func _execute_wizard_blood_siphon() -> void:
	var siphon_radius: float = 180.0
	AudioManager.play_sfx("burst_splat")
	AudioManager.play_sfx("spell_fire")
	_screen_shake(12.0, 0.40)

	# 1. Glowing crimson ritual ring showing 180px boundary
	var ring: Line2D = Line2D.new()
	ring.width = 6.0
	ring.default_color = Color(2.5, 0.2, 0.45, 1.0)
	var pts: PackedVector2Array = PackedVector2Array()
	var segs: int = 40
	for i: int in range(segs + 1):
		var ang: float = float(i) * TAU / float(segs)
		pts.append(global_position + Vector2(cos(ang), sin(ang)) * siphon_radius)
	ring.points = pts
	get_tree().current_scene.add_child(ring)
	var tw_ring: Tween = create_tween()
	tw_ring.tween_property(ring, ^"width", 0.0, 0.45)
	tw_ring.tween_callback(ring.queue_free)

	# 2. Blood swirl under player
	var swirl_fx: AnimatedSprite2D = AnimatedSprite2D.new()
	swirl_fx.sprite_frames = _impact_burst_frames
	swirl_fx.animation = &"play"
	swirl_fx.scale = Vector2(3.2, 3.2)
	swirl_fx.global_position = global_position
	swirl_fx.modulate = Color(2.4, 0.15, 0.35, 0.9)
	get_tree().current_scene.add_child(swirl_fx)
	swirl_fx.play(&"play")
	swirl_fx.animation_finished.connect(swirl_fx.queue_free)

	# 3. Siphon blood ONLY from enemies strictly inside 180px radius
	var enemies: Array[Node] = get_tree().get_nodes_in_group(&"enemies")
	var hit_count: int = 0
	for e_node: Node in enemies:
		var enemy: CharacterBody2D = e_node as CharacterBody2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var dist: float = global_position.distance_to(enemy.global_position)
		if dist <= siphon_radius:
			hit_count += 1

			# Blood burst FX at enemy
			var burst_fx: AnimatedSprite2D = AnimatedSprite2D.new()
			burst_fx.sprite_frames = _impact_burst_frames
			burst_fx.animation = &"play"
			burst_fx.scale = Vector2(2.0, 2.0)
			burst_fx.global_position = enemy.global_position
			burst_fx.modulate = Color(2.4, 0.1, 0.25, 1.0)
			get_tree().current_scene.add_child(burst_fx)
			burst_fx.play(&"play")
			burst_fx.animation_finished.connect(burst_fx.queue_free)

			# Soul siphon blood line flying back to player
			var soul_line: Line2D = Line2D.new()
			soul_line.width = 4.0
			soul_line.default_color = Color(2.5, 0.3, 0.5, 0.9)
			soul_line.points = PackedVector2Array([enemy.global_position, enemy.global_position])
			get_tree().current_scene.add_child(soul_line)
			var tw_soul: Tween = create_tween()
			tw_soul.tween_property(soul_line, ^"points", PackedVector2Array([enemy.global_position, global_position]), 0.22)
			tw_soul.tween_property(soul_line, ^"width", 0.0, 0.08)
			tw_soul.tween_callback(soul_line.queue_free)

			enemy.take_damage(600)
		# NOTE: enemies outside siphon_radius are completely untouched!

	# Heal player for enemies siphoned
	if hit_count > 0:
		var heal_amount: int = mini(hit_count * 15, 60)
		get_tree().create_timer(0.20).timeout.connect(func():
			heal(heal_amount)
			AudioManager.play_sfx("heal")
		)


func _execute_wings_of_salvation() -> void:
	AudioManager.play_sfx("heal")
	AudioManager.play_sfx("explosion")
	_screen_shake(10.0, 0.35)
	heal(50)
	defense += 5
	var tw_def: Tween = create_tween()
	tw_def.tween_interval(8.0)
	tw_def.tween_callback(func(): defense -= 5)

	for e_node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy: CharacterBody2D = e_node as CharacterBody2D
		if enemy != null and is_instance_valid(enemy) and global_position.distance_to(enemy.global_position) <= 150.0:
			enemy.take_damage(600)


func _execute_finale() -> void:
	AudioManager.play_sfx("unpause")
	is_stealthed = true
	is_invincible = true
	var orig_color: Color = sprite.modulate
	sprite.modulate.a = 0.35
	speed *= 1.5

	var tw: Tween = create_tween()
	tw.tween_interval(4.0)
	tw.tween_callback(func():
		is_stealthed = false
		is_invincible = false
		sprite.modulate = orig_color
		speed /= 1.5
	)


func _execute_crucible_beast() -> void:
	AudioManager.play_sfx("explosion")
	_screen_shake(12.0, 0.4)
	var orig_mod: Color = sprite.modulate
	sprite.modulate = Color(2.0, 0.6, 0.2, 1.0)
	speed *= 1.35

	for wave_idx: int in range(3):
		var tw_wave: Tween = create_tween()
		tw_wave.tween_interval(float(wave_idx) * 1.5)
		tw_wave.tween_callback(func():
			_screen_shake(8.0, 0.25)
			for e_node: Node in get_tree().get_nodes_in_group(&"enemies"):
				var enemy: CharacterBody2D = e_node as CharacterBody2D
				if enemy != null and is_instance_valid(enemy) and global_position.distance_to(enemy.global_position) <= 180.0:
					enemy.take_damage(400)
		)

	var tw_end: Tween = create_tween()
	tw_end.tween_interval(5.0)
	tw_end.tween_callback(func():
		sprite.modulate = orig_mod
		speed /= 1.35
	)


func _screen_shake(amount: float, duration: float = 0.3) -> void:
	var hud_nodes: Array[Node] = get_tree().get_nodes_in_group(&"hud")
	if hud_nodes.size() > 0:
		var hud: HUD = hud_nodes[0] as HUD
		if hud != null:
			hud.screen_shake(amount, duration)


