---
name: perpetual-dev
description: 永动机自主开发模式（并行编排版）。给定项目目录和目标，持续循环：审查→规划→并行编码→merge→测试→推送，直到用户喊停。自动管理 watchdog 续命、git worktree 并行、编码引擎选择、进度汇报、断点恢复。触发词：永动机、持续开发、perpetual、自主循环开发、跑一晚上。
homepage: https://github.com/laolin5564/perpetual-dev
user-invocable: true
metadata:
  version: "2.0.0"
  openclaw:
    os: ["darwin", "linux"]
---

# Perpetual Dev v2 — 并行编排永动机

基于 Ralph Wiggum 的增强版。v2 新增并行编排能力，多个 Codex 同时写代码。

## 核心原理

```
while 用户没喊停:
    Orchestrator (Opus):
        1. 读 IMPLEMENTATION_PLAN.md
        2. 如果全部完成 → 审查代码 → 规划新任务
        3. 分析任务依赖关系
        4. 把无依赖的任务分组
        5. 每组创建 git worktree + 独立分支
        6. 并行启动 Codex（每个 worktree 一个）
        7. 等待全部完成
        8. 逐个 merge 回 main
        9. 验证（go build + 前端 build）
        10. 清理 worktree
        11. push + 汇报
        12. 回到步骤 1
    
    if Orchestrator 超时/失败:
        watchdog 5分钟内自动续命
```

## 架构

```
┌─────────────────────────────────────────┐
│       Orchestrator (Opus, 1h timeout)    │
│                                         │
│  读计划 → 分析依赖 → 分组               │
│       ↓ 并行 spawn                      │
│  ┌────┼────┬────────┐                   │
│  ▼    ▼    ▼        ▼                   │
│ Codex Codex Codex  Codex                │
│ w1    w2    w3     w4                   │
│ 分支1  分支2  分支3   分支4               │
│  │    │    │        │                   │
│  └────┴────┴────────┘                   │
│       ↓ merge 回 main                   │
│  验证 → 清理 → push → 汇报              │
└──────────┬──────────────────────────────┘
           │
    ┌──────▼──────┐
    │  Watchdog    │
    │ (每 5 分钟)   │
    │ 挂了自动续命  │
    └─────────────┘
```

## 使用方式

### 启动永动机

用户说"永动机跑起来"时，按以下步骤执行：

#### 步骤 1：检测编码引擎

```bash
which codex && echo "ENGINE=codex" || (which claude && echo "ENGINE=claude")
```

#### 步骤 2：创建 Discord thread

```json
{
  "action": "thread-create",
  "channel": "discord",
  "to": "<频道ID>",
  "threadName": "🔧 <项目名> 永动机开发"
}
```

⚠️ 后续汇报用 `channel:<threadID>` 前缀。

#### 步骤 3：创建 watchdog cron

```bash
openclaw cron add \
  --name "<项目名>-perpetual-watchdog" \
  --cron "*/5 * * * *" \
  --tz "Asia/Shanghai" \
  --session "isolated" \
  --no-deliver \
  --model "opus" \
  --timeout-seconds 300 \
  --message "<watchdog 指令，见下方模板>"
```

#### 步骤 4：spawn Orchestrator

```json
{
  "model": "opus",
  "runTimeoutSeconds": 3600,
  "task": "并行编排任务描述..."
}
```

⚠️ `runTimeoutSeconds: 3600` 必须设，默认超时太短。

### 停止永动机

1. `subagents kill` 所有活跃子任务
2. `openclaw cron disable <watchdog-id>`
3. 清理残留 worktree：`git worktree list` → `git worktree remove`

## Orchestrator 执行流程

每轮 Orchestrator 做以下事情：

### 1. 规划

```
读 IMPLEMENTATION_PLAN.md
如果有未完成任务 → 直接进入步骤 2
如果全部完成 → 批判性审查代码 → 找新优化点 → 更新 PLAN
```

规划时回答三个问题：
- 解决什么真实问题？
- 不做会怎样？
- 怎么验证有效？

### 2. 依赖分析

把任务分成可并行的组：
- 改不同文件的任务 → 可并行
- 有依赖关系的任务 → 串行（放下一批）

### 3. 创建 worktree

```bash
cd /path/to/project
git worktree add ../project-w1 -b task-1-branch
git worktree add ../project-w2 -b task-2-branch
git worktree add ../project-w3 -b task-3-branch
```

### 4. 并行启动 Codex

```bash
cd ../project-w1 && echo "<任务1描述>" | codex exec --full-auto &
cd ../project-w2 && echo "<任务2描述>" | codex exec --full-auto &
cd ../project-w3 && echo "<任务3描述>" | codex exec --full-auto &
wait
```

每个 Codex 的 prompt 必须包含：
- 具体要改什么文件
- 改完后的验证命令（go build / npm run build）
- git commit 命令和消息

### 5. Merge 回 main

```bash
cd /path/to/project
git checkout main
git merge task-1-branch --no-edit
git merge task-2-branch --no-edit
git merge task-3-branch --no-edit
```

如果有冲突，手动解决（Opus 处理）。

### 6. 验证

```bash
go build -o /dev/null ./cmd/server/
cd frontend && npm run build && cd ..
```

### 7. 清理

```bash
git worktree remove ../project-w1
git worktree remove ../project-w2
git worktree remove ../project-w3
git branch -d task-1-branch task-2-branch task-3-branch
```

### 8. Push + 汇报

```bash
git push origin main
```

往 thread 发汇报。

## Watchdog 模板

```
你是 <项目名> 永动机的 watchdog（并行编排模式）。

检查步骤：
1. exec: cd <项目目录> && git log --oneline -3 && echo '---' && grep -c '\- \[ \]' IMPLEMENTATION_PLAN.md
2. sessions_list status=active 检查有没有活跃子任务

判断：
A) 有活跃子任务 → 不干预
B) 没有活跃子任务 → spawn 编排任务

spawn: sessions_spawn model=opus runTimeoutSeconds=3600 task=<并行编排任务描述>
```

## 关键规则

1. **runTimeoutSeconds: 3600** — 必须设，默认超时太短
2. **Discord ID 用 channel: 前缀** — 避免精度丢失
3. **不依赖 announce** — watchdog 兜底
4. **失败不刷屏** — 同一错误只汇报一次
5. **编码用 Codex** — Opus 只做编排，不写代码
6. **git worktree 隔离** — 并行 Codex 不能共享工作目录
7. **每轮汇报** — 并行开始时、完成时、merge 后各汇报一次
8. **价值评估** — 连续 3 轮找不到新任务则降频

## 踩坑经验

1. announce 回调不可靠 → 靠 watchdog + 状态文件
2. Discord ID 在 JSON 中丢精度 → `channel:` 前缀
3. Codex ACP session 太短 → 用 Codex CLI
4. 失败重试导致刷屏 → 失败只报一次
5. Gateway 重启导致孤儿 session → watchdog 自动处理
6. 全部完成不等于停止 → 自动审查找新任务
7. 模型选择 → Opus 编排，Codex 编码
8. 默认超时太短 → 必须设 runTimeoutSeconds
9. 串行效率低 → 并行 worktree + 多 Codex
10. loop.sh build N 期间无法汇报 → 每轮 build 1 或并行模式

## Credits

- Based on [Ralph Wiggum](https://ghuntley.com/ralph/) by [@GeoffreyHuntley](https://github.com/ghuntley)
- Built for [OpenClaw](https://github.com/openclaw/openclaw)
