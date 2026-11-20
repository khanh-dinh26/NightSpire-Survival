class_name Spawner
extends Node
## Handles spawning enemies during combat waves, mini-bosses, and final bosses.

@export var arena: Arena = null
@export var entities_container: Node2D = null

var current_tower: TowerData = null
var current_floor_config: FloorConfig = null

var active_enemies: int = 0
var is_spawning: bool = false
var time_remaining: float = 0.0

var _spawn_timer: Timer = null
var _wave_timer: Timer = null
var _enemy_scene: PackedScene = preload("res://src/entities/enemies/EnemyBase.tscn")
var _boss_scene: PackedScene = preload("res://src/entities/enemies/BossBase.tscn")
var _formation_tick_counter: int = 0


func _ready() -> void:
	_spawn_timer = Timer.new()
	_spawn_timer.one_shot = false
	_spawn_timer.timeout.connect(_on_spawn_tick)
	add_child(_spawn_timer)

	_wave_timer = Timer.new()
	_wave_timer.one_shot = true
	_wave_timer.timeout.connect(_on_wave_timeout)
	add_child(_wave_timer)

	EventBus.enemy_killed.connect(_on_enemy_killed)


func _process(_delta: float) -> void:
	if is_spawning and _wave_timer != null and not _wave_timer.is_stopped():
		time_remaining = _wave_timer.time_left


func start_floor(tower: TowerData, config: FloorConfig) -> void:
	current_tower = tower
	current_floor_config = config
	active_enemies = 0

	# Clear any leftover enemies or bosses in entities container
	if entities_container != null:
		for child: Node in entities_container.get_children():
			if child is EnemyBase or child is BossBase:
				child.queue_free()

	match config.floor_type:
		FloorConfig.FloorType.COMBAT_WAVE:
			time_remaining = config.wave_duration
			is_spawning = true
			_wave_timer.wait_time = config.wave_duration
			_wave_timer.start()

			_spawn_timer.wait_time = config.spawn_interval
			_spawn_timer.start()
			_spawn_burst()
			EventBus.wave_started.emit(config.floor_index)

		FloorConfig.FloorType.MINIBOSS:
			time_remaining = 0.0
			is_spawning = false
			_wave_timer.stop()
			_spawn_timer.stop()
			_spawn_miniboss()
			EventBus.wave_started.emit(config.floor_index)

		FloorConfig.FloorType.NPC_SANCTUARY:
			time_remaining = 0.0
			is_spawning = false
			_wave_timer.stop()
			_spawn_timer.stop()
			EventBus.wave_started.emit(config.floor_index)

		FloorConfig.FloorType.FINAL_BOSS:
			time_remaining = 0.0
			is_spawning = false
			_wave_timer.stop()
			_spawn_timer.stop()
			_spawn_final_boss()
			EventBus.wave_started.emit(config.floor_index)


func stop_spawning() -> void:
	is_spawning = false
	_spawn_timer.stop()
	_wave_timer.stop()


func _on_spawn_tick() -> void:
	if not is_spawning or current_tower == null or current_floor_config == null:
		return
	var max_allowed: int = mini(current_floor_config.max_concurrent_enemies, 26)
	if active_enemies >= max_allowed:
		return
	_spawn_burst()


func _spawn_burst() -> void:
	if current_tower.common_enemies.is_empty():
		return

	var max_allowed: int = mini(current_floor_config.max_concurrent_enemies, 26)
	var available_slots: int = max_allowed - active_enemies
	if available_slots <= 0:
		return

	_formation_tick_counter += 1
	# Periodically trigger special tactical formations (Pincer lines, Surround circle, Elite vanguard)
	if _formation_tick_counter >= 3 and available_slots >= 4:
		_formation_tick_counter = 0
		_spawn_special_formation(available_slots)
		return

	var burst_count: int = mini(current_floor_config.enemies_per_burst, available_slots)
	var floor_idx: int = current_floor_config.floor_index if current_floor_config != null else 1
	var elite_chance: float = clampf(0.08 + float(floor_idx) * 0.015, 0.08, 0.25)

	for i: int in range(burst_count):
		var enemy_data: EnemyData = _get_tiered_enemy()
		if enemy_data != null:
			var make_elite: bool = (randf() <= elite_chance)
			_spawn_enemy(enemy_data, make_elite)


func _spawn_special_formation(available_slots: int) -> void:
	var pattern: int = randi() % 3
	match pattern:
		0:
			_spawn_pincer_lines(available_slots)
		1:
			_spawn_surrounding_circle(available_slots)
		2:
			_spawn_elite_vanguard(available_slots)


func _spawn_pincer_lines(available_slots: int) -> void:
	if arena == null:
		return
	var bounds: Rect2 = arena.get_spawn_bounds()
	var horizontal: bool = (randi() % 2 == 0)
	var per_side: int = clampi(available_slots / 2, 2, 4)

	if horizontal:
		var y_top: float = bounds.position.y + 6.0
		var y_bot: float = bounds.end.y - 6.0
		var x_start: float = bounds.position.x + 36.0
		var x_end: float = bounds.end.x - 36.0
		var step_x: float = (x_end - x_start) / maxf(float(per_side - 1), 1.0)

		for i: int in range(per_side):
			var x_pos: float = x_start + float(i) * step_x
			var data_top: EnemyData = _get_tiered_enemy()
			if data_top != null:
				var is_lead: bool = (i == per_side / 2 and randf() <= 0.45)
				_spawn_enemy(data_top, is_lead, Vector2(x_pos, y_top))

			var data_bot: EnemyData = _get_tiered_enemy()
			if data_bot != null:
				_spawn_enemy(data_bot, false, Vector2(x_pos, y_bot))
	else:
		var x_left: float = bounds.position.x + 6.0
		var x_right: float = bounds.end.x - 6.0
		var y_start: float = bounds.position.y + 24.0
		var y_end: float = bounds.end.y - 24.0
		var step_y: float = (y_end - y_start) / maxf(float(per_side - 1), 1.0)

		for i: int in range(per_side):
			var y_pos: float = y_start + float(i) * step_y
			var data_left: EnemyData = _get_tiered_enemy()
			if data_left != null:
				var is_lead: bool = (i == per_side / 2 and randf() <= 0.45)
				_spawn_enemy(data_left, is_lead, Vector2(x_left, y_pos))

			var data_right: EnemyData = _get_tiered_enemy()
			if data_right != null:
				_spawn_enemy(data_right, false, Vector2(x_right, y_pos))


func _spawn_surrounding_circle(available_slots: int) -> void:
	if arena == null:
		return
	var players: Array[Node] = get_tree().get_nodes_in_group(&"player")
	var center: Vector2 = (players[0] as Node2D).global_position if players.size() > 0 else arena.get_center_position()
	var bounds: Rect2 = arena.get_spawn_bounds()

	var count: int = clampi(available_slots, 4, 6)
	var radius: float = 125.0
	var step_angle: float = TAU / float(count)

	for i: int in range(count):
		var angle: float = float(i) * step_angle
		var pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius
		pos.x = clampf(pos.x, bounds.position.x + 8.0, bounds.end.x - 8.0)
		pos.y = clampf(pos.y, bounds.position.y + 8.0, bounds.end.y - 8.0)
		var data: EnemyData = _get_tiered_enemy()
		if data != null:
			var is_lead: bool = (i == 0 and randf() <= 0.35)
			_spawn_enemy(data, is_lead, pos)


func _spawn_elite_vanguard(available_slots: int) -> void:
	var lead_data: EnemyData = _get_tiered_enemy()
	if lead_data == null:
		return
	var lead_pos: Vector2 = _get_spawn_position()
	_spawn_enemy(lead_data, true, lead_pos)

	var flank_count: int = mini(available_slots - 1, 2)
	for i: int in range(flank_count):
		var flank_data: EnemyData = _get_tiered_enemy()
		if flank_data != null:
			var offset: Vector2 = Vector2(randf_range(-22.0, 22.0), randf_range(-22.0, 22.0))
			_spawn_enemy(flank_data, false, lead_pos + offset)


func _get_tiered_enemy() -> EnemyData:
	if current_tower.common_enemies.is_empty():
		return null

	var enemies: Array = current_tower.common_enemies
	var floor_idx: int = current_floor_config.floor_index if current_floor_config != null else 1
	var pool: Array[EnemyData] = []

	if floor_idx <= 3:
		# Floors 1-3: Early game. Mostly low-tier monsters (bats, spiders, goblins)
		var max_k: int = mini(3, enemies.size())
		for k: int in range(max_k):
			pool.append(enemies[k])
	elif floor_idx <= 7:
		# Floors 5-7: Mid game. Move to mid-tier monsters (snakes, slimes, cultists, zombies)
		var start_k: int = 1 if enemies.size() > 2 else 0
		var end_k: int = mini(enemies.size(), 4)
		for k: int in range(start_k, end_k):
			pool.append(enemies[k])
	else:
		# Floors 10-12+: Late game elite horde. Brutal monsters only (abyssal crawlers, demons, golems)
		var start_k: int = maxi(0, enemies.size() - 3)
		for k: int in range(start_k, enemies.size()):
			pool.append(enemies[k])

	if pool.is_empty():
		return enemies[randi() % enemies.size()]
	return pool[randi() % pool.size()]


func _spawn_enemy(data: EnemyData, is_elite: bool = false, custom_pos: Vector2 = Vector2.ZERO) -> void:
	var enemy: EnemyBase = _enemy_scene.instantiate() as EnemyBase
	var hp_scale: float = current_floor_config.enemy_hp_multiplier
	var dmg_scale: float = current_floor_config.enemy_damage_multiplier
	var spd_scale: float = current_floor_config.enemy_speed_multiplier

	if GameManager.is_dark_night:
		hp_scale *= (1.0 + float(GameManager.dark_night_cycle) * 0.6)
		dmg_scale *= (1.0 + float(GameManager.dark_night_cycle) * 0.35)
		spd_scale *= (1.0 + float(GameManager.dark_night_cycle) * 0.12)

	enemy.setup(data, hp_scale, dmg_scale, spd_scale, is_elite)

	var spawn_pos: Vector2 = custom_pos if custom_pos != Vector2.ZERO else _get_spawn_position()
	if arena != null:
		var bounds: Rect2 = arena.get_spawn_bounds()
		spawn_pos.x = clampf(spawn_pos.x, bounds.position.x + 4.0, bounds.end.x - 4.0)
		spawn_pos.y = clampf(spawn_pos.y, bounds.position.y + 4.0, bounds.end.y - 4.0)

	enemy.global_position = spawn_pos

	if entities_container != null:
		entities_container.add_child(enemy)
	else:
		get_tree().current_scene.add_child(enemy)

	active_enemies += 1


func _spawn_miniboss() -> void:
	if current_tower.miniboss_pool.is_empty():
		return

	# Floor 4 -> miniboss 1 (index 0); Floor 8 -> miniboss 2 (index 1 if exists)
	var boss_idx: int = 0
	if current_floor_config.floor_index >= 8 and current_tower.miniboss_pool.size() > 1:
		boss_idx = 1
	var data: EnemyData = current_tower.miniboss_pool[boss_idx]

	_spawn_boss_instance(data)

	# Spawn 2-3 supporting minions (one of which is an Elite minion)
	for i: int in range(3):
		if not current_tower.common_enemies.is_empty():
			var minion_data: EnemyData = current_tower.common_enemies[i % current_tower.common_enemies.size()]
			_spawn_enemy(minion_data, (i == 0))


func _spawn_final_boss() -> void:
	if current_tower.final_boss == null:
		return
	_spawn_boss_instance(current_tower.final_boss)

	# Spawn 2 minions (one of which is an Elite minion)
	for i: int in range(2):
		if not current_tower.common_enemies.is_empty():
			var minion_data: EnemyData = current_tower.common_enemies[i % current_tower.common_enemies.size()]
			_spawn_enemy(minion_data, (i == 0))


func _spawn_boss_instance(boss_data: EnemyData) -> void:
	var boss: BossBase = _boss_scene.instantiate() as BossBase
	var hp_scale: float = current_floor_config.enemy_hp_multiplier
	var dmg_scale: float = current_floor_config.enemy_damage_multiplier
	var spd_scale: float = current_floor_config.enemy_speed_multiplier

	if GameManager.is_dark_night:
		hp_scale *= (1.0 + float(GameManager.dark_night_cycle) * 0.75)
		dmg_scale *= (1.0 + float(GameManager.dark_night_cycle) * 0.4)
		spd_scale *= (1.0 + float(GameManager.dark_night_cycle) * 0.15)

	boss.setup(boss_data, hp_scale, dmg_scale, spd_scale)

	# Position near top center of arena
	if arena != null:
		var center: Vector2 = arena.get_center_position()
		boss.global_position = Vector2(center.x, center.y - 80.0)
	else:
		boss.global_position = Vector2(288, 80)

	if entities_container != null:
		entities_container.add_child(boss)
	else:
		get_tree().current_scene.add_child(boss)

	# Connect Boss HP bar on HUD
	var hud: HUD = get_tree().current_scene.get_node_or_null("HUD") as HUD
	if hud != null:
		hud.show_boss_bar(boss_data.enemy_name, boss.max_hp)
		boss.boss_hp_changed.connect(hud.update_boss_hp)


func _get_spawn_position() -> Vector2:
	if arena == null:
		return Vector2(100, 100)

	var bounds: Rect2 = arena.get_spawn_bounds()
	var side: int = randi() % 4
	var pos: Vector2 = Vector2.ZERO
	match side:
		0:
			pos = Vector2(randf_range(bounds.position.x, bounds.end.x), bounds.position.y)
		1:
			pos = Vector2(randf_range(bounds.position.x, bounds.end.x), bounds.end.y)
		2:
			pos = Vector2(bounds.position.x, randf_range(bounds.position.y, bounds.end.y))
		3:
			pos = Vector2(bounds.end.x, randf_range(bounds.position.y, bounds.end.y))
	return pos


func _on_enemy_killed(_pos: Vector2, _gold: int) -> void:
	active_enemies = maxi(active_enemies - 1, 0)


func _on_wave_timeout() -> void:
	is_spawning = false
	_spawn_timer.stop()
	EventBus.wave_ended.emit(current_floor_config.floor_index)
