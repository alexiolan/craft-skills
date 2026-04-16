#!/bin/bash
# Shared LLM configuration — sourced by all llm-*.sh scripts
# Override any variable by setting it in the environment before running a script.
#
# Usage (in other scripts): source "$(dirname "$0")/llm-config.sh"

export LLM_MODEL="${LLM_MODEL:-google/gemma-4-26b-a4b}"
export LLM_URL="${LLM_URL:-http://127.0.0.1:1234}"
export LLM_CONTEXT_LENGTH="${LLM_CONTEXT_LENGTH:-131072}"
export LMS="${LMS:-${HOME}/.lmstudio/bin/lms}"

# Extract short model name for grep matching (e.g., "google/gemma-4-26b-a4b" → "gemma-4-26b-a4b")
export LLM_MODEL_SHORT=$(echo "$LLM_MODEL" | sed 's|.*/||')

# Ensure the configured model is loaded with the correct context length.
# Call this from any script that needs the model ready before making API calls.
llm_ensure_loaded() {
  [ -x "$LMS" ] || return 0
  local loaded
  loaded=$("$LMS" ps 2>/dev/null | grep -c "$LLM_MODEL_SHORT")
  if [ "$loaded" -eq 0 ]; then
    "$LMS" load "$LLM_MODEL" -c "$LLM_CONTEXT_LENGTH" 2>/dev/null
  else
    local ctx
    ctx=$("$LMS" ps 2>/dev/null | grep "$LLM_MODEL_SHORT" | grep -oE '\b[0-9]{4,6}\b' | head -1)
    if [ -n "$ctx" ] && [ "$ctx" -lt "$LLM_CONTEXT_LENGTH" ] 2>/dev/null; then
      "$LMS" unload "$LLM_MODEL" 2>/dev/null
      sleep 2
      "$LMS" load "$LLM_MODEL" -c "$LLM_CONTEXT_LENGTH" 2>/dev/null
    fi
  fi
}
