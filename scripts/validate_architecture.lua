--- Architecture Validator
--- Scans the project for architectural violations:
---   1. Undeclared globals in src/ files
---   2. Cross-plugin imports (src/plugins/X requiring src/plugins/Y)
---   3. Game logic outside ECS systems (direct state in client/server entry files)
---   4. Missing test file mirrors (every src/ .lua must have a tests/ _spec.lua)
---
--- Usage:
---   lua scripts/validate_architecture.lua [--fix]
---
--- Exits 0 if no violations, 1 if violations found.

local Validator = {}

-- Globals whitelisted by love2d.yml selene std definition.
-- These are framework-provided or ECS context globals — not violations.
local ALLOWED_GLOBALS = {
	love = true,
	world = true,
	eventBus = true,
	registry = true,
}

-- Directories excluded from all checks.
local EXCLUDED_DIRS = { "lib" }

-------------------------------------------------------------------------------
-- File system helpers
-------------------------------------------------------------------------------

--- Check whether a path segment matches any excluded directory.
--- @param path string
--- @return boolean
local function is_excluded(path)
	for _, dir in ipairs(EXCLUDED_DIRS) do
		-- Match at path start or after a separator
		if path == dir or path:match("^" .. dir .. "/") or path:match("/" .. dir .. "/") then
			return true
		end
	end
	return false
end

--- Recursively collect .lua files under a directory using the `find` command.
--- @param dir string  Root directory to scan (relative to cwd)
--- @return string[]  List of file paths (relative)
local function find_lua_files(dir)
	local files = {}
	local handle = io.popen('find "' .. dir .. '" -name "*.lua" -type f 2>/dev/null | sort')
	if not handle then
		return files
	end
	for line in handle:lines() do
		if not is_excluded(line) then
			files[#files + 1] = line
		end
	end
	handle:close()
	return files
end

--- Check whether a file exists on disk.
--- @param path string
--- @return boolean
local function file_exists(path)
	local f = io.open(path, "r")
	if f then
		f:close()
		return true
	end
	return false
end

--- Read all lines of a file into a table.
--- @param path string
--- @return string[]|nil  Lines, or nil on error
local function read_lines(path)
	local f = io.open(path, "r")
	if not f then
		return nil
	end
	local lines = {}
	for line in f:lines() do
		lines[#lines + 1] = line
	end
	f:close()
	return lines
end

--- Extract the plugin name from a src/plugins/<name>/... path.
--- Returns nil if the path is not inside src/plugins/.
--- @param path string
--- @return string|nil
local function plugin_name_from_path(path)
	return path:match("^src/plugins/([^/]+)/")
end

-------------------------------------------------------------------------------
-- Detection: undeclared globals
-------------------------------------------------------------------------------

--- Detect lines in a file that assign to an undeclared global.
--- Conservative heuristic: match bare identifier assignments at line start
--- that are not `local` declarations and not whitelisted globals.
---
--- Pattern matched: optional whitespace, identifier, optional whitespace, `=`,
--- where the identifier is not preceded by `local` on the same line.
---
--- @param path string    File path to scan
--- @param lines string[] Pre-read lines (optional, reads file if nil)
--- @return table[]  List of { line_num: number, line: string, name: string }
function Validator.detect_globals(path, lines)
	if not lines then
		lines = read_lines(path)
		if not lines then
			return {}
		end
	end

	-- Keywords that cannot be global names
	local keywords = {
		["local"] = true,
		["function"] = true,
		["return"] = true,
		["if"] = true,
		["then"] = true,
		["else"] = true,
		["elseif"] = true,
		["end"] = true,
		["for"] = true,
		["while"] = true,
		["do"] = true,
		["repeat"] = true,
		["until"] = true,
		["break"] = true,
		["in"] = true,
		["not"] = true,
		["and"] = true,
		["or"] = true,
		["true"] = true,
		["false"] = true,
		["nil"] = true,
	}

	local violations = {}
	-- Track curly-brace depth and function depth to avoid false positives.
	-- Real global assignments occur at brace_depth == 0 AND function_depth == 0.
	-- Inside table constructors ({...}) or function bodies, assignments are locals.
	-- This is a conservative heuristic — real linting is done by selene.
	local brace_depth = 0
	local function_depth = 0

	for i, line in ipairs(lines) do
		local stripped = line:match("^%s*(.-)%s*$")

		-- Skip blank lines and comment lines
		if stripped ~= "" and not stripped:match("^%-%-") then
			-- Capture depths at the START of this line.
			local depth_at_line_start = brace_depth
			local fn_depth_at_line_start = function_depth

			-- Update brace depth by counting { and } on this line.
			for ch in stripped:gmatch(".") do
				if ch == "{" then
					brace_depth = brace_depth + 1
				elseif ch == "}" then
					if brace_depth > 0 then
						brace_depth = brace_depth - 1
					end
				end
			end

			-- Update function depth: function keyword opens, end closes (simplified).
			-- We count `function` and `end` keywords to track function nesting.
			-- This is imprecise for multiline constructs but sufficient for a heuristic.
			if
				stripped:match("^function%s+")
				or stripped:match("^local%s+function%s+")
				or stripped:match("%s+function%s*%(")
				or stripped:match("=%s*function%s*%(")
			then
				function_depth = function_depth + 1
			end
			if stripped:match("^end%s*$") or stripped == "end" or stripped:match("^end%-%-") then
				if function_depth > 0 then
					function_depth = function_depth - 1
				end
			end

			-- Only flag potential globals when NOT inside a table literal or function body.
			if depth_at_line_start == 0 and fn_depth_at_line_start == 0 then
				-- Look for: identifier = (not ==, ~=, <=, >=)
				local name = stripped:match("^([%a_][%w_]*)%s*=[^=]")
				if name and not keywords[name] and not ALLOWED_GLOBALS[name] then
					-- Additional filter: skip self-assignments like `x = x + 1` or `x = x or default`.
					-- These are always reassignments of an existing local or parameter, never a new global.
					local after_eq = stripped:match("^[%a_][%w_]*%s*=%s*(.+)$")
					local is_self_assignment = after_eq and after_eq:match("^" .. name .. "[^%w_]")
					if not is_self_assignment then
						violations[#violations + 1] = {
							line_num = i,
							line = line,
							name = name,
						}
					end
				end
			end
		end
	end
	return violations
end

-------------------------------------------------------------------------------
-- Detection: cross-plugin imports
-------------------------------------------------------------------------------

--- Detect require() calls in a plugin file that reference a different plugin.
--- Only flags requires that match `src.plugins.<other_plugin>` where
--- other_plugin differs from the owning plugin's name.
---
--- @param path string    File path (must be under src/plugins/<name>/)
--- @param lines string[] Pre-read lines (optional)
--- @return table[]  List of { line_num, line, from_plugin, to_plugin }
function Validator.detect_cross_plugin_imports(path, lines)
	local from_plugin = plugin_name_from_path(path)
	if not from_plugin then
		-- Not a plugin file — skip
		return {}
	end

	if not lines then
		lines = read_lines(path)
		if not lines then
			return {}
		end
	end

	local violations = {}
	for i, line in ipairs(lines) do
		-- Match require("src.plugins.<name>...") or require('src.plugins.<name>...')
		local to_plugin = line:match("[\"']src%.plugins%.([%a_][%w_]*)[%.\"']")
		if to_plugin and to_plugin ~= from_plugin then
			violations[#violations + 1] = {
				line_num = i,
				line = line,
				from_plugin = from_plugin,
				to_plugin = to_plugin,
			}
		end
	end
	return violations
end

-------------------------------------------------------------------------------
-- Detection: missing test files
-------------------------------------------------------------------------------

--- Detect src/ Lua files that have no corresponding tests/ _spec.lua mirror.
--- Mapping: src/<rest>.lua -> tests/<rest>_spec.lua
---
--- @param src_files string[]  List of src/ file paths to check
--- @return table[]  List of { src_file, expected_test }
function Validator.detect_missing_tests(src_files)
	local violations = {}
	for _, src_file in ipairs(src_files) do
		-- Map src/<rest>.lua -> tests/<rest>_spec.lua
		local rest = src_file:match("^src/(.+)%.lua$")
		if rest then
			local expected = "tests/" .. rest .. "_spec.lua"
			if not file_exists(expected) then
				violations[#violations + 1] = {
					src_file = src_file,
					expected_test = expected,
				}
			end
		end
	end
	return violations
end

-------------------------------------------------------------------------------
-- Detection: game logic outside ECS systems
-------------------------------------------------------------------------------

--- Detect patterns suggesting direct game-state manipulation outside ECS systems.
--- Checks src/client/ and src/server/ files for:
---   - love.update or love.draw containing logic beyond system delegation
---   - Direct entity creation patterns outside system files
---
--- This check is intentionally conservative to avoid false positives.
--- Flags only clear structural violations.
---
--- @param path  string    File path
--- @param lines string[]  Pre-read lines (optional)
--- @return table[]  List of { line_num, line, reason }
function Validator.detect_logic_outside_ecs(path, lines)
	-- Only check client and server entry files
	if not (path:match("^src/client/") or path:match("^src/server/")) then
		return {}
	end

	-- Skip system files — they are the correct location for game logic
	if path:match("/systems/") then
		return {}
	end

	if not lines then
		lines = read_lines(path)
		if not lines then
			return {}
		end
	end

	local violations = {}
	local in_love_callback = false
	local callback_name = nil
	local brace_depth = 0

	for i, line in ipairs(lines) do
		local stripped = line:match("^%s*(.-)%s*$")

		-- Detect love.update / love.draw function definitions
		local cb = stripped:match("^function%s+love%.(%a+)%s*%(")
		if cb == "update" or cb == "draw" then
			in_love_callback = true
			callback_name = cb
			brace_depth = 1
		elseif in_love_callback then
			-- Track end keywords to find the closing of the callback
			if stripped:match("^end%s*$") or stripped == "end" then
				brace_depth = brace_depth - 1
				if brace_depth <= 0 then
					in_love_callback = false
					callback_name = nil
				end
			elseif
				stripped:match("^if%s+")
				or stripped:match("^for%s+")
				or stripped:match("^while%s+")
				or stripped:match("^function%s+")
			then
				brace_depth = brace_depth + 1
			end

			-- Flag non-trivial game logic inside love.update/love.draw
			-- Conservative: only flag direct ECS world manipulation
			local has_world_access = stripped:match("world%s*:%s*%a+%(") or stripped:match("world%s*%.%s*%a+%(")
			if has_world_access then
				violations[#violations + 1] = {
					line_num = i,
					line = line,
					reason = "Direct ECS world access in love."
						.. (callback_name or "callback")
						.. " — delegate to a system",
				}
			end
		end
	end
	return violations
end

-------------------------------------------------------------------------------
-- Detection: raw ECS calls in plugin files
-------------------------------------------------------------------------------

--- Detect raw evolved.spawn() / evolved.id() calls in plugin files.
--- These violate PLUG-03 and PLUG-04 — plugins must use worlds:spawn_server()
--- or worlds:spawn_client() instead of raw evolved API.
---
--- Also warns (but does not error) on require("lib.evolved") in plugin files,
--- since that may be legitimate in rare cases but warrants review.
---
--- examples/ and non-plugin paths excluded by the ^src/plugins/ path guard.
---
--- @param path  string    File path to scan
--- @param lines string[]  Pre-read lines (optional, reads file if nil)
--- @return table[], table[]  errors, warnings
---   errors:   { line_num, line, kind, message }
---   warnings: { line_num, line, kind, message }
function Validator.detect_raw_ecs_calls(path, lines)
	-- examples/ and non-plugin paths excluded by this guard
	if not path:match("^src/plugins/") then
		return {}, {}
	end

	if not lines then
		lines = read_lines(path)
		if not lines then
			return {}, {}
		end
	end

	local errors = {}
	local warnings = {}

	for i, line in ipairs(lines) do
		local stripped = line:match("^%s*(.-)%s*$")

		-- Skip blank lines and comment lines
		if stripped ~= "" and not stripped:match("^%-%-") then
			-- Check for alias assignments: local <name> = evolved.spawn or evolved.id
			-- Flag ONLY the alias assignment line (not subsequent calls) to avoid false positives.
			local alias_target = stripped:match("^local%s+[%a_][%w_]*%s*=%s*(evolved%.[%a_][%w_]*)")
			if alias_target == "evolved.spawn" then
				errors[#errors + 1] = {
					line_num = i,
					line = line,
					kind = "alias",
					message = "evolved.spawn() alias -- use worlds:spawn_server() or worlds:spawn_client()",
				}
			elseif alias_target == "evolved.id" then
				errors[#errors + 1] = {
					line_num = i,
					line = line,
					kind = "alias",
					message = "evolved.id() alias -- use worlds:spawn_server() or worlds:spawn_client()",
				}
			end

			-- Check for direct evolved.spawn() calls
			if stripped:match("evolved%.spawn%s*%(") then
				errors[#errors + 1] = {
					line_num = i,
					line = line,
					kind = "direct",
					message = "evolved.spawn() -- use worlds:spawn_server() or worlds:spawn_client()",
				}
			-- Check for direct evolved.id() calls (only if not already caught by alias check)
			elseif stripped:match("evolved%.id%s*%(") then
				errors[#errors + 1] = {
					line_num = i,
					line = line,
					kind = "direct",
					message = "evolved.id() -- use worlds:spawn_server() or worlds:spawn_client()",
				}
			end

			-- Check for require("lib.evolved") — warning only, not error
			if stripped:match("[\"']lib%.evolved[\"']") then
				warnings[#warnings + 1] = {
					line_num = i,
					line = line,
					kind = "require",
					message = 'require("lib.evolved") in plugin -- consider using ctx.worlds for entity management',
				}
			end
		end
	end

	return errors, warnings
end

-------------------------------------------------------------------------------
-- Report formatting
-------------------------------------------------------------------------------

--- Print a violation report section.
--- @param title      string
--- @param violations table[]
--- @param formatter  function(v) -> string
local function print_section(title, violations, formatter)
	if #violations == 0 then
		return
	end
	print("\n[" .. title .. "] " .. #violations .. " violation(s):")
	for _, v in ipairs(violations) do
		print("  " .. formatter(v))
	end
end

-------------------------------------------------------------------------------
-- Main entry point
-------------------------------------------------------------------------------

--- Run all checks and return total violation count.
--- @param opts table  { fix: boolean, silent: boolean }
--- @return number  Total violation count
function Validator.run(opts)
	opts = opts or {}
	local total = 0

	if opts.fix then
		print("Note: --fix is not yet implemented. Reporting violations only.")
	end

	-- Collect src/ files
	local src_files = find_lua_files("src")

	-- Collect plugin files (subset of src/)
	local plugin_files = {}
	for _, f in ipairs(src_files) do
		if f:match("^src/plugins/") then
			plugin_files[#plugin_files + 1] = f
		end
	end

	-- 1. Undeclared globals in all src/ files
	local global_violations = {}
	for _, path in ipairs(src_files) do
		local v = Validator.detect_globals(path)
		for _, violation in ipairs(v) do
			violation.file = path
			global_violations[#global_violations + 1] = violation
		end
	end
	print_section("Undeclared Globals", global_violations, function(v)
		return v.file .. ":" .. v.line_num .. ": global `" .. v.name .. "`"
	end)
	total = total + #global_violations

	-- 2. Cross-plugin imports
	local import_violations = {}
	for _, path in ipairs(plugin_files) do
		local v = Validator.detect_cross_plugin_imports(path)
		for _, violation in ipairs(v) do
			violation.file = path
			import_violations[#import_violations + 1] = violation
		end
	end
	print_section("Cross-Plugin Imports", import_violations, function(v)
		return v.file .. ":" .. v.line_num .. ": plugin `" .. v.from_plugin .. "` imports `" .. v.to_plugin .. "`"
	end)
	total = total + #import_violations

	-- 3. Game logic outside ECS systems
	local logic_violations = {}
	for _, path in ipairs(src_files) do
		local v = Validator.detect_logic_outside_ecs(path)
		for _, violation in ipairs(v) do
			violation.file = path
			logic_violations[#logic_violations + 1] = violation
		end
	end
	print_section("Game Logic Outside ECS", logic_violations, function(v)
		return v.file .. ":" .. v.line_num .. ": " .. v.reason
	end)
	total = total + #logic_violations

	-- 4. Missing test files
	local missing_tests = Validator.detect_missing_tests(src_files)
	print_section("Missing Test Files", missing_tests, function(v)
		return v.src_file .. " -> missing " .. v.expected_test
	end)
	total = total + #missing_tests

	return total
end

-------------------------------------------------------------------------------
-- Script entry point
-- Run when called directly: lua scripts/validate_architecture.lua
-- Not run when required as a module.
-------------------------------------------------------------------------------

-- Detect whether this file is being run as a script (not required as a module).
-- We check arg[0] for the script name.
if arg and arg[0] and (arg[0]:match("validate_architecture") or arg[0]:match("validate%-architecture")) then
	local fix = false
	for _, a in ipairs(arg) do
		if a == "--fix" then
			fix = true
		end
	end

	local total = Validator.run({ fix = fix })

	if total == 0 then
		print("Architecture check passed: no violations found.")
		os.exit(0)
	else
		print("\nArchitecture check FAILED: " .. total .. " violation(s) found.")
		os.exit(1)
	end
end

return Validator
