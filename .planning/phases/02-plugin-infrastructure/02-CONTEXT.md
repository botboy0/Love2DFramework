# Phase 2: Plugin Infrastructure - Context

**Gathered:** 2026-03-02
**Status:** Ready for planning

<domain>
## Phase Boundary

Codify the canonical plugin pattern, harden the test harness for dependency isolation, and extend the architecture validator to catch raw ECS calls and undeclared service dependencies. Makes the Phase 1 core contract enforceable. No new runtime features — this phase is about tooling and enforcement.

</domain>

<decisions>
## Implementation Decisions

### Harness Strictness
- Hard error when a plugin calls `ctx.services:get("X")` without declaring "X" as a dependency (name-only check — no method validation)
- Respect `error_mode` config like Bus and Registry do (strict by default, tolerant available for integration tests)
- Keep explicit `harness.teardown(ctx)` calls — no auto-cleanup via busted hooks

### Canonical Plugin Scope
- Add config usage demonstration (`ctx.config` read)
- No error handling demos — example stays a clean structural skeleton
- No fake dependency consumption — `deps = {}` stays empty
- Keep local component fragments (`evolved.id()` in example) — self-contained, no imports from `src/core/components.lua`
- **Drag-and-drop principle**: a developer should be able to drop the canonical plugin into their project, declare it in plugin_list, and it works — never crashes, warns at most

### Validator Detection Rules
- Flag `evolved.spawn` and `evolved.id` including aliases (e.g., `local spawn = evolved.spawn`) — these are **errors** that fail CI
- Warn on `require("lib.evolved")` in plugin files — **warning** only, does not fail CI (plugins legitimately use `evolved.builder()` and `evolved.execute()`)
- `services:get()` cross-referencing: parse deps from a convention-enforced single-line declaration on the module table (`MyPlugin.deps = { "dep1", "dep2" }`). If the deps line isn't parseable, that itself is a violation
- Scan **all files** under a plugin directory for `services:get()` calls, not just init.lua

### Validator Error Messages
- Default output: short message + actionable fix suggestion on one line (e.g., `evolved.spawn() — use worlds:spawn_server() or worlds:spawn_client()`)
- `--verbose` flag: adds CLAUDE.md rule reference and surrounding code context (3 lines around violation)
- Exit code 0 for warnings only, exit code 1 if any errors exist — warnings don't block CI

### Claude's Discretion
- Exact regex patterns for alias detection
- How to handle edge cases in single-line deps parsing (e.g., trailing comma, mixed quotes)
- Verbose output formatting details
- Test file organization within the phase

</decisions>

<specifics>
## Specific Ideas

- Canonical plugin should feel "drag-and-drop ready" — drop it in, declare it, it runs. No crashes, graceful degradation with logger warnings at most.
- Validator verbosity example:
  ```
  # Default
  src/plugins/movement/init.lua:8: evolved.spawn() — use worlds:spawn_server() or worlds:spawn_client()

  # --verbose
  src/plugins/movement/init.lua:8: evolved.spawn() — use worlds:spawn_server() or worlds:spawn_client()
    Rule: CLAUDE.md §1 — "All game logic MUST live in ECS systems"
    > 7:  function MovementPlugin:init(ctx)
    > 8:    local e = evolved.spawn()  <--
    > 9:    evolved.set(e, Position, {x=0, y=0})
  ```

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `examples/canonical_plugin.lua`: Already demonstrates init, components, queries, events, services, shutdown — needs config usage added
- `tests/helpers/plugin_harness.lua`: Creates isolated ctx with real Bus/Worlds/Context — needs dep enforcement hardened
- `scripts/validate_architecture.lua`: Has 4 checks (globals, cross-plugin imports, missing tests, logic outside ECS) — needs spawn/id/services checks added

### Established Patterns
- `error_mode` resolution: Bus, Registry, and Context all use `resolve_error_mode(config, module_name, fallback)` — harness should follow this pattern
- Registry dep declaration: `registry:register("name", Module, { deps = { "dep1" } })` — plugin-side deps mirror this as `Module.deps = { "dep1" }`
- Validator structure: each check is a `Validator.detect_*` function returning `{ line_num, line, ... }` violations — new checks follow this pattern

### Integration Points
- `plugin_harness.create_context(opts)`: Add dep enforcement via a services proxy that checks against declared deps
- `Validator.run(opts)`: Add new detection functions for spawn/id/services, integrate `--verbose` flag into opts
- `canonical_plugin.lua`: Add `ctx.config` usage example

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 02-plugin-infrastructure*
*Context gathered: 2026-03-02*
