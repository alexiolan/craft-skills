#!/bin/bash
# Quick LLM availability check — run once at pipeline start
# Returns one line: LLM_AVAILABLE or LLM_UNAVAILABLE with details
# Claude reads this output and skips all LLM steps if unavailable

LMS="${HOME}/.lmstudio/bin/lms"
MODEL="${LLM_MODEL:-qwen/qwen3.5-35b-a3b}"
URL="${LLM_URL:-http://127.0.0.1:1234}"

# Check 1: lms CLI exists
if [ ! -x "$LMS" ]; then
  echo "LLM_UNAVAILABLE: LM Studio CLI not found"
  exit 0
fi

# Check 2: LM Studio server is running
if ! curl -s --max-time 2 "$URL" > /dev/null 2>&1; then
  echo "LLM_UNAVAILABLE: LM Studio server not running on $URL"
  exit 0
fi

# Check 3: model is installed
if ! "$LMS" ls 2>/dev/null | grep -q "qwen3.5-35b-a3b"; then
  echo "LLM_UNAVAILABLE: model $MODEL not installed"
  exit 0
fi

# Auto-load model if not loaded (warm up ~10s)
LOADED=$("$LMS" ps 2>/dev/null | grep -c "qwen3.5-35b-a3b")
if [ "$LOADED" -eq 0 ]; then
  "$LMS" load "$MODEL" -c 65536 -y 2>/dev/null
fi

echo "LLM_AVAILABLE: $MODEL on $URL (loaded and ready)"
