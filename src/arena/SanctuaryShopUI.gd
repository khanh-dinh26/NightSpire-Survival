class_name SanctuaryShopUI
extends CanvasLayer
## In-game NPC Shop interface for Sanctuary floor.
## Opens distinct shops for Blacksmith (Upgrades), Alchemist (Potions/Spells), and Merchant (Items/Weapons).
## Uses Gold for trade with no negative debuffs and unlimited purchases.

signal closed

@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var gold_label: Label = %GoldLabel
@onready var cards_container: HBoxContainer = %CardsContainer
@onready var close_btn: Button = %CloseButton

var _btn_normal: StyleBox = preload("res://assets/ui/buttons/btn_rect_normal.tres")
var _btn_hover: StyleBox = preload("res://assets/ui/buttons/btn_rect_hover.tres")
var _card_panel_tex: Texture2D = preload("res://assets/ui/slices/panel_window.png")
var _items_tex: Texture2D = preload("res://assets/sprites/items.png")

enum ShopType { BLACKSMITH, ALCHEMIST, MERCHANT }
var _current_shop_type: ShopType = ShopType.BLACKSMITH
var _merchant_items: Array[ItemData] = []
var _bought_merchant_items: Dictionary = {}
var _all_items_pool: Array[ItemData] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_to_group(&"shop_ui")
	close_btn.pressed.connect(close_shop)
	EventBus.gold_changed.connect(_update_gold_display)
	_load_items_pool()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_F)):
		close_shop()
		get_viewport().set_input_as_handled()


func _load_items_pool() -> void:
	_all_items_pool.clear()
	var paths: Array[String] = [
		"res://src/data/items/weapons/starter_dagger.tres",
		"res://src/data/items/weapons/dagger.tres",
		"res://src/data/items/weapons/short_bow.tres",
		"res://src/data/items/weapons/flame_sword.tres",
		"res://src/data/items/weapons/crystal_staff.tres",
		"res://src/data/items/weapons/vampire_dagger.tres",
		"res://src/data/items/weapons/scythe_of_doom.tres",
		"res://src/data/items/weapons/golden_repeater.tres",
		"res://src/data/items/weapons/berserker_axe.tres",
		"res://src/data/items/spells/spell_fireball.tres",
		"res://src/data/items/spells/spell_meteor_rock.tres",
		"res://src/data/items/spells/spell_void_portal.tres",
		"res://src/data/items/spells/spell_molten_spear.tres",
		"res://src/data/items/spells/spell_earth_spike.tres",
		"res://src/data/items/spells/spell_water_geyser.tres",
		"res://src/data/items/spells/spell_tornado.tres",
		"res://src/data/items/buffs/ruby_ring.tres",
		"res://src/data/items/buffs/leather_boots.tres",
		"res://src/data/items/buffs/crystal_pendant.tres",
		"res://src/data/items/buffs/iron_shield.tres",
		"res://src/data/items/buffs/health_potion.tres",
		"res://src/data/items/buffs/golden_magnet.tres",
		"res://src/data/items/buffs/lucky_clover.tres",
		"res://src/data/items/buffs/hermes_wings.tres",
		"res://src/data/items/buffs/vampire_chalice.tres",
		"res://src/data/items/buffs/frost_heart.tres",
		"res://src/data/items/buffs/super_magnet.tres",
	]
	for p: String in paths:
		if ResourceLoader.exists(p):
			_all_items_pool.append(load(p) as ItemData)


func open_blacksmith() -> void:
	_current_shop_type = ShopType.BLACKSMITH
	_show_ui("THỢ RÈN — CƯỜNG HÓA VŨ KHÍ", "Nâng cấp chỉ số chiến đấu bằng Vàng", Color(1.0, 0.85, 0.3))
	_build_blacksmith_cards()


func open_alchemist() -> void:
	_current_shop_type = ShopType.ALCHEMIST
	_show_ui("NHÀ GIẢ KIM — CỔ THUẬT & DƯỢC LIỆU", "Tăng cường sinh mệnh và phép thuật bằng Vàng", Color(0.4, 1.0, 0.6))
	_build_alchemist_cards()


func open_merchant() -> void:
	_current_shop_type = ShopType.MERCHANT
	_show_ui("THƯƠNG NHÂN — KHO BÁU BÍ MẬT", "Mua vật phẩm và trang bị quý hiếm bằng Vàng", Color(0.4, 0.8, 1.0))
	_build_merchant_cards()


func _show_ui(title_text: String, sub_text: String, col: Color) -> void:
	title_label.text = title_text
	title_label.add_theme_color_override(&"font_color", col)
	subtitle_label.text = sub_text
	_update_gold_display(GameManager.gold)
	visible = true
	get_tree().paused = true
	AudioManager.play_sfx("confirm")


func close_shop() -> void:
	AudioManager.play_sfx("confirm")
	visible = false
	get_tree().paused = false
	closed.emit()


func _update_gold_display(gold_val: int) -> void:
	if gold_label != null:
		gold_label.text = "%d VÀNG" % gold_val


func _clear_cards() -> void:
	for child: Node in cards_container.get_children():
		child.queue_free()


# ── BLACKSMITH CARDS ───────────────────────────────────────────────────
func _build_blacksmith_cards() -> void:
	_clear_cards()
	_create_service_card("Luyện Kiếm Sắc", "SÁT THƯƠNG", "+25% Sát thương toàn bộ vũ khí.", 25, Color(1.0, 0.5, 0.3), 0)
	_create_service_card("Gió Lốc Bạt Mạng", "TỐC ĐÁNH", "+30% Tốc đánh (Giảm cooldown).", 25, Color(1.0, 0.85, 0.3), 1)
	_create_service_card("Khí Giáp Hoàng Kim", "PHÒNG THỦ", "+3 Giáp vĩnh viễn & Hồi Đầy Máu.", 30, Color(0.4, 1.0, 0.5), 2)


func _apply_blacksmith(idx: int) -> void:
	var p: Player = _get_player()
	match idx:
		0:
			for w: ItemData in GameManager.equipped_weapons:
				w.base_damage = ceili(w.base_damage * 1.25)
			EventBus.weapons_changed.emit()
		1:
			for w: ItemData in GameManager.equipped_weapons:
				w.attack_speed *= 1.30
				w.cooldown = maxf(w.cooldown * 0.77, 0.1)
			EventBus.weapons_changed.emit()
		2:
			if p != null:
				p.defense += 3
				p.heal(p.max_hp)
	_update_gold_display(GameManager.gold)


# ── ALCHEMIST CARDS ────────────────────────────────────────────────────
func _build_alchemist_cards() -> void:
	_clear_cards()
	_create_service_card("Huyết Dược Sinh Mệnh", "SINH MỆNH", "+40 Máu Tối Đa & Hồi Đầy Máu.", 25, Color(1.0, 0.4, 0.45), 10)
	_create_service_card("Thuốc Thần Tốc", "TỐC ĐỘ", "+30 Tốc Độ Di Chuyển.", 20, Color(0.4, 0.85, 1.0), 11)
	_create_service_card("Cổ Dược Phép Thuật", "PHÉP THUẬT", "+1 Cấp cho TẤT CẢ Phép Thuật.", 35, Color(1.0, 0.65, 0.25), 12)


func _apply_alchemist(idx: int) -> void:
	var p: Player = _get_player()
	match idx:
		10:
			if p != null:
				p.max_hp += 40
				GameManager.player_max_hp = p.max_hp
				p.heal(p.max_hp)
		11:
			if p != null:
				p.speed += 30.0
		12:
			for s_id: String in GameManager.learned_spells.keys():
				GameManager.learned_spells[s_id] += 1
				EventBus.spell_learned.emit(s_id, GameManager.learned_spells[s_id])
	_update_gold_display(GameManager.gold)


# ── MERCHANT CARDS ─────────────────────────────────────────────────────
func _build_merchant_cards() -> void:
	_clear_cards()
	if _merchant_items.is_empty():
		var pool_copy: Array[ItemData] = _all_items_pool.duplicate()
		pool_copy.shuffle()
		for i: int in range(mini(3, pool_copy.size())):
			_merchant_items.append(pool_copy[i])

	for item: ItemData in _merchant_items:
		_create_item_card(item)


# ── CARD CREATION HELPERS ──────────────────────────────────────────────
func _create_service_card(p_name: String, p_type: String, p_desc: String, p_cost: int, p_col: Color, p_action_id: int) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(150, 175)

	var bg: NinePatchRect = NinePatchRect.new()
	bg.texture = _card_panel_tex
	bg.patch_margin_left = 12
	bg.patch_margin_top = 12
	bg.patch_margin_right = 12
	bg.patch_margin_bottom = 12
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(bg)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", 8)
	margin.add_theme_constant_override(&"margin_right", 8)
	margin.add_theme_constant_override(&"margin_top", 10)
	margin.add_theme_constant_override(&"margin_bottom", 10)
	panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override(&"separation", 4)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	var name_lbl: Label = Label.new()
	name_lbl.text = p_name
	name_lbl.add_theme_font_size_override(&"font_size", 12)
	name_lbl.add_theme_color_override(&"font_color", p_col)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_lbl)

	var badge_lbl: Label = Label.new()
	badge_lbl.text = "[ %s ]" % p_type
	badge_lbl.add_theme_font_size_override(&"font_size", 9)
	badge_lbl.add_theme_color_override(&"font_color", Color(0.75, 0.75, 0.75))
	badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(badge_lbl)

	var desc_lbl: Label = Label.new()
	desc_lbl.text = p_desc
	desc_lbl.add_theme_font_size_override(&"font_size", 10)
	desc_lbl.add_theme_color_override(&"font_color", Color(0.9, 0.9, 0.9))
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc_lbl)

	var btn: Button = Button.new()
	btn.custom_minimum_size = Vector2(0, 26)
	btn.add_theme_font_size_override(&"font_size", 11)
	btn.add_theme_color_override(&"font_color", Color(0.12, 0.1, 0.08))
	btn.add_theme_stylebox_override(&"normal", _btn_normal)
	btn.add_theme_stylebox_override(&"hover", _btn_hover)
	btn.add_theme_stylebox_override(&"pressed", _btn_hover)
	btn.text = "Mua: %d Vàng" % p_cost
	vbox.add_child(btn)

	btn.pressed.connect(func():
		if GameManager.gold >= p_cost:
			GameManager.spend_gold(p_cost)
			if p_action_id < 10:
				_apply_blacksmith(p_action_id)
			else:
				_apply_alchemist(p_action_id)
			AudioManager.play_sfx("buy")
			btn.text = "Thành Công!"
			var tw: Tween = create_tween()
			tw.tween_interval(0.8)
			tw.tween_callback(func():
				if is_instance_valid(btn):
					btn.text = "Mua: %d Vàng" % p_cost
			)
		else:
			btn.text = "Không đủ Vàng!"
			var tw: Tween = create_tween()
			tw.tween_interval(1.0)
			tw.tween_callback(func():
				if is_instance_valid(btn):
					btn.text = "Mua: %d Vàng" % p_cost
			)
	)

	cards_container.add_child(panel)


func _create_item_card(item: ItemData) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(150, 175)

	var bg: NinePatchRect = NinePatchRect.new()
	bg.texture = _card_panel_tex
	bg.patch_margin_left = 12
	bg.patch_margin_top = 12
	bg.patch_margin_right = 12
	bg.patch_margin_bottom = 12
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(bg)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", 8)
	margin.add_theme_constant_override(&"margin_right", 8)
	margin.add_theme_constant_override(&"margin_top", 8)
	margin.add_theme_constant_override(&"margin_bottom", 8)
	panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override(&"separation", 3)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	var spr_center: CenterContainer = CenterContainer.new()
	var tex_rect: TextureRect = TextureRect.new()
	tex_rect.custom_minimum_size = Vector2(28, 28)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if not item.custom_icon_path.is_empty() and ResourceLoader.exists(item.custom_icon_path):
		tex_rect.texture = load(item.custom_icon_path)
	else:
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = _items_tex
		atlas.region = item.sprite_region
		tex_rect.texture = atlas
	spr_center.add_child(tex_rect)
	vbox.add_child(spr_center)

	var name_lbl: Label = Label.new()
	name_lbl.text = item.item_name
	name_lbl.add_theme_font_size_override(&"font_size", 11)
	name_lbl.add_theme_color_override(&"font_color", Color(1.0, 0.9, 0.4))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_lbl)

	var type_str: String = "VẬT PHẨM"
	match item.type:
		ItemData.ItemType.WEAPON: type_str = "VŨ KHÍ"
		ItemData.ItemType.PASSIVE_BUFF: type_str = "BUFF"
		ItemData.ItemType.SPELL: type_str = "PHÉP"
	var type_lbl: Label = Label.new()
	type_lbl.text = "[ %s ]" % type_str
	type_lbl.add_theme_font_size_override(&"font_size", 9)
	type_lbl.add_theme_color_override(&"font_color", Color(0.5, 0.9, 0.5))
	type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(type_lbl)

	var desc_lbl: Label = Label.new()
	desc_lbl.text = item.description
	desc_lbl.add_theme_font_size_override(&"font_size", 9)
	desc_lbl.add_theme_color_override(&"font_color", Color(0.85, 0.85, 0.85))
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc_lbl)

	var cost: int = maxi(item.price, 20)
	var btn: Button = Button.new()
	btn.custom_minimum_size = Vector2(0, 24)
	btn.add_theme_font_size_override(&"font_size", 10)
	btn.add_theme_color_override(&"font_color", Color(0.12, 0.1, 0.08))
	btn.add_theme_stylebox_override(&"normal", _btn_normal)
	btn.add_theme_stylebox_override(&"hover", _btn_hover)
	btn.add_theme_stylebox_override(&"pressed", _btn_hover)

	var is_bought: bool = _bought_merchant_items.get(item.item_id, false)
	if is_bought:
		btn.text = "ĐÃ MUA"
		btn.disabled = true
		btn.modulate = Color(0.5, 0.5, 0.5, 0.7)
	else:
		btn.text = "Mua: %d Vàng" % cost

	vbox.add_child(btn)

	btn.pressed.connect(func():
		if _bought_merchant_items.get(item.item_id, false):
			return
		if GameManager.gold >= cost:
			_bought_merchant_items[item.item_id] = true
			GameManager.spend_gold(cost)
			GameManager.add_item(item)
			AudioManager.play_sfx("buy")
			_update_gold_display(GameManager.gold)
			btn.text = "ĐÃ MUA"
			btn.disabled = true
			btn.modulate = Color(0.5, 0.5, 0.5, 0.7)
		else:
			btn.text = "Không đủ Vàng!"
			var tw: Tween = create_tween()
			tw.tween_interval(1.0)
			tw.tween_callback(func():
				if is_instance_valid(btn):
					btn.text = "Mua: %d Vàng" % cost
			)
	)

	cards_container.add_child(panel)


func _get_player() -> Player:
	var nodes: Array[Node] = get_tree().get_nodes_in_group(&"player")
	if nodes.size() > 0:
		return nodes[0] as Player
	return null
