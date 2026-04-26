extends CanvasLayer

var _selection_label: Label
var _container_bars: Array = []
var _pipe_system: Node = null
var _world_gen: Node = null
var _placement: Node = null
var _minimap: Control = null
var _cursor_preview: Control = null
var _game_ui: CanvasLayer = null
var _green_spread: Node = null
var _green_bar: ProgressBar = null
var _green_pct: Label = null
var _health_bar: ProgressBar = null
var _health_label: Label = null
var _hurt_flash: ColorRect = null
var _font_future: Font = null

func setup(pipe_system: Node, world_gen: Node, placement: Node, player: CharacterBody3D = null) -> void:
	_pipe_system = pipe_system
	_world_gen = world_gen
	_placement = placement
	if _minimap and player:
		_minimap.setup(world_gen, pipe_system, player)
	if _cursor_preview and placement:
		_cursor_preview.setup(placement, placement._radial_menu)
	_setup_game_ui()
	if player:
		_setup_player_health(player)
		player.player_hurt.connect(_on_player_hurt)

func setup_green_spread(gs: Node) -> void:
	_green_spread = gs
	_green_spread.spread_progress.connect(_on_spread_progress)
	if _minimap and _minimap.has_method("setup_green_spread"):
		_minimap.setup_green_spread(gs)

func _ready() -> void:
	_font_future = load("res://UInesneleri/Font/Kenney Future.ttf")
	
	_selection_label = Label.new()
	if _font_future: _selection_label.add_theme_font_override("font", _font_future)
	_selection_label.add_theme_font_size_override("font_size", 16)
	_selection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_selection_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_selection_label.offset_left = -120
	_selection_label.offset_top = -40
	_selection_label.offset_right = 120
	_selection_label.offset_bottom = -10
	add_child(_selection_label)
	_setup_container_panel()
	_setup_minimap()
	_setup_cursor_preview()

func _setup_game_ui() -> void:
	if _game_ui:
		return
	var game_ui_scene := load("res://scenes/ui/game_ui.tscn") as PackedScene
	if not game_ui_scene:
		return
	_game_ui = game_ui_scene.instantiate()
	add_child(_game_ui)
	_game_ui.setup_pipe_system(_pipe_system)
	_game_ui.setup_pipe_placement(_placement)

func _setup_container_panel() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left = 20
	panel.offset_top = -260
	panel.offset_right = 320
	panel.offset_bottom = -20
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.1, 0.9) # Deep deep blue
	style.set_corner_radius_all(20)
	style.set_border_width_all(6)
	style.border_color = Color(1, 1, 1, 1.0) # Thick white border
	style.set_shadow_size(12)
	style.shadow_color = Color(0, 0, 0, 0.6)
	panel.add_theme_stylebox_override("panel", style)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	panel.add_child(margin)
	
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	margin.add_child(vb)
	
	var title := Label.new()
	title.text = "CORE TELEMETRY"
	if _font_future: title.add_theme_font_override("font", _font_future)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2)) # Golden
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 5)
	vb.add_child(title)
	
	var bar_bg_style := StyleBoxFlat.new()
	bar_bg_style.bg_color = Color(0, 0, 0, 0.7)
	bar_bg_style.set_corner_radius_all(8)
	bar_bg_style.set_border_width_all(2)
	bar_bg_style.border_color = Color(0.3, 0.3, 0.4, 1)
	
	for i in range(2):
		var unit_vb := VBoxContainer.new()
		unit_vb.add_theme_constant_override("separation", 4)
		
		var hlbl := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = "STORAGE TANK 0" + str(i + 1)
		if _font_future: lbl.add_theme_font_override("font", _font_future)
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
		hlbl.add_child(lbl)
		
		hlbl.add_spacer(false)
		
		var pct := Label.new()
		pct.text = "0%"
		if _font_future: pct.add_theme_font_override("font", _font_future)
		pct.add_theme_font_size_override("font_size", 11)
		pct.add_theme_color_override("font_color", Color.WHITE)
		hlbl.add_child(pct)
		unit_vb.add_child(hlbl)
		
		var bar := ProgressBar.new()
		bar.max_value = 100.0
		bar.custom_minimum_size.y = 22
		bar.show_percentage = false
		
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color(0.1, 0.7, 1.0) # Vibrant Electric Blue
		fill.set_corner_radius_all(6)
		fill.set_border_width(SIDE_BOTTOM, 4)
		fill.border_color = Color(0.05, 0.3, 0.5, 0.8) # Depth
		fill.set_border_width(SIDE_TOP, 2)
		fill.border_color = Color(1, 1, 1, 0.3) # Glossy Top
		
		bar.add_theme_stylebox_override("background", bar_bg_style)
		bar.add_theme_stylebox_override("fill", fill)
		unit_vb.add_child(bar)
		vb.add_child(unit_vb)
		_container_bars.append({"bar": bar, "pct": pct})
		
	var sep := ColorRect.new()
	sep.custom_minimum_size.y = 4
	sep.color = Color(1, 1, 1, 0.1)
	vb.add_child(sep)
	
	var green_vb := VBoxContainer.new()
	green_vb.add_theme_constant_override("separation", 6)
	
	var gtitle_hb := HBoxContainer.new()
	var gtitle := Label.new()
	gtitle.text = "TERRAFORMING"
	if _font_future: gtitle.add_theme_font_override("font", _font_future)
	gtitle.add_theme_font_size_override("font_size", 16)
	gtitle.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	gtitle.add_theme_color_override("font_outline_color", Color.BLACK)
	gtitle.add_theme_constant_override("outline_size", 5)
	gtitle_hb.add_child(gtitle)
	
	gtitle_hb.add_spacer(false)
	
	var gpct := Label.new()
	gpct.text = "0%"
	if _font_future: gpct.add_theme_font_override("font", _font_future)
	gpct.add_theme_font_size_override("font_size", 13)
	gtitle_hb.add_child(gpct)
	green_vb.add_child(gtitle_hb)
	
	var gbar := ProgressBar.new()
	gbar.max_value = 100.0
	gbar.custom_minimum_size.y = 26
	gbar.show_percentage = false
	
	var gfill := StyleBoxFlat.new()
	gfill.bg_color = Color(0.2, 0.9, 0.2) # Vibrant Neon Green
	gfill.set_corner_radius_all(8)
	gfill.set_border_width(SIDE_BOTTOM, 5)
	gfill.border_color = Color(0.1, 0.4, 0.1, 0.8)
	gfill.set_border_width(SIDE_TOP, 2)
	gfill.border_color = Color(1, 1, 1, 0.3) # Glossy Top
	
	gbar.add_theme_stylebox_override("background", bar_bg_style)
	gbar.add_theme_stylebox_override("fill", gfill)
	green_vb.add_child(gbar)
	vb.add_child(green_vb)
	
	_green_bar = gbar
	_green_pct = gpct
	add_child(panel)

func _setup_player_health(player: Node) -> void:
	var container := PanelContainer.new()
	container.custom_minimum_size = Vector2(260, 50)
	
	var style_empty := StyleBoxEmpty.new()
	container.add_theme_stylebox_override("panel", style_empty)
	
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	container.add_child(hbox)
	
	# Heart Icon Circle
	var heart_circle := Panel.new()
	heart_circle.custom_minimum_size = Vector2(46, 46)
	var circle_style := StyleBoxFlat.new()
	circle_style.bg_color = Color(0.85, 0.15, 0.15)
	circle_style.set_corner_radius_all(23)
	circle_style.set_border_width_all(4)
	circle_style.border_color = Color(1, 1, 1, 0.9)
	circle_style.set_shadow_size(4)
	circle_style.shadow_color = Color(0, 0, 0, 0.3)
	heart_circle.add_theme_stylebox_override("panel", circle_style)
	
	var heart_lbl := Label.new()
	heart_lbl.text = "❤"
	heart_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	heart_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heart_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heart_lbl.add_theme_font_size_override("font_size", 24)
	heart_lbl.add_theme_color_override("font_outline_color", Color(0.4, 0, 0))
	heart_lbl.add_theme_constant_override("outline_size", 4)
	heart_circle.add_child(heart_lbl)
	hbox.add_child(heart_circle)
	
	# Progress Bar
	_health_bar = ProgressBar.new()
	_health_bar.custom_minimum_size = Vector2(180, 28)
	_health_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_health_bar.max_value = player.get("MAX_HP")
	_health_bar.value = player.get("hp")
	_health_bar.show_percentage = false
	
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	bg_style.set_corner_radius_all(8)
	bg_style.set_border_width_all(3)
	bg_style.border_color = Color(0, 0, 0, 1)
	bg_style.expand_margin_left = 2
	bg_style.expand_margin_right = 2
	bg_style.expand_margin_top = 2
	bg_style.expand_margin_bottom = 2
	
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.35, 0.85, 0.35)
	fill_style.set_corner_radius_all(5)
	fill_style.set_border_width(SIDE_BOTTOM, 4)
	fill_style.border_color = Color(0.2, 0.6, 0.2, 0.5) # Darker bottom for depth
	fill_style.set_border_width(SIDE_TOP, 2)
	fill_style.border_color = Color(1, 1, 1, 0.2) # Lighter top
	
	_health_bar.add_theme_stylebox_override("background", bg_style)
	_health_bar.add_theme_stylebox_override("fill", fill_style)
	hbox.add_child(_health_bar)
	
	# Health Segments
	var max_hp: int = player.get("MAX_HP")
	for i in range(1, max_hp):
		var segment := ColorRect.new()
		segment.custom_minimum_size = Vector2(2, 0)
		segment.color = Color(0, 0, 0, 0.4)
		segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
		segment.set_anchors_preset(Control.PRESET_FULL_RECT)
		var pos_pct: float = float(i) / float(max_hp)
		segment.anchor_left = pos_pct
		segment.anchor_right = pos_pct
		segment.offset_left = -1
		segment.offset_right = 1
		segment.offset_top = 2
		segment.offset_bottom = -2
		_health_bar.add_child(segment)
	
	_health_label = Label.new()
	_health_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_health_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_health_label.text = str(player.hp) + " / " + str(player.MAX_HP)
	if _font_future: _health_label.add_theme_font_override("font", _font_future)
	_health_label.add_theme_font_size_override("font_size", 14)
	_health_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_health_label.add_theme_constant_override("outline_size", 6)
	_health_bar.add_child(_health_label)
	
	if _game_ui:
		var top_center = _game_ui.get_node_or_null("%TopCenter")
		if top_center:
			top_center.add_child(container)
			# Move to the first position so it appears to the left of the coin
			top_center.move_child(container, 0)
		else:
			add_child(container)
	else:
		add_child(container)
	
	_hurt_flash = ColorRect.new()
	_hurt_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hurt_flash.color = Color(1.0, 0.0, 0.0, 0.0)
	_hurt_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hurt_flash)

func _on_player_hurt(hp_remaining: int) -> void:
	if _health_bar:
		var tween := create_tween()
		tween.tween_property(_health_bar, "value", float(hp_remaining), 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _health_label:
		_health_label.text = str(hp_remaining) + " / 3"
	
	_hurt_flash.color = Color(1.0, 0.0, 0.0, 0.35)
	var flash_tween := create_tween()
	flash_tween.tween_property(_hurt_flash, "color", Color(1.0, 0.0, 0.0, 0.0), 0.4)

func _setup_minimap() -> void:
	var script := load("res://scenes/ui/minimap.gd")
	_minimap = Control.new()
	_minimap.set_script(script)
	_minimap.name = "Minimap"
	add_child(_minimap)

func _setup_cursor_preview() -> void:
	var ctrl := Control.new()
	ctrl.set_script(preload("res://scenes/ui/cursor_preview.gd"))
	ctrl.name = "CursorPreview"
	ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(ctrl)
	_cursor_preview = ctrl

func _process(_delta: float) -> void:
	if _placement:
		if not _placement.placing_market_item.is_empty():
			_selection_label.text = "Placing " + _placement.placing_market_item["name"] + "  [LMB] Place  [RMB] Cancel"
		else:
			var item_name: String = PipeSystem.ITEM_NAMES[_placement.selected_item]
			_selection_label.text = item_name + "  [R] Rotate  [MMB] Menu"
	if not _world_gen:
		return
	for i in range(mini(_world_gen.container_positions.size(), _container_bars.size())):
		var cp: Vector2i = _world_gen.container_positions[i]
		var level: float = _world_gen.container_levels.get(cp, 0.0)
		var bar: ProgressBar = _container_bars[i]["bar"]
		var pct: Label = _container_bars[i]["pct"]
		bar.value = level
		pct.text = str(int(level)) + "%"

func _on_spread_progress(remaining: int, total: int) -> void:
	if total <= 0 or not _green_bar:
		return
	var pct_val := 100.0 * (1.0 - float(remaining) / float(total))
	_green_bar.value = pct_val
	_green_pct.text = str(int(pct_val)) + "%"

func _on_game_won() -> void:
	if _game_ui and _game_ui.has_method("show_win_screen"):
		_game_ui.show_win_screen()
