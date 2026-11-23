class_name TowerData
extends Resource
## Data definition for a single Tower (Spire) with distinct traits and modifiers.

@export var tower_id: String = ""
@export var tower_name: String = ""
@export_multiline var lore_description: String = ""

## Trait Descriptions for UI
@export var player_buff_desc: String = ""
@export var player_debuff_desc: String = ""
@export var enemy_trait_desc: String = ""

## Player Modifiers
@export var player_speed_mult: float = 1.0
@export var player_atk_speed_mult: float = 1.0
@export var player_heal_mult: float = 1.0
@export var player_dmg_taken_mult: float = 1.0
@export var player_dmg_deal_mult: float = 1.0
@export var player_spell_dmg_mult: float = 1.0
@export var player_crit_bonus: float = 0.0
@export var player_gold_mult: float = 1.0

## Enemy Modifiers
@export var enemy_hp_mult: float = 1.0
@export var enemy_speed_mult: float = 1.0
@export var enemy_dmg_mult: float = 1.0
@export var enemy_knockback_resist: float = 0.0

## Tile coordinates on tiles.png for floor tiles (row, cols)
@export var floor_tile_atlas_coords: Array[Vector2i] = []
## Tile coordinates for wall tiles
@export var wall_tile_atlas_coords: Array[Vector2i] = []

## Tower environment modifier enum
enum TowerModifier { NONE, BLIGHTWOOD_POISON, CATACOMB_CURSE, CINDERFORGE_INFERNO }
@export var tower_modifier: TowerModifier = TowerModifier.NONE
@export var modifier_value: float = 0.25

## Enemy pools
@export var common_enemies: Array[EnemyData] = []
@export var miniboss_pool: Array[EnemyData] = []
@export var final_boss: EnemyData = null

## Visual tint
@export var ambient_color: Color = Color(1.0, 1.0, 1.0, 1.0)
