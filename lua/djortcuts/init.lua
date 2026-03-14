local config = require("djortcuts.config")
local utils = require("djortcuts.utils")
local commands = require("djortcuts.commands")
local management = require("djortcuts.management")
local pickers = require("djortcuts.pickers")
local logs = require("djortcuts.logs")
local floating = require("djortcuts.floating")
local overseer = require("djortcuts.overseer")

local M = {}

-- Public API functions
function M.DjangoRun()
	commands.run_django_terminal("runserver")
end

function M.DjangoMigrate()
	commands.run_django_terminal("migrate")
end

function M.DjangoMakemigrations()
	commands.run_django_terminal("makemigrations")
end

function M.DjangoShell()
	commands.run_django_terminal("shell")
end

function M.DjangoInit()
	local django_root = utils.find_django_root()

	if not django_root then
		print("Error: Django project not found. Please navigate to a Django project directory first.")
		return
	end

	local venv_path = utils.find_venv()

	-- preguntar settings normales si no existen
	if not config.config.django_settings then
		local input_settings = vim.fn.input("Django settings module (e.g. mysite.settings): ")
		if input_settings ~= "" then
			config.config.django_settings = input_settings
		else
			config.config.django_settings = "mysite.settings"
		end
	end

	-- preguntar settings de test si no existen
	if not config.config.django_test_settings then
		local input_test_settings = vim.fn.input("Django test settings module (e.g. mysite.test_settings): ")
		if input_test_settings ~= "" then
			config.config.django_test_settings = input_test_settings
		else
			config.config.django_test_settings = config.config.django_settings -- fallback
		end
	end

	config.config.django_root = django_root
	config.config.project_root = vim.fn.getcwd()
	config.config.venv_path = venv_path

	config.save_config()

	print("Djortcuts initialized!")
	print("Django root: " .. django_root)
	print("Project root: " .. config.config.project_root)
	print("Django settings: " .. config.config.django_settings)
	print("Django test settings: " .. config.config.django_test_settings)
	if venv_path then
		print("Virtual environment: " .. venv_path)
	else
		print("Virtual environment: Not found (will use system Python)")
	end
end

function M.DjangoTest()
	commands.run_django_terminal("test", { test = true })
end

function M.DjangoCollectstatic()
	commands.run_django_terminal("collectstatic --noinput")
end

function M.DjangoCreateSuperuser()
	commands.run_django_terminal("createsuperuser")
end

-- i18n: makemessages
function M.DjangoMakemessages()
	local opts = vim.fn.input("makemessages options (e.g. -l es, -a): ")
	local cmd = "makemessages"
	if opts and opts ~= "" then
		cmd = cmd .. " " .. opts
	end
	commands.run_django_terminal(cmd)
end

-- i18n: compilemessages (aka build messages)
function M.DjangoCompilemessages()
	local opts = vim.fn.input("compilemessages options (optional, e.g. -l es): ")
	local cmd = "compilemessages"
	if opts and opts ~= "" then
		cmd = cmd .. " " .. opts
	end
	commands.run_django_terminal(cmd)
end

function M.DjangoCheck()
	commands.run_django_terminal("check")
end

function M.DjangoFlush()
	commands.run_django_terminal("flush")
end

function M.DjangoLoaddata()
	commands.run_django_terminal("loaddata")
end

function M.DjangoDumpdata()
	commands.run_django_terminal("dumpdata")
end

function M.DjangoShowmigrations()
	commands.run_django_terminal("showmigrations")
end

function M.DjangoSquashmigrations()
	commands.run_django_terminal("squashmigrations")
end

function M.DjangoStartapp()
	local app_name = vim.fn.input("App name: ")
	if app_name and app_name ~= "" then
		commands.run_django_terminal("startapp " .. app_name)
	end
end

function M.DjangoStartproject()
	local project_name = vim.fn.input("Project name: ")
	if project_name and project_name ~= "" then
		commands.run_django_terminal("startproject " .. project_name)
	end
end

function M.DjortcutsLogs(args)
	local log_list = logs.list()

	if not log_list or #log_list == 0 then
		print("No command logs found.")
		return
	end

	if args and args.args and args.args ~= "" then
		local id = tonumber(args.args)
		if id then
			local log_entry = logs.get(id)
			if log_entry then
				floating.open(log_entry.output)
				return
			else
				print("Log not found for ID: " .. id)
				return
			end
		end
	end

	vim.ui.select(log_list, {
		prompt = "Select a command log:",
		format_item = function(item)
			return string.format("[%d] %s - %s", item.id, item.timestamp, item.command)
		end,
	}, function(choice)
		if choice then
			local log_entry = logs.get(choice.id)
			if log_entry then
				floating.open(log_entry.output)
			end
		end
	end)
end

-- 🚀 Función principal mejorada para DjangoManagementCommand
function M.DjangoManagementCommand()
	local available_commands = utils.get_all_management_commands()
	if not available_commands or #available_commands == 0 then
		print("Error: No se encontraron management commands")
		return
	end

	-- Seleccionar comando principal
	vim.ui.select(available_commands, { prompt = "Seleccioná un management command:" }, function(choice)
		if not choice then
			return
		end

		-- Quitar prefijo de app si existe
		if choice:match("%.") then
			local parts = vim.split(choice, "%.")
			choice = parts[#parts]
		end

		-- Analizar argumentos del comando
		local parsed_args = management.parse_command_help(choice)

		if #parsed_args.errors > 0 then
			for _, error in ipairs(parsed_args.errors) do
				print("Error: " .. error)
			end
			return
		end

		-- Estado del picker
		local selected_args = {}
		local available_flags = parsed_args.flags
		local available_positional = parsed_args.positional

		-- Función para manejar selección de argumento
		local function handle_arg_selection(entry)
			if entry.type == "flag" then
				if entry.flag_type == "with_value" then
					-- Flag con valor: pedir el valor al usuario
					local value = vim.fn.input(string.format("Valor para %s: ", entry.value))
					if value and value ~= "" then
						table.insert(selected_args, entry.value .. " " .. value)
						-- Marcar como usado
						for _, flag in ipairs(available_flags) do
							if flag.flag == entry.value then
								flag.used = true
								break
							end
						end
					end
				else
					-- Flag sin valor: agregar directamente
					table.insert(selected_args, entry.value)
					-- Marcar como usado
					for _, flag in ipairs(available_flags) do
						if flag.flag == entry.value then
							flag.used = true
							break
						end
					end
				end
			elseif entry.type == "positional" then
				-- Argumento posicional: agregar directamente
				table.insert(selected_args, entry.value)
				-- Marcar como usado
				for _, pos_arg in ipairs(available_positional) do
					if pos_arg.name == entry.value then
						pos_arg.used = true
						break
					end
				end
			elseif entry.type == "dynamic_positional" then
				-- Argumento posicional dinámico: agregar el valor
				table.insert(selected_args, entry.value)
			end

			-- Recrear el picker con argumentos actualizados
			local new_picker = pickers.create_args_picker(
				choice,
				{ flags = available_flags, positional = available_positional },
				selected_args,
				handle_arg_selection,
				function()
					-- Función de confirmación
					local final_cmd = choice
					if #selected_args > 0 then
						final_cmd = final_cmd .. " " .. table.concat(selected_args, " ")
					end
					commands.run_django_terminal(final_cmd)
				end
			)
			new_picker:find()
		end

		-- Función de confirmación
		local function confirm_execution()
			local final_cmd = choice
			if #selected_args > 0 then
				final_cmd = final_cmd .. " " .. table.concat(selected_args, " ")
			end
			commands.run_django_terminal(final_cmd)
		end

		-- Crear y mostrar el picker inicial
		local picker =
			pickers.create_args_picker(choice, parsed_args, selected_args, handle_arg_selection, confirm_execution)
		picker:find()
	end)
end

-- Setup function
function M.setup(user_config)
	config.setup(user_config)

	if config.config.auto_detect then
		config.load_config()

		if not config.config.django_root then
			config.config.django_root = utils.find_django_root()
		end

		if not config.config.project_root then
			config.config.project_root = vim.fn.getcwd()
		end

		if not config.config.venv_path then
			config.config.venv_path = utils.find_venv()
		end
	end

	if config.config.use_overseer ~= false and overseer.is_available() then
		overseer.setup({ fullscreen = config.config.overseer_fullscreen })
	end

	vim.api.nvim_create_user_command("DjangoRun", M.DjangoRun, { desc = "Run Django development server" })
	vim.api.nvim_create_user_command("DjangoMigrate", M.DjangoMigrate, { desc = "Run Django migrations" })
	vim.api.nvim_create_user_command("DjangoMakemigrations", M.DjangoMakemigrations, { desc = "Create migrations" })
	vim.api.nvim_create_user_command("DjangoShell", M.DjangoShell, { desc = "Open Django shell" })
	vim.api.nvim_create_user_command("DjangoInit", M.DjangoInit, { desc = "Initialize Djortcuts config" })
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
	vim.api.nvim_create_user_command("DjangoMakemessages", M.DjangoMakemessages, { desc = "Create/Update .po files" })
	vim.api.nvim_create_user_command(
		"DjangoCompilemessages",
		M.DjangoCompilemessages,
		{ desc = "Compile .po to .mo (build messages)" }
	)
	vim.api.nvim_create_user_command(
		"DjangoSquashmigrations",
		M.DjangoSquashmigrations,
		{ desc = "Squash Django migrations" }
	)
	vim.api.nvim_create_user_command("DjangoStartapp", M.DjangoStartapp, { desc = "Create Django app" })
	vim.api.nvim_create_user_command("DjangoStartproject", M.DjangoStartproject, { desc = "Create Django project" })
	vim.api.nvim_create_user_command(
		"DjangoManagementCommand",
		M.DjangoManagementCommand,
		{ desc = "Run Management Command" }
	)
	vim.api.nvim_create_user_command("DjortcutsLogs", M.DjortcutsLogs, {
		desc = "List and view command logs",
		nargs = "?",
	})
	vim.api.nvim_create_user_command("DjangoOverseerToggle", function()
		overseer.toggle_overseer_fullscreen()
	end, { desc = "Toggle overseer task list" })
end

return M
