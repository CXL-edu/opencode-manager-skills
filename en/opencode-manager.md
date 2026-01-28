# opencode-manager

Manage OpenCode background instances: startup, monitoring, command execution, and result capture. Use this workflow when you need to:

- Run one or more OpenCode servers as long‑lived background daemons
- Attach via CLI / Web UI / API
- Execute tasks and capture structured outputs
- Monitor health and events in real time

---

## Core Concepts

OpenCode supports running as a long‑lived server (daemon) via `opencode serve`. Unlike one‑shot execution, the server:

- Listens on a port
- Accepts multiple concurrent clients
- Persists state across sessions
- Logs all activity to files
- Exposes a full OpenAPI 3.1 interface

**Architecture:**
```
┌─────────────────────────────────────────────────────────┐
│  opencode serve (background process)                    │
│  ├─ Listen port: 4096 (default)                        │
│  ├─ Load config: opencode.json                         │
│  ├─ Expose OpenAPI 3.1 interface                       │
│  └─ Support multiple simultaneous clients              │
└─────────────────────────────────────────────────────────┘
         ↓                    ↓                    ↓
    [Web UI]           [CLI Attach]          [API/SDK]
  http://localhost      opencode attach     curl/fetch
     :4096              :4096
```

**Key advantages:**
- ✅ Persistent operation, independent of terminal session
- ✅ All interactions queryable via HTTP API
- ✅ Multiple instances on different ports
- ✅ Web UI, TUI, API, or SDK interaction
- ✅ SSE real‑time event streaming
- ✅ OpenAPI 3.1 spec, easy client generation

---

## Workflows

### Scenario 1: Start Background OpenCode Instances

**Goal:** Start one or more OpenCode servers in the background.

**Steps:**

1. **Locate `opencode` binary**

```bash
# Find opencode path
OPENCODE_PATH=$(which opencode || echo "/root/.opencode/bin/opencode")
echo "OpenCode path: $OPENCODE_PATH"
```

2. **Check port availability**

```bash
# Check if port 4096 is in use
ss -tlnp | grep 4096 || echo "Port 4096 available"

# Or using lsof
lsof -i :4096 || echo "Port 4096 available"
```

3. **Start server (single instance)**

```bash
# Full start command
# IMPORTANT: --print-logs and --log-level are global flags and must come BEFORE `serve`
$OPENCODE_PATH --print-logs --log-level INFO serve \
  --port 4096 \
  --hostname 127.0.0.1 \
  > /tmp/opencode_server_4096.log 2>&1 &

# Record PID
echo $! > /tmp/opencode_server_4096.pid
echo "OpenCode server started (PID: $(cat /tmp/opencode_server_4096.pid))"
```

4. **Start multiple instances (auto‑assign ports)**

```bash
# Helper: find first available TCP port
find_available_port() {
  local port=${1:-4096}
  while ss -tlnp | grep -q ":$port "; do
    ((port++))
  done
  echo $port
}

# Start 3 instances
for i in 1 2 3; do
  PORT=$(find_available_port $((4095 + i)))
  $OPENCODE_PATH --print-logs --log-level INFO serve \
    --port $PORT \
    --hostname 127.0.0.1 \
    > /tmp/opencode_server_$PORT.log 2>&1 &
  echo $! > /tmp/opencode_server_$PORT.pid
  echo "Instance $i: Port $PORT, PID $(cat /tmp/opencode_server_$PORT.pid), Log: /tmp/opencode_server_$PORT.log"
done
```

5. **Verify startup**

```bash
# Check processes
ps aux | grep "opencode.*serve" | grep -v grep

# Check listening ports
ss -tlnp | grep -E "4096|4097|4098"

# Health check via API
curl -s http://127.0.0.1:4096/global/health | jq .
# Expected: { "healthy": true, "version": "x.x.x" }

# OpenAPI docs
echo "OpenAPI docs: http://127.0.0.1:4096/doc"
```

**Sample output:**
```
Instance 1: Port 4096, PID 53725, Log: /tmp/opencode_server_4096.log
Instance 2: Port 4097, PID 62094, Log: /tmp/opencode_server_4097.log
Instance 3: Port 4098, PID 62218, Log: /tmp/opencode_server_4098.log
```

---

### Scenario 2: Find Running Instances

**Goal:** Discover all running OpenCode servers and their details.

**Methods:**

1. **List all instances (basic)**

```bash
# List all `opencode serve` processes with ports
ps aux | grep "opencode.*serve" | grep -v grep | awk '{
  pid = $2
  for(i=1;i<=NF;i++) {
    if($i == "--port") {
      port = $(i+1)
      break
    }
  }
  printf "PID: %s, Port: %s\n", pid, port
}'
```

2. **Verify instance health via API**

```bash
for port in 4096 4097 4098; do
  HEALTH=$(curl -s --connect-timeout 2 http://127.0.0.1:$port/global/health 2>/dev/null)
  if [ -n "$HEALTH" ]; then
    VERSION=$(echo "$HEALTH" | jq -r '.version // "unknown"')
    echo "Port $port: Running (version $VERSION)"
  else
    echo "Port $port: Not running"
  fi
done
```

3. **Generate a detailed instance report**

```bash
echo "═══════════════════════════════════════════════════════"
echo "  OpenCode Instance Status Report"
echo "═══════════════════════════════════════════════════════"

echo ""
echo "🔵 Running processes:"
ps aux | grep "opencode.*serve" | grep -v grep | while read line; do
  PID=$(echo "$line" | awk '{print $2}')
  PORT=$(echo "$line" | grep -oP '(?<=--port )\d+')
  echo "  PID $PID: Port $PORT"

  # Check log redirection
  LOG_FILE=$(ls -l /proc/$PID/fd/1 2>/dev/null | awk '{print $NF}')
  if [ -n "$LOG_FILE" ]; then
    echo "    Log: $LOG_FILE"
  fi
done

echo ""
echo "📁 Log files:"
ls -lh /tmp/opencode_server*.log 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}' || echo "  No log files"

echo ""
echo "🌐 Listening ports:"
ss -tlnp | grep opencode | awk '{print "  " $4}' || echo "  No listening ports"

echo ""
echo "═══════════════════════════════════════════════════════"
```

---

### Scenario 3: Send Commands and Capture Results

**Goal:** Execute commands on a running OpenCode instance and capture structured outputs.

#### Method 1: `opencode run --attach` (recommended for scripting)

```bash
# Send a command and get JSONL output (one JSON object per line)
$OPENCODE_PATH run \
  --attach http://127.0.0.1:4096 \
  --format json \
  "List files in current directory" 2>&1
```

**JSONL event examples:**

```jsonl
{"type":"step_start","timestamp":1769605898320,"sessionID":"ses_xxx",...}
{"type":"tool_use","timestamp":1769605899312,"tool":"bash","state":{...}}
{"type":"text","text":"Files:\n- README.md\n- backend/\n..."}
```

**Event types:**

| Event Type   | Description                                                                 |
|-------------|-----------------------------------------------------------------------------|
| `step_start` | A processing step started, includes `sessionID` and `timestamp`            |
| `tool_use`   | A tool call completed, includes tool name, inputs, outputs, status, timing |
| `text`       | Model text output, includes actual content and timestamp                   |

#### Method 2: `opencode attach` (interactive TUI)

```bash
# Attach to a running server (TUI mode)
$OPENCODE_PATH attach http://127.0.0.1:4096

# Attach with working directory and specific session
$OPENCODE_PATH attach http://127.0.0.1:4096 \
  --dir /path/to/project \
  --session ses_xxx
```

#### Method 3: Direct REST API

```bash
# 1. List sessions
curl -s http://127.0.0.1:4096/session | jq .

# 2. Create a new session
SESSION=$(curl -s -X POST http://127.0.0.1:4096/session \
  -H "Content-Type: application/json" \
  -d '{"title": "API Test Session"}')
SESSION_ID=$(echo "$SESSION" | jq -r '.id')
echo "New session ID: $SESSION_ID"

# 3. Send a message (sync)
curl -s -X POST "http://127.0.0.1:4096/session/$SESSION_ID/message" \
  -H "Content-Type: application/json" \
  -d '{
    "parts": [{"type": "text", "text": "List current directory"}]
  }' | jq .

# 4. Send a message (async, fire‑and‑forget)
curl -s -X POST "http://127.0.0.1:4096/session/$SESSION_ID/prompt_async" \
  -H "Content-Type: application/json" \
  -d '{
    "parts": [{"type": "text", "text": "Analyze code structure"}]
  }'

# 5. Get session messages
curl -s "http://127.0.0.1:4096/session/$SESSION_ID/message" | jq .

# 6. Get session todos
curl -s "http://127.0.0.1:4096/session/$SESSION_ID/todo" | jq .

# 7. Get global session status
curl -s http://127.0.0.1:4096/session/status | jq .
```

**Send tasks to multiple instances in parallel:**

```bash
$OPENCODE_PATH run --attach http://127.0.0.1:4096 "Analyze backend/" > /tmp/task1.log 2>&1 &
$OPENCODE_PATH run --attach http://127.0.0.1:4097 "Analyze frontend/" > /tmp/task2.log 2>&1 &
$OPENCODE_PATH run --attach http://127.0.0.1:4098 "Generate docs"    > /tmp/task3.log 2>&1 &

wait
echo "All tasks completed"
```

---

### Scenario 4: Continuously Monitor Instance Output

**Goal:** Monitor OpenCode instance activity in real time.

#### Method 1: SSE global event stream (recommended)

```bash
curl -N -s http://127.0.0.1:4096/global/event | while read -r line; do
  if [[ "$line" == data:* ]]; then
    EVENT=$(echo "$line" | sed 's/^data://')
    TYPE=$(echo "$EVENT" | jq -r '.type // "unknown"')
    echo "[$(date '+%H:%M:%S')] Event: $TYPE"

    case "$TYPE" in
      "session.created")
        echo "  New session created"
        ;;
      "message.created")
        echo "  New message"
        ;;
      "tool.started"|"tool.completed")
        TOOL=$(echo "$EVENT" | jq -r '.tool // "unknown"')
        echo "  Tool: $TOOL"
        ;;
    esac
  fi
done
```

#### Method 2: Tail log files

```bash
# Single instance
tail -f /tmp/opencode_server_4096.log

# Filter important lines
tail -f /tmp/opencode_server_4096.log | \
  grep --line-buffered -E "session|message|tool|ERROR|WARN"

# Simple multi‑instance monitoring
tail -f /tmp/opencode_server_*.log | while read line; do
  if echo "$line" | grep -qE "ERROR|WARN"; then
    echo "⚠️  $line"
  elif echo "$line" | grep -qE "session|message"; then
    echo "📝  $line"
  fi
done
```

#### Method 3: Reusable monitoring script

```bash
cat > /tmp/monitor_opencode.sh << 'SCRIPT'
#!/bin/bash

echo "═══════════════════════════════════════════════════════"
echo "  OpenCode Live Monitor"
echo "═══════════════════════════════════════════════════════"

PORTS="${1:-4096}"  # Default: monitor 4096

for PORT in $PORTS; do
  echo "Monitoring port: $PORT"

  # Background SSE monitor
  (curl -N -s "http://127.0.0.1:$PORT/event" 2>/dev/null | \
    while read -r line; do
      if [[ "$line" == data:* ]]; then
        TIMESTAMP=$(date '+%H:%M:%S')
        EVENT=$(echo "$line" | sed 's/^data://' | jq -c '.')
        echo "[$TIMESTAMP] Port $PORT: $EVENT"
      fi
    done) &
done

echo "Press Ctrl+C to stop monitoring"
wait
SCRIPT

chmod +x /tmp/monitor_opencode.sh
# Usage: /tmp/monitor_opencode.sh "4096 4097 4098"
```

---

### Scenario 5: Stop and Cleanup

**Goal:** Gracefully stop OpenCode instances and clean temporary files.

1. **Stop a specific instance**

```bash
# Using PID file
kill $(cat /tmp/opencode_server_4096.pid 2>/dev/null)

# By port
kill $(lsof -ti:4096)

# By process name + port
pkill -f "opencode.*serve.*--port 4096"
```

2. **Stop all instances**

```bash
# Method 1: pkill
pkill -f "opencode.*serve"

# Method 2: loop and verify
for pid in $(ps aux | grep "opencode.*serve" | grep -v grep | awk '{print $2}'); do
  echo "Stopping PID: $pid"
  kill $pid
done

sleep 2
ps aux | grep "opencode.*serve" | grep -v grep || echo "✓ All instances stopped"
```

3. **Clean temp files**

```bash
rm -f /tmp/opencode_server*.log
rm -f /tmp/opencode_server*.pid
rm -f /tmp/task*.log
rm -f /tmp/monitor_opencode.sh

ls /tmp/opencode_server* 2>&1 | grep -q "No such file" && \
  echo "✓ Temp files cleaned"
```

4. **Full cleanup script**

```bash
#!/bin/bash
echo "═══════════════════════════════════════════════════════"
echo "  OpenCode Full Cleanup"
echo "═══════════════════════════════════════════════════════"

echo ""
echo "🛑 Stopping processes..."
pkill -f "opencode.*serve" 2>/dev/null
sleep 2

RUNNING=$(ps aux | grep "opencode.*serve" | grep -v grep | wc -l)
echo "  Instances still running: $RUNNING"

echo ""
echo "🗑️  Cleaning files..."
rm -f /tmp/opencode_server*.log /tmp/opencode_server*.pid /tmp/task*.log
echo "  ✓ Log files removed"
echo "  ✓ PID files removed"

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  Cleanup complete"
echo "═══════════════════════════════════════════════════════"
```

---

## Advanced Usage

### Server with Authentication

```bash
# Enable HTTP Basic Auth
OPENCODE_SERVER_PASSWORD=your-secure-password \
OPENCODE_SERVER_USERNAME=admin \
$OPENCODE_PATH serve --port 4096

# Access API with auth
curl -u admin:your-secure-password http://127.0.0.1:4096/global/health
```

### Cross‑Origin Access (CORS)

```bash
$OPENCODE_PATH serve \
  --port 4096 \
  --hostname 0.0.0.0 \
  --cors http://localhost:3000 \
  --cors https://app.example.com
```

### Keep Alive with `nohup`

```bash
# Prevent server from exiting when terminal closes
nohup $OPENCODE_PATH --print-logs --log-level INFO serve \
  --port 4096 \
  > /tmp/opencode_server_4096.log 2>&1 &

echo $! > /tmp/opencode_server_4096.pid
disown
```

### Session Tracing

```bash
# Trace all activity for a specific session
SESSION_ID="ses_3fb44f4c5ffeG7A3ZxWj0C4nVX"

# Session details
curl -s "http://127.0.0.1:4096/session/$SESSION_ID" | jq .

# Session messages
curl -s "http://127.0.0.1:4096/session/$SESSION_ID/message" | \
  jq '.[] | {role: .info.role, content: .parts[0].text}'

# Session code diff
curl -s "http://127.0.0.1:4096/session/$SESSION_ID/diff" | jq .
```

### Batch Task Execution

```bash
# Define tasks: PORT:PROMPT
TASKS=(
  "4096:Analyze backend/app/main.py"
  "4097:Analyze frontend/src/App.tsx"
  "4098:Generate API docs"
)

# Run in parallel
for task in "${TASKS[@]}"; do
  PORT=$(echo "$task" | cut -d: -f1)
  PROMPT=$(echo "$task" | cut -d: -f2-)
  echo "Submitting task to port $PORT: $PROMPT"
  $OPENCODE_PATH run --attach "http://127.0.0.1:$PORT" "$PROMPT" \
    > "/tmp/task_${PORT}.log" 2>&1 &
done

wait
echo "All tasks completed"

# Show results
for port in 4096 4097 4098; do
  echo "=== Port $port results ==="
  cat "/tmp/task_${port}.log" | \
    jq -r 'select(.type=="text") | .text' 2>/dev/null | head -20
done
```

---

## API Quick Reference

### Core Endpoints

| Category | Method | Endpoint        | Description                  |
|----------|--------|-----------------|------------------------------|
| Docs     | GET    | `/doc`          | OpenAPI 3.1 specification    |
| Health   | GET    | `/global/health`| Server health status         |
| Events   | GET    | `/global/event` | SSE global event stream      |
| Events   | GET    | `/event`        | SSE event stream (all events)|

### Session Management

| Method | Endpoint                  | Description              |
|--------|---------------------------|--------------------------|
| GET    | `/session`                | List all sessions       |
| POST   | `/session`                | Create new session      |
| GET    | `/session/:id`            | Get session details     |
| DELETE | `/session/:id`            | Delete session          |
| GET    | `/session/:id/message`    | Get session messages    |
| POST   | `/session/:id/message`    | Send message (sync)     |
| POST   | `/session/:id/prompt_async` | Send message (async)  |
| GET    | `/session/:id/todo`       | Get session todos       |
| POST   | `/session/:id/abort`      | Abort running session   |
| GET    | `/session/:id/diff`       | Get session code diff   |

### Files & Search

| Method | Endpoint                   | Description          |
|--------|----------------------------|----------------------|
| GET    | `/find?pattern=xxx`       | Search file contents |
| GET    | `/find/file?query=xxx`    | Find files by name   |
| GET    | `/file?path=xxx`          | List directory       |
| GET    | `/file/content?path=xxx`  | Read file content    |

### Infrastructure

| Method | Endpoint   | Description               |
|--------|------------|---------------------------|
| GET    | `/mcp`     | MCP server status         |
| POST   | `/mcp`     | Add MCP server dynamically|
| GET    | `/lsp`     | LSP server status         |
| GET    | `/config`  | Get server configuration  |

---

## Troubleshooting

### Issue 1: Port already in use

```bash
# Check port usage
ss -tlnp | grep 4096
lsof -i :4096

# Fix: stop conflicting process or use another port
kill $(lsof -ti:4096)
# Or
$OPENCODE_PATH serve --port 4097
```

### Issue 2: Server exits immediately after start

```bash
# Check logs for errors
cat /tmp/opencode_server_4096.log | tail -50

# Common causes:
# - Invalid config file
# - MCP server startup failures
# - Permission problems

# Start in debug mode
$OPENCODE_PATH --print-logs --log-level DEBUG serve --port 4096
```

### Issue 3: API requests failing

```bash
# Check if server is running
curl -v http://127.0.0.1:4096/global/health

# If authentication is enabled
curl -u opencode:password http://127.0.0.1:4096/global/health

# Check firewall rules
sudo iptables -L -n | grep 4096
```

### Issue 4: MCP servers not loading

```bash
# Check MCP status
curl -s http://127.0.0.1:4096/mcp | jq .

# Check MCP config in opencode.json
cat opencode.json | jq '.mcp'
```

---

## Best Practices

1. **Process management**
   - Always store PIDs in files for easier control
   - Consider using `systemd`, `supervisor`, or similar for long‑running services
   - Periodically check health via `/global/health`

2. **Log management**
   - Use `--log-level WARN` or higher in production to reduce noise
   - Configure log rotation (e.g., `logrotate`) for `/tmp/opencode_server_*.log`
   - Regularly clean up old logs to avoid disk pressure

3. **Port planning**

   | Port range | Usage                      |
   |-----------|----------------------------|
   | 4096      | Main development server    |
   | 4097–4099 | Parallel task instances    |
   | 4100+     | Test / experimental servers|

4. **Security**
   - Always set `OPENCODE_SERVER_PASSWORD` in production
   - Use `--hostname 127.0.0.1` to restrict to local access by default
   - For remote access, put OpenCode behind a reverse proxy (HTTPS, auth, rate limits)

5. **Resource monitoring**

   ```bash
   # Monitor memory usage
   ps aux | grep "opencode.*serve" | \
     awk '{print "PID: "$2", RSS: "$6/1024" MB"}'

   # Monitor connection count
   ss -tnp | grep 4096 | wc -l
   ```

---

## Quick Command Reference

```bash
# === Start ===
# Single instance
opencode --print-logs serve --port 4096 > /tmp/opencode_4096.log 2>&1 &

# === Find ===
# List all instances
ps aux | grep "opencode.*serve" | grep -v grep

# Health check
curl -s http://127.0.0.1:4096/global/health | jq .

# === Interact ===
# Send a task
opencode run --attach http://127.0.0.1:4096 "your task"

# Attach TUI
opencode attach http://127.0.0.1:4096

# === Monitor ===
# Realtime logs
tail -f /tmp/opencode_4096.log

# SSE event stream
curl -N http://127.0.0.1:4096/event

# === Cleanup ===
# Stop all
pkill -f "opencode.*serve"

# Remove logs and PID files
rm -f /tmp/opencode*.log /tmp/opencode*.pid
```

---

**Version:** v2.0  
**Last Updated:** 2026-01-28  
**Compatibility:** OpenCode 1.1.39+  
**Reference:** https://opencode.ai/docs/server

# opencode-manager

Manage OpenCode background instances: startup, monitoring, command execution, and result capture. Use this workflow when users need to run OpenCode servers in the background, execute commands, and listen to outputs.

---

## Core Concepts

OpenCode supports running as a long-lived server (daemon) via `opencode serve`. Unlike one-time execution, the server continuously listens on a port, accepts multiple connections, and logs all activities.

**Architecture:**
```
┌─────────────────────────────────────────────────────────┐
│  opencode serve (background process)                    │
│  ├─ Listen port: 4096 (default)                        │
│  ├─ Load config: opencode.json                         │
│  ├─ Expose OpenAPI 3.1 interface                       │
│  └─ Support multiple simultaneous clients              │
└─────────────────────────────────────────────────────────┘
         ↓                    ↓                    ↓
    [Web UI]           [CLI Attach]          [API/SDK]
  http://localhost      opencode attach     curl/fetch
     :4096              :4096
```

**Key Advantages:**
- ✅ Persistent operation, independent of terminal session
- ✅ All interactions queryable via API
- ✅ Multiple instances on different ports
- ✅ Web UI, TUI, API, or SDK interaction
- ✅ SSE real-time event streaming
- ✅ OpenAPI 3.1 spec for client generation

---

## Workflows

### Scenario 1: Start Background OpenCode Instances

**Goal:** Start one or more OpenCode servers in background

**Steps:**

1. **Locate opencode binary**
```bash
OPENCODE_PATH=$(which opencode || echo "/root/.opencode/bin/opencode")
echo "OpenCode path: $OPENCODE_PATH"
```

2. **Check port availability**
```bash
ss -tlnp | grep 4096 || echo "Port 4096 available"
lsof -i :4096 || echo "Port 4096 available"
```

3. **Start server (single instance)**
```bash
# Note: --print-logs and --log-level are global flags, placed before serve
$OPENCODE_PATH --print-logs --log-level INFO serve \
  --port 4096 \
  --hostname 127.0.0.1 \
  > /tmp/opencode_server_4096.log 2>&1 &

echo $! > /tmp/opencode_server_4096.pid
echo "OpenCode server started (PID: $(cat /tmp/opencode_server_4096.pid))"
```

4. **Start multiple instances**
```bash
find_available_port() {
  local port=${1:-4096}
  while ss -tlnp | grep -q ":$port "; do
    ((port++))
  done
  echo $port
}

for i in 1 2 3; do
  PORT=$(find_available_port $((4095 + i)))
  $OPENCODE_PATH --print-logs --log-level INFO serve \
    --port $PORT \
    > /tmp/opencode_server_$PORT.log 2>&1 &
  echo $! > /tmp/opencode_server_$PORT.pid
  echo "Instance $i: Port $PORT, PID $(cat /tmp/opencode_server_$PORT.pid)"
done
```

5. **Verify startup**
```bash
ps aux | grep "opencode.*serve" | grep -v grep
ss -tlnp | grep -E "4096|4097|4098"
curl -s http://127.0.0.1:4096/global/health | jq .
echo "OpenAPI docs: http://127.0.0.1:4096/doc"
```

---

### Scenario 2: Find Running Instances

**Goal:** Find all running OpenCode servers

```bash
# List all instances
ps aux | grep "opencode.*serve" | grep -v grep | awk '{
  pid = $2
  for(i=1;i<=NF;i++) {
    if($i == "--port") port = $(i+1)
  }
  printf "PID: %s, Port: %s\n", pid, port
}'

# Check health via API
for port in 4096 4097 4098; do
  HEALTH=$(curl -s --connect-timeout 2 http://127.0.0.1:$port/global/health 2>/dev/null)
  if [ -n "$HEALTH" ]; then
    VERSION=$(echo "$HEALTH" | jq -r '.version // "unknown"')
    echo "Port $port: Running (version $VERSION)"
  else
    echo "Port $port: Not running"
  fi
done
```

---

### Scenario 3: Send Commands and Capture Results

**Method 1: Using `opencode run --attach`**

```bash
# JSONL format output (one JSON object per line)
$OPENCODE_PATH run \
  --attach http://127.0.0.1:4096 \
  --format json \
  "List files in current directory" 2>&1
```

**JSONL Event Types:**
| Event Type | Description |
|------------|-------------|
| `step_start` | Processing step started, contains sessionID and timestamp |
| `tool_use` | Tool call completed, contains tool name, input/output, status |
| `text` | Model text output with actual content |

**Method 2: Using `opencode attach` for interactive mode**

```bash
$OPENCODE_PATH attach http://127.0.0.1:4096
$OPENCODE_PATH attach http://127.0.0.1:4096 --dir /path/to/project --session ses_xxx
```

**Method 3: REST API**

```bash
# List sessions
curl -s http://127.0.0.1:4096/session | jq .

# Create session
SESSION=$(curl -s -X POST http://127.0.0.1:4096/session \
  -H "Content-Type: application/json" \
  -d '{"title": "API Test Session"}')
SESSION_ID=$(echo "$SESSION" | jq -r '.id')

# Send message (sync)
curl -s -X POST "http://127.0.0.1:4096/session/$SESSION_ID/message" \
  -H "Content-Type: application/json" \
  -d '{"parts": [{"type": "text", "text": "List current directory"}]}' | jq .

# Send message (async)
curl -s -X POST "http://127.0.0.1:4096/session/$SESSION_ID/prompt_async" \
  -H "Content-Type: application/json" \
  -d '{"parts": [{"type": "text", "text": "Analyze code structure"}]}'

# Get messages
curl -s "http://127.0.0.1:4096/session/$SESSION_ID/message" | jq .
```

---

### Scenario 4: Monitor Instance Output

**Method 1: SSE Event Stream (Recommended)**

```bash
curl -N -s http://127.0.0.1:4096/global/event | while read -r line; do
  if [[ "$line" == data:* ]]; then
    EVENT=$(echo "$line" | sed 's/^data://')
    TYPE=$(echo "$EVENT" | jq -r '.type // "unknown"')
    echo "[$(date '+%H:%M:%S')] Event: $TYPE"
  fi
done
```

**Method 2: Log file monitoring**

```bash
tail -f /tmp/opencode_server_4096.log
tail -f /tmp/opencode_server_4096.log | grep --line-buffered -E "session|message|tool|ERROR|WARN"
```

---

### Scenario 5: Stop and Cleanup

```bash
# Stop specific instance
kill $(cat /tmp/opencode_server_4096.pid 2>/dev/null)
kill $(lsof -ti:4096)

# Stop all instances
pkill -f "opencode.*serve"

# Cleanup temp files
rm -f /tmp/opencode_server*.log /tmp/opencode_server*.pid /tmp/task*.log
```

---

## Advanced Usage

### Authentication

```bash
OPENCODE_SERVER_PASSWORD=your-secure-password \
OPENCODE_SERVER_USERNAME=admin \
$OPENCODE_PATH serve --port 4096

curl -u admin:your-secure-password http://127.0.0.1:4096/global/health
```

### CORS Configuration

```bash
$OPENCODE_PATH serve \
  --port 4096 \
  --hostname 0.0.0.0 \
  --cors http://localhost:3000 \
  --cors https://app.example.com
```

### Persistent Running with nohup

```bash
nohup $OPENCODE_PATH --print-logs --log-level INFO serve \
  --port 4096 \
  > /tmp/opencode_server_4096.log 2>&1 &
echo $! > /tmp/opencode_server_4096.pid
disown
```

---

## API Quick Reference

### Core Endpoints

| Category | Method | Endpoint | Description |
|----------|--------|----------|-------------|
| Docs | GET | `/doc` | OpenAPI 3.1 spec |
| Health | GET | `/global/health` | Server health status |
| Events | GET | `/global/event` | SSE global event stream |
| Events | GET | `/event` | SSE event stream (all) |

### Session Management

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/session` | List all sessions |
| POST | `/session` | Create new session |
| GET | `/session/:id` | Get session details |
| DELETE | `/session/:id` | Delete session |
| GET | `/session/:id/message` | Get session messages |
| POST | `/session/:id/message` | Send message (sync) |
| POST | `/session/:id/prompt_async` | Send message (async) |
| GET | `/session/:id/todo` | Get session todos |
| POST | `/session/:id/abort` | Abort running session |

### Files & Search

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/find?pattern=xxx` | Search file contents |
| GET | `/find/file?query=xxx` | Find files by name |
| GET | `/file?path=xxx` | List directory |
| GET | `/file/content?path=xxx` | Read file content |

---

## Troubleshooting

### Port Already in Use
```bash
ss -tlnp | grep 4096
kill $(lsof -ti:4096)
```

### Server Exits Immediately
```bash
cat /tmp/opencode_server_4096.log | tail -50
$OPENCODE_PATH --print-logs --log-level DEBUG serve --port 4096
```

### MCP Servers Not Loading
```bash
curl -s http://127.0.0.1:4096/mcp | jq .
cat opencode.json | jq '.mcp'
```

---

## Quick Command Reference

```bash
# === Start ===
opencode --print-logs serve --port 4096 > /tmp/opencode_4096.log 2>&1 &

# === Find ===
ps aux | grep "opencode.*serve" | grep -v grep
curl -s http://127.0.0.1:4096/global/health | jq .

# === Interact ===
opencode run --attach http://127.0.0.1:4096 "your task"
opencode attach http://127.0.0.1:4096

# === Monitor ===
tail -f /tmp/opencode_4096.log
curl -N http://127.0.0.1:4096/event

# === Cleanup ===
pkill -f "opencode.*serve"
rm -f /tmp/opencode*.log /tmp/opencode*.pid
```

---

**Version:** v2.0  
**Last Updated:** 2026-01-28  
**Compatibility:** OpenCode 1.1.39+  
**Reference:** https://opencode.ai/docs/server
