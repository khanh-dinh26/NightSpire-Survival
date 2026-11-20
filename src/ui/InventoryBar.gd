class_name InventoryBar
extends HBoxContainer
## Inventory Hotbar displaying up to 6 equipped weapon slots.

@onready var slot_0: InventorySlot = $Slot0
@onready var slot_1: InventorySlot = $Slot1
@onready var slot_2: InventorySlot = $Slot2
@onready var slot_3: InventorySlot = $Slot3
@onready var slot_4: InventorySlot = $Slot4
@onready var slot_5: InventorySlot = $Slot5

var _slots: Array[InventorySlot] = []


func _ready() -> void:
	_slots = [slot_0, slot_1, slot_2, slot_3, slot_4, slot_5]

	for i: int in range(_slots.size()):
		_slots[i].slot_clicked.connect(_on_slot_clicked)

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
	drop_dialog.title = "Drop Weapon"
	drop_dialog.dialog_text = "Drop %s (Damage: %d)?" % [item.item_name, item.base_damage]
	drop_dialog.ok_button_text = "Drop"
	drop_dialog.cancel_button_text = "Cancel"
	add_child(drop_dialog)
	drop_dialog.popup_centered()

	drop_dialog.confirmed.connect(func():
		GameManager.remove_weapon(slot_index)
		drop_dialog.queue_free()
	)
	drop_dialog.canceled.connect(func():
		drop_dialog.queue_free()
	)
