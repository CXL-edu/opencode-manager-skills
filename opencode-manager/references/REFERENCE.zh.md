# opencode-manager

管理 OpenCode 后台实例的启动、监控、命令执行和结果捕获。当用户需要在后台运行 OpenCode 服务器、执行命令、监听输出时使用此工作流。

---

## 核心概念

OpenCode 支持作为长期运行的服务器模式（daemon），通过 `opencode serve` 启动。与一次性执行不同，服务器会持续监听端口，接受多个连接，并将所有活动记录到日志文件中。

**架构说明：**
```
┌─────────────────────────────────────────────────────────┐
│  opencode serve (后台进程)                              │
│  ├─ 监听端口: 4096 (默认)                              │
│  ├─ 加载配置: opencode.json                            │
│  ├─ 暴露 OpenAPI 3.1 接口                              │
│  └─ 支持多客户端同时连接                               │
└─────────────────────────────────────────────────────────┘
         ↓                    ↓                    ↓
    [Web UI]           [CLI Attach]          [API/SDK]
  http://localhost      opencode attach     curl/fetch
     :4096              :4096
```

**关键优势：**
- ✅ 持久化运行，不依赖终端会话
- ✅ 所有交互自动通过 API 可查询
- ✅ 支持多个实例同时运行（不同端口）
- ✅ 可通过 Web UI、TUI、API 或 SDK 交互
- ✅ SSE 实时事件流监控
- ✅ OpenAPI 3.1 规范，支持自动生成客户端

---

## 工作流程

### 场景 1: 启动后台 OpenCode 实例

**目标：** 启动一个或多个 OpenCode 服务器在后台运行

**步骤：**

1. **定位 opencode 二进制文件**
```bash
# 查找 opencode 路径
OPENCODE_PATH=$(which opencode || echo "/root/.opencode/bin/opencode")
echo "OpenCode 路径: $OPENCODE_PATH"
```

2. **检查端口占用**
```bash
# 检查端口 4096 是否被占用
ss -tlnp | grep 4096 || echo "端口 4096 可用"

# 或使用 lsof
lsof -i :4096 || echo "端口 4096 可用"
```

3. **启动服务器（单个实例）**
```bash
# 完整启动命令（注意：--print-logs 和 --log-level 是全局 flag，需放在 serve 之前）
$OPENCODE_PATH --print-logs --log-level INFO serve \
  --port 4096 \
  --hostname 127.0.0.1 \
  > /tmp/opencode_server_4096.log 2>&1 &

# 记录 PID
echo $! > /tmp/opencode_server_4096.pid
echo "OpenCode 服务器已启动 (PID: $(cat /tmp/opencode_server_4096.pid))"
```

4. **启动多个实例（自动分配端口）**
```bash
# 自动查找可用端口的函数
find_available_port() {
  local port=${1:-4096}
  while ss -tlnp | grep -q ":$port "; do
    ((port++))
  done
  echo $port
}

# 启动 3 个实例
for i in 1 2 3; do
  PORT=$(find_available_port $((4095 + i)))
  $OPENCODE_PATH --print-logs --log-level INFO serve \
    --port $PORT \
    > /tmp/opencode_server_$PORT.log 2>&1 &
  echo $! > /tmp/opencode_server_$PORT.pid
  echo "实例 $i: 端口 $PORT, PID $(cat /tmp/opencode_server_$PORT.pid)"
done
```

5. **验证启动状态**
```bash
# 检查进程
ps aux | grep "opencode.*serve" | grep -v grep

# 检查端口监听
ss -tlnp | grep -E "4096|4097|4098"

# 检查健康状态（通过 API）
curl -s http://127.0.0.1:4096/global/health | jq .
# 预期输出: { "healthy": true, "version": "x.x.x" }

# 查看 OpenAPI 文档
echo "OpenAPI 文档: http://127.0.0.1:4096/doc"
```

**输出示例：**
```
实例 1: 端口 4096, PID 53725, 日志: /tmp/opencode_server_4096.log
实例 2: 端口 4097, PID 62094, 日志: /tmp/opencode_server_4097.log
实例 3: 端口 4098, PID 62218, 日志: /tmp/opencode_server_4098.log
```

---

### 场景 2: 查找运行中的实例

**目标：** 找到所有正在运行的 OpenCode 服务器及其信息

**方法：**

1. **查找所有实例（基础）**
```bash
# 获取所有 opencode serve 进程
ps aux | grep "opencode.*serve" | grep -v grep | awk '{
  pid = $2
  for(i=1;i<=NF;i++) {
    if($i == "--port") {
      port = $(i+1)
      break
    }
  }
  printf "PID: %s, 端口: %s\n", pid, port
}'
```

2. **通过 API 验证实例状态**
```bash
# 检查每个已知端口的健康状态
for port in 4096 4097 4098; do
  HEALTH=$(curl -s --connect-timeout 2 http://127.0.0.1:$port/global/health 2>/dev/null)
  if [ -n "$HEALTH" ]; then
    VERSION=$(echo "$HEALTH" | jq -r '.version // "unknown"')
    echo "端口 $port: 运行中 (版本 $VERSION)"
  else
    echo "端口 $port: 未运行"
  fi
done
```

3. **生成详细实例报告**
```bash
echo "═══════════════════════════════════════════════════════"
echo "  OpenCode 实例状态报告"
echo "═══════════════════════════════════════════════════════"

# 进程信息
echo ""
echo "🔵 运行中的进程:"
ps aux | grep "opencode.*serve" | grep -v grep | while read line; do
  PID=$(echo "$line" | awk '{print $2}')
  PORT=$(echo "$line" | grep -oP '(?<=--port )\d+')
  echo "  PID $PID: 端口 $PORT"
  
  # 检查日志文件重定向
  LOG_FILE=$(ls -l /proc/$PID/fd/1 2>/dev/null | awk '{print $NF}')
  if [ -n "$LOG_FILE" ]; then
    echo "    日志: $LOG_FILE"
  fi
done

# 日志文件
echo ""
echo "📁 日志文件:"
ls -lh /tmp/opencode_server*.log 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}' || echo "  无日志文件"

# 端口监听
echo ""
echo "🌐 端口监听:"
ss -tlnp | grep opencode | awk '{print "  " $4}' || echo "  无监听端口"

echo ""
echo "═══════════════════════════════════════════════════════"
```

---

### 场景 3: 向实例发送命令并捕获结果

**目标：** 在后台运行的 OpenCode 实例中执行命令并获取输出

**方法一：使用 `opencode run --attach` 命令**

```bash
# 发送命令并获取 JSONL 格式输出
# 注意：--format json 输出的是 JSONL 格式（每行一个 JSON 对象）
$OPENCODE_PATH run \
  --attach http://127.0.0.1:4096 \
  --format json \
  "列出当前目录的文件" 2>&1
```

**JSONL 输出事件类型：**
```jsonl
{"type":"step_start","timestamp":1769605898320,"sessionID":"ses_xxx",...}
{"type":"tool_use","timestamp":1769605899312,"tool":"bash","state":{...}}
{"type":"text","text":"文件列表:\n- README.md\n- backend/\n..."}
```

| 事件类型 | 说明 |
|---------|------|
| `step_start` | 处理步骤开始，包含 sessionID 和 timestamp |
| `tool_use` | 工具调用完成，包含工具名、输入输出、状态和耗时 |
| `text` | 模型文本输出，包含实际内容和时间戳 |

**方法二：使用 `opencode attach` 进入交互模式**

```bash
# 附加到运行中的服务器（进入 TUI 模式）
$OPENCODE_PATH attach http://127.0.0.1:4096

# 可指定工作目录和会话
$OPENCODE_PATH attach http://127.0.0.1:4096 --dir /path/to/project --session ses_xxx
```

**方法三：通过 REST API 直接交互**

```bash
# 1. 获取所有会话列表
curl -s http://127.0.0.1:4096/session | jq .

# 2. 创建新会话
SESSION=$(curl -s -X POST http://127.0.0.1:4096/session \
  -H "Content-Type: application/json" \
  -d '{"title": "API 测试会话"}')
SESSION_ID=$(echo "$SESSION" | jq -r '.id')
echo "新会话 ID: $SESSION_ID"

# 3. 发送消息（同步等待响应）
curl -s -X POST "http://127.0.0.1:4096/session/$SESSION_ID/message" \
  -H "Content-Type: application/json" \
  -d '{
    "parts": [{"type": "text", "text": "列出当前目录"}]
  }' | jq .

# 4. 发送消息（异步，不等待）
curl -s -X POST "http://127.0.0.1:4096/session/$SESSION_ID/prompt_async" \
  -H "Content-Type: application/json" \
  -d '{
    "parts": [{"type": "text", "text": "分析代码结构"}]
  }'

# 5. 获取会话消息历史
curl -s "http://127.0.0.1:4096/session/$SESSION_ID/message" | jq .

# 6. 获取会话 Todo 列表
curl -s "http://127.0.0.1:4096/session/$SESSION_ID/todo" | jq .

# 7. 获取会话状态
curl -s http://127.0.0.1:4096/session/status | jq .
```

**向不同实例发送任务：**
```bash
# 并行向多个实例发送任务
$OPENCODE_PATH run --attach http://127.0.0.1:4096 "分析 backend/" > /tmp/task1.log 2>&1 &
$OPENCODE_PATH run --attach http://127.0.0.1:4097 "分析 frontend/" > /tmp/task2.log 2>&1 &
$OPENCODE_PATH run --attach http://127.0.0.1:4098 "生成文档" > /tmp/task3.log 2>&1 &

# 等待所有任务完成
wait
echo "所有任务已完成"
```

---

### 场景 4: 持续监控实例输出

**目标：** 实时监控 OpenCode 实例的活动

**方法一：通过 SSE 事件流（推荐）**

```bash
# 使用 curl 订阅全局事件流
curl -N -s http://127.0.0.1:4096/global/event | while read -r line; do
  if [[ "$line" == data:* ]]; then
    EVENT=$(echo "$line" | sed 's/^data://')
    TYPE=$(echo "$EVENT" | jq -r '.type // "unknown"')
    echo "[$(date '+%H:%M:%S')] 事件: $TYPE"
    
    # 根据事件类型处理
    case "$TYPE" in
      "session.created")
        echo "  新会话创建"
        ;;
      "message.created")
        echo "  新消息"
        ;;
      "tool.started"|"tool.completed")
        TOOL=$(echo "$EVENT" | jq -r '.tool // "unknown"')
        echo "  工具: $TOOL"
        ;;
    esac
  fi
done
```

**方法二：通过日志文件监控**

```bash
# 实时监控单个实例日志
tail -f /tmp/opencode_server_4096.log

# 过滤关键事件
tail -f /tmp/opencode_server_4096.log | grep --line-buffered -E "session|message|tool|ERROR|WARN"

# 监控多个实例（使用 multitail）
multitail /tmp/opencode_server_4096.log /tmp/opencode_server_4097.log

# 或使用简单的并行 tail
tail -f /tmp/opencode_server_*.log | while read line; do
  if echo "$line" | grep -qE "ERROR|WARN"; then
    echo "⚠️ $line"
  elif echo "$line" | grep -qE "session|message"; then
    echo "📝 $line"
  fi
done
```

**方法三：创建监控脚本**

```bash
cat > /tmp/monitor_opencode.sh << 'SCRIPT'
#!/bin/bash

echo "═══════════════════════════════════════════════════════"
echo "  OpenCode 实时监控"
echo "═══════════════════════════════════════════════════════"

PORTS="${1:-4096}"  # 默认监控 4096

for PORT in $PORTS; do
  echo "监控端口: $PORT"
  
  # 后台启动 SSE 监控
  (curl -N -s "http://127.0.0.1:$PORT/event" 2>/dev/null | while read -r line; do
    if [[ "$line" == data:* ]]; then
      TIMESTAMP=$(date '+%H:%M:%S')
      EVENT=$(echo "$line" | sed 's/^data://' | jq -c '.')
      echo "[$TIMESTAMP] 端口 $PORT: $EVENT"
    fi
  done) &
done

echo "按 Ctrl+C 停止监控"
wait
SCRIPT

chmod +x /tmp/monitor_opencode.sh
# 使用: /tmp/monitor_opencode.sh "4096 4097 4098"
```

---

### 场景 5: 停止和清理

**目标：** 停止所有 OpenCode 实例并清理临时文件

**方法：**

1. **停止特定实例**
```bash
# 通过 PID 文件停止
kill $(cat /tmp/opencode_server_4096.pid 2>/dev/null)

# 通过端口查找并停止
kill $(lsof -ti:4096)

# 通过进程名停止特定端口
pkill -f "opencode.*serve.*--port 4096"
```

2. **停止所有实例**
```bash
# 方法 1: 使用 pkill
pkill -f "opencode.*serve"

# 方法 2: 循环停止并验证
for pid in $(ps aux | grep "opencode.*serve" | grep -v grep | awk '{print $2}'); do
  echo "停止 PID: $pid"
  kill $pid
done

# 等待进程退出
sleep 2
ps aux | grep "opencode.*serve" | grep -v grep || echo "✓ 所有实例已停止"
```

3. **清理临时文件**
```bash
# 删除日志和 PID 文件
rm -f /tmp/opencode_server*.log
rm -f /tmp/opencode_server*.pid
rm -f /tmp/task*.log
rm -f /tmp/monitor_opencode.sh

# 验证清理结果
ls /tmp/opencode_server* 2>&1 | grep -q "No such file" && echo "✓ 临时文件已清理"
```

4. **完整清理脚本**
```bash
#!/bin/bash
echo "═══════════════════════════════════════════════════════"
echo "  OpenCode 完整清理"
echo "═══════════════════════════════════════════════════════"

# 停止所有进程
echo ""
echo "🛑 停止进程..."
pkill -f "opencode.*serve" 2>/dev/null
sleep 2

# 验证
RUNNING=$(ps aux | grep "opencode.*serve" | grep -v grep | wc -l)
echo "  运行中的实例: $RUNNING"

# 清理文件
echo ""
echo "🗑️ 清理文件..."
rm -f /tmp/opencode_server*.log /tmp/opencode_server*.pid /tmp/task*.log
echo "  ✓ 日志文件已删除"
echo "  ✓ PID 文件已删除"

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  清理完成"
echo "═══════════════════════════════════════════════════════"
```

---

## 高级用法

### 带认证的服务器

```bash
# 启用 HTTP Basic Auth
OPENCODE_SERVER_PASSWORD=your-secure-password \
OPENCODE_SERVER_USERNAME=admin \
$OPENCODE_PATH serve --port 4096

# 使用认证访问 API
curl -u admin:your-secure-password http://127.0.0.1:4096/global/health
```

### 允许跨域访问

```bash
# 允许特定来源的跨域请求
$OPENCODE_PATH serve \
  --port 4096 \
  --hostname 0.0.0.0 \
  --cors http://localhost:3000 \
  --cors https://app.example.com
```

### 使用 nohup 确保持久运行

```bash
# 使用 nohup 防止终端关闭导致进程退出
nohup $OPENCODE_PATH --print-logs --log-level INFO serve \
  --port 4096 \
  > /tmp/opencode_server_4096.log 2>&1 &

# 记录 PID
echo $! > /tmp/opencode_server_4096.pid
disown
```

### 会话追踪

```bash
# 追踪特定会话的所有活动
SESSION_ID="ses_3fb44f4c5ffeG7A3ZxWj0C4nVX"

# 通过 API 获取会话详情
curl -s "http://127.0.0.1:4096/session/$SESSION_ID" | jq .

# 获取会话消息
curl -s "http://127.0.0.1:4096/session/$SESSION_ID/message" | jq '.[] | {role: .info.role, content: .parts[0].text}'

# 获取会话 diff（代码变更）
curl -s "http://127.0.0.1:4096/session/$SESSION_ID/diff" | jq .
```

### 批量任务执行

```bash
# 定义任务列表
TASKS=(
  "4096:分析 backend/app/main.py"
  "4097:分析 frontend/src/App.tsx"
  "4098:生成 API 文档"
)

# 并行执行
for task in "${TASKS[@]}"; do
  PORT=$(echo "$task" | cut -d: -f1)
  PROMPT=$(echo "$task" | cut -d: -f2-)
  echo "提交任务到端口 $PORT: $PROMPT"
  $OPENCODE_PATH run --attach "http://127.0.0.1:$PORT" "$PROMPT" \
    > "/tmp/task_${PORT}.log" 2>&1 &
done

# 等待完成
wait
echo "所有任务已完成"

# 查看结果
for port in 4096 4097 4098; do
  echo "=== 端口 $port 结果 ==="
  cat "/tmp/task_${port}.log" | jq -r 'select(.type=="text") | .text' 2>/dev/null | head -20
done
```

---

## API 快速参考

### 核心端点

| 分类 | 方法 | 端点 | 说明 |
|------|------|------|------|
| 文档 | GET | `/doc` | OpenAPI 3.1 规范 |
| 健康 | GET | `/global/health` | 服务器健康状态 |
| 事件 | GET | `/global/event` | SSE 全局事件流 |
| 事件 | GET | `/event` | SSE 事件流（所有事件） |

### 会话管理

| 方法 | 端点 | 说明 |
|------|------|------|
| GET | `/session` | 列出所有会话 |
| POST | `/session` | 创建新会话 |
| GET | `/session/:id` | 获取会话详情 |
| DELETE | `/session/:id` | 删除会话 |
| GET | `/session/:id/message` | 获取会话消息 |
| POST | `/session/:id/message` | 发送消息（同步） |
| POST | `/session/:id/prompt_async` | 发送消息（异步） |
| GET | `/session/:id/todo` | 获取会话 Todo |
| POST | `/session/:id/abort` | 中止运行中的会话 |
| GET | `/session/:id/diff` | 获取会话代码变更 |

### 文件与搜索

| 方法 | 端点 | 说明 |
|------|------|------|
| GET | `/find?pattern=xxx` | 搜索文件内容 |
| GET | `/find/file?query=xxx` | 按名称查找文件 |
| GET | `/file?path=xxx` | 列出目录内容 |
| GET | `/file/content?path=xxx` | 读取文件内容 |

### 基础设施

| 方法 | 端点 | 说明 |
|------|------|------|
| GET | `/mcp` | MCP 服务器状态 |
| POST | `/mcp` | 动态添加 MCP 服务器 |
| GET | `/lsp` | LSP 服务器状态 |
| GET | `/config` | 获取配置 |

---

## 故障排查

### 问题 1: 端口已被占用
```bash
# 检查端口占用
ss -tlnp | grep 4096
lsof -i :4096

# 解决方案：停止占用进程或使用其他端口
kill $(lsof -ti:4096)
# 或
$OPENCODE_PATH serve --port 4097
```

### 问题 2: 服务器启动后立即退出
```bash
# 查看日志获取错误信息
cat /tmp/opencode_server_4096.log | tail -50

# 常见原因：
# - 配置文件语法错误
# - MCP 服务器启动失败
# - 权限问题

# 调试模式启动
$OPENCODE_PATH --print-logs --log-level DEBUG serve --port 4096
```

### 问题 3: API 请求失败
```bash
# 检查服务器是否运行
curl -v http://127.0.0.1:4096/global/health

# 如果启用了认证
curl -u opencode:password http://127.0.0.1:4096/global/health

# 检查防火墙
sudo iptables -L -n | grep 4096
```

---

## 最佳实践

1. **进程管理**
   - 保存 PID 到文件便于管理
   - 考虑使用 systemd 或 supervisor 管理长期服务
   - 定期检查进程健康状态

2. **日志管理**
   - 使用 `--log-level WARN` 减少日志量
   - 考虑日志轮转（logrotate）
   - 定期清理旧日志

3. **端口规划**
   | 端口范围 | 用途 |
   |---------|------|
   | 4096 | 主开发服务器 |
   | 4097-4099 | 并行任务实例 |
   | 4100+ | 测试/实验实例 |

4. **安全考虑**
   - 生产环境必须设置 `OPENCODE_SERVER_PASSWORD`
   - 使用 `--hostname 127.0.0.1` 限制本地访问
   - 远程访问时考虑反向代理和 HTTPS

5. **资源监控**
   ```bash
   # 监控内存使用
   ps aux | grep "opencode.*serve" | awk '{print "PID: "$2", 内存: "$6/1024" MB"}'
   
   # 监控连接数
   ss -tnp | grep 4096 | wc -l
   ```

---

## 快速命令速查

```bash
# === 启动 ===
# 单实例启动
opencode --print-logs serve --port 4096 > /tmp/opencode_4096.log 2>&1 &

# === 查找 ===
# 列出所有实例
ps aux | grep "opencode.*serve" | grep -v grep

# 检查健康状态
curl -s http://127.0.0.1:4096/global/health | jq .

# === 交互 ===
# 发送命令
opencode run --attach http://127.0.0.1:4096 "你的任务"

# 附加 TUI
opencode attach http://127.0.0.1:4096

# === 监控 ===
# 实时日志
tail -f /tmp/opencode_4096.log

# SSE 事件流
curl -N http://127.0.0.1:4096/event

# === 清理 ===
# 停止所有
pkill -f "opencode.*serve"

# 删除日志
rm -f /tmp/opencode*.log /tmp/opencode*.pid
```

---

**版本:** v2.0  
**最后更新:** 2026-01-28  
**兼容性:** OpenCode 1.1.39+  
**参考文档:** https://opencode.ai/docs/server
