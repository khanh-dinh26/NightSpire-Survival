class_name ItemPool
extends RefCounted
## Utility for generating random items for Wave Shop and Boss Draft.

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

	while selected.size() < count and not pool.is_empty():
		var total_weight: float = 0.0
		for item: ItemData in pool:
			var w: float = ItemData.rarity_weight(item.rarity)
			if item.type == ItemData.ItemType.WEAPON:
				w *= 2.2
				if item.rarity == ItemData.Rarity.COMMON:
					w *= 1.5
			total_weight += w

		var roll: float = randf_range(0.0, total_weight)
		var cumulative: float = 0.0
		var chosen_idx: int = 0

		for i: int in range(pool.size()):
			var w: float = ItemData.rarity_weight(pool[i].rarity)
			if pool[i].type == ItemData.ItemType.WEAPON:
				w *= 2.2
				if pool[i].rarity == ItemData.Rarity.COMMON:
					w *= 1.5
			cumulative += w
			if roll <= cumulative:
				chosen_idx = i
				break

		selected.append(pool[chosen_idx])
		pool.remove_at(chosen_idx)

	return selected


static func get_boss_draft_items(count: int, all_items: Array[ItemData]) -> Array[ItemData]:
	var candidates: Array[ItemData] = all_items.duplicate()
	if candidates.is_empty():
		return []

	var selected: Array[ItemData] = []
	var pool: Array[ItemData] = candidates.duplicate()

	while selected.size() < count and not pool.is_empty():
		var total_weight: float = 0.0
		for item: ItemData in pool:
			var w: float = ItemData.rarity_weight(item.rarity)
			# Boost Rare and Epic weights
			if item.rarity == ItemData.Rarity.RARE or item.rarity == ItemData.Rarity.EPIC:
				w *= 2.5
			total_weight += w

		var roll: float = randf_range(0.0, total_weight)
		var cumulative: float = 0.0
		var chosen_idx: int = 0

		for i: int in range(pool.size()):
			var w: float = ItemData.rarity_weight(pool[i].rarity)
			if pool[i].rarity == ItemData.Rarity.RARE or pool[i].rarity == ItemData.Rarity.EPIC:
				w *= 2.5
			cumulative += w
			if roll <= cumulative:
				chosen_idx = i
				break

		selected.append(pool[chosen_idx])
		pool.remove_at(chosen_idx)

	return selected
