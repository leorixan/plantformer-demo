# Plantformer Demo - 任务清单

> 来源：`.claude/memory/session-log.md`
> 规则：每次执行后更新本文件，标记已完成任务，写出下一步任务。

---

## 已完成

- [x] M1 角色核心：FSM + Idle/Run/Air + 土狼/缓存/角落修正/可变跳高 + 灰盒测试场景
- [x] M2 动作扩展：8 向 Dash、墙抓/攀爬/墙跳、Theo 与 Jellyfish 抓取抛接
- [x] 输入映射：J 跳、K 冲刺、Shift 抓、A/D/方向键移动
- [x] 15×15 网格基准（已废弃，第 17 轮改回 Celeste 的 8×8 砖 + 320×180 视口）
- [x] 测试房重建：Jump / Dash / Climb / Corner / Carry 分区全部按 15px 网格
- [x] CSV 参数驱动：`documents/player_params.csv` + F5 热重载
- [x] 下载 Celeste Player.cs 作为参考：`documents/CelestePlayerReference.txt`
- [x] M2 控制完全重构：此前高级技巧实现已替换；Player 单一帧模拟、参考比例参数、Super/Hyper/Ultra/Dash 保速回归测试已通过
- [x] Player 子节点 UI：Dash pips、stamina bar，数值驱动且不随角色翻面
- [x] 测试房控制 debug：仅测试房显示模式、速度、Dash 方向、最近技巧/事件
- [x] 参数按 15px 网格统一缩放 ×1.875（Celeste 8px 砖 → 本项目 15px 格），`player.gd` 默认值与 CSV 一致；实测按住跳 53.5px = 3.6 格
- [x] Hyper / Ultra 改为参考真实路径：Dash Slide（×1.2 + Ducking）+ Ducking SuperJump（×1.25, ×0.5），不再用自造的 ultra 窗口
- [x] Dash 期间速度只在起手写一次（参考 DashCoroutine），修掉每帧重写导致 Dash Slide 提速被覆盖
- [x] 恢复上升角落修正（UpwardCornerCorrection）+ 新增空中 Dash 撞地角修正（DashCornerCorrection，用 `dash_started_on_ground` 门控）
- [x] 爬墙跳 / 翻墙 hop 扣 `climb_jump_stamina_cost`，死参数清零
- [x] 删除空壳 `scripts/player/states/`，TDD §4.1 改为记录 Player 内 Mode 状态机（与 Celeste 的 `int State` 一致）
- [x] 假回归测试重写为真实 headless 物理回归：25 条断言全部通过，且经"故意改坏 → 断言变红"自检
- [x] 抓墙不再自动下滑：`ClimbUpdate` 的 `target` 默认 0，只有 `SlipCheck()`（手高过墙沿）才 slip，另补 Up Limit / Down Limit
- [x] 抓墙贴合无空隙：拆分 `climb_check_distance`(3.75) 与 `wall_check_distance`(5.625)，抓墙瞬间照 `ClimbBegin` 逐像素吸附，攀爬中用 1px 邻接判定
- [x] 爬墙跳与墙跳分离：拉离墙 = `WallJump`（水平弹开、不扣体力），无方向 = `ClimbJump`（垂直、扣体力）
- [x] 反向 Hyper / 反向 Super：Facing 在 Dash 期间继续跟随 `moveX`（只有 Climb 例外）
- [x] 回归扩到 34 条断言，新增反向 Hyper、抓墙贴合、抓墙不下滑、爬墙跳 / 墙跳分离；两次故意改坏均被断言抓住
- [x] 输入缓存双路采样：`_unhandled_input` 捕获按下事件（不丢快速点按）+ 物理帧 `is_action_just_pressed` 补采样，写同一个缓存计时器
- [x] `move_x` / `move_y` 单点采样 + `forceMoveX`（墙跳 0.16 / SuperWallJump 0.2 / 翻墙 hop 0.2 归零），facing / 加速 / 跳跃加成 / 爬墙跳判定统一读同一份
- [x] Dash 起手冻结 `dash_freeze_time` 0.05s（参考 `Celeste.Freeze` + `DashCoroutine` 的 `yield return null`），**方向留到冻结结束才采样** → 修掉八向方向判定延迟
- [x] 墙沿反复 ClimbHop 抽干体力：补上参考的"上升中 / 离墙中不许抓墙"守卫（`Speed.Y >= 0 && sign(Speed.X) != -Facing`）；ClimbHop 改为免费动作（不扣体力、不算跳跃）+ `hopWaitX` 越沿才推速度
- [x] 墙面检测顺序对齐参考（先右后左），`_wall_jump_check` 统一 WallJumpCheckDist
- [x] 回归扩到 45 条断言，新增冻结期补按方向、墙沿只 hop 一次不抽体力、纯上 Dash 蹭平台侧面 SuperWallJump；三次故意改坏均被断言抓住
- [x] 墙跳跳高受按键时长控制：三条路径（空中墙跳 / 攀爬墙跳 / 垂直爬墙跳）实测点按 9-10px、按住 27-28px，回归断言固定
- [x] 修掉"按住抓取贴墙起跳被弹很远"：补上 `NormalUpdate` 跳跃段的 ClimbJump / SuperWallJump / WallJump 三分派（参考 2969-3004）
- [x] Wall Slide：贴墙下落上限 `lerp(MaxFall, WallSlideStartMax 20, timer/1.2)`，落地或起跳重置
- [x] Wallboost：中立爬墙跳武装 0.2s 窗口，窗口内推离墙面退还 `ClimbJumpCost` 且不锁输入 → 无体力可连续上墙
- [x] Wall Speed Retention（Cornerboost 来源）：`OnCollideH` 存撞墙前水平速度，0.06s 内离墙即还原
- [x] Fastfalling：按住下方向下落上限以 300 渐进到 240；重力改用 `Calc.Approach` 语义
- [x] Extended Dash：落地补 dash 加 `dash_refill_cooldown` 0.1s 门控
- [x] 尺度改为 Celeste 同规格：1 砖 8px、视口 320×180、站立碰撞箱 8×11、下蹲 8×6，所有参数照搬原值（不再有 ×1.875 的小数）
- [x] 下蹲实现：`NormalUpdate` 的 Ducking 段（底边固定、`duck_friction` 500、`CanUnDuck`、`DuckCorrectCheck` 4 / `DuckCorrectSlide` 50、空中自动站起）
- [x] Godot 适配 epsilon：`CONTACT_MARGIN` 0.001（贴墙吸附）、`SHAPE_INSET` 0.2（8px 身体穿 8px 缝）；角落修正改用整箱重叠检测
- [x] 清理过时代码：删除 `ConfigLoader.get_value` 死接口与未用局部变量、test_room 空 `Grid` 节点、CSV 被误当翻译表生成的 4 个 `.translation` 产物（改 importer=keep）
- [x] 回归扩到 71 条断言（新增 Wallboost / Wall Slide / Fastfall / dash 补充冷却 / 撞墙速度保留 / 下蹲 6 条组），并经"故意改坏 3 处 → 8 条断言变红"自检
- [x] Celeste wiki Tech 第 1/2/3 大条目逐项审计（见 §审计结论）
- [x] 修掉"Super / Wavedash / Hyper 之后冲刺不恢复"：①"是否站在地上"全部改用 Celeste 的几何探针 `_on_ground()`（`vy>=0 且脚下 1px 有实体`），不再用 Godot 的 `is_on_floor()`（水平 Dash / Dash Slide 帧里为假 → dash、体力、土狼都补不回来）；②碰撞层分离（地形 1 / 玩家 2 / 可携带物 4），此前 Theo 与地形同层且正好坐在出生跑道上，角色被它顶住 → 同样不补 dash
- [x] 回归扩到 80 条断言（新增 Super / Hyper 后仍持有 dash、水平 Dash 期间算站在地上、可携带物不阻挡角色），并经"故意把 Theo 改回层 1 → 断言变红"自检
- [x] 测试房按技巧分区重建（参考 Strawberry Jam Collab 教学房）：`scripts/levels/test_room.gd`（`@tool`）用 ASCII 网格生成 11 个分区，每区带标题与操作要点标签、目标标记，区间 2 砖坑分界，掉坑在本区入口自动重生
- [x] 调试字体不糊：`stretch/mode` 由 `viewport` 改 `canvas_items` + `scale_mode=integer`（启用动态字体 oversampling，按最终分辨率光栅化），`default_texture_filter=Nearest`；调试文字移到 `CanvasLayer` 固定屏幕左下、字号 6 + 黑描边

---

## 当前待办（按优先级）

- [x] 高级技巧审计修复：旧状态分散实现已被单一 Player 模拟替换；Super/Hyper/Ultra/Dash 保速用 headless 回归覆盖
- [ ] **手动试玩验证**：测试房确认 Super（地面横 K + J）、Hyper（地面斜下 K + J）、Ultra（空中斜下 K 撞地 + J）、反向 Hyper（Dash 中回拉 + J）的窗口手感，窗口 = `dash_duration` 0.15s
- [ ] **手动试玩验证**：Shift 抓墙贴合无缝、静止不下滑、上下攀爬、体力耗尽、爬墙跳 vs 墙跳、墙顶 hop（确认只翻一次且不掉体力）
- [ ] **手动试玩验证**：K 与方向键同时按下的八向方向是否还有延迟感；冻结 0.05s 的顿感是否合适（嫌顿改 `dash_freeze_time`）
- [ ] **手动试玩验证**：对平台边缘上冲蹭墙跳是否稳定触发；墙跳后 `wall_jump_force_time` 0.16s 的输入接管是否别扭
- [ ] **试玩验证**：Theo 与 Jellyfish 拾取、抛出、Jellyfish 先升后浮
- [ ] **试玩验证**：测试房区 9 的 1 砖天花板缝（向上 K 冲刺），确认角落修正塞得进去且不吸附
- [ ] **试玩验证**：新测试房 11 个分区的坑宽是否合适（headless 实测：区3 Dash+跳飞越 82px / 区4 Super 44px / 区5 Hyper 28px / 区6 Ultra 76px；坑分别 6/6/4/4 砖），偏难就调 `ZONES` 里的地面字符串
- [ ] **试玩验证**：区 2 低通道（下蹲不能走，只能带速度滑进或蹲着 K 冲）是否易懂
- [ ] **试玩验证**：跳高 3.6 砖是否偏矮；若偏矮只调 `var_jump_time`，不要改 `jump_speed`（会连带影响 Hyper 低跳）
- [ ] **试玩验证**：320×180 视口下相机取景与 debug 文字可读性；S 下蹲手感与低通道通行
- [ ] **试玩验证**：无体力时靠 Wallboost 连续上墙的节奏是否顺手；贴墙下滑速度是否偏慢

---

## 审计结论：Celeste wiki Tech 第 1/2/3 大条目

**已实现**：1.2 Climbhop、1.3 Corner Correction、1.4 Coyote Time、1.8 Fastfalling、1.9 Input Buffering（缓存 0.12s，Celeste 为 0.08s，属主动放宽）、
2.2 Superdash、2.3 Hyperdash、2.4 Wavedash、2.5 Extended Dashes、2.6 Reverse Dashes、2.8 Ultra / Grounded Ultra、2.10 Wallbounce、
3.1 Bunnyhop、3.2 Cornerkick、3.4 Crouch Jump、3.5 Neutral Jump、3.7 Cornerboost、3.11 Stamina Cancel、3.12 Wallboost。

**仍缺（需后续实现）**：
- [ ] 2.9 Demodash / Demohyper / Diagonal Demodash（需要 `duck + dash` 的组合输入与 demo 判定）
- [ ] 2.8.3 Delayed Ultra
- [ ] 3.3 Ceiling Pop
- [ ] 3.6 5jump
- [ ] 3.13 Cornerslip
- [ ] 1.5 Dash Attack 的细节判定（当前只有 `dash_attack_timer` 的基础用法）

**不适用（缺对应实体，等 M3+ 关卡机关）**：Berry、Directional Spikes、Fastbubbling、Liftboost、Screen Transition、Wind Resistance、Spring Cancel 及所有尖刺类技巧。


---

## 下一步任务（M3：首个关卡）

- [ ] 基于试玩反馈调校 Dash / Climb / Carryable CSV 参数与碰撞细节
- [ ] 补齐上表"仍缺"的 6 项技巧（优先 Demodash 系列，它是 Dashless/Dash 两大类的基础）
- [ ] 实现尖刺、检查点、掉落边界与即时复活
- [ ] 设计首个起承转合关卡
- [ ] 地形改用 `TileMapLayer`（8px 砖），替换当前手摆的 StaticBody2D

---

## 后续里程碑

- M3：首个起承转合关卡 + 尖刺/检查点/即时复活
- M4：参数仪表盘、死亡热力图、辅助模式
- M5+：环境机制、美术、更多关卡
