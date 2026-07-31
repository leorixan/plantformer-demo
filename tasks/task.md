# Plantformer Demo - 任务清单

> 来源：`.claude/memory/session-log.md`
> 规则：每次执行后更新本文件，标记已完成任务，写出下一步任务。

---

## 已完成

- [x] M1 角色核心：FSM + Idle/Run/Air + 土狼/缓存/角落修正/可变跳高 + 灰盒测试场景
- [x] M2 动作扩展：8 向 Dash、墙抓/攀爬/墙跳、Theo 与 Jellyfish 抓取抛接
- [x] 输入映射：J 跳、K 冲刺、Shift 抓、A/D/方向键移动
- [x] 15×15 网格基准、相机 zoom 2、角色 12×21
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

---

## 当前待办（按优先级）

- [x] 高级技巧审计修复：旧状态分散实现已被单一 Player 模拟替换；Super/Hyper/Ultra/Dash 保速用 headless 回归覆盖
- [ ] **手动试玩验证**：测试房确认 Super（地面横 K + J）、Hyper（地面斜下 K + J）、Ultra（空中斜下 K 撞地 + J）、反向 Hyper（Dash 中回拉 + J）的窗口手感，窗口 = `dash_duration` 0.15s
- [ ] **手动试玩验证**：Shift 抓墙贴合无缝、静止不下滑、上下攀爬、体力耗尽、爬墙跳 vs 墙跳、墙顶 hop（确认只翻一次且不掉体力）
- [ ] **手动试玩验证**：K 与方向键同时按下的八向方向是否还有延迟感；冻结 0.05s 的顿感是否合适（嫌顿改 `dash_freeze_time`）
- [ ] **手动试玩验证**：对平台边缘上冲蹭墙跳是否稳定触发；墙跳后 `wall_jump_force_time` 0.16s 的输入接管是否别扭
- [ ] **试玩验证**：Theo 与 Jellyfish 拾取、抛出、Jellyfish 先升后浮
- [ ] **试玩验证**：测试房 x=735~750 的 1 格天花板缝，确认角落修正塞得进去且不吸附
- [ ] **试玩验证**：跳高 3.6 格是否偏矮；若偏矮只调 `var_jump_time`，不要改 `jump_speed`（会连带影响 Hyper 低跳）


---

## 下一步任务（M3：首个关卡）

- [ ] 基于试玩反馈调校 Dash / Climb / Carryable CSV 参数与碰撞细节
- [ ] 实现尖刺、检查点、掉落边界与即时复活
- [ ] 设计首个起承转合关卡
- [ ] 给回归测试补 SuperWallJump、咖啡跳（Cornerkick）、兔子跳链式保速三条断言

---

## 后续里程碑

- M3：首个起承转合关卡 + 尖刺/检查点/即时复活
- M4：参数仪表盘、死亡热力图、辅助模式
- M5+：环境机制、美术、更多关卡
