class_name HUD
extends CanvasLayer
## In-game HUD showing HP, Gold, Floor Progression, Wave Timer, and Boss Health Bar.

@onready var hp_bar: TextureProgressBar = $MarginContainer/VBoxContainer/TopBar/PlayerStatus/HPContainer/HPBar
@onready var hp_label: Label = $MarginContainer/VBoxContainer/TopBar/PlayerStatus/HPContainer/HPBar/HPLabel
@onready var heart_icon: TextureRect = $MarginContainer/VBoxContainer/TopBar/PlayerStatus/HPContainer/HeartIcon
@onready var buffs_container: HBoxContainer = $MarginContainer/VBoxContainer/TopBar/PlayerStatus/BuffsContainer
@onready var gold_label: Label = $MarginContainer/VBoxContainer/TopBar/GoldLabel
@onready var floor_label: Label = $MarginContainer/VBoxContainer/CenterBar/FloorLabel
@onready var timer_label: Label = $MarginContainer/VBoxContainer/CenterBar/TimerLabel

# Boss Bar
@onready var boss_bar_container: VBoxContainer = $MarginContainer/VBoxContainer/BossBarContainer
@onready var boss_name_label: Label = $MarginContainer/VBoxContainer/BossBarContainer/BossNameLabel
@onready var boss_hp_bar: TextureProgressBar = $MarginContainer/VBoxContainer/BossBarContainer/BossHPBar
@onready var boss_hp_label: Label = $MarginContainer/VBoxContainer/BossBarContainer/BossHPBar/BossHPLabel

@onready var game_over_panel: PanelContainer = $GameOverPanel
@onready var checkpoint_button: Button = get_node_or_null("GameOverPanel/Margin/VBox/Buttons/CheckpointButton") as Button
@onready var restart_button: Button = get_node_or_null("GameOverPanel/Margin/VBox/Buttons/RestartButton") as Button

@onready var endgame_panel: PanelContainer = $EndgamePanel
@onready var endgame_menu_btn: Button = $EndgamePanel/Margin/VBox/Buttons/MenuButton
@onready var endgame_darknight_btn: Button = $EndgamePanel/Margin/VBox/Buttons/DarkNightButton
@onready var screen_border: NinePatchRect = $ScreenBorder
@onready var boss_alert_panel: PanelContainer = $BossAlertPanel
@onready var alert_header_label: Label = $BossAlertPanel/Margin/VBox/AlertHeader
@onready var alert_sub_label: Label = $BossAlertPanel/Margin/VBox/AlertSubtitle

var spawner: Spawner = null
var _alert_tween: Tween = null


func _ready() -> void:
	game_over_panel.visible = false
	endgame_panel.visible = false
	boss_bar_container.visible = false
	if boss_alert_panel != null:
		boss_alert_panel.visible = false
	if restart_button != null:
		restart_button.pressed.connect(_on_restart_pressed)
	if checkpoint_button != null:
		checkpoint_button.pressed.connect(_on_checkpoint_pressed)
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
	EventBus.item_bought.connect(func(_id): _update_buffs_display())
	EventBus.item_picked.connect(func(_id): _update_buffs_display())

	_update_hp_display(GameManager.player_current_hp, GameManager.player_max_hp)
	_on_gold_changed(GameManager.gold)
	_update_buffs_display()
	_update_screen_border()


func _update_screen_border() -> void:
	if screen_border != null:
		if GameManager.is_dark_night:
			screen_border.modulate = Color(0.85, 0.6, 1.0, 0.95)
		else:
			screen_border.modulate = Color(1.0, 1.0, 1.0, 0.9)


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
	if float(current) / float(maxi(max_val, 1)) <= 0.3:
		hp_label.add_theme_color_override(&"font_color", Color(1.0, 0.35, 0.35))
		if heart_icon != null:
			heart_icon.modulate = Color(1.0, 0.4, 0.4)
	else:
		hp_label.add_theme_color_override(&"font_color", Color(1.0, 1.0, 1.0))
		if heart_icon != null:
			heart_icon.modulate = Color.WHITE


# ── Boss Bar & Alerts ───────────────────────────────────────────────────
func trigger_boss_alert(boss_name: String, is_final: bool = false, is_second_boss: bool = false) -> void:
	if boss_alert_panel == null:
		return

	if _alert_tween != null and _alert_tween.is_valid():
		_alert_tween.kill()

	if is_second_boss:
		alert_header_label.text = "CẢNH BÁO: TRÙM THỨ 2 XUẤT HIỆN!"
		alert_header_label.set("theme_override_colors/font_color", Color(1.0, 0.2, 0.15, 1.0))
		alert_sub_label.text = "SONG ĐẤU MA VƯƠNG — %s" % boss_name.to_upper()
	elif is_final:
		alert_header_label.text = "TỐI HẬU CẢNH BÁO: TRÙM CUỐI GIÁNG LÂM!"
		alert_header_label.set("theme_override_colors/font_color", Color(1.0, 0.35, 0.9, 1.0))
		alert_sub_label.text = "%s" % boss_name.to_upper()
	else:
		alert_header_label.text = "CẢNH BÁO: ĐẠI MA VƯƠNG XUẤT HIỆN!"
		alert_header_label.set("theme_override_colors/font_color", Color(1.0, 0.25, 0.15, 1.0))
		alert_sub_label.text = "%s" % boss_name.to_upper()

	if timer_label != null:
		timer_label.text = alert_header_label.text

	AudioManager.play_sfx("explosion")
	_shake_screen(6.0, 0.35)

	boss_alert_panel.visible = true
	boss_alert_panel.modulate.a = 0.0
	boss_alert_panel.scale = Vector2(1.25, 1.25)
	boss_alert_panel.pivot_offset = Vector2(190, 28)

	_alert_tween = create_tween()
	# Zoom & fade in with punch
	_alert_tween.parallel().tween_property(boss_alert_panel, ^"modulate:a", 1.0, 0.18)
	_alert_tween.parallel().tween_property(boss_alert_panel, ^"scale", Vector2.ONE, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	# Pulsing alert flash twice
	_alert_tween.tween_property(alert_header_label, ^"modulate", Color(2.0, 2.0, 2.0, 1.0), 0.15)
	_alert_tween.tween_property(alert_header_label, ^"modulate", Color.WHITE, 0.15)
	_alert_tween.tween_property(alert_header_label, ^"modulate", Color(2.0, 2.0, 2.0, 1.0), 0.15)
	_alert_tween.tween_property(alert_header_label, ^"modulate", Color.WHITE, 0.15)
	# Hold visible
	_alert_tween.tween_interval(1.4)
	# Fade out
	_alert_tween.tween_property(boss_alert_panel, ^"modulate:a", 0.0, 0.35)
	_alert_tween.tween_callback(func(): boss_alert_panel.visible = false)


func _shake_screen(amount: float, duration: float) -> void:
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam == null:
		return
	var orig_offset: Vector2 = cam.offset
	var tw: Tween = create_tween()
	var steps: int = int(duration / 0.05)
	for i: int in range(steps):
		var damp: float = 1.0 - (float(i) / float(steps))
		var shake_vec: Vector2 = orig_offset + Vector2(randf_range(-amount, amount), randf_range(-amount, amount)) * damp
		tw.tween_property(cam, ^"offset", shake_vec, 0.05)
	tw.tween_property(cam, ^"offset", orig_offset, 0.05)


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
	timer_label.text = "CHIẾN THẮNG TRÙM! HÃY NHẶT VÀNG TRƯỚC KHI CHỌN THƯỞNG..."
	timer_label.visible = true


func _update_buffs_display() -> void:
	if buffs_container == null:
		return
	for child: Node in buffs_container.get_children():
		child.queue_free()

	for buff: ItemData in GameManager.passive_buffs:
		if buff == null:
			continue
		var icon_rect: TextureRect = TextureRect.new()
		icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon_rect.custom_minimum_size = Vector2(16, 16)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if not buff.custom_icon_path.is_empty() and ResourceLoader.exists(buff.custom_icon_path):
			icon_rect.texture = load(buff.custom_icon_path)
		else:
			var atlas: AtlasTexture = AtlasTexture.new()
			atlas.atlas = preload("res://assets/sprites/items.png")
			atlas.region = buff.sprite_region
			icon_rect.texture = atlas

		if buff.level > 1:
			icon_rect.tooltip_text = "%s (Cấp %d): %s" % [buff.item_name, buff.level, buff.description]
			var lvl_lbl: Label = Label.new()
			lvl_lbl.text = "%d" % buff.level
			lvl_lbl.add_theme_font_size_override(&"font_size", 8)
			lvl_lbl.add_theme_color_override(&"font_color", Color(1.0, 0.9, 0.2))
			lvl_lbl.add_theme_color_override(&"font_shadow_color", Color.BLACK)
			lvl_lbl.add_theme_constant_override(&"shadow_offset_x", 1)
			lvl_lbl.add_theme_constant_override(&"shadow_offset_y", 1)
			lvl_lbl.position = Vector2(9, 6)
			icon_rect.add_child(lvl_lbl)
		else:
			icon_rect.tooltip_text = "%s: %s" % [buff.item_name, buff.description]

		buffs_container.add_child(icon_rect)


func _on_gold_changed(new_gold: int) -> void:
	gold_label.text = "Gold: %d" % new_gold


func _on_player_hit(_damage: int) -> void:
	_update_hp_display(GameManager.player_current_hp, GameManager.player_max_hp)


func _on_player_died() -> void:
	_update_hp_display(0, GameManager.player_max_hp)
	if checkpoint_button != null:
		checkpoint_button.text = "Hồi Sinh Checkpoint (Tầng %d)" % GameManager.current_floor_index
	game_over_panel.visible = true


func _on_checkpoint_pressed() -> void:
	game_over_panel.visible = false
	if SaveManager.resume_saved_run():
		GameManager.player_current_hp = GameManager.player_max_hp
		get_tree().reload_current_scene()
	else:
		_on_restart_pressed()


func _on_wave_started(floor_idx: int) -> void:
	_update_screen_border()
	var cfg: FloorConfig = GameManager.get_current_floor_config()
	var type_str: String = "QUÁI VẬT"
	if cfg != null:
		match cfg.floor_type:
			FloorConfig.FloorType.COMBAT_WAVE: type_str = "QUÁI VẬT"
			FloorConfig.FloorType.MINIBOSS: type_str = "TRÙM PHỤ"
			FloorConfig.FloorType.NPC_SANCTUARY: type_str = "THƯƠNG NHÂN"
			FloorConfig.FloorType.FINAL_BOSS: type_str = "TRÙM CUỐI"

	var prefix: String = ""
	if GameManager.is_dark_night:
		prefix = "[ĐÊM TỐI C%d] " % GameManager.dark_night_cycle

	var total_floors: int = GameManager.floor_configs.size() if not GameManager.floor_configs.is_empty() else 100
	floor_label.text = "%sTầng %d/%d — %s" % [prefix, floor_idx, total_floors, type_str]
	if spawner != null and not spawner.is_spawning and cfg != null and cfg.floor_type == FloorConfig.FloorType.COMBAT_WAVE:
		floor_label.text = "%sTầng %d/%d — THƯƠNG NHÂN" % [prefix, floor_idx, total_floors]
		timer_label.text = "KHU VỰC AN TOÀN"
	if cfg == null or (cfg.floor_type != FloorConfig.FloorType.MINIBOSS and cfg.floor_type != FloorConfig.FloorType.FINAL_BOSS):
		hide_boss_bar()


func _on_wave_ended(_floor_idx: int) -> void:
	timer_label.text = "HOÀN THÀNH TẦNG!"


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
