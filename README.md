# Context-Aware Terminal Manager for Neovim

![Cover image](https://github.com/mtkld/ctxterm.nvim/blob/master/front.gif?raw=true)

Lightweight terminal manager for Neovim.

Create floating terminals and switch between them.

Group them by context.

> [!IMPORTANT]
> This is early stage of development. It is a plugin being part of a bigger project but should work as standalone.

> [!NOTE]
> Ctxterm provides merely a set of functions. You need to bind them yourself.

## Purpose

Enable something like "scratch-terminals".

Decrease the need of switching out of Neovim, ... by allowing quick access to terminals and simle organization of them.

## Context-aware

Ctxterm stores all terminals in a given context. You control the context by the callback function `current_context_cb`. Let the function return a string that represents the current context. When you create a new terminal, it will be added to the context. All exposed functions relate to the context-identifyer returned by this function.

Avoid specifying `current_context_cb` if you want to use a single context for all terminals.

## Configuration

### Default configuration

```lua
local default_opts = {
	shell = "bash",
	current_context_cb = function()
		return "Single Generic Context"
	end,
}
```

### Suggested configuration

Example of integratoin with your arbitrary project manager.

```lua
return {
  'mtkld/ctxterm.nvim',
  dependencies = {
    'mtkld/your-project-manager.nvim',
  },
  config = function()
    require('ctxterm').setup {
      shell = 'fish',
      start_shell_with_cwd_cb = function()
        local project_path = require('your-project-manager.properties').current_project.project_path
        return project_path
      end,
      current_context_cb = function()
        local project_name = require('your-project-manager.properties').current_project.name
        return project_name
      end,
    }
  end,
}
```

## Example keybindings

Alt + k - Toggle terminal mode (creates new terminal, switch to last terminal in use, or close terminal mode)

Alt + j - Create new terminal

Alt + h - Bring up previous terminal

Alt + l - Bring up next terminal

```lua
vim.keymap.set('n', '<A-k>', '<CMD>lua require("ctxterm").toggle_context_terminal()<CR>', { noremap = true, silent = true })
vim.keymap.set('t', '<A-k>', '<CMD>lua require("ctxterm").toggle_context_terminal()<CR>', { noremap = true, silent = true })
vim.keymap.set('i', '<A-k>', '<CMD>lua require("ctxterm").toggle_context_terminal()<CR>', { noremap = true, silent = true })

vim.keymap.set('n', '<A-j>', '<CMD>lua require("ctxterm").create_new_terminal()<CR>', { noremap = true, silent = true })
vim.keymap.set('t', '<A-j>', '<CMD>lua require("ctxterm").create_new_terminal()<CR>', { noremap = true, silent = true })
vim.keymap.set('i', '<A-j>', '<CMD>lua require("ctxterm").create_new_terminal()<CR>', { noremap = true, silent = true })

vim.keymap.set('n', '<A-l>', '<CMD>lua require("ctxterm").next_terminal()<CR>', { noremap = true, silent = true })
vim.keymap.set('t', '<A-l>', '<CMD>lua require("ctxterm").next_terminal()<CR>', { noremap = true, silent = true })
vim.keymap.set('i', '<A-l>', '<CMD>lua require("ctxterm").next_terminal()<CR>', { noremap = true, silent = true })

vim.keymap.set('n', '<A-h>', '<CMD>lua require("ctxterm").previous_terminal()<CR>', { noremap = true, silent = true })
vim.keymap.set('t', '<A-h>', '<CMD>lua require("ctxterm").previous_terminal()<CR>', { noremap = true, silent = true })
vim.keymap.set('i', '<A-h>', '<CMD>lua require("ctxterm").previous_terminal()<CR>', { noremap = true, silent = true })
```
