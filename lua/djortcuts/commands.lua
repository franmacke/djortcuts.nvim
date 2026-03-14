local config = require("djortcuts.config")
local utils = require("djortcuts.utils")
local logs = require("djortcuts.logs")
local floating = require("djortcuts.floating")
local overseer = require("djortcuts.overseer")

local M = {}

local current_output = {}
local job_start_time = nil
local current_command = nil

function M.run_django_terminal(command, opts)
	opts = opts or {}
	local django_root = config.config.django_root or utils.find_django_root()

	if not django_root then
		vim.notify("Error: Django project not found. Please run :DjangoInit first or navigate to a Django project directory.", vim.log.levels.ERROR)
		return
	end

	local use_overseer = config.config.use_overseer ~= false
	local overseer_available = overseer.is_available()

	if use_overseer and overseer_available then
		M.run_with_overseer(command, opts, django_root)
	else
		if use_overseer and not overseer_available then
			vim.notify("Using legacy execution: overseer not available", vim.log.levels.WARN)
		end
		M.run_with_jobstart(command, opts, django_root)
	end
end

function M.run_with_overseer(command, opts, django_root)
	local job_start_time = vim.fn.reltime()
	local current_output = {}

	vim.notify("Running: " .. command, vim.log.levels.INFO)

	local on_complete = function(task)
		local exit_code = task.code or 0
		local duration_ms = vim.fn.reltimefloat(vim.fn.reltime(job_start_time)) * 1000

		local full_command = "django manage.py " .. command

		logs.add({
			command = full_command,
			output = current_output,
			exit_code = exit_code,
			duration_ms = duration_ms,
		})

		local exit_msg = exit_code == 0 and "completed successfully" or "failed with exit code " .. exit_code
		local log_level = exit_code == 0 and vim.log.levels.INFO or vim.log.levels.ERROR
		vim.notify(command .. " " .. exit_msg .. " (" .. string.format("%.0f", duration_ms) .. "ms)", log_level)
	end

	overseer.run_command(command, {
		test = opts.test,
		on_output = function(line)
			if line and line ~= "" then
				table.insert(current_output, line)
			end
		end,
		on_complete = on_complete,
	})
end

function M.run_with_jobstart(command, opts, django_root)
	local python_exec = utils.get_python_executable()
	local manage_py = django_root .. "/manage.py"

	if vim.fn.filereadable(manage_py) ~= 1 then
		vim.notify("Error: manage.py not found in " .. django_root, vim.log.levels.ERROR)
		return
	end

	local is_test_command = false
	if opts.test then
		is_test_command = true
	else
		local first_word = command:match("^%s*(%S+)")
		if first_word == "test" then
			is_test_command = true
		end
	end

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

	current_output = {}
	job_start_time = vim.fn.reltime()
	current_command = full_command

	vim.notify("Running: " .. command, vim.log.levels.INFO)

	floating.open({ "Starting: " .. command .. "..." })

	local job_id = vim.fn.jobstart(full_command, {
		on_stdout = function(_, data)
			for _, line in ipairs(data) do
				if line and line ~= "" then
					table.insert(current_output, line)
					floating.update({ line })
				end
			end
		end,
		on_stderr = function(_, data)
			for _, line in ipairs(data) do
				if line and line ~= "" then
					table.insert(current_output, "[stderr] " .. line)
					floating.update({ "[stderr] " .. line })
				end
			end
		end,
		on_exit = function(_, exit_code)
			local duration_ms = vim.fn.reltimefloat(vim.fn.reltime(job_start_time)) * 1000
			local exit_msg = exit_code == 0 and "completed successfully" or "failed with exit code " .. exit_code

			logs.add({
				command = current_command,
				output = current_output,
				exit_code = exit_code,
				duration_ms = duration_ms,
			})

			local log_level = exit_code == 0 and vim.log.levels.INFO or vim.log.levels.ERROR
			vim.notify(command .. " " .. exit_msg .. " (" .. string.format("%.0f", duration_ms) .. "ms)", log_level)

			current_output = {}
			job_start_time = nil
			current_command = nil
		end,
	})

	if job_id <= 0 then
		vim.notify("Error: Failed to start job", vim.log.levels.ERROR)
		floating.close()
	end
end

return M
