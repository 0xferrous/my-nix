local failures = {}

local function note(msg)
  print("[lsp-smoke] " .. msg)
end

local function fail(msg)
  table.insert(failures, msg)
  vim.api.nvim_err_writeln("[lsp-smoke][fail] " .. msg)
end

local function ensure_dir(path)
  vim.fn.mkdir(path, "p")
end

local function write_file(path, lines)
  vim.fn.writefile(lines, path)
end

local function join(...)
  return vim.fs.joinpath(...)
end

local function setup_workspace()
  local root = vim.fn.tempname() .. "-lsp-smoke"
  ensure_dir(root)
  ensure_dir(join(root, ".git"))

  write_file(join(root, "init.lua"), { "return {}" })
  write_file(join(root, "main.ts"), { "const x: number = 1" })
  write_file(join(root, "go.mod"), { "module smoke", "", "go 1.22" })
  write_file(join(root, "main.go"), { "package main", "", "func main() {}" })
  write_file(join(root, "compile_commands.json"), { "[]" })
  write_file(join(root, "main.c"), { "int main(void) { return 0; }" })
  write_file(join(root, "README.md"), { "# smoke" })
  write_file(join(root, "build.zig"), { "pub fn build(b: *std.Build) void {}" })
  write_file(join(root, "main.zig"), { "const std = @import(\"std\");", "pub fn main() void {}" })
  write_file(join(root, "pyproject.toml"), { "[project]", "name = 'smoke'", "version = '0.1.0'" })
  write_file(join(root, "main.py"), { "x: int = 1" })
  write_file(join(root, "main.nu"), { "echo 'hi'" })
  ensure_dir(join(root, ".zk"))

  return root
end

local function stop_clients()
  for _, client in ipairs(vim.lsp.get_clients()) do
    client:stop(true)
  end
  vim.wait(600, function()
    return #vim.lsp.get_clients() == 0
  end, 50)
end

local function ensure_lsp_plugin_loaded()
  local ok_lze, lze = pcall(require, "lze")
  if ok_lze then
    pcall(function()
      lze.trigger_load("neovim/nvim-lspconfig")
    end)
  end

  -- Open one file to make sure BufReadPre path is exercised.
  vim.cmd("edit " .. vim.fn.fnameescape("/tmp/lsp-smoke-bootstrap.lua"))
end

local function has_buf_keymap(buf, lhs)
  for _, map in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
    if map.lhs == lhs then
      return true
    end
  end
  return false
end

local workspace = setup_workspace()
vim.cmd("cd " .. vim.fn.fnameescape(workspace))
ensure_lsp_plugin_loaded()

local enabled = vim.lsp._enabled_configs or {}
local server_names = vim.tbl_keys(enabled)
table.sort(server_names)

if #server_names == 0 then
  fail("no enabled LSP configs found")
end

note("enabled servers: " .. table.concat(server_names, ", "))

local fixtures = {
  lua_ls = { path = "init.lua", filetype = "lua" },
  ts_ls = { path = "main.ts", filetype = "typescript" },
  gopls = { path = "main.go", filetype = "go", extra_bins = { "go" } },
  ccls = { path = "main.c", filetype = "c" },
  marksman = { path = "README.md", filetype = "markdown" },
  zls = { path = "main.zig", filetype = "zig", extra_bins = { "zig" } },
  ty = { path = "main.py", filetype = "python" },
  nushell = { path = "main.nu", filetype = "nu" },
  zk = { path = "README.md", filetype = "markdown" },
  noir = { path = "README.md", filetype = "markdown" },
}

for _, name in ipairs(server_names) do
  local cfg = vim.lsp.config[name]
  local fx = fixtures[name]

  if not cfg then
    fail(("%s: missing vim.lsp.config entry"):format(name))
    goto continue
  end

  if not fx then
    fail(("%s: no smoke fixture defined"):format(name))
    goto continue
  end

  if type(cfg.cmd) ~= "table" or type(cfg.cmd[1]) ~= "string" or cfg.cmd[1] == "" then
    fail(("%s: invalid cmd in config"):format(name))
    goto continue
  end

  local cmd_bin = cfg.cmd[1]
  if vim.fn.exepath(cmd_bin) == "" then
    fail(("%s: missing binary '%s' in PATH"):format(name, cmd_bin))
    goto continue
  end

  for _, bin in ipairs(fx.extra_bins or {}) do
    if vim.fn.exepath(bin) == "" then
      fail(("%s: missing required helper binary '%s' in PATH"):format(name, bin))
      goto continue
    end
  end

  stop_clients()

  vim.cmd("edit " .. vim.fn.fnameescape(join(workspace, fx.path)))
  vim.bo.filetype = fx.filetype

  local attached = vim.wait(2500, function()
    local clients = vim.lsp.get_clients({ bufnr = 0 })
    for _, c in ipairs(clients) do
      if c.name == name then
        return true
      end
    end
    return false
  end, 50)

  if not attached then
    local msgs = vim.api.nvim_exec2("messages", { output = true }).output or ""
    fail(("%s: did not attach for %s (messages: %s)"):format(name, fx.path, msgs:gsub("\n", " | ")))
  else
    note(("ok: %s attached"):format(name))

    for _, lhs in ipairs({ "gd", "gI" }) do
      if not has_buf_keymap(0, lhs) then
        fail(("%s: missing expected LSP buffer keymap %s"):format(name, lhs))
      end
    end

    local ok_cmds, cmds = pcall(vim.api.nvim_buf_get_commands, 0, {})
    if not ok_cmds or type(cmds) ~= "table" or cmds.FormatLsp == nil then
      fail(("%s: missing expected buffer command FormatLsp"):format(name))
    end
  end

  ::continue::
end

stop_clients()

if #failures > 0 then
  note(("failed: %d"):format(#failures))
  for _, f in ipairs(failures) do
    vim.api.nvim_err_writeln("  - " .. f)
  end
  vim.cmd("cquit 1")
else
  note("all configured LSP servers passed")
  vim.cmd("qa")
end
