# DaisyUI Portal & Overflow Patterns

Reference for handling dropdowns, tooltips, and interactive elements in constrained containers.

## The Problem

DaisyUI dropdowns rendered inside `overflow-x-auto` or `overflow-hidden` containers get clipped. This is common in DataTable rows that need action menus, or select fields inside scrollable areas.

## Solution: Portal-Based Dropdown

The shared `Dropdown` component (`src/domain/shared/ui/Dropdown.tsx`) supports portal rendering via `createPortal`:

```tsx
<Dropdown usePortal={true}> {/* default — renders to document.body */}
<Dropdown usePortal={false}> {/* inline — uses DaisyUI CSS positioning */}
```

### Portal Mode (default)
- Renders dropdown content to `document.body` via `createPortal`
- Uses fixed positioning with z-index 9999
- Auto-detects optimal position (top/bottom/start/center/end) based on viewport edges
- Handles click-outside and Escape key dismissal
- Recalculates position on scroll

### Inline Mode
- Uses DaisyUI CSS classes: `dropdown-top`, `dropdown-bottom`, `dropdown-start`, `dropdown-end`
- Only works when parent has no `overflow: hidden` or `overflow: auto`
- Simpler but limited

## When to Use Portal vs Inline

| Context | Use Portal | Why |
|---------|-----------|-----|
| Inside DataTable | Yes | Table has `overflow-x-auto` |
| Inside scrollable container | Yes | Content would be clipped |
| Inside modal/dialog | Yes | Stacking context issues |
| Standalone form field | Either | No overflow constraints |
| Simple nav menu | Inline | Simpler, no positioning calc |

## Dropdown Content Height

Fields constrain dropdown height to prevent viewport overflow:

| Component | Max Height | Class |
|-----------|-----------|-------|
| SearchableSelectField | 240px | `max-h-60 overflow-y-auto` |
| SearchableMultiselectField | 280px | `max-h-70 overflow-y-auto` |
| TreeviewMultiselectField | 320px | `max-h-80 overflow-y-auto` |
| DatePicker/DateRangePicker | Auto | `!min-w-fit` |

## Popover Pattern (Hover)

For hover-triggered overlays (e.g., rate plan info), use the `Popover` component:
- Always portal-based (no inline option)
- Configurable show/hide delay (default 200ms)
- Fixed positioning with scroll offset awareness
- Supports top/bottom/left/right placement

## DataTable + Dropdowns

DataTable uses `overflow-x-auto` for horizontal scroll. Interactive elements inside table rows:
- **Action menus** → Use `Dropdown` (portal mode is default, so they work automatically)
- **Tooltips** → Use DaisyUI `tooltip` class with responsive wrapper to hide when cell is not visible
- **Select fields** → SearchableSelectField already uses Dropdown with portal

## Common Pitfalls

1. **Setting `usePortal={false}` inside a scrollable container** → Dropdown gets clipped
2. **Forgetting `max-h-*` + `overflow-y-auto` on long option lists** → Dropdown extends beyond viewport
3. **Tooltip inside overflow-hidden** → Empty box appears; wrap tooltip container with responsive visibility class
4. **Z-index conflicts** → Portal uses 9999; modals typically use 50-100 via DaisyUI; no conflict as long as dropdowns close before modals animate
