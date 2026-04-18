# 🔄 Perpetual Dev

[OpenClaw](https://github.com/openclaw/openclaw) 的增强版自主编码循环。基于 [Ralph Wiggum](https://ghuntley.com/ralph/)，经过 40+ 轮真实项目开发实战验证。

**问题**：Ralph Wiggum 适合单次编码会话，但实际使用中你需要它跑一整晚、自动从故障中恢复、持续发现新的优化方向——不需要人盯着。

**Perpetual Dev** 通过自动 watchdog 续命、多引擎支持、实时进度汇报和自驱动优化循环解决了这些问题。

[English](README.md) | 中文

## 工作原理

```
while 用户没喊停:
    if IMPLEMENTATION_PLAN.md 有未完成任务:
        loop.sh build N    # Codex 或 Claude 写代码
    else:
        批判性审查所有代码
        找新的优化方向
        更新 IMPLEMENTATION_PLAN.md
        继续构建
    
    if 任务超时或失败:
        watchdog 5 分钟内自动恢复
        从断点继续
```

## 与 Ralph Wiggum 的区别

| 问题 | Ralph Wiggum | Perpetual Dev |
|------|-------------|---------------|
| 任务超时 | 手动重启 | watchdog 自动续命（5 分钟） |
| 计划全部完成 | 停止 | 自动审查代码，规划新一轮 |
| 编码引擎 | 仅 Claude Code | Codex CLI → Claude Code → 手动，自动降级 |
| 进度汇报 | 无 | Discord thread 实时更新 |
| 完成通知丢失 | 会话卡住 | 基于状态文件，不依赖通知回调 |
| Discord ID 精度 | 数字被截断 | `channel:` 前缀防止精度丢失 |
| 错误刷屏 | 重试时反复发消息 | 失败只汇报一次 |
| 价值评估 | 无 | P0-P3 优先级过滤 |

## 快速开始

### 1. 安装 Skill

```bash
# 复制到 OpenClaw skills 目录
cp -r perpetual-dev ~/.openclaw/skills/
# 或者软链接
ln -s $(pwd) ~/.openclaw/skills/perpetual-dev
```

### 2. 初始化项目

```bash
cd /path/to/your/project

# 复制模板
cp ~/.openclaw/skills/perpetual-dev/templates/PROMPT_build.md .
cp ~/.openclaw/skills/perpetual-dev/templates/PROMPT_plan.md .
cp ~/.openclaw/skills/perpetual-dev/templates/AGENTS_TEMPLATE.md ./AGENTS.md
cp ~/.openclaw/skills/perpetual-dev/templates/IMPLEMENTATION_PLAN_TEMPLATE.md ./IMPLEMENTATION_PLAN.md

# 复制循环脚本（选择你的引擎）
cp ~/.openclaw/skills/perpetual-dev/scripts/loop-codex.sh ./loop.sh
# 或者
cp ~/.openclaw/skills/perpetual-dev/scripts/loop-claude.sh ./loop.sh
chmod +x loop.sh

# 写需求规格
mkdir -p specs
echo "# 我的功能规格" > specs/my-feature.md
```

### 3. 告诉 OpenClaw

直接说：

> "永动机跑起来" 或 "start perpetual dev on this project"

OpenClaw 会自动：
1. 检测可用的编码引擎（Codex CLI / Claude Code）
2. 创建 Discord thread 汇报进度
3. 设置 watchdog cron（每 5 分钟检查）
4. spawn 第一个编码任务
5. 持续运行直到你说停

### 4. 停止

> "停" 或 "stop the perpetual dev"

## 编码引擎

Perpetual Dev 自动检测并使用最佳可用引擎：

| 优先级 | 引擎 | 命令 | 费用 |
|--------|------|------|------|
| 1 | Codex CLI | `codex exec --full-auto` | OpenAI 额度 |
| 2 | Claude Code | `claude -p --dangerously-skip-permissions` | Anthropic 额度 |
| 3 | 手动模式 | OpenClaw read/write/edit/exec | 模型额度 |

调度 Agent（Opus）负责规划和任务管理，编码引擎负责实际实现。这种分离意味着大部分 token 消耗在更便宜的编码引擎上。

## 架构

```
┌─────────────────────────────────────────┐
│           OpenClaw 主会话                │
│         （Opus — 调度编排）               │
│                                         │
│  "永动机跑起来"                           │
│       ↓                                 │
│  1. 检测编码引擎                          │
│  2. 创建 Discord thread                 │
│  3. 创建 watchdog cron                  │
│  4. spawn 编码任务                       │
└──────────┬──────────────────────────────┘
           │
    ┌──────▼──────┐     ┌──────────────┐
    │   编码任务    │     │   Watchdog   │
    │ (Opus+Codex) │     │  （每 5 分钟） │
    │              │     │              │
    │ loop.sh ─────┤     │ 检查存活     │
    │  └─ codex    │     │ 挂了 →      │
    │     exec     │     │   自动续命   │
    │              │     │              │
    └──────┬───────┘     └──────────────┘
           │
    ┌──────▼──────┐
    │   状态持久化  │
    │              │
    │ PLAN.md ─────│── 唯一信源
    │ git log ─────│── 进度证明
    │ thread ──────│── 人类可见
    └─────────────┘
```

## 状态管理

Perpetual Dev 从不依赖内存状态或通知回调。所有状态都持久化：

- **IMPLEMENTATION_PLAN.md** — 任务完成状态（`[x]` vs `[ ]`）
- **git log** — 工作证明（带时间戳的 commit）
- **Discord thread** — 人类可读的进度记录
- **watchdog cron** — 确保连续性的心跳

如果任务超时，下一次 spawn 会读取 `IMPLEMENTATION_PLAN.md` 并从断点精确恢复。

## 价值评估

每轮规划必须为每个提议的任务回答三个问题：

1. **解决什么真实问题？**（不是"代码可以更好"——而是"用户会遇到这个 bug"）
2. **不做会怎样？**（如果答案是"没影响"→ 跳过）
3. **怎么验证有效？**（必须有可测量的结果）

优先级：
- **P0**：会导致线上故障（必须做）
- **P1**：用户能感知到的问题（应该做）
- **P2**：开发者体验 / 代码质量（有空做）
- **P3**：锦上添花（最后做）

如果连续 3 轮找不到新任务，watchdog 自动暂停并通知用户。

## Discord Thread 汇报

进度消息格式：

```
⏳ 正在: <任务描述>
✅ 完成: <任务描述> | 改了: <文件列表>
❌ 失败: <错误描述>（只报一次，不重复）
📊 本轮总结: N 个任务完成，M 次 commit
```

**重要**：Discord thread ID 必须使用 `channel:` 前缀，防止 JavaScript 数字精度丢失：

```
✅ 正确: to = "channel:1494956741056532531"
❌ 错误: to = "1494956741056532531"  （会丢精度）
❌ 错误: to = 1494956741056532531    （数字，不是字符串）
```

## 文件结构

```
perpetual-dev/
├── SKILL.md                              # OpenClaw skill 定义
├── README.md                             # English README
├── README_CN.md                          # 中文 README（本文件）
├── scripts/
│   ├── loop-codex.sh                     # Codex CLI 循环脚本
│   └── loop-claude.sh                    # Claude Code 循环脚本
└── templates/
    ├── PROMPT_build.md                   # 构建模式 prompt
    ├── PROMPT_plan.md                    # 规划模式 prompt
    ├── AGENTS_TEMPLATE.md                # 项目构建命令模板
    └── IMPLEMENTATION_PLAN_TEMPLATE.md   # 任务跟踪模板
```

## 实战踩坑经验

这些是 40+ 轮通宵开发中遇到的真实问题：

1. **完成通知不可靠** — 不要依赖 announce 回调。用 watchdog + 状态文件。
2. **Discord ID 在 JSON 中丢精度** — 始终用 `channel:` 前缀。
3. **Codex ACP 会话太短** — 用 Codex CLI（loop.sh）而不是 ACP runtime。
4. **失败重试导致刷屏** — 在任务指令中强制"失败只报一次"。
5. **Gateway 重启导致孤儿会话** — watchdog 自动处理。
6. **"全部完成"不等于停止** — 自动审查代码，找新的优化方向。
7. **模型选择很重要** — Opus 做调度，Codex 做编码。别搞混了。

## 致谢

- 基于 [Ralph Wiggum](https://ghuntley.com/ralph/) by [@GeoffreyHuntley](https://github.com/ghuntley)
- 为 [OpenClaw](https://github.com/openclaw/openclaw) 打造
- 在 [Linyn-kf](https://github.com/laolin5564/linyn-kf) 项目上实战验证

## 开源协议

MIT
