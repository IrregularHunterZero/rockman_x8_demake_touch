extends SimplePlayerProjectile
onready var left_tracker: Area2D = $left_tracker
onready var right_tracker: Area2D = $right_tracker
onready var all_tracker: Area2D = $all_tracker
var tracking: bool = false

var hitbox_rehit_time = 0.2

const bypass_shield: = true

var hitfirsttime_casted: bool = false

# 显形前把位置贴在发射者身上用（真月轮要等 pop_in_time 才显形，
# 那段空窗期里人物还在跑，定死出生点就等于"从背后冒出来"）。
var spawn_anchor: Node2D = null
var spawn_anchor_offset: Vector2 = Vector2.ZERO

# 出手速度只定"模量"：默认 280（原值），人物水平速度更快时取人物速度，
# 免得弹幕一出膛就落在高速移动的人物后面；上限 420 防止极速状态下
# 月亮被甩出画面。出膛后的追踪速度（track3）不参与这套换算，仍是 280。
var character_horizontal_speed: float = 0.0
const default_launch_speed: float = 280.0
const launch_speed_limit: float = 420.0

# 出生点沿朝向往前挪，和场景里的炮口节点 "Shot Position"(18, -2) 对齐。
# 原来月亮压在人物中心上，站桩看不出来，冲刺跳起来后和手炮位置明显不一致。
const muzzle_forward: float = 18.0

func get_target_from_facing_direction_first() -> Node2D:
	var first_check
	var second_check
	if get_facing_direction() > 0:
		first_check = right_tracker
		second_check = left_tracker
	else:
		first_check = left_tracker
		second_check = right_tracker

	var target = first_check.get_closest_target()
	
	
	return target

func get_target_from_facing_direction_all() -> Node2D:
	var all_check1
	var all_check2
	if get_facing_direction() > 0:
		all_check1 = all_tracker
		all_check2 = all_tracker
	else:
		all_check1 = all_tracker
		all_check2 = all_tracker

	var target = all_check1.get_closest_target()
	
	
	return target

func track():
	var target = get_target_from_facing_direction_first()
	if target:
		var dir: = Tools.get_angle_between(target, self)
		set_horizontal_speed(280 * dir.x)
		set_vertical_speed(280 * dir.y)
		if facing_direction == - 1:
			scale.x=-1
		else:
			scale.x=1
	else:
		set_horizontal_speed(280 * get_facing_direction())
		if facing_direction == - 1:
			scale.x=-1
		else:
			scale.x=1
	# 只改速度模量：默认 280，人物更快就跟上人物；方向仍是上面算出来的那条
	apply_launch_speed()
	tracking = true
	hitfirsttime_casted = false
	track2()

func track2():
	if not hitfirsttime_casted:
		yield(get_tree().create_timer(0.7), "timeout")
		set_horizontal_speed(0)
		set_vertical_speed(0)
		tracking = true
		hitfirsttime_casted = true
		track3()
	else:
		pass

func _OnHit(_target_remaining_HP) -> void :
	Tools.timer(hitbox_rehit_time, "rehit", self)
	if not hitfirsttime_casted:
		hitfirsttime_casted = true
		yield(get_tree().create_timer(0.15), "timeout")
		set_horizontal_speed(0)
		set_vertical_speed(0)
		tracking = true
		track3()
	else:
		pass

func deflect(_var) -> void :
	pass

func rehit() -> void :
	$collisionShape2D.set_deferred("disabled", true)
	yield(get_tree().create_timer(0.15), "timeout")
	$collisionShape2D.set_deferred("disabled", false)

func track3():
	yield(get_tree().create_timer(1.5), "timeout")
	var target = get_target_from_facing_direction_all()
	if target:
		var dir: = Tools.get_angle_between(target, self)
		set_horizontal_speed(280 * dir.x)
		set_vertical_speed(280 * dir.y)
		if facing_direction == - 1:
			scale.x=-1
		else:
			scale.x=1
	else:
		set_horizontal_speed(280 * get_facing_direction())
		if facing_direction == - 1:
			scale.x=-1
		else:
			scale.x=1
	tracking = true

func _Update(delta: float) -> void :
	# 先贴人再走父类：父类这一帧可能刚好把动画显形，显形位置要落在
	# 人物此刻的位置上，而不是上一帧的旧位置。
	snap_to_spawn_anchor()
	._Update(delta)
	if not tracking:
		hitfirsttime_casted = false
		track()

func set_spawn_anchor(anchor: Node2D, offset: Vector2, anchor_horizontal_speed: float = 0.0) -> void :
	spawn_anchor = anchor
	spawn_anchor_offset = offset
	character_horizontal_speed = abs(anchor_horizontal_speed)

func initialize(direction) -> void :
	.initialize(direction)
	var resolved: int = resolve_launch_direction(direction)
	if resolved != facing_direction:
		set_direction(resolved)

# 攀墙状态（统一问 Character.is_clinging_to_wall）下无视左右方向键，
# 一律朝离墙一侧出膛：贴着墙时按方向键必然是朝墙的，照朝向打就成了往墙里开火。
# 离墙以后一律用人物朝向，这里不再插手。
func resolve_launch_direction(direction: int) -> int:
	if not is_instance_valid(spawn_anchor):
		return direction
	if not spawn_anchor.has_method("is_clinging_to_wall"):
		return direction
	if not spawn_anchor.is_clinging_to_wall():
		return direction
	if spawn_anchor.has_method("is_colliding_with_wall"):
		var wall: int = spawn_anchor.is_colliding_with_wall()
		if wall != 0:
			return - wall
	return direction

func apply_launch_speed() -> void :
	var target_speed: float = clamp(character_horizontal_speed, default_launch_speed, launch_speed_limit)
	if velocity.length() < 0.001:
		return
	velocity = velocity.normalized() * target_speed

func snap_to_spawn_anchor() -> void :
	if animatedSprite.visible:
		return
	if not is_instance_valid(spawn_anchor):
		return
	if not spawn_anchor.is_inside_tree():
		return
	global_position = spawn_anchor.global_position + spawn_anchor_offset + Vector2(muzzle_forward * get_facing_direction(), 0)

func set_direction(new_direction) -> void :
	Log("Seting direction: " + str(new_direction))
	facing_direction = new_direction

func _on_area2D_body_entered(body: Node) -> void :
	if active:
		if body.is_in_group("Enemies") or body.is_in_group("Bosses"):
			return
		if body.active:
			react(body)

func react(body: Node) -> void :
	call_deferred("deflect_projectile", body)

func deflect_projectile(body):
	if body.is_in_group("Enemy Projectile"):
		if body.has_method("_OnHit"):
			body._OnHit(self)
			return
		body.destroy()
