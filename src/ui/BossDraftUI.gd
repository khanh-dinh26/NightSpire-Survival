class_name BossDraftUI
extends CanvasLayer
## Draft interface displayed after defeating a Mini-Boss (floors 4, 8).
## Shows 5 high-tier items; player picks up to 2 for free.
## Supports replacing/dropping an existing weapon when inventory has 6/6 weapons.

const MAX_PICKS: int = 2

@onready var title_label: Label = $Panel/Margin/VBox/Header/TitleLabel
@onready var picks_label: Label = $Panel/Margin/VBox/Header/PicksLabel
@onready var cards_container: HBoxContainer = $Panel/Margin/VBox/CardsScroll/CardsContainer
@onready var continue_btn: Button = $Panel/Margin/VBox/Footer/ContinueButton

# Replace Modal
@onready var replace_modal: PanelContainer = $ReplaceModal
@onready var replace_title: Label = $ReplaceModal/Margin/VBox/TitleLabel
@onready var replace_slots_container: HBoxContainer = $ReplaceModal/Margin/VBox/SlotsContainer
@onready var replace_cancel_btn: Button = $ReplaceModal/Margin/VBox/CancelButton

var _card_scene: PackedScene = preload("res://src/ui/ItemCard.tscn")
var _cards: Array[ItemCard] = []
var _picks_left: int = MAX_PICKS

var _pending_item: ItemData = null
var _pending_card: ItemCard = null


func _ready() -> void:
	visible = false
	add_to_group(&"draft_ui")
	if replace_modal != null:
		replace_modal.visible = false
		replace_cancel_btn.pressed.connect(_hide_replace_modal)
	continue_btn.pressed.connect(_on_continue_pressed)


func open_draft(items: Array[ItemData]) -> void:
	_hide_replace_modal()
	get_tree().paused = true
	_picks_left = MAX_PICKS
	title_label.text = "MINI-BOSS DEFEATED — SPOILS OF WAR"
	_update_picks_label()
	_populate_cards(items)
	visible = true


func _populate_cards(items: Array[ItemData]) -> void:
	for child: Node in cards_container.get_children():
		child.queue_free()
	_cards.clear()

	for item: ItemData in items:
		var card: ItemCard = _card_scene.instantiate() as ItemCard
		card.custom_minimum_size = Vector2(98, 155)
		cards_container.add_child(card)
		card.setup(item, true)
		card.item_selected.connect(_on_card_selected)
		_cards.append(card)


func _on_card_selected(card: ItemCard, item: ItemData) -> void:
	if _picks_left <= 0:
		return

	# If picking a weapon and weapons full (6/6) and not already owned, prompt to drop
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

	_claim_item(card, item)


func _claim_item(card: ItemCard, item: ItemData) -> void:
	GameManager.add_item(item)
	EventBus.item_picked.emit(item.item_id)
	card.mark_as_bought()
	_picks_left -= 1
	_update_picks_label()

	if _picks_left <= 0:
		for c: ItemCard in _cards:
			if not c.is_bought:
				c.action_btn.disabled = true
				c.modulate = Color(0.5, 0.5, 0.5, 0.6)
		continue_btn.grab_focus()


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
	GameManager.replace_weapon(slot_idx, _pending_item)
	EventBus.item_picked.emit(_pending_item.item_id)
	_pending_card.mark_as_bought()
	_picks_left -= 1
	_update_picks_label()

	if _picks_left <= 0:
		for c: ItemCard in _cards:
			if not c.is_bought:
				c.action_btn.disabled = true
				c.modulate = Color(0.5, 0.5, 0.5, 0.6)
		continue_btn.grab_focus()

	_hide_replace_modal()


func _hide_replace_modal() -> void:
	replace_modal.visible = false
	_pending_item = null
	_pending_card = null


func _update_picks_label() -> void:
	picks_label.text = "Draft: %d / %d remaining" % [_picks_left, MAX_PICKS]
	if _picks_left <= 0:
		picks_label.text = "All spoils claimed!"


func _on_continue_pressed() -> void:
	_hide_replace_modal()
	visible = false
	get_tree().paused = false
	EventBus.draft_closed.emit()
