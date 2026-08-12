# Plantformer Demo

A 2D platformer character controller in **Godot 4.7 (GDScript)**. I rebuilt *Celeste*'s movement
system to learn how precision platformers actually work, and then wrote a headless test suite for it
because tuning by feel alone kept breaking things I had already fixed.

Still grey-box: coloured rectangles, no art, no audio, no real level yet.

I'm a third-year software engineering undergrad and this is my first serious game project, so parts
of it are rough — see [Known issues](#known-issues) / [已知问题](#已知问题).

[English](#english) · [中文](#中文)

---

## English

### Where the design comes from

This is a **learning reimplementation**, and I want to be upfront about that. The movement constants
and the frame ordering follow the `Player.cs` source that the *Celeste* authors published
(`NoelFB/Celeste`). Comments in `player.gd` cite it by line number so I could check my behaviour
against the original while working.

I don't include that source file in this repo. It's public for study but not under an open-source
license, so I keep it locally only (see `.gitignore`). Everything committed here is written by me.

### What I actually worked on

Copying numbers is easy. These are the parts that took real time:

**1. Integer coordinates → floats.** The reference runs on integer pixel positions. Godot's 2D
physics uses floats and a default `safe_margin` of `0.08`, which counts "just touching" as a
collision. That quietly broke wall grabbing and corner correction in ways that looked like logic
bugs. It took me a while to realise the logic was fine and the margin was the problem. The two
constants at `scripts/player/player.gd:12-17` (`CONTACT_MARGIN`, `SHAPE_INSET`) are what came out of
it, and I left the reasoning in the comments so I wouldn't "clean them up" later and break it again.

**2. Headless physics tests.** 82 assertions that instantiate the real player scene and drive it with
`Input.action_press`, one physics frame at a time, plus smaller suites for level geometry and
components. My first version of these was fake — it called functions directly and asserted on
numbers I had just written, so it passed no matter what. I rewrote it after noticing it stayed green
while the game was visibly broken. Now, whenever I add a feature, I break a parameter on purpose
first and check that the matching assertion turns red before trusting it.

**3. Pit widths from measured distances.** In the test room the gaps are sized from distances I
measured in-engine: normal jump ≈ 40 px, jump + air dash ≈ 65 px, Super ≈ 85 px, Hyper ≈ 110 px. So a
10-tile (80 px) gap should only be crossable with the technique that zone teaches.
`room_regression.gd` re-checks this, because I had already broken it once by editing zone layout
without re-measuring.

### Problems worth writing down

| Symptom | What was actually wrong | Fix |
|---|---|---|
| Dash, stamina and coyote time never refilled during a ground dash | `is_on_floor()` reflects the previous frame and needs downward movement, which a horizontal dash doesn't have | Wrote an explicit `_on_ground()` geometry probe instead |
| Wall grab slipped one pixel below the ledge | the default `0.08` safe margin made the slip probe land exactly on the wall boundary | snap to contact with `move_and_collide` and `CONTACT_MARGIN = 0.001` |
| An 8 px wide body couldn't fit through an 8 px gap | exact fit on integers, sub-pixel alignment on floats, so corner correction never found a free spot | shrink the physics box by 1 px (`SHAPE_INSET`) |
| Super / Hyper / Ultra worked maybe half the time | several nodes were writing `velocity` in the same frame, each reading stale collision data | one owner for the simulation, fixed frame order |

The frame order is now: sample input edges → tick timers → decide → **one** `move_and_slide` → read
this frame's collisions → arm post-landing techniques. State is a `Mode` enum
(`NORMAL / DASH / CLIMB`) inside `player.gd`, roughly like the single `State` integer in the
reference. I originally had separate state node scripts and deleted them; my notes on why are in
`.claude/documents/TDD.md`.

### What's in it

Run, coyote time, jump buffering, variable jump height, ducking, 8-direction dash (direction sampled
after the freeze frames, speed retained), Dash Slide, Super / Hyper / Ultra, wall jump,
SuperWallJump, wall slide, wall speed retention (Cornerboost), climb / climb jump / climb hop /
Wallboost with stamina, upward and dash corner correction, checkpoints with instant respawn.

Feel parameters are all `@export`ed and mirrored in `.claude/documents/player_params.csv`, which I
can reload at runtime with `F5` so I don't have to restart while tuning.

### Running it

```bash
# play
godot --path .

# tests
godot --headless --path . --script res://scripts/debug/player_regression.gd     # 82 physics assertions
godot --headless --path . --script res://scripts/debug/room_regression.gd       # level geometry
godot --headless --path . --script res://scripts/debug/component_regression.gd  # 6 component checks
```

Needs Godot **4.7**. 320×180 viewport with integer scaling, 8 px tiles.

| Action | Key |
|---|---|
| Move | `A` / `D` or arrows |
| Jump | `J` |
| Dash | `K` |
| Grab / climb | `Shift` |
| Reload parameters from CSV | `F5` |

`scenes/levels/test_room.tscn` is split into 10 zones, one technique each, with a hint label and its
own checkpoint.

### Layout

```
scenes/            player, levels, reusable components (.tscn)
scripts/
  player/          player.gd — all of the simulation
  components/      spike, spring, breakable block, moving platform, checkpoint
                   scene_builder.gd — @tool, builds a scene from an ASCII map
  autoload/        config_loader.gd — CSV parameter reload
  debug/           the three headless test scripts
.claude/documents/ design notes, tech notes, level design notes, parameter CSV
```

Levels can also be written as ASCII (`#` wall, `P` spawn, `S` spike, `B` breakable, `^` spring,
`M` moving platform, `C` checkpoint) and expanded by `SceneBuilder`.

### Known issues

Things I know are wrong or missing, rather than pretending they aren't:

- `player.gd` is one 781-line file. I have a reason for it (a single owner fixed the ordering bugs
  above) but it's still a lot in one place, and adding a new mode means touching several sections.
- The camera is a plain follow with no smoothing, no look-ahead and no room bounds, so it jitters
  during dashes.
- The tests check numbers, not feel. Nobody except me has played this, so I don't really know if the
  advanced techniques are comfortable for someone who hasn't practised them.
- The death heatmap and assist mode in my design notes aren't implemented yet.
- No menu, no pause, no settings, no gamepad support.
- Components are minimal — the moving platform only goes back and forth on one axis, for example.
- I spent a while rescaling everything to a 15 px grid before realising it was easier to keep the
  reference's 8 px tiles, so some of the git history is me undoing that.

### Next

- M3: an actual level, built around one mechanic in the introduce → develop → twist → test shape
- one or two mechanics of my own instead of only reference ones
- rewrite the controller core as a **C++ GDExtension**, keeping the simulation free of Godot types
  behind a `CollisionQuery` interface, so it can run both in the engine and in plain unit tests

---

## 中文

### 设计来源

这是一个**学习性复刻**，我想先把这点说清楚。移动参数和帧序参照 *Celeste* 作者公开的 `Player.cs`
（`NoelFB/Celeste`），`player.gd` 的注释里用行号引用，方便我边写边和原实现对照。

参考源码本身没放进仓库。它是公开供学习的，但不是开源许可，所以只留在本地（见 `.gitignore`）。
仓库里提交的代码都是我自己写的。

### 我真正花时间的地方

抄数值不难，难的是这几块：

**1. 整数坐标搬到浮点。** 参考实现的位置是整数像素，Godot 2D 物理用浮点，而且默认 `safe_margin`
是 `0.08`，"刚好贴上"也算碰到。这件事静默地弄坏了抓墙和角落修正，但表现出来像逻辑 bug。
我折腾了挺久才反应过来逻辑没错、是边距的问题。`scripts/player/player.gd:12-17` 的两个常量
（`CONTACT_MARGIN`、`SHAPE_INSET`）就是这么来的，理由我写在注释里，怕以后自己手贱"整理掉"再踩一遍。

**2. Headless 物理测试。** 82 条断言，真实实例化玩家场景，用 `Input.action_press` 逐物理帧驱动，
另外还有关卡几何和组件两套小的。我第一版测试是假的：直接调函数、断言我刚写下的那些数，所以怎么改都过。
后来发现游戏明显坏了它还全绿，就整个重写了。现在每加一个功能，我会先故意把某个参数改坏，
确认对应断言变红，才敢相信它。

**3. 坑宽用实测距离定。** 测试房的坑是按我在引擎里量出来的距离定的：普通跳 ≈40px、跳+空中冲 ≈65px、
Super ≈85px、Hyper ≈110px。所以 10 砖（80px）的坑，理论上只有本区教的技巧能过去。
`room_regression.gd` 会重新检查这件事，因为我之前改分区布局时没重新量，已经弄坏过一次。

### 值得记下来的问题

| 现象 | 实际原因 | 处理 |
|---|---|---|
| 地面 Dash 期间 dash / 体力 / 土狼时间都补不回来 | `is_on_floor()` 反映上一帧、且依赖向下位移，水平 Dash 没有 | 自己写了 `_on_ground()` 几何探针 |
| 抓墙会在墙沿下滑一像素 | 默认 `0.08` 安全边距让滑落探针正好落在墙面边界上 | `move_and_collide` 配 `CONTACT_MARGIN = 0.001` 推到接触 |
| 8px 宽的身体过不去 8px 宽的缝 | 整数下是严丝合缝，浮点下要亚像素对齐，角落修正找不到空位 | 物理盒内缩 1px（`SHAPE_INSET`） |
| Super / Hyper / Ultra 大概一半的概率触发 | 同一帧里好几个节点都在写 `velocity`，各自读到过期的碰撞数据 | 模拟只留一个所有者，帧序固定 |

现在的帧序：采样输入边沿 → 走计时器 → 做决策 → **只调用一次** `move_and_slide` → 读本帧碰撞
→ 武装落地后的技巧。状态是 `player.gd` 里的 `Mode` 枚举（`NORMAL / DASH / CLIMB`），
大致对应参考实现里那个单独的 `State` 整数。我一开始写的是分散的状态节点脚本，后来删掉了，
原因记在 `.claude/documents/TDD.md`。

### 做了哪些东西

跑动、土狼时间、输入缓存、可变跳高、下蹲、八向 Dash（方向在冻结帧之后才采样、保速）、Dash Slide、
Super / Hyper / Ultra、墙跳、SuperWallJump、沿墙下滑、撞墙速度保留（Cornerboost）、
攀爬 / 爬墙跳 / 翻墙 hop / Wallboost 与体力、上升和 Dash 两种角落修正、存盘点与即时复活。

手感参数全部 `@export`，并镜像在 `.claude/documents/player_params.csv`，运行时按 `F5` 重载，
调参不用重启。

### 怎么跑

```bash
# 试玩
godot --path .

# 测试
godot --headless --path . --script res://scripts/debug/player_regression.gd     # 82 条物理断言
godot --headless --path . --script res://scripts/debug/room_regression.gd       # 关卡几何
godot --headless --path . --script res://scripts/debug/component_regression.gd  # 6 条组件检查
```

需要 Godot **4.7**。视口 320×180 整数缩放，8px 砖。

| 操作 | 按键 |
|---|---|
| 移动 | `A` / `D` 或方向键 |
| 跳跃 | `J` |
| 冲刺 | `K` |
| 抓 / 攀爬 | `Shift` |
| 从 CSV 重载参数 | `F5` |

`scenes/levels/test_room.tscn` 分成 10 个区，一区一个技巧，带提示文字和各自的存盘点。

### 目录

```
scenes/            玩家、关卡、可复用组件（.tscn）
scripts/
  player/          player.gd —— 所有模拟逻辑
  components/      尖刺、弹簧、可破坏方块、移动平台、存盘点
                   scene_builder.gd —— @tool，用 ASCII 地图生成场景
  autoload/        config_loader.gd —— CSV 参数重载
  debug/           三个 headless 测试脚本
.claude/documents/ 策划、技术、关卡设计笔记，参数 CSV
```

关卡也可以直接写成 ASCII（`#` 墙、`P` 出生点、`S` 尖刺、`B` 可破坏、`^` 弹簧、`M` 移动平台、
`C` 存盘点），由 `SceneBuilder` 展开。

### 已知问题

明知有问题的地方，不装作没有：

- `player.gd` 是一个 781 行的单文件。我有理由（单一所有者修掉了上面那些时序 bug），
  但确实太多东西挤在一处，加新模式得改好几段。
- 相机就是普通跟随，没做平滑、没有前瞻、没有房间边界，冲刺时会晃。
- 测试测的是数值，不是手感。除了我自己没人玩过，所以那些高级技巧对没练过的人是否舒服，我心里没数。
- 策划笔记里写的死亡热力图和 Assist Mode 都还没做。
- 没有菜单、暂停、设置，也没做手柄支持。
- 组件都很简单，比如移动平台只能在单轴上来回走。
- 我花了不少时间把所有东西缩放到 15px 网格，后来才发现直接沿用参考的 8px 砖更省事，
  所以 git 历史里有一段是我在撤销这件事。

### 接下来

- M3：做一个真正的关卡，围绕一个机制按"起 → 承 → 转 → 合"展开
- 加一两个自己设计的机制，不只是参考里的那些
- 把控制器核心用 **C++ GDExtension** 重写，模拟部分通过 `CollisionQuery` 接口和 Godot 类型解耦，
  这样同一份代码既能在引擎里跑，也能在普通单元测试里跑
