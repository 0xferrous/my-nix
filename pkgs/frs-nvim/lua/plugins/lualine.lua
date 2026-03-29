local function get_toggleterm_id()
  local winid = vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_get_current_buf()
  local bufvars = vim.b[bufnr]
  local tid = bufvars.toggle_number or "!"
  return "w: " .. winid .. " b: " .. bufnr .. " t: " .. tid
end

return {
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    opts = {
      options = {
        icons_enabled = false,
        theme = "gruvbox",
        component_separators = "|",
        section_separators = "",
        always_show_tabline = true,
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch", "diff", "diagnostics" },
        lualine_c = { { "filename", path = 1 } },
        lualine_x = {
          "encoding",
          "fileformat",
          "filetype",
          function()
            return vim.fn.bufnr()
          end,
          "overseer",
        },
        lualine_y = { "progress" },
        lualine_z = { "location" },
      },
      inactive_sections = {
        lualine_a = { "mode" },
        lualine_b = {},
        lualine_c = { "filename" },
        lualine_x = { "location" },
        lualine_y = {},
      },
    },
  },
}
