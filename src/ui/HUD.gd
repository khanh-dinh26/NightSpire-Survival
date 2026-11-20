class_name HUD
extends CanvasLayer
## In-game HUD showing HP, Gold, Floor Progression, and Wave Timer.

@onready var hp_bar: ProgressBar = $MarginContainer/VBoxContainer/TopBar/HPBar
@onready var hp_label: Label = $MarginContainer/VBoxContainer/TopBar/HPBar/HPLabel
@onready var gold_label: Label = $MarginContainer/VBoxContainer/TopBar/GoldLabel
@onready var floor_label: Label = $MarginContainer/VBoxContainer/CenterBar/FloorLabel
@onready var timer_label: Label = $MarginContainer/VBoxContainer/CenterBar/TimerLabel
@onready var game_over_panel: PanelContainer = $GameOverPanel

var spawner: Spawner = null


func _ready() -> void:
	game_over_panel.visible = false

	EventBus.gold_changed.connect(_on_gold_changed)
	EventBus.player_hit.connect(_on_player_hit)
	EventBus.player_died.connect(_on_player_died)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_ended.connect(_on_wave_ended)

	# Initial values
	_update_hp_display(GameManager.player_current_hp, GameManager.player_max_hp)
	_on_gold_changed(GameManager.gold)


func setup_spawner(p_spawner: Spawner) -> void:
	spawner = p_spawner


func _process(_delta: float) -> void:
	if spawner != null and spawner.is_spawning:
		timer_label.text = "Time: %02ds" % ceili(spawner.time_remaining)
		timer_label.visible = true
	else:
		timer_label.visible = false


func _update_hp_display(current: int, max_val: int) -> void:
	hp_bar.max_value = max_val
	hp_bar.value = current
	hp_label.text = "%d / %d" % [current, max_val]


func _on_gold_changed(new_gold: int) -> void:
	gold_label.text = "🪙 Gold: %d" % new_gold


func _on_player_hit(_damage: int) -> void:
	_update_hp_display(GameManager.player_current_hp, GameManager.player_max_hp)


func _on_player_died() -> void:
	_update_hp_display(0, GameManager.player_max_hp)
	game_over_panel.visible = true


func _on_wave_started(floor_idx: int) -> void:
	var cfg: FloorConfig = GameManager.get_current_floor_config()
	var type_str: String = "WAVE"
	if cfg != null:
		match cfg.floor_type:
			FloorConfig.FloorType.COMBAT_WAVE: type_str = "WAVE"
			FloorConfig.FloorType.MINIBOSS: type_str = "MINI-BOSS"
			FloorConfig.FloorType.NPC_SANCTUARY: type_str = "SANCTUARY"
			FloorConfig.FloorType.FINAL_BOSS: type_str = "FINAL BOSS"

	floor_label.text = "Floor %d/10 — %s" % [floor_idx, type_str]


func _on_wave_ended(_floor_idx: int) -> void:
	timer_label.text = "WAVE CLEARED!"
