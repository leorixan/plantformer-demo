# 音效接入与修改接口

## 已经接好的音效

- 音频文件：`assets/audio/sfx/*.wav`（28 个）
- 音效表：`scenes/audio/sfx.tscn` 根节点 `Sfx` 的 **Entries**（Autoload 名：`Sfx`）
- 每个 entry 字段：
  - `id`：代码里调用的事件名
  - `streams`：该事件的音频变体列表（随机挑一个播放）
  - `volume_db`：音量
  - `pitch_min` / `pitch_max`：随机音高范围
  - `loop`：是否循环音

## 事件绑定表

| 事件 id | 触发点 | 使用的音频 |
|---|---|---|
| `jump` | 跳跃/超级跳/Hyper/Ultra/爬墙跳/DreamJump | jump_01 / jump_03 |
| `land` | 落地（下落速度 > 60） | land_heavy_01 |
| `wall_jump` | 已改为用 `jump`；entry 保留但不再调用 | wall_jump_01 / 02（备用） |
| `wall_slide` | 贴墙下滑（循环） | wall_slide_01 |
| `climb_grab` | 开始抓墙 | climb_grab_01 |
| `footstep` | 地面上移动（每 0.26s） | footstep_01 / 02 |
| `dash` | 冲刺开始 | dash_02 |
| `dash_end` | 冲刺结束 | dash_end_01 |
| `dream_enter` | 进入紫块 | dream_enter_02 |
| `dream_exit` | 离开紫块 | dream_exit_01 |
| `dream_loop` | 紫块内持续（循环） | dream_loop_01 |
| `crystal` | 吃冲刺水晶 | crystal_01 / 02 |
| `trophy` | 奖杯结算 | trophy_01 |
| `spring` | 弹簧弹起 | spring_01 / 02 |
| `breakable` | 可破坏块被冲刺打碎 | breakable_01 / 02 |
| `death` | 死亡/重生 | death_01 / 02 |
| `level_complete` | 到达 Goal | level_complete_01 |
| `ui_move` | 菜单按钮获得焦点/悬停 | ui_move_01 |
| `ui_confirm` | 菜单开始按钮 | ui_confirm_01 |
| `ui_back` / `ui_pause` | 预留给以后 UI | ui_back_01 / ui_pause_01 |

## 怎么改

1. 打开 `scenes/audio/sfx.tscn`
2. 选中根节点 `Sfx`
3. Inspector → `Entries` → 展开某个事件
4. 改 `Streams`：把 `assets/audio/sfx/` 里的 wav 拖进去（可多个变体）
5. 改 `Volume Db`、`Pitch Min/Max`、`Loop`

新增事件：
- 在 `Entries` 里 Add Element（Resource）
- `id` 填一个名字，例如 `pause`
- 代码里调用 `Sfx.play(&"pause")`

## 代码接口

```gdscript
Sfx.play(&"jump")                    # 播放一次（随机变体 + 随机音高）
Sfx.play(&"land", -3.0)              # 额外降低 3dB
Sfx.start_loop(&"wall_slide")        # 开始循环
Sfx.stop_loop(&"wall_slide")         # 停止循环（淡出）
Sfx.stop_all()                       # 全部停
Sfx.refresh()                        # 运行时重新读 Entries
```

根节点还可调：`pool_size`（同时播放数）、`pitch_jitter`（全局随机音高幅度）、`bus_name`（默认 Master）。

## 当前触发代码位置

- 玩家：`scripts/player/player.gd`
  - `_event()`：跳跃/墙跳/冲刺/爬墙
  - `_physics_process()`：落地、脚步、墙滑循环
  - `apply_spring_boost()`：弹簧
  - `start_dream_dash()` / `end_dream_dash()`：紫块进/出/循环
- 组件：`scripts/components/graybox_parts.gd`
  - `Crystal._on_body()`：`crystal`
  - `Breakable._physics_process()`：`breakable`
- 关卡：`scripts/levels/graybox_level.gd`
  - `respawn_player()`：`death`
  - `collect_trophy()`：`trophy`
  - `_on_goal()`：`level_complete`
- 菜单：`scripts/ui/main_menu.gd`
  - 开始按钮：`ui_confirm`；聚焦/悬停：`ui_move`

## 备注

- 主菜单 BGM 不经过 `Sfx`，在 `scenes/ui/main_menu.tscn` 的脚本里。
- 房间 BGM 在 `scenes/levels/level.tscn` 的 `Bgm` 节点下配置，见 `docs/BGM_Rooms.md`。
- `ui_back` / `ui_pause` 目前没有对应 UI，接口已留好。
