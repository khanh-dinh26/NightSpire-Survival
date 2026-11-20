class_name Player
extends CharacterBody2D
## Player character — 8-directional movement, responsive attack, walk bobbing/tilting, sprite direction facing.

# ── Stats ──────────────────────────────────────────────────────────────
var max_hp: int = 100
var current_hp: int = 100
var speed: float = 130.0
var defense: int = 0

# ── Node references ────────────────────────────────────────────────────
@onready var sprite: Sprite2D = $Sprite2D
@onready var weapon_orbit: WeaponOrbit = $WeaponOrbit

var _spell_scene: PackedScene = preload("res://src/entities/spells/SpellEntity.tscn")

# ── Procedural animation timers ────────────────────────────────────────
var _walk_phase: float = 0.0
var _idle_phase: float = 0.0
var _facing_right: bool = false
var _is_hit_animating: bool = false


func _ready() -> void:
	add_to_group(&"player")
	EventBus.spell_cast_requested.connect(_on_spell_cast_requested)
	if GameManager.chosen_class != null:
		setup_from_class(GameManager.chosen_class)
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


func setup_from_class(p_class: ClassData) -> void:
	if p_class == null:
		return
	max_hp = p_class.max_hp
	current_hp = max_hp
	speed = p_class.speed
	defense = p_class.defense
	sprite.region_rect = p_class.sprite_region

	if weapon_orbit != null:
		weapon_orbit.clear_weapons()
		for w: ItemData in GameManager.equipped_weapons:
			weapon_orbit.add_weapon(w)


# ── Movement & Procedural Animation ─────────────────────────────────────
func _physics_process(delta: float) -> void:
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

	velocity = input_dir * speed
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
	var effective: int = maxi(amount - defense, 1)
	current_hp -= effective
	GameManager.player_current_hp = current_hp

	EventBus.player_hit.emit(effective)
	_hit_flash()

	if current_hp <= 0:
		current_hp = 0
		EventBus.player_died.emit()


func heal(amount: int) -> void:
	current_hp = mini(current_hp + amount, max_hp)
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
	AudioManager.play_sfx("slash")
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
	AudioManager.play_sfx("slash")
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
	AudioManager.play_sfx("slash")
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
	AudioManager.play_sfx("slash")
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
