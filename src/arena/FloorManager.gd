class_name FloorManager
extends Node
## Orchestrates floor progression, transitions, and run lifecycle.

@export var arena: Arena = null
@export var spawner: Spawner = null
@export var player: Player = null

var default_tower: TowerData = preload("res://src/data/towers/blightwood_spire.tres")
var all_floor_configs: Array[FloorConfig] = []


func _ready() -> void:
	_load_floor_configs()

	EventBus.wave_ended.connect(_on_wave_ended)
	EventBus.floor_cleared.connect(_on_floor_cleared)
	EventBus.floor_transition_requested.connect(_on_floor_transition_requested)
	EventBus.player_died.connect(_on_player_died)

	# Auto-start run on ready if not yet started
	call_deferred(&"start_default_run")


func _load_floor_configs() -> void:
	all_floor_configs.clear()
	for i: int in range(1, 11):
		var path: String = "res://src/data/floors/floor_%02d.tres" % i
		if ResourceLoader.exists(path):
			var config: FloorConfig = load(path) as FloorConfig
			all_floor_configs.append(config)


func start_default_run() -> void:
	GameManager.start_new_run(default_tower, all_floor_configs)
	start_floor(1)


func start_floor(floor_num: int) -> void:
	var config: FloorConfig = null
	if floor_num >= 1 and floor_num <= all_floor_configs.size():
		config = all_floor_configs[floor_num - 1]
	else:
		return

	# Setup arena tiles and dimensions
	if arena != null:
		arena.setup_floor(GameManager.current_tower, config)

	# Reset player to center
	if player != null and arena != null:
		player.global_position = arena.get_center_position()

	# Start enemy spawner
	if spawner != null:
		spawner.start_floor(GameManager.current_tower, config)


func _on_wave_ended(floor_index: int) -> void:
	# Wave survived! Automatically clear remaining enemies and allow next floor
	if spawner != null:
		spawner.stop_spawning()

	# For Phase 1, transition to next floor after brief delay
	var tw: Tween = create_tween()
	tw.tween_interval(2.0)
	tw.tween_callback(func(): GameManager.advance_floor())


func _on_floor_cleared(floor_index: int) -> void:
	# Boss/Miniboss cleared!
	var tw: Tween = create_tween()
	tw.tween_interval(2.0)
	tw.tween_callback(func(): GameManager.advance_floor())


func _on_floor_transition_requested(next_floor_index: int) -> void:
	# Fade transition
	var canvas_mod: CanvasModulate = get_tree().current_scene.get_node_or_null("ScreenFade") as CanvasModulate
	if canvas_mod != null:
		var tw: Tween = create_tween()
		tw.tween_property(canvas_mod, ^"color", Color.BLACK, 0.4)
		tw.tween_callback(func(): start_floor(next_floor_index))
		tw.tween_property(canvas_mod, ^"color", Color.WHITE, 0.4)
	else:
		start_floor(next_floor_index)


func _on_player_died() -> void:
	if spawner != null:
		spawner.stop_spawning()
