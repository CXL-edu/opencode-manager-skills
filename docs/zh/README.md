# OpenCode Manager

[English](../../README.md) | 中文文档

---

**适用于 AI 编程代理（AI Coding Agents）的通用 OpenCode 管理工具包。**

它通过统一的 CLI 接口，让 Cursor、Claude Code、Codex 等 AI 代理能够轻松管理本地 OpenCode 实例。

## ✨ 核心功能

- 🚀 **后台服务管理**：在后台静默启动 OpenCode 服务器，不阻塞当前终端会话。
- 🔍 **智能监控**：自动发现、列出并监控所有运行中的 OpenCode 进程及端口状态。
- 📡 **通用指令执行**：通过 CLI 或 REST API 发送任务，支持任何能执行 Shell 的 Agent。
- 📊 **实时数据流**：支持 SSE (Server-Sent Events) 事件流，实时捕获执行日志和结果。
- 🧹 **进程清理**：一键清理僵尸进程，保持环境整洁。

---

## 📥 安装指南

我们提供了多种安装方式，推荐使用远程一键安装。

### ⚡️ 远程一键安装（推荐）

无需下载仓库，直接在终端执行即可：

```bash
# 中文版（自动配置中文适配器）
curl -fsSL https://raw.githubusercontent.com/CXL-edu/opencode-manager-skills/main/install.sh | bash -s -- --lang zh

# 英文版
curl -fsSL https://raw.githubusercontent.com/CXL-edu/opencode-manager-skills/main/install.sh | bash -s -- --lang en
```

> **该脚本会自动执行：**
> 1. 下载并安装 `opencode-manager` CLI 工具。
> 2. 根据你的环境（如 Cursor），自动生成对应的 Agent 适配器文件。

### 📦 快速安装（本地脚本）

如果你已经克隆了本仓库，可以使用本地脚本安装：

```bash
# 交互式安装（推荐）
bash install.sh

# 静默安装（中文）
bash install.sh --lang zh
```

### 🛠 手动安装（Git Clone）

如果你需要完全的控制权，可以手动配置：

1. **克隆仓库**：
   ```bash
   git clone https://github.com/CXL-edu/opencode-manager-skills.git
   cd opencode-manager-skills
   ```

2. **配置通用 CLI**：
   将 `opencode-manager` 脚本加入到你的系统 `PATH` 中，或者直接通过路径调用。

3. **配置 Agent 适配器**（以 Cursor 为例）：
   - 将 `zh/opencode-manager.md` 复制到项目的 `.cursor/skills/` 目录。
   - 在 Cursor 对话中即可使用：“用 opencode-manager 启动服务...”。

---

## 🤖 使用指南

本工具包设计为 **Agent Agnostic**（与代理无关）。只要你的 AI 编程助手（Agent）具备**执行 Shell 命令**的能力，它就能直接使用此工具。

安装完成后，你无需记忆复杂的 CLI 参数，只需用**自然语言**下达指令，Agent 会自动将其转换为对应的 `opencode-manager` 命令。

**交互示例：**

- “帮我启动一个后台 OpenCode 服务，端口 4096”
- “检查一下现在有没有正在运行的 OpenCode 实例”
- “清理掉所有不再使用的 OpenCode 进程”
- “在后台运行启动 opencode 并运行测试其使用 context7 mcp 的效果，返回监听结果”
- “运行 opencode 记录端口，后续通过这个服务发送任务”
- “列出当前所有正在运行的 OpenCode 实例”

Agent 会自动解析你的意图，并调用底层的 `opencode-manager` 工具来完成任务。

---

## 📂 目录结构

```text
opencode-manager/
├── README.md                 # 英文说明（项目主页）
├── docs/
│   └── zh/
│       └── README.md         # 中文说明（本文档）
├── install.sh                # 统一安装脚本
├── zh/
│   └── opencode-manager.md   # 中文 Agent 适配规则 / Prompt
└── en/
    └── opencode-manager.md   # 英文 Agent 适配规则 / Prompt
```

## 📄 License

MIT

## 🔖 版本信息

v2.0 | 2026-01-28 | Compatible with OpenCode 1.1.39+
