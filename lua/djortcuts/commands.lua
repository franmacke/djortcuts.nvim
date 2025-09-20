local config = require("djortcuts.config")
local utils = require("djortcuts.utils")

local M = {}

function M.run_django_terminal(command, opts)
	opts = opts or {}
	local django_root = config.config.django_root or utils.find_django_root()

	if not django_root then
		print(
			"Error: Django project not found. Please run :DjangoInit first or navigate to a Django project directory."
		)
		return
	end

	local python_exec = utils.get_python_executable()
	local manage_py = django_root .. "/manage.py"

	if vim.fn.filereadable(manage_py) ~= 1 then
		print("Error: manage.py not found in " .. django_root)
		return
	end

	-- Usar settings de test si se solicita explícitamente o si el comando es 'test'
	local is_test_command = false
	if opts.test then
		is_test_command = true
	else
		local first_word = command:match("^%s*(%S+)")
		if first_word == "test" then
			is_test_command = true
		end
	end

	-- Usar settings normales o de test según el tipo de comando
	local settings_module = is_test_command and config.config.django_test_settings or config.config.django_settings
	local settings_arg = settings_module and (" --settings=" .. settings_module) or ""

	-- Build the full command
	local full_command
	if config.config.venv_path then
		local venv_activate = config.config.venv_path .. "/bin/activate"
		if vim.fn.filereadable(venv_activate) == 1 then
			full_command = "cd "
				.. django_root
				.. " && source "
				.. venv_activate
				.. " && "
				.. python_exec
				.. " manage.py "
				.. command
				.. settings_arg
		else
			full_command = "cd " .. django_root .. " && " .. python_exec .. " manage.py " .. command .. settings_arg
		end
	else
		full_command = "cd " .. django_root .. " && " .. python_exec .. " manage.py " .. command .. settings_arg
	end

	print("Running command: " .. full_command)

	vim.cmd(config.config.terminal_cmd)
	vim.cmd("terminal " .. full_command)
	vim.cmd("stopinsert")
end

return M
