class_name SpellSlot
extends Control
## An individual active spell button in the vertical Spell Bar.
## Supports mouse click or keyboard hotkey to cast towards the mouse cursor.

signal cast_requested(spell_id: String, level: int)

@export var hotkey_index: int = 1 # 1, 2, 3...

var spell_id: String = ""
var level: int = 1
var cooldown_time: float = 3.5
var _cooldown_timer: float = 0.0

@onready var icon_rect: TextureRect = $IconRect
@onready var level_label: Label = $LevelLabel
@onready var hotkey_label: Label = $HotkeyLabel
@onready var cooldown_overlay: ColorRect = $CooldownOverlay
@onready var cooldown_label: Label = $CooldownOverlay/CooldownLabel
@onready var btn: Button = $Button


func _ready() -> void:
	btn.pressed.connect(_on_pressed)
	cooldown_overlay.visible = false
	hotkey_label.text = str(hotkey_index)


func setup_spell(p_id: String, p_lvl: int, p_icon: Texture2D, p_cooldown: float = 3.5) -> void:
	spell_id = p_id
	level = p_lvl
	cooldown_time = p_cooldown
	icon_rect.texture = p_icon
	level_label.text = "Lv.%d" % level
	hotkey_label.text = str(hotkey_index)

	match spell_id:
		"fireball":
			btn.tooltip_text = "Cầu Lửa (Fireball) Lv.%d\nBắn cầu lửa phát nổ diện rộng." % level
		"molten_spear":
			btn.tooltip_text = "Thương Dung Nham Lv.%d\nBắn thương lửa bay cực nhanh xuyên thấu quái." % level
		"tornado":
			btn.tooltip_text = "Lốc Xoáy Lv.%d\nHút quái vật và gây sát thương xoáy liên tục." % level
		"earth_spike":
			btn.tooltip_text = "Gai Đất Lv.%d\nTriệu hồi gai nhọn trồi lên làm choáng mục tiêu." % level
		_:
			btn.tooltip_text = "%s Lv.%d" % [spell_id, level]


func set_level(new_lvl: int) -> void:
	level = new_lvl
	level_label.text = "Lv.%d" % level
	# Visual pulse when upgraded
	var tw: Tween = create_tween()
	tw.tween_property(self, ^"scale", Vector2(1.25, 1.25), 0.1)
	tw.tween_property(self, ^"scale", Vector2(1.0, 1.0), 0.1)


func _process(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta
		cooldown_overlay.visible = true
		cooldown_label.text = "%.1fs" % _cooldown_timer
	else:
		if cooldown_overlay.visible:
			cooldown_overlay.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if spell_id.is_empty():
		return
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var key_code: Key = event.keycode
		var expected_key: Key = KEY_1 + (hotkey_index - 1)
		if key_code == expected_key:
			_try_cast()


func _on_pressed() -> void:
	_try_cast()


func _try_cast() -> void:
	if spell_id.is_empty() or _cooldown_timer > 0.0:
		return
	_cooldown_timer = cooldown_time
	cast_requested.emit(spell_id, level)
