class_name SpellSlot
extends Control
## An individual spell inventory slot in the vertical Spell Bar.
## Styled identically to weapon inventory slots (Sample-InventorySlotsSet.png).
## Auto-casts towards nearby enemies on cooldown, and supports mouse click to cast.

signal cast_requested(spell_id: String, level: int, target_pos: Vector2)

@export var slot_index: int = 0

var spell_id: String = ""
var level: int = 1
var cooldown_time: float = 3.5
var is_equipped: bool = false
var _cooldown_timer: float = 0.0

@onready var frame_rect: TextureRect = $FrameRect
@onready var icon_rect: TextureRect = $IconRect
@onready var level_label: Label = $LevelLabel
@onready var cooldown_overlay: ColorRect = $CooldownOverlay
@onready var cooldown_label: Label = $CooldownOverlay/CooldownLabel
@onready var click_btn: Button = $ClickButton

var _slot_sheet: Texture2D = preload("res://assets/sprites/Sample-InventorySlotsSet.png")


func _ready() -> void:
	# Configure slot frame from Sample-InventorySlotsSet.png (24x24 slot at 112, 79)
	var slot_atlas: AtlasTexture = AtlasTexture.new()
	slot_atlas.atlas = _slot_sheet
	slot_atlas.region = Rect2(112, 79, 24, 24)
	frame_rect.texture = slot_atlas

	click_btn.pressed.connect(_on_pressed)
	clear_slot()


func clear_slot() -> void:
	is_equipped = false
	spell_id = ""
	level = 1
	_cooldown_timer = 0.0
	icon_rect.texture = null
	icon_rect.visible = false
	level_label.text = ""
	level_label.visible = false
	cooldown_overlay.visible = false
	click_btn.tooltip_text = "Ô Phép (Trống)"


func setup_spell(p_id: String, p_lvl: int, p_icon: Texture2D, p_cooldown: float = 3.5) -> void:
	is_equipped = true
	spell_id = p_id
	level = p_lvl
	cooldown_time = p_cooldown
	icon_rect.texture = p_icon
	icon_rect.visible = true
	level_label.text = "L%d" % level
	level_label.visible = (level > 1)

	var s_name: String = _get_spell_name(spell_id)
	click_btn.tooltip_text = "%s Lv.%d (Hồi: %.1fs)" % [s_name, level, cooldown_time]


func _get_spell_name(s_id: String) -> String:
	match s_id:
		"fireball": return "Phép: Cầu Lửa"
		"meteor_rock": return "Phép: Mưa Thiên Thạch"
		"void_portal": return "Phép: Hố Đen Hư Không"
		"molten_spear": return "Phép: Thương Dung Nham"
		"earth_spike": return "Phép: Gai Đất"
		"water_geyser": return "Phép: Thủy Long Bộc Phá"
		"tornado": return "Phép: Lốc Xoáy Cuồng Phong"
		_: return s_id.capitalize()


func set_level(new_lvl: int) -> void:
	level = new_lvl
	level_label.text = "L%d" % level
	level_label.visible = (level > 1)
	var s_name: String = _get_spell_name(spell_id)
	click_btn.tooltip_text = "%s Lv.%d (Hồi: %.1fs)" % [s_name, level, cooldown_time]
	var tw: Tween = create_tween()
	tw.tween_property(self, ^"scale", Vector2(1.2, 1.2), 0.1)
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
		var diff: Vector2 = enemy.global_position - pl.global_position
		# Strictly limit targeting to enemies visible within the 640x360 screen viewport
		if absf(diff.x) > 290.0 or absf(diff.y) > 155.0:
			continue
		var d: float = diff.length()
		if d < min_dist:
			min_dist = d
			closest = enemy
	return closest


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
			var diff: Vector2 = mouse_pos - pl.global_position
			diff.x = clampf(diff.x, -290.0, 290.0)
			diff.y = clampf(diff.y, -155.0, 155.0)
			mouse_pos = pl.global_position + diff
	cast_requested.emit(spell_id, level, mouse_pos)
