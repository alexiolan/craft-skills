---
name: reuse-index
description: "Generate or refresh .claude/reuse-index.md — a one-page inventory of the project's shared utilities, enums, hooks, and components that downstream implementer agents must consult before writing new code. Project-agnostic scan: no framework assumptions baked in. Invoke once per project (or when the shared surface changes meaningfully)."
---

# Reuse Index

Produce a project-level `.claude/reuse-index.md` listing the maintained inventory of shared utilities, enums, hooks, components, service primitives, and HTTP clients. Downstream skills (`architect`, `develop`, `simplify`, `implementer-prompt.md`, `llm-implement.sh`) read this file and treat every entry as a mandatory-consideration before specifying or writing any new util/type/helper.

Mirrors the pattern of `aesthetic-direction`: one-time generation, project-agnostic process, project-specific output.

## When to invoke

- **First-time per project** — no `.claude/reuse-index.md` exists yet
- **When the shared surface changes meaningfully** — a new category of shared primitive is added, or a refactor moves shared code. Regenerate rather than manually edit for safety.
- **Invoked automatically by other craft skills** when they detect the file is missing and the feature being planned would clearly benefit (optional; each calling skill decides).

If the file exists and was regenerated recently (last 30 days, or user preference), skip with a note.

## Input

- `$ARGUMENTS` — optional. Accepted forms:
  - Empty → auto-detect the project's shared directory (see Step 1)
  - Path like `src/domain/shared` or `src/shared` → use that as the scan root
  - `--force` → regenerate even if `.claude/reuse-index.md` exists

## Process

### Step 1: Detect the project's shared directory

Try these in order; accept the first that exists and is non-empty:

```bash
candidates=(
  "src/domain/shared"
  "src/shared"
  "src/common"
  "src/lib"
  "app/shared"
  "lib/shared"
  "packages/shared"
  "packages/ui"
  "src/utils"
)
```

If none match, prompt the user: *"I couldn't auto-detect this project's shared directory. Where do your shared utilities live? (examples: `src/shared`, `packages/ui`). Enter a path or `skip`."*

If the user skips, write a stub reuse-index that says *"No shared directory detected. Edit this file manually to list your project's reusable primitives."* and exit.

### Step 2: Scan the shared tree (graph-first)

Prefer `semantic_search_nodes_tool` + `query_graph_tool` with `file_summary` on each top-level shared directory. Fall back to Glob + Read if the graph is unavailable.

Extract, per file:
- **Named exports** — function, class, const, enum, type
- **Default export** (if any) — usually a React/Vue component
- **Short purpose** — infer from the file name + top-level JSDoc or the first non-import line

Do NOT read implementation bodies — only signatures. Keep it concise.

### Step 3: Categorize

Bin entries into categories by path or heuristic:

| Category | Path hints |
|---|---|
| **UI primitives** | `**/ui/**`, `**/components/**` |
| **Hooks** | `**/hooks/**`, `use*.ts(x)` |
| **Utilities** | `**/utils/**`, `**/lib/**`, `**/helpers/**` |
| **Enums & labels** | `**/enums/**`, `**/constants/**` |
| **Services / HTTP** | `**/infrastructure/**`, `**/services/**`, `**/data/**`, `**/network/**`, `**/api/**` |
| **Query / mutation factories** | `**/queries/**`, `*Queries.ts`, `*Mutations.ts`, `createQuery*`, `createMutation*` |
| **Forms** | `**/forms/**`, `**/fields/**` |
| **Notifications / toasts / errors** | `**/notifications/**`, `toast*`, `error*` |
| **Types / models** | `**/models/**`, `**/types/**` |

Categories absent from the project are simply omitted.

### Step 4: Write the index

Write to `.claude/reuse-index.md` using this template. Keep it under ~400 lines; trim the longest categories if needed (note at top that full list is in source).

```markdown
# {Project Name} — Reuse Index

> One-page inventory of the project's maintained reusable primitives.
> Downstream craft-skills agents MUST consult this file before writing any
> new util, type, helper, or label map.
>
> Generated: {YYYY-MM-DD} by craft-skills:reuse-index
> Regenerate when the shared surface changes meaningfully.

## How to read this file

Each entry lists: `ExportName` — import path — one-line purpose.

If your task requires something from these categories, reuse what's listed here instead of writing a parallel implementation. If nothing here fits, document the gap in your plan's Prior-Art Scan table before introducing a new primitive.

---

## UI primitives
- `Button` — `@/domain/shared/ui/Button` — DaisyUI-styled primary/ghost button
- `Modal` — `@/domain/shared/ui/Modal` — Headless UI dialog wrapper
- ...

## Hooks
- `useDrawer` — `@/domain/shared/hooks/useDrawer` — right-/left-side overlay drawer with escape + overlay close
- `useModal` — `@/domain/shared/hooks/useModal` — modal open/close state + mount helper
- ...

## Utilities
- `formatDate`, `formatTimeDistance`, `formatTimeOfDay` — `@/domain/shared/utils/date` — **ALL date/time formatting goes here, including relative-time strings**
- `cn` — `@/domain/shared/utils/styles` — Tailwind class merging
- ...

## Enums & labels
- `ContentProvider`, `contentProviderLabels`, `parseContentProvider` — `@/domain/shared/data/enums/contentProvider` — provider enum + label map + wire-format parser
- ...

## Services / HTTP
- `apiService` — `@/domain/network/data/infrastructure/apiService` — HTTP client instances (inventoryHttp, identityHttp, localHttp)
- ...

## Query / mutation factories
- `createQueryHook`, `createQueryByIdHook`, `createRequiredQueryHook` — `@/domain/shared/data/queries/createQueryHook` — **ALL useQuery hooks must go through these**
- `createMutationHook`, `createMutationWithIdHook` — `@/domain/shared/data/queries/createMutationHook`
- ...

## Notifications / toasts / errors
- `notificationService` — `@/domain/shared/data/infrastructure/notificationService` — **ALL toasts go through this**
- `handleError` — `@/domain/shared/utils/handleError` — centralized error handler
- ...

## Types / models
- ...

---

## What NOT to duplicate

If you find yourself about to write any of the following, STOP and reuse instead:
- A new relative-time helper → `formatTimeDistance` exists
- A new toast call → `notificationService.toast()` exists
- A new string-to-enum parser for an existing enum → check `parseContentProvider` pattern
- A new icon wrapper → `Icon` exists; do not import `lucide-react` directly
- A new drawer/modal shell → `useDrawer` / `Modal` exist
- A new date format → `formatDate(..., DateFormats.X)` exists

Add to this list whenever you catch a duplication in review — this file is the living contract.

## Regeneration

Run `craft-skills:reuse-index --force` to regenerate from scratch. Keep any hand-authored "What NOT to duplicate" entries you've added — the regeneration should merge, not overwrite.
```

### Step 5: Non-blocking report

Tell the user in one sentence:
> "Generated `.claude/reuse-index.md` scanning `<shared-dir>` — <N> entries across <M> categories. Downstream craft-skills will consult it. Refine anytime; changes stick."

Do NOT block on user approval. The pipeline continues immediately.

## Output

- File: `.claude/reuse-index.md`
- Return: path of the written file, scan root used, entry count

## Integration contract

Other skills that consume this file:
- `craft-skills:architect` / `craft-skills:craft` — cite it in plan's Prior-Art Scan table
- `craft-skills:develop` — loaded by `llm-implement.sh` into every Gemma dispatch's SYSTEM_PROMPT; `implementer-prompt.md` tells Claude agents to consult it
- `craft-skills:simplify` — reads it during the reuse check

A project without this file still works — every consumer gracefully degrades to grep-based search. The file just makes reuse discipline cheap and reliable.

## Fallbacks

| Condition | Behavior |
|---|---|
| Project has no obvious shared directory | Ask user; if they skip, write a stub with instructions for manual editing |
| Graph unavailable | Fall back to Glob + Read for signature extraction |
| Scan produces >200 entries | Keep the top 150 most-imported (use `importers_of` counts) and note that the full list is in source |
| `--force` flag absent AND file exists AND mtime <30 days | Skip and report: "Index is recent; use `--force` to regenerate" |
