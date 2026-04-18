---
name: perpetual-dev
description: 永动机自主开发模式。给定项目目录和目标，持续循环：审查→规划→编码→测试→commit→推送，直到用户喊停。自动管理 watchdog 续命、编码引擎选择、进度汇报、断点恢复。基于 Ralph Wiggum 模式增强。触发词：永动机、持续开发、perpetual、自主循环开发、跑一晚上。
homepage: https://github.com/ghuntley/how-to-ralph-wiggum
user-invocable: true
metadata:
  version: "1.0.0"
  openclaw:
    os: ["darwin", "linux"]
---

# Perpetual Dev — 永动机自主开发模式

基于 Ralph Wiggum 的增强版。解决了实际使用中遇到的所有问题。

## 与 Ralph Wiggum 的区别

| 问题 | Ralph Wiggum | Perpetual Dev |
|------|-------------|---------------|
| 子任务超时 | 手动重启 | watchdog 自动续命 |
| 计划全部完成 | 停止 | 自动审查→规划新轮次 |
| 编码引擎 | 只支持 claude CLI | Codex CLI / Claude Code / 手动模式，自动 fallback |
| 进度汇报 | 无 | Discord thread 实时汇报 |
| announce 丢失 | 主会话不知道完成了 | 不依赖 announce，靠状态文件 |
| Discord ID 精度 | 丢精度 | 用 channel: 前缀 |
| 刷屏 | 失败重试每次都发消息 | 失败只汇报一次 |

## 核心原理

```
永动机 = Ralph Wiggum 循环 + watchdog 续命 + 自动规划

while 用户没喊停:
    if IMPLEMENTATION_PLAN.md 有未完成任务:
        loop.sh build N  # Codex/Claude 写代码
    else:
        批判性审查代码 → 找新优化点 → 更新 IMPLEMENTATION_PLAN.md
    
    if 子任务超时/失败:
        watchdog 5分钟内自动续命，从断点继续
```

## 使用方式

### 启动永动机

用户说"永动机跑起来"或"持续开发"时，按以下步骤执行：

#### 步骤 1：初始化项目（如果还没有 Ralph Wiggum 文件）

```bash
cd /path/to/project
```

检查是否存在 `IMPLEMENTATION_PLAN.md`、`PROMPT_build.md`、`PROMPT_plan.md`、`loop.sh`。
不存在则从模板复制（同 Ralph Wiggum skill）。

#### 步骤 2：确定编码引擎

按优先级检测可用的编码 CLI：

1. `codex --version` → 用 Codex CLI（`codex exec --full-auto`）
2. `claude --version` → 用 Claude Code CLI（`claude -p --dangerously-skip-permissions`）
3. 都没有 → 手动模式（子任务直接用 read/write/edit/exec）

更新 `loop.sh` 使用检测到的引擎。

#### 步骤 3：创建 Discord thread（如果在 Discord 频道）

```json
{
  "action": "thread-create",
  "channel": "discord",
  "to": "<频道ID>",
  "threadName": "🔧 <项目名> 永动机开发"
}
```

记住 thread ID，后续汇报用 `channel:<threadID>` 前缀（避免 ID 精度丢失）。

#### 步骤 4：创建 watchdog cron

```bash
openclaw cron add \
  --name "<项目名>-perpetual-watchdog" \
  --cron "*/5 * * * *" \
  --tz "Asia/Shanghai" \
  --session "isolated" \
  --no-deliver \
  --model "opus" \
  --timeout-seconds 300 \
  --message "<watchdog 指令>"
```

watchdog 指令模板：

```
你是 <项目名> 永动机的 watchdog。

检查步骤：
1. exec: cd <项目目录> && git log --oneline -3 && echo '---' && grep -c '\- \[ \]' IMPLEMENTATION_PLAN.md
2. sessions_list status=active 检查有没有活跃子任务

判断：
A) 有活跃子任务 → 不干预
B) 没有活跃子任务 → spawn 新子任务继续

spawn 模板：
sessions_spawn model=opus task=继续 <项目名> 开发。工作目录 <项目目录>。Discord thread to=channel:<threadID>。读 IMPLEMENTATION_PLAN.md 从断点继续。如果全部完成就批判性审查代码找新优化点并更新计划。用 loop.sh 或手动迭代实现。go build 验证。git commit。每完成一个任务往 thread 汇报。写大文件用 write+edit。失败2次换方法。
```

#### 步骤 5：spawn 第一个子任务

```json
{
  "model": "opus",
  "task": "继续 <项目名> 开发。工作目录 <项目目录>。Discord thread to=channel:<threadID>。..."
}
```

#### 步骤 6：通知用户

```
永动机已启动：
- 编码引擎：Codex CLI / Claude Code / 手动
- watchdog：每 5 分钟检查
- 进度：thread 里看
- 停止：跟我说"停"
```

### 停止永动机

用户说"停"或"可以了"时：

1. `subagents kill` 所有活跃子任务
2. `openclaw cron disable <watchdog-id>`
3. 汇报最终进度

### 子任务 spawn 模板

所有 spawn 的子任务必须包含以下约束：

```
## 约束
- Discord thread 汇报 to 必须用 "channel:<threadID>" 前缀
- 绝不允许连续两个 exec 中间没有 message 汇报
- 失败只汇报一次，不重复发同样的消息
- 同一操作失败 2 次换方法，不死循环重试
- 写大文件用 write + 多次 edit，不一次性写超大内容
- commit 消息用中文
```

### 编码引擎 fallback 策略

子任务内部的执行顺序：

1. 尝试 `./loop.sh build N`（调 Codex/Claude CLI）
2. 如果 CLI 认证失败或不可用 → 切换手动模式
3. 手动模式：read/write/edit/exec 直接实现 → go build 验证 → git commit

### 状态文件约定

永动机不依赖 announce 通知，靠以下文件判断进度：

- `IMPLEMENTATION_PLAN.md` — 任务完成状态（`[x]` vs `[ ]`）
- `git log` — 最近的 commit 时间和内容
- 子任务列表 — `sessions_list` 或 `subagents list`

### 进度汇报格式

子任务往 thread 发的消息格式：

```
⏳ 正在: <任务描述>
✅ 完成: <任务描述> | 改了: <文件列表>
❌ 失败: <错误描述>
📊 本轮总结: N 个任务完成，M 次 commit
```

## 关键规则

1. **不依赖 announce** — 子任务完成通知可能丢失，watchdog 兜底
2. **Discord ID 用 channel: 前缀** — 避免 JSON 数字精度丢失
3. **失败不刷屏** — 同一错误只汇报一次
4. **超时不丢进度** — IMPLEMENTATION_PLAN.md 是持久化状态，断点续传
5. **编码引擎自动选择** — 优先 Codex（省 Anthropic 额度），fallback Claude Code，最后手动
6. **watchdog 5 分钟间隔** — 比 15 分钟更快续命
7. **全部完成自动规划** — 不停下来，自动找新优化点

## 与其他 Skill 的关系

- 基于 `ralph-wiggum` skill 增强
- 可配合 `planning-with-files` skill 做初始规划
- 可配合 `coding` skill 的工程规范
