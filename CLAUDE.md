# CLAUDE.md

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

## Project: e-medrese (Flutter)

- Layers: `lib/core`, `lib/data`, `lib/domain`, `lib/presentation`, `lib/services`. Keep new code in the matching layer.
- State: Riverpod. Routing: go_router. Storage: hive_ce. Backend: Supabase (push: Firebase Messaging). Use these; don't add alternatives.
- Before adding a package, check `pubspec.yaml` for one that already does the job.
- UI: one page = one purpose. Every feature (except feeds) gets its own page; no menus, dialogs or tabs that bundle several features.
- Verify with `flutter analyze` and `flutter test`.
- After each completed change: commit with a short message and push to `origin main`.
- Versioning: every user-facing change bumps `version:` in `pubspec.yaml` (`x.y.z+build`, semver) in the same commit, and adds a line to `CHANGELOG.md`. `z`: bug fix / small tweak with no new feature. `y`: new feature, backward compatible (reset `z`). `x`: breaking change — old app versions stop working with the backend, data/migration that needs a fresh install, or a major redesign (reset `y`, `z`). Always increment `+build` by 1. Refactors, tests and docs alone don't bump.
