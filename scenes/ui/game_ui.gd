extends CanvasLayer

@onready var coin_label: Label = %CoinLabel
@onready var settings_popup: Control = %SettingsPopup
@onready var debug_spawn_btn: Button = %DebugSpawnBtn
@onready var debug_money_btn: Button = %DebugMoneyBtn
@onready var settings_menu: Control = %SettingsMenu
@onready var alarm_overlay: ColorRect = %AlarmOverlay if has_node("%AlarmOverlay") else $Control/AlarmOverlay
@onready var alarm_timer: Timer = $AlarmTimer

@onready var upgrade_subs: Control = %UpgradeSubs
@onready var build1_subs: Control = %Build1Subs
@onready var build2_subs: Control = %Build2Subs

var active_tweens: Dictionary = {}
var _pipe_system: Node = null
var _pipe_placement: Node = null
var _sub_bg: Dictionary = {}
var _win_overlay: Control = null
var _lose_overlay: Control = null

const ITEM_COSTS: Dictionary = {
	"HIZLI SU": 100,
	"KOSMA": 200,
	"ARITICI": 80,
	"TUZDAN ARIT.": 100,
	"Turret": 150,
	"BOMBA": 200,
	"DRON": 250,
}


func setup_pipe_system(pipe_system: Node) -> void:
	_pipe_system = pipe_system
	_pipe_system.score_changed.connect(_on_pipe_score_changed)
	_on_pipe_score_changed(_pipe_system.score)

func setup_pipe_placement(placement: Node) -> void:
	_pipe_placement = placement

func show_win_screen() -> void:
	if _win_overlay:
		_win_overlay.show()
	get_tree().paused = true

func _ready() -> void:
	Global.coin_changed.connect(_on_coin_changed)
	
	_on_coin_changed(Global.coins)
	
	settings_popup.hide()
	alarm_overlay.hide()
	
	_setup_button_effects(self)
	
	%RunSpeed.pressed.connect(_on_speed_upgrade_pressed)
	
	_connect_build_buttons(build1_subs, ["ARITICI", "TUZDAN ARIT.", "Turret"])

	_connect_build_buttons(build2_subs, ["BOMBA", "DRON"])

	%Settings.pressed.connect(_on_settings_button_pressed)
	settings_menu.closed.connect(_on_settings_menu_closed)

	_setup_win_overlay()

func _connect_build_buttons(container: Control, item_names: Array) -> void:
	var children = container.get_children()
	for i in range(children.size()):
		var btn = children[i]
		if btn is Button and i < item_names.size():
			var item_name: String = item_names[i]
			btn.pressed.connect(_on_build_item_pressed.bind(item_name))

func _on_build_item_pressed(item_name: String) -> void:
	if not _pipe_placement:
		return
	var cost: int = ITEM_COSTS.get(item_name, 0)
	_pipe_placement._on_market_item_purchased(item_name, cost)
	_close_all()

func _close_all() -> void:
	if upgrade_subs.visible:
		_animate_oval(upgrade_subs)
	if build1_subs.visible:
		_animate_oval(build1_subs)
	if build2_subs.visible:
		_animate_oval(build2_subs)

func _on_coin_changed(amount: int) -> void:
	if amount < 50:
		if alarm_timer.is_stopped():
			alarm_timer.start()
			alarm_overlay.show()
	else:
		alarm_timer.stop()
		alarm_overlay.hide()

func _on_pipe_score_changed(new_score: float) -> void:
	coin_label.text = "🪙 " + str(int(new_score))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_F1 and event.pressed:
		debug_spawn_btn.visible = not debug_spawn_btn.visible
		debug_money_btn.visible = debug_spawn_btn.visible
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed):
		if settings_popup.visible:
			_on_resume_pressed()
		else:
			_on_settings_toggle()

func _on_settings_toggle() -> void:
	settings_popup.show()
	get_tree().paused = true

func _on_resume_pressed() -> void:
	settings_popup.hide()
	settings_menu.hide()
	get_tree().paused = false

func _on_settings_button_pressed() -> void:
	settings_menu.show()

func _on_settings_menu_closed() -> void:
	settings_menu.hide()

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/splash_screen.tscn")

func _on_exit_pressed() -> void:
	get_tree().quit()

func _on_upgrade_toggle() -> void:
	if !upgrade_subs.visible:
		_close_all_except(upgrade_subs)
	_animate_oval(upgrade_subs)

func _on_build1_toggle() -> void:
	if !build1_subs.visible:
		_close_all_except(build1_subs)
	_animate_oval(build1_subs)

func _on_build2_toggle() -> void:
	if !build2_subs.visible:
		_close_all_except(build2_subs)
	_animate_oval(build2_subs)

func _close_all_except(target: Control):
	if upgrade_subs.visible and upgrade_subs != target:
		_animate_oval(upgrade_subs)
	if build1_subs.visible and build1_subs != target:
		_animate_oval(build1_subs)
	if build2_subs.visible and build2_subs != target:
		_animate_oval(build2_subs)

func _get_or_create_bg(container: Control) -> ColorRect:
	if _sub_bg.has(container):
		return _sub_bg[container]
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.z_index = -1
	bg.visible = false
	container.add_child(bg)
	container.move_child(bg, 0)
	_sub_bg[container] = bg
	return bg

func _get_main_button_center(container: Control) -> float:
	var parent_vbox = container.get_parent()
	if parent_vbox:
		var main_btn = parent_vbox.get_node_or_null("MainButton")
		if main_btn:
			return main_btn.size.x / 2.0
	return 0.0

func _animate_oval(container: Control):
	var is_opening = !container.visible
	
	if active_tweens.has(container):
		active_tweens[container].kill()
	
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	active_tweens[container] = tween
	
	var buttons = container.get_children()
	var bg = _get_or_create_bg(container)
	var sub_buttons = []
	for c in buttons:
		if c != bg:
			sub_buttons.append(c)
	var count = sub_buttons.size()
	
	var center_x = _get_main_button_center(container)
	
	if is_opening:
		container.show()
		for btn in sub_buttons:
			btn.position = Vector2(center_x, 0)
			btn.modulate.a = 0.0
			btn.scale = Vector2.ZERO
		
		var y_offset = -180.0
		var spacing = 120.0
		var start_x = center_x - (count - 1) * spacing / 2.0
		
		for i in range(count):
			var target_pos = Vector2(start_x + i * spacing, y_offset)
			
			tween.tween_property(sub_buttons[i], "position", target_pos, 0.4).set_delay(i * 0.05)
			tween.tween_property(sub_buttons[i], "modulate:a", 1.0, 0.3).set_delay(i * 0.05)
			tween.tween_property(sub_buttons[i], "scale", Vector2.ONE, 0.4).set_delay(i * 0.05)
		
		bg.position = Vector2(start_x - 10, y_offset - 10)
		bg.size = Vector2((count - 1) * spacing + 120, 100)
		bg.modulate.a = 0.0
		bg.visible = true
		tween.tween_property(bg, "modulate:a", 1.0, 0.3)
	else:
		for i in range(count):
			tween.tween_property(sub_buttons[i], "position", Vector2(center_x, 0), 0.3).set_delay((count - 1 - i) * 0.05)
			tween.tween_property(sub_buttons[i], "modulate:a", 0.0, 0.2).set_delay((count - 1 - i) * 0.05)
			tween.tween_property(sub_buttons[i], "scale", Vector2.ZERO, 0.3).set_delay((count - 1 - i) * 0.05)
		
		tween.tween_property(bg, "modulate:a", 0.0, 0.2)
		tween.set_parallel(false)
		tween.tween_callback(func():
			bg.visible = false
			container.hide()
		)

func _setup_button_effects(node: Node):
	for child in node.get_children():
		if child is Button:
			child.pressed.connect(func(): _play_click_sound())
			child.button_down.connect(func(): _animate_button_scale(child, 0.9))
			child.button_up.connect(func(): _animate_button_scale(child, 1.0))
		_setup_button_effects(child)

func _play_click_sound():
	$AudioStreamPlayer.play()

func _animate_button_scale(btn: Button, target_scale: float):
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", Vector2(target_scale, target_scale), 0.1)

func _on_speed_upgrade_pressed():
	if Global.coins >= 200:
		Global.add_coins(-200)
		var player = get_tree().get_first_node_in_group("player")
		if player:
			player.speed += 2.0

func _on_alarm_timer_timeout() -> void:
	alarm_overlay.visible = !alarm_overlay.visible
	if alarm_overlay.visible:
		$AudioStreamPlayer.play()

func _on_debug_spawn_enemy() -> void:
	var enemy_scene := load("res://scenes/props/enemy.tscn") as PackedScene
	if not enemy_scene:
		return
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if not player:
		return
	var enemy := enemy_scene.instantiate()
	var forward := -player.global_basis.z.normalized()
	enemy.global_position = player.global_position + forward * 5.0 + Vector3(0, 0.6, 0)
	get_tree().current_scene.add_child(enemy)
	enemy.setup(player)

func _on_debug_give_money() -> void:
	if _pipe_system:
		_pipe_system.score += 10000
		_pipe_system.score_changed.emit(_pipe_system.score)
	Global.add_coins(10000)

func _setup_win_overlay() -> void:
	_win_overlay = Control.new()
	_win_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_win_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_win_overlay.visible = false
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.3, 0.1, 0.7)
	_win_overlay.add_child(bg)
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_left = -200.0
	vbox.offset_top = -100.0
	vbox.offset_right = 200.0
	vbox.offset_bottom = 100.0
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_win_overlay.add_child(vbox)
	var title := Label.new()
	title.text = "YOU WIN!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
	_win_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_child(title)
	var btn := Button.new()
	btn.text = "PLAY AGAIN"
	btn.custom_minimum_size = Vector2(200, 60)
	btn.pressed.connect(_on_play_again)
	vbox.add_child(btn)
	$Control.add_child(_win_overlay)
	_setup_lose_overlay()

func show_game_over() -> void:
	if _lose_overlay:
		_lose_overlay.show()
	get_tree().paused = true

func _setup_lose_overlay() -> void:
	_lose_overlay = Control.new()
	_lose_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lose_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_lose_overlay.visible = false
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.3, 0.0, 0.0, 0.7)
	_lose_overlay.add_child(bg)
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_left = -200.0
	vbox.offset_top = -100.0
	vbox.offset_right = 200.0
	vbox.offset_bottom = 100.0
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_lose_overlay.add_child(vbox)
	var title := Label.new()
	title.text = "GAME OVER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	vbox.add_child(title)
	var btn := Button.new()
	btn.text = "TRY AGAIN"
	btn.custom_minimum_size = Vector2(200, 60)
	btn.pressed.connect(_on_play_again)
	vbox.add_child(btn)
	$Control.add_child(_lose_overlay)

func _on_play_again() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/splash_screen.tscn")
