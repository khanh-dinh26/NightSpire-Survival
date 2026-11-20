class_name HUD
extends CanvasLayer
## In-game HUD showing HP, Gold, Floor Progression, Wave Timer, and Boss Health Bar.

@onready var hp_bar: ProgressBar = $MarginContainer/VBoxContainer/TopBar/HPBar
@onready var hp_label: Label = $MarginContainer/VBoxContainer/TopBar/HPBar/HPLabel
@onready var gold_label: Label = $MarginContainer/VBoxContainer/TopBar/GoldLabel
@onready var floor_label: Label = $MarginContainer/VBoxContainer/CenterBar/FloorLabel
@onready var timer_label: Label = $MarginContainer/VBoxContainer/CenterBar/TimerLabel

# Boss Bar
@onready var boss_bar_container: VBoxContainer = $MarginContainer/VBoxContainer/BossBarContainer
@onready var boss_name_label: Label = $MarginContainer/VBoxContainer/BossBarContainer/BossNameLabel
@onready var boss_hp_bar: ProgressBar = $MarginContainer/VBoxContainer/BossBarContainer/BossHPBar
@onready var boss_hp_label: Label = $MarginContainer/VBoxContainer/BossBarContainer/BossHPBar/BossHPLabel

@onready var game_over_panel: PanelContainer = $GameOverPanel
@onready var restart_button: Button = $GameOverPanel/Margin/VBox/RestartButton

@onready var endgame_panel: PanelContainer = $EndgamePanel
@onready var endgame_menu_btn: Button = $EndgamePanel/Margin/VBox/Buttons/MenuButton
@onready var endgame_darknight_btn: Button = $EndgamePanel/Margin/VBox/Buttons/DarkNightButton

var spawner: Spawner = null


func _ready() -> void:
	game_over_panel.visible = false
	endgame_panel.visible = false
	boss_bar_container.visible = false
	if restart_button != null:
		restart_button.pressed.connect(_on_restart_pressed)
	if endgame_menu_btn != null:
		endgame_menu_btn.pressed.connect(_on_endgame_menu_pressed)
	if endgame_darknight_btn != null:
		endgame_darknight_btn.pressed.connect(_on_endgame_darknight_pressed)

	EventBus.gold_changed.connect(_on_gold_changed)
	EventBus.player_hit.connect(_on_player_hit)
	EventBus.player_died.connect(_on_player_died)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_ended.connect(_on_wave_ended)
	EventBus.boss_killed.connect(_on_boss_killed)
	EventBus.tower_conquered.connect(_on_tower_conquered)

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


# ── Boss Bar ────────────────────────────────────────────────────────────
func show_boss_bar(boss_name: String, max_hp_val: int) -> void:
	boss_name_label.text = "BOSS: %s" % boss_name
	boss_hp_bar.max_value = max_hp_val
	boss_hp_bar.value = max_hp_val
	boss_hp_label.text = "%d / %d" % [max_hp_val, max_hp_val]
	boss_bar_container.visible = true


func update_boss_hp(current: int, max_hp_val: int) -> void:
	boss_hp_bar.max_value = max_hp_val
	boss_hp_bar.value = current
	boss_hp_label.text = "%d / %d" % [current, max_hp_val]


func hide_boss_bar() -> void:
	boss_bar_container.visible = false


func _on_boss_killed(_boss_id: String) -> void:
	hide_boss_bar()


func _on_gold_changed(new_gold: int) -> void:
	gold_label.text = "Gold: %d" % new_gold


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

	var prefix: String = ""
	if GameManager.is_dark_night:
		prefix = "[DARK NIGHT C%d] " % GameManager.dark_night_cycle

	floor_label.text = "%sFloor %d/10 — %s" % [prefix, floor_idx, type_str]
	if spawner != null and not spawner.is_spawning and cfg != null and cfg.floor_type == FloorConfig.FloorType.COMBAT_WAVE:
		floor_label.text = "%sFloor %d/10 — SANCTUARY" % [prefix, floor_idx]
	if cfg == null or (cfg.floor_type != FloorConfig.FloorType.MINIBOSS and cfg.floor_type != FloorConfig.FloorType.FINAL_BOSS):
		hide_boss_bar()


func _on_wave_ended(_floor_idx: int) -> void:
	timer_label.text = "WAVE CLEARED!"


func _on_restart_pressed() -> void:
	SaveManager.delete_save()
	get_tree().change_scene_to_file("res://src/ui/TowerSelect.tscn")


func _on_tower_conquered() -> void:
	endgame_panel.visible = true


func _on_endgame_menu_pressed() -> void:
	SaveManager.delete_save()
	get_tree().change_scene_to_file("res://src/ui/MainMenu.tscn")


func _on_endgame_darknight_pressed() -> void:
	endgame_panel.visible = false
	GameManager.is_dark_night = true
	GameManager.dark_night_cycle += 1
	GameManager.current_floor_index = 1
	var players: Array[Node] = get_tree().get_nodes_in_group(&"player")
	if players.size() > 0:
		var p: Player = players[0] as Player
		if p != null:
			p.heal(p.max_hp)
	EventBus.floor_transition_requested.emit(1)
