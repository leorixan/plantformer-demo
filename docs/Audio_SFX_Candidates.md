# 开源音效候选清单（试听用）

> 范围：移动基础、冲刺与紫块、拾取、机关、UI / 关卡完成。
> 所有来源均为 CC0 或可免费商用；每套都附试听/下载页。挑中后我再导入项目并接触发点。

---

## 1. 候选音效包（多套，按试听顺序排列）

### ① SubspaceAudio — 512 Sound Effects (8-bit style)

- 试听 + 下载：https://opengameart.org/content/512-sound-effects-8-bit-style
- 授权：CC0
- 体量：512 个音效，20.6 MB
- 风格：NES / C64 / 8-bit，短促、像素感强
- 覆盖：跳跃、落地、拾取、受击、UI、爆炸几乎全有
- 适合：先听这一套，确定整体是不是要复古 8-bit 方向

### ② Kenney — Impact Sounds

- 试听 + 下载：https://kenney.nl/assets/impact-sounds
- 授权：CC0
- 体量：130 个
- 风格：写实短音，干净
- 覆盖：落地（轻/重）、可破坏块碎裂、死亡、弹簧撞地
- 适合：想要比 8-bit 更"实"的撞击层；也可与 8-bit 叠在一起用

### ③ Kenney — Interface Sounds

- 试听 + 下载：https://kenney.nl/assets/interface-sounds
- 授权：CC0
- 风格：UI 点击、确认、返回、滑入/滑出
- 覆盖：菜单、暂停、关卡完成提示
- 适合：UI 这一组基本可以直接从这套里挑

### ④ SubspaceAudio / OGA — GUI Sound Effects

- 试听 + 下载：https://opengameart.org/content/gui-sound-effects
- 授权：CC0（OGA CC0 筛选内）
- 风格：偏复古的界面音，数量不多但很有味道
- 覆盖：菜单移动/确认/返回、暂停
- 适合：和 8-bit 主体搭配，比 Kenney UI 更"游戏机"一点

### ⑤ OGA — 51 UI sound effects (buttons, switches and clicks)

- 试听 + 下载：https://opengameart.org/content/51-ui-sound-effects-buttons-switches-and-clicks
- 授权：CC0
- 覆盖：按钮、开关、点击、滑条
- 适合：想要更"开关感"的 UI 音

### ⑥ OGA — 63 Digital sound effects (lasers, phasers, space etc.)

- 试听 + 下载：https://opengameart.org/content/63-digital-sound-effects-lasers-phasers-space-etc
- 授权：CC0
- 覆盖：冲刺、能量、激光、传送类
- 适合：冲刺起手、紫块进入/离开、弹簧的能量音、水晶

### ⑦ OGA — Level up, power up, Coin get (13 Sounds)

- 试听 + 下载：https://opengameart.org/content/level-up-power-up-coin-get-13-sounds
- 授权：CC0
- 覆盖：拾取、回复、奖励
- 适合：水晶回复 dash、奖杯收集、检查点

### ⑧ OGA — 35 wooden cracks / hits / destructions

- 试听 + 下载：https://opengameart.org/content/35-wooden-crackshitsdestructions
- 授权：CC0
- 覆盖：木头碎裂、撞裂
- 适合：可破坏块碎裂、弹簧起跳、木质平台落地

### ⑨ OGA — Swishes Sound Pack

- 试听 + 下载：https://opengameart.org/content/swishes-sound-pack
- 授权：CC0
- 覆盖：挥动、风切、快速移动
- 适合：冲刺中/冲刺收尾、紫块穿越的风声层

### ⑩ OGA — Different steps on wood, stone, leaves, gravel and mud

- 试听 + 下载：https://opengameart.org/content/different-steps-on-wood-stone-leaves-gravel-and-mud
- 授权：CC0
- 覆盖：不同材质脚步
- 适合：落地/奔跑的脚步层（可选，看是否要做脚步声）

### ⑪ 自制生成（jsfxr / Bfxr）

- jsfxr：https://sfxr.me/
- Bfxr：https://www.bfxr.net/
- 授权：生成文件无版权问题
- 适合：上面几套里找不到完全贴合的短音（例如水晶 4 帧冻结的"叮"、紫块果冻声），现调时长与音高

---

## 2. 与游戏事件的对应关系

### 移动基础
- 跳跃：512 套的 jump 类，或 jsfxr 做一个 80~120ms 上扬音
- 落地轻/重：Kenney Impact（轻、重各一）；可叠 512 套的低音层
- 墙滑：Swishes 里的短风切 loop，或 512 套的 slide
- 墙跳：跳跃音 + 一点摩擦（可用 Audacity 叠两个短音）
- 爬墙抓取：木质/布料短音（Kenney RPG 脚步或 wooden hits 里的短音）

### 冲刺与紫块
- 冲刺起手：63 Digital 的 laser/charge 类；要和 5 帧冻结对齐（50~90ms）
- 冲刺中：Swishes 的风声 loop，音量低
- 进入紫块：低沉 + 果冻感的短音，可用 jsfxr 调低通 + 快速衰减
- 离开紫块：63 Digital 的传送/释放类，或 Swishes 的收尾

### 拾取
- 水晶回复 dash：Level up 包里的 coin/power up 短音，要清脆、100~200ms；对应 4 帧冻结
- 奖杯收集：更长的奖励音，300~600ms，可两段叠
- 检查点：稳定确认音，不抢戏

### 机关
- 弹簧：wooden hits 的弹起声，横/竖弹簧用不同音高
- 可破坏块碎裂：35 wooden cracks 里的 crack/destruction，2~3 个变体
- 假地形显形：轻的沙沙声或 low 音量 noise（可选）

### UI / 关卡完成
- 菜单移动/确认/返回：Kenney Interface 或 51 UI 套
- 暂停/继续：Interface 的 confirm/back
- 关卡完成：Level up 包的 fanfare 类，或 512 套的 completion

---

## 3. 试听建议顺序（省时间）

1. 先听 **512 8-bit** 的 preview，确定整体方向
2. 再听 **Kenney Impact + Interface**，判断是否要更写实的撞击/UI
3. 然后听 **63 Digital**（冲刺/紫块）和 **Level up**（拾取）
4. 最后听 **wooden cracks / Swishes** 补机关与风声
5. 缺的声音用 jsfxr 现做，保证时长和动作精确对齐

---

## 4. 选好之后我做什么

1. 下载选中包，解压到 `assets/audio/_incoming/`（不提交大文件）
2. 按事件挑 2~3 个变体，统一命名：`jump_01.wav`、`dash_start_02.wav` 等
3. 导入 Godot：WAV 16-bit / 单声道 / 44.1k，短音效关闭循环，BGM 用 OGG
4. 接触发点：跳跃、落地、墙跳、冲刺起手/结束、水晶、奖杯、检查点、弹簧、可破坏块、死亡、UI
5. 记录 `docs/CREDITS.md`（包名、作者、链接、许可证）
6. 加一条 SFX 总线与音量控制（SFX / Music / Ambient 分开）
