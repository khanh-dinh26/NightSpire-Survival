class_name InventoryBar
extends HBoxContainer
## Inventory Hotbar displaying up to 10 equipped weapon slots.

var _slots: Array[InventorySlot] = []


func _ready() -> void:
	_slots.clear()
	for child: Node in get_children():
		if child is InventorySlot:
			var slot: InventorySlot = child as InventorySlot
			_slots.append(slot)
			slot.slot_clicked.connect(_on_slot_clicked)

	EventBus.weapons_changed.connect(refresh_inventory)
	call_deferred(&"refresh_inventory")


func refresh_inventory() -> void:
	var weapons: Array[ItemData] = GameManager.equipped_weapons
	for i: int in range(_slots.size()):
		if i < weapons.size():
			_slots[i].set_item(weapons[i], i)
		else:
			_slots[i].clear_slot()


func _on_slot_clicked(slot_index: int, item: ItemData) -> void:
	# Show quick drop prompt
	var drop_dialog: ConfirmationDialog = ConfirmationDialog.new()
	drop_dialog.title = "Bỏ Vũ Khí"
	drop_dialog.dialog_text = "Bạn có chắc muốn bỏ %s (Sát thương: %d)?" % [item.item_name, item.base_damage]
	drop_dialog.ok_button_text = "Bỏ"
	drop_dialog.cancel_button_text = "Hủy"
	add_child(drop_dialog)
	drop_dialog.popup_centered()

	drop_dialog.confirmed.connect(func():
		GameManager.remove_weapon(slot_index)
		drop_dialog.queue_free()
	)
	drop_dialog.canceled.connect(func():
		drop_dialog.queue_free()
	)
