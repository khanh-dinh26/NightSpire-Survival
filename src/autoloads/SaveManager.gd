class_name SaveManagerClass
extends Node
## Handles saving / loading / deleting the checkpoint run file.

const SAVE_PATH: String = "user://savegame.json"


func save_run() -> void:
	if GameManager.current_tower == null:
		return

	var floor_types: Array = []
	for fc: FloorConfig in GameManager.floor_configs:
		if fc != null:
			floor_types.append(fc.floor_type)

	var weapons_data: Array = []
	for w: ItemData in GameManager.equipped_weapons:
		if w != null:
			weapons_data.append({
				"id": w.item_id,
				"level": w.level,
				"base_damage": w.base_damage,
				"embedded_spell": w.embedded_spell,
				"embedded_spell_level": w.embedded_spell_level
			})

	var passives_data: Array = []
	for p: ItemData in GameManager.passive_buffs:
		if p != null:
			passives_data.append({
				"id": p.item_id,
				"level": p.level
			})

	var data: Dictionary = {
		"tower_id": GameManager.current_tower.tower_id,
		"class_id": GameManager.chosen_class.class_id if GameManager.chosen_class != null else "",
		"current_floor_index": GameManager.current_floor_index,
		"floor_types": floor_types,
		"gold": GameManager.gold,
		"current_hp": GameManager.player_current_hp,
		"max_hp": GameManager.player_max_hp,
		"is_dark_night": GameManager.is_dark_night,
		"dark_night_cycle": GameManager.dark_night_cycle,
		"learned_spells": GameManager.learned_spells,
		"equipped_weapons": weapons_data,
		"passives": passives_data
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
	if json.parse(text) == OK and json.data is Dictionary:
		return json.data as Dictionary
	return {}


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)


func resume_saved_run() -> bool:
	if not has_save():
		return false
	var save_data: Dictionary = load_run()
	if save_data.is_empty():
		return false

	# Load tower
	var tower_id: String = save_data.get("tower_id", "blightwood")
	var tower_path: String = "res://src/data/towers/%s_spire.tres" % tower_id
	if not ResourceLoader.exists(tower_path):
		tower_path = "res://src/data/towers/blightwood_spire.tres"
	var tower: TowerData = load(tower_path) as TowerData

	# Load class if any
	var class_id: String = save_data.get("class_id", "")
	var chosen_class: ClassData = null
	if not class_id.is_empty():
		var class_path: String = "res://src/data/classes/%s.tres" % class_id
		if ResourceLoader.exists(class_path):
			chosen_class = load(class_path) as ClassData

	# Recreate 100 floors using saved types
	var floor_types: Array = save_data.get("floor_types", [])
	var floors: Array[FloorConfig] = FloorConfig.generate_100_floors(floor_types)

	GameManager.current_tower = tower
	GameManager.chosen_class = chosen_class
	GameManager.floor_configs = floors
	GameManager.current_floor_index = int(save_data.get("current_floor_index", save_data.get("next_floor", 1)))
	GameManager.gold = int(save_data.get("gold", 0))
	GameManager.player_max_hp = int(save_data.get("max_hp", 100))
	var saved_hp: int = int(save_data.get("current_hp", GameManager.player_max_hp))
	# Ensure resuming has at least half HP or full HP
	GameManager.player_current_hp = maxi(saved_hp, GameManager.player_max_hp / 2)
	GameManager.is_dark_night = bool(save_data.get("is_dark_night", false))
	GameManager.dark_night_cycle = int(save_data.get("dark_night_cycle", 0))

	# Restore learned spells
	GameManager.learned_spells.clear()
	var spells: Dictionary = save_data.get("learned_spells", {})
	for s_id: Variant in spells:
		GameManager.learned_spells[str(s_id)] = int(spells[s_id])

	# Restore equipped weapons
	GameManager.equipped_weapons.clear()
	var weapons_data: Array = save_data.get("equipped_weapons", [])
	for wd: Variant in weapons_data:
		var w_dict: Dictionary = wd as Dictionary if wd is Dictionary else {"id": str(wd)}
		var wid: String = str(w_dict.get("id", ""))
		var w_path: String = "res://src/data/items/weapons/%s.tres" % wid
		if ResourceLoader.exists(w_path):
			var w_item: ItemData = (load(w_path) as ItemData).duplicate()
			if w_dict.has("level"):
				w_item.level = int(w_dict["level"])
			if w_dict.has("base_damage"):
				w_item.base_damage = int(w_dict["base_damage"])
			if w_dict.has("embedded_spell"):
				w_item.embedded_spell = str(w_dict["embedded_spell"])
			if w_dict.has("embedded_spell_level"):
				w_item.embedded_spell_level = int(w_dict["embedded_spell_level"])
			GameManager.equipped_weapons.append(w_item)

	# Restore passives
	GameManager.passive_buffs.clear()
	var passives_data: Array = save_data.get("passives", [])
	for pd: Variant in passives_data:
		var p_dict: Dictionary = pd as Dictionary if pd is Dictionary else {"id": str(pd)}
		var pid: String = str(p_dict.get("id", ""))
		var p_path: String = "res://src/data/items/buffs/%s.tres" % pid
		if ResourceLoader.exists(p_path):
			var p_item: ItemData = (load(p_path) as ItemData).duplicate()
			if p_dict.has("level"):
				p_item.level = int(p_dict["level"])
			GameManager.passive_buffs.append(p_item)

	return true

