extends Movement
class_name HoverZero

# 白 Axl（Floppa Axl）的悬停逻辑移植到觉醒 Zero。
#
# 进入：空中按住"下"再按跳键（下+跳），会打断当前的跳跃直接进入悬停。
# 退出：松开跳键、落地、或接上空中冲刺。
#       （不再因为贴墙/按朝墙键而退出——悬停与攀墙互不派生，想挂墙先松开跳键。）
# 允许的派生：
#   - 冲刺键按下 -> 空中冲刺照常启动，悬停当场结束，之后和悬停无关。
#   - 装了手炮（Z-Buster / 节点名 Z-Breaker）时的攻击派生，悬停不中断，
#     攻击动作播完自动回到悬停循环（跳跃键没松就一直悬着）：
#       攻击                 -> 手炮普通攻击（SaberJump）
#       下 + 攻击            -> 手炮下段派生（SaberCombo 的 saber_shot_fast1/2）
#       上 + 特殊攻击        -> 冰龙升（手炮版是 Drift Diamond 弹）
#       左右 + 特殊攻击      -> 叶断突
#       特殊攻击（无方向）   -> 十文字斩的手炮版（连续炮击），不再是空中的罗刹旋
#   其余攻击仍然派生不出来（悬停是高优先级）。
# 资源：悬停不消耗 AirJump 的空中资源，空中冲刺也与它无关；
#       但悬停期间空中资源不恢复（DoubleJumpZero.recharge_blocking_moves 里有 "HoverZero"）。
# 动画：awaken_beam —— 6 帧 80x160 的循环，和 Boss Zero 的 awakened_ready_loop
#       用的是同一张贴图（res://Zero_mod/X8/Player/Genmuzero/awakened_loop.png）。
# 注意：节点名不能叫 "Hover"——Character.max_out_air_abilities() 会去给名为
#       Hover 的节点写 current_air_jumps（那是 Axl 的悬停），会报 Invalid set index。

export var vertical_velocity: float = 90.0
export var hover_animation: String = "awaken_beam"
export var requires_awakened_armor: bool = true

var down_armed: bool = false

# 能压着悬停放的派生动作。悬停对它们只做两件事：别抢动画，垂直别往下沉。
const hover_attacks: Array = ["SaberCombo", "SaberJump", "SaberDash", "SaberWall", "Juuhazan", "Youdantotsu", "Hyouryuushou"]


func should_execute_on_hold() -> bool:
	return true

func is_high_priority() -> bool:
	# 允许的派生需要在同一帧启动（框架先判"能不能启动"，再判"要不要结束"），
	# 所以按下对应按键的这段时间先让出高优先级；结束判定在 _EndCondition 里做。
	if character.get_action_pressed("dash"):
		return false
	if buster_equipped() and (character.get_action_pressed("fire") or character.get_action_pressed("alt_fire")):
		return false
	return true

func buster_equipped() -> bool:
	var shot_node = character.get_node_or_null("Shot")
	if shot_node == null:
		return false
	var weapon = shot_node.get("current_weapon")
	if weapon == null:
		return false
	return weapon.name == "Z-Breaker"

func _StartCondition() -> bool:
	if requires_awakened_armor and not CharacterManager.awakened_zero_armor:
		return false
	# 攀墙期间不派生悬停：只要还贴在墙的探测范围内就不给悬停
	# （is_colliding_with_wall 是 8px 探测，正好覆盖"挂在墙上/刚从墙上下来"）。
	# 想悬停就先离开墙，别跟攀墙抢控制。
	if character.is_colliding_with_wall() != 0:
		return false
	if character.is_executing("WallSlide"):
		return false
	if character.has_method("is_clinging_to_wall") and character.is_clinging_to_wall():
		return false
	if character.is_on_floor():
		return false
	# 唯一门槛写在这里：Ability.Should_Execute 对 should_execute_on_hold 的写法
	# 不会替我们过滤输入，所以"下 + 跳"必须自己判。
	if not character.get_action_pressed("move_down"):
		return false
	if not character.get_action_just_pressed("jump"):
		return false
	if character.get_animation() in character.saber_animations:
		return false
	return true

func stop_running_jumps() -> void:
	# 下+跳要能直接打断跳跃。悬停在某些帧会让出高优先级（按着手炮/冲刺时），
	# 那种情况下 StopAnyConflictingMoves 不会替我们结束跳跃，所以这里点名收掉。
	for ability_name in ["Jump", "DashJump", "AirJump", "WallJump", "DashWallJump"]:
		if character.is_executing(ability_name):
			character.force_end(ability_name)

func _Setup() -> void:
	stop_running_jumps()
	down_armed = false
	if hover_animation != "":
		character.play_animation(hover_animation)
	zero_bonus_horizontal_speed()

func _Update(_delta: float) -> void:
	zero_bonus_horizontal_speed()
	if attack_is_executing():
		# 派生动作的位移一律沿用攻击自己的逻辑：该原地罚站的就罚站，该前突的就前突，
		# 悬停不碰水平方向。垂直只兜住"别往下沉"，但放过动作自己的上升速度（冰龙升）。
		if character.get_vertical_speed() >= 0.0:
			character.set_vertical_speed(0)
		refresh_hover_animation()
		return
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
	refresh_hover_animation()

func attack_is_executing() -> bool:
	for move_name in hover_attacks:
		if character.is_executing(move_name):
			return true
	return false

func refresh_hover_animation() -> void:
	if hover_animation == "":
		return
	# 攻击动作还在播的时候别抢动画，播完再回到悬停循环
	# （不能只看当前动画名：saber_jump / juuhazan 本身就在 saber_animations 里）
	if attack_is_executing():
		return
	if character.get_animation() != hover_animation:
		character.play_animation(hover_animation)

func _EndCondition() -> bool:
	if character.is_on_floor():
		return true
	# 不再因为"按着朝墙键"而退出悬停：那是攀墙的入口状态，退出就会一帧后挂上去。
	# 悬停→攀墙被禁止，想挂墙就先松开跳键结束悬停。
	if actions.size() > 0 and not character.get_action_pressed(actions[0]):
		return true
	# 空中冲刺真的起来了才结束悬停；没有跳数、冲不出去时继续悬着
	if character.is_executing("AirDash"):
		return true
	return false

func _Interrupt() -> void:
	._Interrupt()
	character.set_vertical_speed(0)
	# 交给空中冲刺/攻击动作的话就别覆盖它们的动画
	if character.is_executing("AirDash") or attack_is_executing():
		return
	if character.is_on_floor():
		character.play_animation("idle")
	else:
		character.play_animation("fall")
