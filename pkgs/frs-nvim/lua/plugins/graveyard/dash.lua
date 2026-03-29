local string = string
local table = table
local math = math

local function theme_config()
  local theme = require("alpha.themes.startify")
  local section = theme.section
  local button = theme.button

  local session = {
    type = "group",
    val = {
      { type = "padding", val = 1 },
      {
        type = "text",
        val = "Sessions MRU",
        opts = { hl = "SpecialComment" },
      },
      { type = "padding", val = 1 },
      {
        type = "group",
        val = function()
          local auto_session = require("auto-session")
          local cwd = auto_session.get_root_dir()
          local all_sessions = vim.fs.find(function(_, _)
            return true
          end, {
            path = cwd,
            limit = math.huge,
          })
          local sessions_with_mtimes = {}

          for _, session in ipairs(all_sessions) do
            local stat = vim.uv.fs_stat(session)
            if stat then
              table.insert(sessions_with_mtimes, {
                mtime = stat.mtime,
                session = session,
              })
            end
          end

          table.sort(sessions_with_mtimes, function(a, b)
            if a.mtime.sec == b.mtime.sec then
              return a.mtime.nsec >= b.mtime.nsec
            else
              return a.mtime.sec >= b.mtime.sec
            end
          end)

          local results = {}
          local max_sessions = 10
          local total = #sessions_with_mtimes
          local i = 1

          while i <= total and i <= max_sessions do
            local session_mtime = sessions_with_mtimes[i]
            local session_name = vim.fs.basename(session_mtime.session)
            local display = string.gsub(session_name, "%%", "/")
            local path = session_mtime.session

            table.insert(results, {
              type = "button",
              val = display,
              on_press = function()
                auto_session.RestoreSession(path)
              end,
            })
            i = i + 1
          end

          return results
        end,
      },
    },
  }

  local top_buttons = {
    type = "group",
    val = {
      button("e", "New file", "<cmd>ene <CR>"),
      button("s", "Current directory session", "<cmd>SessionRestore<CR>"),
    },
  }

  return {
    layout = {
      { type = "padding", val = 1 },
      section.header,
      { type = "padding", val = 2 },
      top_buttons,
      session,
      { type = "padding", val = 1 },
      section.mru_cwd,
      section.mru,
      { type = "padding", val = 1 },
      section.bottom_buttons,
      section.footer,
    },
    opts = {
      margin = 3,
      redraw_on_resize = false,
      setup = function()
        vim.api.nvim_create_autocmd("DirChanged", {
          pattern = "*",
          group = "alpha_temp",
          callback = function()
            require("alpha").redraw()
            vim.cmd("AlphaRemap")
          end,
        })
      end,
    },
  }
end

return {
  {
    "goolord/alpha-nvim",
    enabled = false,
    config = function()
      local opts = theme_config()
      require("alpha").setup(opts)
    end,
    dependencies = { "rmagatti/auto-session" },
  },
}
