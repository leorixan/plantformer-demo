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
- [x] M2 控制重构：统一 J/K 输入缓存；同向超速 Dash、冻结期、结束速度；Super / Hyper / Ultra / CB；墙跳、攀爬、翻越（已按 Celeste 帧时序修复并完成 headless 验证）
- [x] Player 子节点 UI：Dash pips、stamina bar，数值驱动且不随角色翻面

---

## 当前待办（按优先级）

- [x] 高级技巧审计修复：SuperWallJump、VarJump、Ultra 本帧落地、CB dash 攻击资格、Cornerkick 有效冲刺资格与 CSV 同步
- [ ] **手动试玩验证**：按测试房路线验证 Super、Hyper、Ultra、CB、Cornerkick 的手感与参数窗口
- [ ] **手动试玩验证**：Shift 抓墙、上下攀爬、体力耗尽、墙跳、墙顶翻越
- [ ] **试玩验证**：Theo 与 Jellyfish 拾取、抛出、Jellyfish 先升后浮
- [ ] **试玩验证**：角落修正是否吸附角色；频繁顶头是否造成 x 轴漂移

---

## 下一步任务（M3：首个关卡）

- [ ] 基于试玩反馈调校 Dash / Climb / Carryable CSV 参数与碰撞细节
- [ ] 实现尖刺、检查点、掉落边界与即时复活
- [ ] 设计首个起承转合关卡
- [ ] 验证高级技巧自然涌现：super / hyper / ultra / CB / 咖啡跳 / 兔子跳

---

## 后续里程碑

- M3：首个起承转合关卡 + 尖刺/检查点/即时复活
- M4：参数仪表盘、死亡热力图、辅助模式
- M5+：环境机制、美术、更多关卡
