---
name: aesthetic-direction
description: "Generate or verify the project's one-time AESTHETIC_DIRECTION.md — a design-language contract used by ux-brief and design-review. Invoked automatically by architect/craft when UI work is planned and .claude/aesthetic-direction.md does not yet exist. Auto-generates without blocking; user can refine the file later."
---

# Aesthetic Direction

Produce a one-time, project-level design-language contract at `.claude/aesthetic-direction.md`. All downstream UI work (ux-brief, design-review) reads this file as the source of truth for the project's visual system.

Write it **once per project**. Regenerate only when the design system meaningfully changes (new theme, new UI library, rebranding).

## When to invoke

Architect/craft/implement call this skill **only** when both are true:
1. The feature being planned includes UI components
2. `.claude/aesthetic-direction.md` does NOT exist

If the file exists, skip this skill and load the file as context.

## Input

No arguments needed. The skill reads the project directly.

## Process

### Step 1: Check dependencies

```bash
# Check if frontend-design skill is available
FD_AVAILABLE=$(find ~/.claude/plugins -type d -name "frontend-design" 2>/dev/null | head -1)
if [ -n "$FD_AVAILABLE" ]; then echo "FD_AVAILABLE"; else echo "FD_UNAVAILABLE"; fi
```

- `FD_AVAILABLE` → proceed with skill invocation (Step 2a)
- `FD_UNAVAILABLE` → fallback template generation (Step 2b)

### Step 2a: Invoke frontend-design skill (preferred path)

1. Read, in this order:
   - Project CLAUDE.md (parent + project-level)
   - `tailwind.config.*` if present, `postcss.config.*`
   - `src/**/globals.css` or equivalent theme file
   - 5-7 files from the project's shared UI directory (card, badge, button, select, modal, alert)
   - One reference feature page (pick a meaningful one — clients, dashboard, settings)

2. Invoke the `frontend-design:frontend-design` skill via the Skill tool. Ask it to produce an aesthetic direction document **constrained to the project's existing visual vocabulary**. Explicit constraints:
   - Do NOT invent new fonts, colors, or components
   - Do NOT propose visual reinvention
   - Describe what IS, then articulate the principles behind it

3. Structure the output (write to `.claude/aesthetic-direction.md`) using this template:

```markdown
# {Project Name} — Aesthetic Direction

> One-time design-language contract. Updated manually when the design system changes.
> Generated: {YYYY-MM-DD} by craft-skills:aesthetic-direction

## One-sentence north star
{What this product *feels* like in one sentence.}

## Reference atmosphere
{2-3 sentences capturing the tone: clinical-calm / editorial-dense / playful-minimal / etc.
Who the user is, what they expect visually.}

## Voice & tone
| Dimension | Direction |
|---|---|
| Voice | {editorial / conversational / instructional} |
| Warmth | {low / medium / high, with rationale} |
| Density | {high / medium / low} |
| Humor | {none / dry / warm} |
| Numbers | {how precision is conveyed — tabular, bold, inline} |
| Labels | {microcopy conventions} |

## Typography system (observed, not invented)
- **Primary:** {font family, source, when to use}
- **Body:** {font family, weights used}
- **Data/numerics:** {tabular-nums required y/n, mono font if applicable}

Name the exact fonts currently declared in the project. If none are declared, note "system fonts currently — direction should preserve this restraint or name a specific font to adopt."

## Color philosophy
- **Canvas/background:** {token + hex}
- **Ink/text:** {token + hex}
- **Primary accent:** {token + hex + when to use}
- **Semantic tokens:** {success / warning / error — usage rules}
- **What NOT to use:** {colors/tokens explicitly ruled out}

List tokens exactly as they appear in the project (e.g. `--color-primary`, `oklch(...)`, DaisyUI theme name).

## Density & spacing
- Padding rhythm: {e.g. "4-8-16-24", or specific to DaisyUI/Tailwind scale}
- Radii: {small/medium/large tokens with values}
- Card/container shape: {bordered / shadowed / flat}
- Motion budget: {animations allowed, durations, reduced-motion handling}

## What this direction RULES OUT
Explicit list. Prevents downstream agents from introducing:
- Specific fonts/colors that don't fit
- Patterns the project deliberately avoids (e.g., "no purple gradients," "no glassmorphism")
- Component libraries or utilities that would clash

## Signature elements (memorable)
1-3 visual signatures that, if lost, would change the product's identity. E.g., "teal primary + warm base-100," "small-caps section labels," "hairline dividers instead of cards."

## Accessibility baseline
- Minimum contrast ratio for this project
- Focus-visible convention
- Color-is-not-the-only-encoder rule
- Motion-reduce handling

## How to use this file
Downstream skills (`ux-brief`, `design-review`) read this file as input. When reviewing new UI work, they check the result against this direction. When proposing UI patches, they respect these rules.

If the design system meaningfully changes (new theme, new brand, new UI library), update this file manually — DO NOT regenerate from scratch without preserving intentional decisions.
```

4. Write the generated file. Report the path.

### Step 2b: Fallback template (frontend-design not installed)

If the skill is not available, generate a minimal direction by extracting observable facts from the codebase. No creative authorship — just document what is.

1. Read tailwind config / globals.css / CLAUDE.md / shared UI samples (same as Step 2a)
2. Populate the same template using only what you can observe:
   - Fonts declared in CSS
   - Colors defined as CSS custom properties
   - Radii and spacing scale
   - Components inventory
3. Add a note at the top: `> AUTO-GENERATED without frontend-design skill. Please refine voice/tone/signature sections manually.`
4. Write to `.claude/aesthetic-direction.md`

Quality will be lower but downstream skills still have a contract to read. User can refine later.

### Step 3: Non-blocking confirmation

Tell the user in one sentence:
> "Generated `.claude/aesthetic-direction.md` from {method: frontend-design skill | observed tokens}. Downstream UI work will use it as the design-language contract. Refine it anytime; changes stick."

Do NOT block on user approval — pipeline continues. User reviews asynchronously.

## Output

- File: `.claude/aesthetic-direction.md`
- Return: path of the written file + generation method (skill / fallback)

## Integration contract

Other skills that consume this file:
- `craft-skills:ux-brief` — reads it as context when drafting per-feature UX briefs
- `craft-skills:design-review` — uses it as the reference for regression and distinctiveness checks
- `craft-skills:simplify` — consults it during UI quality review

Architect / craft / implement / finalize invoke `aesthetic-direction` as a prerequisite when UI work is detected and the file is missing. They do NOT invoke it for features with no UI layer.
