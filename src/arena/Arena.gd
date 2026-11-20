class_name Arena
extends Node2D
## The combat arena — draws floor/wall tiles from TowerData and manages spawn positions and boundaries.

const ARENA_WIDTH: int = 40   # tiles (1280 px)
const ARENA_HEIGHT: int = 26  # tiles (832 px)
const TILE_SIZE: int = 32
const DOOR_GAP_WIDTH: int = 2 # tiles wide, centered in top wall

@onready var floor_layer: TileMapLayer = $FloorLayer
@onready var decor_layer: TileMapLayer = $DecorLayer
@onready var wall_layer: TileMapLayer = $WallLayer
@onready var entities: Node2D = $Entities

var _spawn_bounds: Rect2 = Rect2()

# --- Atlas source ID inside the TileSet ---
const ATLAS_SOURCE_ID: int = 0


func _ready() -> void:
	_ensure_tileset_source()
	_build_perimeter_colliders()
	_setup_camera_limits()
	var hud: HUD = get_node_or_null("HUD") as HUD
	var spawner_node: Spawner = get_node_or_null("Spawner") as Spawner
	if hud != null and spawner_node != null:
		hud.setup_spawner(spawner_node)


func _ensure_tileset_source() -> void:
	if floor_layer == null:
		floor_layer = get_node_or_null("FloorLayer") as TileMapLayer
	if decor_layer == null:
		decor_layer = get_node_or_null("DecorLayer") as TileMapLayer
	if wall_layer == null:
		wall_layer = get_node_or_null("WallLayer") as TileMapLayer
	if floor_layer == null or floor_layer.tile_set == null:
		return
	var source: TileSetAtlasSource = floor_layer.tile_set.get_source(ATLAS_SOURCE_ID) as TileSetAtlasSource
	if source != null:
		for x: int in range(17):
			for y: int in range(27):
				if not source.has_tile(Vector2i(x, y)):
					source.create_tile(Vector2i(x, y))


func _setup_camera_limits() -> void:
	var player_node: Node2D = get_node_or_null("Player") as Node2D
	if player_node != null:
		var cam: Camera2D = player_node.get_node_or_null("Camera2D") as Camera2D
		if cam != null:
			cam.limit_left = 0
			cam.limit_top = 0
			cam.limit_right = ARENA_WIDTH * TILE_SIZE
			cam.limit_bottom = ARENA_HEIGHT * TILE_SIZE


func setup_floor(tower: TowerData, floor_config: FloorConfig) -> void:
	if floor_layer == null:
		floor_layer = get_node_or_null("FloorLayer") as TileMapLayer
	if decor_layer == null:
		decor_layer = get_node_or_null("DecorLayer") as TileMapLayer
	if wall_layer == null:
		wall_layer = get_node_or_null("WallLayer") as TileMapLayer

	_ensure_tileset_source()
	_setup_camera_limits()
	_clear_tiles()
	_draw_floor(tower)
	_draw_walls(tower, floor_config)
	_draw_decorations(tower)
	_calculate_spawn_bounds()

	# Apply ambient colour tint to floor and decor layers
	if floor_layer != null:
		if GameManager.is_dark_night:
			floor_layer.modulate = Color(0.45, 0.25, 0.6, 1.0)
		else:
			floor_layer.modulate = tower.ambient_color

	if decor_layer != null:
		if GameManager.is_dark_night:
			decor_layer.modulate = Color(0.55, 0.35, 0.7, 1.0)
		else:
			decor_layer.modulate = tower.ambient_color


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
	var existing = get_node_or_null("PerimeterColliders")
	if existing != null:
		existing.queue_free()

	var total_w: float = float(ARENA_WIDTH * TILE_SIZE)
	var total_h: float = float(ARENA_HEIGHT * TILE_SIZE)
	var wall_thick: float = float(TILE_SIZE * 2) # Double wall thickness for clear boundary

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
	if decor_layer != null:
		decor_layer.clear()


func _draw_decorations(tower: TowerData) -> void:
	if decor_layer == null:
		return

	var tower_id: String = tower.tower_id if tower != null else "blightwood"
	var decor_tiles: Array[Vector2i] = []

	match tower_id:
		"blightwood":
			# Trees, saplings, forest mushrooms
			decor_tiles = [Vector2i(0, 25), Vector2i(1, 25), Vector2i(2, 25), Vector2i(0, 20), Vector2i(1, 20)]
		"catacomb":
			# Skulls, bones, tombstones, sarcophagi, urns
			decor_tiles = [Vector2i(0, 21), Vector2i(1, 21), Vector2i(0, 23), Vector2i(3, 23), Vector2i(2, 17)]
		"cinderforge":
			# Boulders, molten rocks, barrels, demonic pentagrams
			decor_tiles = [Vector2i(0, 18), Vector2i(1, 18), Vector2i(4, 17), Vector2i(2, 17), Vector2i(14, 16)]
		_:
			decor_tiles = [Vector2i(0, 25), Vector2i(1, 25)]

	# Scatter decorations along the borders and corners without obstructing center
	var decor_count: int = 24
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()

	for i: int in range(decor_count):
		var tile_coord: Vector2i = decor_tiles[rng.randi() % decor_tiles.size()]
		var tx: int = 0
		var ty: int = 0
		# Place primarily near walls (outer ring)
		if rng.randf() <= 0.5:
			tx = rng.randi_range(3, ARENA_WIDTH - 4)
			ty = rng.randi_range(2, 4) if rng.randf() <= 0.5 else rng.randi_range(ARENA_HEIGHT - 5, ARENA_HEIGHT - 3)
		else:
			tx = rng.randi_range(2, 4) if rng.randf() <= 0.5 else rng.randi_range(ARENA_WIDTH - 5, ARENA_WIDTH - 3)
			ty = rng.randi_range(3, ARENA_HEIGHT - 4)

		decor_layer.set_cell(Vector2i(tx, ty), ATLAS_SOURCE_ID, tile_coord)


func _draw_floor(tower: TowerData) -> void:
	var coords: Array[Vector2i] = tower.floor_tile_atlas_coords
	if GameManager.is_dark_night:
		coords = [Vector2i(1, 13), Vector2i(2, 13), Vector2i(3, 13)]

	if coords.is_empty():
		return

	# Fill the entire interior walkable area inside the double walls (2..ARENA_WIDTH-3, 2..ARENA_HEIGHT-3)
	for x: int in range(2, ARENA_WIDTH - 2):
		for y: int in range(2, ARENA_HEIGHT - 2):
			var atlas_coord: Vector2i = coords[randi() % coords.size()]
			floor_layer.set_cell(Vector2i(x, y), ATLAS_SOURCE_ID, atlas_coord)


func _draw_walls(tower: TowerData, _floor_config: FloorConfig) -> void:
	var coords: Array[Vector2i] = tower.wall_tile_atlas_coords
	if coords.is_empty():
		coords = [Vector2i(0, 0), Vector2i(1, 0)]

	var top_wall_tile: Vector2i = coords[0]
	var side_wall_tile: Vector2i = coords[mini(1, coords.size() - 1)]

	# Outer and inner border wall rows (row 0 and 1: top wall; row ARENA_HEIGHT-2 and ARENA_HEIGHT-1: bottom wall)
	for x: int in range(ARENA_WIDTH):
		wall_layer.set_cell(Vector2i(x, 0), ATLAS_SOURCE_ID, top_wall_tile)
		wall_layer.set_cell(Vector2i(x, 1), ATLAS_SOURCE_ID, side_wall_tile)
		wall_layer.set_cell(Vector2i(x, ARENA_HEIGHT - 2), ATLAS_SOURCE_ID, side_wall_tile)
		wall_layer.set_cell(Vector2i(x, ARENA_HEIGHT - 1), ATLAS_SOURCE_ID, top_wall_tile)

	# Left and right double columns (col 0, 1 and col ARENA_WIDTH-2, ARENA_WIDTH-1)
	for y: int in range(ARENA_HEIGHT):
		wall_layer.set_cell(Vector2i(0, y), ATLAS_SOURCE_ID, top_wall_tile)
		wall_layer.set_cell(Vector2i(1, y), ATLAS_SOURCE_ID, side_wall_tile)
		wall_layer.set_cell(Vector2i(ARENA_WIDTH - 2, y), ATLAS_SOURCE_ID, side_wall_tile)
		wall_layer.set_cell(Vector2i(ARENA_WIDTH - 1, y), ATLAS_SOURCE_ID, top_wall_tile)


func _calculate_spawn_bounds() -> void:
	# Walkable area: 2 tiles inward (walls) + 1 tile buffer on each side
	var margin: int = 3
	_spawn_bounds = Rect2(
		Vector2(float(margin * TILE_SIZE), float(margin * TILE_SIZE)),
		Vector2(
			float((ARENA_WIDTH - margin * 2) * TILE_SIZE),
			float((ARENA_HEIGHT - margin * 2) * TILE_SIZE)
		)
	)
