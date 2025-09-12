local M = {}

-- Default configuration
M.default_config = {
	-- Django root (directory containing manage.py)
	django_root = nil,
	-- Project root (parent directory where you stand)
	project_root = nil,
	-- Default virtual environment path (will be auto-detected if not set)
	venv_path = nil,
	-- Default Python executable (will use venv python if available)
	python_executable = "python",
	-- Django settings for normal commands
	django_settings = nil,
	-- Django settings for tests
	django_test_settings = nil,
	-- Terminal command to run Django commands
	terminal_cmd = "split",
	-- Configuration file name
	config_file = ".djortcuts.json",
	-- Auto-detect Django project
	auto_detect = true,
}

-- Configuration
M.config = {}

function M.load_config()
	local config_path = vim.fn.getcwd() .. "/" .. M.default_config.config_file

	if vim.fn.filereadable(config_path) == 1 then
		local file = io.open(config_path, "r")
		if file then
			local content = file:read("*all")
			file:close()

			local success, json_config = pcall(vim.fn.json_decode, content)
			if success and json_config then
				M.config.django_root = json_config.django_root or M.config.django_root
				M.config.project_root = json_config.project_root or M.config.project_root
				M.config.venv_path = json_config.venv_path or M.config.venv_path
				M.config.python_executable = json_config.python_executable or M.config.python_executable
				M.config.django_settings = json_config.django_settings or M.config.django_settings
				M.config.django_test_settings = json_config.django_test_settings or M.config.django_test_settings
			end
		end
	end
end

function M.save_config()
	local config_path = vim.fn.getcwd() .. "/" .. M.default_config.config_file
	local config_data = {
		django_root = M.config.django_root,
		project_root = M.config.project_root,
		venv_path = M.config.venv_path,
		python_executable = M.config.python_executable,
		django_settings = M.config.django_settings,
		django_test_settings = M.config.django_test_settings,
	}

	local file = io.open(config_path, "w")
	if file then
		file:write(vim.fn.json_encode(config_data))
		file:close()
		print("Djortcuts config saved to " .. config_path)
	else
		print("Error: Could not save config to " .. config_path)
	end
end

function M.setup(user_config)
	M.config = vim.tbl_deep_extend("force", M.default_config, user_config or {})
end

return M
