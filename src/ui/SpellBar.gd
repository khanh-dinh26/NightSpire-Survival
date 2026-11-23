class_name SpellBar
extends Control
## Vertical Spell Bar positioned along the left edge of the screen with 5 slots.
## Holds learned active spells, auto-casts on cooldown, and supports 1-5 keys or click.

@onready var container: VBoxContainer = $MarginContainer/VBoxContainer

var _slots: Array[SpellSlot] = []

# Spell icon preloads
var _spell_icons: Dictionary = {
	"fireball": preload("res://assets/effects/magic_effects/Icons/tile000.png"),
	"meteor_rock": preload("res://assets/effects/magic_effects/Icons/tile001.png"),
	"void_portal": preload("res://assets/effects/magic_effects/Icons/tile004.png"),
	"molten_spear": preload("res://assets/effects/magic_effects/Icons/tile006.png"),
	"earth_spike": preload("res://assets/effects/magic_effects/Icons/tile007.png"),
	"water_geyser": preload("res://assets/effects/magic_effects/Icons/tile008.png"),
	"tornado": preload("res://assets/effects/magic_effects/Icons/tile009.png"),
}


func _ready() -> void:
	_slots.clear()
	for child: Node in container.get_children():
		if child is SpellSlot:
			var slot: SpellSlot = child as SpellSlot
			_slots.append(slot)
			slot.cast_requested.connect(_on_slot_cast_requested)

	EventBus.spell_learned.connect(_on_spell_learned)
	refresh_spell_slots()


func _on_spell_learned(_spell_id: String, _level: int) -> void:
	refresh_spell_slots()


func refresh_spell_slots() -> void:
	var learned_ids: Array = GameManager.learned_spells.keys()
	for i: int in range(_slots.size()):
		if i < learned_ids.size():
			var s_id: String = str(learned_ids[i])
			var lvl: int = int(GameManager.learned_spells[s_id])
			var icon: Texture2D = _spell_icons.get(s_id, _spell_icons["fireball"])
			var cd: float = _get_spell_cooldown(s_id)
			_slots[i].setup_spell(s_id, lvl, icon, cd)
		else:
			_slots[i].clear_slot()


func _get_spell_cooldown(spell_id: String) -> float:
	match spell_id:
		"fireball": return 3.0
		"molten_spear": return 2.5
		"water_geyser": return 3.2
		"earth_spike": return 3.5
		"meteor_rock": return 3.5
		"void_portal": return 4.0
		"tornado": return 4.5
		_: return 3.5


func _on_slot_cast_requested(spell_id: String, level: int, target_pos: Vector2) -> void:
	EventBus.spell_cast_requested.emit(spell_id, level, target_pos)
