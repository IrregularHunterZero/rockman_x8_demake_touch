extends Movement
class_name WallSlideZero

export  var start_delay: = 0.16
export  var block_timer: = 0.0

onready var particles = character.get_node("animatedSprite").get_node("WallSlide Particles")

var horizontal_speed = 90
var wallgrab_direction: = 0

func _Setup() -> void :
	character.emit_signal("wallslide")
	character.set_direction( - get_pressed_direction())
	wallgrab_direction = get_pressed_direction()
	character.Rasetsusen_used = false
	character.Hyouryuushou_used = false
	character.dashjumps_since_jump = 0
	character.set_vertical_speed(0)

func _Update(_delta: float) -> void :
	apply_cling_movement(not delay_has_expired())
	if delay_has_expired():
		emit_particles(particles, true)

# 攀墙默认位移：水平按抓墙方向推、垂直起手后开始下滑。
# pinned = true 时定住不下滑（挂在墙上放招的招式用）。
func apply_cling_movement(pinned: bool = false) -> void :
	character.set_horizontal_speed(horizontal_speed * wallgrab_direction)
	if pinned:
		character.set_vertical_speed(0, false)
	else:
		character.set_vertical_speed(jump_velocity)

func _StartCondition() -> bool:
	var _animation = get_parent().get_animation()
	var saber_jump: bool = character.is_executing("SaberJump")
	if _animation in character.saber_animations:
		if not saber_jump:
			return false
		# 空中斩期间：前 5 帧先让刀光出来，之后允许抓墙。
		# 原来这里对 "saber_jump" 的特判被缩进到了悬停 return 后面，实际是死代码，
		# 表现就是蓄力 L1~L2 派生空中斩撞墙时一直保持斩击姿势。
		if character.animatedSprite.frame < 5:
			return false
	# 悬停期间不派生攀墙：悬停是"定在原地"，这时候去挂墙会两套位移互相抢。
	if character.is_executing("HoverZero"):
		return false
	if character.is_on_floor() or block_timer > 0:
		return false
	if character.is_colliding_with_wall() == 0:
		return false
	if get_pressed_direction() != character.is_colliding_with_wall():
		return false
	# 空中斩不收"必须在下落"的限制：上升段贴到墙也直接接攀墙。
	if saber_jump:
		return true
	return character.get_vertical_speed() > 0

func _EndCondition() -> bool:
	var _animation = get_parent().get_animation()
	if character.is_on_floor():
		Log("Floor detected")
		return true
	
	if not character.is_in_reach_for_walljump():
		Log("No wall detected")
		block_timer = 0.01
		return true
		
	if get_pressed_direction() != character.is_in_reach_for_walljump():
		Log("Not pressing towards wall")
		return true

	if get_pressed_direction() == 0:
		Log("Not pressing")
		return true
		
	return false

func _physics_process(delta: float) -> void :
	if block_timer > 0:
		block_timer += delta
		if block_timer > 0.15:
			block_timer = 0

func _Interrupt():
	if character.get_vertical_speed() > 0:
		character.set_vertical_speed(40)
	character.set_horizontal_speed(0)
	emit_particles(particles, false)

func delay_has_expired() -> bool:
	return timer > start_delay
	
func should_execute_on_hold() -> bool:
	return true
