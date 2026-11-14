extends DashJumpZero
class_name DoubleJumpZero

var max_air_jumps: int = 1
var current_air_jumps: int = 0
var should_end_walljump: bool = false
var should_end_dashwalljump: bool = false

# ==== time based recharge (replaces land / wall resets) ====
export var time_based_recharge: bool = true
# 0.47s = 二段跳顶点到落地的滞空时间：
#   一段跳 320 速 / 0.19 满速比 -> 顶点 57px（上升 0.38s）
#   二段跳 190 速 / 0.30 满速比 -> 再 +41px（上升 0.37s，冻结期）
#   从 98px 顶点按 900 重力、375 终端速度落地 = 0.467s
# 即"放完二段跳，落地的同时刚好回一格"。
export var recharge_time: float = 0.47
export var refill_on_land: bool = false
# awakened Zero's "A" option (full power) removes the recharge entirely
export var no_cooldown_when_awakened: bool = true
# 空中这些招式执行期间冻结回充：它们的动画会把人悬在半空，
# 不冻结就等于"拖时间换回充"，可以无限续。
export var recharge_blocking_moves: Array = ["AirJump", "AirDash", "Rasetsusen", "Hyouryuushou", "Youdantotsu", "Raikousen", "Hover"]
var recharge_progress: float = 0.0


func _ready() -> void :
	if active:
		if refill_on_land or not time_based_recharge:
			character.listen("land", self, "reset_jump_count")
			character.listen("ride", self, "reset_jump_count")
			character.listen("wallslide", self, "reset_jump_count")
			character.listen("walljump", self, "reset_jump_count")
		character.listen("firedash", self, "reduce_air_jumps")
	recharge_progress = 0.0

func _physics_process(delta: float) -> void :
	._physics_process(delta)
	recharge(delta)

func recharge(delta: float) -> void :
	if not time_based_recharge or not active:
		return
	if is_full_power_awakened():
		current_air_jumps = max_air_jumps
		recharge_progress = 0.0
		return
	if is_recharge_blocked():
		return
	if current_air_jumps >= max_air_jumps:
		recharge_progress = 0.0
		return
	if recharge_time <= 0.0:
		current_air_jumps = max_air_jumps
		recharge_progress = 0.0
		return
	recharge_progress += delta
	while recharge_progress >= recharge_time and current_air_jumps < max_air_jumps:
		recharge_progress -= recharge_time
		current_air_jumps += 1
	if current_air_jumps >= max_air_jumps:
		recharge_progress = 0.0

func is_recharge_blocked() -> bool:
	if not active:
		return false
	if character.is_on_floor():
		return false
	for move in character.executing_moves:
		if move.name in recharge_blocking_moves:
			return true
	return false

func _Setup() -> void :
	interrupt_if_needed()
	reduce_air_jumps(1)
	if character.get_action_pressed(dash_action):
		horizontal_velocity = dashjump_speed
		character.dashjump_signal()
	else:
		character.dashjumps_since_jump = 0
		horizontal_velocity = fall_base_velocity
	._Setup()

func reset_jump_count(_dummy: = null):
	current_air_jumps = max_air_jumps
	recharge_progress = 0.0

func is_full_power_awakened() -> bool:
	return no_cooldown_when_awakened and CharacterManager.awakened_zero_armor and CharacterManager.awakened_zero_full_power_max

func reduce_air_jumps(amount: = 1):
	current_air_jumps = max(0, current_air_jumps - amount)
	
func emit_dashjump() -> void :
	pass
	
func set_max_air_jumps(value: int):
	max_air_jumps = value
	current_air_jumps = value
	recharge_progress = 0.0
	Log("setting max airjumps:" + str(current_air_jumps))

func _StartCondition() -> bool:
	var _animation = get_parent().get_animation()
	if _animation in character.saber_animations:
		return false
	if current_air_jumps <= 0:
		return false
	if character.ride_eject_delay > 0:
		return false
	if not character.is_on_floor():
		if character.time_since_on_floor > leeway_time and character.is_in_reach_for_walljump() == 0:
			var walljump = character.get_executing_ability("WallJump")
			var dashwalljump = character.get_executing_ability("DashWallJump")
			if not walljump and not dashwalljump:
				reset_interrupt_bools()
				return true
			else:
				if walljump:
					if walljump.timer > 0.25:
						should_end_walljump = true
						return true
				if dashwalljump:
					if dashwalljump.timer > 0.25:
						should_end_dashwalljump = true
						return true
	return false

func _Update(_delta: float) -> void :
	._Update(_delta)
	if character.get_animation() == "double_jump":
		if character.animatedSprite.frame >= 9:
			character.animatedSprite.animation = "jump"

func reset_interrupt_bools():
	should_end_walljump = false
	should_end_dashwalljump = false

func interrupt_if_needed():
	if should_end_walljump:
		interrupt("WallJump")
	elif should_end_dashwalljump:
		interrupt("DashWallJump")
	reset_interrupt_bools()

func interrupt(ability: String):
	Log("Ending " + ability)
	character.force_end(ability)
	
func change_animation_if_falling(_s) -> void :
	if not changed_animation:
		if character.get_animation() != "fall":
			if character.get_vertical_speed() > 0:
				EndAbility()
				if horizontal_velocity == dashjump_speed:
					character.start_dashfall()

func _EndCondition() -> bool:
	if character.is_executing("WallJump") or character.is_executing("DashWallJump"):
		return true
	return ._EndCondition()
