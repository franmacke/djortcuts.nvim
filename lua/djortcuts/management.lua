local config = require("djortcuts.config")
local utils = require("djortcuts.utils")

local M = {}

function M.parse_command_help(command)
	local django_root = config.config.django_root or utils.find_django_root()
	if not django_root then
		return { flags = {}, positional = {}, errors = { "Django project not found" } }
	end

	local python_exec = utils.get_python_executable()
	local manage_py = django_root .. "/manage.py"

	if vim.fn.filereadable(manage_py) ~= 1 then
		return { flags = {}, positional = {}, errors = { "manage.py not found" } }
	end

	local cmd = string.format("cd %s && %s manage.py %s --help", django_root, python_exec, command)
	local raw_output = vim.fn.system(cmd)

	if vim.v.shell_error ~= 0 then
		return { flags = {}, positional = {}, errors = { "Error executing command" } }
	end

	local lines = {}
	for line in raw_output:gmatch("[^\n]+") do
		table.insert(lines, line)
	end

	local flags = {}
	local positional = {}
	local errors = {}

	-- Analizar cada línea del help
	for _, line in ipairs(lines) do
		line = vim.trim(line)

		-- Buscar flags con valor (--name NAME, --file FILE, etc.)
		local flag_with_value = line:match("^%-%-([%w%-]+)%s+([A-Z_]+)")
		if flag_with_value then
			table.insert(flags, {
				type = "with_value",
				flag = "--" .. flag_with_value,
				placeholder = flag_with_value:upper(),
				description = line:gsub("^%-%-[%w%-]+%s+[A-Z_]+%s*", ""),
				used = false
			})
		end

		-- Buscar flags sin valor (--skip-verification, --force, etc.)
		local flag_without_value = line:match("^%-%-([%w%-]+)$")
		if flag_with_value == nil and flag_without_value then
			table.insert(flags, {
				type = "without_value",
				flag = "--" .. flag_without_value,
				description = line:gsub("^%-%-[%w%-]+%s*", ""),
				used = false
			})
		end

		-- Buscar argumentos posicionales (positional arguments)
		if line:match("^positional arguments:") or line:match("^arguments:") then
			-- Los argumentos posicionales suelen estar en las siguientes líneas
			-- Buscar patrones como "csv_file", "input_file", etc.
			for i = 1, 5 do -- Buscar en las siguientes 5 líneas
				local next_line_idx = _ + i
				if next_line_idx <= #lines then
					local next_line = vim.trim(lines[next_line_idx])
					local pos_arg = next_line:match("^([%w_]+)")
					if pos_arg and not next_line:match("^%-%-") then
						table.insert(positional, {
							name = pos_arg,
							description = next_line:gsub("^[%w_]+%s*", ""),
							used = false
						})
					end
				end
			end
		end
	end

	-- Si no encontramos argumentos específicos, agregar opciones comunes
	if #flags == 0 and #positional == 0 then
		table.insert(flags, {
			type = "without_value",
			flag = "--help",
			description = "Show help message",
			used = false
		})
		table.insert(flags, {
			type = "without_value",
			flag = "--version",
			description = "Show version",
			used = false
		})
	end

	return { flags = flags, positional = positional, errors = errors }
end

return M
