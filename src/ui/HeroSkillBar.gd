class_name HeroSkillBar
extends Control
## Displays Hero Character Ultimate Art (damage-charged).
## Located at bottom-right corner of screen, clickable with mouse or via E / Q / Space.

@onready var ult_btn: Button = $HBox/UltimateSlot/UltButton
@onready var ult_name_lbl: Label = $HBox/UltimateSlot/UltButton/VBox/UltName
@onready var ult_charge_lbl: Label = $HBox/UltimateSlot/UltButton/VBox/ChargeLabel
@onready var ult_overlay: ColorRect = $HBox/UltimateSlot/UltButton/ChargeOverlay
@onready var ult_glow: NinePatchRect = $HBox/UltimateSlot/UltButton/GlowBorder
@onready var key_lbl: Label = $HBox/UltimateSlot/UltButton/VBox/KeyLabel

var _ult_pulse_tween: Tween = null
var _is_ult_ready: bool = false
var _is_aiming: bool = false
var _hero_class: ClassData = null


func _ready() -> void:
	EventBus.hero_ultimate_charge_updated.connect(_on_ult_charge_updated)
	EventBus.hero_ultimate_used.connect(_on_ult_used)
	EventBus.hero_skill_aiming_changed.connect(_on_aiming_changed)

	ult_btn.pressed.connect(_on_ult_pressed)

	_setup_from_class(GameManager.chosen_class)


func _setup_from_class(p_class: ClassData) -> void:
	if p_class == null:
		var default_path: String = "res://src/data/classes/knight.tres"
		if ResourceLoader.exists(default_path):
			p_class = load(default_path) as ClassData
	_hero_class = p_class

	if _hero_class != null:
		ult_name_lbl.text = _hero_class.ultimate_name.get_slice("(", 0).strip_edges()
		ult_btn.tooltip_text = "%s\n%s\n[Yêu cầu: %d sát thương | Nhấn E hoặc Click để ngắm, Chuột Trái để dùng (Nhấn lại E để hủy)]" % [
			_hero_class.ultimate_name, _hero_class.ultimate_desc, _hero_class.ultimate_required_damage
		]

	ult_overlay.visible = true
	ult_glow.visible = false
	ult_charge_lbl.text = "0%"
	key_lbl.text = "[E | Click]"


func _on_ult_pressed() -> void:
	var players: Array[Node] = get_tree().get_nodes_in_group(&"player")
	if players.size() > 0:
		var p: Player = players[0] as Player
		if p != null:
			if _is_aiming:
				p.cancel_ability_aiming()
			else:
				p.cast_ultimate_ability()


func _on_ult_charge_updated(current_dmg: int, max_dmg: int) -> void:
	var pct: float = clampf(float(current_dmg) / float(maxi(max_dmg, 1)), 0.0, 1.0)
	if pct >= 1.0:
		_is_ult_ready = true
		ult_overlay.visible = false
		if not _is_aiming:
			ult_charge_lbl.text = "SẴN SÀNG!"
			ult_charge_lbl.add_theme_color_override(&"font_color", Color(0.35, 1.0, 0.45, 1.0))
			ult_name_lbl.add_theme_color_override(&"font_color", Color(1.0, 1.0, 1.0, 1.0))
			key_lbl.text = "[E | Click]"
		_start_ult_glow()
	else:
		_is_ult_ready = false
		ult_overlay.visible = true
		ult_charge_lbl.text = "%d%%" % roundi(pct * 100.0)
		ult_charge_lbl.add_theme_color_override(&"font_color", Color(1.0, 0.75, 0.35, 1.0))
		ult_name_lbl.add_theme_color_override(&"font_color", Color(0.9, 0.9, 0.9, 1.0))
		key_lbl.text = "[E | Click]"
		_stop_ult_glow()


func _on_aiming_changed(is_aiming: bool) -> void:
	_is_aiming = is_aiming
	if is_aiming:
		key_lbl.text = "[CHUỘT TRÁI]"
		ult_charge_lbl.text = "BẮN (E: HỦY)"
		ult_charge_lbl.add_theme_color_override(&"font_color", Color(1.0, 0.95, 0.3, 1.0))
		ult_btn.modulate = Color(1.3, 1.3, 0.4, 1.0)
	else:
		ult_btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
		if _is_ult_ready:
			key_lbl.text = "[E | Click]"
			ult_charge_lbl.text = "SẴN SÀNG!"
			ult_charge_lbl.add_theme_color_override(&"font_color", Color(0.35, 1.0, 0.45, 1.0))
		else:
			key_lbl.text = "[E | Click]"


func _start_ult_glow() -> void:
	ult_glow.visible = true
	if _ult_pulse_tween != null and _ult_pulse_tween.is_valid():
		return
	_ult_pulse_tween = create_tween().set_loops()
	_ult_pulse_tween.tween_property(ult_glow, ^"modulate", Color(1.3, 1.1, 0.3, 1.0), 0.5)
	_ult_pulse_tween.tween_property(ult_glow, ^"modulate", Color(1.4, 0.5, 0.2, 1.0), 0.5)


func _stop_ult_glow() -> void:
	if _ult_pulse_tween != null and _ult_pulse_tween.is_valid():
		_ult_pulse_tween.kill()
		_ult_pulse_tween = null
	ult_glow.visible = false


func _on_ult_used(_id: String) -> void:
	_stop_ult_glow()
	_is_aiming = false
	key_lbl.text = "[E | Click]"
	ult_btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
	ult_charge_lbl.text = "0%"
	ult_charge_lbl.add_theme_color_override(&"font_color", Color(1.0, 0.75, 0.35, 1.0))
	var tw: Tween = create_tween()
	tw.tween_property(ult_btn, ^"scale", Vector2(1.25, 1.25), 0.10)
	tw.tween_property(ult_btn, ^"scale", Vector2.ONE, 0.15)
