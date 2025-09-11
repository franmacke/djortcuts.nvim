local M = {}

-- Default configuration
local default_config = {
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
	config_file = ".django-automation.json",
	-- Auto-detect Django project
	auto_detect = true,
}

-- Configuration
local config = {}

-- Utility functions
local function find_django_root()
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

local function find_venv()
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

local function get_python_executable()
	if config.venv_path then
		local bin_python = config.venv_path .. "/bin/python"
		local scripts_python = config.venv_path .. "/Scripts/python.exe"

		if vim.fn.filereadable(bin_python) == 1 then
			return bin_python
		elseif vim.fn.filereadable(scripts_python) == 1 then
			return scripts_python
		end
	end

	return config.python_executable
end

local function load_config()
	local config_path = vim.fn.getcwd() .. "/" .. default_config.config_file

	if vim.fn.filereadable(config_path) == 1 then
		local file = io.open(config_path, "r")
		if file then
			local content = file:read("*all")
			file:close()

			local success, json_config = pcall(vim.fn.json_decode, content)
			if success and json_config then
				config.django_root = json_config.django_root or config.django_root
				config.project_root = json_config.project_root or config.project_root
				config.venv_path = json_config.venv_path or config.venv_path
				config.python_executable = json_config.python_executable or config.python_executable
				config.django_settings = json_config.django_settings or config.django_settings
				config.django_test_settings = json_config.django_test_settings or config.django_test_settings
			end
		end
	end
end

local function save_config()
	local config_path = vim.fn.getcwd() .. "/" .. default_config.config_file
	local config_data = {
		django_root = config.django_root,
		project_root = config.project_root,
		venv_path = config.venv_path,
		python_executable = config.python_executable,
		django_settings = config.django_settings,
		django_test_settings = config.django_test_settings,
	}

	local file = io.open(config_path, "w")
	if file then
		file:write(vim.fn.json_encode(config_data))
		file:close()
		print("Django automation config saved to " .. config_path)
	else
		print("Error: Could not save config to " .. config_path)
	end
end

-- Función genérica para ejecutar comandos de Django
local function run_django_terminal(command, opts)
	opts = opts or {}
	local django_root = config.django_root or find_django_root()

	if not django_root then
		print(
			"Error: Django project not found. Please run :DjangoInit first or navigate to a Django project directory."
		)
		return
	end

	local python_exec = get_python_executable()
	local manage_py = django_root .. "/manage.py"

	if vim.fn.filereadable(manage_py) ~= 1 then
		print("Error: manage.py not found in " .. django_root)
		return
	end

	-- Usar settings normales o de test según `opts`
	local settings_module = opts.test and config.django_test_settings or config.django_settings
	local settings_arg = settings_module and (" --settings=" .. settings_module) or ""

	-- Build the full command
	local full_command
	if config.venv_path then
		local venv_activate = config.venv_path .. "/bin/activate"
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

	vim.cmd(config.terminal_cmd)
	vim.cmd("terminal " .. full_command)
	vim.cmd("stopinsert")
end

-- Public API functions
function M.DjangoRun()
	run_django_terminal("runserver")
end

function M.DjangoMigrate()
	run_django_terminal("migrate")
end

function M.DjangoMakemigrations()
	run_django_terminal("makemigrations")
end

function M.DjangoShell()
	run_django_terminal("shell")
end

function M.DjangoInit()
	local django_root = find_django_root()

	if not django_root then
		print("Error: Django project not found. Please navigate to a Django project directory first.")
		return
	end

	local venv_path = find_venv()

	-- preguntar settings normales si no existen
	if not config.django_settings then
		local input_settings = vim.fn.input("Django settings module (e.g. mysite.settings): ")
		if input_settings ~= "" then
			config.django_settings = input_settings
		else
			config.django_settings = "mysite.settings"
		end
	end

	-- preguntar settings de test si no existen
	if not config.django_test_settings then
		local input_test_settings = vim.fn.input("Django test settings module (e.g. mysite.test_settings): ")
		if input_test_settings ~= "" then
			config.django_test_settings = input_test_settings
		else
			config.django_test_settings = config.django_settings -- fallback
		end
	end

	config.django_root = django_root
	config.project_root = vim.fn.getcwd()
	config.venv_path = venv_path

	save_config()

	print("Django automation initialized!")
	print("Django root: " .. django_root)
	print("Project root: " .. config.project_root)
	print("Django settings: " .. config.django_settings)
	print("Django test settings: " .. config.django_test_settings)
	if venv_path then
		print("Virtual environment: " .. venv_path)
	else
		print("Virtual environment: Not found (will use system Python)")
	end
end

function M.DjangoTest()
	run_django_terminal("test", { test = true })
end

function M.DjangoCollectstatic()
	run_django_terminal("collectstatic --noinput")
end

function M.DjangoCreateSuperuser()
	run_django_terminal("createsuperuser")
end

function M.DjangoCheck()
	run_django_terminal("check")
end

function M.DjangoFlush()
	run_django_terminal("flush")
end

function M.DjangoLoaddata()
	run_django_terminal("loaddata")
end

function M.DjangoDumpdata()
	run_django_terminal("dumpdata")
end

function M.DjangoShowmigrations()
	run_django_terminal("showmigrations")
end

function M.DjangoSquashmigrations()
	run_django_terminal("squashmigrations")
end

function M.DjangoStartapp()
	local app_name = vim.fn.input("App name: ")
	if app_name and app_name ~= "" then
		run_django_terminal("startapp " .. app_name)
	end
end

function M.DjangoStartproject()
	local project_name = vim.fn.input("Project name: ")
	if project_name and project_name ~= "" then
		run_django_terminal("startproject " .. project_name)
	end
end

-- Setup function
function M.setup(user_config)
	config = vim.tbl_deep_extend("force", default_config, user_config or {})

	if config.auto_detect then
		load_config()

		if not config.django_root then
			config.django_root = find_django_root()
		end

		if not config.project_root then
			config.project_root = vim.fn.getcwd()
		end

		if not config.venv_path then
			config.venv_path = find_venv()
		end
	end

	vim.api.nvim_create_user_command("DjangoRun", M.DjangoRun, { desc = "Run Django development server" })
	vim.api.nvim_create_user_command("DjangoMigrate", M.DjangoMigrate, { desc = "Run Django migrations" })
	vim.api.nvim_create_user_command("DjangoMakemigrations", M.DjangoMakemigrations, { desc = "Create migrations" })
	vim.api.nvim_create_user_command("DjangoShell", M.DjangoShell, { desc = "Open Django shell" })
	vim.api.nvim_create_user_command("DjangoInit", M.DjangoInit, { desc = "Initialize Django automation config" })
	vim.api.nvim_create_user_command("DjangoTest", M.DjangoTest, { desc = "Run Django tests with test settings" })
	vim.api.nvim_create_user_command("DjangoCollectstatic", M.DjangoCollectstatic, { desc = "Collect static files" })
	vim.api.nvim_create_user_command(
		"DjangoCreateSuperuser",
		M.DjangoCreateSuperuser,
		{ desc = "Create Django superuser" }
	)
	vim.api.nvim_create_user_command("DjangoCheck", M.DjangoCheck, { desc = "Check Django project" })
	vim.api.nvim_create_user_command("DjangoFlush", M.DjangoFlush, { desc = "Flush Django database" })
	vim.api.nvim_create_user_command("DjangoLoaddata", M.DjangoLoaddata, { desc = "Load Django fixtures" })
	vim.api.nvim_create_user_command("DjangoDumpdata", M.DjangoDumpdata, { desc = "Dump Django data" })
	vim.api.nvim_create_user_command(
		"DjangoShowmigrations",
		M.DjangoShowmigrations,
		{ desc = "Show Django migrations" }
	)
	vim.api.nvim_create_user_command(
		"DjangoSquashmigrations",
		M.DjangoSquashmigrations,
		{ desc = "Squash Django migrations" }
	)
	vim.api.nvim_create_user_command("DjangoStartapp", M.DjangoStartapp, { desc = "Create Django app" })
	vim.api.nvim_create_user_command("DjangoStartproject", M.DjangoStartproject, { desc = "Create Django project" })
end

return M