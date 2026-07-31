# Plantformer Demo — 技术方案文档 (TDD)

> 对应策划案：`documents/GDD.txt` v1.0
> 文档版本：v1.0 | 2026-07-30
> 引擎：Godot 4.7（Forward Plus，GDScript）| 平台：PC

---

## 1. 技术目标

| 目标 | 对应 GDD 条目 | 技术手段 |
|---|---|---|
| 低上手门槛、高操作上限 | 1.1 核心概念 | 简洁输入 + 进阶技巧由基础操作组合涌现 |
| 手感深度可调 | 1.3 手感微调控制 | 全部手感参数 `@export` 化 + 调试仪表盘 |
| 高解耦、易扩展 | 1.3 基于FSM的架构 | 节点式 FSM 角色控制器 |
| 即时复活 | 1.2 即时复活 | 检查点 + 零延迟重生，无死亡惩罚 |
| 数据驱动设计 | 4.2 死亡热力图 | 死亡坐标记录 → JSON → 热力图 |
| 可访问性 | 4.3 辅助模式 | Assist Mode（游戏速度、无限冲刺等） |

---

## 2. 目录结构

```
res://
├── project.godot
├── scenes/                  # 所有场景
│   ├── main.tscn            # 主场景（启动入口，加载当前关卡）
│   ├── player/player.tscn   # 玩家（CharacterBody2D + FSM）
│   ├── levels/              # 关卡（level_01.tscn, ...）
│   └── components/          # 可复用机关：spikes, spring, checkpoint, theo, jellyfish...
├── scripts/
│   ├── player/
│   │   └── player.gd        # 单一模拟所有者，内含 Mode 状态机（见 §4.1）
│   ├── components/          # 机关脚本，与场景一一对应
│   ├── autoload/            # game.gd, assist.gd
│   └── debug/               # player_regression.gd（headless 物理回归）
├── assets/
│   ├── sprites/  audio/  fonts/   # 灰盒阶段用占位色块（PlaceholderTexture / ColorRect）
└── documents/               # GDD.txt, TDD.md（本文件）
```

原则：**场景与脚本分离**（scenes/ 与 scripts/ 平行），机关做成可复用的独立场景，关卡只负责摆放组合。

---

## 3. Autoload 设计（保持精简，仅 2 个）

| Autoload | 职责 | 关键接口 |
|---|---|---|
| `Game` | 检查点记录、即时复活、死亡次数/坐标统计、关卡切换 | `set_checkpoint(pos)` / `respawn()` / `record_death(pos)` / 信号 `player_died(pos)` |
| `Assist` | 辅助模式设置（全局生效） | `speed_scale: float` / `infinite_dash: bool` / `apply()`（写 Engine.time_scale） |

> 不引入全局 EventBus。跨节点通信优先用 Godot 信号直连；`Game.player_died` 是唯一需要的全局信号（供死亡统计、特效、音效订阅）。

---

## 4. 角色控制器：Player 单一模拟所有者（Mode 状态机）

### 4.1 架构

```
Player (CharacterBody2D, player.gd)          # 唯一写 velocity 的地方
├── Visuals (Node2D) / CollisionShape2D
├── UI (DashPip1..3 + StaminaBar/Fill)       # 冲刺次数 + 体力条视觉指示器
├── CarryAnchor (Marker2D)                   # 持物跟随点
├── GrabDetector (Area2D)                    # 探测附近可抓取物品
├── Camera2D
└── ControllerDebug (Label)                  # show_controller_debug 打开
```

对齐 Celeste `Player.cs`：Celeste 的 `StateMachine` 只是 Player 内部的 `int State` + 回调表，
**不是独立节点树**。原先的 `states/*.gd` 子节点方案会让多个节点在同一帧各写一次 `velocity`，
并读到上一帧的 `is_on_floor()`，Super/Hyper/Ultra 因此永远无法稳定触发。故已删除
`scripts/player/states/`，改为 Player 内 `enum Mode { NORMAL, DASH, CLIMB }`：

- `_normal_update` / `_dash_update` / `_climb_update` 一一对应参考的 `NormalUpdate` / `DashUpdate` / `ClimbUpdate`。
- 固定帧序（`_physics_process`）：采样输入 → 计时器 → 状态更新 → **一次** `move_and_slide()` → `_resolve_collisions()`。
- 碰撞派生结论（落地、角落修正、Dash Slide）只在 `_resolve_collisions()` 里基于**本帧**碰撞事实做，不读上一帧状态。
- 扩展新机制 = 加一个 `Mode` 分支 + 一个 `_xxx_update`，不影响既有分支。

### 4.2 手感系统（全部 @export 参数化 + CSV 集中配置）

手感参数除在 `player.gd` 中保留 `@export` 默认值外，**集中管理在 `documents/player_params.csv`**：

- 可用 **Excel / 任何表格软件** 打开编辑（标准 CSV 逗号分隔，UTF-8）。
- 运行时由 `ConfigLoader` autoload 读取并覆盖到 Player。
- 游戏中按 **F5** 即可重新加载 CSV 并应用，无需重启 Godot。
- **数值基准**：Celeste 用 8px 砖，本项目用 15px 格，所以所有像素类参数 = **Celeste 原值 × 1.875**，
  时间类参数（`*_time`、`dash_duration` 等）与倍率类参数（`*_mult`）原样照搬。
  按住跳实测跳高 **53.5px ≈ 3.6 格**，与 Celeste 的 3.4 砖手感一致。

CSV 列：`category, name, value, type, description`。当前包含：

| 分类 | 参数 | 说明 |
|---|---|---|
| Movement | `max_speed` / `acceleration` / `over_speed_decel` / `air_accel_mult` | 对应 MaxRun / RunAccel / RunReduce / AirMult |
| Movement | `duck_friction` | Dash Slide 后下蹲滑行的地面摩擦 |
| Jump | `jump_speed` / `jump_speed_boost` / `var_jump_time` / `coyote_time` / `jump_buffer_time` / `ceiling_var_jump_grace` | 起跳、水平加成、可变跳高、土狼、缓存 |
| Gravity | `gravity` / `max_fall_speed` / `half_gravity_threshold` | 顶点半重力（按住跳时） |
| Dash | `dash_speed` / `dash_end_speed` / `end_dash_up_mult` / `dash_duration` / `dash_cooldown` / `dash_attack_time` / `dash_buffer_time` | 冲刺本体 |
| Dash | `super_jump_speed` / `dodge_slide_speed_mult` / `duck_super_jump_x_mult` / `duck_super_jump_y_mult` | Super / Hyper / Ultra |
| Dash | `super_wall_jump_speed` / `super_wall_jump_horizontal` | 上冲刺撞墙的 SuperWallJump |
| Climb | `max_stamina` / `climb_*_speed` / `climb_acceleration` / `climb_*_stamina_cost` / `climb_check_distance` / `slip_check_depth` / `wall_check_distance` / `wall_jump_speed` / `climb_hop_x` / `climb_hop_y` | 墙抓攀爬与墙跳 |
| Feel | `corner_correction_px` / `dash_corner_correction_px` | 上升撞顶修正 / 空中 Dash 撞地角修正 |
| Carry | `throw_speed` / `throw_lift` | 抛物 |

手感机制实现要点：
- **土狼时间**：离开平台边缘后计时器内仍允许起跳。
- **输入缓存**：跳跃/冲刺输入在 `_physics_process` 里采样（`is_action_just_pressed`），一帧一次判定，落地瞬间自动起跳。
- **可变跳高**：照搬参考的 `varJumpTimer` —— 按住跳时 `velocity.y = min(velocity.y, varJumpSpeed)` 维持 `var_jump_time`，松手立即清零。这是跳高的主要来源，不是 `jump_cut_mult`。
- **角落修正**：参考 `Player.cs` 的 `OnCollideV`。上升撞顶时用**移动前**的 `vy` 判定，逐像素探测 **(±i, -1)** 是否为空并整体平移；修正失败才按 `ceiling_var_jump_grace` 掐掉可变跳。另有 `DashCornerCorrection`：空中起手的 Dash 撞地角时横移让位（`dash_started_on_ground` 为 false 才生效）。
- **无落地硬直**：落地不打断输入，保证响应度。


### 4.3 冲刺（Dash）

- 8 向（读 `move_*` 四方向输入组合），无方向输入时默认朝面向。
- 流程：触发 → `dash_freeze_frames` 冻结 → 固定速度直线冲 `dash_duration` → 回到 Air。
- 落地刷新次数；`Assist.infinite_dash` 开启时无限。
- 冲刺期间关闭重力。

### 4.4 抓（Grab）：墙抓攀爬

按 Celeste 式**墙抓/攀爬/墙跳**设计（已确认）：按住 grab 贴墙 → Climb 模式 → 跳跃键弹出。
**持有物品期间禁用墙抓**（手被占用）——抛出物品后才能抓墙，这是"抛接"技巧循环的核心。

对齐参考 `ClimbBegin` / `ClimbUpdate`（3056 / 3102）的三条硬约束：

1. **抓住不下滑**：`ClimbUpdate` 的 `target` 默认 **0**，只有 `SlipCheck()` 命中（面墙一侧头顶探针为空 = 手已高过墙沿）才改成 `climb_slip_speed`。
   另有 Up Limit（头顶顶住则停住）与 Down Limit（非主动下爬且脚边墙面到头则 `velocity.y = 0`），所以贴着墙面绝不会缓慢滑落。
2. **贴墙无空隙**：抓墙检测距离用 `climb_check_distance`（ClimbCheckDist 2 ×1.875 = 3.75px）且**只看面朝一侧**；
   墙跳检测另用 `wall_check_distance`（WallJumpCheckDist 3 ×1.875 = 5.625px）。抓墙瞬间照搬 `ClimbBegin` 末尾的逐像素吸附把身体推到贴住墙面；
   攀爬中的"是否还有墙可抓"用 **1px** 邻接判定（参考 `CollideCheck<Solid>(Position + UnitX * Facing)`）。
3. **爬墙跳 ≠ 墙跳**：参考 `moveX == -Facing ? WallJump(-Facing) : ClimbJump()`。
   拉离墙方向 = 墙跳（水平弹开 `wall_jump_speed`，不扣体力）；无方向或按向墙 = `ClimbJump`（垂直起跳，扣 `climb_jump_stamina_cost`）。

### 4.5 抓取物品与抛接（Carryable）

参考 Celeste 的 Theo 水晶与水母。物品抓取**不是** FSM 状态，而是叠加在 Idle/Run/Air 上的"持有"修饰（持有期间正常跑跳）：

- **Carryable 基类**（`scripts/components/carryable.gd`，`class_name Carryable`，继承 CharacterBody2D），三态：
  - `FREE`：自由物理（重力 + 落地静止 / 碰撞反弹）
  - `CARRIED`：跟随玩家的 `CarryAnchor`，关闭物理
  - `THROWN`：受抛掷冲量飞行，`regrab_cooldown`（约 0.15s）后可被再次抓取
  - 接口：`pick_up(player)` / `throw_item(direction)`
- **grab 键优先级**：持物 → 抛出；附近有 Carryable → 拾取；贴墙 → 墙抓
- **Theo 型（重物）**：抛出后平直飞行、落地静止（可扩展为压开关 / 砸障碍的关卡机制）
- **水母型（浮物）**：持有时玩家 `max_fall_speed` 降低（缓降）；抛出后先上升短程再缓落；上升途中可再次抓取，玩家随其获得升力 → 抛接进阶技巧的基础
- 参数同样 `@export` 化：`throw_force` / `jelly_rise_speed` / `jelly_rise_time` / `jelly_float_fall_speed` / `regrab_cooldown`

### 4.6 高级技巧复现（Super / Hyper / Ultra / SuperWallJump / 兔子跳）

> 参考：`documents/CelestePlayerReference.txt` 的 `DashCoroutine`(3548) / `DashUpdate`(3474) / `SuperJump`(1695) / `OnCollideV`(2504)。
> **已实现**。这些技巧不是独立动作，而是从 `Dash Slide + SuperJump + Ducking` 三条规则里**涌现**出来的。

关键发现：Hyper 与 Ultra 在参考里**是同一段代码**。区别只在 Dash 起手位置：

1. **Dash Slide**（`DashCoroutine` 尾部 + `OnCollideV`）：`dash_dir.x != 0 && dash_dir.y > 0` 且触地时 →
   `dash_dir` 转为纯水平、`velocity.y = 0`、`velocity.x *= 1.2`、`is_ducking = true`。
2. **SuperJump**（`DashUpdate` 里 `dash_dir.y == 0 && 土狼 > 0` 时按跳）：
   `velocity = (super_jump_speed * facing, -jump_speed)`；若 `is_ducking` 则再乘 `(1.25, 0.5)`。

| 技巧 | 操作 | 底层机制 | 实测速度（15px 网格） |
|---|---|---|---|
| **Super（超级跳）** | 地面水平 Dash 未结束时按 J | 非 Ducking 的 SuperJump | `(487.5, -196.9)` |
| **Hyper（冲刺跳）** | 地面斜下 Dash（起手即 Dash Slide）立刻按 J | Ducking 的 SuperJump | `(609.4, -98.4)` 低跳远距 |
| **反向 Hyper / 反向 Super** | Dash 途中回拉反方向再按 J | 参考 `Update` 的 Facing 段除 Climb 外**所有状态**（含 Dash）都跟随 `moveX`，`SuperJump` 用 `facing` 定方向 | `(-609.4, -98.4)` |
| **Ultra（超级冲刺）** | 空中斜下 Dash 撞地（Dash Slide）后按 J | 与 Hyper 同路径，仅 `dash_started_on_ground == false` | `(609.4, -98.4)`，触地滑行段 `381.8` |
| **SuperWallJump** | 纯上 Dash 期间贴墙按 J | `DashUpdate` 的 `dash_dir == UP` 分支 | `(±318.75, -300)` |
| **咖啡跳（Cornerkick）** | 蹭墙角上沿瞬间按 J | 上升角落修正把碰撞箱挪到墙侧 → `get_wall_direction()` 命中 → 普通墙跳 | `(±243.75, -196.9)` |
| **兔子跳（Bunnyhop）** | 落地瞬间连续跳 | `_try_jump()` 排在水平摩擦**之后**，起跳写入的速度不会被地面摩擦吃掉；再 +`jump_speed_boost` | 保住上一次的 Super/Hyper 动量 |

**实现约束（必须遵守，回归测试逐条守着）**：

1. **Dash 期间速度只在起手写一次**（参考 `DashCoroutine`），`_dash_update()` 绝不每帧重写 `velocity`，否则 Dash Slide 的 ×1.2 会被立刻覆盖。
2. **`_finish_dash()` 只在 `dash_dir.y <= 0` 时改写速度**（参考同处判断）。斜下 Dash 触地后 `dash_dir.y` 已被 Dash Slide 置 0，所以水平速度**不会**被清零。
3. **跳跃判定排在水平移动与重力之后**（参考 `NormalUpdate` 帧序），不需要额外的"落地摩擦宽限"补丁。
4. **落地/角落这类结论只能来自本帧 `move_and_slide()` 之后**，禁止跨帧读 `is_on_floor()`。
5. **Hyper / Ultra 的输入窗口就是 `dash_duration`（0.15s）本身**，不额外开 `ultra_window`；`jump_buffer_time` 负责容错。
6. **参数按 §4.2 的 ×1.875 基准**，倍率类参数原样照搬 Celeste，不要自己拍数。
7. **Facing 在 Dash 期间必须继续跟随 `moveX`**（只有 Climb 例外），否则反向 Super / 反向 Hyper 永远做不出来。

**自动化验收**：`scripts/debug/player_regression.gd`（真实物理回归，34 条断言）

```
godot --headless --path . --script res://scripts/debug/player_regression.gd
```

它会在 headless 场景里搭地板/墙/带缺口的天花板，实例化 `player.tscn`，
用 `Input.action_press` 逐物理帧驱动，覆盖：Super / Hyper / Ultra / 反向 Hyper 的精确速度、
斜下 Dash 触地不清零水平速度、Dash 自然结束保速、按住跳 vs 点按跳高、
上升角落修正穿缝、抓墙贴合无空隙、抓墙静止不下滑、爬墙跳扣体力、墙跳弹开不扣体力。


---

## 5. 输入映射（InputMap）

| Action | 键位 |
|---|---|
| `move_left` / `move_right` | A/D、方向键 ←/→ |
| `move_up` / `move_down` | W/S、方向键 ↑/↓（8向冲刺、爬墙用） |
| `jump` | J（建议预留第二跳跃键：咖啡跳需极短间隔连跳） |
| `dash` | K |
| `grab` | Shift（墙抓/拾取/抛出复用同一键） |

---

## 6. 关卡与复活

- **网格基准**：`15×15 px = 1 方块`（已确认）。关卡几何全部按 15 的倍数摆放；角色碰撞箱 12×21（0.8×1.4 格）。
- **关卡场景**：`Node2D` 根 + `TileMapLayer`（地形）+ 机关实例 + `Checkpoint` 节点 + `Camera2D`。
- **检查点**：Area2D，进入时 `Game.set_checkpoint()`。
- **死亡**：碰到 Hazard（尖刺等）或掉出边界 → `Game.record_death(global_position)` → **立即**在检查点重生（无 UI、无延迟、无惩罚）。
- **死亡记录**：`debug/death_recorder.gd` 把每次死亡坐标追加写入 `user://deaths.json`，供热力图分析（作品集加分项）。

---

## 7. 作品集支撑功能

1. **参数仪表盘**（`debug/param_dashboard.gd`，CanvasLayer）：滑条/输入框实时绑定 §4.2 的所有 @export 参数，F1 呼出 → 直接产出"参数仪表盘"截图与调参演示。
2. **死亡热力图**： deaths.json → 后期用 Python/Excel 或 Godot 内叠加显示。
3. **辅助模式**（Assist autoload）：游戏速度（Engine.time_scale 0.5–1.0）、无限冲刺开关。

---

## 8. 代码规范

- 全部使用**静态类型标注**（`var x: float` / `func f() -> void`）。
- 可复用类声明 `class_name`（`Player`、`CarryItem`、`ConfigLoader`）；单场景脚本不加。
- 命名：类 PascalCase，变量/函数 snake_case，常量 CONSTANT_CASE，信号 snake_case 过去式（`player_died`）。
- 通信方向：父调子用直接引用，子报父用信号；跨场景用 `Game` 的信号。
- 手感参数注释用中文注明调参方向（例：`# 调大 → 跳得更高`）。

---

## 9. 待确认事项

1. ~~**"抓"的形态**~~ ✅ 已确认：Celeste 式墙抓攀爬；另需物品抓取抛接（Theo 型重物 + 水母型浮物），见 §4.5
2. **美术方向**：灰盒期用占位色块；网格基准已定 `15×15`；正式风格/分辨率（像素风建议 320×180 起步）待定。
3. ~~**冲刺键位**~~ ✅ 已确认：跳 J、冲刺 K、抓 Shift。

---

## 10. 里程碑

| 里程碑 | 内容 | 验收 |
|---|---|---|
| **M1 角色核心** | Player Mode 状态机 + 土狼/缓存/角落修正/可变跳高 + 灰盒测试场景 | ✅ 测试场景内跑跳手感可调；headless 回归覆盖跳高与角落修正 |
| **M2 动作扩展** | Dash（8向）+ 墙抓/爬/墙跳 + 物品抓取抛接（Theo/水母）+ §4.6 高级技巧 | ✅ Super/Hyper/Ultra/反向 Hyper/SuperWallJump 已实现且回归 34/34 通过；抛接待手动试玩 |
| **M3 首个关卡** | 起承转合四段式关卡 + 尖刺/检查点/即时复活 + 相机 | 完整通关流程 |
| **M4 作品集功能** | 参数仪表盘、死亡记录、辅助模式 | 可出截图与数据 |
| **M5+** | 各关环境机制、更多关卡、美术 | — |
