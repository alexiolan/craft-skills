#!/bin/bash
# Unload all models from LM Studio to free RAM
# Run at the end of pipeline LLM steps

LMS="${HOME}/.lmstudio/bin/lms"

if [ -x "$LMS" ]; then
  "$LMS" unload --all 2>/dev/null
  echo "LLM_UNLOADED"
else
  echo "LLM_SKIP: lms CLI not found"
fi
