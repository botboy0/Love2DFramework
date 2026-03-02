# Phase 2: Plugin Infrastructure - Research

**Researched:** 2026-03-02
**Domain:** Lua plugin isolation testing, static analysis / architecture validation, Love2D/evolved.lua plugin patterns
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Harness Strictness
- Hard error when a plugin calls `ctx.services:get("X")` without declaring "X" as a dependency (name-only check — no method validation)
- Respect `error_mode` config like Bus and Registry do (strict by default, tolerant available for integration tests)
- Keep explicit `harness.teardown(ctx)` calls — no auto-cleanup via busted hooks

#### Canonical Plugin Scope
- Add config usage demonstration (`ctx.config` read)
- No error handling demos — example stays a clean structural skeleton
- No fake dependency consumption — `deps = {}` stays empty
- Keep local component fragments (`evolved.id()` in example) — self-contained, no imports from `src/core/components.lua`
- **Drag-and-drop principle**: a developer should be able to drop the canonical plugin into their project, declare it in plugin_list, and it works — never crashes, warns at most

#### Validator Detection Rules
- Flag `evolved.spawn` and `evolved.id` including aliases (e.g., `local spawn = evolved.spawn`) — these are **errors** that fail CI
- Warn on `require("lib.evolved")` in plugin files — **warning** only, does not fail CI (plugins legitimately use `evolved.builder()` and `evolved.execute()`)
- `services:get()` cross-referencing: parse deps from a convention-enforced single-line declaration on the module table (`MyPlugin.deps = { "dep1", "dep2" }`). If the deps line isn't parseable, that itself is a violation
- Scan **all files** under a plugin directory for `services:get()` calls, not just init.lua

#### Validator Error Messages
- Default output: short message + actionable fix suggestion on one line (e.g., `evolved.spawn() — use worlds:spawn_server() or worlds:spawn_client()`)
- `--verbose` flag: adds CLAUDE.md rule reference and surrounding code context (3 lines around violation)
- Exit code 0 for warnings only, exit code 1 if any errors exist — warnings don't block CI

### Claude's Discretion
- Exact regex patterns for alias detection
- How to handle edge cases in single-line deps parsing (e.g., trailing comma, mixed quotes)
- Verbose output formatting details
- Test file organization within the phase

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| PLUG-01 | Plugin isolation test harness provides minimal ctx with declared dependencies only | Services proxy pattern; existing `plugin_harness.create_context` needs a guarded services wrapper that checks `opts.allowed_deps` before allowing `get()` |
| PLUG-02 | Canonical plugin example demonstrates component registration, system registration, and event handling | `examples/canonical_plugin.lua` already covers these; needs `ctx.config` read example added |
| PLUG-03 | Architecture validator flags raw `evolved.spawn()` calls in plugin files | New `Validator.detect_raw_ecs_calls` function following existing `detect_*` pattern; pattern matching `evolved%.spawn` and aliases |
| PLUG-04 | Architecture validator flags `evolved.id()` calls in plugin files | Same detection function as PLUG-03 — `evolved.id` is flagged alongside `evolved.spawn`; note: examples/ is excluded |
| PLUG-05 | Architecture validator cross-references `ctx.services:get()` against declared plugin deps | New `Validator.detect_undeclared_service_deps` function; parses `Module.deps = { ... }` from init.lua, scans all plugin files for `:get()` calls |
</phase_requirements>

---

## Summary

Phase 2 is a **tooling and enforcement phase** — no new runtime features are added. Three distinct units of work exist: (1) harden `plugin_harness.lua` so undeclared `services:get()` calls hard-error, (2) add `ctx.config` usage to `canonical_plugin.lua`, and (3) extend `validate_architecture.lua` with three new detection rules (raw ECS calls, ECS aliases, undeclared service deps).

All three units build on solid Phase 1 foundations. The plugin harness, context, registry, bus, and validator are already in place with established patterns: `resolve_error_mode()`, `detect_*` functions returning violation tables, the `Services` proxy in `context.lua`. Phase 2 only adds new detection logic and a proxy layer — no architectural rewrites.

The highest-complexity work is the validator's `services:get()` cross-reference (PLUG-05): it requires parsing a single-line `deps` declaration from init.lua, then scanning all files under the plugin directory for `:get("name")` calls, then cross-referencing. The regex patterns need to handle aliases (`local spawn = evolved.spawn`) correctly for PLUG-03/PLUG-04.

**Primary recommendation:** Implement in this order — PLUG-02 (trivial, establishes test baseline), PLUG-01 (harness dep enforcement), then PLUG-03+PLUG-04 together (shared detection function), then PLUG-05 (most complex, builds on pattern established by PLUG-03/04).

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| busted | ~2.2 | Test runner | Already configured in `.busted`; all Phase 1 specs use it |
| evolved.lua | vendored in `lib/` | ECS engine | Project's locked ECS; validator must detect misuse of its raw API |
| Lua 5.1/LuaJIT | system | Language runtime | Love2D target; `io.popen`, `io.open`, `string.match` used throughout |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| src.core.bus | local | Event bus | Harness creates real Bus instance for plugin testing |
| src.core.context | local | Context factory | Harness delegates to `Context.new()`; services proxy wraps the result |
| src.core.worlds | local | ECS worlds | Harness creates real Worlds instance |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Services proxy (metatable `__index` intercept) | Modify `Services:get()` directly | Direct modification couples harness logic into runtime; proxy keeps test-only enforcement test-side |
| Parsing `deps` via `load()`/`dofile()` | Regex on raw file text | `load()` would execute plugin code as a side effect; regex on the single-line convention is safer and sufficient |

**Installation:** No new packages — all tooling is existing Lua + busted.

---

## Architecture Patterns

### Recommended Project Structure

No new directories needed. All changes are modifications to existing files:

```
examples/
  canonical_plugin.lua     # ADD: ctx.config read demo
scripts/
  validate_architecture.lua  # ADD: detect_raw_ecs_calls, detect_undeclared_service_deps
tests/
  helpers/
    plugin_harness.lua       # ADD: services dep enforcement proxy
  helpers/
    plugin_harness_spec.lua  # NEW: tests for harness dep enforcement
  validate_architecture_spec.lua  # ADD: tests for new validator checks
  canonical_plugin_spec.lua  # ADD: test for ctx.config access
```

### Pattern 1: Services Dependency Proxy

**What:** Wrap `ctx.services` in a proxy table that intercepts `:get()` calls and errors if the requested name is not in an allowed-deps whitelist.
**When to use:** In `plugin_harness.create_context()` when the caller passes `opts.allowed_deps` (array of permitted service names).

```lua
-- Source: derived from existing plugin_harness.lua + context.lua patterns
local function make_dep_enforced_services(real_services, allowed_deps, error_mode)
    -- Build lookup set from allowed_deps array
    local allowed = {}
    for _, name in ipairs(allowed_deps or {}) do
        allowed[name] = true
    end

    -- Return a proxy that delegates all calls but guards :get()
    local proxy = {}
    setmetatable(proxy, {
        __index = function(_, key)
            if key == "get" then
                return function(_, name)
                    if not allowed[name] then
                        local msg = string.format(
                            "Plugin accessed undeclared service '%s' — add it to deps", name
                        )
                        if error_mode == "strict" then
                            error(msg, 2)
                        else
                            print("[Harness] " .. msg)
                            return real_services:get(name)
                        end
                    end
                    return real_services:get(name)
                end
            end
            -- Delegate everything else (register, etc.) transparently
            local v = real_services[key]
            if type(v) == "function" then
                return function(_, ...) return v(real_services, ...) end
            end
            return v
        end,
    })
    return proxy
end
```

**Integration point:** In `plugin_harness.create_context()`, after `Context.new()`, replace `ctx.services` with the proxy when `opts.allowed_deps` is provided.

### Pattern 2: Validator detect_* Function Convention

**What:** Every new validator check is a standalone `Validator.detect_*` function that takes `(path, lines)` and returns a table of violation records. Records include `line_num`, `line`, and check-specific fields.
**When to use:** For every new violation category — keeps checks independently testable.

```lua
-- Source: existing validate_architecture.lua pattern (detect_globals, detect_cross_plugin_imports)
--- Detect raw evolved.spawn / evolved.id calls in plugin files (errors) and
--- evolved require in plugin files (warnings).
--- @param path string
--- @param lines string[]
--- @return table[] violations, table[] warnings
function Validator.detect_raw_ecs_calls(path, lines)
    -- Only check plugin files
    if not path:match("^src/plugins/") then
        return {}, {}
    end
    if not lines then
        lines = read_lines(path)
        if not lines then return {}, {} end
    end

    local errors = {}
    local warnings = {}

    -- Track alias assignments: "local spawn = evolved.spawn" style
    local aliases = {}  -- alias_name -> true (means: this local IS evolved.spawn/id)

    for i, line in ipairs(lines) do
        local stripped = line:match("^%s*(.-)%s*$")
        if not stripped:match("^%-%-") then
            -- Detect alias assignment: local <name> = evolved.spawn or evolved.id
            local alias = stripped:match("^local%s+([%a_][%w_]*)%s*=%s*evolved%.spawn%s*$")
                       or stripped:match("^local%s+([%a_][%w_]*)%s*=%s*evolved%.id%s*$")
            if alias then
                aliases[alias] = true
                errors[#errors + 1] = {
                    line_num = i, line = line,
                    kind = "alias",
                    message = line:match("evolved%.[%a_]+") .. "() alias — use worlds:spawn_server() or worlds:spawn_client()",
                }
            end

            -- Detect direct call: evolved.spawn(...) or evolved.id(...)
            if stripped:match("evolved%.spawn%s*%(") or stripped:match("evolved%.id%s*%(") then
                local fn = stripped:match("evolved%.(spawn)") or stripped:match("evolved%.(id)")
                errors[#errors + 1] = {
                    line_num = i, line = line,
                    kind = "direct",
                    message = "evolved." .. (fn or "spawn") .. "() — use worlds:spawn_server() or worlds:spawn_client()",
                }
            end

            -- Detect alias invocation: spawn(...) where spawn was aliased
            for alias_name in pairs(aliases) do
                if stripped:match("^" .. alias_name .. "%s*%(")
                or stripped:match("[^%w_]" .. alias_name .. "%s*%(") then
                    errors[#errors + 1] = {
                        line_num = i, line = line,
                        kind = "alias_call",
                        message = alias_name .. "() (alias for evolved raw API) — use worlds:spawn_server() or worlds:spawn_client()",
                    }
                end
            end

            -- Warn on require("lib.evolved") in plugin files
            if stripped:match('["\']lib%.evolved["\']') then
                warnings[#warnings + 1] = {
                    line_num = i, line = line,
                    message = "require(\"lib.evolved\") in plugin — use ctx.worlds for entity management",
                }
            end
        end
    end

    return errors, warnings
end
```

### Pattern 3: Services Dep Cross-Reference in Validator

**What:** Parse `Module.deps = { ... }` from a plugin's init.lua using line regex. Then scan all files under the plugin directory for `:get("name")` calls. Cross-reference.

```lua
-- Source: project pattern + CONTEXT.md spec
--- Parse declared deps from a single-line Module.deps declaration.
--- Convention: exactly one line matching: <Identifier>.deps = { ... }
--- Returns array of dep names, or nil if not parseable (itself a violation).
--- @param lines string[]
--- @return string[]|nil
local function parse_declared_deps(lines)
    for _, line in ipairs(lines) do
        -- Match: <Identifier>.deps = { "a", "b", 'c' }
        local body = line:match("^%s*[%a_][%w_]*%.deps%s*=%s*{(.-)}")
        if body then
            local deps = {}
            -- Extract all quoted strings (single or double) from the body
            for name in body:gmatch('["\']([%a_][%w_]*)["\']') do
                deps[#deps + 1] = name
            end
            return deps
        end
    end
    return nil  -- no deps declaration found — violation
end

--- Detect services:get() calls that reference undeclared deps.
--- Scans ALL files under the plugin directory (not just init.lua).
--- @param plugin_dir string  e.g. "src/plugins/movement"
--- @return table[] errors, table[] dep_parse_errors
function Validator.detect_undeclared_service_deps(plugin_dir)
    local errors = {}

    -- Find and parse init.lua for declared deps
    local init_path = plugin_dir .. "/init.lua"
    local init_lines = read_lines(init_path)
    if not init_lines then
        return errors, {{ message = init_path .. " not found — cannot parse deps" }}
    end

    local declared = parse_declared_deps(init_lines)
    if declared == nil then
        -- Missing deps declaration is itself a violation
        return {}, {{ file = init_path, message = "No parseable 'Module.deps = { ... }' declaration found" }}
    end

    -- Build lookup set
    local allowed = {}
    for _, name in ipairs(declared) do allowed[name] = true end

    -- Scan all .lua files under the plugin directory
    local plugin_files = find_lua_files(plugin_dir)
    for _, path in ipairs(plugin_files) do
        local lines = read_lines(path)
        if lines then
            for i, line in ipairs(lines) do
                local stripped = line:match("^%s*(.-)%s*$")
                -- Match: services:get("name") or services:get('name')
                local svc_name = stripped:match('[sS]ervices%s*:%s*get%s*%(%s*["\']([%a_][%w_]*)["\']')
                if svc_name and not allowed[svc_name] then
                    errors[#errors + 1] = {
                        file = path, line_num = i, line = line,
                        service = svc_name,
                        message = "services:get('" .. svc_name .. "') — not declared in deps",
                    }
                end
            end
        end
    end

    return errors, {}
end
```

### Pattern 4: Verbose Flag in Validator.run

**What:** Add `--verbose` to the script entry point and thread it through `Validator.run(opts)`. In verbose mode, each violation printer includes the CLAUDE.md rule reference and ±3 surrounding lines.

```lua
-- In Validator.run(opts):
-- opts.verbose = true → format violations with context

local function format_verbose(file, line_num, lines, message, rule_ref)
    local result = { file .. ":" .. line_num .. ": " .. message }
    if rule_ref then
        result[#result + 1] = "  Rule: " .. rule_ref
    end
    -- Print 3 lines of context: line_num-1, line_num (marked), line_num+1
    for offset = -1, 1 do
        local n = line_num + offset
        if lines and lines[n] then
            local marker = offset == 0 and "  <--" or ""
            result[#result + 1] = string.format("  > %d:  %s%s", n, lines[n], marker)
        end
    end
    return table.concat(result, "\n")
end
```

### Anti-Patterns to Avoid

- **Modifying `Services:get()` in context.lua for test enforcement:** This couples test behavior into the runtime. Keep dep enforcement in the harness proxy only.
- **Auto-parsing deps via `load()` or `require()`:** Would execute plugin module-level code and create side effects (e.g., `evolved.id(2)` runs). Use regex on the raw file text.
- **Scanning only init.lua for `services:get()` calls:** CONTEXT.md requires scanning ALL files under the plugin directory — helper modules and system files can also call services.
- **Making warnings fail CI:** Exit code 0 for warnings-only is a locked decision. The validator exit logic must separate error count from warning count.
- **Modifying `examples/` to import from `src/core/components.lua`:** The canonical plugin is self-contained by design. Keep `evolved.id()` there; the validator must exclude `examples/` from the raw ECS call check.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Plugin dependency graph resolution | Custom resolver | Existing `Registry` topological sort (Phase 1) | Already battle-tested; harness just pre-registers services |
| Test doubles for Bus/Worlds/Context | Stub tables | Real instances from Phase 1 | Plugin harness explicitly uses real infrastructure; stubs would hide integration failures |
| File enumeration in validator | Custom walk | Existing `find_lua_files()` already in validate_architecture.lua | Handles excluded dirs, returns sorted list |
| Lua pattern escaping | Custom escaper | Lua's `string.gsub(s, "([%.%(%)%%%+%-%*%?%[%^%$])", "%%%1")` | Standard Lua idiom; needed when plugin dir path used in pattern |

**Key insight:** All three deliverables are extensions of existing Phase 1 code. The patterns, helpers, and infrastructure are in place — Phase 2 adds new detection rules and a proxy layer without structural rewrites.

---

## Common Pitfalls

### Pitfall 1: examples/ Excluded from Raw ECS Call Check

**What goes wrong:** `detect_raw_ecs_calls` flags `examples/canonical_plugin.lua` for its `evolved.id(2)` call, causing CI failures on a file that is intentionally self-contained.
**Why it happens:** The validator scans `src/` and `scripts/`, but `examples/` is not under `src/`. However, if the detection function is called directly on the examples path, or if a future scan expands to all .lua files, it will trigger.
**How to avoid:** The path guard in `detect_raw_ecs_calls` must check `^src/plugins/` — `examples/` does not match, so it is naturally excluded. Document this explicitly.
**Warning signs:** CI fails with `examples/canonical_plugin.lua:31: evolved.id()` in the error output.

### Pitfall 2: Alias Detection False Positives

**What goes wrong:** The pattern `local spawn = evolved.spawn` is detected, and then every subsequent `spawn(...)` call in the file — including legitimate non-ECS functions named `spawn` — is flagged.
**Why it happens:** Alias tracking is file-scoped but does not account for local variable shadowing or other `spawn` locals defined later.
**How to avoid:** Track alias detection conservatively: only flag the alias assignment line itself as an error (not subsequent calls), OR scope alias tracking to the function body (complex). Simplest safe approach: flag the alias assignment as the error, with message "evolved.spawn alias detected — remove alias and use worlds:spawn_server()".
**Warning signs:** Validator reports false positives on files that have local functions named `spawn` for non-ECS purposes.

### Pitfall 3: deps Parsing Misses Multi-line Declarations

**What goes wrong:** A plugin developer writes `MyPlugin.deps = {\n  "inventory",\n}` across multiple lines. The single-line regex finds no match, reports a "deps declaration not parseable" violation even though the declaration exists.
**Why it happens:** The locked decision specifies a **single-line** convention. Multi-line is intentionally not supported.
**How to avoid:** The violation message for a missing/unparseable deps line must say "deps must be declared on a single line: `MyPlugin.deps = { ... }`" so developers know the convention.
**Warning signs:** Developers with multi-line deps declarations getting confusing validator errors.

### Pitfall 4: services:get() Pattern Misses Non-Standard Spacing

**What goes wrong:** `ctx.services:get("foo")` is detected but `ctx.services : get( "foo" )` (unusual spacing) is not.
**Why it happens:** Lua pattern `services%s*:%s*get%s*%(%s*` handles spaces around `:`, `get`, and `(`, so most real-world cases are covered. Pathological spacing is unlikely in production code.
**How to avoid:** The provided pattern `[sS]ervices%s*:%s*get%s*%(%s*["\']([%a_][%w_]*)["\']` covers normal and minor spacing variants. Document that extreme spacing is not supported.
**Warning signs:** A service call is in a file but the validator does not flag it.

### Pitfall 5: Harness Proxy Breaks services:register()

**What goes wrong:** The proxy wrapper for services only overrides `:get()` but the `__index` implementation incorrectly shadows `:register()`, causing test setup (pre-registering stubs) to fail silently.
**Why it happens:** Metatable `__index` intercepts ALL key lookups if implemented naively.
**How to avoid:** The proxy `__index` must delegate all non-`get` methods to the underlying real_services object transparently. The code example above handles this via the `key ~= "get"` branch.
**Warning signs:** Tests fail with "Service 'X' is already registered" or "Service 'X' not found" when the test setup clearly registered X.

### Pitfall 6: Validator Exit Code Conflates Errors and Warnings

**What goes wrong:** `Validator.run()` returns a single `total` count mixing errors and warnings. CI fails on warnings (locked decision: warnings should not block CI).
**Why it happens:** The current `Validator.run()` returns one number. Adding warnings requires returning (or tracking) two counts.
**How to avoid:** `Validator.run()` must track `error_count` and `warning_count` separately. The script entry point checks `error_count > 0` for the exit code, not `error_count + warning_count > 0`.
**Warning signs:** `lua scripts/validate_architecture.lua` exits 1 when only `require("lib.evolved")` warnings are present.

---

## Code Examples

### Harness dep enforcement — full create_context signature

```lua
-- Source: plugin_harness.lua (to be modified)
-- opts.allowed_deps: string[] — names of services this plugin may call :get() on
-- opts.error_mode: "strict" (default) | "tolerant"
-- opts.deps: name->service table — services to pre-register (unchanged from Phase 1)

function plugin_harness.create_context(opts)
    opts = opts or {}
    local bus = Bus.new()
    local worlds = Worlds.create({ dual = true })
    local ctx = Context.new({ worlds = worlds, bus = bus, config = opts.config or {} })

    -- Pre-register provided services (unchanged)
    if opts.deps then
        -- ... existing dep-registration logic ...
    end

    -- Install dep enforcement proxy if allowed_deps is specified
    if opts.allowed_deps then
        local error_mode = opts.error_mode or "strict"
        ctx.services = make_dep_enforced_services(ctx.services, opts.allowed_deps, error_mode)
    end

    return ctx
end
```

### Test: harness blocks undeclared service access

```lua
-- Source: to be written in tests/helpers/plugin_harness_spec.lua
it("errors when plugin accesses undeclared service", function()
    local ctx = harness.create_context({ allowed_deps = { "inventory" } })
    ctx.services:register("inventory", { stub = true })
    ctx.services:register("crafting", { stub = true })

    -- Access declared dep — should succeed
    assert.has_no_error(function()
        ctx.services:get("inventory")
    end)

    -- Access undeclared dep — should hard error
    assert.has_error(function()
        ctx.services:get("crafting")
    end)
end)
```

### Validator verbose output format (locked spec from CONTEXT.md)

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

### Canonical plugin config usage addition

```lua
-- Source: examples/canonical_plugin.lua (to be modified — add after bus/worlds store)
function CanonicalPlugin:init(ctx)
    self.bus = ctx.bus
    self.worlds = ctx.worlds

    -- 0. Config access — read framework/game configuration values.
    -- ctx.config is the plain table passed through Context.new().
    -- Games set values in _config in main.lua or override via conf.lua.
    local _tick_rate = ctx.config.tick_rate or 60  -- unused in example; demonstrates pattern

    -- ... rest of init unchanged ...
end
```

### Validator run() with separate error/warning counts

```lua
-- Source: validate_architecture.lua (to be modified)
function Validator.run(opts)
    opts = opts or {}
    local error_count = 0
    local warning_count = 0

    -- ... existing checks add to error_count ...

    -- New check: raw ECS calls (errors + warnings)
    for _, path in ipairs(plugin_files) do
        local lines = read_lines(path)
        local errs, warns = Validator.detect_raw_ecs_calls(path, lines)
        for _, v in ipairs(errs) do
            v.file = path
            error_count = error_count + 1
            -- print ...
        end
        for _, v in ipairs(warns) do
            v.file = path
            warning_count = warning_count + 1
            -- print ...
        end
    end

    -- New check: undeclared service deps (errors only)
    -- ... grouped by plugin_dir ...

    return error_count, warning_count
end

-- Script entry point
local errs, _warns = Validator.run({ verbose = verbose })
if errs == 0 then
    print("Architecture check passed.")
    os.exit(0)
else
    print("Architecture check FAILED: " .. errs .. " error(s).")
    os.exit(1)
end
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Harness accepts string-array deps (stubs only) | Harness accepts name->service table OR string array (dual format support) | Phase 1 (01-01) | Phase 2 must add dep enforcement on top of the current dual-format logic |
| Validator returns single total count | Validator must return (error_count, warning_count) | Phase 2 | Callers of `Validator.run()` must handle the updated return signature; existing test `assert.equals(0, total)` must be updated |
| No raw ECS call detection | Validator detects `evolved.spawn`, `evolved.id`, aliases | Phase 2 (new) | CI will block plugins using raw ECS API |

**Deprecated/outdated:**
- Single return value from `Validator.run()`: The existing `assert.equals(0, total, ...)` test in `validate_architecture_spec.lua` will need updating to `local errs, _ = Validator.run(...)` once the return signature changes. The existing integration smoke test must remain passing.

---

## Open Questions

1. **Alias detection scope: should alias calls be flagged separately from the assignment?**
   - What we know: CONTEXT.md says "flag `evolved.spawn` and `evolved.id` including aliases" — the assignment IS an error
   - What's unclear: whether each downstream call of the alias variable should also be reported as a separate violation
   - Recommendation: Flag only the alias assignment line. The assignment itself is the error (violates the "don't use raw ECS API" rule). Flagging every use is verbose and harder to implement without scope tracking. One error per alias assignment is sufficient to guide the fix.

2. **How to collect all files under a plugin directory in detect_undeclared_service_deps**
   - What we know: `find_lua_files(dir)` already exists in the validator and accepts any directory
   - What's unclear: whether it handles being called with a plugin subdirectory (e.g., `src/plugins/movement`) vs. the full `src/` scan
   - Recommendation: `find_lua_files` is path-agnostic — pass `plugin_dir` directly. This is a LOW risk; verify with a manual call during implementation.

3. **examples/ exclusion from detect_raw_ecs_calls — explicit guard or path convention?**
   - What we know: `examples/` is not under `src/plugins/`, so the `^src/plugins/` guard naturally excludes it
   - What's unclear: If the validator ever gains a broader scan (e.g., scanning `examples/` for other checks), the guard would need updating
   - Recommendation: Add an explicit comment in `detect_raw_ecs_calls` noting that examples/ is intentionally excluded and why. The path guard is sufficient for Phase 2.

---

## Sources

### Primary (HIGH confidence)

- Direct file read: `examples/canonical_plugin.lua` — current state, what config addition needs to land
- Direct file read: `tests/helpers/plugin_harness.lua` — current state, dual-format dep registration pattern
- Direct file read: `scripts/validate_architecture.lua` — current state, `detect_*` function pattern, `find_lua_files`, `read_lines`
- Direct file read: `src/core/context.lua` — Services class, `resolve_error_mode`, proxy target
- Direct file read: `src/core/registry.lua` — `resolve_error_mode` pattern used in Bus/Registry/Context
- Direct file read: `.planning/phases/02-plugin-infrastructure/02-CONTEXT.md` — locked decisions
- Direct file read: `.planning/REQUIREMENTS.md` — PLUG-01 through PLUG-05 definitions
- Direct file read: `tests/validate_architecture_spec.lua` — existing test patterns, temp file helpers

### Secondary (MEDIUM confidence)

- Lua 5.1 reference manual (training knowledge, verified against existing codebase usage) — `string.match`, `string.gmatch`, `io.open`, `io.popen`, metatable `__index`

### Tertiary (LOW confidence)

None — all critical claims are grounded in the project's own source files.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — confirmed from existing project files, no new external dependencies
- Architecture patterns: HIGH — all patterns derived from existing Phase 1 code in the repository
- Pitfalls: HIGH — derived from explicit CONTEXT.md decisions and direct code inspection of the files being modified

**Research date:** 2026-03-02
**Valid until:** 2026-04-02 (stable internal tooling; no external dependencies that could change)
