# Vibe Design Tips Skill (Community All-in-One Collection)

> **⚠️ 版权声明与原作者致谢 / Attribution & Credits**  
> 本仓库为社区整理的 **All-in-One 合集 Skill 封装版本（非官方仓库）**。  
> 全部设计规范、量化参数与分期改造提示词均源自设计师 **枯白 Kubai（[@Kubai087](https://x.com/Kubai087)）** 的开源免费系列教程 [**《999 个小技巧，让你 Vibe 的产品更有质感》**](https://vibedesign.tips/)（原站：[`https://vibedesign.tips`](https://vibedesign.tips/) · 原帖推荐：[X 讨论帖](https://x.com/Kubai087/status/2122917792903209141)）。  
> 原作者官方在网站按**单篇分散形式**提供逐期独立 `SKILL.md` 安装（截至 2026-11-19 官方 GitHub 发布的主仓库是动态图标库 [`kubai087/kubai-icons`](https://github.com/kubai087/kubai-icons)）。为了方便 AI Coding Agent 在一次对话中综合检索与应用全套规范，本仓库将已发布的 **001～022 期** 规范浓缩为统一入口 `SKILL.md` + 22 篇分册索引 `issues/`，供个人学习与开发辅助使用。**所有原始设计教程与提示词的著作权及解释权归原作者 [@Kubai087](https://x.com/Kubai087) 所有。**

---

## ✨ 这个合集 Skill 有什么不同？

- **一页总览 + 按需深入**：`SKILL.md` 提炼了高频通用的设计法则（同心圆角、微拟物按钮、等宽数字排版、浮层与加载状态矩阵、选择控件矩阵、液态玻璃边缘光与动效曲线），并兼顾 **Web CSS** 与 **iOS/macOS SwiftUI** 双端实现；
- **全 22 期完整收录**：`issues/001-*.md` ～ `issues/022-*.md` 原样收录了官网提供的完整分期改造规则与量化参数，Agent 可在需要某一项专项打磨（如镭射卡 `#018`、滚动卡片 `#019`、选择控件诊断 `#020`）时按需读取对应分册；
- **多端 Agent 开箱即用**：兼容 **Claude Code**、**OpenAI Codex CLI**、**Antigravity**、**Cursor** 等支持 `SKILL.md` 规范的工具。

---

## 🚀 一键安装 / Quick Install

```bash
git clone https://github.com/iamvicliu/vibe-design-tips-skill.git
cd vibe-design-tips-skill
chmod +x install.sh
./install.sh
```

`install.sh` 会自动将本 Skill（含 `SKILL.md` 与 `issues/`）安装到以下本机存在的 Agent 技能目录（也可传入参数指定单个目录）：

- Claude Code: `~/.claude/skills/vibe-design-tips`
- Codex: `~/.codex/skills/vibe-design-tips`
- Antigravity / Gemini: `~/.gemini/config/skills/vibe-design-tips`

### 手动安装 / Manual Install

只需将本仓库的 `SKILL.md` 和 `issues/` 文件夹整体拷贝到你所用 AI 工具的全局或项目级 `skills/vibe-design-tips/` 目录即可，例如：

```bash
mkdir -p ~/.claude/skills/vibe-design-tips
cp -R SKILL.md issues ~/.claude/skills/vibe-design-tips/
```

---

## 🔄 自动同步官网更新 / Auto Sync

本仓库通过 GitHub Actions（[`.github/workflows/sync-official.yml`](./.github/workflows/sync-official.yml)）**每天定时**从官方站点 [`https://vibedesign.tips`](https://vibedesign.tips/) 抓取最新发布及修订的分期内容，自动更新 `issues/`、`SKILL.md` 与 `README.md` 并提交到主分支（也支持在 Actions 页面手动点击 **Run workflow** 立即触发）。

本地手动同步与更新安装：

```bash
# 从官网同步最新期数与修订内容（纯 Python 3 标准库，无需安装依赖）
python3 scripts/sync_official.py

# 仅预览变更不写入文件
python3 scripts/sync_official.py --dry-run

# 同步官网最新内容并重新安装到本地 Agent 目录
./install.sh --sync
```

---

## 📚 收录期数一览（001～022 期）

<!-- AUTO-SYNC:README-TABLE:START -->
| 期数 | 主题 | 分册文件 |
| :--- | :--- | :--- |
| `#001` | 有按压反馈的拟物按钮（五层级、五层材质、按压光影） | [`001-skeuomorphic-buttons.md`](./issues/001-skeuomorphic-buttons.md) |
| `#002` | 级联菜单安全三角区与延时规则 | [`002-cascade-menu.md`](./issues/002-cascade-menu.md) |
| `#003` | 实时 ASCII 字符画与有序抖色（Dither） | [`003-ascii-dither.md`](./issues/003-ascii-dither.md) |
| `#004` | 同心圆角公式（`r = R - p`）与连续曲率（Squircle / Superellipse） | [`004-continuous-corners.md`](./issues/004-continuous-corners.md) |
| `#005` | 拖拽排序光标、落点线与相邻避让动效 | [`005-drag-ripple.md`](./issues/005-drag-ripple.md) |
| `#006` | 悬停立体翻书卡片 | [`006-book-cards.md`](./issues/006-book-cards.md) |
| `#007` | 中英文排版与等宽数字防抖动（`tabular-nums` / `text-wrap`） | [`007-type-switches.md`](./issues/007-type-switches.md) |
| `#008` | Wiki 与帮助中心双栏大纲布局规范 | [`008-wiki-layout.md`](./issues/008-wiki-layout.md) |
| `#009` | 浮层分级规则（Tooltip / Popover / Popconfirm / Drawer / Dialog） | [`009-overlays.md`](./issues/009-overlays.md) |
| `#010` | 液态玻璃六层材质与自适应文字对比度 | [`010-liquid-glass.md`](./issues/010-liquid-glass.md) |
| `#011` | 缓动曲线与动效 Token 体系 | [`011-easing-curves.md`](./issues/011-easing-curves.md) |
| `#012` | AI 对话消息气泡六种材质与收发/展开动效 | [`012-message-bubbles.md`](./issues/012-message-bubbles.md) |
| `#013` | 冲击波光环与透镜色散特效 | [`013-shockwave-glow.md`](./issues/013-shockwave-glow.md) |
| `#014` | 卡片删除消散特效（Burn / Plume / Blocks / Peel） | [`014-card-delete.md`](./issues/014-card-delete.md) |
| `#015` | 界面连续性与跨状态共享元素过渡 | [`015-ui-continuity.md`](./issues/015-ui-continuity.md) |
| `#016` | Toast 与通知中心的选择、堆叠与自动消隐规则 | [`016-toast-or-notification.md`](./issues/016-toast-or-notification.md) |
| `#017` | 加载状态选择矩阵（300ms 门槛 / 原地旋转 / 骨架屏 / 乐观更新） | [`017-loading-states.md`](./issues/017-loading-states.md) |
| `#018` | 3D 视差镭射卡片（6 种箔片材质预设与正反翻转） | [`018-holo-card.md`](./issues/018-holo-card.md) |
| `#019` | 滚动驱动的 5 种长页卡片交互（堆叠 / 飞牌 / 画廊 / 封面流 / 图片展开） | [`019-scroll-cards.md`](./issues/019-scroll-cards.md) |
| `#020` | 开关、复选框、单选、分段选择与下拉控件选用规则 | [`020-choice-controls.md`](./issues/020-choice-controls.md) |
| `#021` | 景深环形卡片、边缘玻璃色散与流体渐变（环内/环外双视角） | [`021-ring-cards.md`](./issues/021-ring-cards.md) |
| `#022` | 空状态诊断与改造（线框版 / 图标版 / 迷你版、按钮与文案规范） | [`022-empty-states.md`](./issues/022-empty-states.md) |
<!-- AUTO-SYNC:README-TABLE:END -->

---

## 🙏 支持原作者 / Support the Original Author

- 原作者网站（免费持续日更 + 交互式 Live Demo）：[**https://vibedesign.tips**](https://vibedesign.tips/)
- 在 X 上关注枯白 Kubai：[**@Kubai087**](https://x.com/Kubai087)
- 原作者开源的另一款动态图标库 + Agent Skill：[**kubai087/kubai-icons**](https://github.com/kubai087/kubai-icons)

> 如原作者团队有官方汇总仓库发布或对本社区整合版本有任何建议与下架需求，请随时联系或提交 Issue，我们将第一时间配合更新或归档。

## 📄 License

本仓库的整理结构、汇总 `SKILL.md` 索引与安装脚本采用 [MIT License](./LICENSE)；`issues/` 中收录的原始单期中文文案及提示词规范著作权归原作者 **枯白 Kubai (`@Kubai087`)** 所有，仅限学习参考与个人 AI 辅助开发使用。
