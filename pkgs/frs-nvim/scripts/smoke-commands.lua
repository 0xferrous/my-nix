local failures = {}

local function note(msg)
  print("[commands-smoke] " .. msg)
end

local function fail(msg)
  table.insert(failures, msg)
  vim.api.nvim_err_writeln("[commands-smoke][fail] " .. msg)
end

local function check(label, fn)
  local ok, err = pcall(fn)
  if not ok then
    fail(("%s: %s"):format(label, tostring(err)))
  else
    note("ok: " .. label)
  end
end

local function join(...)
  return vim.fs.joinpath(...)
end

local function ensure_dir(path)
  vim.fn.mkdir(path, "p")
end

local function write_file(path, lines)
  vim.fn.writefile(lines, path)
end

local function setup_workspace()
  local root = vim.fn.tempname() .. "-commands-smoke"
  ensure_dir(root)
  ensure_dir(join(root, ".git"))
  write_file(join(root, "README.md"), { "# smoke", "", "hello" })
  write_file(join(root, "notes.norg"), { "* Smoke", "  - works" })
  write_file(join(root, "init.lua"), { "local x = 1", "return x" })
  return root
end

local function trigger_load(repo)
  local ok_lze, lze = pcall(require, "lze")
  if not ok_lze then
    fail("failed to require lze")
    return
  end

  local ok, err = pcall(function()
    lze.trigger_load(repo)
  end)
  if not ok then
    fail(("trigger_load(%s): %s"):format(repo, tostring(err)))
  else
    note("trigger_load(" .. repo .. ")")
  end
end

local function assert_command(name)
  if vim.fn.exists(":" .. name) ~= 2 then
    fail(("command %s does not exist"):format(name))
  else
    note("command exists: " .. name)
  end
end

local function open_file(path, filetype)
  vim.cmd("edit " .. vim.fn.fnameescape(path))
  if filetype and filetype ~= "" then
    vim.bo.filetype = filetype
  end
  vim.cmd("redraw")
end

local workspace = setup_workspace()
vim.cmd("cd " .. vim.fn.fnameescape(workspace))

trigger_load("folke/snacks.nvim")
assert_command("Notifications")
check("Snacks require", function()
  require("snacks")
  require("snacks.git")
end)
check("Notifications command runs", function()
  vim.cmd("Notifications")
  vim.cmd("enew")
end)

trigger_load("nvim-telescope/telescope.nvim")
check("Telescope require", function()
  local telescope = require("telescope")
  pcall(telescope.load_extension, "fzf")
  pcall(telescope.load_extension, "ui-select")
  pcall(telescope.load_extension, "project")
  pcall(telescope.load_extension, "undo")
end)

trigger_load("nvim-neo-tree/neo-tree.nvim")
assert_command("Neotree")
check("neo-tree require", function()
  require("neo-tree")
end)

trigger_load("folke/trouble.nvim")
assert_command("Trouble")
check("trouble require", function()
  require("trouble")
end)

trigger_load("neo451/feed.nvim")
assert_command("Feed")

trigger_load("pwntester/octo.nvim")
assert_command("Octo")

open_file(join(workspace, "README.md"), "markdown")
check("render-markdown require", function()
  require("render-markdown")
end)
check("markdown treesitter parser available", function()
  local parser = vim.treesitter.get_parser(0, "markdown")
  if not parser then
    error("no markdown parser")
  end
end)

open_file(join(workspace, "notes.norg"), "norg")
check("neorg require", function()
  require("neorg")
end)

if #failures > 0 then
  note(("failed: %d"):format(#failures))
  for _, msg in ipairs(failures) do
    vim.api.nvim_err_writeln("  - " .. msg)
  end
  vim.cmd("cquit 1")
else
  note("all command-focused checks passed")
  vim.cmd("qa")
end
