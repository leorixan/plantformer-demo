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

用 Godot 4.7 + GDScript 写的 2D 平台跳跃角色控制器。想搞明白硬核平台跳跃的手感到底是怎么调出来的，
就把 Celeste 的移动系统照着重写了一遍，后来又给它配了一套 headless 测试 —— 因为纯靠手感调参，
老是修好一个又碰坏另一个。

目前还是灰盒，纯色块，没美术没音效，也还没有真正的关卡。

我大三在读，这是第一个正经做的游戏项目，好多地方挺糙的，具体见[已知问题](#已知问题)。

### 参考了什么

先把来源说清楚：这是**学习性质的复刻**。移动参数和帧序都是照 Celeste 作者公开的 `Player.cs`
（`NoelFB/Celeste`）来的，`player.gd` 的注释里标了行号，方便我边写边对。

那份源码没放进仓库。它虽然公开，但不是开源许可，所以只留在本地（见 `.gitignore`）。
仓库里提交的代码都是我自己写的。

### 主要时间花在哪

数值照抄不费劲，真正耗时间的是这几块。

**一、从整数坐标搬到浮点。** 参考实现的位置全是整数像素，Godot 的 2D 物理是浮点，而且默认
`safe_margin` 有 0.08，"刚贴上"就算撞到了。抓墙和角落修正就是这么被悄悄搞坏的，
但看起来特别像逻辑写错了。我查了半天才反应过来逻辑没问题，是边距的事。
`scripts/player/player.gd:12-17` 那两个常量（`CONTACT_MARGIN`、`SHAPE_INSET`）就是这么来的。
理由我都写在注释里了，免得过段时间自己手贱当垃圾清掉，再踩一遍。

**二、headless 物理测试。** 82 条断言，真的把玩家场景实例化出来，用 `Input.action_press`
一帧一帧喂输入，另外还有关卡几何和组件两套小的。第一版测试其实是假的：直接调函数，
断言的又是我刚写下的那些数，所以随便怎么改都能过。后来发现游戏明显都坏了它还全绿，
干脆整个推掉重写。现在每加一个功能，我都先故意把某个参数改坏，看着对应的断言变红了，才敢信它。

**三、坑宽是量出来的，不是拍出来的。** 测试房里每个坑的宽度都按引擎里实测的距离定：
普通跳 40px 左右，跳+空中冲 65px，Super 85px，Hyper 110px。所以 10 砖（80px）的坑，
理论上只有本区教的那个技巧过得去。`room_regression.gd` 会再核一遍这件事 ——
之前我改分区布局忘了重新量，已经把坑宽弄失效过一次。

### 记几个印象深的问题

| 现象 | 真正的原因 | 怎么解决 |
|---|---|---|
| 地面 Dash 的时候 dash 次数、体力、土狼时间全都补不回来 | `is_on_floor()` 拿到的是上一帧的结果，还得有向下位移才算，而水平 Dash 根本不往下走 | 自己写了个 `_on_ground()` 几何探针，不用它了 |
| 抓墙的时候会顺着墙沿往下滑一像素 | 默认 0.08 的安全边距让滑落探针刚好落在墙面边界上 | 用 `move_and_collide` 配 `CONTACT_MARGIN = 0.001`，一路推到真正贴住 |
| 8px 宽的身体钻不过 8px 宽的缝 | 整数下是严丝合缝刚好过，浮点下得亚像素对齐，角落修正压根找不到空位 | 物理盒内缩 1px（`SHAPE_INSET`） |
| Super / Hyper / Ultra 大概一半概率触发不了 | 同一帧里好几个节点都在写 `velocity`，各自读到的碰撞数据还是过期的 | 模拟只留一个所有者，帧序定死 |

现在的帧序是：采输入边沿 → 走计时器 → 做决策 → `move_and_slide` **只调一次** → 读本帧的碰撞
→ 再判落地后能接什么技巧。状态就是 `player.gd` 里一个 `Mode` 枚举（`NORMAL / DASH / CLIMB`），
跟参考实现里那个单独的 `State` 整数思路差不多。一开始我是拆成好几个状态节点脚本写的，后来删了，
为什么删记在 `.claude/documents/TDD.md`。

### 做了些什么

跑动、土狼时间、输入缓存、可变跳高、下蹲、八向 Dash（方向等冻结帧结束才采、保速）、Dash Slide、
Super / Hyper / Ultra、墙跳、SuperWallJump、贴墙下滑、撞墙速度保留（Cornerboost）、
抓墙攀爬 / 爬墙跳 / 翻墙 hop / Wallboost 和体力、上升和 Dash 两种角落修正、存盘点和即时复活。

手感参数全都 `@export` 了，同时在 `.claude/documents/player_params.csv` 里存一份，
游戏里按 `F5` 就能重载，调参不用来回重启。

### 怎么跑

```bash
# 试玩
godot --path .

# 测试
godot --headless --path . --script res://scripts/debug/player_regression.gd     # 82 条物理断言
godot --headless --path . --script res://scripts/debug/room_regression.gd       # 关卡几何
godot --headless --path . --script res://scripts/debug/component_regression.gd  # 6 条组件检查
```

需要 Godot 4.7。视口 320×180，整数缩放，一砖 8px。

| 操作 | 按键 |
|---|---|
| 移动 | `A` / `D` 或方向键 |
| 跳 | `J` |
| 冲刺 | `K` |
| 抓墙 | `Shift` |
| 重载 CSV 参数 | `F5` |

`scenes/levels/test_room.tscn` 分了 10 个区，一区练一个技巧，都带提示文字和自己的存盘点。

### 目录

```
scenes/            玩家、关卡、可复用的组件（.tscn）
scripts/
  player/          player.gd —— 所有模拟逻辑都在这
  components/      尖刺、弹簧、可破坏方块、移动平台、存盘点
                   scene_builder.gd —— @tool，拿 ASCII 地图生成场景
  autoload/        config_loader.gd —— CSV 参数重载
  debug/           三个 headless 测试脚本
.claude/documents/ 策划、技术、关卡设计的笔记，参数 CSV
```

关卡也能直接写成 ASCII（`#` 墙、`P` 出生点、`S` 尖刺、`B` 可破坏、`^` 弹簧、`M` 移动平台、
`C` 存盘点），交给 `SceneBuilder` 展开。

### 已知问题

自己知道有毛病的地方，就不装看不见了：

- `player.gd` 一个文件 781 行。我有我的理由（就是靠单一所有者才修掉上面那些时序 bug），
  但确实太挤了，想加个新模式得来回改好几段。
- 相机就是硬跟随，没做平滑、没有前瞻、也没有房间边界，一冲刺就晃。
- 测试只能测数值，测不了手感。除我之外没人玩过，那些高级技巧对没练过的人到底顺不顺手，我心里没底。
- 策划笔记里写的死亡热力图和 Assist Mode 都还没做。
- 没有菜单、暂停、设置，手柄也没支持。
- 组件都很简陋，比如移动平台只能在一个轴上来回走。
- 早期我把所有东西缩放到 15px 网格上折腾了好一阵，后来发现还是沿用参考的 8px 砖省事，
  所以 git 历史里有一段就是我在往回改。

### 接下来

- M3：做一个真的关卡，围绕一个机制按"起承转合"铺开
- 加一两个自己想的机制，不要全是参考里那些
- 把控制器核心用 **C++ GDExtension** 重写一遍，模拟部分靠 `CollisionQuery` 接口跟 Godot 类型脱开，
  这样同一份代码既能在引擎里跑，也能在普通单元测试里跑
