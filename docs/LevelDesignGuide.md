# Plantformer Demo — 手搭关卡指南

> **这条指南是为不写代码、直接在 Godot 编辑器里搭关卡的关卡设计师写的。**
> 你不需要改任何脚本，只要摆好节点、配好属性即可。
> 项目全部技术参数在 `docs/TDD.md` 里；以下只摘抄跟搭关卡有关的。

---

## 1. 网格与尺度 —— 一切的基础

| 项目 | 数值 | 备注 |
|------|------|------|
| **1 砖** | `8 × 8 px` | 所有几何都按 8 的倍数放 |
| 视口（游戏画面） | `320 × 180 px` | 对应 40×22.5 砖 |
| 窗口（屏幕上看到的） | `1280 × 720 px` | 4 倍整数放大，无模糊 |
| 玩家站立碰撞箱 | 宽 **8**、高 **11**（`-4, -11` → `+4, 0`） | 原点在脚底中心 |
| 玩家下蹲碰撞箱 | 宽 **8**、高 **6**（`-4, -6` → `+4, 0`） | 底边不动 |
| 1 砖宽的缝 | 玩家 **可以** 挤过去（角落修正会帮忙） | `SHAPE_INSET = 1.0` 留了 1px 余量 |
| 1 砖高的低通道 | 只有 **蹲着 + Dash** 能过，站着会被顶住 | 蹲 = 6px 高 |
| 地面 | 碰撞体 **顶面** 与角色脚底平齐即可 | `floor_snap_length = 2px` 会吸附上去 |

> **编辑器建议**：Godot 顶部菜单 `Project → Project Settings → General → Grid Map` 把默认步进设成 **8**，吸附打开（`Transform → Configure Snap`）——
> 这样拖东西自动对齐 8px 网格，绝对不要用小数坐标（角落修正靠整数对齐才能稳定工作）。

---

## 2. 碰撞层 —— 放错就死人

**一套语法、一套后果**：放错了不会有报错，但玩家可能被卡在半空，dash 和体力再也不恢复，然后你会觉得"手感崩了"。

| 层 | 值 | 给谁 | 碰撞掩码（mask）|
|----|-----|------|-----------------|
| 1 | `0b1` | **所有地形**（地板、墙、天花板） | — |
| 2 | `0b10` | **玩家**（`Player`） | **只勾 1** |

**什么意思？**
- 地形只放在层 1，不用设 mask。
- 玩家 `Player.tscn` 已经配好了（层 2 / 掩码 1），**新关卡里不要改它**。

---

## 3. 关卡场景的节点结构

新建关卡场景（`Scene → New Scene`），根节点选 `Node2D`，然后按下面的树来搭：

```
Level01 (Node2D)                         ← 场景根
├── Terrain (StaticBody2D)               ← 所有实体地形放这个下面
│   ├── Floor (CollisionShape2D)          ← 矩形地板
│   ├── WallLeft (CollisionShape2D)       ← 墙
│   ├── Ceiling (CollisionShape2D)        ← 天花板
│   └── ...（任意数量，按关卡需求摆）
├── TerrainVisuals (Node2D)               ← 地形视觉（ColorRect），与碰撞体一一对应
│   ├── FloorVisual (ColorRect)
│   └── ...
├── Checkpoint (Area2D)                   ← 检查点（带碰撞形状就行，玩家踩中自动保存）
│   └── CollisionShape2D
├── KillPlane (Area2D)                    ← 死亡区（玩家碰了就死，即时送回检查点）
│   └── CollisionShape2D
├── Spawn (Marker2D)                      ← 出生点（关卡加载时玩家出现在这里）
├── Player (PackedScene)                  ← 拖入 player.tscn 实例
└── Camera2D                              ← 关卡专属相机（可选，player.tscn 自带的也能用）
```

### 3.1 地形（StaticBody2D）

每块地形 = **1 个 `CollisionShape2D`** + **1 个 `ColorRect`**（视觉对应）。

- `CollisionShape2D.shape` 选 `RectangleShape2D`，尺寸按 8px 倍数设。
- **碰撞层 (collision_layer)** 必须设为 **1**，**碰撞掩码 (collision_mask) 留空**。
- `ColorRect` 挂在 `TerrainVisuals` 下，位置和尺寸与碰撞体对齐。
  - 当前推荐颜色：`Color(0.22, 0.25, 0.32)` （深灰蓝）。
  - `ColorRect` 的存在**纯粹为了眼睛看**——玩家碰撞只看 `StaticBody2D` 的形状，`ColorRect` 不参与物理。

> 灰盒阶段不需要 `TileMap`，直接摆 `StaticBody2D` 最快。等最终美术确定后可以换成 `TileMapLayer`（8px 砖模板），但碰撞规则完全不变。

#### 常见地形尺寸速查

| 地形 | 尺寸 (w × h) | position 示例 | 用途 |
|------|-------------|---------------|------|
| 地面 | `≥ 64 × 16` (8x2 砖) | `(0, 120)` | 顶面在 y=112 |
| 2 砖厚的地面 | `≥ 64 × 16` | `(0, 112)` | 顶面 y=112、更结实 |
| 墙 | `16 × ≥80` (2x10 砖) | 贴在侧面 | 攀爬用 |
| 天花板 / 台子 | `64 × 8` (8x1 砖) | `(32, 88)` | 顶面在 y=96 |
| 低通道 roof | `32 × 8` | 蹲着才能过 | 底面 y=96（1 砖高缝） |

> **position 的 y 是形状中心**，不是顶面。地面的顶面 = `position.y - height/2`。
> 建议直接按"顶面 y = 你想要的坐标"来反算 position：
> `position.y = 顶面_y + height / 2`。

---

### 3.2 检查点（Checkpoint）

检查点是 `Area2D`，玩家踩中时 `Game` autoload 自动记录位置。

- 节点类型：`Area2D`（名字随便，比如 `Checkpoint_01`）
- 子节点：`CollisionShape2D`，形状用 `RectangleShape2D`，宽 16~24px、高 16~32px
- layer/mask 全部**留空**（`0`），它不需要参与物理碰撞，只靠 `area_entered` 信号
- 视觉：挂一个 `ColorRect`（推荐绿 `Color(0.35, 0.85, 0.45)`）标记位置
- **放哪儿**：关卡入口、岔路关键点、坑前、Boss 门前

> ❗ **检查点本身没有脚本，不用挂任何代码**—— `Game` autoload 靠查找场景里的 `Area2D` 实例来工作。
> 如果你想让检查点只触发一次，给它配 `monitoring = true` / `monitorable = true`（默认就开了）。

---

### 3.3 死亡区（KillPlane）

玩家碰到就立刻死，送回最近的检查点。**零死亡动画、零延迟**。

- 节点类型：`Area2D`（名字随便，比如 `KillPlane`）
- 子节点：`CollisionShape2D`，宽拉满全关、高 24~32px
- layer/mask 同检查点，**留空**（`0`）
- position：放在所有坑底，顶面比坑底稍高。参考坐标：`y = 144~160`（地面 y=112 下方 4~6 砖）
- 视觉：红色半透明条 `Color(0.72, 0.18, 0.22, 0.5)`，比碰撞区窄一点（让人看见就够了）

> 如果关卡边界外有可能摔出去的区域，在边界最下方横拉一条兜底。
> 复活帧数实测约 **17 帧**（~0.28 秒），所以玩家几乎感觉不到停顿。

---

### 3.4 出生点与玩家

- **出生点**：`Marker2D`，起名 `Spawn`，放在关卡起点。
- **玩家**：把 `res://scenes/player/player.tscn` 从文件系统拖进场景，放在 `Spawn` 上。
  - 玩家节点的 `collision_layer = 2`、`collision_mask = 1`（场景自带，不要改）。

---

---

## 4. 技巧坑的坑宽速查

这些是实测出的基础数据，设计跨越坑时对照：

| 动作 | 平地能跨 | 备注 |
|------|----------|------|
| 普通跳 | **40 px（5 砖）** | 按住 J 最远 |
| 台沿干走 | **8 px（1 砖）** | 仅限蹭出去的，不算跳 |
| 台沿 + 空中 Dash | **10 px（1.2 砖）** | 从台子边缘走一步再 K |
| 跳 + 空中水平 Dash | **65 px（8.1 砖）** | 跳起来在半空按 K |
| Super（地面横向 Dash+J） | **85 px（10.6 砖）** | — |
| Hyper（地面斜下 Dash+J） | **110 px（13.8 砖）** | 低平远距 |
| Wavedash（跳→斜下 Dash→J） | **114 px（14.2 砖）** | — |
| Ultra（台子上跑出→斜下 Dash 撞地→J）| **~114 px**（但起跳点在台边，实际跨距取决于台子位置） | 台子越近坑起跳越晚 |

> **坑宽设计原则**：要挡普通跳就 ≥ **6 砖**；要连「跳+空中 Dash」也挡就 ≥ **9 砖**；
> 要挡住 Super 留给 Hyper 用就 ≥ **11 砖**。

---

## 5. 相机

`Player.tscn` 自带 `Camera2D`，**新关卡不用额外加相机**，除非你想自定义相机行为。

如果你想关卡有独立相机（固定视角、平滑跟随、边界限制等）：

1. 关卡根下加 `Camera2D` 节点
2. 设为 `current = ON`（勾上 `Enabled` 旁边的 `Current`）
3. 关掉 Player 的相机：选中 Player 下的 Camera2D，把 `Enabled` 关掉
4. 常用相机参数：
   - `drag_horizontal / vertical` 设 0.3~0.5 有平滑跟随
   - `limit_left / right / top / bottom` 限制镜头不超出关卡边界（320×180 视口下非常有用）

---

## 6. 测试你的关卡

### 6.1 Godot 编辑器里

把新建的关卡场景设为主场景：右键 `.tscn` → `Set as Main Scene` → 按 **F6** 运行。

### 6.2 不会坏掉的保证：跑 headless 回归

**每次改完关卡跑一遍，两分钟不到，能抓出 99% 的物理倒退**：

```
F:\personal\Godot\Godot_v4.7.1-stable_win64_console.exe --headless --path "f:\personal\plantformer-demo" --script "res://scripts/debug/player_regression.gd"
```

期望输出：`---- PLAYER REGRESSION 84 passed, 0 failed ----`

如果 FAIL，说明你加了什么东西撞到了现有物理——回头检查碰撞层。

如果测试房没动过，就不需要跑 `room_regression.gd`（那是专门给 `test_room.gd` 的 ASCII 图用的）。

### 6.3 快速手动检查

| 检查项 | 操作 | 期望 |
|--------|------|------|
| 踩地 | 站在所有地面上不动 | 不滑、不穿模、debug 显示 `MODE NORMAL` |
| Dash | K + 方向 | 8 向都通，dash 次数扣 1 |
| Dash 恢复 | Dash 后落地 | dash 次数回到 1 |
| 蹲着走 | 按住 S | 速度被摩擦压到很慢（不能正常走路） |
| 爬墙 | Shift 贴墙 | 角色吸附在墙上、不下滑 |
| 坑 | 摔进坑 | 死亡瞬发、回到检查点、dash 体力全满 |
| 相机 | 正常跑跳 | 不抖、不穿帮、不跟丢 |

---

## 7. 常见错误排查

| 症状 | 最可能的原因 | 怎么修 |
|------|-------------|--------|
| 1 砖缝怎么也钻不进去 | 缝隙 < 8px（比如 7px 宽） | 检查两个碰撞体之间的距离，必须是 8px 的整数倍 |
| 角色站地上却在慢慢滑 | 某个碰撞体角度不是 0（有微小旋转） | 所有地形碰撞体 `rotation` 必须为 0 |
| 检查点不触发 | `monitoring` 或 `monitorable` 关了 | `Area2D` 两个都勾上 |
| 掉坑不死、一直往下掉 | 没放 KillPlane，且玩家 y 没超过关卡里的死亡阈值 | 在坑底加 KillPlane（Area2D + CollisionShape2D） |
| 编辑器看到的跟运行时不一样 | 改完没有保存 `.tscn` | Ctrl+S 保存场景 |
| 玩家掉出 y > 场景底部但没 KillPlane | 关卡最下方横拉一个 KillPlane 兜底 |

---

## 8. 从 test_room 学到的坑（可以跳过，但读了能省很多时间）

1. **角色碰撞箱只有 8×11**，所以 1 砖（8px）高的通道站着是过不去的，必须蹲着（6px）+ Dash。同理 1 砖宽的缝理论上是够的，但实际上需要 `SHAPE_INSET` 帮忙（已配好），你的地形只要保证缝 **正好 8px** 就行。
2. **地面往下的第一行不算 KillPlane**——如果坑的底部跟地面在同一行（比如坑深刚好 1 砖），掉进去前玩家可能还在 `floor_snap_length` 范围内蹭到地面。
4. **`player.tscn` 的 `safe_margin = 0.001`** 是故意设这么小的，否则贴墙爬墙会出现 1px 空隙。新建的关卡地形不需要特别设这个值。
5. 如果玩家出生后立刻掉进虚空，检查 `Spawn` 的 y 坐标——角色的 `(0,0)` 是脚底，所以 Marker2D 必须放在**实体上方 1px 以上**，否则玩家会在出生帧就被地板吞掉。

---

## 9. 快速起步：建你的第一个关卡

1. `Scene → New Scene`，根节点 `Node2D`，命名为 `Level01`，保存到 `res://scenes/levels/level_01.tscn`。
2. 加 `StaticBody2D` → 改名 `Terrain`，给它加子节点 `CollisionShape2D` + `RectangleShape2D`：
   - 尺寸 `640 × 16`（80 砖宽 × 2 砖厚），position `(320, 120)` → 一条从 x=0 到 x=640、顶面 y=112 的地面。
3. 加 `Node2D` → 改名 `TerrainVisuals`，给它加 `ColorRect`：
   - 尺寸 `640 × 16`，position `(0, 112)`，颜色 `Color(0.22, 0.25, 0.32)`。
4. 加 `Area2D` → 改名 `KillPlane`，加子 `CollisionShape2D` + 矩形 `1280 × 32`，position `(640, 160)`。
5. 加 `Marker2D` → 改名 `Spawn`，position `(32, 111)`（刚好站在地面上方 1px）。
6. 从 FileSystem 拖 `player.tscn` 到场景根，position 设 `(32, 112)`（脚底踩地面顶面）。
7. 右键 `level_01.tscn` → `Set as Main Scene`。
8. 按 **F6** 跑。角色站在地面上，左右走、跳、Dash——一切正常。
9. 回头开始加墙、坑、天花板……不断 F6 测试。

> 关卡设计没有"对""错"，只有"拳头够不够硬"——你摆的每一块砖，最后都要自己跑得过。
