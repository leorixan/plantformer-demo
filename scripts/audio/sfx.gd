extends Node
## 音效接口：
##   Sfx.play(&"jump")
##   Sfx.start_loop(&"wall_slide") / Sfx.stop_loop(&"wall_slide")
##
## 编辑位置：scenes/audio/sfx.tscn 的 Inspector -> Entries
## 每个 entry 有 id / streams / volume_db / pitch_min / pitch_max / loop。
## 换音频：把 .wav 拖进对应 entry 的 Streams 数组。
## 加事件：新增 entry，id 和代码里调用名一致。

@export var entries: Array[Resource] = []
@export var pool_size := 12
@export var pitch_jitter := 0.03
@export var bus_name := "Master"

var _map: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _loops: Dictionary = {}
var _next_player := 0


func _ready() -> void:
	_build_map()
	for i in pool_size:
		var p := AudioStreamPlayer.new()
		p.name = "SfxPlayer%d" % i
		p.bus = bus_name if AudioServer.get_bus_index(bus_name) >= 0 else "Master"
		add_child(p)
		_pool.append(p)


func refresh() -> void:
	_build_map()


func _build_map() -> void:
	_map.clear()
	for e in entries:
		if e == null:
			continue
		var id := String(e.get("id"))
		if id != "":
			_map[id] = e


func play(id: StringName, volume_offset_db := 0.0) -> void:
	var e = _map.get(String(id))
	if e == null:
		return
	var streams: Array = e.get("streams")
	if streams.is_empty():
		return
	if bool(e.get("loop")):
		start_loop(id, volume_offset_db)
		return
	var p := _free_player()
	if p == null:
		return
	p.stream = streams[randi() % streams.size()]
	p.volume_db = float(e.get("volume_db")) + volume_offset_db
	p.pitch_scale = randf_range(maxf(0.01, float(e.get("pitch_min")) - pitch_jitter), float(e.get("pitch_max")) + pitch_jitter)
	p.play()


func start_loop(id: StringName, volume_offset_db := 0.0) -> void:
	var key := String(id)
	if _loops.has(key):
		return
	var e = _map.get(key)
	if e == null:
		return
	var streams: Array = e.get("streams")
	if streams.is_empty():
		return
	var p := AudioStreamPlayer.new()
	p.name = "SfxLoop_%s" % key
	p.bus = bus_name if AudioServer.get_bus_index(bus_name) >= 0 else "Master"
	p.stream = _make_looped(streams[0])
	p.volume_db = -60.0
	add_child(p)
	p.play()
	_loops[key] = p
	var tw := create_tween()
	tw.tween_property(p, "volume_db", float(e.get("volume_db")) + volume_offset_db, 0.15)


func stop_loop(id: StringName, fade := 0.15) -> void:
	var key := String(id)
	var p: AudioStreamPlayer = _loops.get(key)
	if p == null:
		return
	_loops.erase(key)
	var tw := create_tween()
	tw.tween_property(p, "volume_db", -60.0, fade)
	tw.tween_callback(p.queue_free)


func stop_all(fade := 0.1) -> void:
	for key in _loops.keys():
		stop_loop(StringName(key), fade)
	for p in _pool:
		if p.playing:
			var tw := create_tween()
			tw.tween_property(p, "volume_db", -60.0, fade)
			tw.tween_callback(p.stop)


func _free_player() -> AudioStreamPlayer:
	for i in _pool.size():
		var idx := (_next_player + i) % _pool.size()
		if not _pool[idx].playing:
			_next_player = (idx + 1) % _pool.size()
			return _pool[idx]
	var p := _pool[_next_player]
	_next_player = (_next_player + 1) % _pool.size()
	p.stop()
	return p


func _make_looped(stream: AudioStream) -> AudioStream:
	if stream is AudioStreamWAV:
		var w := (stream as AudioStreamWAV).duplicate() as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(round(w.get_length() * w.mix_rate))
		return w
	if stream is AudioStreamOggVorbis:
		var o := (stream as AudioStreamOggVorbis).duplicate() as AudioStreamOggVorbis
		o.loop = true
		return o
	return stream
