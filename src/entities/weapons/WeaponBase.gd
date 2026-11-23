class_name WeaponBase
extends Node2D
## Spinning orbital weapon that revolves around the player like a spinner/buzzsaw,
## slicing and dealing contact damage to any enemy that collides with it.
## Ranged weapons (bows) and embedded spells auto-cast projectiles outwards as normal.

var item_data: ItemData = null

var _target: Node2D = null
var _cooldown_left: float = 0.0
var _spell_cooldown_left: float = 0.0
var _enemy_hit_cooldowns: Dictionary = {}
var _last_slash_sound_time: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var attack_timer: Timer = $AttackTimer

var _projectile_scene: PackedScene = preload("res://src/entities/weapons/Projectile.tscn")
var _spell_scene: PackedScene = preload("res://src/entities/spells/SpellEntity.tscn")


func _ready() -> void:
	attack_timer.stop()


func setup(data: ItemData) -> void:
	item_data = data
	sprite.region_rect = data.sprite_region
	_cooldown_left = 0.0
	_spell_cooldown_left = 0.0


func _physics_process(delta: float) -> void:
	if item_data == null:
		return

	# Continuous spinning contact damage (slashes any enemy touching the weapon!)
	_process_spinning_contact_damage()

	# Ranged weapon projectile firing (Bows/crossbows fire arrows outwards as normal)
	if item_data.weapon_style == ItemData.WeaponStyle.RANGED_PROJECTILE:
		if _cooldown_left > 0.0:
			_cooldown_left -= delta
		else:
			_target = _find_closest_enemy()
			if _target != null:
				_cooldown_left = 1.0 / maxf(item_data.attack_speed, 0.5)
				_attack_ranged()

	# Auto-cast embedded spell emblem (Fireball, Molten Spear, Tornado, Earth Spike)
	if not item_data.embedded_spell.is_empty():
		if _spell_cooldown_left > 0.0:
			_spell_cooldown_left -= delta
		else:
			var spell_target: Node2D = _find_spell_target()
			if spell_target != null:
				_auto_cast_embedded_spell(spell_target)

	# Berserk Low HP visual indicator (crimson pulse if HP <= 35%)
	if item_data.special_effect == "berserk_low_hp":
		var players: Array[Node] = get_tree().get_nodes_in_group(&"player")
		if players.size() > 0:
			var pl: Player = players[0] as Player
			if pl != null and float(pl.current_hp) / float(maxi(pl.max_hp, 1)) <= 0.35:
				var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
				sprite.modulate = Color(2.2, 0.2 + 0.3 * pulse, 0.2 + 0.3 * pulse, 1.0)
			else:
				sprite.modulate = Color.WHITE


# ── Continuous Spinning Contact Damage ────────────────────────────────────
func _process_spinning_contact_damage() -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	# Hit interval per enemy based on weapon attack speed
	var hit_interval: float = clampf(1.0 / maxf(item_data.attack_speed, 1.0), 0.16, 0.40)
	var contact_radius: float = 44.0 + float(item_data.level - 1) * 2.5

	var enemies: Array[Node] = get_tree().get_nodes_in_group(&"enemies")
	for node: Node in enemies:
		var enemy: Node2D = node as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		if global_position.distance_to(enemy.global_position) <= contact_radius:
			var eid: int = enemy.get_instance_id()
			var last_hit: float = _enemy_hit_cooldowns.get(eid, 0.0)
			if now - last_hit >= hit_interval:
				_enemy_hit_cooldowns[eid] = now
				_deal_melee_damage(enemy)

	# Prune stale IDs
	if _enemy_hit_cooldowns.size() > 64:
		var valid_ids: Dictionary = {}
		for node: Node in enemies:
			var eid: int = node.get_instance_id()
			if _enemy_hit_cooldowns.has(eid):
				valid_ids[eid] = _enemy_hit_cooldowns[eid]
		_enemy_hit_cooldowns = valid_ids


func _deal_melee_damage(target: Node2D) -> void:
	if not is_instance_valid(target) or not target.has_method("take_damage") or item_data == null:
		return

	var final_damage: int = item_data.base_damage

	# Tower modifier & crit bonus
	if GameManager.current_tower != null:
		final_damage = roundi(float(final_damage) * GameManager.current_tower.player_dmg_deal_mult)
		if GameManager.current_tower.player_crit_bonus > 0.0 and randf() < GameManager.current_tower.player_crit_bonus:
			final_damage = roundi(float(final_damage) * 1.75)

	# Berserk Low HP check
	var players: Array[Node] = get_tree().get_nodes_in_group(&"player")
	var player_ref: Player = players[0] as Player if players.size() > 0 else null

	if item_data.special_effect == "berserk_low_hp" and player_ref != null:
		if float(player_ref.current_hp) / float(maxi(player_ref.max_hp, 1)) <= 0.35:
			final_damage = roundi(final_damage * 1.5)

	target.take_damage(final_damage)

	# Knock enemy away from player center (deflection effect)
	if target.has_method("apply_knockback") and player_ref != null:
		var kb_dir: Vector2 = (target.global_position - player_ref.global_position).normalized()
		if kb_dir == Vector2.ZERO:
			kb_dir = Vector2.RIGHT
		target.apply_knockback(kb_dir * (item_data.knockback * 0.6))

	# Responsive hit pop
	var tw: Tween = create_tween()
	tw.tween_property(sprite, ^"scale", Vector2(1.28, 1.28), 0.03)
	tw.tween_property(sprite, ^"scale", Vector2(1.0, 1.0), 0.05)

	# Sound throttling (max 1 sound per 0.12s to keep audio crisp)
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_slash_sound_time > 0.12:
		_last_slash_sound_time = now
		AudioManager.play_sfx("slash")

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
	var radius: float = 150.0
	for enemy: Node in get_tree().get_nodes_in_group(&"enemies"):
		var e: Node2D = enemy as Node2D
		if e == null or not is_instance_valid(e):
			continue
		if e.is_in_group(&"boss") or e.is_in_group(&"bosses"):
			continue
		if center_pos.distance_to(e.global_position) <= radius:
			if e.has_method("take_damage"):
				e.take_damage(9999)
	AudioManager.play_sfx("enemy_death")


# ── Ranged Weapon Projectile ──────────────────────────────────────────────
func _find_closest_enemy() -> Node2D:
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	var closest: Node2D = null
	var closest_dist: float = (item_data.attack_range * 1.25) if item_data != null else 220.0
	for enemy: Node in enemies:
		var e: Node2D = enemy as Node2D
		if e == null or not is_instance_valid(e):
			continue
		var dist: float = global_position.distance_to(e.global_position)
		if dist <= closest_dist:
			closest_dist = dist
			closest = e
	return closest


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


# ── Auto-Cast Embedded Spell ──────────────────────────────────────────
func _find_spell_target() -> Node2D:
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	var closest: Node2D = null
	var closest_dist: float = 280.0
	for enemy: Node in enemies:
		var e: Node2D = enemy as Node2D
		if e == null or not is_instance_valid(e):
			continue
		var dist: float = global_position.distance_to(e.global_position)
		if dist <= closest_dist:
			closest_dist = dist
			closest = e
	return closest


func _auto_cast_embedded_spell(target_node: Node2D) -> void:
	if target_node == null or item_data == null:
		return

	var lvl: int = item_data.embedded_spell_level
	_spell_cooldown_left = maxf(3.2 - float(lvl) * 0.35, 1.2)

	var target_pos: Vector2 = target_node.global_position
	var aim_dir: Vector2 = (target_pos - global_position).normalized()
	if aim_dir == Vector2.ZERO:
		aim_dir = Vector2.RIGHT

	match item_data.embedded_spell:
		"fireball":
			_cast_fireball(lvl, aim_dir)
		"molten_spear":
			_cast_molten_spear(lvl, aim_dir)
		"tornado":
			_cast_tornado(lvl, aim_dir)
		"earth_spike":
			_cast_earth_spike(lvl, target_pos)
		"water_geyser":
			_cast_water_geyser(lvl, target_pos)
		"void_portal":
			_cast_void_portal(lvl, target_pos)
		"meteor_rock":
			_cast_meteor_rock(lvl, target_pos)

	var tw: Tween = create_tween()
	tw.tween_property(self, ^"scale", Vector2(1.3, 1.3), 0.06)
	tw.tween_property(self, ^"scale", Vector2(1.0, 1.0), 0.08)


func _get_spell_directions(lvl: int, base_dir: Vector2) -> Array[Vector2]:
	var echo_bonus: int = 0
	for buff: ItemData in GameManager.passive_buffs:
		if buff != null and buff.item_id == "spell_echo_prism":
			echo_bonus += buff.level
	
	var total_count: int = lvl + echo_bonus
	var dirs: Array[Vector2] = []
	if total_count <= 1:
		dirs.append(base_dir)
	elif total_count == 2:
		dirs.append(base_dir)
		dirs.append(-base_dir)
	else:
		var step: float = TAU / float(total_count)
		for i: int in range(total_count):
			dirs.append(base_dir.rotated(float(i) * step))
	return dirs


func _cast_fireball(lvl: int, base_dir: Vector2) -> void:
	AudioManager.play_sfx("slash")
	var dirs: Array[Vector2] = _get_spell_directions(lvl, base_dir)
	for fire_dir: Vector2 in dirs:
		var spell: Area2D = _spell_scene.instantiate() as Area2D
		spell.set("spell_type", 0) # FIREBALL
		spell.set("level", lvl)
		spell.set("damage", 25 + (lvl - 1) * 12)
		spell.set("direction", fire_dir)
		spell.global_position = global_position
		get_tree().current_scene.add_child(spell)


func _cast_molten_spear(lvl: int, base_dir: Vector2) -> void:
	AudioManager.play_sfx("slash")
	var dirs: Array[Vector2] = _get_spell_directions(lvl, base_dir)
	for fire_dir: Vector2 in dirs:
		var spell: Area2D = _spell_scene.instantiate() as Area2D
		spell.set("spell_type", 1) # MOLTEN_SPEAR
		spell.set("level", lvl)
		spell.set("damage", 35 + (lvl - 1) * 18)
		spell.set("direction", fire_dir)
		spell.global_position = global_position
		get_tree().current_scene.add_child(spell)


func _cast_tornado(lvl: int, base_dir: Vector2) -> void:
	AudioManager.play_sfx("slash")
	var dirs: Array[Vector2] = _get_spell_directions(lvl, base_dir)
	for fire_dir: Vector2 in dirs:
		var spell: Area2D = _spell_scene.instantiate() as Area2D
		spell.set("spell_type", 2) # TORNADO
		spell.set("level", lvl)
		spell.set("damage", 18 + (lvl - 1) * 8)
		spell.set("direction", fire_dir)
		spell.global_position = global_position
		get_tree().current_scene.add_child(spell)


func _cast_earth_spike(lvl: int, target_pos: Vector2) -> void:
	AudioManager.play_sfx("slash")
	var echo_bonus: int = 0
	for buff: ItemData in GameManager.passive_buffs:
		if buff != null and buff.item_id == "spell_echo_prism":
			echo_bonus += buff.level
	var count: int = 1 + (lvl - 1) * 2 + echo_bonus
	var offsets: Array[Vector2] = [Vector2.ZERO]
	if count == 2:
		offsets.append(Vector2(28, 0))
	elif count >= 3:
		var radius: float = 30.0
		for i: int in range(count - 1):
			var angle: float = float(i) * TAU / float(count - 1)
			offsets.append(Vector2(cos(angle), sin(angle)) * radius)

	for offset: Vector2 in offsets:
		var spell: Area2D = _spell_scene.instantiate() as Area2D
		spell.set("spell_type", 3) # EARTH_SPIKE
		spell.set("level", lvl)
		spell.set("damage", 40 + (lvl - 1) * 20)
		spell.global_position = target_pos + offset
		get_tree().current_scene.add_child(spell)


func _cast_water_geyser(lvl: int, target_pos: Vector2) -> void:
	AudioManager.play_sfx("water")
	var echo_bonus: int = 0
	for buff: ItemData in GameManager.passive_buffs:
		if buff != null and buff.item_id == "spell_echo_prism":
			echo_bonus += buff.level
	var count: int = 1 + lvl + echo_bonus
	for i: int in range(count):
		var offset: Vector2 = Vector2.ZERO if i == 0 else Vector2(randf_range(-35, 35), randf_range(-35, 35))
		var spell: Area2D = _spell_scene.instantiate() as Area2D
		spell.set("spell_type", 5) # WATER_GEYSER
		spell.set("level", lvl)
		spell.set("damage", 45 + (lvl - 1) * 22)
		spell.global_position = target_pos + offset
		get_tree().current_scene.add_child(spell)


func _cast_void_portal(lvl: int, target_pos: Vector2) -> void:
	AudioManager.play_sfx("spell_fire")
	var spell: Area2D = _spell_scene.instantiate() as Area2D
	spell.set("spell_type", 6) # VOID_PORTAL
	spell.set("level", lvl)
	spell.set("damage", 30 + (lvl - 1) * 15)
	spell.global_position = target_pos
	get_tree().current_scene.add_child(spell)


func _cast_meteor_rock(lvl: int, target_pos: Vector2) -> void:
	AudioManager.play_sfx("explosion")
	var echo_bonus: int = 0
	for buff: ItemData in GameManager.passive_buffs:
		if buff != null and buff.item_id == "spell_echo_prism":
			echo_bonus += buff.level
	var count: int = 1 + (lvl / 2) + echo_bonus
	for i: int in range(count):
		var offset: Vector2 = Vector2.ZERO if i == 0 else Vector2(randf_range(-40, 40), randf_range(-40, 40))
		var spell: Area2D = _spell_scene.instantiate() as Area2D
		spell.set("spell_type", 7) # METEOR_ROCK
		spell.set("level", lvl)
		spell.set("damage", 60 + (lvl - 1) * 28)
		spell.global_position = target_pos + offset
		get_tree().current_scene.add_child(spell)
