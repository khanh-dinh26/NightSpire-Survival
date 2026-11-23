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

# ── Hero Abilities (Character Skill & Ultimate Art) ─────────────────────
var hero_class: ClassData = null
var skill_cooldown_timer: float = 0.0
var skill_cooldown_max: float = 7.0
var ultimate_charge: int = 0
var ultimate_required_damage: int = 650
var is_stealthed: bool = false
var is_invincible: bool = false

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


func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			cast_character_skill()
		elif event.keycode == KEY_Q or event.keycode == KEY_SPACE:
			cast_ultimate_art()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			cast_character_skill()


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
	if is_dead:
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


# ── Character Skill & Ultimate Art Execution ─────────────────────────
func cast_character_skill() -> bool:
	if is_dead or skill_cooldown_timer > 0.0:
		return false
	if hero_class == null or hero_class.skill_id.is_empty():
		return false

	skill_cooldown_timer = skill_cooldown_max
	EventBus.hero_skill_used.emit(hero_class.skill_id)
	EventBus.hero_skill_cooldown_updated.emit(skill_cooldown_timer, skill_cooldown_max)

	var mouse_pos: Vector2 = get_global_mouse_position()
	var aim_dir: Vector2 = (mouse_pos - global_position).normalized()
	if aim_dir == Vector2.ZERO:
		aim_dir = Vector2.LEFT if sprite.flip_h else Vector2.RIGHT

	match hero_class.skill_id:
		"claw_shot":
			_execute_claw_shot(mouse_pos, aim_dir)
		"marking_dash":
			_execute_marking_dash(aim_dir)
		"magic_cocktail":
			_execute_magic_cocktail(mouse_pos)
		"whirlwind":
			_execute_whirlwind()
		"restage":
			_execute_restage()
		"cursed_sword":
			_execute_cursed_sword(aim_dir)
		_:
			_execute_claw_shot(mouse_pos, aim_dir)
	return true


func cast_ultimate_art() -> bool:
	if is_dead or ultimate_charge < ultimate_required_damage:
		return false
	if hero_class == null or hero_class.ultimate_id.is_empty():
		return false

	ultimate_charge = 0
	GameManager.hero_ultimate_charge = 0
	EventBus.hero_ultimate_used.emit(hero_class.ultimate_id)
	EventBus.hero_ultimate_charge_updated.emit(0, ultimate_required_damage)

	var mouse_pos: Vector2 = get_global_mouse_position()
	var aim_dir: Vector2 = (mouse_pos - global_position).normalized()
	if aim_dir == Vector2.ZERO:
		aim_dir = Vector2.LEFT if sprite.flip_h else Vector2.RIGHT

	match hero_class.ultimate_id:
		"onslaught_stake":
			_execute_onslaught_stake(mouse_pos)
		"single_shot":
			_execute_single_shot(aim_dir)
		"soulblood_song":
			_execute_soulblood_song()
		"wings_of_salvation":
			_execute_wings_of_salvation()
		"finale":
			_execute_finale()
		"crucible_beast":
			_execute_crucible_beast()
		_:
			_execute_onslaught_stake(mouse_pos)
	return true


func _execute_claw_shot(_mouse_pos: Vector2, aim_dir: Vector2) -> void:
	AudioManager.play_sfx("slash")
	_screen_shake(4.0, 0.2)

	# Direct frontal claw strike visual
	var claw_line: Line2D = Line2D.new()
	claw_line.width = 5.0
	claw_line.default_color = Color(1.3, 0.9, 0.3, 1.0)
	claw_line.points = PackedVector2Array([Vector2.ZERO, aim_dir * 140.0])
	add_child(claw_line)
	var tw: Tween = create_tween()
	tw.tween_property(claw_line, ^"width", 0.0, 0.15)
	tw.tween_callback(claw_line.queue_free)

	# Strike enemies in front cone
	var enemies: Array[Node] = get_tree().get_nodes_in_group(&"enemies")
	for e_node: Node in enemies:
		var enemy: CharacterBody2D = e_node as CharacterBody2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var to_e: Vector2 = enemy.global_position - global_position
		if to_e.length() <= 150.0 and to_e.normalized().dot(aim_dir) > 0.3:
			if "apply_knockback" in enemy:
				enemy.apply_knockback(aim_dir * 120.0)
			enemy.take_damage(140)


func _execute_marking_dash(aim_dir: Vector2) -> void:
	AudioManager.play_sfx("slash")
	_screen_shake(3.0, 0.15)

	# Swift evasive dash
	global_position += aim_dir * 60.0

	# Front slash
	var enemies: Array[Node] = get_tree().get_nodes_in_group(&"enemies")
	for e_node: Node in enemies:
		var enemy: CharacterBody2D = e_node as CharacterBody2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		if global_position.distance_to(enemy.global_position) <= 120.0:
			enemy.take_damage(130)


func _execute_magic_cocktail(target_pos: Vector2) -> void:
	AudioManager.play_sfx("spell_fire")
	_screen_shake(5.0, 0.2)

	# Instant elemental explosion at target
	var enemies: Array[Node] = get_tree().get_nodes_in_group(&"enemies")
	for e_node: Node in enemies:
		var enemy: CharacterBody2D = e_node as CharacterBody2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.global_position.distance_to(target_pos) <= 110.0:
			enemy.take_damage(180)


func _execute_whirlwind() -> void:
	AudioManager.play_sfx("spell_wind")
	_screen_shake(6.0, 0.25)
	for e_node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy: CharacterBody2D = e_node as CharacterBody2D
		if enemy != null and is_instance_valid(enemy) and global_position.distance_to(enemy.global_position) <= 130.0:
			var push_dir: Vector2 = (enemy.global_position - global_position).normalized()
			if "apply_knockback" in enemy:
				enemy.apply_knockback(push_dir * 180.0)
			enemy.take_damage(140)


func _execute_restage() -> void:
	AudioManager.play_sfx("slash")
	_screen_shake(6.0, 0.25)
	for e_node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy: CharacterBody2D = e_node as CharacterBody2D
		if enemy != null and is_instance_valid(enemy) and global_position.distance_to(enemy.global_position) <= 130.0:
			enemy.take_damage(180)


func _execute_cursed_sword(aim_dir: Vector2) -> void:
	AudioManager.play_sfx("slash")
	_screen_shake(6.0, 0.25)
	global_position += aim_dir * 100.0
	for e_node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy: CharacterBody2D = e_node as CharacterBody2D
		if enemy != null and is_instance_valid(enemy) and global_position.distance_to(enemy.global_position) <= 90.0:
			enemy.take_damage(190)


# ── Ultimates ──────────────────────────────────────────────────────────
func _execute_onslaught_stake(target_pos: Vector2) -> void:
	AudioManager.play_sfx("explosion")
	_screen_shake(16.0, 0.5)

	# Giant fiery impact shockwave
	var enemies: Array[Node] = get_tree().get_nodes_in_group(&"enemies")
	for e_node: Node in enemies:
		var enemy: CharacterBody2D = e_node as CharacterBody2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.global_position.distance_to(target_pos) <= 180.0:
			var push: Vector2 = (enemy.global_position - target_pos).normalized() * 220.0
			if "apply_knockback" in enemy:
				enemy.apply_knockback(push)
			enemy.take_damage(850)


func _execute_single_shot(aim_dir: Vector2) -> void:
	AudioManager.play_sfx("explosion")
	_screen_shake(12.0, 0.4)

	# Visual supersonic piercing laser beam
	var laser: Line2D = Line2D.new()
	laser.width = 8.0
	laser.default_color = Color(2.5, 2.0, 0.5, 1.0)
	laser.points = PackedVector2Array([global_position, global_position + aim_dir * 900.0])
	get_tree().current_scene.add_child(laser)
	var tw: Tween = create_tween()
	tw.tween_property(laser, ^"width", 0.0, 0.35)
	tw.tween_callback(laser.queue_free)

	# Pierces all enemies along line
	var ray_start: Vector2 = global_position
	var ray_end: Vector2 = global_position + aim_dir * 900.0
	for e_node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy: CharacterBody2D = e_node as CharacterBody2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var to_e: Vector2 = enemy.global_position - ray_start
		var proj: float = to_e.dot(aim_dir)
		if proj >= 0.0 and proj <= 900.0:
			var closest_point: Vector2 = ray_start + aim_dir * proj
			if enemy.global_position.distance_to(closest_point) <= 45.0:
				enemy.take_damage(1100)


func _execute_soulblood_song() -> void:
	AudioManager.play_sfx("spell_fire")
	_screen_shake(10.0, 0.35)
	heal(40)

	for e_node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy: CharacterBody2D = e_node as CharacterBody2D
		if enemy != null and is_instance_valid(enemy):
			enemy.take_damage(500)


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

