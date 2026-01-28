# OpenCode Manager

[![OpenCode](https://img.shields.io/badge/OpenCode-1.1.39+-blue?logo=data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjQiIGhlaWdodD0iMjQiIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48cGF0aCBkPSJNMTIgMkM2LjQ4IDIgMiA2LjQ4IDIgMTJzNC40OCAxMCAxMCAxMCAxMC00LjQ4IDEwLTEwUzE3LjUyIDIgMTIgMnptMCAxOGMtNC40MSAwLTgtMy41OS04LThzMy41OS04IDgtOCA4IDMuNTkgOCA4LTMuNTkgOC04IDh6IiBmaWxsPSJ3aGl0ZSIvPjxwYXRoIGQ9Ik0xMiA2djZsNC41IDIuNyIgc3Ryb2tlPSJ3aGl0ZSIgc3Ryb2tlLXdpZHRoPSIyIiBzdHJva2UtbGluZWNhcD0icm91bmQiLz48L3N2Zz4=)](https://github.com/anomalyco/opencode)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![GitHub](https://img.shields.io/badge/GitHub-CXL--edu%2Fopencode--manager--skills-181717?logo=github)](https://github.com/CXL-edu/opencode-manager-skills)

English | [中文文档](docs/zh/README.md)

---

**A universal [OpenCode](https://opencode.ai) management toolkit for AI Coding Agents.**

It provides a unified CLI interface that allows AI agents like Cursor, Claude Code, and Codex cli to easily manage local OpenCode instances.

## ✨ Core Features

- 🚀 **Background Service Management**: Start OpenCode servers silently in the background without blocking the current terminal session.
- 🔍 **Smart Monitoring**: Automatically discover, list, and monitor all running OpenCode processes and their port status.
- 📡 **Universal Command Execution**: Send tasks via CLI or REST API, supporting any Agent capable of executing Shell commands.
- 📊 **Real-time Data Streaming**: Supports SSE (Server-Sent Events) to capture execution logs and results in real-time.
- 🧹 **Process Cleanup**: One-click cleanup of zombie processes to keep your environment tidy.

---

## 📥 Installation Guide

We offer multiple installation methods, with the remote one-line install being recommended.

### ⚡️ Remote Install (Recommended)

No need to download the repository, just run this in your terminal:

```bash
# Chinese version (auto-configures Chinese adapter)
curl -fsSL https://raw.githubusercontent.com/CXL-edu/opencode-manager-skills/main/install.sh | bash -s -- --lang zh

# English version
curl -fsSL https://raw.githubusercontent.com/CXL-edu/opencode-manager-skills/main/install.sh | bash -s -- --lang en
```

> **The script will automatically:**
> 1. Download and install the `opencode-manager` CLI tool.
> 2. Auto-generate the corresponding Agent adapter files based on your environment (e.g., for Cursor).

### 📦 Quick Install (Local Script)

If you have already cloned this repository, you can use the local script:

```bash
# Interactive mode (Recommended)
bash install.sh

# Silent install (English)
bash install.sh --lang en
```

### 🛠 Manual Install (Git Clone)

If you need full control, you can configure it manually:

1. **Clone the repository**:
   ```bash
   git clone https://github.com/CXL-edu/opencode-manager-skills.git
   cd opencode-manager-skills
   ```

2. **Configure Common CLI**:
   Add the `opencode-manager` script to your system `PATH`, or call it directly via its full path.

3. **Configure Agent Adapter** (e.g., for Cursor):
   - Copy `en/opencode-manager.md` to your project's `.cursor/skills/` directory.
   - You can then use it in Cursor chat: "Use opencode-manager to start a server..."

---

## 🤖 Usage Guide

This toolkit is designed to be **Agent Agnostic**. As long as your AI coding assistant (Agent) has the ability to **execute Shell commands**, it can use this tool directly.

Once installed, you don't need to memorize complex CLI arguments. Just give instructions in **natural language**, and the Agent will automatically translate them into the corresponding `opencode-manager` commands.

**Interaction Examples:**

> "Start a background OpenCode server on port 4096"

> "Check if there are any running OpenCode instances"

> "Clean up all unused OpenCode processes"

The Agent will parse your intent and call the underlying `opencode-manager` tool to complete the task.

---

## 📂 Directory Structure

```text
opencode-manager/
├── README.md                 # English Documentation (Project Home)
├── docs/
│   └── zh/
│       └── README.md         # Chinese Documentation
├── install.sh                # Unified Installation Script
├── zh/
│   └── opencode-manager.md   # Chinese Agent Adapter / Prompt
└── en/
    └── opencode-manager.md   # English Agent Adapter / Prompt
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔖 Version

v2.0 | 2026-01-28 | Compatible with [OpenCode 1.1.39+](https://opencode.ai)

## 🔗 Links

- [OpenCode GitHub Repository](https://github.com/anomalyco/opencode)
- [OpenCode Official Website](https://opencode.ai)
- [OpenCode Documentation](https://opencode.ai/docs)
- [OpenCode Server Docs](https://opencode.ai/docs/server)
- [This Project Repository](https://github.com/CXL-edu/opencode-manager-skills)
