local config = require("djortcuts.config")

local M = {}

function M.find_django_root()
	local current_dir = vim.fn.getcwd()
	print("Current directory: " .. current_dir)

	local subdirs = vim.fn.glob(current_dir .. "/*/", false, true)
	for _, subdir in ipairs(subdirs) do
		subdir = subdir:gsub("/$", "")
		local subdir_manage_py = subdir .. "/manage.py"
		if vim.fn.filereadable(subdir_manage_py) == 1 then
			print("Found Django project in: " .. subdir)
			return subdir
		end
	end

	print("No Django project found in subdirectories")
	return nil
end

function M.find_venv()
	local current_dir = vim.fn.getcwd()
	local dir = current_dir

	while dir ~= "/" and dir ~= "" do
		local venv_dirs = { "venv", ".venv", "env", ".env", "virtualenv" }
		for _, venv_dir in ipairs(venv_dirs) do
			local venv_path = dir .. "/" .. venv_dir
			local bin_path = venv_path .. "/bin/python"
			local scripts_path = venv_path .. "/Scripts/python.exe"

			if vim.fn.filereadable(bin_path) == 1 or vim.fn.filereadable(scripts_path) == 1 then
				return venv_path
			end
		end
		dir = vim.fn.fnamemodify(dir, ":h")
	end

	return nil
end

function M.get_python_executable()
	if config.config.venv_path then
		local bin_python = config.config.venv_path .. "/bin/python"
		local scripts_python = config.config.venv_path .. "/Scripts/python.exe"

		if vim.fn.filereadable(bin_python) == 1 then
			return bin_python
		elseif vim.fn.filereadable(scripts_python) == 1 then
			return scripts_python
		end
	end

	return config.config.python_executable
end

function M.get_all_management_commands()
	local results = {}

	local function scan_dir(dir, prefix)
		local fd = vim.loop.fs_scandir(dir)
		if not fd then
			return
		end

		while true do
			local name, file_type = vim.loop.fs_scandir_next(fd)
			if not name then
				break
			end

			if file_type == "directory" then
				scan_dir(dir .. "/" .. name, prefix)
			elseif file_type == "file" and name:match("%.py$") and name ~= "__init__.py" then
				local command_name = prefix .. name:gsub("%.py$", "")
				table.insert(results, command_name)
			end
		end
	end

	local project_root = config.config.django_root or config.config.project_root
	if not project_root then
		return results
	end

	local fd = vim.loop.fs_scandir(project_root)
	if not fd then
		return results
	end

	while true do
		local app_name, app_type = vim.loop.fs_scandir_next(fd)
		if not app_name then
			break
		end

		if app_type == "directory" then
			local commands_path = project_root .. "/" .. app_name .. "/management/commands"
			local stat = vim.loop.fs_stat(commands_path)
			if stat and stat.type == "directory" then
				scan_dir(commands_path, app_name .. ".")
			else
			end
		end
	end

	return results
end

return M
