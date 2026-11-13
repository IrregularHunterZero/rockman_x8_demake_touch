extends Node

const subtle_motion: Array = [Vector2(1, 1), Vector2( - 1, - 1), Vector2(1, - 1), Vector2( - 1, 1), Vector2(0, 0)]

var active: bool = false
var frequency: float = 0.01
var duration: float = 0.01
var extra_y_position: float = -4
var extra_scale: float = 1.5
var extra_z_index: float = -4
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

export var initial_color := Color(1,1,1,0)

export var custom_omega_aura: bool = false
onready var character = get_parent().get_parent()
onready var original: AnimatedSprite = character.get_node("animatedSprite")

var upgraded: bool = false
var can_emit: bool = false

var afterimage: = AnimatedSprite.new()
var resettimer: float = 0
var max_scale: float = 1

func _ready() -> void :
	call_deferred("set_shader_colors")
	add_child(afterimage)

func set_shader_colors():
	var material = original.get_material()
	if material is ShaderMaterial:
		frequency = 0.01
		duration = 0.01
		extra_y_position = -4
		extra_scale = 1.5
		extra_z_index = -4
		if not custom_omega_aura:
			initial_color = Color("#FFFFFFFF")
		else:
			if "Axl_Boss" in character.name:
				initial_color = material.get_shader_param("R_AxlYellowColor1")
			elif "Zero_Boss" in character.name:
				initial_color = material.get_shader_param("R_AfterimagesColor")

func _process(delta):
	if can_emit:
		aura_size(delta)
		afterimage_emit()

func activate():
	if active:
		can_emit = true
		afterimage_emit()

func deactivate():
	can_emit = false
	active = false

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
	if not character.has_health() or not can_emit or original.animation == "empty" or original.animation == "messiah_flash":
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
	afterimage.z_index = original.z_index - extra_z_index
	afterimage.visible = character.visible

