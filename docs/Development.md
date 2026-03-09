# AI-Driven Development Workflow

## Purpose

This project uses a multi-AI workflow to turn ideas into reviewed, testable changes.

The goal is not full autonomy. The goal is a repeatable development loop where:

- work is planned as GitHub Issues
- implementation is done by a builder AI
- review is performed by an independent reviewer AI
- test and review results are fed back into the next planning step

GitHub Issues act as the persistent memory of the system.

## Roles

Each AI has a distinct responsibility.

| Role | Primary Tool | Responsibility |
| ---- | ------------ | -------------- |
| Planner | Antigravity | Analyze requests, break work into issues, propose next actions |
| Builder | Claude Code | Implement approved work and add or update tests |
| Reviewer | Cursor | Review diffs independently and identify risks, regressions, or missing coverage |
| Validator | Local tests + manual verification | Confirm the build, behavior, and logs are acceptable |

This separation reduces the risk of a single model planning, implementing, and approving its own output.

## Development Loop

```text
Idea or issue
  ->
Planning
  ->
Implementation
  ->
Testing
  ->
Independent review
  ->
Improvement analysis
  ->
Next issue or close
```

This workflow maps to a practical PDCA cycle:

| Phase | Owner | Main Output |
| ----- | ----- | ----------- |
| Plan | Antigravity | A scoped issue with acceptance criteria |
| Do | Claude Code | Code changes and related tests |
| Check | Tests + Cursor | Validation results and review findings |
| Act | Antigravity | Follow-up issue, reprioritization, or closure |

## Handoff Rules

Every phase must have a clear input and output.

| Phase | Input | Output | Done When |
| ----- | ----- | ------ | --------- |
| Planning | Idea, bug report, review finding, or previous issue | A GitHub Issue with scope, constraints, and success criteria | The issue is specific enough to implement without guessing |
| Implementation | An approved issue | A code diff and, when appropriate, tests or docs | The change matches the issue and builds cleanly |
| Testing | The implementation diff | Test results, log observations, and behavior notes | Regressions are checked and evidence is recorded |
| Review | Diff plus test evidence | Findings, risks, missing tests, and improvement suggestions | A go/no-go recommendation is possible |
| Improvement Analysis | Review findings and test results | A follow-up issue or a decision to close | The next action is explicit |

## Execution Rules

### 1. One issue, one clear outcome

Each implementation cycle should focus on one issue or one tightly related group of changes.

Avoid mixing:

- feature work and unrelated refactors
- behavior changes and speculative cleanup
- multiple independent improvements in one cycle

### 2. Human approval remains the gate

AI may propose issues, fixes, and follow-up work, but human approval should remain the final gate for:

- opening or prioritizing new work
- merging significant changes
- shipping releases
- accepting behavior changes with user-facing impact

### 3. Do not auto-loop on low-confidence findings

If test output, logs, or review findings are ambiguous, stop the loop and request clarification instead of generating more speculative issues.

### 4. Prefer updating an existing issue before creating a new one

When a review finding is a direct continuation of current work, append the evidence to the current issue unless a separate issue improves tracking.

## Issue Template Expectations

Every implementation-ready issue should answer these questions:

- What problem are we solving?
- Why does it matter now?
- What is in scope?
- What is explicitly out of scope?
- How will success be verified?
- What evidence or reproduction steps are available?

Minimal acceptance criteria should be concrete and testable.

## Testing And Validation

Testing is part of the loop, not an optional afterthought.

### Minimum validation for this project

Use the project-standard commands:

```bash
./build.sh
./build.sh --run
./build.sh --install
```

Use the lightest command that proves the change. Prefer `./build.sh` for build verification, and use `--run` or `--install` when behavior or integration needs confirmation.

Relevant runtime logs:

```text
~/Library/Logs/KeyLens/app.log
```

### What testing should cover

- regression detection
- algorithm correctness
- edge cases
- failure conditions
- performance-sensitive behavior when relevant

### When to create or update an issue from validation

Create or update an issue if validation reveals:

- a reproducible failure
- a measurable performance regression
- missing coverage for a risky code path
- unclear behavior that blocks release confidence

## Review Expectations

Independent review should prioritize:

- behavioral regressions
- architecture or maintainability risks
- missing tests
- hidden assumptions
- performance concerns

The review should produce actionable findings, not just a quality score.

## Guardrails

To keep the workflow useful and controlled:

- do not auto-create duplicate issues
- do not open follow-up issues without evidence
- do not treat speculative AI suggestions as confirmed defects
- do not close the loop until the next action is explicit

If multiple AIs disagree, the disagreement itself should be recorded as part of the issue history.

## Future Evolution

Possible extensions of this workflow include:

- AI-generated tests for edge cases and failure modes
- metric-driven performance checks
- better issue clustering and duplicate detection
- automatic draft issue generation from validated findings

These should be introduced gradually and only after the current loop is reliable.

## Current Stack

| Function | Current Tooling |
| -------- | --------------- |
| Planning | Antigravity |
| Implementation | Claude Code |
| Review | Cursor |
| Validation | Local build, tests, logs, and manual verification |

## Goal

The long-term goal is a self-improving development environment where AI can continuously assist with planning, implementation, review, and improvement, while GitHub Issues preserve project memory and humans retain final judgment.
