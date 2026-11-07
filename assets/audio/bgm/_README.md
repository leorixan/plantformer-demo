# Plantformer BGM 候选

来源：Mixkit 免费音乐库（https://mixkit.co/free-stock-music/）
许可：Mixkit Stock Music Free License（可商用、无需署名、不可把音乐作为独立素材再分发）。

候选方向：
- Celeste-like 钢琴/氛围：Silent Descent、Beautiful Dream、Discover、Piano Reflections、Staring at the Night Sky、Tears of Joy
- 氛围/探索：Forest Mist Whispers、Feedback Dreams、Opalescent、Echoes、Fallen (Asper)、Charlotte
- 轻快/平台感：Keeping Fit、Bold and Brash
- 古典/完成：Cristales

试听页：`_audition.html`（内嵌 10 秒片段）
完整曲目：当前目录的 MP3；`_all_bgm.m3u8` 用 VLC 播全部

## 已选用（循环版）

- 主菜单：07 Forest Mist Whispers -> `bgm_menu.ogg`（144.9s 循环）
- 游戏前段：01 Silent Descent -> `bgm_early.ogg`（153.7s 循环）
- 游戏后段：09 Opalescent -> `bgm_late.ogg`（274.1s 循环）

房间切换逻辑在 `scripts/levels/graybox_level.gd` 的 `_on_room_changed()`：
前段 = room5/room4/room6/bonus2；后段 = room3/room2/room1/bonus1/void。
