---
name: browser-test
description: "Use when a feature has been built and needs browser-based UI testing. Plans test scenarios, groups them into parallel batches, and dispatches multiple browser-tester agents simultaneously."
---

# Browser Test

Plan and execute browser-based UI testing in parallel using multiple agents.

## Input

The user input is: `$ARGUMENTS`

- **Spec/plan path**: Use this to understand what was built and derive test scenarios
- **Empty**: Auto-detect the most recent spec from `.claude/plans/specs/` or plan from `.claude/plans/`

If no spec or plan is found, ask the user what feature to test.

## Step 1: Read Context

1. Read the spec/plan to understand what was built
2. Read relevant source files to understand the actual implementation (component locations, routes, UI structure)
3. Identify the app URL (default: `http://localhost:3000`)

## Step 2: Create Test Plan

Analyze the feature and group scenarios by independence:

**For each feature area, create test scenarios covering:**
- **Happy path**: Core functionality works as expected
- **Edge cases**: Empty states, loading states, error handling
- **Interactions**: Click, hover, expand/collapse, open/close
- **Visual verification**: Layout, text content matches spec

**Group into parallel batches** — different pages or scenarios that can each start from a fresh page load.

Present the test plan:

```
Test Plan: [Feature Name]

Batch 1 (Agent 1): [Description]
  - Scenario 1.1: ...
  - Scenario 1.2: ...

Batch 2 (Agent 2): [Description]
  - Scenario 2.1: ...
```

Wait for user approval. Max 4-5 parallel agents.

## Step 3: Dispatch Parallel Test Agents

Dispatch each batch as a separate agent (**haiku model**). Read the agent prompt template from the `tester-prompt.md` file in this skill's directory and provide it as context along with the batch's specific scenarios.

Launch all batches in parallel using the Agent tool.

**Why haiku:** Browser test agents perform simple, mechanical work — navigate to URL, click elements, verify text content. This doesn't require deep reasoning, and haiku's speed means faster test cycles.

## Step 4: Collect Results

Compile results from all batches:

```
Test Results: [Feature Name]

PASSED: X/Y scenarios
FAILED: Z/Y scenarios

Batch 1: [status]
  - Scenario 1.1: PASS
  - Scenario 1.2: FAIL - [reason]
```

If tests failed, analyze whether the failure is a bug or a test environment issue. Report with specific details.
