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

--- Create a stub test spec file with a pending placeholder.
--- Creates parent directories as needed.
--- @param spec_path string  Path to the spec file to create
--- @param module_name string  Module name for the describe block
--- @return boolean  true if created successfully
local function create_stub_spec(spec_path, module_name)
	local dir = spec_path:match("^(.+)/[^/]+$")
	if dir then
		os.execute('mkdir -p "' .. dir .. '"')
	end
	local f = io.open(spec_path, "w")
	if not f then
		return false
	end
	f:write('describe("' .. module_name .. '", function()\n')
	f:write('\tpending("TODO: add tests")\n')
	f:write("end)\n")
	f:close()
	return true
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
	-- Track curly-brace depth and block depth to avoid false positives.
	-- Real global assignments occur at brace_depth == 0 AND block_depth == 0.
	-- Inside table constructors ({...}), function bodies, if/for/while/do blocks,
	-- assignments are not top-level globals.
	-- This is a conservative heuristic — real linting is done by selene.
	local brace_depth = 0
	local block_depth = 0 -- counts ALL block-opening constructs (function, if, for, while, do, repeat)

	for i, line in ipairs(lines) do
		local stripped = line:match("^%s*(.-)%s*$")

		-- Skip blank lines and comment lines
		if stripped ~= "" and not stripped:match("^%-%-") then
			-- Capture depths at the START of this line.
			local depth_at_line_start = brace_depth
			local blk_depth_at_line_start = block_depth

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

			-- Update block depth: count ALL block-opening keywords.
			-- Openers: function ... end, if ... then ... end, for ... do ... end,
			--          while ... do ... end, do ... end, repeat ... until
			-- Closers: end, until (closes repeat)
			-- Note: `then` and `do` alone don't open a new block (they're part of
			-- the if/for/while opener that starts the block). We count the opening
			-- keyword (function, if, for, while, do-standalone, repeat).
			-- Heuristic: count `end` and `until` as closers; count block-opening patterns as openers.
			local opens = 0
			local closes = 0

			-- Count function openers (any `function` keyword on the line)
			-- Use gsub to count occurrences
			local _, fn_count = stripped:gsub("%f[%w_]function%f[^%w_]", "")
			opens = opens + fn_count

			-- Count if/for/while/repeat openers (standalone keywords starting a block)
			-- `if`, `for`, `while`, `repeat` each open a block closed by `end`/`until`
			local _, if_count = stripped:gsub("%f[%w_]if%f[^%w_]", "")
			local _, for_count = stripped:gsub("%f[%w_]for%f[^%w_]", "")
			local _, while_count = stripped:gsub("%f[%w_]while%f[^%w_]", "")
			local _, repeat_count = stripped:gsub("%f[%w_]repeat%f[^%w_]", "")
			opens = opens + if_count + for_count + while_count + repeat_count

			-- Standalone `do` (not `do` after for/while — those are part of the loop header)
			-- Detect `do` on its own or following non-for/while context. Simplified: count all `do`
			-- occurrences and subtract those that are part of for/while (their openers are already counted).
			-- Simplified approach: count `do` that appears standalone on a line (not after for/while content)
			local _, do_count = stripped:gsub("%f[%w_]do%f[^%w_]", "")
			-- Subtract `do` instances that are part of `for`/`while` headers (already counted above)
			-- For/while blocks: `do` closes the header but the block itself was opened by `for`/`while`.
			-- So we should NOT double-count. But `do` in `while x do` is not opening a NEW block —
			-- the `while` already counted it. Use simpler approach:
			-- Only count standalone `do` (line matches `^do%s*$` or `^do%-%-`) as extra block opener.
			do_count = 0 -- Reset: don't double-count do from for/while headers
			if stripped:match("^do%s*$") or stripped:match("^do%-%-") or stripped:match("^do%s+") then
				do_count = 1
			end
			opens = opens + do_count

			-- Count closers: `end` and `until`
			local _, end_count = stripped:gsub("%f[%w_]end%f[^%w_]", "")
			local _, until_count = stripped:gsub("%f[%w_]until%f[^%w_]", "")
			closes = closes + end_count + until_count

			block_depth = block_depth + opens - closes
			if block_depth < 0 then
				block_depth = 0
			end

			-- Only flag potential globals when NOT inside a table literal or any block.
			if depth_at_line_start == 0 and blk_depth_at_line_start == 0 then
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
-- Detection: undeclared service dependencies
-------------------------------------------------------------------------------

--- Parse the deps declaration from a plugin's init.lua lines.
--- Supports both single-line and multi-line declarations:
---   MyPlugin.deps = { 'dep1', 'dep2' }          -- single-line
---   MyPlugin.deps = {                             -- multi-line
---     'dep1',
---     'dep2',
---   }
--- Returns an array of declared dep names, or nil if no declaration found.
---
--- @param lines string[]  Lines from the plugin's init.lua
--- @return string[]|nil  Array of declared dep names, or nil if not parseable
local function parse_declared_deps(lines)
	for i, line in ipairs(lines) do
		-- Match: SomeName.deps = { ... (opening brace, may or may not close on same line)
		local after_brace = line:match("^%s*[%a_][%w_]*%.deps%s*=%s*{(.*)")
		if after_brace ~= nil then
			-- Check if the closing brace is on the same line
			local body = after_brace:match("^(.-)}")
			if body then
				-- Single-line: SomeName.deps = { 'a', 'b' }
				local deps = {}
				for name in body:gmatch("[\"']([%a_][%w_]*)[\"']") do
					deps[#deps + 1] = name
				end
				return deps
			else
				-- Multi-line: collect lines until closing brace
				local parts = { after_brace }
				for j = i + 1, #lines do
					local closing = lines[j]:match("^(.-)}")
					if closing then
						parts[#parts + 1] = closing
						break
					else
						parts[#parts + 1] = lines[j]
					end
				end
				local full_body = table.concat(parts, "\n")
				local deps = {}
				for name in full_body:gmatch("[\"']([%a_][%w_]*)[\"']") do
					deps[#deps + 1] = name
				end
				return deps
			end
		end
	end
	return nil
end

--- Detect services:get() calls in plugin files that reference services not declared in deps.
---
--- Reads init.lua in plugin_dir to parse the deps declaration, then scans ALL .lua files
--- under plugin_dir for services:get("X") calls where X is not in the declared deps.
---
--- @param plugin_dir string  Path to plugin directory (e.g. "src/plugins/movement")
--- @return table[], table[]  errors, dep_parse_errors
---   errors:           { file, line_num, line, service, message }
---   dep_parse_errors: { message } — structural problems with the deps declaration
function Validator.detect_undeclared_service_deps(plugin_dir)
	local errors = {}
	local dep_parse_errors = {}

	-- Read init.lua
	local init_path = plugin_dir .. "/init.lua"
	local init_lines = read_lines(init_path)
	if not init_lines then
		dep_parse_errors[#dep_parse_errors + 1] = {
			message = "init.lua not found -- cannot parse deps",
		}
		return errors, dep_parse_errors
	end

	-- Parse declared deps
	local declared_deps = parse_declared_deps(init_lines)
	if declared_deps == nil then
		dep_parse_errors[#dep_parse_errors + 1] = {
			message = "No parseable 'Module.deps = { ... }' declaration found",
		}
		return errors, dep_parse_errors
	end

	-- Build allowed lookup set
	local allowed = {}
	for _, dep in ipairs(declared_deps) do
		allowed[dep] = true
	end

	-- Scan all .lua files under plugin_dir for services:get() calls
	local plugin_files = find_lua_files(plugin_dir)
	for _, path in ipairs(plugin_files) do
		local lines = read_lines(path)
		if lines then
			for i, line in ipairs(lines) do
				-- Match services:get("X") or services:get('X') — case-insensitive on "services"
				local svc_name = line:match("[sS]ervices%s*:%s*get%s*%(%s*[\"']([%a_][%w_]*)[\"']")
				if svc_name and not allowed[svc_name] then
					errors[#errors + 1] = {
						file = path,
						line_num = i,
						line = line,
						service = svc_name,
						message = "services:get('" .. svc_name .. "') -- not declared in deps",
					}
				end
			end
		end
	end

	return errors, dep_parse_errors
end

-------------------------------------------------------------------------------
-- Report formatting
-------------------------------------------------------------------------------

--- Format a violation with verbose context: surrounding lines + rule reference.
--- @param file     string    File path
--- @param line_num number    1-based line number of the violation
--- @param lines    string[]  All file lines (used for context)
--- @param message  string    Violation message
--- @param rule_ref string|nil  Optional CLAUDE.md rule reference
--- @return string  Multi-line formatted string
local function format_verbose(file, line_num, lines, message, rule_ref)
	local parts = {}
	parts[#parts + 1] = file .. ":" .. line_num .. ": " .. message
	if rule_ref then
		parts[#parts + 1] = "  Rule: " .. rule_ref
	end
	-- Show line_num-1, line_num (marked), line_num+1
	for _, n in ipairs({ line_num - 1, line_num, line_num + 1 }) do
		if n >= 1 and n <= #lines then
			local marker = (n == line_num) and "  <--" or ""
			parts[#parts + 1] = "  > " .. n .. ":  " .. lines[n] .. marker
		end
	end
	return table.concat(parts, "\n")
end

--- Print a violation report section.
--- @param title      string
--- @param violations table[]
--- @param formatter  function(v) -> string
--- @param verbose    boolean|nil   If true, use verbose formatter
--- @param log_fn     function|nil  Output function (defaults to print)
local function print_section(title, violations, formatter, verbose, log_fn)
	if #violations == 0 then
		return
	end
	log_fn = log_fn or print
	log_fn("\n[" .. title .. "] " .. #violations .. " violation(s):")
	for _, v in ipairs(violations) do
		if verbose and v._verbose_str then
			log_fn(v._verbose_str)
		else
			log_fn("  " .. formatter(v))
		end
	end
end

--- Print a warning section (prefixed with [WARNING]).
--- @param title    string
--- @param warnings table[]
--- @param formatter function(v) -> string
--- @param verbose   boolean|nil
--- @param log_fn    function|nil  Output function (defaults to print)
local function print_warning_section(title, warnings, formatter, verbose, log_fn)
	if #warnings == 0 then
		return
	end
	log_fn = log_fn or print
	log_fn("\n[WARNING: " .. title .. "] " .. #warnings .. " warning(s):")
	for _, v in ipairs(warnings) do
		if verbose and v._verbose_str then
			log_fn(v._verbose_str)
		else
			log_fn("  " .. formatter(v))
		end
	end
end

-------------------------------------------------------------------------------
-- Main entry point
-------------------------------------------------------------------------------

--- Run all checks and return (error_count, warning_count).
--- @param opts table  { fix: boolean, log: function, verbose: boolean }
--- @return number, number  error_count, warning_count
function Validator.run(opts)
	opts = opts or {}
	local error_count = 0
	local warning_count = 0
	local verbose = opts.verbose or false
	local log_fn = opts.log or print

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
		local file_lines = verbose and read_lines(path) or nil
		local v = Validator.detect_globals(path, file_lines)
		for _, violation in ipairs(v) do
			violation.file = path
			if verbose and file_lines then
				violation._verbose_str = format_verbose(
					path,
					violation.line_num,
					file_lines,
					"global `" .. violation.name .. "`",
					'CLAUDE.md SS5 -- "No global mutable state outside the ECS world"'
				)
			end
			global_violations[#global_violations + 1] = violation
		end
	end
	print_section("Undeclared Globals", global_violations, function(v)
		return v.file .. ":" .. v.line_num .. ": global `" .. v.name .. "`"
	end, verbose, log_fn)
	error_count = error_count + #global_violations

	-- 2. Cross-plugin imports
	local import_violations = {}
	for _, path in ipairs(plugin_files) do
		local file_lines = verbose and read_lines(path) or nil
		local v = Validator.detect_cross_plugin_imports(path, file_lines)
		for _, violation in ipairs(v) do
			violation.file = path
			if verbose and file_lines then
				violation._verbose_str = format_verbose(
					path,
					violation.line_num,
					file_lines,
					"plugin `" .. violation.from_plugin .. "` imports `" .. violation.to_plugin .. "`",
					'CLAUDE.md SS4 -- "No plugin may access another plugin\'s internals"'
				)
			end
			import_violations[#import_violations + 1] = violation
		end
	end
	print_section("Cross-Plugin Imports", import_violations, function(v)
		return v.file .. ":" .. v.line_num .. ": plugin `" .. v.from_plugin .. "` imports `" .. v.to_plugin .. "`"
	end, verbose, log_fn)
	error_count = error_count + #import_violations

	-- 3. Game logic outside ECS systems
	local logic_violations = {}
	for _, path in ipairs(src_files) do
		local file_lines = verbose and read_lines(path) or nil
		local v = Validator.detect_logic_outside_ecs(path, file_lines)
		for _, violation in ipairs(v) do
			violation.file = path
			if verbose and file_lines then
				violation._verbose_str = format_verbose(
					path,
					violation.line_num,
					file_lines,
					violation.reason,
					'CLAUDE.md SS1 -- "All game logic MUST live in ECS systems"'
				)
			end
			logic_violations[#logic_violations + 1] = violation
		end
	end
	print_section("Game Logic Outside ECS", logic_violations, function(v)
		return v.file .. ":" .. v.line_num .. ": " .. v.reason
	end, verbose, log_fn)
	error_count = error_count + #logic_violations

	-- 4. Missing test files
	local missing_tests = Validator.detect_missing_tests(src_files)

	-- Auto-fix: create stub spec files when --fix is passed
	if opts.fix and #missing_tests > 0 then
		local fixed = 0
		for _, v in ipairs(missing_tests) do
			local module_name = v.src_file:match("([^/]+)%.lua$") or "module"
			if create_stub_spec(v.expected_test, module_name) then
				fixed = fixed + 1
			end
		end
		if fixed > 0 then
			log_fn("Fixed: created " .. fixed .. " missing test file(s)")
		end
		-- Re-detect after fix to get accurate remaining count
		missing_tests = Validator.detect_missing_tests(src_files)
	end

	print_section("Missing Test Files", missing_tests, function(v)
		return v.src_file .. " -> missing " .. v.expected_test
	end, verbose, log_fn)
	error_count = error_count + #missing_tests

	-- 5. Raw ECS calls in plugin files
	local ecs_errors = {}
	local ecs_warnings = {}
	for _, path in ipairs(plugin_files) do
		local file_lines = read_lines(path)
		local errs, warns = Validator.detect_raw_ecs_calls(path, file_lines)
		for _, e in ipairs(errs) do
			e.file = path
			if verbose and file_lines then
				e._verbose_str = format_verbose(
					path,
					e.line_num,
					file_lines,
					e.message,
					'CLAUDE.md SS1 -- "All game logic MUST live in ECS systems"'
				)
			end
			ecs_errors[#ecs_errors + 1] = e
		end
		for _, w in ipairs(warns) do
			w.file = path
			if verbose and file_lines then
				w._verbose_str = format_verbose(
					path,
					w.line_num,
					file_lines,
					w.message,
					'CLAUDE.md SS5 -- "No global mutable state outside the ECS world"'
				)
			end
			ecs_warnings[#ecs_warnings + 1] = w
		end
	end
	print_section("Raw ECS Calls", ecs_errors, function(v)
		return v.file .. ":" .. v.line_num .. ": " .. v.message
	end, verbose, log_fn)
	print_warning_section("ECS Require Warnings", ecs_warnings, function(v)
		return v.file .. ":" .. v.line_num .. ": " .. v.message
	end, verbose, log_fn)
	error_count = error_count + #ecs_errors
	warning_count = warning_count + #ecs_warnings

	-- 6. Undeclared service dependencies in plugin directories
	-- Collect unique plugin directories from plugin_files
	local plugin_dirs_seen = {}
	local plugin_dirs = {}
	for _, f in ipairs(plugin_files) do
		local plugin_dir = f:match("^(src/plugins/[^/]+)")
		if plugin_dir and not plugin_dirs_seen[plugin_dir] then
			plugin_dirs_seen[plugin_dir] = true
			plugin_dirs[#plugin_dirs + 1] = plugin_dir
		end
	end

	local svc_errors = {}
	local svc_dep_parse_errors = {}
	for _, plugin_dir in ipairs(plugin_dirs) do
		local errs, dep_errs = Validator.detect_undeclared_service_deps(plugin_dir)
		for _, e in ipairs(errs) do
			if verbose then
				local file_lines = read_lines(e.file)
				if file_lines then
					e._verbose_str = format_verbose(
						e.file,
						e.line_num,
						file_lines,
						e.message,
						'CLAUDE.md SS4 -- "No plugin may access another plugin\'s internals"'
					)
				end
			end
			svc_errors[#svc_errors + 1] = e
		end
		for _, de in ipairs(dep_errs) do
			de.plugin_dir = plugin_dir
			svc_dep_parse_errors[#svc_dep_parse_errors + 1] = de
		end
	end

	print_section("Undeclared Service Dependencies", svc_errors, function(v)
		return v.file .. ":" .. v.line_num .. ": " .. v.message
	end, verbose, log_fn)
	print_section("Missing deps Declaration", svc_dep_parse_errors, function(v)
		return (v.plugin_dir or "?") .. ": " .. v.message
	end, verbose, log_fn)
	error_count = error_count + #svc_errors
	error_count = error_count + #svc_dep_parse_errors

	return error_count, warning_count
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
	local verbose = false
	for _, a in ipairs(arg) do
		if a == "--fix" then
			fix = true
		elseif a == "--verbose" then
			verbose = true
		end
	end

	local errs, warns = Validator.run({ fix = fix, verbose = verbose })

	if warns and warns > 0 then
		print("(" .. warns .. " warning(s))")
	end

	if errs == 0 then
		print("Architecture check passed: no violations found.")
		os.exit(0)
	else
		print("\nArchitecture check FAILED: " .. errs .. " violation(s) found.")
		os.exit(1)
	end
end

return Validator
