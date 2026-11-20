class_name InventorySlot
extends Control
## An individual inventory slot frame using Sample-InventorySlotsSet.png.

signal slot_clicked(slot_index: int, item: ItemData)

@export var slot_index: int = 0

@onready var frame_rect: TextureRect = $FrameRect
@onready var icon_rect: TextureRect = $IconRect
@onready var click_btn: Button = $ClickButton
@onready var level_label: Label = $LevelLabel
@onready var emblem_rect: TextureRect = $EmblemRect
@onready var emblem_level_label: Label = $EmblemLevelLabel

var current_item: ItemData = null
var _slot_sheet: Texture2D = preload("res://assets/sprites/Sample-InventorySlotsSet.png")
var _items_tex: Texture2D = preload("res://assets/sprites/items.png")

var _spell_icons: Dictionary = {
	"fireball": preload("res://assets/effects/magic_effects/Icons/tile000.png"),
	"molten_spear": preload("res://assets/effects/magic_effects/Icons/tile006.png"),
	"earth_spike": preload("res://assets/effects/magic_effects/Icons/tile007.png"),
	"tornado": preload("res://assets/effects/magic_effects/Icons/tile009.png"),
}


func _ready() -> void:
	# Configure slot frame from Sample-InventorySlotsSet.png (24x24 slot at 112, 79)
	var slot_atlas: AtlasTexture = AtlasTexture.new()
	slot_atlas.atlas = _slot_sheet
	slot_atlas.region = Rect2(112, 79, 24, 24)
	frame_rect.texture = slot_atlas

	click_btn.pressed.connect(_on_click_pressed)
	clear_slot()


func set_item(item: ItemData, idx: int) -> void:
	slot_index = idx
	current_item = item

	if item != null:
		var item_atlas: AtlasTexture = AtlasTexture.new()
		item_atlas.atlas = _items_tex
		item_atlas.region = item.sprite_region
		icon_rect.texture = item_atlas
		icon_rect.visible = true
		
		if level_label != null:
			if item.level > 1:
				level_label.text = "L%d" % item.level
				level_label.visible = true
			else:
				level_label.visible = false

		var effect_text: String = ""
		if not item.special_effect.is_empty():
			effect_text += "\nHiệu ứng: %s" % ItemData.get_special_effect_name(item.special_effect)

		if emblem_rect != null:
			if not item.embedded_spell.is_empty() and _spell_icons.has(item.embedded_spell):
				emblem_rect.texture = _spell_icons[item.embedded_spell]
				emblem_rect.visible = true
				if emblem_level_label != null:
					emblem_level_label.text = "L%d" % item.embedded_spell_level
					emblem_level_label.visible = true
				effect_text += "\n[Khảm Phép: %s Lv.%d (Tự Động Bắn)]" % [
					item.embedded_spell.capitalize(), item.embedded_spell_level
				]
			else:
				emblem_rect.visible = false
				if emblem_level_label != null:
					emblem_level_label.visible = false

		click_btn.tooltip_text = "%s (Lv.%d | Damage: %d)%s\nClick to DROP" % [
			item.item_name, item.level, item.base_damage, effect_text
		]
	else:
		clear_slot()


func clear_slot() -> void:
	current_item = null
	icon_rect.texture = null
	icon_rect.visible = false
	if level_label != null:
		level_label.visible = false
	if emblem_rect != null:
		emblem_rect.visible = false
	if emblem_level_label != null:
		emblem_level_label.visible = false
	click_btn.tooltip_text = "Empty Slot"


func _on_click_pressed() -> void:
	if current_item != null:
		slot_clicked.emit(slot_index, current_item)
