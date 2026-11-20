class_name FloorConfig
extends Resource
## Configuration for a single floor within a tower run.

enum FloorType { COMBAT_WAVE, MINIBOSS, NPC_SANCTUARY, FINAL_BOSS }

@export var floor_index: int = 1  # 1..10
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
