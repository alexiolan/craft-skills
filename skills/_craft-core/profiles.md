# Craft Executor Profiles

This file is the authoritative reference for profile definitions. Read by wrappers and `develop` to determine which executors are active for a run.

## Profile values

| Value | Claude | Codex | Local LLM | Used by |
|---|---|---|---|---|
| `claude` | yes | no | no | `/craft` |
| `claude+codex` | yes | yes | no | `/craft-duo` |
| `claude+llm` | yes | no | yes | `/craft-local` |
| `claude+codex+llm` | yes | yes | yes | `/craft-squad` |

## `.craft-profile` file

Wrapper skills write the profile value as a single line (no trailing newline) to `.craft-profile` at the project root as their very first step:

```bash
echo -n "claude+codex" > "$PROJECT_ROOT/.craft-profile"
```

`develop`, `architect`, and `_craft-core/core.md` read it:

```bash
CRAFT_PROFILE=$(cat "$PROJECT_ROOT/.craft-profile" 2>/dev/null || echo "claude")
```

Default when missing: `claude` (backwards-compatible fallback).

## Gating helpers

```bash
# Does the profile include Codex?
case "$CRAFT_PROFILE" in
  *codex*) CODEX_ENABLED=1 ;;
  *)       CODEX_ENABLED=0 ;;
esac

# Does the profile include local LLM?
case "$CRAFT_PROFILE" in
  *llm*) LLM_ENABLED=1 ;;
  *)     LLM_ENABLED=0 ;;
esac
```

## Cleanup

`.craft-profile` is deleted alongside `.shared-state.md` at the end of `develop` Step 5 (cleanup).
