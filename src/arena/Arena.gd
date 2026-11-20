class_name Arena
extends Node2D
## The combat arena — draws floor/wall tiles from TowerData and manages spawn positions and boundaries.

const ARENA_WIDTH: int = 18   # tiles
const ARENA_HEIGHT: int = 12  # tiles
const TILE_SIZE: int = 32
const DOOR_GAP_WIDTH: int = 2 # tiles wide, centered in top wall

@onready var floor_layer: TileMapLayer = $FloorLayer
@onready var wall_layer: TileMapLayer = $WallLayer
@onready var entities: Node2D = $Entities

var _spawn_bounds: Rect2 = Rect2()

# --- Atlas source ID inside the TileSet ---
const ATLAS_SOURCE_ID: int = 0


func _ready() -> void:
	_build_perimeter_colliders()
	var hud: HUD = get_node_or_null("HUD") as HUD
	var spawner_node: Spawner = get_node_or_null("Spawner") as Spawner
	if hud != null and spawner_node != null:
		hud.setup_spawner(spawner_node)


func setup_floor(tower: TowerData, floor_config: FloorConfig) -> void:
	_clear_tiles()
	_draw_floor(tower)
	_draw_walls(tower, floor_config)
	_calculate_spawn_bounds()

	# Apply ambient colour tint to the floor layer
	floor_layer.modulate = tower.ambient_color


func get_spawn_bounds() -> Rect2:
	return _spawn_bounds


func get_random_spawn_position() -> Vector2:
	var x: float = randf_range(_spawn_bounds.position.x, _spawn_bounds.end.x)
	var y: float = randf_range(_spawn_bounds.position.y, _spawn_bounds.end.y)
	return Vector2(x, y)


func get_center_position() -> Vector2:
	return Vector2(
		float(ARENA_WIDTH * TILE_SIZE) / 2.0,
		float(ARENA_HEIGHT * TILE_SIZE) / 2.0
	)


# ---------------------------------------------------------------------------
#  Collision boundaries
# ---------------------------------------------------------------------------

func _build_perimeter_colliders() -> void:
	var total_w: float = float(ARENA_WIDTH * TILE_SIZE)
	var total_h: float = float(ARENA_HEIGHT * TILE_SIZE)
	var wall_thick: float = float(TILE_SIZE)

	# StaticBody container
	var body: StaticBody2D = StaticBody2D.new()
	body.name = "PerimeterColliders"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)

	# Top Wall
	_add_wall_shape(body, Vector2(total_w / 2.0, wall_thick / 2.0), Vector2(total_w, wall_thick))
	# Bottom Wall
	_add_wall_shape(body, Vector2(total_w / 2.0, total_h - wall_thick / 2.0), Vector2(total_w, wall_thick))
	# Left Wall
	_add_wall_shape(body, Vector2(wall_thick / 2.0, total_h / 2.0), Vector2(wall_thick, total_h))
	# Right Wall
	_add_wall_shape(body, Vector2(total_w - wall_thick / 2.0, total_h / 2.0), Vector2(wall_thick, total_h))


func _add_wall_shape(body: StaticBody2D, pos: Vector2, size: Vector2) -> void:
	var col: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = size
	col.shape = rect
	col.position = pos
	body.add_child(col)


# ---------------------------------------------------------------------------
#  Private tile drawing helpers
# ---------------------------------------------------------------------------

func _clear_tiles() -> void:
	floor_layer.clear()
	wall_layer.clear()


func _draw_floor(tower: TowerData) -> void:
	var coords: Array[Vector2i] = tower.floor_tile_atlas_coords
	if coords.is_empty():
		return

	# Fill the interior (1‥ARENA_WIDTH-2, 1‥ARENA_HEIGHT-2)
	for x: int in range(1, ARENA_WIDTH - 1):
		for y: int in range(1, ARENA_HEIGHT - 1):
			var atlas_coord: Vector2i = coords[randi() % coords.size()]
			floor_layer.set_cell(Vector2i(x, y), ATLAS_SOURCE_ID, atlas_coord)


func _draw_walls(tower: TowerData, floor_config: FloorConfig) -> void:
	var coords: Array[Vector2i] = tower.wall_tile_atlas_coords
	if coords.is_empty():
		return

	# Door gap position (centered in top wall)
	var gap_start: int = (ARENA_WIDTH - DOOR_GAP_WIDTH) / 2
	var gap_end: int = gap_start + DOOR_GAP_WIDTH  # exclusive
	var is_intermediate_floor: bool = (
		floor_config.floor_index >= 1 and floor_config.floor_index <= 9
	)

	# Top wall (row 0)
	for x: int in range(ARENA_WIDTH):
		if is_intermediate_floor and x >= gap_start and x < gap_end:
			continue  # leave door gap
		var atlas_coord: Vector2i = coords[0]  # top variant
		wall_layer.set_cell(Vector2i(x, 0), ATLAS_SOURCE_ID, atlas_coord)

	# Bottom wall (row ARENA_HEIGHT - 1)
	for x: int in range(ARENA_WIDTH):
		var atlas_coord: Vector2i = _pick_side_wall(coords)
		wall_layer.set_cell(Vector2i(x, ARENA_HEIGHT - 1), ATLAS_SOURCE_ID, atlas_coord)

	# Left wall (col 0, rows 1‥ARENA_HEIGHT-2)
	for y: int in range(1, ARENA_HEIGHT - 1):
		var atlas_coord: Vector2i = _pick_side_wall(coords)
		wall_layer.set_cell(Vector2i(0, y), ATLAS_SOURCE_ID, atlas_coord)

	# Right wall (col ARENA_WIDTH - 1, rows 1‥ARENA_HEIGHT-2)
	for y: int in range(1, ARENA_HEIGHT - 1):
		var atlas_coord: Vector2i = _pick_side_wall(coords)
		wall_layer.set_cell(Vector2i(ARENA_WIDTH - 1, y), ATLAS_SOURCE_ID, atlas_coord)


func _pick_side_wall(coords: Array[Vector2i]) -> Vector2i:
	if coords.size() > 1:
		return coords[1 + randi() % (coords.size() - 1)]
	return coords[0]


func _calculate_spawn_bounds() -> void:
	# Walkable area: one tile inward from walls on each side
	var margin: int = 2
	_spawn_bounds = Rect2(
		Vector2(float(margin * TILE_SIZE), float(margin * TILE_SIZE)),
		Vector2(
			float((ARENA_WIDTH - margin * 2) * TILE_SIZE),
			float((ARENA_HEIGHT - margin * 2) * TILE_SIZE)
		)
	)
