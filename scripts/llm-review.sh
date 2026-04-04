#!/bin/bash
# Review a file using local LLM via LM Studio (with thinking/reasoning)
# Auto-loads the model if not already loaded
# Usage: llm-review.sh <file_path> [focus] [model]
# Returns: review text to stdout (reasoning is used internally, not printed)
#
# Environment:
#   LLM_URL   - API base URL (default: http://127.0.0.1:1234)
#   LLM_MODEL - model identifier (default: qwen/qwen3.5-35b-a3b)

FILE="$1"
FOCUS="${2:-general code quality}"
MODEL="${3:-${LLM_MODEL:-qwen/qwen3.5-35b-a3b}}"
URL="${LLM_URL:-http://127.0.0.1:1234}"
LMS="${HOME}/.lmstudio/bin/lms"

# Health check mode
if [ -z "$FILE" ] || [ "$FILE" = "/dev/null" ]; then
  bash "$(dirname "$0")/llm-check.sh"
  exit 0
fi

if [ ! -f "$FILE" ]; then
  echo "File not found: $FILE" >&2
  exit 1
fi

# Check server
if ! curl -s --max-time 2 "$URL" > /dev/null 2>&1; then
  echo "LLM_UNAVAILABLE"
  exit 0
fi

# Auto-load model with correct context length
if [ -x "$LMS" ]; then
  LOADED=$("$LMS" ps 2>/dev/null | grep -c "qwen3.5-35b-a3b")
  if [ "$LOADED" -eq 0 ]; then
    "$LMS" load "$MODEL" -c 65536 2>/dev/null
  else
    # Reload if context too small
    CTX=$("$LMS" ps 2>/dev/null | grep "qwen3.5-35b-a3b" | grep -oE '\b[0-9]{4,6}\b' | head -1)
    if [ -n "$CTX" ] && [ "$CTX" -lt 65536 ] 2>/dev/null; then
      "$LMS" unload "$MODEL" 2>/dev/null
      sleep 2
      "$LMS" load "$MODEL" -c 65536 2>/dev/null
    fi
  fi
fi

FILENAME=$(basename "$FILE")

python3 - "$URL" "$MODEL" "$FILE" "$FILENAME" "$FOCUS" <<'PYEOF'
import sys, json, urllib.request

url, model, filepath, filename, focus = sys.argv[1:6]
content = open(filepath).read()

prompt = f"""/think
Review the file '{filename}'. Focus on: {focus}.
Report ONLY confirmed issues. Be concise — no filler, no praise, just findings.

File content:
{content}"""

try:
    data = json.dumps({
        "model": model,
        "max_tokens": 16384,
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.6,
        "top_p": 0.95
    }).encode()
    req = urllib.request.Request(
        f"{url}/v1/chat/completions", data=data,
        headers={"Content-Type": "application/json"}
    )
    resp = json.loads(urllib.request.urlopen(req, timeout=300).read())
    msg = resp["choices"][0]["message"]
    answer = msg.get("content", "")
    if answer.strip():
        print(answer)
    else:
        # Fallback: if answer empty, model used all tokens on thinking
        reasoning = msg.get("reasoning_content", "")
        if reasoning:
            print("LLM_THINKING_OVERFLOW: model used all tokens on reasoning, increase max_tokens or simplify prompt")
        else:
            print("LLM_ERROR: empty response")
except Exception as e:
    print(f"LLM_ERROR: {e}", file=sys.stderr)
    sys.exit(1)
PYEOF
