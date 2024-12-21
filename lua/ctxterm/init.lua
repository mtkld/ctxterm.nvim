local M = {}

-- Global table to track the currently selected terminal for each project
local currently_selected_terminal = {}
local terminal_count = 0 -- Track the number of terminals created
local terminals = {} -- List of all terminals
local terminal_creation_count = 0
local default_opts = {
	shell = "bash",
	current_context_cb = function()
		return "Single Generic Context"
	end,
}
local opts = {}

function M.setup(user_opts)
	opts = vim.tbl_deep_extend("force", default_opts, user_opts or {})
end

-- Function to darken a color by a percentage
local function darken_color(hex_color, percentage)
	local r = tonumber(hex_color:sub(2, 3), 16)
	local g = tonumber(hex_color:sub(4, 5), 16)
	local b = tonumber(hex_color:sub(6, 7), 16)

	local factor = (100 - percentage) / 100
	r = math.floor(r * factor)
	g = math.floor(g * factor)
	b = math.floor(b * factor)

	return string.format("#%02x%02x%02x", r, g, b)
end

-- Function to generate a unique highlight group for each terminal with darker colors
local function create_terminal_highlight()
	terminal_count = terminal_count + 1
	local highlight_name = "TerminalHighlight" .. terminal_count

	-- Generate a random light color
	local base_color = string.format("#%06x", math.random(0x888888, 0xFFFFFF)) -- Lighter base color range
	local darkened_color = darken_color(base_color, 85)

	-- Set the highlight for the terminal
	vim.api.nvim_set_hl(0, highlight_name, { bg = darkened_color }) -- Darkened background
	return highlight_name
end

-- Function to create a floating title window
local function create_title_window(title, col, row, width, highlight_group)
	-- Create a buffer for the title
	local title_buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(title_buf, 0, -1, false, { " " .. title .. " " }) -- Add title text

	-- Create the floating window for the title
	local opts = {
		relative = "editor",
		width = #title + 2, -- Title width with padding
		height = 1,
		col = col + math.floor((width - (#title + 4)) / 2), -- Center the title
		row = row - 1, -- Place above the terminal
		style = "minimal",
		border = "none",
	}
	local title_win = vim.api.nvim_open_win(title_buf, false, opts)

	-- Set the highlight for the title window
	vim.api.nvim_set_option_value(
		"winhl",
		"NormalFloat:" .. highlight_group .. ",FloatBorder:" .. highlight_group,
		{ win = title_win }
	)

	-- Set buffer options
	vim.bo[title_buf].bufhidden = "wipe" -- Wipe the buffer when closed
	vim.bo[title_buf].modifiable = false -- Make the buffer unmodifiable
	return title_win
end
-- Function to create a new terminal in a floating window
function M.create_new_terminal()
	local context = opts.current_context_cb()
	-- Initialize terminal list for the project if not already present
	terminals[context] = terminals[context] or {}

	-- Check and hide the currently visible terminal for the project
	local current_index = currently_selected_terminal[context]
	if current_index then
		local current_terminal = terminals[context][current_index]
		if current_terminal then
			if vim.api.nvim_win_is_valid(current_terminal.win) then
				vim.api.nvim_win_hide(current_terminal.win)
			end
			if current_terminal.title_win and vim.api.nvim_win_is_valid(current_terminal.title_win) then
				vim.api.nvim_win_hide(current_terminal.title_win)
			end
		end
	end

	-- Create a new terminal buffer
	local new_term_buf = vim.api.nvim_create_buf(false, true) -- Create a new unlisted buffer

	-- Set up the floating window dimensions
	local width = math.floor(vim.o.columns * 0.8)
	local height = math.floor(vim.o.lines * 0.8)
	local col = math.floor((vim.o.columns - width) / 2)
	local row = math.floor((vim.o.lines - height) / 2)

	local termopts = {
		relative = "editor",
		width = width,
		height = height,
		col = col,
		row = row,
		style = "minimal",
		border = "rounded",
	}

	-- Create a new floating window for the terminal
	local new_term_win = vim.api.nvim_open_win(new_term_buf, true, termopts)

	-- Assign a unique background color to the terminal
	local highlight_group = create_terminal_highlight()
	vim.api.nvim_set_option_value(
		"winhl",
		"NormalFloat:" .. highlight_group .. ",FloatBorder:" .. highlight_group,
		{ win = new_term_win }
	)

	-- Create a title window above the terminal
	-- NOTE: terminal_creation_count is leftover thing, but still used to generate unique color groups for unique background of each terminal
	terminal_creation_count = terminal_creation_count + 1

	-- Create a title window above the terminal
	local terminal_number = #terminals[context] + 1

	local title = "[" .. context .. "] Context Terminal " .. terminal_number
	local new_title_win = create_title_window(title, col, row, width, highlight_group)

	-- Open fish shell in the terminal buffer
	if opts.start_shell_with_cwd_cb then
		vim.fn.termopen(opts.shell, { cwd = opts.start_shell_with_cwd_cb() })
	else
		vim.fn.termopen(opts.shell)
	end

	-- Set buffer options
	vim.bo[new_term_buf].buflisted = false -- Unlist buffer
	vim.bo[new_term_buf].filetype = "toggleterm" -- Neutral filetype for terminal

	-- Disable Treesitter for terminal
	vim.cmd(string.format("autocmd TermOpen <buffer=%d> lua require'nvim-treesitter'.detach()", new_term_buf))

	-- Start terminal in insert mode
	vim.cmd("startinsert")

	-- Store the terminal data in the context-specific list
	table.insert(terminals[context], {
		buf = new_term_buf,
		win = new_term_win,
		title_win = new_title_win,
		highlight_group = highlight_group,
		title = title,
	})

	-- Update the currently selected terminal for this project
	currently_selected_terminal[context] = #terminals[context]
end

-- Function to toggle the project directory terminal

function M.toggle_context_terminal()
	local context = opts.current_context_cb()

	terminals[context] = terminals[context] or {}
	currently_selected_terminal[context] = currently_selected_terminal[context] or 0

	local project_terminals = terminals[context]
	local selected_index = currently_selected_terminal[context]
	local selected_terminal = project_terminals[selected_index]

	-- If the terminal window is open and valid, hide it
	if selected_terminal and vim.api.nvim_win_is_valid(selected_terminal.win) then
		vim.api.nvim_win_hide(selected_terminal.win)
		if selected_terminal.title_win and vim.api.nvim_win_is_valid(selected_terminal.title_win) then
			vim.api.nvim_win_hide(selected_terminal.title_win)
		end
		-- Do not reset `currently_selected_terminal[context]` to preserve the last active terminal
		return
	end

	-- If no valid terminal exists, create a new one
	if not selected_terminal then
		M.create_new_terminal()
	else
		-- Reopen the floating window for the existing terminal
		local width = math.floor(vim.o.columns * 0.8)
		local height = math.floor(vim.o.lines * 0.8)
		local col = math.floor((vim.o.columns - width) / 2)
		local row = math.floor((vim.o.lines - height) / 2)
		local highlight_group = selected_terminal.highlight_group

		local opts = {
			relative = "editor",
			width = width,
			height = height,
			col = col,
			row = row,
			style = "minimal",
			border = "rounded",
		}
		selected_terminal.win = vim.api.nvim_open_win(selected_terminal.buf, true, opts)

		-- Reapply the background color if reopening
		vim.api.nvim_set_option_value(
			"winhl",
			"NormalFloat:" .. highlight_group .. ",FloatBorder:" .. highlight_group,
			{ win = selected_terminal.win }
		)

		-- Create or reapply the title window above the terminal
		local title = selected_terminal.title
		selected_terminal.title_win = create_title_window(title, col, row, width, highlight_group)

		vim.cmd("startinsert") -- Ensure terminal starts in insert mode
	end
end

local function switch_to_terminal(index)
	local context = opts.current_context_cb()

	local project_terminals = terminals[context]
	if not project_terminals or #project_terminals == 0 then
		print("No terminals available for project: " .. context)
		return
	end

	if index < 1 or index > #project_terminals then
		print("No terminal at this position for project: " .. context)
		return
	end

	-- Close any currently visible terminal and title window
	local currently_selected_index = currently_selected_terminal[context]
	if currently_selected_index and project_terminals[currently_selected_index] then
		local currently_selected = project_terminals[currently_selected_index]
		if vim.api.nvim_win_is_valid(currently_selected.win) then
			vim.api.nvim_win_hide(currently_selected.win)
		end
		if currently_selected.title_win and vim.api.nvim_win_is_valid(currently_selected.title_win) then
			vim.api.nvim_win_hide(currently_selected.title_win)
		end
	end

	-- Switch to the new terminal
	local term = project_terminals[index]

	-- Calculate window dimensions and position
	local width = math.floor(vim.o.columns * 0.8)
	local height = math.floor(vim.o.lines * 0.8)
	local col = math.floor((vim.o.columns - width) / 2)
	local row = math.floor((vim.o.lines - height) / 2)

	-- Reopen the terminal window if necessary
	if not vim.api.nvim_win_is_valid(term.win) then
		local opts = {
			relative = "editor",
			width = width,
			height = height,
			col = col,
			row = row,
			style = "minimal",
			border = "rounded",
		}
		term.win = vim.api.nvim_open_win(term.buf, true, opts)
		vim.api.nvim_set_option_value(
			"winhl",
			"NormalFloat:" .. term.highlight_group .. ",FloatBorder:" .. term.highlight_group,
			{ win = term.win }
		)
	end

	-- Reopen the title window if necessary
	if not vim.api.nvim_win_is_valid(term.title_win) then
		term.title_win = create_title_window(term.title, col, row, width, term.highlight_group)
	end

	vim.cmd("startinsert") -- Ensure terminal starts in insert mode

	-- Update the currently selected terminal index for the project
	currently_selected_terminal[context] = index
end

function M.next_terminal()
	local context = opts.current_context_cb()
	if not context then
		print("No current project detected!")
		return
	end

	-- Get the terminal list for the current project
	local project_terminals = terminals[context]
	if not project_terminals or #project_terminals == 0 then
		print("No terminals created yet for project: " .. context)
		return
	end

	-- Get the current terminal index
	local current_index = currently_selected_terminal[context] or 1

	-- Increment index and wrap around if necessary
	local next_index = current_index + 1
	if next_index > #project_terminals then
		next_index = 1 -- Wrap around to the first terminal
	end

	-- Switch to the next terminal
	switch_to_terminal(next_index)

	-- Update the currently selected terminal
	currently_selected_terminal[context] = next_index
end

-- Function to go to the previous terminal for the current project
function M.previous_terminal()
	local context = opts.current_context_cb()
	if not context then
		print("No current project detected!")
		return
	end

	-- Get the terminal list for the current project
	local project_terminals = terminals[context]
	if not project_terminals or #project_terminals == 0 then
		print("No terminals created yet for project: " .. context)
		return
	end

	-- Get the current terminal index
	local current_index = currently_selected_terminal[context] or 1

	-- Decrement index and wrap around if necessary
	local prev_index = current_index - 1
	if prev_index < 1 then
		prev_index = #project_terminals -- Wrap around to the last terminal
	end

	-- Switch to the previous terminal
	switch_to_terminal(prev_index)

	-- Update the currently selected terminal
	currently_selected_terminal[context] = prev_index
end
function M.terminal_command_quick_run(command, send_ctrl_c_first)
	send_ctrl_c_first = send_ctrl_c_first or false

	local context = opts.current_context_cb()

	-- Ensure terminals table exists for the project
	terminals[context] = terminals[context] or {}

	-- Check if the first terminal exists
	local first_terminal = terminals[context][1]
	if first_terminal then
		-- If the first terminal exists, switch to it
		switch_to_terminal(1)
	else
		-- Create a new terminal if it doesn't exist
		M.create_new_terminal()
	end
	vim.cmd("startinsert")
	-- Send Ctrl-C to stop any running process to cancel previous run if still active
	if send_ctrl_c_first then
		vim.fn.chansend(vim.b.terminal_job_id, "\x03\n") -- Ctrl-C is ASCII 0x03
	end
	vim.fn.chansend(vim.b.terminal_job_id, command .. "\n")
end

return M
