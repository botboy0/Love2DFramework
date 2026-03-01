# Phase 1: DevOps Foundation - Context

**Gathered:** 2026-03-01
**Status:** Ready for planning

<domain>
## Phase Boundary

Linting, formatting, testing, CI, and architectural enforcement rules in place before any game code. The project enforces its own architectural rules — no conforming commit can introduce ECS violations, global state, or cross-plugin coupling.

</domain>

<decisions>
## Implementation Decisions

### Project layout
- Flat `src/` with subdirs: `src/core/`, `src/plugins/`, `src/client/`, `src/server/`
- `lib/` at root for vendored third-party libraries (excluded from linting/formatting)
- `tests/` at root, mirrors `src/` structure — enforced by validator (every source file must have a corresponding `_spec.lua`)
- `assets/` at root for sprites, audio, data
- `conf.lua` and `main.lua` at project root
- Plugins are always directories with `init.lua` as entry point (no single-file plugins)

### Enforcement strictness
- **Tiered:** pre-commit runs lint (selene) + auto-format (stylua stages fixed files), CI runs full suite (lint + format check + tests + architecture validator)
- Full suite also runnable locally via script (not forced on every commit)
- Stylua auto-fixes and stages on pre-commit — no manual formatting step
- Branch protection on GitHub: CI hard-blocks merging on any failure, no bypass

### CLAUDE.md rules
- Architectural rules with code examples (do this / don't do this)
- File templates referenced, not inlined — points to canonical plugin example
- Naming conventions: snake_case for files/variables, PascalCase for classes
- Require path conventions: absolute paths (`src.core.bus`), no relative requires
- **Single source of truth** is a project-wide principle, not just docs — enforced in CLAUDE.md as a top-level rule
- Style enforcement delegated to selene/stylua (CLAUDE.md doesn't duplicate what tools enforce)

### Test conventions
- `_spec.lua` naming pattern (busted default, zero config discovery)
- Shared test harness (`tests/helpers/plugin_harness.lua`) that reads plugin dependency declarations and sets up isolated context (world, bus, registry + declared deps only)
- Plugins may depend on other plugins but must declare dependencies explicitly — undeclared dependencies are violations
- No coverage thresholds — file matching enforced, tests must be meaningful not metric-chasing

### Single source of truth (project-wide principle)
- Game state lives in ECS, nowhere else
- No duplicated state across plugins
- No duplicated rules/templates across files
- Only broken when technically impossible to implement otherwise

</decisions>

<specifics>
## Specific Ideas

- Previous attempt degraded without enforcement — this time devops comes first, no exceptions
- The canonical plugin example (`examples/canonical_plugin.lua`) is the single reference implementation — CLAUDE.md references it, doesn't duplicate it
- Tree mirroring (src → tests) must be actively enforced by validator/CI, not just a convention

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- Greenfield project — no existing code to reuse

### Established Patterns
- No patterns yet — Phase 1 establishes them

### Integration Points
- `conf.lua` and `main.lua` are Love2D entry points at project root
- `lib/` will contain vendored libraries (evolved.lua, etc.) from PROJECT.md library stack

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-devops-foundation*
*Context gathered: 2026-03-01*
