class_name SpellSlot
extends Control
## An individual active spell button in the vertical Spell Bar.
## Auto-casts towards nearby enemies on cooldown, and supports mouse click or keyboard hotkey.

signal cast_requested(spell_id: String, level: int, target_pos: Vector2)

@export var hotkey_index: int = 1 # 1, 2, 3, 4, 5

var spell_id: String = ""
var level: int = 1
var cooldown_time: float = 3.5
var is_equipped: bool = false
var _cooldown_timer: float = 0.0

@onready var icon_rect: TextureRect = $IconRect
@onready var level_label: Label = $LevelLabel
@onready var hotkey_label: Label = $HotkeyLabel
@onready var cooldown_overlay: ColorRect = $CooldownOverlay
@onready var cooldown_label: Label = $CooldownOverlay/CooldownLabel
@onready var btn: BaseButton = $Button


func _ready() -> void:
	btn.pressed.connect(_on_pressed)
	hotkey_label.text = str(hotkey_index)
	clear_slot()


func clear_slot() -> void:
	is_equipped = false
	spell_id = ""
	level = 1
	_cooldown_timer = 0.0
	icon_rect.texture = null
	level_label.text = ""
	cooldown_overlay.visible = false
	btn.tooltip_text = "[%d] Ô Phép Thuật (Trống)" % hotkey_index


func setup_spell(p_id: String, p_lvl: int, p_icon: Texture2D, p_cooldown: float = 3.5) -> void:
	is_equipped = true
	spell_id = p_id
	level = p_lvl
	cooldown_time = p_cooldown
	icon_rect.texture = p_icon
	level_label.text = "L%d" % level
	hotkey_label.text = str(hotkey_index)

	var s_name: String = _get_spell_name(spell_id)
	btn.tooltip_text = "%s Lv.%d (Tự động bắn mỗi %.1fs | Nhấn [%d] hoặc Click để bắn)" % [
		s_name, level, cooldown_time, hotkey_index
	]


func _get_spell_name(s_id: String) -> String:
	match s_id:
		"fireball": return "Cầu Lửa (Fireball)"
		"meteor_rock": return "Mưa Thiên Thạch"
		"void_portal": return "Hố Đen Hư Không"
		"molten_spear": return "Thương Dung Nham"
		"earth_spike": return "Chông Gai Đất"
		"water_geyser": return "Thủy Long Bộc Phá"
		"tornado": return "Lốc Xoáy Cuồng Phong"
		_: return s_id.capitalize()


func set_level(new_lvl: int) -> void:
	level = new_lvl
	level_label.text = "L%d" % level
	var s_name: String = _get_spell_name(spell_id)
	btn.tooltip_text = "%s Lv.%d (Tự động bắn mỗi %.1fs | Nhấn [%d] hoặc Click để bắn)" % [
		s_name, level, cooldown_time, hotkey_index
	]
	var tw: Tween = create_tween()
	tw.tween_property(self, ^"scale", Vector2(1.25, 1.25), 0.1)
	tw.tween_property(self, ^"scale", Vector2(1.0, 1.0), 0.1)


func _process(delta: float) -> void:
	if not is_equipped:
		return

	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta
		cooldown_overlay.visible = true
		cooldown_label.text = "%.1fs" % _cooldown_timer
	else:
		if cooldown_overlay.visible:
			cooldown_overlay.visible = false
		# Auto-cast when ready!
		_auto_cast()


func _auto_cast() -> void:
	if not is_equipped or spell_id.is_empty():
		return
	var target_enemy: Node2D = _find_closest_enemy()
	if target_enemy != null and is_instance_valid(target_enemy):
		_cooldown_timer = cooldown_time
		cast_requested.emit(spell_id, level, target_enemy.global_position)


func _find_closest_enemy() -> Node2D:
	var players: Array[Node] = get_tree().get_nodes_in_group(&"player")
	if players.is_empty():
		return null
	var pl: Node2D = players[0] as Node2D
	if pl == null or not is_instance_valid(pl):
		return null

	var enemies: Array[Node] = get_tree().get_nodes_in_group(&"enemies")
	var closest: Node2D = null
	var min_dist: float = 320.0
	for e_node: Node in enemies:
		var enemy: Node2D = e_node as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		if "is_dead" in enemy and enemy.is_dead:
			continue
		var d: float = pl.global_position.distance_to(enemy.global_position)
		if d < min_dist:
			min_dist = d
			closest = enemy
	return closest


func _unhandled_input(event: InputEvent) -> void:
	if not is_equipped or spell_id.is_empty():
		return
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var key_code: Key = event.keycode
		var expected_key: Key = KEY_1 + (hotkey_index - 1)
		if key_code == expected_key:
			_try_cast()


func _on_pressed() -> void:
	_try_cast()


func _try_cast() -> void:
	if not is_equipped or spell_id.is_empty() or _cooldown_timer > 0.0:
		return
	_cooldown_timer = cooldown_time
	var mouse_pos: Vector2 = get_global_mouse_position()
	var players: Array[Node] = get_tree().get_nodes_in_group(&"player")
	if not players.is_empty():
		var pl: Node2D = players[0] as Node2D
		if pl != null and is_instance_valid(pl):
			mouse_pos = pl.get_global_mouse_position()
	cast_requested.emit(spell_id, level, mouse_pos)
