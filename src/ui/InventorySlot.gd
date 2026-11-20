class_name InventorySlot
extends Control
## An individual inventory slot frame using Sample-InventorySlotsSet.png.

signal slot_clicked(slot_index: int, item: ItemData)

@export var slot_index: int = 0

@onready var frame_rect: TextureRect = $FrameRect
@onready var icon_rect: TextureRect = $IconRect
@onready var click_btn: Button = $ClickButton

var current_item: ItemData = null
var _slot_sheet: Texture2D = preload("res://assets/sprites/Sample-InventorySlotsSet.png")
var _items_tex: Texture2D = preload("res://assets/sprites/items.png")


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
		click_btn.tooltip_text = "%s (Damage: %d)\nClick to DROP" % [item.item_name, item.base_damage]
	else:
		clear_slot()


func clear_slot() -> void:
	current_item = null
	icon_rect.texture = null
	icon_rect.visible = false
	click_btn.tooltip_text = "Empty Slot"


func _on_click_pressed() -> void:
	if current_item != null:
		slot_clicked.emit(slot_index, current_item)
