#!/bin/bash
# Run a benchmark scenario with full metrics capture and verification.
#
# Usage: ./run-scenario.sh <scenario-name> [output-dir]
# Example: ./run-scenario.sh orders-page
#          ./run-scenario.sh orders-page /tmp/my-bench-run
#
# Scenarios live in bench/scenarios/<name>.json and reference task files
# in bench/scenarios/tasks/.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCENARIO_NAME="${1:?Usage: $0 <scenario-name> [output-dir]}"
OUTPUT_DIR="${2:-/tmp/bench-${SCENARIO_NAME}-$(date +%s)}"

SCENARIO_FILE="$SCRIPT_DIR/scenarios/${SCENARIO_NAME}.json"
if [ ! -f "$SCENARIO_FILE" ]; then
  echo "Scenario not found: $SCENARIO_FILE" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"
echo "=== Bench scenario: $SCENARIO_NAME ==="
echo "Output dir: $OUTPUT_DIR"
echo ""

# Parse scenario config
PROJECT_ROOT=$(python3 -c "import json; print(json.load(open('$SCENARIO_FILE'))['project_root'])")

# Pre-flight: ensure project clean
echo "=== Pre-flight: ensuring $PROJECT_ROOT is clean ==="
cd "$PROJECT_ROOT"
git checkout -- . 2>/dev/null || true
python3 -c "
import json
s = json.load(open('$SCENARIO_FILE'))
for p in s.get('cleanup_paths', []):
    import shutil, os
    full = os.path.join(s['project_root'], p)
    if os.path.exists(full):
        if os.path.isdir(full):
            shutil.rmtree(full)
        else:
            os.unlink(full)
        print(f'  Removed: {p}')
"
echo ""

# Run dispatches
DISPATCH_COUNT=$(python3 -c "import json; print(len(json.load(open('$SCENARIO_FILE'))['dispatches']))")
echo "=== Running $DISPATCH_COUNT dispatch(es) ==="

OVERALL_START=$(date +%s.%N)
for i in $(seq 0 $((DISPATCH_COUNT - 1))); do
  DISPATCH_INFO=$(python3 -c "
import json, os
s = json.load(open('$SCENARIO_FILE'))
d = s['dispatches'][$i]
print(d['id'])
print(os.path.join(os.path.dirname('$SCENARIO_FILE'), d['task_file']))
print(','.join(d['allowed_files']))
print('|'.join(os.path.join(s['project_root'], r) for r in d['ref_files']))
")
  IFS=$'\n' read -r -d '' DISPATCH_ID TASK_PATH ALLOWED REFS <<<"$DISPATCH_INFO" || true

  echo ""
  echo "--- Dispatch $((i + 1))/$DISPATCH_COUNT: $DISPATCH_ID ---"

  METRICS_FILE="$OUTPUT_DIR/$(printf '%02d' $((i + 1)))-${DISPATCH_ID}.json"
  STDOUT_FILE="$OUTPUT_DIR/$(printf '%02d' $((i + 1)))-${DISPATCH_ID}.stdout"
  STDERR_FILE="$OUTPUT_DIR/$(printf '%02d' $((i + 1)))-${DISPATCH_ID}.stderr"

  IFS='|' read -r -a REF_ARRAY <<<"$REFS"

  D_START=$(date +%s.%N)
  LLM_METRICS_FILE="$METRICS_FILE" \
    bash "$SCRIPT_DIR/../scripts/llm-implement.sh" \
    "$TASK_PATH" \
    "$PROJECT_ROOT" \
    "$ALLOWED" \
    "${REF_ARRAY[@]}" \
    > "$STDOUT_FILE" 2> "$STDERR_FILE" || true
  D_END=$(date +%s.%N)
  D_ELAPSED=$(echo "$D_END - $D_START" | bc)

  STATUS=$(python3 -c "import json; r=json.load(open('$STDOUT_FILE')); print(r.get('status','?'), r.get('severity','?'))" 2>/dev/null || echo "PARSE_ERROR ?")
  echo "  Status: $STATUS, wall-clock: ${D_ELAPSED}s, metrics: $METRICS_FILE"
done

OVERALL_END=$(date +%s.%N)
OVERALL_ELAPSED=$(echo "$OVERALL_END - $OVERALL_START" | bc)
echo ""
echo "=== All dispatches done in ${OVERALL_ELAPSED}s ==="

# Verify
echo ""
echo "=== Verification ==="
VERIFY_TSC=$(python3 -c "import json; print(json.load(open('$SCENARIO_FILE'))['verify'].get('tsc', False))")
VERIFY_LINT=$(python3 -c "import json; print(json.load(open('$SCENARIO_FILE'))['verify'].get('eslint_fix', False))")
VERIFY_PRETTIER=$(python3 -c "import json; print(json.load(open('$SCENARIO_FILE'))['verify'].get('prettier', False))")

cd "$PROJECT_ROOT"

if [ "$VERIFY_LINT" = "True" ]; then
  echo "--- ESLint --fix ---"
  CHANGED=$(git ls-files --modified --others --exclude-standard | tr '\n' ' ')
  if [ -n "$CHANGED" ]; then
    npx eslint --fix $CHANGED 2>&1 | tail -10 || true
  fi
fi

if [ "$VERIFY_PRETTIER" = "True" ]; then
  echo "--- Prettier ---"
  CHANGED=$(git ls-files --modified --others --exclude-standard | tr '\n' ' ')
  if [ -n "$CHANGED" ]; then
    npx prettier --write $CHANGED 2>&1 | tail -5 || true
  fi
fi

if [ "$VERIFY_TSC" = "True" ]; then
  echo "--- TypeScript check ---"
  TSC_OUT=$(npx tsc --noEmit 2>&1 | head -10)
  if [ -z "$TSC_OUT" ]; then
    echo "  ✓ tsc clean"
    TSC_RESULT="PASS"
  else
    echo "$TSC_OUT"
    TSC_RESULT="FAIL"
  fi
fi

# Aggregate metrics
echo ""
echo "=== Metrics Aggregate ==="
bash "$SCRIPT_DIR/aggregate-metrics.sh" "$OUTPUT_DIR"

# Cleanup project
echo ""
echo "=== Cleanup ==="
cd "$PROJECT_ROOT"
git checkout -- . 2>/dev/null || true
python3 -c "
import json, os, shutil
s = json.load(open('$SCENARIO_FILE'))
for p in s.get('cleanup_paths', []):
    full = os.path.join(s['project_root'], p)
    if os.path.exists(full):
        if os.path.isdir(full):
            shutil.rmtree(full)
        else:
            os.unlink(full)
"
echo "Project reverted to clean state"

# Save run summary
RESULT="${TSC_RESULT:-N/A}"
python3 - <<PYEOF
import json, glob, os
files = sorted(glob.glob('$OUTPUT_DIR/*.json'))
totals = {'wall_clock': 0.0, 'iterations': 0, 'prompt_tokens': 0, 'completion_tokens': 0}
for f in files:
    m = json.load(open(f))
    totals['wall_clock'] += m.get('wall_clock_total_s', 0)
    totals['iterations'] += m.get('iterations', 0)
    totals['prompt_tokens'] += m.get('total_prompt_tokens', 0)
    totals['completion_tokens'] += m.get('total_completion_tokens', 0)
totals['scenario'] = '$SCENARIO_NAME'
totals['tsc_result'] = '$RESULT'
totals['dispatch_count'] = len(files)
with open('$OUTPUT_DIR/SUMMARY.json', 'w') as f:
    json.dump(totals, f, indent=2)
print(f"\nRun summary saved to $OUTPUT_DIR/SUMMARY.json")
PYEOF

echo ""
echo "=== Done ==="
echo "Compare with baseline: BASELINE_METRICS_FILE=bench/baseline-${SCENARIO_NAME}.json bash $SCRIPT_DIR/aggregate-metrics.sh $OUTPUT_DIR"
