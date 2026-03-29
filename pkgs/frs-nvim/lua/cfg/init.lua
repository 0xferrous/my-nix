-- Debug logging setup
local startup_debug = vim.env.NVIM_STARTUP_DEBUG == "1"
local logfile = startup_debug and io.open("/tmp/nvim-startup.log", "w") or nil

local function log(msg)
  if not logfile then
    return
  end

  logfile:write(string.format("%s - %s - Mem: %.2f MB\n",
    os.date("%H:%M:%S"),
    msg,
    collectgarbage("count") / 1024))
  logfile:flush()
end

log("=== NVIM STARTUP BEGIN ===")

-- Set shell to nu
vim.opt.shell = "/run/current-system/sw/bin/nu"

-- Set <space> as the leader key
vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.keymap.set({ "n", "v" }, "<Space>", "<Nop>", { silent = true, desc = "Disable <Space> in normal and visual mode" })
log("Leader keys set")

-- Neovim options

-- Set the floating window borders
vim.o.winborder = "rounded"

-- Set highlight on search
vim.o.hlsearch = false

-- Make line numbers default
vim.wo.number = true
vim.wo.relativenumber = true

-- Enable mouse mode
vim.o.mouse = "a"

-- Sync clipboard between OS and Neovim
vim.o.clipboard = "unnamedplus"

-- Enable break indent
vim.o.breakindent = true

-- Save undo history
vim.o.undofile = true

-- Case-insensitive searching UNLESS \C or capital in search
vim.o.ignorecase = true
vim.o.smartcase = true

-- Keep signcolumn on by default
vim.wo.signcolumn = "yes"

-- Decrease update time
vim.o.updatetime = 250
vim.o.timeoutlen = 300

-- Configure how new splits should be opened
vim.opt.splitright = true
vim.opt.splitbelow = true

-- Preview substitutions live, as you type
vim.opt.inccommand = "split"

-- Set completeopt to have a better completion experience
vim.o.completeopt = "menuone,noselect"

-- Show trailing whitespace and render tabs with full width
vim.opt.list = true
vim.opt.listchars = {
  trail = "·",
  tab = "»·",
}

-- Remap for dealing with word wrap
vim.keymap.set("n", "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true, desc = "Move up by display line when no count is given" })
vim.keymap.set("n", "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true, desc = "Move down by display line when no count is given" })

-- Highlight on yank
vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "Highlight when yanking (copying) text",
  group = vim.api.nvim_create_augroup("highlight-yank", { clear = true }),
  callback = vim.highlight.on_yank,
})

log("Autocmds created")

-- Diagnostic keymaps
vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float,
  { desc = "Open floating diagnostic message" })

vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist,
  { desc = "Open diagnostics list" })

-- Terminal to normal mode keymap
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- No zellij auto start
vim.env.ZELLIJ = 0

-- Highlight active line
vim.go.cursorline = true

-- Set filetype for .ansi files
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = "*.ansi",
  callback = function()
    vim.bo.filetype = "ansi"
  end,
  desc = "set filetype to ansi for .ansi files",
})

-- Render ANSI codes in current buffer
vim.api.nvim_create_user_command("TermHl", function()
  local b = vim.api.nvim_create_buf(false, true)
  local chan = vim.api.nvim_open_term(b, {})
  vim.api.nvim_chan_send(chan, table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n"))
  vim.api.nvim_win_set_buf(0, b)
end, { desc = "Highlights ANSI termcodes in curbuf" })

-- Write :messages to file
vim.api.nvim_create_user_command("WriteMessagesToFile", function()
  local out = vim.api.nvim_exec2("messages", { output = true }).output
  local path = "/tmp/frs-nvim/messages.log"
  vim.fn.mkdir("/tmp/frs-nvim", "p")
  vim.fn.writefile(vim.split(out, "\n"), path)
  vim.notify("Wrote :messages to " .. path)
end, { desc = "Write :messages output to /tmp/frs-nvim/messages.log" })

-- Setup plugins via nix-provided runtime paths (no runtime package manager)
log("Before requiring nix plugin loader")
local loader = require("cfg.fns")
log("Nix loader required, starting setup")
loader.setup_nix_plugins()
log("Nix loader setup complete")

-- Colorscheme
log("Setting colorscheme")
vim.cmd.colorscheme("gruvbox-material")
log("Colorscheme set")

-- Neovide config
vim.g.neovide_opacity = 0.95
vim.g.neovide_normal_opacity = 0.95
vim.g.neovide_theme = "dark"

log("=== NVIM STARTUP COMPLETE ===")

if logfile then
  logfile:close()
end
