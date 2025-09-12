local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local M = {}

function M.create_args_picker(command, available_args, selected_args, on_select, on_confirm)
	local results = {}

	-- Agregar flags disponibles
	for _, flag in ipairs(available_args.flags) do
		if not flag.used then
			local display_text = flag.flag
			if flag.type == "with_value" then
				display_text = display_text .. " <" .. flag.placeholder .. ">"
			end
			if flag.description and flag.description ~= "" then
				display_text = display_text .. " - " .. flag.description
			end

			table.insert(results, {
				value = flag.flag,
				display = display_text,
				type = "flag",
				flag_type = flag.type,
				placeholder = flag.placeholder,
				description = flag.description
			})
		end
	end

	-- Agregar argumentos posicionales disponibles
	for _, pos_arg in ipairs(available_args.positional) do
		if not pos_arg.used then
			local display_text = pos_arg.name
			if pos_arg.description and pos_arg.description ~= "" then
				display_text = display_text .. " - " .. pos_arg.description
			end

			table.insert(results, {
				value = pos_arg.name,
				display = display_text,
				type = "positional",
				description = pos_arg.description
			})
		end
	end

	-- Agregar opción para argumento posicional dinámico
	table.insert(results, {
		value = "<SPACE>",
		display = "<SPACE> - Agregar argumento posicional dinámico",
		type = "dynamic_positional",
		description = "Presiona Espacio para agregar un argumento posicional"
	})

	-- Agregar argumentos ya seleccionados al prompt
	local prompt_text = ""
	for _, arg in ipairs(selected_args) do
		prompt_text = prompt_text .. " " .. arg
	end
	prompt_text = vim.trim(prompt_text)

	return pickers.new({}, {
		prompt_title = string.format("Argumentos para '%s' (Enter: seleccionar, Ctrl+Enter: ejecutar)", command),
		finder = finders.new_table({
			results = results,
			entry_maker = function(entry)
				return {
					value = entry.value,
					display = entry.display,
					ordinal = entry.display,
					type = entry.type,
					flag_type = entry.flag_type,
					placeholder = entry.placeholder,
					description = entry.description
				}
			end
		}),
		sorter = conf.generic_sorter({}),
		layout_strategy = "center",
		layout_config = { width = 0.8, height = 12 },
		attach_mappings = function(prompt_bufnr, map)
			-- Enter: seleccionar argumento
			actions.select_default:replace(function()
				local entry = action_state.get_selected_entry()
				if entry then
					on_select(entry)
				end
			end)

			-- Ctrl+Enter: confirmar y ejecutar
			map("i", "<C-CR>", function()
				actions.close(prompt_bufnr)
				on_confirm()
			end)

			-- Espacio: agregar argumento posicional dinámico
			map("i", "<Space>", function()
				local current_line = action_state.get_current_line()
				if current_line and current_line ~= "" then
					-- Si hay texto en el prompt, agregarlo como argumento posicional
					on_select({
						value = current_line,
						type = "dynamic_positional",
						description = "Argumento posicional dinámico"
					})
				else
					-- Si no hay texto, mostrar mensaje
					vim.notify("Escribe el argumento posicional y presiona Enter", vim.log.levels.INFO)
				end
			end)

			return true
		end,
	})
end

return M
