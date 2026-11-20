class_name EventBusClass
extends Node
## Central event bus — all game-wide signals live here.

# --- Wave / Floor ---
signal wave_started(floor_index: int)
signal wave_ended(floor_index: int)
signal floor_cleared(floor_index: int)
signal floor_transition_requested(next_floor_index: int)

# --- Combat ---
signal enemy_killed(enemy_position: Vector2, gold_value: int)
signal boss_killed(boss_id: String)
signal player_hit(damage: int)
signal player_died()

# --- Economy / Items ---
signal gold_changed(new_total: int)
signal item_bought(item_id: String)
signal item_picked(item_id: String)
signal weapons_changed()
signal weapon_dropped(item_id: String)

# --- UI ---
signal shop_opened(card_list: Array)
signal shop_closed()
signal draft_opened(card_list: Array)
signal draft_closed()
