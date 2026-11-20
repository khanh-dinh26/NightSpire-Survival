class_name TowerData
extends Resource
## Data definition for a single Tower (Spire).

@export var tower_id: String = ""
@export var tower_name: String = ""
@export_multiline var lore_description: String = ""

## Tile coordinates on tiles.png for floor tiles (row, cols)
@export var floor_tile_atlas_coords: Array[Vector2i] = []
## Tile coordinates for wall tiles
@export var wall_tile_atlas_coords: Array[Vector2i] = []

## Tower environment modifier
enum TowerModifier { NONE, POISON, REDUCED_HEAL_MORE_GOLD, INCREASED_DAMAGE }
@export var tower_modifier: TowerModifier = TowerModifier.NONE
@export var modifier_value: float = 0.25  # percentage

## Enemy pools
@export var common_enemies: Array[EnemyData] = []
@export var miniboss_pool: Array[EnemyData] = []
@export var final_boss: EnemyData = null

## Visual tint
@export var ambient_color: Color = Color(1.0, 1.0, 1.0, 1.0)
