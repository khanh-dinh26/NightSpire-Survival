class_name WaveShopUI
extends CanvasLayer
## Shop interface displayed after normal combat waves (floors 1-3, 5-7).

@onready var title_label: Label = $Panel/Margin/VBox/Header/TitleLabel
@onready var gold_label: Label = $Panel/Margin/VBox/Header/GoldLabel
@onready var cards_container: HBoxContainer = $Panel/Margin/VBox/CardsContainer
@onready var reroll_btn: Button = $Panel/Margin/VBox/Footer/RerollButton
@onready var continue_btn: Button = $Panel/Margin/VBox/Footer/ContinueButton

# Replace Modal
@onready var replace_modal: PanelContainer = $ReplaceModal
@onready var replace_title: Label = $ReplaceModal/Margin/VBox/TitleLabel
@onready var replace_slots_container: HBoxContainer = $ReplaceModal/Margin/VBox/SlotsContainer
@onready var replace_cancel_btn: Button = $ReplaceModal/Margin/VBox/CancelButton

var _card_scene: PackedScene = preload("res://src/ui/ItemCard.tscn")
var _inv_slot_scene: PackedScene = preload("res://src/ui/InventorySlot.tscn")
var _all_items_pool: Array[ItemData] = []
var _cards: Array[ItemCard] = []

var _pending_item: ItemData = null
var _pending_card: ItemCard = null
var _rerolls_remaining: int = 2


func _ready() -> void:
	visible = false
	add_to_group(&"shop_ui")
	if replace_modal != null:
		replace_modal.visible = false
		replace_cancel_btn.pressed.connect(_hide_replace_modal)

	reroll_btn.pressed.connect(_on_reroll_pressed)
	continue_btn.pressed.connect(_on_continue_pressed)

	EventBus.gold_changed.connect(_on_gold_changed)
	_load_all_items()


func _load_all_items() -> void:
	_all_items_pool.clear()
	# Weapons
	var weapon_files: Array[String] = [
		"res://src/data/items/weapons/starter_dagger.tres",
		"res://src/data/items/weapons/dagger.tres",
		"res://src/data/items/weapons/short_bow.tres",
		"res://src/data/items/weapons/flame_sword.tres",
		"res://src/data/items/weapons/crystal_staff.tres",
		"res://src/data/items/weapons/vampire_dagger.tres",
		"res://src/data/items/weapons/scythe_of_doom.tres",
		"res://src/data/items/weapons/golden_repeater.tres",
		"res://src/data/items/weapons/berserker_axe.tres",
	]
	for path: String in weapon_files:
		if ResourceLoader.exists(path):
			_all_items_pool.append(load(path) as ItemData)

	# Spells
	var spell_files: Array[String] = [
		"res://src/data/items/spells/spell_fireball.tres",
		"res://src/data/items/spells/spell_molten_spear.tres",
		"res://src/data/items/spells/spell_tornado.tres",
		"res://src/data/items/spells/spell_earth_spike.tres",
	]
	for path: String in spell_files:
		if ResourceLoader.exists(path):
			_all_items_pool.append(load(path) as ItemData)

	# Buffs
	var buff_files: Array[String] = [
		"res://src/data/items/buffs/ruby_ring.tres",
		"res://src/data/items/buffs/leather_boots.tres",
		"res://src/data/items/buffs/crystal_pendant.tres",
		"res://src/data/items/buffs/iron_shield.tres",
		"res://src/data/items/buffs/health_potion.tres",
	]
	for path: String in buff_files:
		if ResourceLoader.exists(path):
			_all_items_pool.append(load(path) as ItemData)


func open_shop(items: Array[ItemData]) -> void:
	_hide_replace_modal()
	_rerolls_remaining = 2
	get_tree().paused = true
	title_label.text = "FLOOR %d CLEARED — ARMORY SHOP" % GameManager.current_floor_index
	_refresh_gold()
	_populate_cards(items)
	_update_reroll_button()
	visible = true


func _populate_cards(items: Array[ItemData]) -> void:
	for child: Node in cards_container.get_children():
		child.queue_free()
	_cards.clear()

	for item: ItemData in items:
		var card: ItemCard = _card_scene.instantiate() as ItemCard
		cards_container.add_child(card)
		card.setup(item, false)
		card.item_selected.connect(_on_card_selected)
		_cards.append(card)


func _on_card_selected(card: ItemCard, item: ItemData) -> void:
	if GameManager.gold < item.price:
		return

	# If weapons are full (6/6) and player does not own this weapon yet, prompt to drop
	var already_owned: bool = false
	if item.type == ItemData.ItemType.WEAPON:
		for eq: ItemData in GameManager.equipped_weapons:
			if eq.item_id == item.item_id:
				already_owned = true
				break

	if item.type == ItemData.ItemType.WEAPON and GameManager.equipped_weapons.size() >= 6 and not already_owned:
		_pending_item = item
		_pending_card = card
		_show_replace_modal(item)
		return

	# Standard purchase
	if GameManager.spend_gold(item.price):
		GameManager.add_item(item)
		card.mark_as_bought()
		EventBus.item_bought.emit(item.item_id)
		_refresh_gold()
		_update_all_cards()


# ── Replace Modal Logic ─────────────────────────────────────────────────
func _show_replace_modal(new_item: ItemData) -> void:
	replace_title.text = "INVENTORY FULL (6/6) — CHỌN WEAPON MUỐN DROP ĐỂ LẤY %s:" % new_item.item_name
	for child: Node in replace_slots_container.get_children():
		child.queue_free()

	for i: int in range(GameManager.equipped_weapons.size()):
		var eq: ItemData = GameManager.equipped_weapons[i]
		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(68, 48)
		btn.text = "%s\n(Damage: %d)" % [eq.item_name, eq.base_damage]
		btn.add_theme_font_size_override(&"font_size", 9)
		btn.pressed.connect(func(): _on_replace_confirmed(i))
		replace_slots_container.add_child(btn)

	replace_modal.visible = true


func _on_replace_confirmed(slot_idx: int) -> void:
	if _pending_item == null or _pending_card == null:
		return
	if GameManager.spend_gold(_pending_item.price):
		GameManager.replace_weapon(slot_idx, _pending_item)
		_pending_card.mark_as_bought()
		EventBus.item_bought.emit(_pending_item.item_id)
		_refresh_gold()
		_update_all_cards()
	_hide_replace_modal()


func _hide_replace_modal() -> void:
	replace_modal.visible = false
	_pending_item = null
	_pending_card = null


func _on_reroll_pressed() -> void:
	if _rerolls_remaining <= 0:
		return
	if GameManager.do_reroll():
		_rerolls_remaining -= 1
		var new_items: Array[ItemData] = ItemPool.get_random_items(3, _all_items_pool)
		_populate_cards(new_items)
		_refresh_gold()
		_update_reroll_button()


func _on_continue_pressed() -> void:
	_hide_replace_modal()
	visible = false
	get_tree().paused = false
	EventBus.shop_closed.emit()


func _refresh_gold() -> void:
	gold_label.text = "Gold: %d" % GameManager.gold


func _update_reroll_button() -> void:
	if _rerolls_remaining <= 0:
		reroll_btn.text = "Out of Rerolls (0/2)"
		reroll_btn.disabled = true
	else:
		reroll_btn.text = "Reroll (%d/2 - %d Gold)" % [_rerolls_remaining, GameManager.reroll_cost]
		reroll_btn.disabled = (GameManager.gold < GameManager.reroll_cost)


func _update_all_cards() -> void:
	for card: ItemCard in _cards:
		card.update_button_state()
	_update_reroll_button()


func _on_gold_changed(_new_gold: int) -> void:
	_refresh_gold()
	_update_all_cards()
