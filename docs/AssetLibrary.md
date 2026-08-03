# 素材库使用指南

场景搭建组件库。所有组件都是独立 `.tscn`，拖进场景即可用；也支持 ASCII 地图代码生成。

## 组件一览

| 组件 | 场景 | 脚本 | 说明 | 关键属性 |
|------|------|------|------|----------|
| 墙体 | `scenes/components/wall.tscn` | `wall.gd` | 实体方块，可调尺寸 | `size` / `color` |
| 尖刺 | `scenes/components/spike.tscn` | `spike.gd` | 碰到玩家 → `take_damage()` 回存盘点 | `size` / `color` |
| 可破坏方块 | `scenes/components/breakable_block.tscn` | `breakable_block.gd` | 玩家 attacking 状态撞上即碎裂 | `size` / `color` |
| 弹簧 | `scenes/components/spring.tscn` | `spring.gd` | 接触即弹射（非实心，走过/踩上都触发） | `launch_speed` |
| 移动平台 | `scenes/components/moving_platform.tscn` | `moving_platform.gd` | A/B 两点往返，玩家站上随动 | `offset` / `speed` |
| 存盘点 | `scenes/components/checkpoint.tscn` | `checkpoint.gd` | 进入后记录重生点 | `size` / `color` |

## 玩家接口（组件依赖）

| 接口 | 说明 |
|------|------|
| `player.is_attacking()` | `dash_attack_timer > 0 \|\| speed >= 240`，可破坏方块用它判断 |
| `player.take_damage()` | 受伤/死亡 → 回到 `last_checkpoint` 重生 |
| `player.set_checkpoint(pos)` | 存盘点组件调用，记录重生位置 |
| `player.kill_plane_y` | 掉到该 y 以下自动重生（导出属性，默认 1000） |

## 拖拽用法

1. 新建场景（Node2D）
2. 把 `scenes/components/*.tscn` 拖进场景
3. 调整位置/属性（inspector 面板）
4. 放一个 `scenes/player/player.tscn`，设它的 `kill_plane_y`（或留默认 1000）
5. F6 运行

碰撞层约定：地形/组件实体 = 层 1，玩家 = 层 2（mask 1）。伤害/触发类组件（尖刺、弹簧、存盘点）是 Area2D，mask 2 检测玩家。

## ASCII 地图生成（SceneBuilder）

`scripts/components/scene_builder.gd`，与 test_room.gd 同范式：

```gdscript
var rows := [
    "................",
    "................",
    "..........P.....",
    "..S..B..^..C....",   # S=尖刺 B=可破坏 ^=弹簧 C=存盘点
    "################",   # #=墙体 .=空
]
var result := SceneBuilder.build(rows, load("res://scenes/player/player.tscn"))
add_child(result["container"])          # 全部组件容器
result["player"].global_position = result["spawn"]
result["player"].kill_plane_y = result["kill_plane_y"] 按地图行数自动算
add_child(result["player"])
```

| 字符 | 组件 |
|------|------|
| `#` | 墙体（连续段自动合并成矩形） |
| `P` | 玩家出生点 |
| `S` | 尖刺 |
| `B` | 可破坏方块 |
| `^` | 弹簧 |
| `M` | 移动平台（横向往返） |
| `C` | 存盘点 |
| `x` | 目标标记（纯视觉） |

## 死亡系统

统一由 `player.gd` 处理，不再依赖关卡脚本：
- `kill_plane_y` 以下 → 自动重生到 `last_checkpoint`
- 尖刺等伤害源 → `take_damage()` → 重生
- 存盘点 Area2D → 进入时更新 `last_checkpoint`
- test_room.gd 已接入：跨区自动设存盘点，坑底死亡走玩家自身判定

## 验证

`scripts/debug/component_regression.gd`（6 条：存盘点/尖刺/可破坏×2/弹簧/死亡线）。
