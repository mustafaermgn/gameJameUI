extends Control

signal closed

# Audio Sliders
@onready var master_slider: HSlider = %MasterSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SfxSlider
@onready var dialogue_slider: HSlider = %DialogueSlider

# Video Controls
@onready var resolution_btn: OptionButton = %ResolutionBtn
@onready var fps_btn: OptionButton = %FpsBtn
@onready var texture_btn: OptionButton = %TextureBtn
@onready var window_mode_btn: CheckButton = %WindowModeBtn
@onready var close_button: Button = %CloseButton

const RESOLUTIONS = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440)
]

const FPS_LIMITS = [30, 60, 120, 144, 0] # 0 means unlimited

func _ready() -> void:
	_setup_resolution_options()
	_setup_fps_options()
	_setup_texture_options()
	
	# Initial state
	window_mode_btn.button_pressed = (get_window().mode == Window.MODE_FULLSCREEN)
	
	# Setup audio sliders to match current levels
	_update_sliders_from_audio()
	
	# Connect signals
	_connect_signals()

func _update_sliders_from_audio():
	master_slider.value = _get_bus_volume_linear("Master")
	music_slider.value = _get_bus_volume_linear("Music")
	sfx_slider.value = _get_bus_volume_linear("SFX")
	dialogue_slider.value = _get_bus_volume_linear("Dialogue")

func _get_bus_volume_linear(bus_name: String) -> float:
	var idx = AudioServer.get_bus_index(bus_name)
	if idx != -1:
		return db_to_linear(AudioServer.get_bus_volume_db(idx)) * 100.0
	return 70.0

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
			fps_btn.add_item("Sınırsız")
		else:
			fps_btn.add_item(str(limit) + " FPS")
	
	var current_fps = Engine.max_fps
	for i in range(FPS_LIMITS.size()):
		if FPS_LIMITS[i] == current_fps:
			fps_btn.selected = i
			break

func _setup_texture_options():
	texture_btn.clear()
	texture_btn.add_item("Düşük")
	texture_btn.add_item("Orta")
	texture_btn.add_item("Yüksek")
	texture_btn.add_item("Ultra")
	
	var current_scale = get_viewport().scaling_3d_scale
	if current_scale <= 0.5: texture_btn.selected = 0
	elif current_scale <= 0.75: texture_btn.selected = 1
	elif current_scale <= 1.0: texture_btn.selected = 2
	else: texture_btn.selected = 3

func _connect_signals():
	resolution_btn.item_selected.connect(_on_resolution_selected)
	fps_btn.item_selected.connect(_on_fps_selected)
	texture_btn.item_selected.connect(_on_texture_selected)
	window_mode_btn.toggled.connect(_on_window_mode_toggled)
	
	master_slider.value_changed.connect(_on_audio_changed.bind("Master"))
	music_slider.value_changed.connect(_on_audio_changed.bind("Music"))
	sfx_slider.value_changed.connect(_on_audio_changed.bind("SFX"))
	dialogue_slider.value_changed.connect(_on_audio_changed.bind("Dialogue"))
	
	close_button.pressed.connect(_on_close_pressed)

func _on_resolution_selected(index: int):
	var res = RESOLUTIONS[index]
	get_window().size = res
	var screen_center = Vector2(DisplayServer.screen_get_position()) + Vector2(DisplayServer.screen_get_size()) / 2.0
	get_window().position = Vector2i(screen_center - Vector2(res) / 2.0)

func _on_fps_selected(index: int):
	Engine.max_fps = FPS_LIMITS[index]

func _on_texture_selected(index: int):
	get_viewport().scaling_3d_scale = 0.5 + (index * 0.25)

func _on_window_mode_toggled(is_full: bool):
	get_window().mode = Window.MODE_FULLSCREEN if is_full else Window.MODE_WINDOWED

func _on_audio_changed(value: float, bus_name: String):
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx != -1:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value / 100.0))
		AudioServer.set_bus_mute(bus_idx, value <= 0)

func _on_close_pressed():
	closed.emit()
	hide()
