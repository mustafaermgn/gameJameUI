extends Control

@onready var progress_bar: ProgressBar = %ProgressBar
@onready var status_label: Label = %StatusLabel
@onready var tip_label: Label = %TipLabel

var _target_scene := "res://scenes/main.tscn"
var _progress := []

const TIPS := [
	"Su sızıntılarını durdurarak puan kazanabilirsin.",
	"Boruları döndürmek için 'R' tuşunu kullan.",
	"Daha hızlı hareket etmek için marketten 'Koşma' yükseltmesini al.",
	"Düşmanları tespit etmek için mini haritayı kontrol et.",
	"Pompalar suyun akışını başlatmak için gereklidir."
]

var _min_duration := 3.0 # Minimum 3 seconds
var _elapsed := 0.0
var _can_transition := false

func _ready() -> void:
	# Set random tip
	tip_label.text = "İPUCU: " + TIPS[randi() % TIPS.size()]
	
	# Start threaded loading
	ResourceLoader.load_threaded_request(_target_scene)
	
	# Initial UI state
	progress_bar.value = 0
	status_label.text = "DÜNYA OLUŞTURULUYOR..."
	
	# Animate status label
	var tween = create_tween().set_loops()
	tween.tween_property(status_label, "modulate:a", 0.3, 0.5)
	tween.tween_property(status_label, "modulate:a", 1.0, 0.5)

func _process(delta: float) -> void:
	_elapsed += delta
	var time_progress = (_elapsed / _min_duration) * 100.0
	
	var status = ResourceLoader.load_threaded_get_status(_target_scene, _progress)
	var real_progress = _progress[0] * 100.0 if _progress.size() > 0 else 0.0
	
	# The progress bar shows the minimum of time-based progress and real progress
	# but we allow it to reach 100 only if both are ready.
	progress_bar.value = lerpf(progress_bar.value, minf(real_progress, time_progress), 0.05)
	
	if status == ResourceLoader.THREAD_LOAD_LOADED and _elapsed >= _min_duration:
		progress_bar.value = 100
		status_label.text = "TAMAMLANDI!"
		set_process(false)
		await get_tree().create_timer(0.8).timeout
		var packed_scene = ResourceLoader.load_threaded_get(_target_scene)
		get_tree().change_scene_to_packed(packed_scene)
	elif status == ResourceLoader.THREAD_LOAD_FAILED:
		status_label.text = "YÜKLEME HATASI!"
		set_process(false)
