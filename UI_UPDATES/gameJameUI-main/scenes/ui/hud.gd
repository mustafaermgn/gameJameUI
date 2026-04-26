extends CanvasLayer

var _selection_label: Label
var _container_bars: Array = []
var _pipe_system: Node = null
var _world_gen: Node = null
var _placement: Node = null
var _minimap: Control = null
var _cursor_preview: Control = null
var _game_ui: CanvasLayer = null

func setup(pipe_system: Node, world_gen: Node, placement: Node, player: CharacterBody3D = null) -> void:
	_pipe_system = pipe_system
	_world_gen = world_gen
	_placement = placement
	if _minimap and player:
		_minimap.setup(world_gen, pipe_system, player)
	if _cursor_preview and placement:
		_cursor_preview.setup(placement, placement._radial_menu)
	_setup_game_ui()

func _ready() -> void:
	_selection_label = Label.new()
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
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left = 10
	panel.offset_top = -120
	panel.offset_right = 210
	panel.offset_bottom = -10
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	vb.add_theme_constant_override("margin_left", 8)
	vb.add_theme_constant_override("margin_right", 8)
	vb.add_theme_constant_override("margin_top", 6)
	vb.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(vb)
	var title := Label.new()
	title.text = "Containers"
	title.add_theme_font_size_override("font_size", 14)
	vb.add_child(title)
	for i in range(2):
		var hb := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = "C" + str(i + 1) + ":"
		lbl.custom_minimum_size.x = 30
		lbl.add_theme_font_size_override("font_size", 13)
		hb.add_child(lbl)
		var bar := ProgressBar.new()
		bar.min_value = 0.0
		bar.max_value = 100.0
		bar.value = 0.0
		bar.custom_minimum_size.x = 130
		bar.show_percentage = false
		hb.add_child(bar)
		var pct := Label.new()
		pct.text = "0%"
		pct.custom_minimum_size.x = 35
		pct.add_theme_font_size_override("font_size", 13)
		hb.add_child(pct)
		vb.add_child(hb)
		_container_bars.append({"bar": bar, "pct": pct})
	add_child(panel)

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
