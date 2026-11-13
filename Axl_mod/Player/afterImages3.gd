extends Node

const subtle_motion: Array = [Vector2(1, 1), Vector2( - 1, - 1), Vector2(1, - 1), Vector2( - 1, 1), Vector2(0, 0)]

export var active: bool = false
var frequency: float = 0.01
var duration: float = 0.01
var extra_y_position: float = -4
var extra_scale: float = 1
var extra_z_index: float = 1
export  var ignored_colors: Array = [
	Color(0, 0, 0), 
	Color(0, 0, 0), 
	Color(0, 0, 0), 
	Color(0, 0, 0), 
	Color(0, 0, 0), 
	Color(0, 0, 0), 
	Color(0, 0, 0), 
	Color(0, 0, 0)
]
export  var motion_amount: float = 0.0

onready var original: AnimatedSprite = $".."
onready var character = get_parent().get_parent()

var initial_color: Color = Color("#00000000")
var final_color: Color = Color("#00000000")
var upgraded: bool = false
var current_motion: = 0
var _rotator_script: Script = preload("res://System/misc/rotatordelete.gd")
var emit = false

var afterimage: = AnimatedSprite.new()
var resettimer: float = 0
var max_scale: float = 1

func _ready() -> void :
	call_deferred("set_shader_colors")
	add_child(afterimage)
	Event.listen("beamin", self, "can_emit")
	Event.listen("x_appear", self, "can_emit")
	Event.listen("gameplay_start", self, "can_emit")
	Event.listen("character_switch", self, "can_emit")
	Event.listen("character_switch_end", self, "can_emit")
	Event.listen("ridearmor_activate", self, "false_emit")
	Event.listen("ridearmor_deactivate", self, "can_emit")

func can_emit() -> void :
	if character.is_current_player:
		emit = true

func false_emit() -> void :
	emit = false

func set_shader_colors():
	var material = original.get_material()
	if material is ShaderMaterial:
		initial_color = material.get_shader_param("R_AxlAfterimagesColor1")
		final_color = material.get_shader_param("R_AxlAfterimagesColor1")

func _process(delta):
	if active:
		aura_size(delta)
		afterimage_emit()

func activate():
	active = true
	set_shader_colors()

func deactivate():
	active = false
	afterimage.visible = false

func set_afterimage_shader() -> void :
	var material = ShaderMaterial.new()
	material.shader = load("res://Zero_mod/Player/DashShader.shader")
	material.set_shader_param("display_color", initial_color)
	material.set_shader_param("ignored_color_1", ignored_colors[0])
	material.set_shader_param("ignored_color_2", ignored_colors[1])
	material.set_shader_param("ignored_color_3", ignored_colors[2])
	material.set_shader_param("ignored_color_4", ignored_colors[3])
	material.set_shader_param("ignored_color_5", ignored_colors[4])
	material.set_shader_param("ignored_color_6", ignored_colors[5])
	material.set_shader_param("ignored_color_7", ignored_colors[6])
	material.set_shader_param("ignored_color_8", ignored_colors[7])
	afterimage.material = material

func afterimage_emit() -> void :
	equate_settings()
	set_afterimage_shader()
	fade_and_delete()

func fade_and_delete() -> void :
	if not character.has_health():
		afterimage.modulate = Color(1, 1, 1, 0)
	else:
		afterimage.modulate = initial_color

func aura_size(delta) -> void :
	resettimer += delta
	max_scale += delta * 100
	if sin(max_scale) < 0:
		extra_scale = -sin(max_scale) * 0.5 + 1
	else:
		extra_scale = sin(max_scale) * 0.5 + 1
	if resettimer >= duration:
		afterimage.scale = original.scale * rand_range( 1, extra_scale)
		resettimer = 0

func equate_settings() -> void :
	afterimage.frames = original.frames
	afterimage.animation = original.animation
	afterimage.frame = original.frame
	afterimage.playing = false
	afterimage.centered = original.centered
	afterimage.offset = original.offset
	afterimage.flip_h = original.flip_h
	afterimage.flip_v = original.flip_v
	afterimage.z_index = 1
	afterimage.global_position = original.global_position + Vector2(0, extra_y_position)
	afterimage.rotation_degrees = original.rotation_degrees
	afterimage.visible = character.visible
