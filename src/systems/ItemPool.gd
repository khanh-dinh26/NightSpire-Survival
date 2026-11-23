class_name ItemPool
extends RefCounted
## Utility for generating random items for Wave Shop and Boss Draft.

static func has_rare_weapon_luck() -> bool:
	for b: ItemData in GameManager.passive_buffs:
		if b != null and b.item_id == "blacksmith_talisman":
			return true
	return false


static func get_random_items(count: int, all_items: Array[ItemData], exclude_ids: Array[String] = []) -> Array[ItemData]:
	var candidates: Array[ItemData] = []
	for item: ItemData in all_items:
		if item == null:
			continue
		if not exclude_ids.has(item.item_id):
			candidates.append(item)

	if candidates.is_empty():
		return []

	var selected: Array[ItemData] = []
	var pool: Array[ItemData] = candidates.duplicate()
	var luck_active: bool = has_rare_weapon_luck()

	while selected.size() < count and not pool.is_empty():
		var total_weight: float = 0.0
		for item: ItemData in pool:
			total_weight += _get_item_weight(item, luck_active, false)

		var roll: float = randf_range(0.0, total_weight)
		var cumulative: float = 0.0
		var chosen_idx: int = 0

		for i: int in range(pool.size()):
			cumulative += _get_item_weight(pool[i], luck_active, false)
			if roll <= cumulative:
				chosen_idx = i
				break

		selected.append(pool[chosen_idx])
		pool.remove_at(chosen_idx)

	return selected


static func get_boss_buff_rewards(count: int, all_items: Array[ItemData]) -> Array[ItemData]:
	var rare_buffs: Array[ItemData] = []
	var other_buffs: Array[ItemData] = []
	for item: ItemData in all_items:
		if item == null:
			continue
		if item.type == ItemData.ItemType.PASSIVE_BUFF:
			if item.rarity >= ItemData.Rarity.RARE:
				rare_buffs.append(item)
			else:
				other_buffs.append(item)

	rare_buffs.shuffle()
	other_buffs.shuffle()

	var selected: Array[ItemData] = []
	for b: ItemData in rare_buffs:
		if selected.size() < count and not selected.has(b):
			selected.append(b)
	for b: ItemData in other_buffs:
		if selected.size() < count and not selected.has(b):
			selected.append(b)
	return selected


static func get_boss_draft_items(count: int, all_items: Array[ItemData]) -> Array[ItemData]:
	var candidates: Array[ItemData] = all_items.duplicate()
	if candidates.is_empty():
		return []

	var selected: Array[ItemData] = []
	var pool: Array[ItemData] = candidates.duplicate()
	var luck_active: bool = has_rare_weapon_luck()

	while selected.size() < count and not pool.is_empty():
		var total_weight: float = 0.0
		for item: ItemData in pool:
			total_weight += _get_item_weight(item, luck_active, true)

		var roll: float = randf_range(0.0, total_weight)
		var cumulative: float = 0.0
		var chosen_idx: int = 0

		for i: int in range(pool.size()):
			cumulative += _get_item_weight(pool[i], luck_active, true)
			if roll <= cumulative:
				chosen_idx = i
				break

		selected.append(pool[chosen_idx])
		pool.remove_at(chosen_idx)

	return selected


static func _get_item_weight(item: ItemData, luck_active: bool, is_boss_draft: bool) -> float:
	var w: float = ItemData.rarity_weight(item.rarity)

	if is_boss_draft:
		# Boost Rare, Epic, Legendary in boss spoils
		if item.rarity == ItemData.Rarity.RARE or item.rarity == ItemData.Rarity.EPIC:
			w *= 2.5
		elif item.rarity == ItemData.Rarity.LEGENDARY:
			w *= 2.0
	else:
		# Standard Shop balanced weapon multiplier
		if item.type == ItemData.ItemType.WEAPON:
			w *= 1.35

	# Blacksmith Talisman: substantially boosts rare, epic, legendary weapons
	if luck_active and item.type == ItemData.ItemType.WEAPON and item.rarity != ItemData.Rarity.COMMON:
		w *= 2.5

	return w
