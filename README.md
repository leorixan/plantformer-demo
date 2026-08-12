# Plantformer Demo

A 2D precision-platformer character controller built in **Godot 4.7 / GDScript**, developed as a
study reimplementation of *Celeste*'s movement system — with a **headless physics regression suite**
so that "game feel" becomes something you can verify, not just something you claim.

[English](#english) · [中文](#中文)

---

## English

### Attribution

This is an openly-declared **learning reimplementation**. The movement constants and the frame-order
logic follow the `Player.cs` source that Maddy Thorson / Noel Berry published for *Celeste*
(`NoelFB/Celeste`). Inline comments cite the reference by line number so every behaviour can be
checked against its origin.

The reference source itself is **not redistributed here** — it is published for study but not under
an open-source license, so it is kept local only (see `.gitignore`). All code in this repository is
written by me.

### What is actually mine

The port is not the interesting part. These three are:

1. **Integer-grid → floating-point port.** The reference runs on integer pixel coordinates; Godot 2D
   physics runs on floats with a default `safe_margin` of `0.08`. That difference silently breaks
   flush-wall detection and corner correction. Diagnosing it produced two deliberate constants,
   `CONTACT_MARGIN` and `SHAPE_INSET` (`scripts/player/player.gd:12-17`), each with the failure it
   fixes documented in place.
2. **A real headless physics regression suite** — 82 assertions driving an actual instantiated
   player through `Input.action_press` frame by frame, plus level-geometry and component suites.
   Every feature was verified by **mutation testing**: deliberately break a parameter or a branch,
   confirm the matching assertion turns red, then revert.
3. **Level geometry derived from measured reach.** Pit widths in the test room are back-solved from
   measured jump distances (normal jump ≈ 40 px, Super ≈ 85 px, Hyper ≈ 110 px → an 80 px pit), so a
   room is *provably* impassable without the technique it teaches. `room_regression.gd` fails the
   build if a design edit invalidates that.

### Engineering notes (the useful part)

| Problem | Root cause | Resolution |
|---|---|---|
| Dash / stamina / coyote never refilled during a horizontal dash | `is_on_floor()` reports the *previous* frame and needs downward displacement; a horizontal dash has none | Replaced with an explicit geometry probe `_on_ground()` (`scripts/player/player.gd`) |
| Climb slipped one pixel below the ledge | Godot's default `safe_margin` `0.08` counts "just touching" as a hit, so the slip probe landed on the wall boundary | Snap to contact via `move_and_collide` with `CONTACT_MARGIN = 0.001` |
| An 8 px body could not pass an 8 px gap | Integer coordinates make it an exact fit; floats demand sub-pixel alignment, so corner correction found no valid slot | Inset the physics box by 1 px (`SHAPE_INSET`), restoring reliable corner correction |
| Super / Hyper / Ultra fired inconsistently | Velocity was written by several nodes per frame, each reading stale collision facts | Single simulation owner with a fixed frame order (below) |

**Fixed frame order** — input edge sampling → timers → pre-move decisions → *one* `move_and_slide`
→ this frame's collision facts → post-move technique arming. State lives in a `Mode` enum
(`NORMAL / DASH / CLIMB`) inside one file rather than in autonomous state nodes, mirroring the
reference's single `State` integer. The rationale is recorded in `.claude/documents/TDD.md`.

### Features

Run / coyote time / jump buffering / variable jump height · ducking · 8-directional dash with
freeze-frame aim sampling and speed retention · Dash Slide · Super / Hyper / Ultra · wall jump /
SuperWallJump / wall slide / wall speed retention (Cornerboost) · climb, climb jump, climb hop,
Wallboost, stamina · upward and dash corner correction · checkpoints and instant respawn.

Data-driven tuning: every feel parameter is `@export`ed and mirrored in
`.claude/documents/player_params.csv`, hot-reloadable at runtime with `F5`.

### Run

```bash
# play
godot --path .

# regression suites
godot --headless --path . --script res://scripts/debug/player_regression.gd     # 82 physics assertions
godot --headless --path . --script res://scripts/debug/room_regression.gd       # level geometry
godot --headless --path . --script res://scripts/debug/component_regression.gd  # 6 component checks
```

Requires Godot **4.7**. Resolution is 320×180 with integer scaling, 8 px tiles.

| Action | Key |
|---|---|
| Move | `A` / `D` or arrow keys |
| Jump | `J` |
| Dash | `K` |
| Grab / climb | `Shift` |
| Reload parameters from CSV | `F5` |

The test room (`scenes/levels/test_room.tscn`) is split into 10 zones, one per technique, each with
an on-screen hint and its own checkpoint.

### Layout

```
scenes/            player, levels, reusable components (.tscn)
scripts/
  player/          player.gd — single simulation owner
  components/      spike, spring, breakable block, moving platform, checkpoint
                   scene_builder.gd — @tool ASCII map → scene
  autoload/        config_loader.gd — CSV parameter hot reload
  debug/           three headless regression suites
.claude/documents/ GDD, TDD, level design guide, asset library, parameter CSV
```

Levels can be authored as ASCII maps (`#` wall, `P` spawn, `S` spike, `B` breakable, `^` spring,
`M` moving platform, `C` checkpoint) and expanded by `SceneBuilder`.

### Status / roadmap

Grey-box; no art or audio yet. Next:

- M3 — a full level following the four-step (introduce / develop / twist / test) structure
- One or two original mechanics of my own design, beyond the reference set
- **Rewriting the controller core as a C++ GDExtension**, with the simulation kept free of any Godot
  dependency behind an abstract `CollisionQuery` interface, so the same code runs both inside the
  engine and inside millisecond-scale unit tests

---

## 中文

### 参考来源声明

本项目是**公开承认的学习性复刻**。移动参数与帧序逻辑参照 Maddy Thorson / Noel Berry 为 *Celeste*
公开的 `Player.cs`（`NoelFB/Celeste`），注释中以行号引用，使每一处行为都可回溯核对。

参考源码**不随本仓库分发**：它公开供学习但非开源许可，因此仅保留在本地（见 `.gitignore`）。
本仓库中的代码均由我编写。

### 我自己的贡献

移植本身不是重点，这三件才是：

1. **整数网格 → 浮点坐标的移植。** 参考实现跑在整数像素上，Godot 2D 物理跑在浮点上且默认
   `safe_margin` 为 `0.08`，这个差异会静默破坏贴墙判定与角落修正。定位过程产出两个刻意保留的
   常量 `CONTACT_MARGIN` 与 `SHAPE_INSET`（`scripts/player/player.gd:12-17`），每个都在原地
   注明了它修掉的具体故障。
2. **真物理 headless 回归套件** —— 82 条断言，真实实例化玩家并用 `Input.action_press` 逐物理帧驱动，
   另有关卡几何与组件两套。每个特性都经过**变异测试**验证：故意改坏参数或分支，确认对应断言变红，再回滚。
3. **按实测射程反推关卡几何。** 测试房的坑宽由实测跳跃距离反解（普通跳 ≈40px、Super ≈85px、
   Hyper ≈110px → 坑宽 80px），使一个房间在"没学会对应技巧"时**可证明地过不去**。
   一旦设计改动让这个前提失效，`room_regression.gd` 会直接报错。

### 工程记录（真正有用的部分）

| 问题 | 根因 | 处理 |
|---|---|---|
| 水平 Dash 期间 dash / 体力 / 土狼全都补不回来 | `is_on_floor()` 反映上一帧且依赖向下位移，而水平 Dash 没有向下位移 | 改为显式几何探针 `_on_ground()`（`scripts/player/player.gd`） |
| 抓墙时会在墙沿下滑一像素 | Godot 默认 `safe_margin` `0.08` 把"刚好贴上"也算命中，滑落探针落在墙面边界上 | 用 `move_and_collide` 配 `CONTACT_MARGIN = 0.001` 推到接触为止 |
| 8px 宽的身体钻不过 8px 宽的缝 | 整数坐标下是严丝合缝，浮点坐标要求亚像素对齐，角落修正找不到可行位置 | 物理盒内缩 1px（`SHAPE_INSET`），角落修正恢复稳定命中 |
| Super / Hyper / Ultra 触发不稳定 | 每帧有多个节点各写一次速度，且各自读到过期的碰撞事实 | 单一模拟所有者 + 固定帧序（见下） |

**固定帧序** —— 输入边沿采样 → 计时器 → pre-move 决策 → **一次** `move_and_slide` → 本帧碰撞事实
→ post-move 技巧判定。状态用单文件内的 `Mode` 枚举（`NORMAL / DASH / CLIMB`）而非自治状态节点，
与参考实现的单个 `State` 整数一致。理由记录在 `.claude/documents/TDD.md`。

### 功能

跑动 / 土狼时间 / 输入缓存 / 可变跳高 · 下蹲 · 八向 Dash（冻结帧采样方向、保速）· Dash Slide ·
Super / Hyper / Ultra · 墙跳 / SuperWallJump / 沿墙下滑 / 撞墙速度保留（Cornerboost）·
攀爬、爬墙跳、翻墙 hop、Wallboost、体力 · 上升与 Dash 角落修正 · 存盘点与即时复活。

数据驱动调参：所有手感参数均 `@export` 并镜像在 `.claude/documents/player_params.csv`，运行时按 `F5` 热重载。

### 运行

```bash
# 试玩
godot --path .

# 回归套件
godot --headless --path . --script res://scripts/debug/player_regression.gd     # 82 条物理断言
godot --headless --path . --script res://scripts/debug/room_regression.gd       # 关卡几何
godot --headless --path . --script res://scripts/debug/component_regression.gd  # 6 条组件检查
```

需要 Godot **4.7**。分辨率 320×180 整数缩放，8px 砖。

| 操作 | 按键 |
|---|---|
| 移动 | `A` / `D` 或方向键 |
| 跳跃 | `J` |
| 冲刺 | `K` |
| 抓 / 攀爬 | `Shift` |
| 从 CSV 重载参数 | `F5` |

测试房 `scenes/levels/test_room.tscn` 划分为 10 个分区，每区一个技巧，带屏幕提示与独立存盘点。

### 结构

```
scenes/            玩家、关卡、可复用组件（.tscn）
scripts/
  player/          player.gd —— 单一模拟所有者
  components/      尖刺、弹簧、可破坏方块、移动平台、存盘点
                   scene_builder.gd —— @tool，ASCII 地图 → 场景
  autoload/        config_loader.gd —— CSV 参数热重载
  debug/           三套 headless 回归
.claude/documents/ GDD、TDD、关卡设计指南、素材库、参数 CSV
```

关卡可用 ASCII 地图书写（`#` 墙、`P` 出生点、`S` 尖刺、`B` 可破坏、`^` 弹簧、`M` 移动平台、
`C` 存盘点），由 `SceneBuilder` 展开。

### 当前状态与路线

灰盒阶段，暂无美术与音效。下一步：

- M3 —— 按"起承转合"结构完成一个完整关卡
- 1~2 个超出参考范围、由我自己设计的原创机制
- **将控制器核心重写为 C++ GDExtension**：模拟层通过抽象接口 `CollisionQuery` 与 Godot 完全解耦，
  使同一份代码既能跑在引擎里、也能跑在毫秒级单元测试里
