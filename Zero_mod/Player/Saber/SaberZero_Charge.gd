extends FallZero

export  var saber_hitbox: Resource = preload("res://Zero_mod/Player/Hitboxes/Saber_Hitbox.tscn")
onready var effect_animation = preload("res://Zero_mod/X8/Sprites/zbuster/object/object.tres")
var current_hitbox = null
var hitbox_upleft = Vector2(0, 0)
var hitbox_downright = Vector2(0, 0)
var hitbox_damage = 0
var hitbox_damage_boss = 0
var hitbox_damage_weakness = 0
var hitbox_break_guard_value = 0.4
var hitbox_break_guards: bool = false
var hitbox_rehit_time = 0.05

var hitbox_upgraded: bool = false
var hitbox_extra_damage = 1
var hitbox_extra_damage_boss = 1
var hitbox_extra_damage_weakness = 1
var hitbox_extra_break_guard_value = 1

var deflectable: bool = false
var hitbox_extra_scale = 1
onready var animatedSprite = character.get_node("animatedSprite")
onready var saber_sound = get_node("saber")
onready var dive_sound = get_node("dive")
onready var sentsuizan_land_sound = get_node("land")
onready var break_sound = get_node("break")
onready var arm_cannon = character.get_node("Shot")

var current_weapon_index: = 0
var weapons = []
var current_weapon
var _listening_to_inputs_start: bool = true
var interrupted_cutscene: bool = false
var slashing: bool = false
var slashes = 0
var landed: bool = false

var vertical_last = 0
var screenshake: bool = false
var end_state: bool = false
var is_charge_saber: bool = false

# 攀墙中放蓄力斩：站位留给 WallSlide，动作沿用贴墙攻击，这里只出刀光和判定。
# 攀墙时人物播的是 "slide"，帧号不能当蓄力斩的时间轴，
# 所以按 charge_saber_jump 的 46fps 换算出同节奏的"假帧"。
var charge_cling: bool = false
var cling_timer: float = 0.0
const charge_animation_speed: float = 46.0
# 攀墙放蓄力时沿用贴墙攻击（SaberZeroX8_Wall）那套动作，不播蓄力斩自己的跃斩
const cling_attack_animation: String = "saber_slide"

func _ready() -> void :
	if active:
		Event.listen("charged_shot_release", self, "charged_saber_release")

func saber_color() -> void:
	if arm_cannon.current_weapon.name == "CrystalBouncer" or CharacterManager.rekkyoudan_active:
		saber_rekkyoudan_on()
	else:
		saber_rekkyoudan_off()

func saber_rekkyoudan_on() -> void:
	character.saber_combo.deflectable = true
	character.saber_dash.deflectable = true
	character.saber_jump.deflectable = true
	character.saber_wall.deflectable = true
	deflectable = true
	
	character.skill_juuhazan.deflectable = true
	character.skill_rasetsusen.deflectable = true
	character.skill_raikousen.deflectable = true
	character.skill_youdantotsu.deflectable = true
	character.skill_hyouryuushou.deflectable = true
	character.skill_enkoujin.deflectable = true
	
	character.saber_combo.saber_hitbox = character.rekkyoudan_hitbox
	character.saber_dash.saber_hitbox = character.rekkyoudan_hitbox
	character.saber_jump.saber_hitbox = character.rekkyoudan_hitbox
	character.saber_wall.saber_hitbox = character.rekkyoudan_hitbox
	saber_hitbox = character.rekkyoudan_hitbox

func saber_rekkyoudan_off() -> void:
	character.saber_combo.deflectable = false
	character.saber_dash.deflectable = false
	character.saber_jump.deflectable = false
	character.saber_wall.deflectable = false
	deflectable = false
	
	character.skill_juuhazan.deflectable = false
	character.skill_rasetsusen.deflectable = false
	character.skill_raikousen.deflectable = false
	character.skill_youdantotsu.deflectable = false
	character.skill_hyouryuushou.deflectable = false
	character.skill_enkoujin.deflectable = false

	character.saber_combo.saber_hitbox = character.saber_hitbox
	character.saber_dash.saber_hitbox = character.saber_hitbox
	character.saber_jump.saber_hitbox = character.saber_hitbox
	character.saber_wall.saber_hitbox = character.saber_hitbox
	saber_hitbox = character.saber_hitbox

func hitbox_name():
	saber_color()
	if arm_cannon.current_weapon.name == "OpticShield":
		current_hitbox.name = "OpticShieldCharged"
	elif arm_cannon.current_weapon.name == "SqueezeBomb":
		current_hitbox.name = "SqueezeBombCharged"
	elif arm_cannon.current_weapon.name == "DarkArrow":
		current_hitbox.name = "DarkArrowCharged"
	elif arm_cannon.current_weapon.name == "ThunderDancer":
		current_hitbox.name = "ThunderDancerCharged"
	elif arm_cannon.current_weapon.name == "BlastLauncher":
		current_hitbox.name = "BlastLaunchCharged"
	elif arm_cannon.current_weapon.name == "CrystalBouncer":
		current_hitbox.name = "CrystalBouncerCharged"
	elif arm_cannon.current_weapon.name == "DriftDiamond":
		current_hitbox.name = "DriftDiamondCharged"
	elif arm_cannon.current_weapon.name == "FireDash":
		current_hitbox.name = "FireDashCharged"
	else:
		CharacterManager.set_saberX8_colors(animatedSprite)
		current_hitbox.name = "SaberCharged"

func reset_hitbox():
	hitbox_upleft = Vector2(0, 0)
	hitbox_downright = Vector2(0, 0)
	hitbox_damage = 0
	hitbox_damage_boss = 0
	hitbox_damage_weakness = 0
	hitbox_break_guard_value = 0.4
	hitbox_break_guards = false
	hitbox_rehit_time = 0.05
	
func spawn_hitbox(_hitbox_upleft: Vector2, _hitbox_downright: Vector2):
	if character.has_method("debug_count_event"):
		character.call("debug_count_event", "hitbox")
	current_hitbox = saber_hitbox.instance()
	add_child(current_hitbox)
	hitbox_name()
	var facing_direction = get_facing_direction()
	if facing_direction == - 1:
		var temp_upleft = Vector2( - _hitbox_downright.x, _hitbox_upleft.y)
		var temp_downright = Vector2( - _hitbox_upleft.x, _hitbox_downright.y)
		current_hitbox.set_hitbox_corners(temp_upleft, temp_downright)
	else:
		current_hitbox.set_hitbox_corners(_hitbox_upleft, _hitbox_downright)
		
	current_hitbox.damage = hitbox_damage * hitbox_extra_damage
	current_hitbox.damage_to_bosses = hitbox_damage_boss * hitbox_extra_damage_boss
	current_hitbox.damage_to_weakness = hitbox_damage_weakness * hitbox_extra_damage_weakness
	current_hitbox.break_guard_damage = hitbox_break_guard_value * hitbox_extra_break_guard_value
	current_hitbox.break_guards = hitbox_break_guards
	current_hitbox.saber_rehit = hitbox_rehit_time
	current_hitbox.upgraded = hitbox_upgraded
	current_hitbox.scale *= hitbox_extra_scale
	
	current_hitbox.deflectable = deflectable

func is_air_charge_animation() -> bool:
	return charge_cling or animatedSprite.animation == "charge_saber_jump"

func restore_cling_animation() -> void:
	# 收招时把动画还给攀墙用那份，否则会停在 saber_slide 的末帧
	if not charge_cling:
		return
	var wall_slide = character.get_node_or_null("WallSlide")
	if wall_slide != null and wall_slide.animation:
		animatedSprite.animation = wall_slide.animation
		animatedSprite.frame = 0
		animatedSprite.playing = true

# 收招后按"当前操作"重新判攀墙：还朝墙按着方向键、人也还在墙上就继续挂，
# 否则把贴墙状态结束掉，交回空中自由态（重力由 Fall 接管）。
func exit_wall_cling() -> void:
	if character.is_executing("WallSlide"):
		character.force_end("WallSlide")

func charge_frame() -> int:
	if charge_cling:
		return int(cling_timer * charge_animation_speed)
	return animatedSprite.frame

func hitbox_and_position():
	
	if animatedSprite.animation == "charge_sentsuizan":
		hitbox_damage = 12
		hitbox_damage_boss = 12
		hitbox_damage_weakness = 24
		hitbox_break_guards = true
		hitbox_rehit_time = 0.1
		if character.saber_node.current_weapon.name == "Sigma-Blade":
			if charge_frame() >= 2 and charge_frame() < 7:
				hitbox_upleft = Vector2(17, - 22)
				hitbox_downright = Vector2(125, 52)
				spawn_hitbox(hitbox_upleft, hitbox_downright)
		else:
			if charge_frame() >= 2 and charge_frame() < 7:
				hitbox_upleft = Vector2(17, - 22)
				hitbox_downright = Vector2(83, 52)
				spawn_hitbox(hitbox_upleft, hitbox_downright)
		return
	
	if character.saber_node.current_weapon.name == "D-Glaive":
		hitbox_damage = 6
		hitbox_damage_boss = 6
		hitbox_damage_weakness = 12
		hitbox_break_guards = true
		hitbox_rehit_time = 0.0125
		if is_air_charge_animation():
			if charge_frame() >= 1 and charge_frame() < 2:
				hitbox_upleft = Vector2( - 62, - 85)
				hitbox_downright = Vector2( - 32, - 55)
				spawn_hitbox(hitbox_upleft, hitbox_downright)
				hitbox_upleft = Vector2( - 97, - 85)
				hitbox_downright = Vector2( - 62, -10)
				spawn_hitbox(hitbox_upleft, hitbox_downright)
				hitbox_upleft = Vector2( - 32, - 133)
				hitbox_downright = Vector2(59, - 85)
				spawn_hitbox(hitbox_upleft, hitbox_downright)
			elif charge_frame() >= 2 and charge_frame() < 3:
				hitbox_upleft = Vector2(29, - 85)
				hitbox_downright = Vector2(59, - 55)
				spawn_hitbox(hitbox_upleft, hitbox_downright)
			elif charge_frame() >= 3 and charge_frame() < 4:
				hitbox_upleft = Vector2(59, - 85)
				hitbox_downright = Vector2(127, 10)
				spawn_hitbox(hitbox_upleft, hitbox_downright)
		if animatedSprite.animation == "charge_saber_land":
			if charge_frame() >= 1 and charge_frame() < 2:
				hitbox_upleft = Vector2( - 62, - 75)
				hitbox_downright = Vector2( - 32, - 45)
				spawn_hitbox(hitbox_upleft, hitbox_downright)
				hitbox_upleft = Vector2( - 97, - 75)
				hitbox_downright = Vector2( - 62, 0)
				spawn_hitbox(hitbox_upleft, hitbox_downright)
				hitbox_upleft = Vector2( - 32, - 123)
				hitbox_downright = Vector2(59, - 75)
				spawn_hitbox(hitbox_upleft, hitbox_downright)
			elif charge_frame() >= 2 and charge_frame() < 3:
				hitbox_upleft = Vector2(29, - 75)
				hitbox_downright = Vector2(59, - 45)
				spawn_hitbox(hitbox_upleft, hitbox_downright)
			elif charge_frame() >= 3 and charge_frame() < 4:
				hitbox_upleft = Vector2(59, - 75)
				hitbox_downright = Vector2(127, 20)
				spawn_hitbox(hitbox_upleft, hitbox_downright)

		if is_charge_saber:
			hitbox_damage = 36
			hitbox_damage_boss = 36
			hitbox_damage_weakness = 48
			hitbox_rehit_time = 0.5
			hitbox_break_guards = true
			if is_air_charge_animation():
				if charge_frame() >= 4 and charge_frame() < 12:
					hitbox_upleft = Vector2(65, - 79)
					hitbox_downright = Vector2(141, 45)
					spawn_hitbox(hitbox_upleft, hitbox_downright)
					hitbox_upleft = Vector2(65, 45)
					hitbox_downright = Vector2(141, 74)
					spawn_hitbox(hitbox_upleft, hitbox_downright)
			if animatedSprite.animation == "charge_saber_land":
				if charge_frame() >= 4 and charge_frame() < 12:
					hitbox_upleft = Vector2(65, - 79)
					hitbox_downright = Vector2(141, 45)
					spawn_hitbox(hitbox_upleft, hitbox_downright)

	elif not character.saber_node.current_weapon.name == "D-Glaive":
		hitbox_damage = 6
		hitbox_damage_boss = 6
		hitbox_damage_weakness = 12
		hitbox_rehit_time = 0.1
		hitbox_break_guards = true
		if is_air_charge_animation():
			if charge_frame() >= 3 and charge_frame() < 4:
				hitbox_upleft = Vector2( - 19, - 54)
				hitbox_downright = Vector2(45, 11)
			if charge_frame() >= 4 and charge_frame() < 6:
				hitbox_upleft = Vector2( - 13, - 57)
				hitbox_downright = Vector2(69, 37)
			if charge_frame() >= 6 and charge_frame() < 8:
				hitbox_upleft = Vector2(12, -3)
				hitbox_downright = Vector2(63, 17)
			spawn_hitbox(hitbox_upleft, hitbox_downright)
	
		if animatedSprite.animation == "charge_saber_land":
			if charge_frame() >= 3 and charge_frame() < 4:
				hitbox_upleft = Vector2( - 19, - 44)
				hitbox_downright = Vector2(45, 1)
			if charge_frame() >= 4 and charge_frame() < 6:
				hitbox_upleft = Vector2( - 13, - 47)
				hitbox_downright = Vector2(69, 27)
			if charge_frame() >= 6 and charge_frame() < 8:
				hitbox_upleft = Vector2(12, 7)
				hitbox_downright = Vector2(63, 27)
			spawn_hitbox(hitbox_upleft, hitbox_downright)
		
		if is_charge_saber:
			hitbox_damage = 36
			hitbox_damage_boss = 36
			hitbox_damage_weakness = 48
			hitbox_rehit_time = 0.5
			hitbox_break_guards = true
			if is_air_charge_animation():
				if charge_frame() >= 3 and charge_frame() < 13:
					hitbox_upleft = Vector2(-10, -29)
					hitbox_downright = Vector2(141, 37)
					spawn_hitbox(hitbox_upleft, hitbox_downright)
					hitbox_upleft = Vector2(50, -122)
					hitbox_downright = Vector2(127, -29)
					spawn_hitbox(hitbox_upleft, hitbox_downright)
					hitbox_upleft = Vector2(15, -47)
					hitbox_downright = Vector2(50, -29)
					spawn_hitbox(hitbox_upleft, hitbox_downright)
			
					hitbox_upleft = Vector2(-10, 37)
					hitbox_downright = Vector2(132, 74)
					spawn_hitbox(hitbox_upleft, hitbox_downright)
			if animatedSprite.animation == "charge_saber_land":
				if charge_frame() >= 3 and charge_frame() < 13:
					hitbox_upleft = Vector2(-10, -19)
					hitbox_downright = Vector2(141, 27)
					spawn_hitbox(hitbox_upleft, hitbox_downright)
					hitbox_upleft = Vector2(50, -112)
					hitbox_downright = Vector2(127, -19)
					spawn_hitbox(hitbox_upleft, hitbox_downright)
					hitbox_upleft = Vector2(15, -37)
					hitbox_downright = Vector2(50, -19)
					spawn_hitbox(hitbox_upleft, hitbox_downright)
		
	reset_hitbox()

func _StartCondition() -> bool:
	return false
	
func _ResetCondition() -> bool:
	return false

func _EndCondition() -> bool:
	# end_state（收招定时）优先：只要它到了就收。
	# 原来必须在 _animation in saber_animations 里才看 end_state，
	# 于是只要当前动画被别的招式改掉（walljump / fall / slide…），这条就永远 false，
	# 招式挂在执行表里不结束，玩家每放一次新蓄力斩就多挂一份，最后几十个实例同时刷刀光判定。
	if end_saber_state():
		return true
	if charge_cling:
		# 攀墙版没有蓄力动画推进，结束只看 finish() 的定时
		return false
	var _animation = get_parent().get_animation()
	if _animation in character.saber_animations:
		if not _animation == "charge_saber_land" and not _animation == "charge_saber_jump" and not _animation == "charge_sentsuizan":
			return true
	return false

var effect: AnimatedSprite
var effect_transparency: float = 0.75
onready var effect_material: Material = preload("res://Zero_mod/X8/Sprites/ZeroX8_Material_Shader.tres")
func effect_emit(_animation, new_scale: float, new_position_x: float, new_position_y: float, flip_h: bool, new_z_index: float) -> void :
	effect = AnimatedSprite.new()
	add_child(effect)
	effect.frames = effect_animation
	effect.animation = _animation
	effect.frame = animatedSprite.frame
	effect.playing = true
	effect.global_position.x = global_position.x + new_position_x * character.get_facing_direction()
	effect.global_position.y = global_position.y + new_position_y
	effect.modulate = Color(1, 1, 1, effect_transparency)
	effect.scale = animatedSprite.scale * new_scale
	effect.z_index = animatedSprite.z_index + 1 + new_z_index
	effect.centered = animatedSprite.centered
	effect.offset.x = animatedSprite.offset.x - 3
	effect.rotation_degrees = animatedSprite.rotation_degrees
	if flip_h:
		effect.flip_h = true
		effect.flip_v = animatedSprite.flip_v
	else:
		effect.flip_h = animatedSprite.flip_h
		effect.flip_v = animatedSprite.flip_v
	
	effect.material = effect_material
	CharacterManager.set_zeroX8_colors(effect)
	if CharacterManager.betazero_activated and CharacterManager.weaponget_zero:
		set_new_colors_on_shader_parameters(effect, arm_cannon.current_weapon.get_palette())

func set_new_colors_on_shader_parameters(object, new_colors) -> void :
	if arm_cannon.current_weapon.name == "OpticShield" or \
	arm_cannon.current_weapon.name == "SqueezeBomb" or \
	arm_cannon.current_weapon.name == "DarkArrow" or \
	arm_cannon.current_weapon.name == "ThunderDancer" or \
	arm_cannon.current_weapon.name == "BlastLauncher" or \
	arm_cannon.current_weapon.name == "CrystalBouncer" or \
	arm_cannon.current_weapon.name == "DriftDiamond" or \
	arm_cannon.current_weapon.name == "FireDash":
		object.material.set_shader_param("R_SaberColor1", new_colors[0])
		object.material.set_shader_param("R_SaberColor2", new_colors[1])
		object.material.set_shader_param("R_SaberColor3", new_colors[2])
		object.material.set_shader_param("R_SaberColor4", new_colors[3])
		object.material.set_shader_param("R_SaberColor5", new_colors[4])

func charged_saber_release(charge_level) -> void :
	# 上一刀还没收招时不再叠一层：叠上去 _Setup 会把 end_state 重置成 false，
	# 已经该结束的那一份永远等不到收招，执行表里越堆越多。
	if executing:
		return
	if not character.has_control():
		Log("Couldn\'t charged fire, character has no control")
		return
	# Charge 的 conflicting_moves 里带 "Nothing"，所以高优先级的悬停挡不住蓄力释放；
	# 在悬停里放出来的话动作会被悬停的动画覆盖、还会互相抢重力，这里直接不让它出。
	if character.is_executing("HoverZero"):
		Log("Couldn\'t charged fire, hovering")
		return
	if not CharacterManager.extra_saber_combo:
		return
	if character.is_executing("Intro") or \
	character.is_executing("Finish") or \
	character.is_executing("Tenshouha") or \
	character.is_executing("Juuhazan") or \
	character.is_executing("Rasetsusen") or \
	character.is_executing("Raikousen") or \
	character.is_executing("Youdantotsu") or \
	character.is_executing("Hyouryuushou") or \
	character.is_executing("Enkoujin") or \
	character.is_executing("Genmuzero") or \
	character.is_executing("Desperation") or \
	character.is_executing("Rekuhouha") or \
	character.is_executing("Ryuenjin") or \
	character.is_executing("Enkoujin_Extra"):
		return
		
	if charge_level >= 3:
		if not character.is_executing("Intro") and \
		not character.is_executing("Finish") and \
		not character.is_executing("Tenshouha") and \
		not character.is_executing("Juuhazan") and \
		not character.is_executing("Rasetsusen") and \
		not character.is_executing("Raikousen") and \
		not character.is_executing("Youdantotsu") and \
		not character.is_executing("Hyouryuushou") and \
		not character.is_executing("Enkoujin") and \
		not character.is_executing("Genmuzero") and \
		not character.is_executing("Desperation") and \
		not character.is_executing("Rekuhouha") and \
		not character.is_executing("Ryuenjin") and \
		not character.is_executing("Enkoujin_Extra"):
			if not CharacterManager.extra_saber_07:
				return
			if animatedSprite.frames.has_animation("charge_saber_land") and animatedSprite.frames.has_animation("charge_saber_jump"):
				is_charge_saber = true
				self.ExecuteOnce()
		
	elif charge_level <= 2:
		# L1~L2 松手：不再放千子斩，改成普通攻击。
		# 千子斩已改成指令输入（空中斜下+攻击），见 _physics_process / start_sentsuizan()。
		release_normal_attack()

# L1~L2 松手等于"普通攻击"：直接起对应的普通斩（空中 SaberJump / 地面 SaberCombo）。
func release_normal_attack() -> void:
	if not character.has_control():
		return
	var ability_name: String = "SaberCombo"
	if not character.is_on_floor():
		ability_name = "SaberJump"
	character.force_execute(ability_name)

# —— 千子斩的新输入：空中 + 按住下 + 方向朝人物朝向 + 攻击 ——
# 原来是"蓄力 1~2 级松手"放的，现在蓄力只负责蓄力斩（3 级），
# 下劈突进单独做成指令；开关沿用 extra_saber_06。
func _physics_process(_delta: float) -> void:
	._physics_process(_delta)
	if executing or not active:
		return
	if not character.has_control() or character.is_on_floor():
		return
	if not CharacterManager.extra_saber_06:
		return
	if not character.get_action_just_pressed("fire"):
		return
	if not character.get_action_pressed("move_down"):
		return
	var pressed: int = character.get_pressed_axis()
	if pressed == 0 or pressed != character.get_facing_direction():
		return
	start_sentsuizan()

func start_sentsuizan() -> void:
	if executing:
		return
	if character.is_executing("WallSlide") or character.is_executing("SaberWall"):
		return
	# 同帧可能已经起了普通空中斩，先收掉再放（SaberCharge 的冲突表里没有 SaberJump）
	if character.is_executing("SaberJump"):
		character.force_end("SaberJump")
	if animatedSprite.frames.has_animation("charge_saber_land") and animatedSprite.frames.has_animation("charge_sentsuizan"):
		is_charge_saber = false
		self.ExecuteOnce()

func end_saber_state():
	return end_state

func set_saber_animations():
	if charge_cling:
		# 攀墙中：沿用贴墙攻击的 "saber_slide"，只挂上收招定时
		animatedSprite.animation = cling_attack_animation
		animatedSprite.frame = 0
		animatedSprite.playing = true
		Tools.timer(0.5, "finish", self)
		saber_sound.play()
		return
	if is_charge_saber:
		Tools.timer(0.5, "finish", self)
		if character.is_on_floor():
			animatedSprite.animation = "charge_saber_land"
			animatedSprite.frame = 0
			saber_sound.play()
		else:
			animatedSprite.animation = "charge_saber_jump"
			animatedSprite.frame = 0
			saber_sound.play()
	else:
		if character.is_on_floor():
			animatedSprite.animation = "charge_saber_land"
			animatedSprite.frame = 0
			saber_sound.play()
		else:
			animatedSprite.animation = "charge_sentsuizan"
			animatedSprite.frame = 0
			saber_sound.play()

func _Setup() -> void :
	cling_timer = 0
	if character.saber_node.current_weapon.name == "D-Glaive":
		if is_charge_saber:
			if character.is_on_floor():
				effect_emit("charge_saber",1 , 90 , -22, false , 0)
				effect_emit("charge_land",1 , 131 , 8, true, 1)
				effect_emit("charge_land",1 , 49 , 8, false, 1)
			else:
				effect_emit("charge_saber_air",1 ,90 , - 32, false, 0)
	
	else:
		if is_charge_saber:
			if character.is_on_floor():
				effect_emit("charge_saber",1.5 , 64 , -42, false , 0)
				effect_emit("charge_land",1.5 ,115 , -12, true, 1)
				effect_emit("charge_land",1.5 ,4 , -12, false, 1)
			else:
				effect_emit("charge_saber_air",1.5 ,64 , - 52, false, 0)
				
	landed = false
	end_state = false
	screenshake = false
	if vertical_last != 0:
		character.velocity.y = vertical_last
	set_saber_animations()
	if character.dashjumps_since_jump > 0:
		horizontal_velocity = character.saber_jump.dashjump_speed
	else:
		horizontal_velocity = 90

func finish() -> void :
	end_state = true

func _Update(_delta: float) -> void :
	if charge_cling:
		# 攀墙中：位移和站位交给 WallSlide，这里只推进判定时间轴。
		# 打到一半松开方向键也不收招——蓄力斩必须先放完，攀墙的去留留到 _Interrupt 判。
		cling_timer += _delta
		hitbox_and_position()
		if not screenshake and charge_frame() >= 4:
			screenshake = true
			dive_sound.play()
			break_sound.play()
			Event.emit_signal("screenshake", 1000)
		# 先用攀墙的默认位移（和 WallSlide 同一套），再叠蓄力斩的特殊处理：定住不下滑
		character.apply_wall_cling_movement(true)
		return
	if character.is_executing("WallJump") or character.is_executing("DashWallJump"):
		# 踢墙期间位移和重力归 WallJump，蓄力这边只留判定：
		# 否则蓄力每帧把横速按回"朝墙 90"，人会被钉在墙上跳不出去。
		hitbox_and_position()
		return
	hitbox_and_position()

	process_gravity(_delta)
	
	if is_charge_saber:
		if animatedSprite.animation == "charge_saber_land" or animatedSprite.animation == "charge_saber_jump":
			if charge_frame() >= 4:
				if not screenshake:
					screenshake = true
					dive_sound.play()
					break_sound.play()
					Event.emit_signal("screenshake", 1000)
					
		if character.dashfall:
			set_movement_no_direction(character.saber_jump.dashjump_speed)
		else:
			set_movement_no_direction(horizontal_velocity)
					
		var animation_frame = animatedSprite.frame
		if character.is_on_floor():
			if not landed:
				animatedSprite.animation = "charge_saber_land"
				animatedSprite.frame = animation_frame
				landed = true
			set_movement_no_direction(0)
			update_bonus_horizontal_only_conveyor()
					
					
	else:
		if animatedSprite.animation == "charge_sentsuizan":
			if charge_frame() >= 5 and not landed:
				animatedSprite.frame = 3
				force_movement(character.saber_jump.dashjump_speed * 1.5)
				character.set_vertical_speed(character.saber_jump.dashjump_speed * 3)
				
			if character.is_on_floor():
				if not landed:
					Tools.timer(0.5, "finish", self)
					landed = true
					sentsuizan_land_sound.play()
					break_sound.play()
					Event.emit_signal("screenshake", 1000)
					character.set_horizontal_speed(0)
					character.set_vertical_speed(0)
		if animatedSprite.animation == "charge_saber_land":
			character.set_horizontal_speed(0)
			if not landed:
				animatedSprite.speed_scale = 0.5
				Tools.timer(0.3, "finish", self)
				landed = true
					

func change_animation_if_falling(_s) -> void :
	animatedSprite.animation = "fall"

func _Interrupt():
	slashes = 0
	animatedSprite.speed_scale = 1
	is_charge_saber = false
	if charge_cling:
		restore_cling_animation()
		if not character.is_clinging_to_wall():
			exit_wall_cling()
	charge_cling = false
	cling_timer = 0
	var _fall_node = character.get_node("Fall")
	_fall_node.horizontal_velocity = horizontal_velocity
	if character.is_on_floor():
		animatedSprite.animation = "recover"
	if is_instance_valid(current_hitbox):
		current_hitbox.queue_free()
	if is_instance_valid(effect):
		effect.queue_free()
		effect = null

func Initialize() -> void :
	# 这个类重写了 Initialize，所以要自己保证不重复入表（BaseAbility 那份去重这里拿不到）。
	# 重复入表 = 同一帧 _Update 跑 N 次 = 刀光判定 N 倍，是之前那波掉帧的源头。
	if self in character.executing_moves:
		character.executing_moves.erase(self)
	# 攀墙中放开蓄力：站位交给 WallSlide，动作沿用贴墙攻击，这里只出刀光和判定
	charge_cling = character.is_clinging_to_wall()
	executing = true
	timer = 0
	last_time_used = get_time()
	character.executing_moves.append(self)
	emit_signal("executed")
	play_sound_on_initialize()
	if not charge_cling:
		play_animation_on_initialize()

func BeforeEveryFrame(_delta: float) -> void :
	pass
	

