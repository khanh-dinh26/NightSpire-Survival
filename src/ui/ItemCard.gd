class_name ItemCard
extends PanelContainer
## Reusable card displaying an ItemData with pixel art icon, rarity border, stats, and buy/choose button.

signal item_selected(card: ItemCard, item: ItemData)

@export var item_data: ItemData = null
@export var is_free: bool = false

@onready var icon_row: HBoxContainer = $Margin/VBox/IconRow
@onready var icon_rect: TextureRect = $Margin/VBox/IconRow/IconRect
@onready var emblem_rect: TextureRect = $Margin/VBox/IconRow/EmblemRect
@onready var name_label: Label = $Margin/VBox/NameLabel
@onready var type_badge: Label = $Margin/VBox/TypeBadge
@onready var desc_label: Label = $Margin/VBox/DescLabel
@onready var action_btn: Button = $Margin/VBox/ActionButton
@onready var frame_bg: NinePatchRect = $FrameBackground

var is_bought: bool = false
var _items_tex: Texture2D = preload("res://assets/sprites/items.png")

var _spell_icons: Dictionary = {
	"fireball": preload("res://assets/effects/magic_effects/Icons/tile000.png"),
	"meteor_rock": preload("res://assets/effects/magic_effects/Icons/tile001.png"),
	"void_portal": preload("res://assets/effects/magic_effects/Icons/tile004.png"),
	"molten_spear": preload("res://assets/effects/magic_effects/Icons/tile006.png"),
	"earth_spike": preload("res://assets/effects/magic_effects/Icons/tile007.png"),
	"water_geyser": preload("res://assets/effects/magic_effects/Icons/tile008.png"),
	"tornado": preload("res://assets/effects/magic_effects/Icons/tile009.png"),
}


var custom_price: int = -1


func setup(data: ItemData, p_is_free: bool = false, price_override: int = -1) -> void:
	item_data = data
	is_free = p_is_free
	is_bought = false
	custom_price = price_override
	_refresh_display()


func _ready() -> void:
	action_btn.pressed.connect(_on_action_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	if item_data != null:
		_refresh_display()


func _on_mouse_entered() -> void:
	if not is_bought:
		modulate = Color(1.15, 1.15, 1.1, 1.0)


func _on_mouse_exited() -> void:
	if not is_bought:
		modulate = Color(1.0, 1.0, 1.0, 1.0)


func _refresh_display() -> void:
	if item_data == null:
		return

	# Icon display
	if not item_data.custom_icon_path.is_empty() and ResourceLoader.exists(item_data.custom_icon_path):
		icon_rect.texture = load(item_data.custom_icon_path)
	else:
		var atlas_tex: AtlasTexture = AtlasTexture.new()
		atlas_tex.atlas = _items_tex
		atlas_tex.region = item_data.sprite_region
		icon_rect.texture = atlas_tex

	# Spell Emblem on weapon card
	if emblem_rect != null:
		if item_data.type == ItemData.ItemType.WEAPON and not item_data.embedded_spell.is_empty() and _spell_icons.has(item_data.embedded_spell):
			emblem_rect.texture = _spell_icons[item_data.embedded_spell]
			emblem_rect.visible = true
		else:
			emblem_rect.visible = false

	# Name & Rarity Color
	name_label.text = item_data.item_name.replace("Khảm Phép:", "Phép:").strip_edges()
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
			type_badge.text = "[ VŨ KHÍ -> Lv.%d ]" % (existing_lvl + 1)
			type_badge.add_theme_color_override(&"font_color", Color(1.0, 0.8, 0.3))
		else:
			type_badge.text = "[ VŨ KHÍ ]"
			type_badge.add_theme_color_override(&"font_color", Color(0.7, 0.7, 0.7))
	elif item_data.type == ItemData.ItemType.SPELL:
		var s_id: String = item_data.spell_id if not item_data.spell_id.is_empty() else item_data.item_id
		var lvl: int = GameManager.learned_spells.get(s_id, 0)
		if lvl > 0:
			type_badge.text = "[ PHÉP THUẬT -> Lv.%d ]" % (lvl + 1)
			type_badge.add_theme_color_override(&"font_color", Color(1.0, 0.7, 0.2))
		else:
			type_badge.text = "[ PHÉP THUẬT ]"
			type_badge.add_theme_color_override(&"font_color", Color(0.3, 0.8, 1.0))
	elif item_data.type == ItemData.ItemType.PASSIVE_BUFF:
		var existing_lvl: int = 1
		var owned: bool = false
		for b: ItemData in GameManager.passive_buffs:
			if b.item_id == item_data.item_id:
				owned = true
				existing_lvl = b.level
				break
		if owned:
			type_badge.text = "[ PHƯỚC LÀNH -> Lv.%d ]" % (existing_lvl + 1)
			type_badge.add_theme_color_override(&"font_color", Color(0.4, 1.0, 0.4))
		else:
			type_badge.text = "[ DI VẬT / PHƯỚC LÀNH ]"
			type_badge.add_theme_color_override(&"font_color", Color(0.4, 0.9, 0.4))

	# Description
	if item_data.type == ItemData.ItemType.WEAPON:
		var extra_effect: String = ""
		if not item_data.special_effect.is_empty():
			extra_effect = "\n[Đặc tính: %s]" % ItemData.get_special_effect_name(item_data.special_effect)
		if not item_data.embedded_spell.is_empty():
			extra_effect += "\n[Khảm Phép: %s Lv.%d]" % [
				_get_spell_display_name(item_data.embedded_spell), item_data.embedded_spell_level
			]
		desc_label.text = "Sát thương: %d  |  Tốc đánh: %.1f/s%s\n%s" % [
			item_data.base_damage,
			item_data.attack_speed,
			extra_effect,
			item_data.description
		]
	elif item_data.type == ItemData.ItemType.SPELL:
		desc_label.text = "Trang bị vào ô Phép (Tự động bắn mỗi %.1fs)\n%s" % [
			item_data.cooldown,
			item_data.description
		]
	elif item_data.type == ItemData.ItemType.PASSIVE_BUFF:
		var existing_lvl: int = 1
		var owned: bool = false
		for b: ItemData in GameManager.passive_buffs:
			if b.item_id == item_data.item_id:
				owned = true
				existing_lvl = b.level
				break
		if owned:
			desc_label.text = "%s\n(Hiện có: Cấp %d - Nâng cấp hiệu ứng!)" % [item_data.description, existing_lvl]
		else:
			desc_label.text = item_data.description
	else:
		desc_label.text = item_data.description

	# Action Button state
	update_button_state()


func get_effective_price() -> int:
	return custom_price if custom_price >= 0 else (item_data.price if item_data != null else 0)


func update_button_state() -> void:
	if is_bought:
		action_btn.text = "✔ ĐÃ CHỌN" if is_free else "✔ ĐÃ MUA"
		action_btn.disabled = true
		action_btn.add_theme_color_override(&"font_disabled_color", Color(0.25, 0.95, 0.45, 1.0))
		modulate = Color(0.92, 0.95, 0.92, 0.95)
		return

	modulate = Color.WHITE
	if is_free:
		action_btn.text = "CHỌN NHẬN"
		action_btn.disabled = false
	else:
		var price_val: int = get_effective_price()
		action_btn.text = "%d Vàng" % price_val
		action_btn.disabled = (GameManager.gold < price_val)


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


func _get_spell_display_name(s_id: String) -> String:
	match s_id:
		"fireball": return "Hỏa Cầu"
		"meteor_rock": return "Mưa Thiên Thạch"
		"void_portal": return "Hố Đen Hư Không"
		"molten_spear": return "Ngọn Giáo Nóng Chảy"
		"earth_spike": return "Chông Gai Đất"
		"water_geyser": return "Thủy Long Bộc Phá"
		"tornado": return "Bão Tố Cuồng Phong"
		_: return s_id.capitalize()
