# 房间 BGM 设置（Godot 内直接改，不用改代码）

## 在哪里配

1. 打开 `scenes/levels/level.tscn`
2. 在场景树选中 `GrayboxLevel` 下的 **`Bgm`** 节点
3. 展开它，子节点就是房间名：`room1` ~ `room6`、`bonus1/2`、`void`
4. 选中某个房间子节点，在 Inspector 里找到 **Stream** 属性
5. 从 FileSystem 把 `assets/audio/bgm/` 里的 `.ogg` 拖进 Stream

节点名必须和 `Rooms` 下的房间节点名一致（不区分大小写）。

## 当前默认

| 房间 | BGM |
|---|---|
| room1 / room2 / room3 / bonus1 / void | bgm_late.ogg（后段） |
| room4 / room5 / room6 / bonus2 | bgm_early.ogg（前段） |

关卡出生在 room5，所以开局是前段；到 room3 左右切后段。

## 常用调整

- **换某房间的 BGM**：选中对应子节点，重新拖 Stream
- **某房间不要 BGM**：删掉对应子节点（或把 Stream 清空）→ 该房间会保持上一首，不会停
- **加新房间**：右键 `Bgm` → Add Child Node → `Node`，命名成房间名，挂 `scripts/audio/room_bgm_entry.gd`，再拖 Stream
- **加新曲目**：把 OGG 放进 `assets/audio/bgm/`，Godot 导入后即可拖进 Stream
- **音量 / 淡入淡出**：选中 `Bgm` 节点，Inspector 里改 `Volume Db` 和 `Crossfade`

## 主菜单音乐

菜单 BGM 在 `scenes/ui/main_menu.tscn` 的脚本里，文件是 `assets/audio/bgm/bgm_menu.ogg`（07 Forest Mist Whispers），不经过 `Bgm` 节点。
