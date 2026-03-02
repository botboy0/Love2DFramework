---
plan: 2
title: "Implement validate_architecture --fix for missing test files"
tasks: 2
---

## Task 1: Implement --fix for missing test files

**Files:** `scripts/validate_architecture.lua`

**Action:**
- Remove the "not yet implemented" note at lines 619-621
- After detecting missing tests in `Validator.run()` (around line 707-711), add logic to create stub test files when `opts.fix` is true:
  - For each missing test, create the parent directories using `os.execute("mkdir -p ...")`
  - Write the stub content to the expected test path with this template:
    ```lua
    describe("<module_name>", function()
    	pending("TODO: add tests")
    end)
    ```
  - Extract module name from the path (e.g., `src/plugins/movement/init.lua` → `movement`, `src/core/bus.lua` → `core.bus`)
- Track the count of created files and report: "Fixed: created N missing test file(s)"
- This should execute after `print_section()` for missing tests, still inside `Validator.run()`

**Verify:**
```bash
# Create a temp src file without a spec, then run:
lua scripts/validate_architecture.lua --fix
# Should output "Fixed: created 1 missing test file(s)"
# Verify the stub file was created with correct content
```

**Done:** `--fix` flag creates missing test stubs with proper directory structure and pending test placeholder

---

## Task 2: Add tests for --fix behavior

**Files:** `tests/validate_architecture_spec.lua`

**Action:**
- Add a new test suite `describe("Validator.run with --fix", function()` after the existing `Validator.run` tests (after line 547)
- Add a test that:
  1. Creates a temp src file at a path without a corresponding spec (e.g., `src/plugins/testfix/init.lua`)
  2. Calls `Validator.run({ fix = true, silent = true })`
  3. Verifies the stub spec file was created at the expected path (`tests/plugins/testfix/init_spec.lua`)
  4. Reads the created file and verifies it contains the pending test placeholder
  5. Cleans up temp files
- Use the existing helper functions: `write_temp()`, `remove_dir()` for setup/teardown
- Add `before_each` and `after_each` hooks to manage `/tmp/arch_test_fix` directory

**Verify:**
```bash
busted tests/validate_architecture_spec.lua
# All tests including new --fix behavior tests should pass
```

**Done:** `--fix` behavior is tested and verified to create correct stub files with proper Lua syntax
