---
name: opencode-manager
description: Manage OpenCode background servers, monitoring, task execution, and cleanup. Use when users mention OpenCode, opencode serve, background instances, ports, logs, or OpenCode APIs.
license: MIT
compatibility: Requires opencode CLI and shell access; optional curl, jq, lsof, ss.
---
# OpenCode Manager

Use this skill to operate OpenCode in long-running server mode and interact with it via CLI or HTTP APIs.

## When to use
- The user wants to start or manage OpenCode background servers.
- The user asks to check running OpenCode instances or ports.
- The user needs to send tasks to OpenCode and capture structured output.
- The user requests monitoring or cleanup of OpenCode processes.

## Core workflow
1. Locate the `opencode` binary (or use the default path).
2. Verify ports and start one or more `opencode serve` instances.
3. Validate health and access the OpenAPI docs.
4. Execute tasks via `opencode run` or REST APIs.
5. Monitor logs or SSE events, then clean up when done.

## References
- English reference: `references/REFERENCE.en.md`
- 中文参考: `references/REFERENCE.zh.md`
