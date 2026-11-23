class_name SanctuaryShopUI
extends CanvasLayer
## In-game NPC Shop interface for Sanctuary floor.
## Opens distinct shops for Blacksmith (Upgrades), Alchemist (Permanent Effects), and Merchant (Items/Weapons).

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
var _all_items_pool: Array[ItemData] = []

var blacksmith_done: bool = false
var alchemist_done: bool = false
var merchant_done: bool = false


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
	]
	for p: String in paths:
		if ResourceLoader.exists(p):
			_all_items_pool.append(load(p) as ItemData)


func open_blacksmith() -> void:
	_current_shop_type = ShopType.BLACKSMITH
	var sub: String = "Chọn 1 giao kèo rèn đúc (Mỗi NPC chỉ chọn đúng 1 lần - Kèm điều kiện đánh đổi)"
	if blacksmith_done:
		sub = "[GIAO KÈO ĐÃ HOÀN TẤT] Bạn đã chọn 1 thỏa thuận từ Thợ Rèn."
	_show_ui("THỢ RÈN — GIAO KÈO RÈN ĐÚC", sub, Color(1.0, 0.85, 0.3))
	_build_blacksmith_cards()


func open_alchemist() -> void:
	_current_shop_type = ShopType.ALCHEMIST
	var sub: String = "Chọn 1 cấm thuật dược liệu (Mỗi NPC chỉ chọn đúng 1 lần - Kèm điều kiện đánh đổi)"
	if alchemist_done:
		sub = "[GIAO KÈO ĐÃ HOÀN TẤT] Bạn đã chọn 1 cấm thuật từ Giả Kim."
	_show_ui("NHÀ GIẢ KIM — CẤM THUẬT DƯỢC LIỆU", sub, Color(0.4, 1.0, 0.6))
	_build_alchemist_cards()


func open_merchant() -> void:
	_current_shop_type = ShopType.MERCHANT
	var sub: String = "Chọn duy nhất 1 món quý hiếm (Khế ước máu: giảm 15 Máu tối đa khi nhận)"
	if merchant_done:
		sub = "[GIAO KÈO ĐÃ HOÀN TẤT] Bạn đã nhận 1 món từ Thương Nhân."
	_show_ui("THƯƠNG NHÂN — KHẾ ƯỚC HẮC ĐIẾM", sub, Color(0.4, 0.8, 1.0))
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
	_create_service_card("Huyết Luyện Binh", "SÁT THƯƠNG", "+40% Sát thương toàn bộ vũ khí.\n\n[ĐÁNH ĐỔI]: -25 Máu Tối Đa.", 25, Color(1.0, 0.45, 0.35), 0, blacksmith_done)
	_create_service_card("Gió Lốc Bạt Mạng", "TỐC ĐÁNH", "+40% Tốc đánh vũ khí (Giảm 40% Cooldown).\n\n[ĐÁNH ĐỔI]: -15 Tốc Độ Chạy.", 20, Color(1.0, 0.85, 0.3), 1, blacksmith_done)
	_create_service_card("Kính Giáp Liều Mạng", "THỦ PHỦ", "+4 Giáp vĩnh viễn & Hồi 100% Máu.\n\n[ĐÁNH ĐỔI]: -15% Sát Thương.", 30, Color(0.4, 1.0, 0.5), 2, blacksmith_done)


func _apply_blacksmith(idx: int) -> void:
	blacksmith_done = true
	var p: Player = _get_player()
	match idx:
		0:
			for w: ItemData in GameManager.equipped_weapons:
				w.base_damage = ceili(w.base_damage * 1.40)
			if p != null:
				p.max_hp = maxi(p.max_hp - 25, 20)
				p.current_hp = mini(p.current_hp, p.max_hp)
				GameManager.player_max_hp = p.max_hp
				GameManager.player_current_hp = p.current_hp
			EventBus.weapons_changed.emit()
		1:
			for w: ItemData in GameManager.equipped_weapons:
				w.attack_speed *= 1.40
				w.cooldown = maxf(w.cooldown * 0.6, 0.1)
			if p != null:
				p.speed = maxf(p.speed - 15.0, 60.0)
			EventBus.weapons_changed.emit()
		2:
			if p != null:
				p.defense += 4
				p.heal(p.max_hp)
			for w: ItemData in GameManager.equipped_weapons:
				w.base_damage = maxi(ceili(w.base_damage * 0.85), 1)
			EventBus.weapons_changed.emit()
	_update_gold_display(GameManager.gold)
	_build_blacksmith_cards()


# ── ALCHEMIST CARDS ────────────────────────────────────────────────────
func _build_alchemist_cards() -> void:
	_clear_cards()
	_create_service_card("Dược Huyết Cuồng Loạn", "SINH MỆNH", "+45 Máu Tối Đa & Hồi Đầy Máu.\n\n[ĐÁNH ĐỔI]: -2 Giáp (Defense).", 20, Color(1.0, 0.35, 0.4), 10, alchemist_done)
	_create_service_card("Ma Dược Thần Tốc", "TỐC ĐỘ", "+45 Tốc Độ Di Chuyển.\n\n[ĐÁNH ĐỔI]: -20 Máu Tối Đa.", 20, Color(0.4, 0.85, 1.0), 11, alchemist_done)
	_create_service_card("Cổ Dược Đột Phá", "PHÉP THUẬT", "+1 Cấp cho TẤT CẢ Phép Thuật đang có.\n\n[ĐÁNH ĐỔI]: -20 Máu Tối Đa.", 25, Color(1.0, 0.6, 0.2), 12, alchemist_done)


func _apply_alchemist(idx: int) -> void:
	alchemist_done = true
	var p: Player = _get_player()
	match idx:
		10:
			if p != null:
				p.max_hp += 45
				p.defense = maxi(p.defense - 2, 0)
				GameManager.player_max_hp = p.max_hp
				p.heal(p.max_hp)
		11:
			if p != null:
				p.speed += 45.0
				p.max_hp = maxi(p.max_hp - 20, 20)
				p.current_hp = mini(p.current_hp, p.max_hp)
				GameManager.player_max_hp = p.max_hp
				GameManager.player_current_hp = p.current_hp
		12:
			for s_id: String in GameManager.learned_spells.keys():
				GameManager.learned_spells[s_id] += 1
				EventBus.spell_learned.emit(s_id, GameManager.learned_spells[s_id])
			if p != null:
				p.max_hp = maxi(p.max_hp - 20, 20)
				p.current_hp = mini(p.current_hp, p.max_hp)
				GameManager.player_max_hp = p.max_hp
				GameManager.player_current_hp = p.current_hp
	_update_gold_display(GameManager.gold)
	_build_alchemist_cards()


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

	for item: ItemData in _merchant_items:
		_create_item_card(item)


# ── CARD CREATION HELPERS ──────────────────────────────────────────────
func _create_service_card(p_name: String, p_type: String, p_desc: String, p_cost: int, p_col: Color, p_action_id: int, is_already_done: bool = false) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(115, 180)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var bg: NinePatchRect = NinePatchRect.new()
	bg.texture = _card_panel_tex
	bg.patch_margin_left = 14
	bg.patch_margin_top = 14
	bg.patch_margin_right = 14
	bg.patch_margin_bottom = 14
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(bg)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", 10)
	margin.add_theme_constant_override(&"margin_right", 10)
	margin.add_theme_constant_override(&"margin_top", 12)
	margin.add_theme_constant_override(&"margin_bottom", 12)
	panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override(&"separation", 6)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	var name_lbl: Label = Label.new()
	name_lbl.text = p_name
	name_lbl.add_theme_font_size_override(&"font_size", 15)
	name_lbl.add_theme_color_override(&"font_color", p_col)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_lbl)

	var badge_lbl: Label = Label.new()
	badge_lbl.text = "[ %s ]" % p_type
	badge_lbl.add_theme_font_size_override(&"font_size", 11)
	badge_lbl.add_theme_color_override(&"font_color", Color(0.7, 0.7, 0.7))
	badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(badge_lbl)

	var desc_lbl: Label = Label.new()
	desc_lbl.text = p_desc
	desc_lbl.add_theme_font_size_override(&"font_size", 12)
	desc_lbl.add_theme_color_override(&"font_color", Color(0.9, 0.9, 0.9))
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc_lbl)

	var btn: Button = Button.new()
	btn.custom_minimum_size = Vector2(0, 28)
	btn.add_theme_font_size_override(&"font_size", 13)
	btn.add_theme_color_override(&"font_color", Color(0.12, 0.1, 0.08))
	btn.add_theme_stylebox_override(&"normal", _btn_normal)
	btn.add_theme_stylebox_override(&"hover", _btn_hover)
	btn.add_theme_stylebox_override(&"pressed", _btn_hover)

	if is_already_done:
		btn.text = "ĐÃ KÝ GIAO KÈO"
		btn.disabled = true
		btn.modulate = Color(0.5, 0.5, 0.5, 0.7)
	else:
		btn.text = "Giao Kèo: %d G" % p_cost

	vbox.add_child(btn)

	btn.pressed.connect(func():
		if is_already_done:
			return
		if GameManager.gold >= p_cost:
			GameManager.spend_gold(p_cost)
			if p_action_id < 10:
				_apply_blacksmith(p_action_id)
			else:
				_apply_alchemist(p_action_id)
			AudioManager.play_sfx("buy")
		else:
			btn.text = "Không đủ Vàng!"
			var tw: Tween = create_tween()
			tw.tween_interval(1.0)
			tw.tween_callback(func(): btn.text = "Giao Kèo: %d G" % p_cost)
	)

	cards_container.add_child(panel)


func _create_item_card(item: ItemData) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(130, 180)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var bg: NinePatchRect = NinePatchRect.new()
	bg.texture = _card_panel_tex
	bg.patch_margin_left = 14
	bg.patch_margin_top = 14
	bg.patch_margin_right = 14
	bg.patch_margin_bottom = 14
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(bg)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", 10)
	margin.add_theme_constant_override(&"margin_right", 10)
	margin.add_theme_constant_override(&"margin_top", 10)
	margin.add_theme_constant_override(&"margin_bottom", 10)
	panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override(&"separation", 4)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	var spr_center: CenterContainer = CenterContainer.new()
	var tex_rect: TextureRect = TextureRect.new()
	tex_rect.custom_minimum_size = Vector2(32, 32)
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
	name_lbl.add_theme_font_size_override(&"font_size", 15)
	name_lbl.add_theme_color_override(&"font_color", Color(1.0, 0.9, 0.4))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_lbl)

	var type_str: String = "VŨ KHÍ"
	var type_col: Color = Color(0.4, 0.8, 1.0)
	if item.type == ItemData.ItemType.SPELL:
		type_str = "PHÉP THUẬT"
		type_col = Color(0.3, 0.8, 1.0)
	elif item.type == ItemData.ItemType.PASSIVE_BUFF:
		type_str = "BUFF"
		type_col = Color(0.4, 1.0, 0.5)

	var badge_lbl: Label = Label.new()
	badge_lbl.text = "[ %s ]" % type_str
	badge_lbl.add_theme_font_size_override(&"font_size", 11)
	badge_lbl.add_theme_color_override(&"font_color", type_col)
	badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(badge_lbl)

	var desc_lbl: Label = Label.new()
	desc_lbl.text = "%s\n\n[ĐÁNH ĐỔI]: -15 Máu Tối Đa." % item.description
	desc_lbl.add_theme_font_size_override(&"font_size", 11)
	desc_lbl.add_theme_color_override(&"font_color", Color(0.85, 0.85, 0.85))
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc_lbl)

	var cost: int = item.price
	var btn: Button = Button.new()
	btn.custom_minimum_size = Vector2(0, 28)
	btn.add_theme_font_size_override(&"font_size", 12)
	btn.add_theme_color_override(&"font_color", Color(0.12, 0.1, 0.08))
	btn.add_theme_stylebox_override(&"normal", _btn_normal)
	btn.add_theme_stylebox_override(&"hover", _btn_hover)
	btn.add_theme_stylebox_override(&"pressed", _btn_hover)

	if merchant_done:
		btn.text = "ĐÃ KÝ GIAO KÈO"
		btn.disabled = true
		btn.modulate = Color(0.5, 0.5, 0.5, 0.7)
	else:
		btn.text = "Khế Ước: %d G (-15 HP)" % cost

	vbox.add_child(btn)

	btn.pressed.connect(func():
		if merchant_done:
			return
		if GameManager.gold >= cost:
			merchant_done = true
			GameManager.spend_gold(cost)
			var p: Player = _get_player()
			if p != null:
				p.max_hp = maxi(p.max_hp - 15, 20)
				p.current_hp = mini(p.current_hp, p.max_hp)
				GameManager.player_max_hp = p.max_hp
				GameManager.player_current_hp = p.current_hp
			GameManager.add_item(item)
			AudioManager.play_sfx("buy")
			_update_gold_display(GameManager.gold)
			_build_merchant_cards()
		else:
			btn.text = "Không đủ Vàng!"
			var tw: Tween = create_tween()
			tw.tween_interval(1.0)
			tw.tween_callback(func(): btn.text = "Khế Ước: %d G (-15 HP)" % cost)
	)

	cards_container.add_child(panel)

	cards_container.add_child(panel)


func _get_player() -> Player:
	var nodes: Array[Node] = get_tree().get_nodes_in_group(&"player")
	if nodes.size() > 0:
		return nodes[0] as Player
	return null
