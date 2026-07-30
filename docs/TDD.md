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
│   │   ├── player.gd
│   │   └── states/          # state_machine.gd, state.gd, idle/run/air/dash/grab.gd
│   ├── components/          # 机关脚本，与场景一一对应
│   ├── autoload/            # game.gd, assist.gd
│   └── debug/               # param_dashboard.gd, death_recorder.gd
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

## 4. 角色控制器：节点式 FSM

### 4.1 架构

```
Player (CharacterBody2D, player.gd)
├── Sprite2D / CollisionShape2D
├── CarryAnchor (Marker2D)                    # 持物跟随点（头顶/身前）
├── GrabDetector (Area2D)                     # 探测附近可抓取物品
├── StateMachine (Node, state_machine.gd)     # 通用、可复用，非玩家专用
│   ├── Idle  (Node, idle.gd)
│   ├── Run   (Node, run.gd)
│   ├── Air   (Node, air.gd)                  # 跳跃上升/下落/土狼/缓存都在这里
│   ├── Dash  (Node, dash.gd)
│   └── Grab  (Node, grab.gd)                 # 墙抓/攀爬/墙跳
```

- **StateMachine**：持有 `current_state`，转发 `_physics_process` / `_unhandled_input`，提供 `transition_to(name)`。进入/退出时调状态的 `enter()` / `exit()`。
- **State 基类**（`state.gd`，`class_name State`）：虚函数 `enter()` `exit()` `physics_update(delta)` `handle_input(event)`；持有 `player` 引用。
- **每个状态一个子节点一个脚本**：新增机制（如弹簧、绳索）= 新增一个状态节点，不改已有代码 → 满足"高解耦、易扩展"。
- 状态切换只通过 `transition_to()`，状态间不直接引用。

### 4.2 手感系统（全部 @export 参数化 + CSV 集中配置）

手感参数除在 `player.gd` 中保留 `@export` 默认值外，**集中管理在 `documents/player_params.csv`**：

- 可用 **Excel / 任何表格软件** 打开编辑（标准 CSV 逗号分隔，UTF-8）。
- 运行时由 `ConfigLoader` autoload 读取并覆盖到 Player。
- 游戏中按 **F5** 即可重新加载 CSV 并应用，无需重启 Godot。

CSV 列：`category, name, value, type, description`。当前包含：

| 分类 | 参数 | 说明 |
|---|---|---|
| Movement | `max_speed` / `acceleration` / `deceleration` | 地面移动（加速度模型） |
| Movement | `air_accel_mult` / `over_speed_decel` | 空中操控与超速保速（兔子跳） |
| Jump | `jump_force` / `jump_cut_mult` / `jump_speed_boost` | 起跳、可变跳高、水平加成 |
| Gravity | `gravity` / `fall_gravity_mult` / `apex_gravity_mult` / `apex_threshold` / `max_fall_speed` | 重力三分段 |
| Feel | `coyote_time` / `jump_buffer_time` / `corner_correction_px` | 土狼、缓存、角落修正 |

后续 Dash/Grab/Carryable 参数也将追加到同一张 CSV。

手感机制实现要点：
- **土狼时间**：离开平台边缘后计时器内仍允许起跳。
- **输入缓存**：落地前按下跳跃，落地瞬间自动起跳。
- **角落修正**：直接参考 Celeste 官方开源 `Player.cs`（见 `documents/CelestePlayerReference.txt`）。撞头后记录移动前的 `vy`，然后探测 **(±i, -1)** 偏移是否为空；若空则移动过去。关键的 `-1` 像素确保角色不会被吸进天花板内部。
- **无落地硬直**：落地不打断输入，保证响应度。

### 4.3 冲刺（Dash）

- 8 向（读 `move_*` 四方向输入组合），无方向输入时默认朝面向。
- 流程：触发 → `dash_freeze_frames` 冻结 → 固定速度直线冲 `dash_duration` → 回到 Air。
- 落地刷新次数；`Assist.infinite_dash` 开启时无限。
- 冲刺期间关闭重力。

### 4.4 抓（Grab）：墙抓攀爬

按 Celeste 式**墙抓/攀爬/墙跳**设计（已确认）：按住 grab 贴墙 → Grab 状态（可上下爬、消耗体力可选）→ 跳跃键触发墙跳弹出。
**持有物品期间禁用墙抓**（手被占用）——抛出物品后才能抓墙，这是"抛接"技巧循环的核心。

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

### 4.6 高级技巧复现（Super / Hyper / Ultra / CB / 咖啡跳 / 兔子跳）

> 参考：[celeste.ink Tech wiki](https://celeste.ink/wiki/Tech)、[蔚蓝中文资料库·技巧](https://celestecn.miraheze.org/wiki/%E6%8A%80%E5%B7%A7)。
> 这些技巧**不是独立动作**，而是从核心物理规则中**涌现**的组合技。本节只定义机制与实现约束，**暂不实现**，作为 M1–M2 物理规则的验收标准。

| 技巧 | 操作 | 底层机制 |
|---|---|---|
| **Super（超级跳）** | 地面水平冲刺中按跳 | 冲刺速度保留进跳跃（不被 `max_speed` 覆盖）→ 远距平跳 |
| **Hyper（冲刺跳）** | 下蹲 + 斜下冲刺触地即跳 | 低空长距跳（Celeste 参考值 325 px/s）；斜下冲刺 + 起跳速度保留 |
| **Ultra（超级冲刺）** | 高速（>170 px/s）状态下斜下冲刺 | 触地时水平速度 ×1.2；冲刺须在落地**前**结束，否则丢失；落地后短暂窗口内起跳保留倍率；平地可无限链式（Celeste 中最快的平地移动，~390 px/s） |
| **CB（Cornerboost）** | 带冲刺动量在墙顶边缘做爬墙跳 | 爬墙跳**取消冲刺但保留冲刺速度**，翻过墙顶时返还；与墙碰撞**前**起跳额外 +40（good CB） |
| **咖啡跳（Cornerkick）** | 头顶蹭到墙角**下沿**瞬间按跳 | 角落修正把碰撞箱滑到墙侧 → 判定为贴墙 → 允许一次墙跳；起跳帧不按方向 = 中性咖啡跳（水平位移小）。建议支持**双跳跃键**（两次跳间隔极短） |
| **兔子跳（Bunnyhop）** | 落地瞬间起跳、连续跳 | 每次起跳 +40 水平速度；落地即刻起跳不吃地面摩擦 → 保住 super/hyper 动量连续跳 |

**实现约束（M1–M2 物理规则必须遵守）**：

1. **冲刺→跳跃速度保留**：冲刺结束或被跳跃取消时，水平速度不回落到 `max_speed`，进 Air 后按空中惯性自然衰减（Super/Hyper/兔子跳的根源）
2. **斜下冲刺落地倍率**：`ultra_speed_mult`（参考 1.2）、`ultra_min_speed`（参考 170）@export 化（Ultra）
3. **角落修正双向生效**：撞头上挤（§4.2 已有）+ 蹭角后短窗口内允许墙跳，窗口 `corner_kick_window` @export（咖啡跳）；墙跳判定基于**贴墙检测**（is_on_wall / 射线），不要求必须处于 Grab 状态
4. **爬墙跳取消冲刺但保速**：墙跳执行时若处于冲刺或冲刺刚结束，保留冲刺速度；碰撞前起跳奖励 `cb_bonus_speed`（参考 +40）（CB）
5. **起跳速度加成**：`jump_speed_boost`（参考 +40）+ 落地摩擦宽限（落地 N 帧内起跳不应用地面减速）（兔子跳）
6. **土狼时间 / 输入缓存**（§4.2）独立可调 —— 是 extended hyper 等变体的土壤

> 注：325、1.2、+40、170 为 Celeste 参考值；我们的绝对数值按自己的手感定，但**机制对应关系**保持一致。

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
- 可复用类声明 `class_name`（`StateMachine`、`State`）；单场景脚本不加。
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
| **M1 角色核心** | StateMachine + Idle/Run/Air + 土狼/缓存/角落修正/可变跳高 + 灰盒测试场景 | 测试场景内跑跳手感可调 |
| **M2 动作扩展** | Dash（8向+冻结帧）+ 墙抓/爬/墙跳 + 物品抓取抛接（Theo/水母） | 四动作+抛接连贯组合；物理规则满足 §4.6 技巧涌现条件 |
| **M3 首个关卡** | 起承转合四段式关卡 + 尖刺/检查点/即时复活 + 相机 | 完整通关流程 |
| **M4 作品集功能** | 参数仪表盘、死亡记录、辅助模式 | 可出截图与数据 |
| **M5+** | 各关环境机制、更多关卡、美术 | — |
