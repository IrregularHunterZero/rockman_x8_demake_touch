extends X8OptionButton


func setup() -> void :
	set_showdebug(get_showdebug())
	display()

func increase_value() -> void :
	set_showdebug( not get_showdebug())
	display()

func decrease_value() -> void :
	set_showdebug( not get_showdebug())
	display()

func set_showdebug(value: bool) -> void :
	Configurations.set("ShowDebug", value)

func get_showdebug():
	if Configurations.get("ShowDebug"):
		return true
	return false

func display():
	if Configurations.get("ShowDebug"):
		display_value("ON_VALUE")
	else:
		display_value("OFF_VALUE")

func _on_OptionsMenu_initialize() -> void:
	var in_editor: bool = OS.has_feature("editor")
	# 编辑器里也要把这一行露出来。原来整段判断被 not OS.has_feature("editor") 门着，
	# 而场景里这一行是 visible = false，于是"在编辑器里跑"永远看不到 DEBUG_OPTION，
	# 也就永远开不了调试菜单 / 碰撞显示。
	get_parent().visible = in_editor or GameManager.debug_enabled
	if not in_editor and not GameManager.debug_enabled:
		set_showdebug(false)
	display()
