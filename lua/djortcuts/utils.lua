local config = require("djortcuts.config")

local M = {}

local cached_django_root = nil

local function search_manage_py(dir)
	local manage_py_path = dir .. "/manage.py"
	if vim.fn.filereadable(manage_py_path) == 1 then
		return dir
	end
	return nil
end

local function walk_up(current_dir, max_levels)
	local dir = current_dir
	local levels = 0
	while dir and dir ~= "/" and dir ~= "" and levels < max_levels do
		local result = search_manage_py(dir)
		if result then
			return result
		end
		dir = vim.fn.fnamemodify(dir, ":h")
		levels = levels + 1
	end
	return nil
end

local function search_recursive(base_dir, depth, current_depth)
	if current_depth > depth then
		return nil
	end

	local result = search_manage_py(base_dir)
	if result then
		return result
	end

	local subdirs = vim.fn.glob(base_dir .. "/*/", false, true)
	for _, subdir in ipairs(subdirs) do
		subdir = subdir:gsub("/$", "")
		result = search_recursive(subdir, depth, current_depth + 1)
		if result then
			return result
		end
	end

	return nil
end

function M.find_django_root()
	if cached_django_root then
		return cached_django_root
	end

	local current_dir = vim.fn.getcwd()
	local depth = config.config.detection_depth or 3

	local result = search_manage_py(current_dir)
	if result then
		cached_django_root = result
		return result
	end

	result = walk_up(current_dir, depth)
	if result then
		cached_django_root = result
		return result
	end

	result = search_recursive(current_dir, depth, 0)
	if result then
		cached_django_root = result
		return result
	end

	return nil
end

function M.clear_cache()
	cached_django_root = nil
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
