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
	if active_enemies >= current_floor_config.max_concurrent_enemies:
		return
	_spawn_burst()


func _spawn_burst() -> void:
	if current_tower.common_enemies.is_empty():
		return

	var burst_count: int = mini(
		current_floor_config.enemies_per_burst,
		current_floor_config.max_concurrent_enemies - active_enemies
	)

	for i: int in range(burst_count):
		var enemy_data: EnemyData = _get_tiered_enemy()
		if enemy_data != null:
			_spawn_enemy(enemy_data)


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


func _spawn_enemy(data: EnemyData) -> void:
	var enemy: EnemyBase = _enemy_scene.instantiate() as EnemyBase
	var hp_scale: float = current_floor_config.enemy_hp_multiplier
	var dmg_scale: float = current_floor_config.enemy_damage_multiplier
	var spd_scale: float = current_floor_config.enemy_speed_multiplier

	if GameManager.is_dark_night:
		hp_scale *= (1.0 + float(GameManager.dark_night_cycle) * 0.6)
		dmg_scale *= (1.0 + float(GameManager.dark_night_cycle) * 0.35)
		spd_scale *= (1.0 + float(GameManager.dark_night_cycle) * 0.12)

	enemy.setup(data, hp_scale, dmg_scale, spd_scale)

	var spawn_pos: Vector2 = _get_spawn_position()
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

	# Spawn 2-3 supporting minions
	for i: int in range(3):
		if not current_tower.common_enemies.is_empty():
			var minion_data: EnemyData = current_tower.common_enemies[i % current_tower.common_enemies.size()]
			_spawn_enemy(minion_data)


func _spawn_final_boss() -> void:
	if current_tower.final_boss == null:
		return
	_spawn_boss_instance(current_tower.final_boss)

	# Spawn 2 minions
	for i: int in range(2):
		if not current_tower.common_enemies.is_empty():
			var minion_data: EnemyData = current_tower.common_enemies[i % current_tower.common_enemies.size()]
			_spawn_enemy(minion_data)


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

	# 50% chance to warp directly out of an active summoning portal!
	var portals: Array[Vector2] = arena.get_portal_positions()
	if not portals.is_empty() and randf() <= 0.5:
		var p: Vector2 = portals[randi() % portals.size()]
		var offset: Vector2 = Vector2(randf_range(-20, 20), randf_range(-20, 20))
		return p + offset

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
