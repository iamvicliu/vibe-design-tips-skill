---
name: vibe-design-tips
description: 使用 Vibe Design Tips（@Kubai087，《999 个小技巧，让你 Vibe 的产品更有质感》）的量化界面质感规范审查与打磨 iOS/macOS SwiftUI 与 Web UI。触发词：界面质感、圆角、排版、拟物按钮、液态玻璃、动效曲线、加载状态、选择控件、空状态、连续性、vibe design tips。
---

# Vibe Design Tips UI 质感打磨指南（All-in-One 001～022 期精华）

> **致谢与来源声明**：本 Skill 中的设计法则、量化参数与单期改造提示词整理自设计师 **枯白 Kubai（[@Kubai087](https://x.com/Kubai087)）** 的免费开源设计专栏 [**Vibe Design Tips**](https://vibedesign.tips/)（《999 个小技巧，让你 Vibe 的产品更有质感》），原始版权归原作者所有。  
> 各期完整原版提示词与细则存放于同目录下的 `./issues/<slug>.md`（已按 001～022 期完整收录）。

## 1. 最常用高频量化法则（可直接落地到 SwiftUI 与 Web CSS）

1. **#004 递进式同心圆角 & 连续曲率 (`superellipse` / `.continuous`)**：
   - 公式：**`内圆角 = 外圆角 − 间距`（`r = R - p`）**，同层级元素共用同一圆角，最小不低于 `4`，胶囊 `Capsule` / 圆形保持全圆，所有间距/圆角尽量落在 `4pt / 4px` 网格。
   - **SwiftUI**：全部 `RoundedRectangle` 统一使用 `style: .continuous`；外层卡片若 `R = 22`、`padding = 14~18`，内部输入框/内嵌按钮圆角取 `10~12`。
   - **Web CSS 渐进增强**：
     ```css
     @supports (corner-shape: superellipse(1.25)) {
       .card, .stat-card, select, input, textarea, button:not(.pill) {
         corner-shape: superellipse(1.25);
       }
     }
     ```

2. **#001 微拟物按压反馈与 1px 顶部高光（Tactile Buttons）**：
   - 顶面从上到下略亮 `6–8%`，内阴影顶部保留 `1px` 高光，底边有轻微接地阴影；
   - 按下瞬间：**SwiftUI** 使用 `ButtonStyle` 配合 `.scaleEffect(isPressed ? 0.972 : 1)` + 弹性曲线（`120ms~220ms`）；**Web** `:active` 下沉 `translateY(1px)`、外阴影收敛。

3. **#007 中英文排版与数字防抖动（Typography & Tabular Nums）**：
   - 所有实时变化或对齐的数字（进度、倒计时、电量斜率、版本号、计分）必须开启 **等宽数字**（SwiftUI `.monospacedDigit()`，CSS `font-variant-numeric: tabular-nums`），避免数字跳变引发按钮或列表抖动；
   - 标题使用 `text-wrap: balance`，正文使用 `text-wrap: pretty`，按钮文字固定单行（`white-space: nowrap` / `.lineLimit(1)`），弹性容器内长文本外层设 `min-width: 0`。

4. **#009 浮层分级 & #017 原地加载态（Overlays & Loading States）**：
   - 补充说明 → Tooltip；可撤销或常见反馈 → Toast；不可逆/高风险切换 → 确认弹窗；长表单/独立管理 → Drawer / Sheet / 二级导航页面；Web 端优先使用原生 Popover API、`dialog.showModal()` 与 CSS Anchor Positioning；
   - `300ms` 以内不显示加载态；单个按钮触发的短操作，由按钮**自身原地图标/文案切换**（不要插入额外提示条撑开页面导致跳动）；耗时可计数任务显示进度条与剩余时间（`ProgressView(value:total:)`）。

5. **#010 液态玻璃边缘质感 & #011 动效曲线 & #015 界面连续性**：
   - 卡片与悬浮面板顶部加入微妙 `0.5~1px` 内边缘高光与轻量投影（注意在长列表 `ScrollView` 中避免将多图层叠加 `.clipShape` 挂复杂阴影触发离屏渲染）；
   - 入场 `ease-out`、离场 `ease-in`、状态位移动画用 `spring`（`0.28~0.35s`, `dampingFraction: 0.78`），尽量用单一平滑过渡替代硬切闪烁；
   - 界面连续性：状态变化时尽量让当前元素直接平滑过渡到下一状态，而非消失再突然重建。

6. **#020 选择控件选用矩阵（Switch / Checkbox / Radio / Segmented / Select / Dropdown）**：
   - **Switch vs Checkbox**：拨动立即生效的独立设置项用 Switch（不要两个 Radio On/Off）；随表单一起保存提交的选项或多选列表用 Checkbox；
   - **Select vs Dropdown Menu**：Select 用于选定“值”（选中后回显在触发框且列表内打勾 checkmark，不要用单选圆圈）；Dropdown Menu 用于收纳“动作”（导出、复制、删除），点选后立即执行而不替换触发按钮名称；
   - **单选控件按数量分级**：`2–5` 项简短选项用分段选择 `Segmented Control`；`2–5` 项需整行说明的选项用 `Radio`（若可不选则提供「暂不确定/无」选项）；`6` 项以上或动态增删的列表改用 `Select`（上百项配搜索与空状态）。

7. **#022 空状态诊断与改造（Empty States）**：
   - 按空间大小选尺寸（页面 / 卡片 / 单行 / 菜单）而非只按类型：保留页面骨架（标题栏、搜索框、筛选条件），避免空白区域、裸“暂无数据”或永不结束的加载圈；
   - 顺序固定为「图形（双色图标或自绘线框，避免通用插画/emoji）→ 标题 → 说明（卡片/行/菜单级省略）→ 最多 1 主 1 次动词按钮」；错误提示用人话说明发生了什么、数据是否安全及下一步，不直接暴露 HTTP 500 / 堆栈信息。

## 2. 完整分册索引（001～022 期）

需要某一期完整参数、诊断方法或详细 Prompt 时，直接读取本 Skill 目录下的 `./issues/<slug>.md`：

<!-- AUTO-SYNC:SKILL-TABLE:START -->
| 分类 | 期号与文件 | 核心主题 |
| :--- | :--- | :--- |
| **按钮与材质** | [`001-skeuomorphic-buttons.md`](./issues/001-skeuomorphic-buttons.md) | 拟物按钮五层级、五层材质与按压状态 |
|  | [`003-ascii-dither.md`](./issues/003-ascii-dither.md) | 图片/视频实时 ASCII 字符画与有序抖色 |
|  | [`010-liquid-glass.md`](./issues/010-liquid-glass.md) | 液态玻璃六层材质与自适应文字对比度 |
| **布局与排版** | [`004-continuous-corners.md`](./issues/004-continuous-corners.md) | 同心嵌套圆角公式 `r = R - p` 与 `superellipse` |
|  | [`007-type-switches.md`](./issues/007-type-switches.md) | 中英文混排、孤字消除与等宽数字防抖动 |
|  | [`008-wiki-layout.md`](./issues/008-wiki-layout.md) | Wiki 与帮助中心双栏大纲及移动端适配 |
| **交互、浮层与控件** | [`002-cascade-menu.md`](./issues/002-cascade-menu.md) | 级联菜单安全三角区与开/切/关延时 |
|  | [`009-overlays.md`](./issues/009-overlays.md) | Tooltip / Popover / Popconfirm / Drawer / Dialog 分级 |
|  | [`016-toast-or-notification.md`](./issues/016-toast-or-notification.md) | Toast 与通知中心选用与堆叠规则 |
|  | [`017-loading-states.md`](./issues/017-loading-states.md) | 加载状态时间门槛与原地/骨架/进度矩阵 |
|  | [`020-choice-controls.md`](./issues/020-choice-controls.md) | Switch / Checkbox / Radio / Segmented / Select / Menu |
|  | [`022-empty-states.md`](./issues/022-empty-states.md) | 空状态诊断与改造（线框版 / 图标版 / 迷你版与文案规范） |
| **高级动效与卡片** | [`005-drag-ripple.md`](./issues/005-drag-ripple.md) | 拖拽排序光标、插入线与相邻避让波纹 |
|  | [`006-book-cards.md`](./issues/006-book-cards.md) | 悬停立体翻书卡片 |
|  | [`011-easing-curves.md`](./issues/011-easing-curves.md) | 动效缓动曲线与 Motion Token 体系 |
|  | [`012-message-bubbles.md`](./issues/012-message-bubbles.md) | AI 对话消息气泡六种材质与收发/展开动效 |
|  | [`013-shockwave-glow.md`](./issues/013-shockwave-glow.md) | 点击触发全页冲击波光环与透镜色散 |
|  | [`014-card-delete.md`](./issues/014-card-delete.md) | 卡片删除消散特效（Burn / Plume / Blocks / Peel） |
|  | [`015-ui-continuity.md`](./issues/015-ui-continuity.md) | 界面连续性与跨状态平滑形变过渡 |
|  | [`018-holo-card.md`](./issues/018-holo-card.md) | 3D 视差镭射会员卡/徽章（6 种材质预设） |
|  | [`019-scroll-cards.md`](./issues/019-scroll-cards.md) | 滚动驱动的 5 种长页卡片叙事交互 |
|  | [`021-ring-cards.md`](./issues/021-ring-cards.md) | 景深环形卡片、边缘玻璃色散与流体渐变 |
<!-- AUTO-SYNC:SKILL-TABLE:END -->

## 3. Agent 审查与落地工作流

1. **先诊断再改动**：检查产品现有控件、圆角、数字排布、按压反馈、加载态与动效连续性，优先复用项目已有设计 Token 和原生组件，不强行引入冗余第三方 UI 依赖。
2. **明确量化参数**：调整时给出具体圆角数值（`R - p`）、动画曲线、数字防抖处理与交互分支说明。
3. **移动端性能边界**：在 iOS SwiftUI 长列表/表单中使用卡片与高光质感时，避免无节制堆叠 `.clipShape` + 大半径阴影造成 GPU 离屏渲染卡顿，必要时将阴影挂在最底层单色实体几何形状上。
