# LLM Gating Rules

Local LLM (LM Studio) paths run only when the profile includes `llm`.

## Gated step: `architect` pre-exploration (Step 0)

Currently `architect/SKILL.md` runs an LLM availability check and optional background exploration via `llm-agent.sh`. Under profile gating:

```bash
CRAFT_PROFILE=$(cat "$PROJECT_ROOT/.craft-profile" 2>/dev/null || echo "claude")
case "$CRAFT_PROFILE" in
  *llm*)
    # existing LLM availability check + background llm-agent.sh dispatch
    ;;
  *)
    # skip — no LLM steps
    echo "LLM_SKIPPED_BY_PROFILE"
    ;;
esac
```

## Gated step: `develop` Step 3.5 (post-develop review)

Currently runs `llm-agent.sh` to review implementation files. Same gating pattern.

## Gated step: `craft` spec review (Step 1.10)

Currently runs `llm-review.sh` as a parallel supplementary review of the spec. Same gating pattern.

## Gated step: `craft` plan review (Step 2.4)

Currently runs `llm-review.sh` as a parallel supplementary review of the plan. Same gating pattern.

## Unloading

LM Studio keep-loaded / unload scripts run only when LLM was actually loaded. The guard is the same profile check — if LLM was skipped, don't call `llm-unload.sh`.

## What does NOT get gated

Graph tools (`code-review-graph` MCP) run in every profile. They are deterministic infrastructure, not AI. See `profiles.md`.
