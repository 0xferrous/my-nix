local function fail(msg)
  vim.api.nvim_err_writeln(msg)
  vim.cmd("cquit 1")
end

local function ok(msg)
  print("[ok] " .. msg)
end

local ok_lze, lze = pcall(require, "lze")
if not ok_lze then
  fail("failed to require lze")
end

local targets = {
  "neovim/nvim-lspconfig",
  "nvim-telescope/telescope.nvim",
  "folke/snacks.nvim",
  "nvim-neotest/neotest",
  "nvim-neorg/neorg",
  "RRethy/vim-illuminate",
  "MeanderingProgrammer/render-markdown.nvim",
  "zk-org/zk-nvim",
}

for _, name in ipairs(targets) do
  local ok_trigger, err = pcall(function()
    lze.trigger_load(name)
  end)
  if not ok_trigger then
    fail(("failed trigger_load(%s): %s"):format(name, tostring(err)))
  end
  ok("trigger_load(" .. name .. ")")
end

-- Regression test: dependencies declared under top-level specs must become loadable
-- specs as well. rustaceanvim is declared as a dependency of nvim-lspconfig.
local ok_rustacean, rustacean_err = pcall(require, "rustaceanvim")
if not ok_rustacean then
  fail(("dependency flatten/load failed for rustaceanvim: %s"):format(tostring(rustacean_err)))
end
ok("require(rustaceanvim)")

local checks = {
  { "neotest", "neotest" },
  { "neotest-foundry", "neotest-foundry" },
  { "render-markdown", "render-markdown" },
}

for _, check in ipairs(checks) do
  local label, mod = check[1], check[2]
  local ok_require, err = pcall(require, mod)
  if not ok_require then
    fail(("failed require(%s): %s"):format(label, tostring(err)))
  end
  ok("require(" .. label .. ")")
end

print("[ok] smoke-lazy complete")
vim.cmd("qa")
