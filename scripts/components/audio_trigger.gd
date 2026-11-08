extends Area2D
class_name AudioTrigger
## 走入区域时播放音频；无任何可见边框/图形。
## 用法：把场景放到关卡里，调 CollisionShape2D 的大小，在 Inspector 指定 Stream。

@export var stream: AudioStream
@export var volume_db := 0.0
@export var play_once := false          # 只触发一次
@export var stop_on_exit := false        # 离开区域停止（适合循环音）

@onready var _player: AudioStreamPlayer = $AudioStreamPlayer
var _used := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2                  # 玩家层
	monitoring = true
	monitorable = false
	if _player:
		_player.bus = "SFX"
		# 音频可以直接挂在子节点 AudioStreamPlayer 上；根节点的 Stream 作为补充
		if _player.stream == null and stream != null:
			_player.stream = stream
		if volume_db != 0.0:
			_player.volume_db = volume_db
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	add_to_group("resettable_triggers")
	add_to_group("audio_triggers")


func reset_state() -> void:
	_used = false
	stop_audio()


## 房间切换时由关卡统一调用
func stop_audio() -> void:
	if _player:
		_player.stop()
	_used = false


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player") and body.name != "Player":
		return
	if play_once and _used:
		return
	if _player == null:
		return
	if _player.stream == null:
		if stream == null:
			return
		_player.stream = stream
	_used = true
	if volume_db != 0.0:
		_player.volume_db = volume_db
	_player.play()


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player") and body.name != "Player":
		return
	if stop_on_exit and _player:
		_player.stop()
