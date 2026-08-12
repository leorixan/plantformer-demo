# Plantformer Demo — 技术方案文档 (TDD)

> 对应策划案：`.claude/documents/GDD.txt` v1.0
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
└── .claude/documents/               # GDD.txt, TDD.md（本文件）
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
├── UI (DashPip1..3 + StaminaBar/Fill)       # 冲刺 pips + 体力条；身体颜色同步指示（紫=attacking，红=正常，蓝=无dash）
├── Camera2D
└── ControllerDebug (Label)                  # show_controller_debug 打开
```

对齐 CelestePlayerReference.txt `Player.cs`：参考实现的 `StateMachine` 只是 Player 内部的 `int State` + 回调表，
**不是独立节点树**。原先的 `states/*.gd` 子节点方案会让多个节点在同一帧各写一次 `velocity`，
并读到上一帧的 `is_on_floor()`，Super/Hyper/Ultra 因此永远无法稳定触发。故已删除
`scripts/player/states/`，改为 Player 内 `enum Mode { NORMAL, DASH, CLIMB }`：

- `_normal_update` / `_dash_update` / `_climb_update` 一一对应参考的 `NormalUpdate` / `DashUpdate` / `ClimbUpdate`。
- 固定帧序（`_physics_process`）：采样输入 → 计时器 → 状态更新 → **一次** `move_and_slide()` → `_resolve_collisions()`。
- 碰撞派生结论（落地、角落修正、Dash Slide）只在 `_resolve_collisions()` 里基于**本帧**碰撞事实做，不读上一帧状态。
- 扩展新机制 = 加一个 `Mode` 分支 + 一个 `_xxx_update`，不影响既有分支。

### 4.2 手感系统（全部 @export 参数化 + CSV 集中配置）

手感参数除在 `player.gd` 中保留 `@export` 默认值外，**集中管理在 `.claude/documents/player_params.csv`**：

- 可用 **Excel / 任何表格软件** 打开编辑（标准 CSV 逗号分隔，UTF-8）。
- 运行时由 `ConfigLoader` autoload 读取并覆盖到 Player。
- 游戏中按 **F5** 即可重新加载 CSV 并应用，无需重启 Godot。
- **数值基准**：与参考实现完全同规格 —— **1 砖 = 8px**，视口 **320×180**，
  站立碰撞箱 **8×11**、下蹲 **8×6**（原点在脚底，参考 `normalHitbox = Hitbox(8, 11, -4, -11)` / `duckHitbox = Hitbox(8, 6, -4, -6)`）。
  **所有参数直接来自 CelestePlayerReference.txt 常量区，不做任何缩放**，因此表里没有小数尾巴。
  按住跳实测跳高 **28.6px ≈ 3.6 砖**，与参考一致。
- **Godot 适配的两个 epsilon**（`player.gd` 顶部常量，非玩法参数）：
  `CONTACT_MARGIN = 0.001` 用于贴墙吸附（默认 0.08 安全边距会把"刚好贴上"判成命中，差 1px 会让 `SlipCheck` 误判成手已过墙沿而下滑）；
  `SHAPE_INSET = 1.0` 把物理盒宽度内缩 1px（参考实现坐标是整数，8px 身体钻 8px 缝是严丝合缝地过；
  Godot 坐标是浮点，缝隙与身体等宽时要求亚像素对齐，角落修正会大多数时候找不到可行位置），整箱检测用同一个值。

CSV 列：`category, name, value, type, description`。当前包含：

| 分类 | 参数 | 说明 |
|---|---|---|
| Body | `body_width` 8 / `stand_height` 11 / `duck_height` 6 | 碰撞箱尺寸（CelestePlayerReference.txt 常量区） |
| Movement | `max_speed` / `acceleration` / `over_speed_decel` / `air_accel_mult` | 对应 MaxRun / RunAccel / RunReduce / AirMult |
| Movement | `duck_friction` / `duck_correct_check` / `duck_correct_slide` | 下蹲地面摩擦 / 站不起来时的让位探测与横移速度 |
| Jump | `jump_speed` / `jump_speed_boost` / `var_jump_time` / `coyote_time` / `jump_buffer_time` / `ceiling_var_jump_grace` | 起跳、水平加成、可变跳高、土狼、缓存 |
| Gravity | `gravity` / `max_fall_speed` / `fast_max_fall_speed` / `fast_max_accel` / `half_gravity_threshold` | 顶点半重力（按住跳时）+ 按住下方向的 Fastfall |
| Dash | `dash_speed` / `dash_end_speed` / `end_dash_up_mult` / `dash_duration` / `dash_freeze_time` / `dash_cooldown` / `dash_refill_cooldown` / `dash_attack_time` / `dash_buffer_time` / `attack_speed_threshold` | 冲刺本体 + `is_attacking()`（`dash_attack_timer > 0 \|\| speed >= attack_speed_threshold`）；`dash_refill_cooldown` 是 Extended Dash 的窗口 |
| Dash | `super_jump_speed` / `dodge_slide_speed_mult` / `duck_super_jump_x_mult` / `duck_super_jump_y_mult` | Super / Hyper / Ultra |
| Dash | `super_wall_jump_speed` / `super_wall_jump_horizontal` | 上冲刺撞墙的 SuperWallJump |
| Climb | `max_stamina` / `climb_*_speed` / `climb_acceleration` / `climb_*_stamina_cost` / `climb_check_distance` / `slip_check_depth` / `wall_check_distance` / `wall_jump_speed` / `climb_hop_x` / `climb_hop_y` | 墙抓攀爬与墙跳 |
| Climb | `climb_jump_boost_time` / `wall_slide_start_max` / `wall_slide_time` | Wallboost 窗口 / 贴墙下滑上限与衰减时长 |
| Feel | `corner_correction_px` / `dash_corner_correction_px` / `wall_jump_force_time` / `super_wall_jump_force_time` / `wall_speed_retention_time` | 上升撞顶修正 / 空中 Dash 撞地角修正 / 墙跳后水平输入接管 / 撞墙速度保留（Cornerboost） |

手感机制实现要点：
- **土狼时间**：离开平台边缘后计时器内仍允许起跳。
- **输入缓存（双路采样）**：按下事件在 `_unhandled_input` 里捕获写入缓存计时器（`InputEvent` 不受物理帧节奏影响，两个物理帧之间"按下即松开"的快速点按不会丢），
  同时 `_poll_input` 在物理帧里用 `is_action_just_pressed` 补采样一次（让 headless 回归的 `Input.action_press` 也能驱动）。两条路径写同一个计时器，任一命中都算按下。
- **moveX / moveY 单点采样**：参考 `Update` 的 `moveX` —— 每帧只算一次 `move_x`（受 `forceMoveX` 覆盖）与 `move_y`（原始），
  facing / 水平加速 / 跳跃水平加成 / 爬墙跳判定全部读同一份，避免各处 `Input.get_axis` 读到不一致的值。
  `forceMoveX` 在墙跳（`wall_jump_force_time` 0.16）、SuperWallJump（0.2）、翻墙 hop（`climb_hop_force_time` 0.2 强制归零）后短时间接管水平输入。
  Dash 方向另用**原始**输入（参考 `Input.GetAimVector` 读 `Input.MoveX.Value`，不吃 `forceMoveX`）。
- **Dash 起手冻结**：参考 `DashBegin` 的 `Freeze(.05)`（见 CelestePlayerReference.txt:3442-3467） + `DashCoroutine` 开头的 `yield return null` ——
  按下 K 立刻清零速度与 `dash_dir` 并冻结 `dash_freeze_time`（0.05s ≈ 3 帧），**方向留到冻结结束才采样**。
  这是"八向方向判定没有延迟"的关键：K 与方向键同帧甚至晚一两帧按下都能吃到正确方向。
- **可变跳高**：来自 CelestePlayerReference.txt 的 `varJumpTimer` —— 按住跳时 `velocity.y = min(velocity.y, varJumpSpeed)` 维持 `var_jump_time`，松手立即清零。这是跳高的主要来源，不是 `jump_cut_mult`。
- **角落修正**：参考 `Player.cs` 的 `OnCollideV`。上升撞顶时用**移动前**的 `vy` 判定，逐像素探测 **(±i, -1)** 处整箱是否放得下并整体平移；修正失败才按 `ceiling_var_jump_grace` 掐掉可变跳。另有 `DashCornerCorrection`：空中起手的 Dash 撞地角时横移让位（`dash_started_on_ground` 为 false 才生效）。
  探测照参考用 **整箱重叠检测**（`CollideCheck<Solid>`）而不是扫掠 `test_move` —— 8px 宽的身体钻 8px 宽的缝，扫掠会被两侧墙擦到而永远失败。
- **下蹲（Ducking）**：参考 `NormalUpdate` 的 Ducking 段。地面按下方向即蹲（碰撞箱 8×11 → 8×6，**底边固定在脚下**，所以切换不会挪动角色）；
  蹲下时地面用 `duck_friction` 500 压住水平速度；松开下方向后先 `CanUnDuck` 判定头顶空间，站不起来就保持蹲伏，
  完全静止时按 `duck_correct_check` 4px 内左右探测，找到能站起来的一侧就以 `duck_correct_slide` 50px/s 横向让位。
  空中下落且头顶有空间时自动站起。这条同时是 **Crouch Jump / 低通道** 玩法与 Dash Slide（Hyper/Ultra）的公共基础。
- **探针尺寸**：`_box_is_solid(center, size, inset_y=false)`。`inset_y` 默认 false：`_on_ground()` 不内缩 Y（地面探针底部 y=+1.0，1px 充分重叠地板，防浮点随机失败）。
  `_can_unduck_at` / `_body_fits_at` 传 `inset_y=true`（内缩 1px 避免与地板切线边界判重）。
- **Fastfall**：参考 `Vertical` 段的 `maxFall`。按住下方向且已达 `MaxFall` 时，下落上限以 `fast_max_accel` 300 渐进到 `fast_max_fall_speed` 240。
  重力改用 `Calc.Approach` 语义（`move_toward(velocity.y, limit, g*mult*dt)`），这样上限**下降**时也能减速 —— 贴墙下滑必须依赖这一点。
- **无落地硬直**：落地不打断输入，保证响应度。


### 4.3 冲刺（Dash）

- 8 向（读 `move_*` 四方向输入组合），无方向输入时默认朝面向。
- 流程：触发 → `dash_freeze_time`（0.05s）冻结且速度归零 → 冻结结束才采样方向并写入速度 → 固定速度直线冲 `dash_duration` → 回到 Normal。
- 落地刷新次数；`Assist.infinite_dash` 开启时无限。
- 冲刺期间关闭重力；速度只在冻结结束那一帧写一次，之后绝不每帧重写。

### 4.4 抓（Grab）：墙抓攀爬

按**墙抓/攀爬/墙跳**设计（见 CelestePlayerReference.txt 攀爬段）（已确认）：按住 grab 贴墙 → Climb 模式 → 跳跃键弹出。

对齐参考 `ClimbBegin` / `ClimbUpdate`（3056 / 3102）的三条硬约束：

1. **抓住不下滑**：`ClimbUpdate` 的 `target` 默认 **0**，只有 `SlipCheck()` 命中（面墙一侧头顶探针为空 = 手已高过墙沿）才改成 `climb_slip_speed`。
   另有 Up Limit（头顶顶住则停住）与 Down Limit（非主动下爬且脚边墙面到头则 `velocity.y = 0`），所以贴着墙面绝不会缓慢滑落。
2. **贴墙无空隙**：抓墙检测距离用 `climb_check_distance`（ClimbCheckDist **2px**）且**只看面朝一侧**；
   墙跳检测另用 `wall_check_distance`（WallJumpCheckDist **3px**）。抓墙瞬间照参考 `ClimbBegin` 末尾把身体推到贴住墙面
   （用 `move_and_collide` + `CONTACT_MARGIN`，逐像素 `test_move` 会因默认安全边距停在 1px 外，导致 `SlipCheck` 探针落到墙面边界上而误判下滑）；
   攀爬中的"是否还有墙可抓"用 **1px** 邻接判定（参考 `CollideCheck<Solid>(Position + UnitX * Facing)`）。
3. **爬墙跳 ≠ 墙跳**：参考 `moveX == -Facing ? WallJump(-Facing) : ClimbJump()`。
   拉离墙方向 = 墙跳（水平弹开 `wall_jump_speed`，不扣体力）；无方向或按向墙 = `ClimbJump`（垂直起跳，扣 `climb_jump_stamina_cost`）。
   **`NormalUpdate` 的跳跃段有同一套分支**（参考 2969-3004）：非攀爬状态下贴墙按跳时，先要求 `CanUnDuck`，
   再按「面朝墙 + 按住抓取 + 有体力 → `ClimbJump`」/「纯上 Dash 攻击中 → `SuperWallJump`」/「其余 → `WallJump`」分派。
   缺这段就会出现"按住抓取贴墙起跳被水平弹得很远"。
- **`is_attacking()`**：`dash_attack_timer > 0 || velocity.length() >= attack_speed_threshold(240)`。用于破墙、杀敌等碰撞判定，不限 dash 期。Super(260)/Hyper(325)/Ultra(325) 均满足。
4. **翻墙 hop 是免费动作**：参考 `ClimbHop` 不扣体力、不算跳跃。水平速度先由 `hopWaitX` 压住，
   越过墙沿（侧向 1px 无墙）后才推上平台；同时 `forceMoveX = 0` 维持 `climb_hop_force_time`。
5. **上升中不许抓墙**：参考 `NormalUpdate` 的 `if (Speed.Y >= 0 && Math.Sign(Speed.X) != -Facing)`。
   缺这条守卫，翻墙 hop 刚起跳就会被立刻重新抓住 → 反复 hop，体力被瞬间抽干。
6. **Wall Slide（贴墙下滑）**：参考 `Update` 的 Wall Slide 段。推向墙面（或无方向按住抓取）且没按下方向时，
   下落上限被压到 `lerp(MaxFall, WallSlideStartMax, wallSlideTimer / WallSlideTime)` —— 起始约 **20px/s**，
   `wall_slide_time` 1.2s 内逐渐衰减回 160。落地或起跳重置计时器。**没有这条，连续上墙之间会以 160px/s 掉下去，根本连不上。**
7. **Wallboost（无体力连续上墙）**：参考 `ClimbJump` 末尾与 `Update` 的 Wall Boost 段。
   **无方向输入**的中立爬墙跳会武装一个 `climb_jump_boost_time` 0.2s 的窗口；窗口内推离墙面 →
   `Speed.X = WallJumpHSpeed * moveX` 且 **`Stamina += ClimbJumpCost`（退还这次消耗，不夹到上限）**，且**不设 `forceMoveX`**，所以能立刻推回墙面接下一次。
   这就是"无体力也能一直上墙"的机制来源；缺它的话每次中立爬墙跳都真扣 27.5 体力，只能上 3-4 次。
8. **Wall Speed Retention（Cornerboost 来源）**：参考 `OnCollideH` 与 `Update` 的对应段。
   撞墙瞬间存下撞墙前的水平速度，`wall_speed_retention_time` 0.06s 内一旦侧向无墙就还原回去。

### 4.5 高级技巧复现（Super / Hyper / Ultra / SuperWallJump / 兔子跳）

> 参考：`.claude/documents/CelestePlayerReference.txt` 的 `DashCoroutine`(3548) / `DashUpdate`(3474) / `SuperJump`(1695) / `OnCollideV`(2504)。
> **已实现**。这些技巧不是独立动作，而是从 `Dash Slide + SuperJump + Ducking` 三条规则里**涌现**出来的。

关键发现：Hyper 与 Ultra 在参考里**是同一段代码**。区别只在 Dash 起手位置：

1. **Dash Slide**（`DashCoroutine` 尾部 + `OnCollideV`）：`dash_dir.x != 0 && dash_dir.y > 0` 且触地时 →
   `dash_dir` 转为纯水平、`velocity.y = 0`、`velocity.x *= 1.2`、`is_ducking = true`。
2. **SuperJump**（`DashUpdate` 里 `dash_dir.y == 0 && 土狼 > 0` 时按跳）：
   `velocity = (super_jump_speed * facing, -jump_speed)`；若 `is_ducking` 则再乘 `(1.25, 0.5)`。

| 技巧 | 操作 | 底层机制 | 实测速度（8px 砖，CelestePlayerReference.txt 常量区） |
|---|---|---|---|
| **Super（超级跳）** | 地面水平 Dash 未结束时按 J | 非 Ducking 的 SuperJump | `(260, -105)` |
| **Hyper（冲刺跳）** | 地面斜下 Dash（起手即 Dash Slide）立刻按 J | Ducking 的 SuperJump | `(325, -52.5)` 低跳远距 |
| **反向 Hyper / 反向 Super** | Dash 途中回拉反方向再按 J | 参考 `Update` 的 Facing 段除 Climb 外**所有状态**（含 Dash）都跟随 `moveX`，`SuperJump` 用 `facing` 定方向 | `(-325, -52.5)` |
| **Ultra（超级冲刺）** | 空中斜下 Dash 撞地（Dash Slide）后按 J | 与 Hyper 同路径，仅 `dash_started_on_ground == false` | `(325, -52.5)`，触地滑行段 `203.6` |
| **SuperWallJump** | 纯上 Dash 期间贴墙按 J | `DashUpdate` 与 `NormalUpdate` 的 `dash_dir == UP` 分支 | `(±170, -160)` |
| **咖啡跳（Cornerkick）** | 蹭墙角上沿瞬间按 J | 上升角落修正把碰撞箱挪到墙侧 → `get_wall_direction()` 命中 → 普通墙跳 | `(±130, -105)` |
| **兔子跳（Bunnyhop）** | 落地瞬间连续跳 | `_try_jump()` 排在水平摩擦**之后**，起跳写入的速度不会被地面摩擦吃掉；再 +`jump_speed_boost` | 保住上一次的 Super/Hyper 动量 |
| **Wallboost** | 中立爬墙跳后 0.2s 内推离墙面 | 退还 `ClimbJumpCost` 并转成墙跳，不锁输入 | `(±130, -105)`，体力净消耗 0 |
| **Cornerboost** | 撞墙后 0.06s 内离墙 | `OnCollideH` 的速度保留 | 还原撞墙前水平速度 |
| **Extended Dash** | 落地后 0.1s 内再 Dash | `dash_refill_cooldown` 期间不补 dash，保住 dash 攻击窗口 | — |

**实现约束（必须遵守，回归测试逐条守着）**：

1. **Dash 期间速度只在起手写一次**（参考 `DashCoroutine`），`_dash_update()` 绝不每帧重写 `velocity`，否则 Dash Slide 的 ×1.2 会被立刻覆盖。
2. **`_finish_dash()` 只在 `dash_dir.y <= 0` 时改写速度**（参考同处判断）。斜下 Dash 触地后 `dash_dir.y` 已被 Dash Slide 置 0，所以水平速度**不会**被清零。
3. **跳跃判定排在水平移动与重力之后**（参考 `NormalUpdate` 帧序），不需要额外的"落地摩擦宽限"补丁。
4. **"是否站在地上"必须用几何探针（见 CelestePlayerReference.txt:670-710） `_on_ground()`**（参考 `Update` 顶部 `onGround = Speed.Y >= 0 && CollideCheck<Solid>(Position + UnitY)`），
   禁止用 Godot 的 `is_on_floor()` 做逻辑判定：水平 Dash（vy=0、关重力）、Dash Slide 这类帧里没有向下位移，
   `is_on_floor()` 为假 → dash 次数 / 体力 / 土狼时间全都补不回来，表现为"Super / Hyper / Wavedash 之后冲刺不恢复"。
   `is_on_floor()` 只允许用于 `is_on_ceiling()` / `is_on_wall()` 这类本帧碰撞事实。
   **`_on_ground()` 当前是纯几何探针（不含 `velocity.y < 0` 短路）**：参考实现的 `Speed.Y >= 0` 由自身速度计算出 `onGround`，
   但 Godot 的 `move_and_slide()` 落地帧可能把 `velocity.y` 修正成 −0.001，速度短路不可靠。
   纯探针与 CelestePlayerReference.txt Dashes 段（735 `else if (onGround) ... RefillDash()`）的 refill 逻辑等效。
5. **Hyper / Ultra 的输入窗口就是 `dash_duration`（0.15s）本身**，不额外开 `ultra_window`；`jump_buffer_time` 负责容错。
6. **参数直接来自 CelestePlayerReference.txt 常量区**（1 砖 = 8px，见 §4.2），不要自己拍数、也不要再乘缩放倍数。
7. **Facing 在 Dash 期间必须继续跟随 `moveX`**（只有 Climb 例外），否则反向 Super / 反向 Hyper 永远做不出来。
8. **Dash 方向必须在冻结结束后才采样**（参考 `DashCoroutine` 的 `yield return null`），否则同帧按下的方向键会被漏掉，表现为"方向判定有延迟"。
9. **重力必须用 `Calc.Approach` 语义**（`move_toward`），不能写成 `min(vy + g*dt, maxfall)`，否则贴墙下滑与 Fastfall 的上限变化无法生效。
10. **玩家只与 Solid 碰撞**（参考实现：Theo 是 Actor，不是 Solid）。碰撞层分配：地形 = 层 1；
   玩家 = 层 2 / 掩码 1。
11. **`dash_started_on_ground` 只看几何探针**（参考 `DashBegin` 3445 `dashStartedOnGround = onGround`），
   **不能或上土狼时间**。多算土狼会把"跑出台沿再斜下冲撞地"误判成 Hyper（应为 Ultra），
   还会关掉只对空中起手生效的 Dash 撞地角落修正。
12. **dash 补充冷却写在起手处**（参考 `DashBegin` 3451 `dashRefillCooldownTimer = DashRefillCooldown` 0.1s），
   补充条件是"冷却结束 且 `onGround` 且脚下 1px 有实体"（718-739）。
   所以 **Wavedash 起飞那一刻 dash 必然还是 0**（冷却没走完就已离地），落地后才补满 —— 这与参考一致，不是 bug。

**自动化验收**：`scripts/debug/player_regression.gd`（真实物理回归，**82 条断言**）+
`scripts/debug/room_regression.gd`（测试房几何回归：坑宽把关 / 死亡复活 / 存档点与门洞）

```
godot --headless --path . --script res://scripts/debug/player_regression.gd
godot --headless --path . --script res://scripts/debug/room_regression.gd
```

它会在 headless 场景里搭地板/墙/带 1 砖缺口的天花板/1 砖悬空平台/只有蹲下能进的低通道，实例化 `player.tscn`，
用 `Input.action_press` 逐物理帧驱动，覆盖：Super / Hyper / Ultra / 反向 Hyper 的精确速度、
斜下 Dash 触地不清零水平速度、Dash 自然结束保速、按住跳 vs 点按跳高（含空中墙跳 / 攀爬墙跳 / 垂直爬墙跳三条路径）、
上升角落修正穿 1 砖缝、抓墙贴合无空隙、抓墙静止不下滑、爬墙跳扣体力、墙跳弹开不扣体力、
冻结期补按方向仍被采纳、墙沿持续按上只 hop 一次且不抽体力、纯上 Dash 蹭平台侧面触发 SuperWallJump、
`NormalUpdate` 贴墙按住抓取起跳走 ClimbJump 而非被弹开、Wallboost 退还体力且不锁输入、
贴墙下滑被压到 WallSlideStartMax、按住下方向 Fastfall 到 240 不超、`dash_refill_cooldown` 期间不补 dash、
撞墙速度保留窗口、下蹲（碰撞箱变矮 / 底边不动 / 摩擦 / 自动站起 / 低通道内站不起来）、
**Super / Hyper 起飞后仍持有 dash（水平 Dash 与 Dash Slide 期间 `_on_ground()` 为真）**、
**Wavedash 起飞时 dash 仍在 0.1s 补充冷却里、落地即补满**。


---

## 5. 输入映射（InputMap）

| Action | 键位 |
|---|---|
| `move_left` / `move_right` | A/D、方向键 ←/→ |
| `move_up` / `move_down` | W/S、方向键 ↑/↓（8向冲刺、爬墙用） |
| `jump` | J（建议预留第二跳跃键：咖啡跳需极短间隔连跳） |
| `dash` | K |
| `grab` | Shift（墙抓） |

---

## 6. 关卡与复活

- **网格基准**：`8×8 px = 1 砖`，视口 `320×180`（1砖8px规格）。关卡几何全部按 8 的倍数摆放；
  角色碰撞箱站立 8×11（1×1.375 砖）、下蹲 8×6。窗口默认 1280×720（4 倍整数放大，
  `stretch/mode = canvas_items` + `scale_mode = integer`）。用 `canvas_items` 而不是 `viewport`：
  `viewport` 会把文字先渲进 320×180 缓冲再整体放大，5~6px 的调试字必然糊成一团；
  `canvas_items` 下 Godot 的动态字体 oversampling 会按最终设备分辨率重新光栅化，字才清晰。
  另外 `textures/canvas_textures/default_texture_filter = Nearest`，保证像素图不被插值。
- **测试房（灰盒）**：`scenes/levels/test_room.tscn` = `Node2D` 根 + `scripts/levels/test_room.gd`（`@tool`）。
	 房间由脚本按 ASCII 网格生成（图例：`#` 实体 / `.` 空 / `P` 出生 / `x` 目标标记），
	 每区 16 行、地面固定在第 14/15 行（顶面 y=112），横向 `'#'` 连段合并成一个矩形碰撞体 + 一个 ColorRect。
	 参考 Strawberry Jam Collab 的教学房，按技巧分 10 区（跑跳土狼 / 下蹲低通道 / Dash / Super / Hyper·Wavedash /
	 Ultra / 墙跳·SuperWallJump / 攀爬·Wallboost / 角落修正 / Cornerboost），每区左上角有标题 + 操作要点标签。
	 `@tool` 的意义：编辑器打开场景就能看到生成结果（编辑器里只铺地形/标记/文字，不放角色与道具）。
- **测试房的三条硬规则**（改 `ZONES` 后必须跑 `room_regression.gd` 复验）：
  1. **坑宽按实测射程定**，保证"没学会技巧就过不去"。平地实测（起跳点→落点）：普通跳 **40px**、
     跳+空中冲 **65px**、光冲刺蹭台沿 **10px**、Super **85px**、Hyper **110px**、Wavedash/Ultra **114px**。
    故 Super 区坑 **10 砖**、Hyper·Wavedash 区 **10 砖**、Ultra 区 **10 砖**（Ultra 起跳点在台子边上，
    实际可跨约 130px，所以坑要紧贴台子放），Dash 区 **6 砖**。
  2. **分区之间是 2 砖厚的高墙**（第 0~11 行实体，第 12/13 行留 16px 门洞，脚下补通行地面），
     所以每区的右端两列不能压台子，否则门洞被堵死（区 1 的悬空台因此缩到第 21 列）。
  3. **坑底有死亡带**（第 17/18 行，红色）：`player.kill_plane_y` 由 test_room 设为 `DEATH_ROW * 8`，
     掉下去即触发玩家自带的 `_respawn()`，回到 `last_checkpoint`（跨区时 test_room 调 `set_checkpoint()` 更新到分区入口）
     并补满 dash / 体力 —— 掉坑约 17 帧就重来，不是无底洞。

- **关卡场景**：`Node2D` 根 + 素材库组件（`scenes/components/*.tscn`）+ `player.tscn` + `Camera2D`。详见 `AssetLibrary.md`。
- **检查点**：`checkpoint.tscn`（Area2D），进入时调 `player.set_checkpoint()`。
- **死亡**：统一由 `player.gd` 处理 —— 尖刺等伤害源调 `player.take_damage()`，掉出 `kill_plane_y` 自动重生；
  重生到 `last_checkpoint`，零延迟无惩罚。

---

## 7. 作品集支撑功能

1. **参数仪表盘**（`debug/param_dashboard.gd`，CanvasLayer）：滑条/输入框实时绑定 §4.2 的所有 @export 参数，F1 呼出 → 直接产出"参数仪表盘"截图与调参演示。
2. **死亡热力图**： deaths.json → 后期用 Python/Excel 或 Godot 内叠加显示。
3. **辅助模式**（Assist autoload）：游戏速度（Engine.time_scale 0.5–1.0）、无限冲刺开关。

---

## 8. 代码规范

- 全部使用**静态类型标注**（`var x: float` / `func f() -> void`）。
- 可复用类声明 `class_name`（`Player`、`ConfigLoader`）；单场景脚本不加。
- 命名：类 PascalCase，变量/函数 snake_case，常量 CONSTANT_CASE，信号 snake_case 过去式（`player_died`）。
- 通信方向：父调子用直接引用，子报父用信号；跨场景用 `Game` 的信号。
- 手感参数注释用中文注明调参方向（例：`# 调大 → 跳得更高`）。

---

## 9. 待确认事项

1. ~~**"抓"的形态**~~ ✅ 已确认：墙抓攀爬（见 CelestePlayerReference.txt 攀爬段）。
2. ~~**网格基准 / 分辨率**~~ ✅ 已确认：`8×8` 砖、视口 `320×180`；灰盒期继续用占位色块，正式美术风格待定。
3. ~~**冲刺键位**~~ ✅ 已确认：跳 J、冲刺 K、抓 Shift。

---

## 10. 里程碑

| 里程碑 | 内容 | 验收 |
|---|---|---|
| **M1 角色核心** | Player Mode 状态机 + 土狼/缓存/角落修正/可变跳高 + 灰盒测试场景 | ✅ 测试场景内跑跳手感可调；headless 回归覆盖跳高与角落修正 |
| **M2 动作扩展** | Dash（8向）+ 墙抓/爬/墙跳 + 下蹲 + §4.5 高级技巧 | ✅ Super/Hyper/Ultra/反向 Hyper/SuperWallJump/Wallboost/Cornerboost/Wall Slide/Fastfall/下蹲 已实现且回归 82/82 通过；测试房几何回归全绿（坑宽 12 项 + 存档点/门洞 10 项） |
| **M3 首个关卡** | 起承转合四段式关卡 + 尖刺/检查点/即时复活 + 相机 | 完整通关流程 |
| **M4 作品集功能** | 参数仪表盘、死亡记录、辅助模式 | 可出截图与数据 |
| **M5+** | 各关环境机制、更多关卡、美术 | — |
