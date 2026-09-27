# MODULES · 系统分工

> 只描述职责与接口，不描述实现细节。

## 模块一览

| 模块 | 职责（一句话） | 输入 / 输出 | 依赖 |
| --- | --- | --- | --- |
| GameManager（`Main/GameManager` 节点，非 autoload） | 全局状态：球数、分数、连击、关卡、倒计时、阶段、结算判定、局间强化累积 | 输入：发射请求、球数增减请求、得分请求、结算请求、强化选择；输出：`balls_changed` / `score_changed` / `combo_changed` / `level_changed` / `time_changed` / `phase_changed` / `round_result` / `round_started` / `buffs_changed` 九个信号 | 无（不依赖任何场景节点） |
| Launcher | 鼠标瞄准，按住左键蓄力，松开复制并发射一颗球；清理飞出屏幕的球 | 输入：鼠标左键（停在 UI 上时忽略）；输出：向场景添加球节点、施加冲量 | GameManager（校验能否发射）、BallTemplate（复制源） |
| BallTemplate | 弹珠模板，定义碰撞形状与物理材质 | 输出：被复制的球实例 | 无 |
| Ball（复制出的实例，脚本 `ball.gd`） | 撞图钉时计分并让图钉掉耐久；超时自毁。重球（蓄力满）撞钉一击必碎且双倍分 | 输入：物理碰撞；输出：通知 GameManager 计分、通知 PegBoard 掉耐久 | GameManager、PegBoard |
| PegBoard | 图钉阵，改变球的运动方向；每局随机决定缺失、左右移动、以及每颗钉是脆钉还是硬钉；维护脆钉耐久，击碎后消失，脆钉清空发一次性奖励 | 输入：`Ball` 的撞击请求；输出：反弹、耐久变化、击碎加分 | GameManager（只读 `level`，监听 `round_started`） |
| Spinner（旋转挡板，脚本 `spinner.gd`） | 绕自身中心匀速旋转，把撞上来的球甩向随机方向 | 输入：球的物理碰撞；输出：反弹 + 切向甩动 | GameManager（只读 `level`，监听 `round_started`） |
| Portal（传送门，脚本 `portal.gd`） | 球从一端进、另一端出，速度保留；两端都进冷却 | 输入：球进入区域；输出：改变球的位置 | 对侧的 Portal（NodePath） |
| Booster（加速带，脚本 `booster.gd`） | 球进入时被朝设定方向推一把 | 输入：球进入区域；输出：给球施加冲量 | 无 |
| Walls（LeftWall / RightWall / Ceiling） | 把球约束在视口内 | 输入：球的物理碰撞；输出：反弹 | 无 |
| Floor | 屏幕底部地面 | 输入：球的物理碰撞 | 无 |
| Ring（RingA–RingD） | 空中得分区，球穿过即得分并涨连击，球不消失 | 输入：球进入区域；输出：通知 GameManager 计分 | GameManager |
| Bucket（RewardBucket / NormalZone，脚本 `bucket.gd`） | 底部区域；洞口回球 + 计分，普通区域只让球消失 | 输入：球进入区域；输出：通知 GameManager 加球 / 球已离场 | GameManager |
| HUD（CanvasLayer，脚本 `ui/hud.gd`） | 显示关卡/时间/球数/分数/连击/蓄力条，提供结算、三选一强化、重试、属性面板与关卡跳转 | 输入：GameManager 的信号；输出：结算请求、强化选择、重试请求、跳关请求 | GameManager、Launcher（只读蓄力值） |

## 依赖关系

```
GameManager  ←── Launcher（请求发射、扣球）
     ↑
     ├─────── Ball（撞钉计分）
     ├─────── Ring（穿环计分）
     ├─────── Bucket（进洞回球 / 球离场通知）
     ├─────── Launcher（球被清理通知）
     ├─────── PegBoard（只读 level，监听 round_started）
     └─────── HUD（只读 + 发起结算/强化/重试/跳关）

Launcher ──→ BallTemplate（复制）
HUD ──→ Launcher（只读 _charging / _charge）
```

约束：GameManager 不引用任何具体场景节点，只发信号；场景节点单向依赖 GameManager。禁止反向依赖，避免循环。

## 寻址约定

GameManager 不是 autoload，而是 `Main.tscn` 里的第一个子节点。所有需要它的节点统一用绝对路径 `get_node_or_null("/root/Main/GameManager")` 获取——**前提是主场景根节点名必须是 `Main`**，改名会全盘失效。

## 添加新模块的规则

新增实体（道具、Boss、新区域）时：先在 MODULES.md 补一行职责与依赖，再动手；若依赖数超过 3 个，先拆分或找我确认。
