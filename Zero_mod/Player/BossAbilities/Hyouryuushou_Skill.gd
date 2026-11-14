extends FallZero
class_name SaberHyouryuushou

onready var driftdiamond: PackedScene = preload("res://src/Actors/Player/BossWeapons/DriftDiamond/DriftDiamond.tscn")
var creator: Node2D
onready var use_genmu: Node2D = $"../Special/Genmuzero"

export  var saber_hitbox: Resource = preload("res://Zero_mod/Player/Hitboxes/Hyouryuushou_Hitbox.tscn")
var current_hitbox = null
var hitbox_upleft = Vector2(0, 0)
var hitbox_downright = Vector2(0, 0)
var hitbox_damage = 0
var hitbox_damage_boss = 0
var hitbox_damage_weakness = 0
var hitbox_break_guard_value = 0.25
var hitbox_break_guards: bool = true
var hitbox_rehit_time = 0.075

var hitbox_upgraded: bool = true
var hitbox_extra_damage = 1
var hitbox_extra_damage_boss = 1
var hitbox_extra_damage_weakness = 1
var hitbox_extra_break_guard_value = 1

var deflectable: bool = false

var hitbox_extra_scale = 1

onready var animatedSprite = character.get_node("animatedSprite")
onready var saber_sound: AudioStreamPlayer = $saber

var jumped: bool = false
var descend: bool = false

# ==== 空中起手：按二段跳（AirJump）的上升曲线来升 ====
# 参数直接读 AirJump 节点，所以普通 Zero 与觉醒 Zero 各自升到自己的二段跳高度，
# 冰龙升和罗刹旋也自动一致；地面起手仍用本技能自己的 jump_velocity。
var started_on_floor: bool = false
var ascend_velocity: float = 190.0
var ascend_time_max: float = 0.625
var ascend_fullspeed_proportion: float = 0.19
var ascend_fullspeed_time: float = 0.0
var ascend_slowdown_time: float = 0.0
var ascending: bool = false

onready var particles = $particles2D
var start_speed = 90
var horizontal_speed = start_speed
var loop_frame = 21
var loop_start_frame = 10
var end_frame = 26

func _ready():
	pass

func reset_hitbox():
	hitbox_upleft = Vector2(0, 0)
	hitbox_downright = Vector2(0, 0)
	hitbox_damage = 0
	hitbox_damage_boss = 0
	hitbox_damage_weakness = 0
	hitbox_break_guard_value = 0.25
	hitbox_break_guards = true
	hitbox_rehit_time = 0.075
	
func spawn_hitbox(_hitbox_upleft: Vector2, _hitbox_downright: Vector2):
	current_hitbox = saber_hitbox.instance()
	add_child(current_hitbox)
	var facing_direction = get_facing_direction()
	if facing_direction == - 1:
		var temp_upleft = Vector2( - _hitbox_downright.x, _hitbox_upleft.y)
		var temp_downright = Vector2( - _hitbox_upleft.x, _hitbox_downright.y)
		current_hitbox.set_hitbox_corners(temp_upleft, temp_downright)
	else:
		current_hitbox.set_hitbox_corners(_hitbox_upleft, _hitbox_downright)
		
	current_hitbox.damage = hitbox_damage * hitbox_extra_damage
	current_hitbox.damage_to_bosses = hitbox_damage_boss * hitbox_extra_damage_boss
	current_hitbox.damage_to_weakness = hitbox_damage_weakness * hitbox_extra_damage_weakness
	current_hitbox.break_guard_damage = hitbox_break_guard_value * hitbox_extra_break_guard_value
	current_hitbox.break_guards = hitbox_break_guards
	current_hitbox.saber_rehit = hitbox_rehit_time
	current_hitbox.upgraded = hitbox_upgraded
	current_hitbox.scale *= hitbox_extra_scale
	
	current_hitbox.deflectable = deflectable

func hitbox_and_position():
	if animatedSprite.animation == "hyouryuushou":
		hitbox_damage = 3
		hitbox_damage_boss = 4
		hitbox_damage_weakness = 24
		hitbox_break_guards = true
		hitbox_rehit_time = 0.075
		if animatedSprite.frame >= loop_start_frame and animatedSprite.frame < loop_frame:
			hitbox_upleft = Vector2(3, - 58)
			hitbox_downright = Vector2(40, 18)
			
			spawn_hitbox(hitbox_upleft, hitbox_downright)
			
	reset_hitbox()

func end_saber_state():
	return animatedSprite.frame >= end_frame

func movement_speed_frames():
	return animatedSprite.frame >= loop_start_frame and animatedSprite.frame < loop_frame

func jump_frame():
	if not jumped:
		if animatedSprite.frame >= loop_start_frame:
			particles.emitting = true
			particles.position = Vector2(25 * get_facing_direction(), - 3)
			particles.z_index = animatedSprite.z_index + 1
			if started_on_floor:
				character.set_vertical_speed( - jump_velocity)
			else:
				start_air_jump_ascent()
			jumped = true
			if CharacterManager.awakened_zero_armor or character.get_action_pressed("select_special"):
				if CharacterManager.awakened_zero_armor:
					create()
				else:
					if CharacterManager.extra_saber_combo and use_genmu.has_ammo_expent(CharacterManager.buster_base_energy * 0.25):
						create()
						use_genmu.reduce_ammo(CharacterManager.buster_base_energy * 0.25)

func create() -> void :
	create_driftdiamond(global_position, 520 , 2 , 0.8)
	create_driftdiamond(global_position, 520 , 1.75 , 0.7)
	create_driftdiamond(global_position, 520 , 1.5 , 0.6)
	create_driftdiamond(global_position, 520 , 1.25 , 0.5)
	create_driftdiamond(global_position, 520 , 1 , 0.4)
	create_driftdiamond(global_position, 520 , 0.75 , 0.3)
	create_driftdiamond(global_position, 520 , 0.5 , 0.2)
	create_driftdiamond(global_position, 520 , 0.25 , 0.1)

	create_driftdiamond(global_position, 520 , 0 , 0)

	create_driftdiamond(global_position, 520 , - 0.25 , 0.1)
	create_driftdiamond(global_position, 520 , - 0.5 , 0.2)
	create_driftdiamond(global_position, 520 , - 0.75 , 0.3)
	create_driftdiamond(global_position, 520 , - 1 , 0.4)

func create_driftdiamond(ground_position, speed: float, rotation_degress, rotation_speed) -> void :
	var facing_direction = get_facing_direction()
	var instance = driftdiamond.instance()
	ground_position.y += -9
	instance.rotation = rotation_degress * facing_direction
	instance.set_horizontal_speed(speed * facing_direction - facing_direction * speed * rotation_speed)
	instance.set_vertical_speed(rotation_degress * speed)
	get_tree().current_scene.get_node("Objects").call_deferred("add_child", instance, true)
	instance.set_global_position(ground_position)
	instance.set_creator(creator)
	instance.call_deferred("initialize", get_facing_direction())

func loop_animation():
	if jumped:
		if character.get_vertical_speed() < 0:
			if animatedSprite.frame >= loop_frame:
				animatedSprite.frame = loop_start_frame
		else:
			particles.emitting = false
			if not descend:
				descend = true
				animatedSprite.frame = 22

func set_saber_animations():
	animatedSprite.animation = "hyouryuushou"
	if character.is_on_floor():
		animatedSprite.frame = 0
	else:
		animatedSprite.frame = 6
	saber_sound.play()

func air_charges() -> int:
	var airjump = character.get_node_or_null("AirJump")
	if airjump == null:
		return 1
	return airjump.current_air_jumps

func spend_air_charge() -> void:
	var airjump = character.get_node_or_null("AirJump")
	if airjump != null:
		airjump.reduce_air_jumps(1)

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
	if not character.Hyouryuushou:
		return false
	if not character.is_on_floor() and air_charges() <= 0:
		return false
	if not character.get_action_pressed("move_up"):
		return false
	var _animation = get_parent().get_animation()
	if _animation in character.saber_animations:
		return false
	if not executing:
		if character.is_on_floor():
			return true
		if not character.is_on_floor():
			return true
	return false
	
func _ResetCondition() -> bool:
	return false

func _EndCondition() -> bool:
	var _animation = get_parent().get_animation()
	if _animation in character.saber_animations:
		if not _animation == "hyouryuushou":
			return true
		if end_saber_state():
			return true
	else:
		return true
	return false

func _Setup() -> void :
	started_on_floor = character.is_on_floor()
	ascending = false
	horizontal_speed = start_speed
	update_bonus_horizontal_only_conveyor()
	set_saber_animations()
	jumped = false
	descend = false
	if not character.is_on_floor():
		spend_air_charge()
	character.dashjumps_since_jump = 0

func _Update(_delta: float) -> void :
	if jumped:
		process_air_jump_ascent(_delta)
		
	jump_frame()
	loop_animation()
	hitbox_and_position()
	if movement_speed_frames():
		force_movement(horizontal_speed)
	else:
		force_movement(0)

func change_animation_if_falling(_s) -> void :
	animatedSprite.animation = "fall"




func _Interrupt():

	particles.emitting = false
	animatedSprite.animation = "fall"
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

