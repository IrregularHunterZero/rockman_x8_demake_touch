extends FallZero
class_name SaberRasetsusenX8

export  var damage: float = 2.0
export  var damage_boss: float = 2.0
export  var damage_weakness: float = 24.0
export  var saber_hitbox: Resource = preload("res://Zero_mod/Player/Hitboxes/Rasetsusen_Hitbox.tscn")

onready var darkarrow: PackedScene = preload("res://Zero_mod/X8/Sprites/zbuster/object/DarkArrow.tscn")
var creator: Node2D

onready var animatedSprite: = character.get_node("animatedSprite")
onready var saber_sound: = get_node("saber")

var current_hitbox = null
var hitbox_name: String = "Rasetsusen"
var hitbox_radius: float = 48
var hitbox_inner_radius: float = 0
var hitbox_upleft_corner: Vector2 = Vector2( - hitbox_radius, - hitbox_radius)
var hitbox_downright_corner: Vector2 = Vector2(hitbox_radius, hitbox_radius)
var hitbox_upleft: Vector2 = Vector2(0, 0)
var hitbox_downright: Vector2 = Vector2(0, 0)
var hitbox_damage: float = 0.0
var hitbox_damage_boss: float = 0.0
var hitbox_damage_weakness: float = 0.0
var hitbox_break_guard_value: float = 0.5
var hitbox_break_guards: bool = false
var hitbox_rehit_time: float = 0.15
var hitbox_upgraded: bool = false
var hitbox_extra_damage: float = 0.0
var hitbox_extra_damage_boss: float = 0.0
var hitbox_extra_damage_weakness: float = 0.0
var hitbox_extra_break_guard_value: float = 0.0
var hitbox_extra_scale: float = 1.0
var deflectable: bool = false
var deflectable_type: int = 0
var only_deflect_weak: bool = false

var ending_saber_state: bool = false
var slashing: bool = false
var slashes: int = 0
var landed: bool = false

var max_time: float = 2.0
var fly_up: bool = false
var falling_down: bool = false
var horizontal_speed: float = horizontal_velocity
var cast_time_max: float = 0.35
var cast_time: float = 0.0
var vertical_last: float = 0.0

# ==== 空中起手：按二段跳（AirJump）的上升曲线来升 ====
# 参数直接读 AirJump 节点，所以普通 Zero 与觉醒 Zero 各自升到自己的二段跳高度，
# 和冰龙升完全一致；按得久就升满，松攻击键就停。
var ascend_velocity: float = 190.0
var ascend_time_max: float = 0.625
var ascend_fullspeed_proportion: float = 0.19
var ascend_fullspeed_time: float = 0.0
var ascend_slowdown_time: float = 0.0
var ascending: bool = false

onready var effect_scene: PackedScene = preload("res://System/misc/visual_effect.tscn")
var effect_spawn_position: Vector2 = Vector2(0, 0)
var effect_spawn_timer: float = 0.0
var effect_spawn_time: float = 0.02
var angles: Array = [
	22.5, 45, 67.5, 90, 
	112.5, 135, 157.5, 180, 
	202.5, 225, 247.5, 270, 
	292.5, 315, 337.5, 360
]
var angle_index: int = 0
var angle_timer: float = 0.0
var angle_interval: float = 1.0 / 60.0

var create_dark_arrow: bool = false

func _ready() -> void :
	saber_sound.stream.loop = true
	animatedSprite.connect("animation_finished", self, "_on_animation_finished")

func _on_animation_finished() -> void :
	ending_saber_state = true

func reset_hitbox() -> void :
	hitbox_upleft = Vector2(0, 0)
	hitbox_downright = Vector2(0, 0)
	hitbox_damage = 0
	hitbox_damage_boss = 0
	hitbox_damage_weakness = 0
	hitbox_break_guard_value = 0.5
	hitbox_break_guards = false

func spawn_hitbox(position: Vector2, _hitbox_upleft: Vector2, _hitbox_downright: Vector2) -> void :

	if character.saber_node.current_weapon.name == "K-Knuckle" or character.saber_node.current_weapon.name == "V-Hanger":
		scale.y = 0.2
	else:
		scale.y = 1

	current_hitbox = saber_hitbox.instance()
	add_child(current_hitbox)
	
	var size = _hitbox_downright - _hitbox_upleft
	var radius = min(size.x, size.y) / 2

	current_hitbox.set_hitbox(position, radius)
	current_hitbox.name = hitbox_name
	current_hitbox.damage = hitbox_damage * hitbox_extra_damage
	current_hitbox.damage_to_bosses = hitbox_damage_boss * hitbox_extra_damage_boss
	current_hitbox.damage_to_weakness = hitbox_damage_weakness * hitbox_extra_damage_weakness
	current_hitbox.break_guard_damage = hitbox_break_guard_value * hitbox_extra_break_guard_value
	current_hitbox.break_guards = hitbox_break_guards
	current_hitbox.saber_rehit = hitbox_rehit_time
	current_hitbox.upgraded = hitbox_upgraded
	current_hitbox.inner_radius = hitbox_inner_radius
	current_hitbox.deflectable = deflectable
	current_hitbox.deflectable_type = deflectable_type
	current_hitbox.only_deflect_weak = only_deflect_weak
	current_hitbox.scale *= hitbox_extra_scale

func hitbox_and_position() -> void :
	hitbox_damage = damage
	hitbox_damage_boss = damage_boss
	hitbox_damage_weakness = damage_weakness
	if animatedSprite.animation == "rasetsusen":
		if character.saber_node.current_weapon.name == "Saber":
			hitbox_upleft = Vector2( - hitbox_radius, - hitbox_radius)
			hitbox_downright = Vector2(hitbox_radius, hitbox_radius)
			spawn_hitbox(Vector2(0, - 8), hitbox_upleft, hitbox_downright)
		elif character.saber_node.current_weapon.name == "B-Fan":
			hitbox_upleft = Vector2( - hitbox_radius, - hitbox_radius)
			hitbox_downright = Vector2(hitbox_radius, hitbox_radius)
			spawn_hitbox(Vector2(0, - 8), hitbox_upleft, hitbox_downright)
		elif character.saber_node.current_weapon.name == "D-Glaive":
			hitbox_upleft = Vector2( - hitbox_radius, - hitbox_radius)
			hitbox_downright = Vector2(hitbox_radius, hitbox_radius)
			spawn_hitbox(Vector2(0, - 8), hitbox_upleft, hitbox_downright)
		elif character.saber_node.current_weapon.name == "T-Breaker":
			hitbox_upleft = Vector2( - hitbox_radius, - hitbox_radius)
			hitbox_downright = Vector2(hitbox_radius, hitbox_radius)
			spawn_hitbox(Vector2(0, - 8), hitbox_upleft, hitbox_downright)
		elif character.saber_node.current_weapon.name == "K-Knuckle":
			hitbox_upleft = Vector2( - hitbox_radius, - hitbox_radius)
			hitbox_downright = Vector2(hitbox_radius, hitbox_radius)
			spawn_hitbox(Vector2(0, - 8), hitbox_upleft, hitbox_downright)
		elif character.saber_node.current_weapon.name == "V-Hanger":
			hitbox_upleft = Vector2( - hitbox_radius, - hitbox_radius)
			hitbox_downright = Vector2(hitbox_radius, hitbox_radius)
			spawn_hitbox(Vector2(0, - 8), hitbox_upleft, hitbox_downright)
		elif character.saber_node.current_weapon.name == "Rogue-Blade":
			hitbox_upleft = Vector2( - hitbox_radius, - hitbox_radius)
			hitbox_downright = Vector2(hitbox_radius, hitbox_radius)
			spawn_hitbox(Vector2(0, - 8), hitbox_upleft, hitbox_downright)
		elif character.saber_node.current_weapon.name == "Sigma-Blade":
			hitbox_upleft = Vector2( - hitbox_radius, - hitbox_radius)
			hitbox_downright = Vector2(hitbox_radius, hitbox_radius)
			spawn_hitbox(Vector2(0, - 8), hitbox_upleft, hitbox_downright)
		elif character.saber_node.current_weapon.name == "Z-Breaker":
			hitbox_upleft = Vector2( - hitbox_radius, - hitbox_radius)
			hitbox_downright = Vector2(hitbox_radius, hitbox_radius)
			spawn_hitbox(Vector2(0, - 8), hitbox_upleft, hitbox_downright)
			if not create_dark_arrow:
				create_dark_arrow = true
				Tools.timer(0.3, "reset_dark_arrow", self)
				if CharacterManager.awakened_zero_armor:
					create_darkarrow(global_position, CharacterManager.z_buster_base_damage * 2)
				elif CharacterManager.black_zero_armor and not CharacterManager.awakened_zero_armor:
					create_darkarrow(global_position, CharacterManager.z_buster_base_damage * 1.2)
				else:
					create_darkarrow(global_position, CharacterManager.z_buster_base_damage)
	reset_hitbox()
	if not create_dark_arrow and CharacterManager.awakened_zero_armor and \
	not character.saber_node.current_weapon.name == "Z-Breaker" and \
	not character.saber_node.current_weapon.name == "K-Knuckle" and \
	not character.saber_node.current_weapon.name == "Sigma-Blade" and \
	not character.saber_node.current_weapon.name == "V-Hanger":
		create_dark_arrow = true
		Tools.timer(0.3, "reset_dark_arrow", self)
		create_darkarrow(global_position, CharacterManager.z_buster_base_damage * 2)

func reset_dark_arrow() -> void :
	create_dark_arrow = false

func create_darkarrow(ground_position, damage_value) -> void :
	var instance = darkarrow.instance()
	instance.get_node("animatedSprite").material = character.get_node("animatedSprite").material
	ground_position.y += -9
	instance.damage = damage_value * 2
	instance.damage_to_bosses = damage_value
	instance.damage_to_weakness = damage_value
	get_tree().current_scene.get_node("Objects").call_deferred("add_child", instance, true)
	instance.set_global_position(ground_position)
	instance.set_creator(creator)
	instance.call_deferred("initialize", get_facing_direction())


func effect_emit(_delta: float) -> void :
	effect_position()
	effect_spawn_timer += _delta
	if effect_spawn_timer >= effect_spawn_time:
		effect_spawn_timer = 0
		var effect_instance = effect_scene.instance()
		effect_instance.frames = load("res://Zero_mod/X8/Sprites/Saber/BossAbilities/ability_effects.tres")
		effect_instance.animation = "senpukyaku"
		effect_instance.global_position = effect_spawn_position
		effect_instance.z_index = animatedSprite.z_index + 2
		effect_instance.flip_h = animatedSprite.flip_h
		effect_instance.modulate = Color(1, 1, 1, 0.5)
		get_tree().current_scene.add_child(effect_instance)

func effect_position() -> void :
	var offsets = [15, 5, - 5, - 15, - 20, - 5, 5, 20, 15, 15]
	var frame = animatedSprite.frame
	var offset_x = 0
	if frame < offsets.size():
		offset_x = offsets[frame]
	effect_spawn_position = Vector2(global_position.x + offset_x * get_facing_direction(), global_position.y)

func end_saber_state() -> bool:
	if character.saber_node.current_weapon.name == "K-Knuckle":
		return true
	return animatedSprite.frame >= animatedSprite.frames.get_frame_count("rasetsusen") - 1

func should_add_saber_combo() -> bool:
	return ending_saber_state

func reset_saber_animation() -> void :
	if not character.is_on_floor():
		animatedSprite.animation = "rasetsusen"
		animatedSprite.frame = 1
		if character.saber_node.current_weapon.name == "Saber" or \
		character.saber_node.current_weapon.name == "Z-Breaker" or \
		character.saber_node.current_weapon.name == "B-Fan" or \
		character.saber_node.current_weapon.name == "D-Glaive" or \
		character.saber_node.current_weapon.name == "Rogue-Blade" or \
		character.saber_node.current_weapon.name == "Sigma-Blade" or \
		character.saber_node.current_weapon.name == "V-Hanger" or \
		character.saber_node.current_weapon.name == "T-Breaker":
			animatedSprite.frame = 0
		ending_saber_state = false

func air_charges() -> int:
	var airjump = character.get_node_or_null("AirJump")
	if airjump == null:
		return 1
	return airjump.current_air_jumps

func spend_air_charge() -> void:
	var airjump = character.get_node_or_null("AirJump")
	if airjump != null:
		airjump.reduce_air_jumps(1)

func youdantotsu_has_priority() -> bool:
	var youdantotsu = get_parent().get_node_or_null("Youdantotsu")
	if youdantotsu == null:
		return false
	if not youdantotsu.has_method("can_take_input"):
		return false
	return youdantotsu.can_take_input()

# ==== 空中起手用的上升曲线（参数见文件头部） ====

func attack_is_held() -> bool:
	if actions.size() == 0:
		return true
	return character.get_action_pressed(actions[0])

func start_air_jump_ascent() -> void:
	var airjump = character.get_node_or_null("AirJump")
	if airjump != null:
		ascend_velocity = airjump.jump_velocity
		ascend_time_max = airjump.max_jump_time
		ascend_fullspeed_proportion = airjump.fullspeed_proportion
	if ascend_time_max <= 0.0:
		ascend_time_max = 0.625
	ascend_fullspeed_time = 0.0
	ascend_slowdown_time = 0.0
	ascending = true
	character.set_vertical_speed(0)

func ascend_slowdown_value() -> float:
	var remain = ascend_time_max - ascend_fullspeed_time
	if remain <= 0.0:
		return 0.0
	var value = remain - ascend_slowdown_time / remain
	if value < 0.0:
		return 0.0
	return value

func process_air_jump_ascent(delta: float) -> void:
	if ascending:
		if not attack_is_held():
			ascending = false
		elif character.get_vertical_speed() > 0:
			ascending = false
		else:
			var value = ascend_slowdown_value()
			if value == 0.0:
				ascending = false
			elif ascend_fullspeed_time / ascend_time_max < ascend_fullspeed_proportion:
				character.set_vertical_speed( - ascend_velocity)
				ascend_fullspeed_time += delta
			else:
				character.set_vertical_speed( - ascend_velocity * value)
				ascend_slowdown_time += delta
	process_gravity(delta)

func _StartCondition() -> bool:
	if not character.Rasetsusen:
		return false
	# 悬停时"特殊攻击无方向"走的是地面上的十文字斩，空中的罗刹旋让路
	if character.is_executing("HoverZero"):
		return false
	if youdantotsu_has_priority():
		return false
	if air_charges() <= 0:
		return false
	if character.get_action_pressed("move_up"):
		return false
	if character.get_action_pressed("move_down"):
		return false
	var _animation = get_parent().get_animation()
	if _animation in character.saber_animations:
		return false
	if not executing:
		if not character.is_on_floor():
			vertical_last = character.velocity.y
			return true
	return false

func _ResetCondition() -> bool:
	return false

func _EndCondition() -> bool:
	var _animation = get_parent().get_animation()
	if not _animation == "rasetsusen":
		return true
	if not character.get_action_pressed(actions[0]):
		saber_sound.stop()
		return true
	if character.is_on_floor():
		return true
	return false

func _Setup() -> void :
	saber_sound.play()
	horizontal_velocity = 0
	horizontal_speed = 0
	character.set_horizontal_speed(0)
	character.set_vertical_speed(0)
	character.dashfall = false
	spend_air_charge()
	ascending = false
	fly_up = false
	falling_down = false
	timer = 0.0
	character.dashjumps_since_jump = 0
	cast_time = 0.0
	effect_spawn_timer = 0.0
	ending_saber_state = false

func _Update(_delta: float) -> void :
	if character.saber_node.current_weapon.name == "K-Knuckle":
		effect_emit(_delta)

	timer += _delta
	if fly_up:
		cast_time += _delta


	if not falling_down:
		if (character.get_action_pressed("move_down") and timer >= 0.2 or timer >= max_time) and not fly_up:
			falling_down = true
			timer = max_time
			character.set_vertical_speed(jump_velocity)
			if character.get_action_pressed("move_left") or character.get_action_pressed("move_right"):
				horizontal_speed = dashjump_speed
				character.dashjumps_since_jump = 1
		if character.get_action_pressed("move_up"):
			falling_down = true
			start_air_jump_ascent()
			fly_up = true
			if character.get_action_pressed("move_left") or character.get_action_pressed("move_right"):
				horizontal_speed = dashjump_speed
				character.dashjumps_since_jump = 1
		if character.saber_node.current_weapon.name == "K-Knuckle" or character.saber_node.current_weapon.name == "V-Hanger":
			if character.get_action_pressed("move_left") or character.get_action_pressed("move_right"):
				horizontal_speed = dashjump_speed
				falling_down = true
		set_movement_and_direction(0, _delta)
	else:
		horizontal_velocity = horizontal_speed
		if fly_up:
			process_air_jump_ascent(_delta)
		if character.saber_node.current_weapon.name == "K-Knuckle" and not fly_up and (timer >= max_time or character.get_action_pressed("move_down")):
			character.set_vertical_speed(jump_velocity)
		if character.saber_node.current_weapon.name == "V-Hanger" and not fly_up and (timer >= max_time or character.get_action_pressed("move_down")):
			character.set_vertical_speed(jump_velocity)
			
	force_movement(horizontal_speed)
	hitbox_and_position()
	if should_add_saber_combo():
		if character.get_action_pressed(actions[0]):
			reset_saber_animation()

func change_animation_if_falling(_s) -> void :
	animatedSprite.animation = "fall"

func _Interrupt() -> void :
	slashes = 0
	saber_sound.stop()
	animatedSprite.animation = "fall"
	animatedSprite.rotation_degrees = 0
	if is_instance_valid(current_hitbox):
		current_hitbox.queue_free()

func Initialize() -> void :
	executing = true
	timer = 0
	last_time_used = get_time()
	character.executing_moves.append(self)
	emit_signal("executed")
	play_sound_on_initialize()
	play_animation_on_initialize()

func BeforeEveryFrame(_delta: float) -> void :
	pass
