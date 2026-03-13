local M = {}

local float_win = nil
local float_buf = nil

function M.open(output_lines)
	float_buf = vim.api.nvim_create_buf(false, true)

	vim.api.nvim_buf_set_lines(float_buf, 0, -1, false, output_lines)

	local width = math.floor(vim.o.columns * 0.8)
	local height = math.floor(vim.o.lines * 0.7)
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	local opts = {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
	}

	float_win = vim.api.nvim_open_win(float_buf, true, opts)

	vim.api.nvim_win_set_option(float_win, "wrap", true)
	vim.api.nvim_win_set_option(float_win, "scrolloff", 999)

	vim.api.nvim_buf_set_keymap(
		float_buf,
		"n",
		"q",
		":lua require('djortcuts.floating').close()<CR>",
		{ noremap = true, silent = true }
	)
	vim.api.nvim_buf_set_keymap(
		float_buf,
		"n",
		"<ESC>",
		":lua require('djortcuts.floating').close()<CR>",
		{ noremap = true, silent = true }
	)
	vim.api.nvim_buf_set_keymap(
		float_buf,
		"n",
		"j",
		"j:lua require('djortcuts.floating').scroll('down')<CR>",
		{ noremap = true, silent = true }
	)
	vim.api.nvim_buf_set_keymap(
		float_buf,
		"n",
		"k",
		"k:lua require('djortcuts.floating').scroll('up')<CR>",
		{ noremap = true, silent = true }
	)
end

function M.close()
	if float_win and vim.api.nvim_win_is_valid(float_win) then
		vim.api.nvim_win_close(float_win, true)
	end
	if float_buf and vim.api.nvim_buf_is_valid(float_buf) then
		vim.api.nvim_buf_delete(float_buf, { force = true })
	end
	float_win = nil
	float_buf = nil
end

function M.update(lines)
	if not float_buf or not vim.api.nvim_buf_is_valid(float_buf) then
		return
	end

	local line_count = vim.api.nvim_buf_line_count(float_buf)
	vim.api.nvim_buf_set_lines(float_buf, line_count, -1, false, lines)
end

function M.scroll(direction)
	if not float_win or not vim.api.nvim_win_is_valid(float_win) then
		return
	end

	if direction == "down" then
		vim.cmd("normal j")
	elseif direction == "up" then
		vim.cmd("normal k")
	end
end

function M.is_open()
	return float_win ~= nil and vim.api.nvim_win_is_valid(float_win)
end

return M
