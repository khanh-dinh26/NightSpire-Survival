class_name ItemCard
extends PanelContainer
## Reusable card displaying an ItemData with pixel art icon, rarity border, stats, and buy/choose button.

signal item_selected(card: ItemCard, item: ItemData)

@export var item_data: ItemData = null
@export var is_free: bool = false

@onready var icon_rect: TextureRect = $Margin/VBox/IconCenter/IconRect
@onready var name_label: Label = $Margin/VBox/NameLabel
@onready var type_badge: Label = $Margin/VBox/TypeBadge
@onready var desc_label: Label = $Margin/VBox/DescLabel
@onready var action_btn: Button = $Margin/VBox/ActionButton
@onready var frame_bg: NinePatchRect = $FrameBackground

var is_bought: bool = false
var _items_tex: Texture2D = preload("res://assets/sprites/items.png")


func setup(data: ItemData, p_is_free: bool = false) -> void:
	item_data = data
	is_free = p_is_free
	is_bought = false
	_refresh_display()


func _ready() -> void:
	action_btn.pressed.connect(_on_action_pressed)
	if item_data != null:
		_refresh_display()


func _refresh_display() -> void:
	if item_data == null:
		return

	# Icon
	if not item_data.custom_icon_path.is_empty() and ResourceLoader.exists(item_data.custom_icon_path):
		icon_rect.texture = load(item_data.custom_icon_path)
	else:
		var atlas_tex: AtlasTexture = AtlasTexture.new()
		atlas_tex.atlas = _items_tex
		atlas_tex.region = item_data.sprite_region
		icon_rect.texture = atlas_tex

	# Name & Rarity Color
	name_label.text = item_data.item_name
	var rarity_color: Color = _get_rarity_color(item_data.rarity)
	name_label.add_theme_color_override(&"font_color", rarity_color)
	if frame_bg != null:
		frame_bg.modulate = rarity_color

	# Type Badge
	if item_data.type == ItemData.ItemType.WEAPON:
		var existing_lvl: int = 1
		var owned: bool = false
		for eq: ItemData in GameManager.equipped_weapons:
			if eq.item_id == item_data.item_id:
				owned = true
				existing_lvl = eq.level
				break
		if owned:
			type_badge.text = "[ WEAPON -> Lv.%d ]" % (existing_lvl + 1)
			type_badge.add_theme_color_override(&"font_color", Color(1.0, 0.8, 0.3))
		else:
			type_badge.text = "[ WEAPON ]"
			type_badge.add_theme_color_override(&"font_color", Color(0.7, 0.7, 0.7))
	elif item_data.type == ItemData.ItemType.SPELL:
		var s_id: String = item_data.spell_id if not item_data.spell_id.is_empty() else item_data.item_id
		var lvl: int = GameManager.learned_spells.get(s_id, 0)
		if lvl > 0:
			type_badge.text = "[ KHẢM PHÉP -> Lv.%d ]" % (lvl + 1)
			type_badge.add_theme_color_override(&"font_color", Color(1.0, 0.7, 0.2))
		else:
			type_badge.text = "[ KHẢM PHÉP ]"
			type_badge.add_theme_color_override(&"font_color", Color(0.3, 0.8, 1.0))
	else:
		type_badge.text = "[ RELIC / BUFF ]"
		type_badge.add_theme_color_override(&"font_color", Color(0.4, 0.9, 0.4))

	# Description
	if item_data.type == ItemData.ItemType.WEAPON:
		var extra_effect: String = ""
		if not item_data.special_effect.is_empty():
			extra_effect = "\n[Đặc tính: %s]" % item_data.special_effect
		if not item_data.embedded_spell.is_empty():
			extra_effect += "\n[Khảm Phép: %s Lv.%d (Tự Động Bắn)]" % [
				item_data.embedded_spell.capitalize(), item_data.embedded_spell_level
			]
		desc_label.text = "Damage: %d  |  Speed: %.1f/s%s\n%s" % [
			item_data.base_damage,
			item_data.attack_speed,
			extra_effect,
			item_data.description
		]
	elif item_data.type == ItemData.ItemType.SPELL:
		desc_label.text = "Khảm vào vũ khí: Tự động bắn mỗi %.1fs\n%s" % [
			item_data.cooldown,
			item_data.description
		]
	else:
		desc_label.text = item_data.description

	# Action Button state
	update_button_state()


func update_button_state() -> void:
	if is_bought:
		action_btn.text = "BOUGHT"
		action_btn.disabled = true
		modulate = Color(0.6, 0.6, 0.6, 0.8)
		return

	modulate = Color.WHITE
	if is_free:
		action_btn.text = "SELECT (FREE)"
		action_btn.disabled = false
	else:
		action_btn.text = "%d Gold" % item_data.price
		action_btn.disabled = (GameManager.gold < item_data.price)


func _on_action_pressed() -> void:
	if is_bought:
		return
	item_selected.emit(self, item_data)


func mark_as_bought() -> void:
	is_bought = true
	update_button_state()


func _get_rarity_color(rarity: ItemData.Rarity) -> Color:
	match rarity:
		ItemData.Rarity.COMMON:
			return Color(0.85, 0.85, 0.85)
		ItemData.Rarity.RARE:
			return Color(0.3, 0.7, 1.0)
		ItemData.Rarity.EPIC:
			return Color(0.8, 0.4, 1.0)
		ItemData.Rarity.LEGENDARY:
			return Color(1.0, 0.8, 0.2)
	return Color.WHITE
