class_name Spawner
extends Node
## Handles spawning enemies during combat waves.

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

	# Clear any leftover enemies in entities container
	if entities_container != null:
		for child: Node in entities_container.get_children():
			if child is EnemyBase:
				child.queue_free()

	match config.floor_type:
		FloorConfig.FloorType.COMBAT_WAVE:
			time_remaining = config.wave_duration
			is_spawning = true
			_wave_timer.wait_time = config.wave_duration
			_wave_timer.start()

			_spawn_timer.wait_time = config.spawn_interval
			_spawn_timer.start()
			# Initial burst
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
		var enemy_data: EnemyData = current_tower.common_enemies[randi() % current_tower.common_enemies.size()]
		_spawn_enemy(enemy_data)


func _spawn_enemy(data: EnemyData) -> void:
	var enemy: EnemyBase = _enemy_scene.instantiate() as EnemyBase
	enemy.setup(
		data,
		current_floor_config.enemy_hp_multiplier,
		current_floor_config.enemy_damage_multiplier,
		current_floor_config.enemy_speed_multiplier
	)

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
	var data: EnemyData = current_tower.miniboss_pool[randi() % current_tower.miniboss_pool.size()]
	_spawn_enemy(data)


func _spawn_final_boss() -> void:
	if current_tower.final_boss == null:
		return
	_spawn_enemy(current_tower.final_boss)


func _get_spawn_position() -> Vector2:
	if arena == null:
		return Vector2(100, 100)
	var bounds: Rect2 = arena.get_spawn_bounds()
	# Spawn near border
	var side: int = randi() % 4
	var pos: Vector2 = Vector2.ZERO
	match side:
		0: # Top edge
			pos = Vector2(randf_range(bounds.position.x, bounds.end.x), bounds.position.y)
		1: # Bottom edge
			pos = Vector2(randf_range(bounds.position.x, bounds.end.x), bounds.end.y)
		2: # Left edge
			pos = Vector2(bounds.position.x, randf_range(bounds.position.y, bounds.end.y))
		3: # Right edge
			pos = Vector2(bounds.end.x, randf_range(bounds.position.y, bounds.end.y))
	return pos


func _on_enemy_killed(_pos: Vector2, _gold: int) -> void:
	active_enemies = maxi(active_enemies - 1, 0)
	if not is_spawning and active_enemies == 0:
		if current_floor_config != null and (current_floor_config.floor_type == FloorConfig.FloorType.MINIBOSS or current_floor_config.floor_type == FloorConfig.FloorType.FINAL_BOSS):
			EventBus.floor_cleared.emit(current_floor_config.floor_index)


func _on_wave_timeout() -> void:
	is_spawning = false
	_spawn_timer.stop()
	EventBus.wave_ended.emit(current_floor_config.floor_index)
