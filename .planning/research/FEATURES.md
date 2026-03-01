# Features Research

**Project:** FactoryGame (Love2D)
**Domain:** DevOps enforcement for Love2D ECS-based factory game
**Researched:** 2026-03-01
**Confidence:** MEDIUM

---

## Table Stakes (Must Have or Code Quality Degrades)

### Static Analysis
- **Global usage restriction** — deny undeclared globals; whitelist only `love`, `world`, `eventBus`, `registry` | Complexity: LOW
- **Consistent formatting** — stylua enforced on all Lua files | Complexity: LOW
- **Pre-commit hooks** — lint + format check before every commit | Complexity: LOW
- **CI hard block** — no merge if lint/format/test fails | Complexity: LOW

### Testing
- **Plugin isolation tests** — each plugin loads in a fresh ECS world with no other plugins; must pass | Complexity: MEDIUM
- **ECS world setup/teardown** — test lifecycle hooks for creating/destroying ECS worlds per test | Complexity: LOW
- **Event bus assertion helpers** — verify events fired/not fired during test scenarios | Complexity: MEDIUM

### Architectural Enforcement
- **Plugin registration API** — standard `plugin:init(ctx)` contract; `ctx = { world, bus, config, services }` | Complexity: MEDIUM
- **Event bus as only inter-plugin communication** — no direct `require` of other plugins | Complexity: MEDIUM
- **ECS-only game state** — all mutable game state in components, nowhere else | Complexity: MEDIUM
- **Server-authoritative rule** — no game logic on client thread | Complexity: MEDIUM

### Project Structure
- **Directory convention** — `src/plugins/<name>/`, `src/core/`, `src/client/`, `src/server/`, `spec/` | Complexity: LOW
- **CLAUDE.md with architectural rules** — AI generation context always includes enforcement rules | Complexity: LOW

---

## Differentiators (Competitive Advantage in Code Quality)

### Advanced Enforcement
- **Custom selene rules** — detect direct component mutation outside systems; detect cross-plugin requires | Complexity: HIGH
- **Architecture validator script** — CI runs `validate_architecture.lua` checking for globals, cross-plugin imports, client-side game logic | Complexity: MEDIUM
- **Canonical plugin example** — `examples/canonical_plugin.lua` maintained as reference; included in AI generation prompts | Complexity: LOW

### Testing Excellence
- **Architectural fitness tests** — automated tests verifying "system X communicates only via events" | Complexity: HIGH
- **Save/load roundtrip tests** — serialize ECS state, deserialize, verify all components intact | Complexity: MEDIUM
- **JIT-disabled CI matrix** — test run with `jit.off()` to catch Android-specific issues | Complexity: MEDIUM
- **Cross-version save migration tests** — load saves from N-2 versions; verify migrations work | Complexity: MEDIUM

### Performance Enforcement
- **Android benchmark in CI** — weekly performance regression check on mobile baseline | Complexity: HIGH
- **Draw call budget assertion** — test that rendering stays under draw call limit | Complexity: MEDIUM
- **Hot-path allocation guard** — lint rule or runtime check for table allocation in system update loops | Complexity: HIGH

### Development Workflow
- **Deferred-dispatch event bus** — events queued during handlers, flushed once per tick; prevents synchronous chains | Complexity: MEDIUM
- **Re-entrancy guard on event bus** — runtime error if `fire()` called inside a handler | Complexity: LOW
- **Schema versioned saves from day one** — migration runner before first save file exists | Complexity: MEDIUM

---

## Anti-Features (Things to Deliberately NOT Build)

| Anti-Feature | Reason |
|-------------|--------|
| Hot-reload system | Adds complexity; defeats static analysis; use fast restart instead |
| Dynamic plugin loading at runtime | Fixed plugin set at boot; dynamic loading creates untestable permutations |
| Custom scripting/modding API | Premature; adds massive attack surface for architectural violations |
| Visual ECS debugger | Use cimgui-love/Slab for debug; custom visualizer is scope creep |
| Automated code generation templates | CLAUDE.md + canonical examples are sufficient; codegen adds maintenance burden |

---

## Feature Dependencies

```
Static Analysis ──► Pre-commit hooks ──► CI hard block
       │
       ▼
Plugin registration API ──► Plugin isolation tests
       │                           │
       ▼                           ▼
Event bus implementation ──► Event bus assertion helpers
       │                           │
       ▼                           ▼
ECS-only game state ──► Architectural fitness tests
       │
       ▼
Save/load roundtrip tests ──► Schema versioned saves
```

---

*Features research complete: 2026-03-01*
