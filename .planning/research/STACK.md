# Stack Research

**Project:** FactoryGame (Love2D)
**Domain:** Love2D factory/survival game with devops-first enforcement
**Researched:** 2026-03-01
**Confidence:** MEDIUM — based on training knowledge, verified where possible

---

## Recommended Stack

### Linting & Static Analysis

| Tool | Recommendation | Confidence |
|------|---------------|------------|
| **selene** | PRIMARY — Rust-based, actively maintained, custom TOML std definitions for architectural enforcement | HIGH |
| luacheck | AVOID — largely unmaintained, cannot enforce ECS/event-bus custom rules | HIGH |
| **stylua** | ONLY CHOICE — lua-fmt is abandoned, stylua has won the Lua formatting space | HIGH |

**Why selene over luacheck:** selene supports custom `std` definitions via TOML/YAML files. This enables declaring `world`, `eventBus`, `registry`, and `love` as the only valid globals — any other global access becomes a lint error. luacheck has similar global restriction but lacks the extensibility for architectural rules.

### Testing

| Tool | Recommendation | Confidence |
|------|---------------|------------|
| **busted** | PRIMARY — `before_each`/`after_each` lifecycle + spy/stub system required for plugin isolation tests | HIGH |
| luaunit | AVOID — lacks lifecycle hooks needed for ECS world setup/teardown | MEDIUM |
| love-test | AVOID — requires running Love2D instance, incompatible with headless CI | HIGH |

### CI/CD

| Tool | Recommendation | Confidence |
|------|---------------|------------|
| **GitHub Actions** | Standard CI platform; `love-actions` family for Love2D builds | HIGH |
| **Pre-commit hooks** | lefthook or husky-equivalent for Lua; run selene + stylua on staged files | MEDIUM |

**Pipeline:** lint job → test job → build job (with `needs: [lint, test]` as hard block)

### Game Libraries (Starting Point)

| Category | Library | Status | Confidence |
|----------|---------|--------|------------|
| ECS | evolved.lua | Carried forward, validated | HIGH |
| Networking | Raw ENet (built-in) | + love.thread channels | HIGH |
| Serialization (net) | bitser | Fast binary; verify Lua 5.1 no-JIT path on Android | MEDIUM |
| Serialization (save) | binser | Pure Lua, no JIT needed | HIGH |
| Tilemap | STI | Tiled loader; use for metadata only, NOT for infinite world rendering | HIGH |
| Input | baton | KB/gamepad/touch unification | MEDIUM |
| Camera | gamera | Or custom minimal | MEDIUM |
| Collision | slick | Polygon/circle/AABB with slide | MEDIUM |
| Spatial queries | shash | Broad-phase proximity | MEDIUM |
| Math/Utilities | batteries | Replaces lume, hump, knife, cpml | MEDIUM |
| Texture Atlas | Runtime-TextureAtlas | Pack sprites at startup | MEDIUM |
| Resolution | Push | Fixed internal res scaling | HIGH |
| Tweening | Flux | Animations, UI transitions | MEDIUM |
| Profiling | AppleCake | Perfetto visualization | MEDIUM |
| Async Loading | Lily | Threaded asset loading | MEDIUM |
| UI (debug) | Slab or cimgui-love | Dev tools | LOW |
| UI (game) | Custom | Inventory, HUD | HIGH |

### Dependency Management

- **Game libraries:** vendor under `lib/` — no package manager for game deps
- **Dev tools:** binary downloads for selene, stylua; luarocks for busted
- **Rationale:** Love2D has no standard package manager; vendoring gives full control

### Explicitly Avoided

| Library | Reason |
|---------|--------|
| sock.lua, grease, love-ws | Dead/wrong protocol |
| trickle, moonblob | Archived by authors |
| SUIT | Abandoned since 2015 |
| autobatch | Love 0.10.x only |
| cargo | Fragile magic-table approach |
| CPML | Overkill for 2D; use batteries.vec2 |
| lua-fmt | Abandoned; use stylua |

### Critical Risk

**bitser on Android:** bitser may use JIT-specific optimizations. Must verify the Lua 5.1 interpreted path works correctly on Android Love2D early in development. If it fails, replace with pure-Lua MessagePack or custom `string.pack`/`string.unpack`.

---

*Stack research complete: 2026-03-01*
