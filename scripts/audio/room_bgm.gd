extends Node
class_name RoomBgm
## 房间 BGM 管理器：每个子节点（RoomBgmEntry）按名字对应一个房间。
## 使用方式：把子节点命名成房间节点名（room1/room2...），把 AudioStream 拖进它的 Stream 属性。

@export var volume_db := -9.0
@export var crossfade := 1.5

var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _current: AudioStream
var _streams: Dictionary = {}


func _ready() -> void:
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.name = "BgmPlayer%d" % i
		p.volume_db = -60.0
		add_child(p)
		_players.append(p)
	refresh_entries()


func refresh_entries() -> void:
	_streams.clear()
	for ch in get_children():
		if ch is RoomBgmEntry and (ch as RoomBgmEntry).stream != null:
			_streams[String(ch.name).to_lower()] = (ch as RoomBgmEntry).stream


func play_for_room(room_name: String) -> void:
	var stream: AudioStream = _streams.get(room_name.to_lower())
	if stream == null or stream == _current:
		return
	_current = stream
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	var incoming: AudioStreamPlayer = _players[1 - _active]
	var outgoing: AudioStreamPlayer = _players[_active]
	_active = 1 - _active
	incoming.stream = stream
	incoming.volume_db = -60.0
	incoming.play()
	if crossfade <= 0.0:
		incoming.volume_db = volume_db
		outgoing.stop()
		return
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(incoming, "volume_db", volume_db, crossfade)
	tw.tween_property(outgoing, "volume_db", -60.0, crossfade)
	tw.chain().tween_callback(outgoing.stop)
