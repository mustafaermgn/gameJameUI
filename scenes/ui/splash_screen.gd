extends Control

@onready var title: Label = %Title
@onready var name_input: LineEdit = %NameInput

@onready var master_slider: HSlider = %MasterSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SfxSlider
@onready var dialogue_slider: HSlider = %DialogueSlider

@onready var resolution_btn: OptionButton = %ResolutionBtn
@onready var fps_btn: OptionButton = %FpsBtn
@onready var texture_btn: OptionButton = %TextureBtn
@onready var window_mode_btn: CheckButton = %WindowModeBtn

const RESOLUTIONS = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440)
]

const FPS_LIMITS = [30, 60, 120, 144, 0]

func _ready() -> void:
	title.pivot_offset = title.size / 2
	var tween = create_tween().set_loops()
	tween.tween_property(title, "scale", Vector2(1.1, 1.1), 0.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property(title, "scale", Vector2(1.0, 1.0), 0.6).set_trans(Tween.TRANS_SINE)

	name_input.text = Global.player_name

	_setup_resolution_options()
	_setup_fps_options()
	_setup_texture_options()

	window_mode_btn.button_pressed = (get_window().mode == Window.MODE_FULLSCREEN)

	master_slider.value = 70
	music_slider.value = 70
	sfx_slider.value = 70
	dialogue_slider.value = 70

	_connect_signals()

func _setup_resolution_options():
	resolution_btn.clear()
	for res in RESOLUTIONS:
		resolution_btn.add_item(str(res.x) + "x" + str(res.y))

	var current_res = get_window().size
	for i in range(RESOLUTIONS.size()):
		if RESOLUTIONS[i] == current_res:
			resolution_btn.selected = i
			break

func _setup_fps_options():
	fps_btn.clear()
	for limit in FPS_LIMITS:
		if limit == 0:
			fps_btn.add_item("Sinirsiz")
		else:
			fps_btn.add_item(str(limit) + " FPS")
	fps_btn.selected = 1

func _setup_texture_options():
	texture_btn.clear()
	texture_btn.add_item("Dusuk")
	texture_btn.add_item("Orta")
	texture_btn.add_item("Yuksek")
	texture_btn.add_item("Ultra")
	texture_btn.selected = 2

func _connect_signals():
	resolution_btn.item_selected.connect(_on_resolution_selected)
	fps_btn.item_selected.connect(_on_fps_selected)
	texture_btn.item_selected.connect(_on_texture_selected)
	window_mode_btn.toggled.connect(_on_window_mode_toggled)

	master_slider.value_changed.connect(_on_audio_changed.bind("Master"))
	music_slider.value_changed.connect(_on_audio_changed.bind("Music"))
	sfx_slider.value_changed.connect(_on_audio_changed.bind("SFX"))
	dialogue_slider.value_changed.connect(_on_audio_changed.bind("Dialogue"))

func _on_resolution_selected(index: int):
	var res = RESOLUTIONS[index]
	get_window().size = res
	var screen_center = Vector2(DisplayServer.screen_get_position()) + Vector2(DisplayServer.screen_get_size()) / 2.0
	get_window().position = Vector2i(screen_center - Vector2(res) / 2.0)

func _on_fps_selected(index: int):
	var limit = FPS_LIMITS[index]
	Engine.max_fps = limit

func _on_texture_selected(index: int):
	var quality_scale = 0.5 + (index * 0.25)
	get_viewport().scaling_3d_scale = quality_scale

func _on_window_mode_toggled(is_full: bool):
	if is_full:
		get_window().mode = Window.MODE_FULLSCREEN
	else:
		get_window().mode = Window.MODE_WINDOWED

func _on_audio_changed(value: float, bus_name: String):
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx != -1:
		var db = linear_to_db(value / 100.0)
		AudioServer.set_bus_volume_db(bus_idx, db)
		AudioServer.set_bus_mute(bus_idx, value <= 0)

func _on_start_button_pressed() -> void:
	if name_input.text.strip_edges() != "":
		Global.player_name = name_input.text.strip_edges()
	get_tree().change_scene_to_file("res://scenes/ui/loading_screen.tscn")

func _on_exit_button_pressed():
	get_tree().quit()
