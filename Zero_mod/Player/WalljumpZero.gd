extends JumpZero
class_name WallJumpZero

export  var start_delay: = 0.128
export  var move_away_duration: = 0.08
export  var dash_action: = "dash"
# 起跳锁定窗口的长度。默认 = 场景里的 start_delay + move_away_duration
# （WallJump 0.116 + 0.15 ≈ 0.27s，DashWallJump ≈ 0.25s），也就是"被弹离墙"那一整段。
# 注：walljump 动画本身有 19 帧（≈0.70s），但后面那一大截是收尾姿势，
# 拿整段动画当窗口会把手感拖死。想再短/再长就设这个覆盖值。
export  var commit_time_override: float = - 1.0
var maximum_moveaway: = 0.0
var move_away_speed: = 75
var moveaway: = 0.0
var walljump_direction: = 0
var headbumped: = false
var emitted_jump_signal: = false
onready var dash_wall_jump: Node2D = $"../DashWallJump"

onready var particles = character.get_node("animatedSprite").get_node("WallJump Particle")

func emit_jump_signal():
	pass
	
func _Setup() -> void :
	._Setup()

	changed_animation = false
	character.dashjumps_since_jump = 0
	emitted_jump_signal = false
	character.emit_signal("walljump")
	walljump_direction = - wall_side_for_jump()
	# 踢墙动作播完之前不接受方向键/冲刺：否则动画还在踢墙，人已经能转身走了。
	character.start_walljump_commit(commit_time())
	# 朝向不在这里硬定：踢墙那一下已经在离墙了，朝向交还给玩家
	# （按着方向键就跟着键走，松手则保持离墙侧）。
	update_kick_facing()
	maximum_moveaway = horizontal_velocity
	moveaway = horizontal_velocity * walljump_direction
	headbumped = false
	particles.emitting = true
	character.set_horizontal_speed(0)
	character.set_vertical_speed(0)
	character.Rasetsusen_used = false
	character.Hyouryuushou_used = false
	
	character.position.x = character.position.x + 2 * walljump_direction
	character.position.y = character.position.y - 2

func _Update(delta: float) -> void :
	if not execute_dashwalljump_on_input():
		._Update(delta)
		var _animation = get_parent().get_animation()
		if _animation in character.saber_animations:
			if _animation == "saber_jump":
				if character.animatedSprite.frame >= character.animatedSprite.frames.get_frame_count("saber_jump") - 1:
					set_fall_animation()
			if _animation == "saber_jump_1" or _animation == "saber_jump_2":
				if character.animatedSprite.frame >= character.animatedSprite.frames.get_frame_count("saber_jump_1") - 1:
					set_fall_animation()

func execute_dashwalljump_on_input() -> bool:
	# 起跳锁定窗口内不给冲刺，也不做预输入（缓冲方案待定，这里先纯挡掉）。
	if character.walljump_commit_timer > 0.0:
		return false
	# 0.25 秒缓冲窗口内按冲刺 = 冲刺踢墙跳。但前提是人还真的贴着墙：
	# 原来不看贴墙，踢墙后这个窗口里想按空中冲刺也会被吞成冲刺踢墙跳。
	if timer < 0.25 and Input.is_action_just_pressed(dash_action):
		if character.is_colliding_with_wall() == 0:
			return false
		dash_wall_jump.override_timer = timer
		dash_wall_jump.start_right_away()
		return true
	return false

# 踢墙动作（离墙推进）持续多久，就锁多久。
func commit_time() -> float:
	if commit_time_override > 0.0:
		return commit_time_override
	return start_delay + move_away_duration
	
func _StartCondition() -> bool:
	var _animation = get_parent().get_animation()
	if _animation in character.saber_animations:
		if _animation == "saber_slide":
			if character.animatedSprite.frame >= 4:
				return true
		if not "saber_jump" in _animation:
			return false
		if "saber_jump" in _animation:
			if character.animatedSprite.frame < 5:
				return false
		return false
	if character.is_on_floor():
		return false
	# 必须真的贴着墙才允许踢墙。原来只看 is_in_reach_for_walljump()（长射线），
	# 踢墙后那 2px 的间隙里还能再"凭空"踢一次，表现出来就是对着空气左右横跳。
	if character.is_colliding_with_wall() != 0:
		if not character.get_action_pressed(dash_action):
			return true
	return false

func _ResetCondition() -> bool:
	var _animation = get_parent().get_animation()
	if _animation in character.saber_animations:
		if _animation == "saber_slide":
			return true
		if not "saber_jump" in _animation:
			return false
		if "saber_jump" in _animation:
			if character.animatedSprite.frame < 5:
				return false
		return false
	# 重新起跳同样要求真的贴着墙（长射线判定会让人在空中就近再"踢"一次）
	if character.is_colliding_with_wall() != 0:
		if has_released_input_and_is_pressing_again():
			return true
	return false

func has_released_input_and_is_pressing_again() -> bool:
	return has_let_go_of_input and input > 0

func _EndCondition() -> bool:
	if timer > 0.05 + start_delay:
		# 下落且墙还在判定范围内就收招，好让 WallSlide 重新抓墙。
		# 不用 facing_a_wall()：它跟朝向绑，按着朝墙键时会被立刻触发、提前收掉踢墙。
		if character.get_vertical_speed() > 0 and character.is_in_reach_for_walljump() != 0:
			return true
	var _animation = get_parent().get_animation()
	if _animation in character.saber_animations:
		if "saber_jump" in _animation:
			return false
		if "saber_ensuizan" in _animation:
			return false
		if "charge_saber_jump" in _animation:
			return false
		return true
	return ._EndCondition()

func change_animation_if_falling(_s) -> void :
	if character.is_executing("SaberJump") or character.is_executing("KnuckleJump"):
		return
	.change_animation_if_falling(_s)

func if_no_input_zero_vertical_speed() -> void :
	if timer > move_away_duration:
		.if_no_input_zero_vertical_speed()

func set_movement_and_direction(horizontal_speed: float, _delta: = 0.016) -> void :
	if delay_has_expired():
		if delay_and_move_away_duration_have_expired():
			.set_movement_and_direction(horizontal_speed)
		else:
			move_away_from_wall(_delta)
	# 放在位移之后：基类会用"按了哪个键"重写 direction（没按键就写 0），
	# 而 0 会被 update_facing_direction 当成"朝右"，踢墙动画就会白白镜像一帧。
	update_kick_facing()

# 起跳锁定期间：朝向固定为"被踢的那面墙"。
# 原因：walljump 这套动作画的是"朝墙蹬"，所以要面朝墙；而攀墙时 WallSlide._Setup 把朝向
# 设成了 -按方向键 = 背对墙，直接沿用就会变成"朝身后踢空气"，看起来像踢空气墙。
# 锁定结束后交还输入：按方向键跟键走，不按就保持当前朝向。
# 写回 ±1 而不是留 0：update_facing_direction 里 direction.x == 0 等价于朝右。
func update_kick_facing() -> void :
	if character.walljump_commit_timer > 0.0:
		if walljump_direction != 0:
			character.force_facing( - walljump_direction)
		return
	var pressed: int = get_pressed_direction()
	if pressed != 0:
		character.set_direction(pressed, true)
	else:
		character.set_direction(character.get_facing_direction(), true)

# 踢哪边由"实际贴着的墙"定：连打踢墙时跳跃射线偶尔会读到对侧，
# 一读反 walljump_direction 就会反向（表现为贴着空气墙反向起跳）。
func wall_side_for_jump() -> int:
	var reach_side: int = character.is_in_reach_for_walljump()
	var touching_side: int = character.is_colliding_with_wall()
	if touching_side != 0 and reach_side != touching_side:
		return touching_side
	return reach_side

func ascent_with_slowdown_after_delay(_delta: float) -> void :
	if delay_has_expired():
		if not emitted_jump_signal:
			character.emit_signal("jump")
			emitted_jump_signal = true
		.ascent_with_slowdown_after_delay(_delta)

func process_gravity(_delta: float, gravity: = default_gravity, _s = "null") -> void :
	if delay_has_expired():
		.process_gravity(_delta, gravity)

func move_away_from_wall(_delta: float):
	# 位移只由 walljump_direction 决定，不再用 -get_facing_direction() 反推：
	# 朝向现在跟着玩家走（可能还按着朝墙键），拿它算位移会把人生往墙上推。
	character.set_horizontal_speed(move_away_speed * walljump_direction)

func pressing_towards_wall() -> bool:
	return get_pressed_direction() != 0 and get_pressed_direction() != walljump_direction

func calculate_reducing_move_away_speed(_delta: float) -> float:
	return moveaway - (horizontal_velocity) * _delta * walljump_direction

func move_away_speed_down_to_zero():
	return walljump_direction == 1 and moveaway < 0 or walljump_direction == - 1 and moveaway > 0

func delay_and_move_away_duration_have_expired() -> bool:
	return timer > start_delay + move_away_duration or headbumped

func delay_has_expired() -> bool:
	return timer > start_delay

func on_headbump() -> void :
	if executing:
		character.set_vertical_speed(0)
		stopped_input = true
		headbumped = true
