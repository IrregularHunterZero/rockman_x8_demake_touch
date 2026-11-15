extends Actor
class_name AbilityUser

var moveset: Array = []
var executing_moves: Array = []
var last_used_ability: BaseAbility

signal ability_end(ability)


func _ready() -> void :
	update_moveset()

func _physics_process(delta: float) -> void :
	set_true_delta_animation()
	var actual_delta = delta
	if time_stop_active:
		actual_delta = GameManager.true_delta
	if active:
		if should_process_abilities():
			start_executing_moves()
			process_executing_moves(actual_delta)

func should_process_abilities() -> bool:
	return animatedSprite.visible or not has_health()

func update_moveset():
	for child in get_children():
		if should_add_to_start_moveset(child):
			moveset.append(child)
			child.connect("ability_end", self, "ability_ended")
			child.connect("ability_start", self, "ability_started")

# 招式起手的钩子，派生类（Character）用它做"攻击解除踢墙锁定"之类的事。
func ability_started(_ability) -> void:
	pass

func should_add_to_start_moveset(element) -> bool:
	if element is BaseAbility:
		if element is Ability:
			if element.actions.has("Event"):
				return false
			else:
				return true
		return false
	return false

func start_executing_moves() -> void :
	for move in moveset:
		try_execution(move)

func try_execution(move: BaseAbility, _logs: = false) -> void :
	if move.active and not move.executing:
		var can_start: bool = move._StartCondition()
		if can_start and move.Should_Execute():
			# 拒绝窗口测量（诊断，见 Character.debug_report_refusal）
			if has_method("debug_report_refusal"):
				call("debug_report_refusal", move, "started")
			move.ExecuteOnce()
		elif can_start:
			# 状态已经合法、只是这次没按：窗口到此为止
			if has_method("debug_report_refusal"):
				call("debug_report_refusal", move, "opened")
		elif has_method("debug_track_refusal"):
			call("debug_track_refusal", move)

func process_executing_moves(delta: float) -> void :
	# 副本遍历：EndAbility 会在循环里改 executing_moves，顺便把两类坏条目清掉：
	#   1) 僵尸：已经 Finalize 过（executing=false）却还留在表里；
	#   2) 重复：同一个招式节点被重复入表，会让它的 _Update 一帧跑好几次（判定成倍生成）。
	var seen: Dictionary = {}
	for move in executing_moves.duplicate():
		if not move.executing or seen.has(move):
			if character_debug_enabled():
				print("[ABILITY] dropped ", move.name, " (executing=", move.executing, ")")
			executing_moves.erase(move)
			continue
		seen[move] = true
		move.ExecuteEachFrame(delta)

func character_debug_enabled() -> bool:
	return has_method("debug_tracking_enabled") and call("debug_tracking_enabled")

func remove_from_executing_list(move: BaseAbility):
	while move in executing_moves:
		executing_moves.erase(move)
	if not move.conflicts_with_nothing():
		last_used_ability = move

func get_last_used_ability() -> String:
	if last_used_ability == null:
		return ""
	return last_used_ability.name

func get_animation() -> String:
	return animatedSprite.animation

func play_animation(anim: String, frame: = 0) -> void :
	animatedSprite.play(anim)
	animatedSprite.set_frame(frame)

func play_animation_once(anim: String) -> void :
	if not get_animation() == anim:
		animatedSprite.play(anim)
		animatedSprite.set_frame(0)

func play_animation_backwards(anim: String) -> void :
	if not get_animation() == anim:
		animatedSprite.play(anim, true)

func interrupt_all_moves():
	for move in executing_moves:
		move.EndAbility()
	animatedSprite.playing = false

func is_executing(ability: String) -> bool:
	for move in executing_moves:
		if ability == move.name:
			return true
	return false

func is_executing_either(ability_list: Array) -> bool:
	for move in executing_moves:
		for check_name in ability_list:
			if check_name == move.name:
				return true
	return false

func get_executing_abilities() -> Array:
	return executing_moves

func get_executing_abilities_names() -> String:
	var text = ""
	for each in executing_moves:
		text += each.name + ", "
	return text.trim_suffix(", ")

func get_executing_ability(ability: String) -> BaseAbility:
	for move in executing_moves:
		if ability == move.name:
			return move
	return null

func get_ability(ability: String) -> BaseAbility:
	for move in moveset:
		if ability == move.name:
			return move
	return null

func force_execute(forced_ability: String) -> void :
	for move in moveset:
		if move.name == forced_ability:
			move.ExecuteOnce()
			return

func force_end(forced_ability: String) -> void :
	for move in moveset:
		if move.name == forced_ability:
			move.EndAbility()
			return

func ability_ended(ability):
	emit_signal("ability_end", ability)
