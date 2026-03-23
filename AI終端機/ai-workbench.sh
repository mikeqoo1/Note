#!/usr/bin/env bash
set -euo pipefail

WORKDIR="${1:-$PWD}"
PROJECT_NAME="$(basename "$WORKDIR" | tr ' /:' '___')"
SESSION_NAME="ai-${PROJECT_NAME}"
WINDOW_NAME="ai"

for cmd in tmux bash; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: 找不到指令: $cmd"
    exit 1
  fi
done

if ! command -v claude >/dev/null 2>&1; then
  echo "WARN: 找不到 claude，左上 pane 會停在 shell"
  CLAUDE_CMD="bash"
else
  CLAUDE_CMD="claude"
fi

if ! command -v codex >/dev/null 2>&1; then
  echo "WARN: 找不到 codex，右上 pane 會停在 shell"
  CODEX_CMD="bash"
else
  CODEX_CMD="codex"
fi

if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
  exec tmux attach-session -t "$SESSION_NAME"
fi

# 建新 session + window
tmux new-session -d -s "$SESSION_NAME" -c "$WORKDIR" -n "$WINDOW_NAME"

sleep 0.1

# 左上：claude（目前唯一 pane）
tmux send-keys -t "${SESSION_NAME}:${WINDOW_NAME}" "$CLAUDE_CMD" C-m

# 右上：codex
tmux split-window -h -t "${SESSION_NAME}:${WINDOW_NAME}" -c "$WORKDIR"
tmux send-keys -t "${SESSION_NAME}:${WINDOW_NAME}.2" "$CODEX_CMD" C-m 2>/dev/null || \
tmux send-keys -t "${SESSION_NAME}:${WINDOW_NAME}.1" "$CODEX_CMD" C-m

# 下方：test + git
tmux split-window -v -f -t "${SESSION_NAME}:${WINDOW_NAME}" -c "$WORKDIR"
tmux send-keys -t "${SESSION_NAME}:${WINDOW_NAME}.3" \
'clear; echo "=== TEST + GIT PANE ==="; echo; \
echo "[git status]"; git status 2>/dev/null || true; echo; \
echo "常用指令建議:"; \
echo "  git status"; \
echo "  git diff"; \
echo "  pytest -q"; \
echo "  npm test"; \
echo "  pnpm test"; \
echo "  yarn test"; \
echo; \
exec bash' C-m 2>/dev/null || \
tmux send-keys -t "${SESSION_NAME}:${WINDOW_NAME}.2" \
'clear; echo "=== TEST + GIT PANE ==="; echo; \
echo "[git status]"; git status 2>/dev/null || true; echo; \
echo "常用指令建議:"; \
echo "  git status"; \
echo "  git diff"; \
echo "  pytest -q"; \
echo "  npm test"; \
echo "  pnpm test"; \
echo "  yarn test"; \
echo; \
exec bash' C-m

# 讓底部 pane 高度比較合理
tmux resize-pane -t "${SESSION_NAME}:${WINDOW_NAME}" -D 10

# 游標回左上
tmux select-pane -t "${SESSION_NAME}:${WINDOW_NAME}.1" 2>/dev/null || true

exec tmux attach-session -t "$SESSION_NAME"