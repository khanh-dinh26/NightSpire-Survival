class_name SaveManagerClass
extends Node
## Handles saving / loading / deleting the permadeath run file.

const SAVE_PATH: String = "user://savegame.json"


func save_run() -> void:
	var data: Dictionary = {
		"tower_id": GameManager.current_tower.tower_id if GameManager.current_tower else "",
		"next_floor": GameManager.current_floor_index,
		"gold": GameManager.gold,
		"current_hp": GameManager.player_current_hp,
		"max_hp": GameManager.player_max_hp,
		"equipped_weapons": _serialize_items(GameManager.equipped_weapons),
		"passives": _serialize_items(GameManager.passive_buffs),
	}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func load_run() -> Dictionary:
	if not has_save():
		return {}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return {}
	var text: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	if json.parse(text) == OK:
		return json.data as Dictionary
	return {}


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)


func _serialize_items(items: Array[ItemData]) -> Array:
	var result: Array = []
	for item: ItemData in items:
		result.append(item.item_id)
	return result
