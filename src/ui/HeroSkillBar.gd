class_name HeroSkillBar
extends Control
## Displays Hero Character Skill (cooldown-based) and Ultimate Art (damage-charged)
## Located at bottom-right corner of screen, clickable with mouse or via hotkeys.

@onready var skill_btn: Button = $HBox/SkillSlot/SkillButton
@onready var skill_name_lbl: Label = $HBox/SkillSlot/SkillButton/VBox/SkillName
@onready var skill_cd_overlay: ColorRect = $HBox/SkillSlot/SkillButton/CDOverlay
@onready var skill_cd_lbl: Label = $HBox/SkillSlot/SkillButton/CDOverlay/CDLabel
@onready var skill_key_lbl: Label = $HBox/SkillSlot/SkillButton/VBox/KeyLabel

@onready var ult_btn: Button = $HBox/UltimateSlot/UltButton
@onready var ult_name_lbl: Label = $HBox/UltimateSlot/UltButton/VBox/UltName
@onready var ult_charge_lbl: Label = $HBox/UltimateSlot/UltButton/VBox/ChargeLabel
@onready var ult_overlay: ColorRect = $HBox/UltimateSlot/UltButton/ChargeOverlay
@onready var ult_glow: NinePatchRect = $HBox/UltimateSlot/UltButton/GlowBorder

var _ult_pulse_tween: Tween = null
var _is_ult_ready: bool = false
var _hero_class: ClassData = null


func _ready() -> void:
	EventBus.hero_skill_cooldown_updated.connect(_on_skill_cd_updated)
	EventBus.hero_ultimate_charge_updated.connect(_on_ult_charge_updated)
	EventBus.hero_skill_used.connect(_on_skill_used)
	EventBus.hero_ultimate_used.connect(_on_ult_used)

	skill_btn.pressed.connect(_on_skill_pressed)
	ult_btn.pressed.connect(_on_ult_pressed)

	_setup_from_class(GameManager.chosen_class)


func _setup_from_class(p_class: ClassData) -> void:
	if p_class == null:
		var default_path: String = "res://src/data/classes/knight.tres"
		if ResourceLoader.exists(default_path):
			p_class = load(default_path) as ClassData
	_hero_class = p_class

	if _hero_class != null:
		skill_name_lbl.text = _hero_class.skill_name.get_slice("(", 0).strip_edges()
		skill_btn.tooltip_text = "%s\n%s\n[Hồi: %.1fs | Click chuột hoặc phím E / Chuột Phải]" % [
			_hero_class.skill_name, _hero_class.skill_desc, _hero_class.skill_cooldown
		]

		ult_name_lbl.text = _hero_class.ultimate_name.get_slice("(", 0).strip_edges()
		ult_btn.tooltip_text = "%s\n%s\n[Yêu cầu: %d sát thương | Click chuột hoặc phím Q / Space]" % [
			_hero_class.ultimate_name, _hero_class.ultimate_desc, _hero_class.ultimate_required_damage
		]

	skill_cd_overlay.visible = false
	ult_overlay.visible = true
	ult_glow.visible = false
	ult_charge_lbl.text = "0%"


func _on_skill_pressed() -> void:
	var players: Array[Node] = get_tree().get_nodes_in_group(&"player")
	if players.size() > 0:
		var p: Player = players[0] as Player
		if p != null:
			p.cast_character_skill()


func _on_ult_pressed() -> void:
	var players: Array[Node] = get_tree().get_nodes_in_group(&"player")
	if players.size() > 0:
		var p: Player = players[0] as Player
		if p != null:
			p.cast_ultimate_art()


func _on_skill_cd_updated(current_cd: float, max_cd: float) -> void:
	if current_cd > 0.05:
		skill_cd_overlay.visible = true
		skill_cd_lbl.text = "%.1fs" % current_cd
		skill_btn.disabled = true
		skill_btn.modulate = Color(0.65, 0.65, 0.65, 0.9)
	else:
		skill_cd_overlay.visible = false
		skill_btn.disabled = false
		skill_btn.modulate = Color(1.0, 1.0, 1.0, 1.0)


func _on_ult_charge_updated(current_dmg: int, max_dmg: int) -> void:
	var pct: float = clampf(float(current_dmg) / float(maxi(max_dmg, 1)), 0.0, 1.0)
	if pct >= 1.0:
		_is_ult_ready = true
		ult_overlay.visible = false
		ult_btn.disabled = false
		ult_charge_lbl.text = "SẴN SÀNG!"
		ult_charge_lbl.add_theme_color_override(&"font_color", Color(1.0, 0.95, 0.3))
		_start_ult_glow()
	else:
		_is_ult_ready = false
		ult_overlay.visible = true
		ult_btn.disabled = true
		ult_charge_lbl.text = "%d%%" % roundi(pct * 100.0)
		ult_charge_lbl.add_theme_color_override(&"font_color", Color(1.0, 0.75, 0.35))
		_stop_ult_glow()


func _start_ult_glow() -> void:
	ult_glow.visible = true
	if _ult_pulse_tween != null and _ult_pulse_tween.is_valid():
		return
	_ult_pulse_tween = create_tween().set_loops()
	_ult_pulse_tween.tween_property(ult_glow, ^"modulate", Color(1.5, 1.2, 0.3, 1.0), 0.45)
	_ult_pulse_tween.tween_property(ult_glow, ^"modulate", Color(1.8, 0.4, 0.2, 1.0), 0.45)


func _stop_ult_glow() -> void:
	if _ult_pulse_tween != null and _ult_pulse_tween.is_valid():
		_ult_pulse_tween.kill()
		_ult_pulse_tween = null
	ult_glow.visible = false


func _on_skill_used(_id: String) -> void:
	# Punch pop on use
	var tw: Tween = create_tween()
	tw.tween_property(skill_btn, ^"scale", Vector2(1.2, 1.2), 0.08)
	tw.tween_property(skill_btn, ^"scale", Vector2.ONE, 0.12)


func _on_ult_used(_id: String) -> void:
	# Epic flash and reset
	_stop_ult_glow()
	ult_charge_lbl.text = "0%"
	var tw: Tween = create_tween()
	tw.tween_property(ult_btn, ^"scale", Vector2(1.3, 1.3), 0.10)
	tw.tween_property(ult_btn, ^"scale", Vector2.ONE, 0.15)
