local config = require("djortcuts.config")
local utils = require("djortcuts.utils")

local M = {}

local function try_load_overseer()
	local ok, overseer = pcall(require, "overseer")
	return ok and overseer
end

function M.is_available()
	return try_load_overseer() ~= nil
end

function M.setup(opts)
	opts = opts or {}

	local overseer = try_load_overseer()
	if not overseer then
		return
	end

	local fullscreen = opts.fullscreen or config.config.overseer_fullscreen

	if fullscreen then
		overseer.setup({
			task_list = {
				direction = "bottom",
				max_height = 0.9,
				max_width = 1.0,
			},
		})
	end
end

function M.toggle_overseer_fullscreen()
	vim.cmd("OverseerToggle bottom")
end

function M.run_command(command, opts)
	opts = opts or {}

	local overseer = try_load_overseer()
	if not overseer then
		vim.notify("overseer.nvim not available, falling back to legacy execution", vim.log.levels.WARN)
		return M.run_command_fallback(command, opts)
	end

	local django_root = config.config.django_root or utils.find_django_root()
	if not django_root then
		vim.notify("Error: Django project not found", vim.log.levels.ERROR)
		return false
	end

	local python_exec = utils.get_python_executable()
	local manage_py = django_root .. "/manage.py"

	if vim.fn.filereadable(manage_py) ~= 1 then
		vim.notify("Error: manage.py not found in " .. django_root, vim.log.levels.ERROR)
		return false
	end

	local is_test_command = opts.test or command:match("^%s*(%S+)") == "test"
	local settings_module = is_test_command and config.config.django_test_settings or config.config.django_settings
	local settings_arg = settings_module and (" --settings=" .. settings_module) or ""

	local full_command
	if config.config.venv_path then
		local venv_activate = config.config.venv_path .. "/bin/activate"
		if vim.fn.filereadable(venv_activate) == 1 then
			full_command = "source "
				.. venv_activate
				.. " && "
				.. python_exec
				.. " "
				.. manage_py
				.. " "
				.. command
				.. settings_arg
		else
			full_command = python_exec .. " " .. manage_py .. " " .. command .. settings_arg
		end
	else
		full_command = python_exec .. " " .. manage_py .. " " .. command .. settings_arg
	end

	local task_name = "Django: " .. command

	local task_opts = {
		name = task_name,
		cmd = full_command,
		cwd = django_root,
		components = {
			{ "on_output_quickfix", open = opts.open_quickfix or false },
			"default",
		},
	}

	local task = overseer.new_task(task_opts)

	if opts.on_start then
		task:subscribe("on_start", opts.on_start)
	end

	if opts.on_complete then
		task:subscribe("on_complete", opts.on_complete)
	end

	task:start()

	return true
end

function M.run_command_fallback(command, opts)
	opts = opts or {}

	local django_root = config.config.django_root or utils.find_django_root()
	if not django_root then
		vim.notify("Error: Django project not found", vim.log.levels.ERROR)
		return false
	end

	local python_exec = utils.get_python_executable()
	local manage_py = django_root .. "/manage.py"

	if vim.fn.filereadable(manage_py) ~= 1 then
		vim.notify("Error: manage.py not found in " .. django_root, vim.log.levels.ERROR)
		return false
	end

	local is_test_command = opts.test or command:match("^%s*(%S+)") == "test"
	local settings_module = is_test_command and config.config.django_test_settings or config.config.django_settings
	local settings_arg = settings_module and (" --settings=" .. settings_module) or ""

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

	vim.notify("Running (legacy): " .. command, vim.log.levels.INFO)

	local job_start_time = vim.fn.reltime()
	local current_output = {}

	local job_id = vim.fn.jobstart(full_command, {
		on_stdout = function(_, data)
			for _, line in ipairs(data) do
				if line and line ~= "" then
					table.insert(current_output, line)
				end
			end
		end,
		on_stderr = function(_, data)
			for _, line in ipairs(data) do
				if line and line ~= "" then
					table.insert(current_output, "[stderr] " .. line)
				end
			end
		end,
		on_exit = function(_, exit_code)
			local duration_ms = vim.fn.reltimefloat(vim.fn.reltime(job_start_time)) * 1000
			local exit_msg = exit_code == 0 and "completed successfully" or "failed with exit code " .. exit_code
			local log_level = exit_code == 0 and vim.log.levels.INFO or vim.log.levels.ERROR
			vim.notify(command .. " " .. exit_msg .. " (" .. string.format("%.0f", duration_ms) .. "ms)", log_level)
		end,
	})

	if job_id <= 0 then
		vim.notify("Error: Failed to start job", vim.log.levels.ERROR)
		return false
	end

	return true
end

function M.list_tasks()
	local overseer = try_load_overseer()
	if not overseer then
		return {}
	end

	return overseer.list_tasks()
end

return M
