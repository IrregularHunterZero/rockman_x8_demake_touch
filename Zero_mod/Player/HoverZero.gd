extends Movement
class_name HoverZero

# 白 Axl（Floppa Axl）的悬停逻辑移植到觉醒 Zero。
#
# 进入：空中下落（或到顶）时按住跳键；松开跳键、落地、贴墙、或按冲刺都会结束。
# 资源：悬停不消耗 AirJump 的空中资源，空中冲刺也与它无关；
#       但悬停期间空中资源不恢复（DoubleJumpZero.recharge_blocking_moves 里有 "Hover"）。
# 限制：悬停期间 is_high_priority() 生效，任何攻击动作都派生不出来。
# 动画：awaken_beam —— 6 帧 80x160 的循环，和 Boss Zero 的 awakened_ready_loop
#       用的是同一张贴图（Res://Zero_mod/X8/Player/Genmuzero/awakened_loop.png）。

export var vertical_velocity: float = 90.0
export var hover_animation: String = "awaken_beam"
export var requires_awakened_armor: bool = true


func should_execute_on_hold() -> bool:
	return true

func is_high_priority() -> bool:
	return true

func _StartCondition() -> bool:
	if requires_awakened_armor and not CharacterManager.awakened_zero_armor:
		return false
	# 按住才悬停（_StartCondition 是唯一门槛：Ability.Should_Execute 对
	# should_execute_on_hold 的写法让按住类技能不会替我们把输入过滤掉）
	if actions.size() == 0 or not character.get_action_pressed(actions[0]):
		return false
	if character.is_on_floor():
		return false
	# 上升段留给二段跳：按住跳键时先正常起跳/二段跳，到顶开始下落才接管
	if character.get_vertical_speed() <= 0:
		return false
	if pressing_towards_wall():
		return false
	return true

func _Setup() -> void:
	if hover_animation != "":
		character.play_animation(hover_animation)
	zero_bonus_horizontal_speed()

func _Update(_delta: float) -> void:
	zero_bonus_horizontal_speed()
	set_movement_and_direction(horizontal_velocity, _delta)
	if character.get_action_pressed("move_up"):
		character.set_vertical_speed( - vertical_velocity)
	elif character.get_action_pressed("move_down"):
		character.set_vertical_speed(vertical_velocity)
	else:
		character.set_vertical_speed(0)

func _EndCondition() -> bool:
	if character.is_on_floor():
		return true
	if pressing_towards_wall():
		return true
	if actions.size() > 0 and not character.get_action_pressed(actions[0]):
		return true
	# 冲刺键按下就放手，让下一帧的空中冲刺能接上
	if character.get_action_pressed("dash"):
		return true
	return false

func _Interrupt() -> void:
	._Interrupt()
	character.set_vertical_speed(0)
	if character.is_on_floor():
		character.play_animation("idle")
	else:
		character.play_animation("fall")
