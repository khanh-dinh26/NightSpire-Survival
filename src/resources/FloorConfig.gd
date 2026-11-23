class_name FloorConfig
extends Resource
## Configuration for a single floor within a tower run.

enum FloorType { COMBAT_WAVE, MINIBOSS, NPC_SANCTUARY, FINAL_BOSS }

@export var floor_index: int = 1  # 1..100
@export var floor_type: FloorType = FloorType.COMBAT_WAVE

## Wave settings (only for COMBAT_WAVE)
@export var wave_duration: float = 30.0  # seconds
@export var spawn_interval: float = 2.0  # seconds between spawn bursts
@export var enemies_per_burst: int = 2
@export var max_concurrent_enemies: int = 15

## Difficulty scaling
@export var enemy_hp_multiplier: float = 1.0
@export var enemy_damage_multiplier: float = 1.0
@export var enemy_speed_multiplier: float = 1.0

## Gold multiplier for this floor
@export var gold_multiplier: float = 1.0


static func generate_100_floors(saved_types: Array = []) -> Array[FloorConfig]:
	var configs: Array[FloorConfig] = []
	var has_saved: bool = (saved_types.size() == 100)

	var types: Array[int] = []
	if has_saved:
		for t: Variant in saved_types:
			types.append(int(t))
	else:
		types.resize(100)
		for i: int in range(100):
			types[i] = int(FloorType.COMBAT_WAVE)

		# 1. Floor 100 is always FINAL_BOSS
		types[99] = int(FloorType.FINAL_BOSS)

		# 2. Floor 99 is always NPC_SANCTUARY (Thương nhân trước final boss)
		types[98] = int(FloorType.NPC_SANCTUARY)

		# 3. Boss pacing: every 3, 4, or 5 floors
		var next_boss: int = randi_range(3, 5)
		while next_boss < 97:
			types[next_boss] = int(FloorType.MINIBOSS)
			next_boss += randi_range(3, 5)

		# 4. Merchant: random floors, strictly < 5 visits total (Floor 99 + 3 earlier = 4 total)
		var candidate_merchant_floors: Array[int] = []
		for f: int in range(6, 95):
			if types[f] == int(FloorType.COMBAT_WAVE):
				candidate_merchant_floors.append(f)
		candidate_merchant_floors.shuffle()
		var extra_merchants: int = mini(3, candidate_merchant_floors.size())
		for m: int in range(extra_merchants):
			types[candidate_merchant_floors[m]] = int(FloorType.NPC_SANCTUARY)

	for idx: int in range(1, 101):
		var cfg: FloorConfig = FloorConfig.new()
		cfg.floor_index = idx
		cfg.floor_type = types[idx - 1] as FloorType

		# Wave settings
		cfg.wave_duration = clampf(25.0 + float(idx) * 0.10, 25.0, 35.0)
		cfg.spawn_interval = clampf(2.0 - float(idx) * 0.011, 0.9, 2.0)
		cfg.enemies_per_burst = clampi(2 + idx / 18, 2, 7)
		cfg.max_concurrent_enemies = clampi(14 + idx / 5, 14, 34)

		# Difficulty scaling across 100 floors
		cfg.enemy_hp_multiplier = 1.0 + float(idx - 1) * 0.10
		cfg.enemy_damage_multiplier = 1.0 + float(idx - 1) * 0.05
		cfg.enemy_speed_multiplier = clampf(1.0 + float(idx - 1) * 0.003, 1.0, 1.35)
		cfg.gold_multiplier = 1.0
		configs.append(cfg)

	return configs
