class_name SpellBar
extends Control
## Vertical Spell Bar positioned along the right edge of the screen.
## Holds learned active spells, allows mouse click or hotkeys to cast towards mouse cursor.

@onready var container: VBoxContainer = $MarginContainer/VBoxContainer

var _slot_scene: PackedScene = preload("res://src/ui/SpellSlot.tscn")
var _slots: Dictionary = {} # spell_id: String -> SpellSlot

# Spell icon preloads
var _spell_icons: Dictionary = {
	"fireball": preload("res://assets/effects/magic_effects/Icons/tile000.png"),
	"molten_spear": preload("res://assets/effects/magic_effects/Icons/tile001.png"),
	"earth_spike": preload("res://assets/effects/magic_effects/Icons/tile002.png"),
	"tornado": preload("res://assets/effects/magic_effects/Icons/tile004.png"),
}


func _ready() -> void:
	EventBus.spell_learned.connect(_on_spell_learned)

	# Populate any currently learned spells
	for s_id: String in GameManager.learned_spells:
		learn_spell(s_id, GameManager.learned_spells[s_id])


func _on_spell_learned(spell_id: String, level: int) -> void:
	learn_spell(spell_id, level)


func learn_spell(spell_id: String, level: int) -> void:
	if _slots.has(spell_id):
		var existing_slot: Control = _slots[spell_id] as Control
		if existing_slot != null and existing_slot.has_method("set_level"):
			existing_slot.set_level(level)
		return

	# Add new spell slot
	var slot: Control = _slot_scene.instantiate() as Control
	var hotkey_idx: int = _slots.size() + 1
	if "hotkey_index" in slot:
		slot.hotkey_index = hotkey_idx

	var icon: Texture2D = _spell_icons.get(spell_id, _spell_icons["fireball"])
	var cd: float = 3.5
	match spell_id:
		"fireball": cd = 3.0
		"molten_spear": cd = 2.5
		"tornado": cd = 5.0
		"earth_spike": cd = 4.0

	container.add_child(slot)
	if slot.has_method("setup_spell"):
		slot.setup_spell(spell_id, level, icon, cd)
	if slot.has_signal("cast_requested"):
		slot.cast_requested.connect(_on_slot_cast_requested)
	_slots[spell_id] = slot


func _on_slot_cast_requested(spell_id: String, level: int) -> void:
	var mouse_world_pos: Vector2 = get_global_mouse_position()
	# If we have a player, get world mouse position accurately via player's canvas
	var players: Array[Node] = get_tree().get_nodes_in_group(&"player")
	if players.size() > 0:
		var p: Node2D = players[0] as Node2D
		if p != null:
			mouse_world_pos = p.get_global_mouse_position()

	EventBus.spell_cast_requested.emit(spell_id, level, mouse_world_pos)
