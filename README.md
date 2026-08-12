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

### Tools I used

I use AI assistants the same way I use a debugger or Stack Overflow — as a **tool, not an author**:
looking up Godot API behaviour and reference material, reviewing code I had already written, and
helping narrow down bugs (the `safe_margin` one took a lot of back and forth). Design decisions, the
frame ordering, the parameter tuning and the test suite are mine, and I can explain why every line is
there.

Anything I couldn't explain in an interview doesn't belong in this repo, so that's the line I hold.

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
`docs/TDD.md`.

### What's in it

Run, coyote time, jump buffering, variable jump height, ducking, 8-direction dash (direction sampled
after the freeze frames, speed retained), Dash Slide, Super / Hyper / Ultra, wall jump,
SuperWallJump, wall slide, wall speed retention (Cornerboost), climb / climb jump / climb hop /
Wallboost with stamina, upward and dash corner correction, checkpoints with instant respawn.

Feel parameters are all `@export`ed and mirrored in `docs/player_params.csv`, which I
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
docs/ design notes, tech notes, level design notes, parameter CSV
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

Godot 4.7 + GDScript 写的 2D 平台跳跃角色控制器，一套完整的 Celeste 式移动系统：
八向 Dash、抓墙攀爬、Super / Hyper / Ultra、角落修正、土狼时间、输入缓存。

目前为灰盒阶段，只有一个练习关。没有美术和音乐部分

本人大三在读，这是做的第一个游戏项目。

### 为什么做这个

一开始只是想弄明白一件事：为什么 Celeste 跳起来那么舒服，自己随手写的角色控制就是一坨。

真上手才发现，手感这东西根本不是"调参调到爽"就完事了。参数一多，改 A 坏 B 是常态，
而且坏了往往当场察觉不到 —— 等你发现 Ultra 触发不了，可能是三天前改抓墙的时候改坏的。
所以后半程的重点从"写功能"变成了"怎么让手感可回归"：给它配了一套 headless 物理测试，
82 条断言，直接把玩家场景实例化出来逐帧喂输入，功能改坏了立刻报红。

我觉得这套测试比控制器本身有意思。

### 关于参考来源

这是**学习性质的复刻**，移动参数和帧序都照 Celeste 作者公开的 `Player.cs`
（`NoelFB/Celeste`）来的，`player.gd` 的注释里标了对应行号，方便边写边对。

那份源码本身没进仓库 —— 它虽然公开，但不是开源许可，所以只留在本地（见 `.gitignore`）。
仓库里的代码都是我自己敲的。

### 关于 AI 工具

我把 AI 当**工具**用，跟用调试器、翻 Stack Overflow 是一个性质：查 Godot API 的实际行为、
找参考资料、review 我已经写完的代码、以及帮我缩小 bug 范围（`safe_margin` 那个坑来回问了很久）。
设计决策、帧序怎么定、参数怎么调、测试怎么写，这些是我自己的，每一行为什么在那儿我都讲得出来。

自己讲不清的东西不该留在仓库里，这是我给自己划的线。

### 快速开始

需要 Godot 4.7。视口 320×180、整数缩放、一砖 8px。

```bash
# 试玩
godot --path .

# 三套 headless 测试
godot --headless --path . --script res://scripts/debug/player_regression.gd     # 82 条物理断言
godot --headless --path . --script res://scripts/debug/room_regression.gd       # 关卡几何
godot --headless --path . --script res://scripts/debug/component_regression.gd  # 6 条组件检查
```

| 操作 | 按键 |
|---|---|
| 移动 | `A` / `D` 或方向键 |
| 跳 | `J` |
| 冲刺 | `K` |
| 抓墙 | `Shift` |
| 重载 CSV 参数 | `F5` |

进游戏就是测试房（`scenes/levels/test_room.tscn`），横向分 10 个区，一区练一个技巧：
跑跳土狼 → 下蹲低通道 → Dash → Super → Hyper / Wavedash → Ultra → 墙跳 → 攀爬 →
角落修正 → Cornerboost。每区头顶有提示文字，各自带存盘点，掉坑立刻回本区重来。

### 实现上的两个关键决定

**模拟只留一个所有者，帧序定死。** 最早我是按教程那套拆状态节点写的，Idle / Run / Air 各一个脚本，
各自往 `velocity` 里写。结果 Super / Hyper / Ultra 大概一半概率触发不了：同一帧里好几处都在改速度，
而且各自读到的碰撞数据还是上一帧的。后来全推掉，帧序在 `player.gd` 里定死：

```
采输入边沿 → 走计时器 → 做决策 → move_and_slide（只调一次） → 读本帧碰撞 → 判落地后能接什么技巧
```

状态退化成一个 `Mode` 枚举（`NORMAL / DASH / CLIMB`）。代价是 `player.gd` 涨到 781 行，
但那类时序 bug 一次性绝迹了。为什么这么选记在 `docs/TDD.md`。

**参数全部外置。** 所有手感参数都 `@export`，同时在 `docs/player_params.csv`
存一份，游戏里按 `F5` 热重载。调重力和跳跃初速这种东西，来回重启太耗耐心。

### 踩坑记录

**1. `is_on_floor()` 在水平 Dash 期间一直是 false**

表现是地面 Dash 的时候 dash 次数、体力、土狼时间全都补不回来。原因有两层：
`is_on_floor()` 拿的是上一帧 `move_and_slide` 的结果，而且它要求这一帧有向下位移，
水平 Dash 压根不往下走。最后没用它，自己写了个 `_on_ground()` 几何探针，主动往下探一格。

**2. Godot 的 `safe_margin` 有 0.08，"刚贴上"就算撞到**

抓墙的时候人会顺着墙沿往下滑一像素 —— 因为判定"手是否已过墙沿"的探针刚好落在墙面边界上，
被算成命中了。改成用 `move_and_collide` 配 `CONTACT_MARGIN = 0.001`，一路推到真正贴住为止。

**3. 8px 宽的身体钻不过 8px 宽的缝**

参考实现里坐标是整数，8 进 8 是严丝合缝刚好过；Godot 里是浮点，同宽就要求亚像素级对齐，
角落修正逐像素找位置基本永远找不到。解法是把物理盒内缩 1px（`SHAPE_INSET`），给一砖缝留出余量。

这两个常量在 `scripts/player/player.gd:12-17`，理由写注释了。

**4. 我的第一版测试是假的**

它直接调函数，断言的又是我刚写下的那几个数，所以随便怎么改都能过。
后来发现游戏明明已经坏了它还全绿，整个推掉重写成真实物理驱动。
现在加完一个功能，我会先把某个参数或分支改坏，看着对应断言变红了，才确保这条测试有用。

### 目录结构

```
scenes/            玩家、关卡、可复用组件（.tscn）
scripts/
  player/          player.gd —— 模拟逻辑全在这
  components/      尖刺、弹簧、可破坏方块、移动平台、存盘点
                   scene_builder.gd —— @tool，拿 ASCII 地图直接生成场景
  autoload/        config_loader.gd —— CSV 参数热重载
  debug/           三个 headless 测试脚本
docs/ 策划案、技术方案、关卡设计笔记、参数 CSV
```

摆关卡除了在编辑器里拖，也能直接写 ASCII 图，交给 `SceneBuilder` 展开：

```
................
..........P.....
..S..B..^..C....     # S 尖刺  B 可破坏  ^ 弹簧  C 存盘点  P 出生点
################     # # 墙体（连续段自动合并）  . 空
```

### 已知问题


- `player.gd` 781 行一个文件。有理由，但确实太挤，想加个新模式得来回改好几段。
- 相机是硬跟随，没平滑、没前瞻、没有房间边界。
- 测试只覆盖数值，覆盖不了手感。除我之外没人玩过，那些高级技巧对新手来讲顺不顺手有待确认。
- 策划案里的死亡热力图和 Assist Mode 都还没做。
- 没有菜单、暂停、设置，手柄也没支持。
- 组件都很简陋，比如移动平台只能在一个轴上来回走。
- 早期把整套参数缩放到 15px 网格上折腾了好几轮，后来发现沿用参考的 8px 砖省事得多，
  （git 历史里有一段就是我在往回改。

### 接下来

- M3：做一个真关卡，围绕一个机制按"起承转合"铺开，而不是现在这种技巧陈列室
- 加一两个自己想的机制，不能全是参考里那些
- 把控制器核心用 **C++ GDExtension** 重写：模拟层靠 `CollisionQuery` 抽象接口跟 Godot 类型脱开，
  同一份代码既能在引擎里跑，也能在不开引擎的单元测试里跑
