extends Resource
## 一个音效事件：id = 代码里调用的事件名；streams = 该事件的音频变体；
## volume_db = 音量；pitch_min/max = 随机音高范围；loop = 是否为循环音。

@export var id: StringName
@export var streams: Array[AudioStream] = []
@export var volume_db := 0.0
@export var pitch_min := 1.0
@export var pitch_max := 1.0
@export var loop := false
