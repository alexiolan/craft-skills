#!/bin/bash
# Aggregate LLM session metrics across multiple dispatch JSON files.
# Usage: ./aggregate-metrics.sh <metrics-dir-or-glob>
# Example: ./aggregate-metrics.sh /tmp/orders-test-metrics
#          ./aggregate-metrics.sh "/tmp/run-*.json"

set -e

INPUT="${1:-.}"

# Resolve to a list of JSON files
if [ -d "$INPUT" ]; then
  FILES=("$INPUT"/*.json)
else
  FILES=($INPUT)
fi

if [ ${#FILES[@]} -eq 0 ] || [ ! -f "${FILES[0]}" ]; then
  echo "No metrics JSON files found at: $INPUT" >&2
  exit 1
fi

python3 - "${FILES[@]}" <<'PYEOF'
import json, sys, os

files = sorted(sys.argv[1:])

print(f"=== LLM Session Metrics Aggregate ({len(files)} dispatch(es)) ===\n")
print(f"{'Stage':<28} {'Wall':>7} {'Iters':>5} {'Cold':>7} {'WarmAvg':>8} {'In':>8} {'Out':>6} {'Exit':<14}")
print("─" * 100)

totals = {
    "wall_clock": 0.0,
    "iterations": 0,
    "prompt_tokens": 0,
    "completion_tokens": 0,
    "tools": {},
    "cold_iters": [],
    "warm_iters": [],
    "exit_reasons": {},
}

valid = 0
for f in files:
    try:
        m = json.load(open(f))
    except Exception as e:
        print(f"  (skipped {os.path.basename(f)}: {e})", file=sys.stderr)
        continue

    name = os.path.basename(f).replace('.json', '')[:28]
    timings = m.get('iteration_timings_s', [])
    iters = m.get('iterations', 0)
    if iters == 0 or not timings:
        wall = m.get('wall_clock_total_s', 0)
        exit_r = m.get('exit_reason', '?')[:14]
        print(f"{name:<28} {wall:>6.1f}s {iters:>5} {'-':>7} {'-':>8} {'-':>8} {'-':>6} {exit_r:<14}")
        totals["exit_reasons"][exit_r] = totals["exit_reasons"].get(exit_r, 0) + 1
        continue

    valid += 1
    cold = timings[0]
    warm_iters = timings[1:]
    warm_avg = sum(warm_iters) / len(warm_iters) if warm_iters else 0
    wall = m.get('wall_clock_total_s', sum(timings))
    p_in = m.get('total_prompt_tokens', 0)
    p_out = m.get('total_completion_tokens', 0)
    exit_r = m.get('exit_reason', 'final_answer')[:14]

    print(f"{name:<28} {wall:>6.1f}s {iters:>5} {cold:>6.1f}s {warm_avg:>7.2f}s {p_in:>8} {p_out:>6} {exit_r:<14}")

    totals["wall_clock"] += wall
    totals["iterations"] += iters
    totals["prompt_tokens"] += p_in
    totals["completion_tokens"] += p_out
    totals["cold_iters"].append(cold)
    totals["warm_iters"].extend(warm_iters)
    totals["exit_reasons"][exit_r] = totals["exit_reasons"].get(exit_r, 0) + 1
    for t, c in m.get('tool_calls', {}).items():
        totals["tools"][t] = totals["tools"].get(t, 0) + c

print("─" * 100)
print(f"{'TOTAL':<28} {totals['wall_clock']:>6.1f}s {totals['iterations']:>5} {'':>7} {'':>8} {totals['prompt_tokens']:>8} {totals['completion_tokens']:>6}\n")

if valid > 0:
    cold_avg = sum(totals["cold_iters"]) / len(totals["cold_iters"])
    cold_min = min(totals["cold_iters"])
    cold_max = max(totals["cold_iters"])
    warm_avg = sum(totals["warm_iters"]) / len(totals["warm_iters"]) if totals["warm_iters"] else 0
    decode_time = totals['completion_tokens'] / 43  # ~43 tok/s decode rate for Gemma 4 26B A4B
    prompt_time = totals['wall_clock'] - decode_time

    # Cache effectiveness heuristic: ratio of cold time saved if all dispatches were cold
    if len(totals["cold_iters"]) > 1:
        first_cold = totals["cold_iters"][0]
        subsequent_cold = totals["cold_iters"][1:]
        ideal_warm = warm_avg
        actual_subsequent_avg = sum(subsequent_cold) / len(subsequent_cold)
        # If subsequent colds match warm avg → 100% cache, if match first cold → 0% cache
        if first_cold > ideal_warm:
            cache_eff = max(0.0, min(1.0, (first_cold - actual_subsequent_avg) / (first_cold - ideal_warm)))
            print(f"Cold iteration analysis (across {len(totals['cold_iters'])} dispatches):")
            print(f"  First (always cold):      {first_cold:.1f}s")
            print(f"  Subsequent avg:           {actual_subsequent_avg:.1f}s")
            print(f"  Warm iter avg:            {warm_avg:.1f}s")
            print(f"  Cache effectiveness:      {cache_eff*100:.0f}% (1.0 = full reuse, 0.0 = always cold)\n")

    print(f"Performance breakdown:")
    print(f"  Decode time (gen @ 43 tok/s): {decode_time:.1f}s")
    print(f"  Prompt processing time:        {prompt_time:.1f}s ({prompt_time/totals['wall_clock']*100:.0f}% of total)")
    print(f"  Cold iter range:               {cold_min:.1f}s - {cold_max:.1f}s (avg {cold_avg:.1f}s)")
    print(f"  Warm iter avg:                 {warm_avg:.1f}s")
    print()
    print(f"Tool call breakdown: {totals['tools']}")
    print(f"Exit reasons: {totals['exit_reasons']}")

# Optional baseline comparison
baseline_path = os.environ.get('BASELINE_METRICS_FILE')
if baseline_path and os.path.isfile(baseline_path):
    base = json.load(open(baseline_path))
    print(f"\n=== Diff vs baseline ({baseline_path}) ===")
    delta_wall = totals['wall_clock'] - base.get('wall_clock', 0)
    delta_iters = totals['iterations'] - base.get('iterations', 0)
    delta_in = totals['prompt_tokens'] - base.get('prompt_tokens', 0)
    delta_out = totals['completion_tokens'] - base.get('completion_tokens', 0)
    sign = lambda x: f"+{x}" if x >= 0 else f"{x}"
    print(f"  Wall-clock:  {totals['wall_clock']:.1f}s ({sign(round(delta_wall, 1))}s vs {base.get('wall_clock', 0):.1f}s)")
    print(f"  Iterations:  {totals['iterations']} ({sign(delta_iters)})")
    print(f"  Tokens in:   {totals['prompt_tokens']} ({sign(delta_in)})")
    print(f"  Tokens out:  {totals['completion_tokens']} ({sign(delta_out)})")
PYEOF
