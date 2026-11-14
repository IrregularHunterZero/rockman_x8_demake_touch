extends Movement
class_name HoverZero

# 白 Axl（Floppa Axl）的悬停逻辑移植到觉醒 Zero。
#
# 进入：空中按住"下"再按跳键（下+跳），会打断当前的跳跃直接进入悬停。
# 退出：松开跳键、落地、贴墙、或按冲刺。
# 资源：悬停不消耗 AirJump 的空中资源，空中冲刺也与它无关；
#       但悬停期间空中资源不恢复（DoubleJumpZero.recharge_blocking_moves 里有 "HoverZero"）。
# 限制：悬停期间 is_high_priority() 生效，任何攻击动作都派生不出来。
# 动画：awaken_beam —— 6 帧 80x160 的循环，和 Boss Zero 的 awakened_ready_loop
#       用的是同一张贴图（res://Zero_mod/X8/Player/Genmuzero/awakened_loop.png）。
# 注意：节点名不能叫 "Hover"——Character.max_out_air_abilities() 会去给名为
#       Hover 的节点写 current_air_jumps（那是 Axl 的悬停），会报 Invalid set index。

export var vertical_velocity: float = 90.0
export var hover_animation: String = "awaken_beam"
export var requires_awakened_armor: bool = true

var down_armed: bool = false


func should_execute_on_hold() -> bool:
	return true

func is_high_priority() -> bool:
	return true

func _StartCondition() -> bool:
	if requires_awakened_armor and not CharacterManager.awakened_zero_armor:
		return false
	if character.is_on_floor():
		return false
	# 唯一门槛写在这里：Ability.Should_Execute 对 should_execute_on_hold 的写法
	# 不会替我们过滤输入，所以"下 + 跳"必须自己判。
	if not character.get_action_pressed("move_down"):
		return false
	if not character.get_action_just_pressed("jump"):
		return false
	if pressing_towards_wall():
		return false
	return true

func _Setup() -> void:
	down_armed = false
	if hover_animation != "":
		character.play_animation(hover_animation)
	zero_bonus_horizontal_speed()

func _Update(_delta: float) -> void:
	zero_bonus_horizontal_speed()
	set_movement_and_direction(horizontal_velocity, _delta)
	# 起手时按住的那个"下"不算下压，否则一进悬停就往下掉；
	# 松开一次之后，"下"才开始正常下降。
	if character.get_action_pressed("move_down"):
		if down_armed:
			character.set_vertical_speed(vertical_velocity)
		else:
			character.set_vertical_speed(0)
	elif character.get_action_pressed("move_up"):
		down_armed = true
		character.set_vertical_speed( - vertical_velocity)
	else:
		down_armed = true
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
