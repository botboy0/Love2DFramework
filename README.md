# Love2D Framework

A Love2D game engine framework with an ECS-first architecture and a plugin system.

**Tech stack:** Love2D, Lua, evolved.lua (ECS), busted (tests), selene (lint), stylua (format)

---

## Project Structure

```
src/
  core/      Shared infrastructure (event bus, plugin registry, ECS utilities)
  plugins/   Feature plugins — each a directory with init.lua
  client/    Client-only code (rendering, input, UI)
  server/    Server-only code (simulation tick, world gen)

lib/         Vendored third-party libraries (excluded from lint/format)
tests/       Mirrors src/ — every src/ .lua has a _spec.lua here
  helpers/   Shared test utilities (plugin_harness.lua)
assets/      Sprites, audio, data files
examples/    Reference implementations (canonical_plugin.lua)
scripts/     Developer tooling (validate_architecture.lua, full-check.sh)
```

---

## Dev Setup

### Prerequisites

- [Lua 5.1](https://www.lua.org/)
- [LuaRocks](https://luarocks.org/)
- [selene](https://github.com/Kampfkarren/selene) 0.27.1
- [stylua](https://github.com/JohnnyMorganz/StyLua) 0.20.0
- [busted](https://lunarmodules.github.io/busted/) (via LuaRocks)

```bash
luarocks install busted
```

### Activate pre-commit hook

```bash
git config core.hooksPath .githooks
```

This enables auto-format (stylua) and hard-block lint (selene) on every commit.

---

## Running checks

```bash
# Run all checks (mirrors CI exactly)
bash scripts/full-check.sh

# Individual steps
selene src/ main.lua conf.lua          # Lint
stylua --check src/ main.lua conf.lua  # Format check
busted                                  # Tests
lua scripts/validate_architecture.lua   # Architecture validation
```

---

## CI Pipeline

GitHub Actions runs on every push and pull request to `main`:

1. **Lint** — `selene src/ main.lua conf.lua`
2. **Format check** — `stylua --check src/ main.lua conf.lua`
3. **Tests** — `busted`
4. **Architecture validation** — `lua scripts/validate_architecture.lua`

See `.github/workflows/ci.yml` for the full pipeline definition.

---

## Adding a plugin

See `examples/canonical_plugin.lua` for the reference template. Read `CLAUDE.md` for architectural rules.
