# Pinball Roguelike

2D 柏青哥风格的弹珠肉鸽原型，Godot 4.7 制作，白盒阶段（色块 + 占位图形）。当前版本 **v0.2.0**。

用 50 颗球的库存，在 90 秒内靠发射弹珠撞击图钉、穿过金环、落进底部洞口刷分。
分数达到本关目标即过关，过关后从 3 张强化里挑 1 张，进入更难的下一关。

## 怎么玩

| 操作 | 说明 |
| --- | --- |
| 移动鼠标 | 瞄准，发射器指向鼠标，限制在朝上的扇形内 |
| 按住左键 | 蓄力，越满越准、力度越大 |
| 松开左键 | 发射，消耗 1 颗库存球 |
| Tab | 查看累积强化、剩余图钉、关卡跳转 |
| L | 排行榜：前 10 局成绩 + 历史最高分 |
| Esc | 退出确认（退出前自动存档） |
| F1 | 开关准星 |
| 右上角"结算" | 随时提前结束本局 |

**蓄力拉满会打出重球**：橙色、质量更大，撞脆钉一击必碎且图钉分双倍。

## 存档与排行榜

- **存档**（`user://save.json`）：每次结算、每次退出自动保存——当前关卡、已解锁关卡、累积强化、历史最高分。下次打开接着上次的关卡和强化继续，HUD 左下角显示"存档：第 N 关 · 历史最高 X 分"。
- **排行榜**（`user://leaderboard.json`）：每局结算记一条（分数 / 关卡 / 是否过关 / 发射数 / 时间），按分数取前 10，按 `L` 查看；面板里"清空存档"会把进度和榜单一起清掉。
- 只存**局外进度**，不存局内状态（剩余球数、剩余时间、场上球的位置）：一局只有 90 秒，重开一局的成本远低于把物理场景整个序列化。

## 台面元素

| 元素 | 行为 |
| --- | --- |
| 脆钉（白） | 3 点耐久，越打越红，打碎消失并加分 |
| 硬钉（蓝） | 打不碎，只能吃分，永远留在台面上 |
| 金环 | 穿过得分并涨连击，球不消失 |
| 洞口（7 个） | 回球 + 计分，分值 50–600 |
| 普通区域（5 个） | 球消失，不回球也不扣分 |
| 旋转挡板 | 把撞上来的球甩向随机方向 |
| 传送门 | 从一端进、另一端出，保留速度 |
| 加速带 | 把球朝设定方向推一把 |

两套数字别混淆：**球数 = 资源**（发射 -1、进洞 +N，归零就出局），**分数 = 成绩**（够目标分才过关）。

## 运行

**方式一：直接跑源码**

1. 安装 [Godot 4.7](https://godotengine.org/download/archive/)（标准版，非 .NET）
2. 克隆本仓库，用 Godot 打开 `project.godot`
3. 按 **F5**

**方式二：下载 exe**

见 [Releases](../../releases) 页面的 Windows 版压缩包，解压后运行 `PinballRoguelike.exe`，无需安装 Godot。

## 当前进度

- 核心循环已跑通并通过无头冒烟测试：发射 → 弹 → 进洞 → 球数/分数变化 → 再来一发
- 已完成：球数经济、计分与连击、金环、脆钉/硬钉、重球、台面元素、15 种局间三选一强化、关卡递进、HUD 与结算
- 目标分已按无头试玩数据重校准：第 1 关 18000（2026-10-12，与洞口回球 -1 同步调整），仍待真机手感验证

## 项目结构

```
scenes/         Main.tscn（主场景）、ui/HUD.tscn
scenes3d/       LauncherPreview.tscn（3D 资源预览场景）
scripts/        GameManager、Launcher、Ball、PegBoard、Bucket、Ring
                Spinner、Portal、Booster、ui/hud.gd
assets/         SVG 占位素材
assets3d/       launcher.glb（发射器 3D 资源）+ Godot 预览截图
tools/blender/  build_launcher.py（bpy 建模脚本，可重复跑）
tools/          capture_preview.gd（生成 3D 预览场景 + 截图）
tests/          ab_test.gd（弹性 A/B）、chaos_test.gd（乱打/瞄准模拟）
docs/           设计文档（见下）
```

### 3D 资源（发射器）

发射器已做成 3D 资源（Blender 4.2 + bpy 脚本，三角面 2512、高 1.142、原点在底面中心），工程里只放 `.glb`；
`.blend` 源文件放在提交目录（放工程里会触发 Godot 的 Blender 导入器报错）。重建方式：

```bash
blender --background --python tools/blender/build_launcher.py     # 重建模型 + 导出 glb + 渲染三视图
godot --path . -s tools/capture_preview.gd                        # 生成预览场景 + 预览截图
```

设计文档在 `docs/`：

| 文件 | 内容 |
| --- | --- |
| `bible/SPEC.md` | 规格与全部可调数值边界 |
| `bible/MODULES.md` | 各系统职责与依赖 |
| `bible/EXPERIENCE.md` | 体验目标与测试记录 |
| `bible/99_decisions.md` | 设计决策记录 |
| `MVP_Scope.md` | 范围声明 |
| `Core_Loop.md` | 核心循环拆解 |
| `Priority_Backlog.md` | 功能优先级表 |

改任何 `@export` 数值时，记得同步 `bible/SPEC.md` 的数值表。
