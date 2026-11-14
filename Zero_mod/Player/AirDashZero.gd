extends DashZero
class_name AirDashZero

onready var airjump = character.get_node("AirJump")
var infinite_airdashes: = false
var max_airdashes: = 1
# mirror of the shared air charge pool (AirJump.current_air_jumps), used by the debug label only
var airdash_count: = 0

onready var wall_jump: Node2D = $"../WallJump"
onready var dash_wall_jump: Node2D = $"../DashWallJump"
onready var air_jump: Node2D = $"../AirJump"
var initial_direction: = 1
var initial_sound: = true

func _ready() -> void :
	# air dash no longer keeps its own budget: it spends the same charges
	# the double jump uses, and those recharge over time
	airdash_count = shared_air_charges()

func _Setup() -> void :
	._Setup()
	character.set_vertical_speed(0)
	reduce_air_jumps(1)
	left_ground_timer = 0.0
	initial_direction = character.get_facing_direction()
	character.activate_low_walljump_raycasts()
	Event.emit_signal("airdash")
	character.airdash_signal()
	airdash_count = shared_air_charges()
	$label.text = str(airdash_count)

func shared_air_charges() -> int:
	if airjump == null:
		return max_airdashes
	return airjump.current_air_jumps

func reduce_air_jumps(amount: = 1) -> void :
	airjump.reduce_air_jumps(amount)

func reset_airdash_count() -> void :
	airjump.reset_jump_count()
	airdash_count = shared_air_charges()

func reduce_airdash_count(amount: = 1) -> void :
	airjump.reduce_air_jumps(amount)
	airdash_count = shared_air_charges()

func set_max_air_dash(value: int):
	max_airdashes = value
	airjump.set_max_air_jumps(value)
	airdash_count = value
	Log("setting max air dash:" + str(airdash_count))

func should_dash() -> bool:
	if not has_let_go_of_input:
		if not character.is_on_floor():
			if not Has_time_ran_out():
				if not facing_a_wall():
					return true
	return false
	
func change_animation_if_falling(_s) -> void :
	EndAbility()
	character.start_dashfall()

func on_dash() -> void :
	if pressed_inverse_direction():
		pass

func pressed_inverse_direction() -> bool:
	if timer > 0.1:
		if get_pressed_direction() != 0 and initial_direction != get_pressed_direction():
			Log("Inverse direction detected")
			return true
	else:
		initial_direction = get_pressed_direction()
	return false

func check_for_let_go_of_input():
	if input == 0 or pressed_inverse_direction():
		has_let_go_of_input = true

func emit_particles(_particles, _value: = false):
	pass

func _ResetCondition() -> bool:
	if has_let_go_of_input and Input.is_action_just_pressed(actions[0]):
		if character.get_vertical_speed() > 0:
			# the charge itself is paid in _Setup(), do not pay it twice here
			if infinite_airdashes:
				return true
			if shared_air_charges() > 0:
				return true
	return false

func _StartCondition() -> bool:
	var _animation = get_parent().get_animation()
	if _animation in character.saber_animations:
		return false
	if shared_air_charges() <= 0:
		return false
	if should_dash():
		if is_executing_WallJump():
			return false
		elif shared_air_charges() > 0:
			return true
	return false

func is_executing_DashAirJump() -> bool:
	return air_jump.executing and abs(air_jump.horizontal_velocity) > 90

func is_executing_WallJump() -> bool:
	if dash_wall_jump.executing and dash_wall_jump.timer < 0.2:
		return true
	elif wall_jump.executing and wall_jump.timer < 0.2:
		return true
	return false

func is_executing_DashJump() -> bool:
	return character.dashjumps_since_jump > 0

func is_able_to_airjump() -> bool:
	return airjump.active and airjump.current_air_jumps > 0

func _Interrupt():
	last_time_pressed = 0.0
	initial_sound = true
	character.remove_invulnerability(name)
	._Interrupt()

func play_sound_on_initialize() -> void :
	if initial_sound:
		.play_sound_on_initialize()

func _EndCondition() -> bool:
	var _animation = get_parent().get_animation()
	if _animation in character.saber_animations:
		return true
	if pressing_towards_wall() or character.is_on_floor():
		return true
	return false
