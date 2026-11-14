extends Node2D
class_name BossAI

export  var debug_logs: bool = false
export  var active: bool = false
export  var time_between_attacks: Vector2 = Vector2(0.25, 1.5)
export  var desperation_threshold: float = 0.5
export  var play_desperation_music: bool = true
export  var order_size: int = 32
export  var desperation_chance: float = 1.0

# ==== desperation cooldown, replaces the difficulty based dice roll ====
# seconds per difficulty: rookie, normal, hard, insane (ninja handled separately)
export  var desperation_cooldowns: Array = [120.0, 60.0, 30.0, 20.0]
export  var ninja_cooldown_start: float = 20.0
export  var ninja_cooldown_min: float = 10.0
# > 0 overrides the table for this boss only
export  var desperation_cooldown_override: float = 0.0
# 0 = unlimited reuses, 1 = this boss may only ever use it once
export  var max_desperation_uses: int = 0

onready var character = get_parent()

var exceptions: Array = ["EnemyStun", "BossStun", "Intro", "Idle", "FlyIdle", "BossDeath"]
var attack_moveset: Array = []
var order_of_attacks: Array = []
var attacks_used: int = 0
var desperation_attack
var used_desperation: bool = false
var desperation_uses: int = 0
var desperation_cooldown: float = 0.0
var timer: float = 0.0
var timer_for_next_attack: float = 1.0
var label: Label
var desperation_multi: int = 5

signal activated

func _ready() -> void :
	timer = 0.0
	character.listen("intro_concluded", self, "activate_ai")
	character.listen("damage", self, "force_activation_through_damage")
	Event.listen("play_boss_music", self, "_play_boss_music")
	
	set_game_modes()
	call_deferred("update_moveset")
	if debug_logs or Configurations.get("ShowDebug"):
		var lbl = Label.new()
		add_child(lbl)
		label = lbl

func set_game_modes() -> void :
	var parent = get_parent()
	if parent != null:
		if parent.name != "SeraphLumine":
			set_hard_mode()
			set_insanity_mode()
			set_ninja_mode()
	set_rookie_mode()
	timer_for_next_attack *= CharacterManager.boss_ai_multiplier
	time_between_attacks *= Vector2(CharacterManager.boss_ai_multiplier, CharacterManager.boss_ai_multiplier)
	desperation_chance *= desperation_multi

func set_rookie_mode() -> void :
	if CharacterManager.game_mode == - 1:
		desperation_threshold = 0.25
		desperation_multi = 0

func set_hard_mode() -> void :
	if CharacterManager.game_mode == 1:
		desperation_threshold = 0.75
		desperation_multi = 1

func set_insanity_mode() -> void :
	if CharacterManager.game_mode == 2:
		desperation_threshold = 1.1
		desperation_multi = 5

func set_ninja_mode() -> void :
	if CharacterManager.game_mode >= 3:
		desperation_threshold = 1.1
		desperation_multi = 10

func decide_next_attack():
	if attack_moveset.size() == 0:
		return
	
	if can_use_desperation():
		used_desperation = true
		desperation_uses += 1
		if play_desperation_music:
			Event.emit_signal("play_angry_boss_music")
		return desperation_attack
	
	var no = get_next_attack()
	var next_attack = attack_moveset[no]
	Log("Next attack: " + str(no) + " - " + next_attack.name)
	return next_attack

func _play_boss_music() -> void :
	if CharacterManager.game_mode >= 2:
		if play_desperation_music:
			Event.emit_signal("play_angry_boss_music")

func force_activation_through_damage(_d, _i) -> void :
	Log("Received damage while waiting for start")
	activate_ai()

func activate_ai() -> void :
	Log("Activated AI")
	var attack_names: = ""
	for attack in attack_moveset:
		attack_names += attack.name + ", "
	Log("Moveset: " + attack_names.trim_suffix(", "))
	active = true
	attacks_used = 0
	emit_signal("activated")

func update_moveset() -> void :
	for child in get_parent().get_children():
		if child is AttackAbility:
			if child.active:
				if not child.desperation_attack and not is_ability_exception(child.name):
					attack_moveset.append(child)
				elif child.desperation_attack:
					desperation_attack = child
					
				child.connect("ability_end", self, "attack_ended")
				child.connect("deactivated", self, "_on_attack_deactivated", [child])
					
	decide_order_of_attacks()

func is_ability_exception(_name: String) -> bool:
	for exception in exceptions:
		if _name == exception or _name in exception:
			Log("ability " + _name + " flagged as exception, not including in attack list")
			return true
	return false

func decide_order_of_attacks() -> void :
	Log("Deciding order of attacks")
	order_of_attacks.clear()
	guarantee_all_attacks_on_start()
	randomize_remaining_attack_slots()
	validate_order_of_attacks()

func guarantee_all_attacks_on_start() -> void :
	var initial_pool = build_initial_attack_pool()
	while initial_pool.size() > 0:
		var random_attack = roll(0, initial_pool.size() - 1)
		order_of_attacks.append(initial_pool[random_attack])
		initial_pool.remove(random_attack)

func randomize_remaining_attack_slots() -> void :
	while order_of_attacks.size() < order_size:
		var next_attack_candidate = roll_attack()
		if next_attack_candidate == get_last_two_attacks_added():
			next_attack_candidate = (reroll_attack(next_attack_candidate))
		order_of_attacks.append(next_attack_candidate)

func build_initial_attack_pool() -> Array:
	var i: int = 0
	var pool: Array = []
	for attack in attack_moveset.size():
		pool.append(i)
		i += 1
	return pool

func validate_order_of_attacks() -> void:
	for value in attack_moveset.size():
		if not value in order_of_attacks:
			Log("Error: Attack " + str(value) + " not in order list")
			#return false
	print ("Attack order: " + str(order_of_attacks))
	BossRNG.decided_attack_order(character.name,order_of_attacks)

func _physics_process(delta: float) -> void :
	process_desperation_cooldown(delta)
	process_next_attack(delta)

func process_next_attack(delta: float) -> void :
	if debug_logs:
		label.text = character.get_executing_abilities_names()
	if active and has_attacks():
		if not_attacking() and timer == 0:
			timer = 0.01
		if timer > 0:
			timer += delta
		
		if not_attacking() and timer > timer_for_next_attack:
			execute_next_attack()
			timer = 0

func e(_d):
	#print(character.name + ".AI:")
	#print("Detected Idle")
	#print(timer_for_next_attack)
	#print(time_between_attacks)
	if active and has_attacks():
		Tools.timer(timer_for_next_attack,"execute_next_attack",self)
	pass
	
func execute_next_attack():
	var attack = decide_next_attack()
	attack.ExecuteOnce()


func roll(from : int, to : int) -> int:
	return BossRNG.rng.randi_range(from,to)

func roll_attack() -> int:
	return BossRNG.rng.randi_range(0,attack_moveset.size()-1)
	
func reroll_attack(attack : int) -> int:
	if attack + 1 < attack_moveset.size() -1:
		return attack + 1
	return 0

func get_last_two_attacks_added() -> int:
	if order_of_attacks.size() >= 2:
		if order_of_attacks[order_of_attacks.size()-1] == order_of_attacks[order_of_attacks.size()-2]:
			return order_of_attacks[order_of_attacks.size()-1]

	return -1


func get_next_attack() -> int:
	var next_attack
	if attacks_used > order_of_attacks.size() - 1:
		attacks_used = 0
	next_attack = attacks_used
	attacks_used += 1
	return order_of_attacks[next_attack]

func has_desperation_attack() -> bool:
	return desperation_attack != null

func has_attacks() -> bool:
	return attack_moveset.size() != 0

func not_attacking() -> bool:
	return character.is_executing("Idle")

func attack_ended(_attack) -> void :
	if _attack == desperation_attack:
		start_desperation_cooldown()
	timer = 0.01
	decide_time_for_next_attack()

func decide_time_for_next_attack() -> void :
	var max_time = (character.current_health * time_between_attacks.y) / character.max_health
	timer_for_next_attack = rand_range(time_between_attacks.x, max_time)

func _on_attack_deactivated(attack: AttackAbility) -> void :
	remove_from_attack_order(attack)

func remove_from_attack_order(attack: AttackAbility) -> void :
	if not attack.name in exceptions:
		var id = attack_moveset.find(attack)
		Log("removing " + attack.name + " from order. ID: " + str(id))
		order_of_attacks.erase(id)
		attacks_used -= 1
		Log("New order: " + str(order_of_attacks))

func can_use_desperation() -> bool:
	if not has_desperation_attack():
		return false
	if max_desperation_uses > 0 and desperation_uses >= max_desperation_uses:
		return false
	# keeps the old "once only" escape hatch (e.g. Sigma's Overdrive sets this to 0)
	if desperation_uses > 0 and desperation_chance <= 0.0:
		return false
	if character.current_health > floor(character.max_health * desperation_threshold) - 1:
		return false
	if desperation_uses == 0:
		return true
	return desperation_cooldown <= 0.0

func process_desperation_cooldown(delta: float) -> void :
	if desperation_cooldown > 0.0:
		desperation_cooldown = max(0.0, desperation_cooldown - delta)

func start_desperation_cooldown() -> void :
	desperation_cooldown = get_desperation_cooldown_duration()
	Log("Desperation cooldown: " + str(desperation_cooldown))

func get_desperation_cooldown_duration() -> float:
	if desperation_cooldown_override > 0.0:
		return desperation_cooldown_override
	if CharacterManager.game_mode >= 3:
		var health_ratio: float = clamp(float(character.current_health) / float(character.max_health), 0.0, 1.0)
		return lerp(ninja_cooldown_min, ninja_cooldown_start, health_ratio)
	var index: int = CharacterManager.game_mode + 1
	if index < 0:
		index = 0
	if index > desperation_cooldowns.size() - 1:
		index = desperation_cooldowns.size() - 1
	return float(desperation_cooldowns[index])

func Log(message) -> void :
	if debug_logs:
		print(get_parent().name + "." + name + ": " + message)
