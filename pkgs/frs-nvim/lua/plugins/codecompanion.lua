local function keymap(lhs, rhs, desc)
  return {
    lhs,
    rhs,
    mode = { "n", "v" },
    noremap = true,
    silent = true,
    desc = desc,
  }
end

return {
  {
    "olimorris/codecompanion.nvim",
    keys = {
      keymap("<leader>cca", "<cmd>CodeCompanionActions<cr>", "Open cc actions"),
      keymap("<LocalLeader>a", "<cmd>CodeCompanionChat Toggle<cr>", "Toggle cc chat"),
      keymap("ga", "<cmd>CodeCompanionChat Add<cr>", "Add selected code to cc chat"),
    },
    config = function()
      vim.cmd("cab cc CodeCompanion")
      local cc = require("codecompanion")
      local cca = require("codecompanion.adapters")

      cc.setup({
        display = {
          action_palette = { provider = "telescope" },
          diff = { provider = "mini_diff" },
        },
        interactions = {
          chat = {
            adapter = "claude_code",
            roles = {
              llm = function(adapter)
                return "CodeCompanion (" .. adapter.formatted_name .. ")"
              end,
            },
            tools = {
              mcp = {
                callback = function()
                  require("mcphub.extensions.codecompanion")
                end,
                description = "Call tools and resources from MCP servers",
              },
            },
          },
          inline = { adapter = "openrouter" },
        },
        adapters = {
          http = {
            ollama = function()
              return cca.extend("ollama", {
                env = { url = "http://localhost:11434" },
              })
            end,
            openrouter = function()
              return cca.extend("openai_compatible", {
                env = { api_key = os.getenv("OPENROUTER_API_KEY") },
                schema = { model = { default = "google/gemini-2.5-flash" } },
              })
            end,
            gemini = function()
              return cca.extend("gemini", {
                env = { api_key = os.getenv("GEMINI_API_KEY") },
              })
            end,
          },
          acp = {
            claude_code = function()
              return cca.extend("claude_code", {
                env = {
                  CLAUDE_CODE_OAUTH_TOKEN = "cmd: jq -r .claudeAiOauth.accessToken ~/.claude/.credentials.json",
                },
              })
            end,
          },
        },
        opts = { log_level = "ERROR" },
      })

      local ccf = require("cfg.code_companion_fidget")
      local telescope = require("telescope")
      ccf:init()
      telescope.load_extension("codecompanion")
    end,
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      "j-hui/fidget.nvim",
      {
        "echasnovski/mini.diff",
        config = function()
          local diff = require("mini.diff")
          diff.setup({ source = diff.gen_source.none() })
        end,
      },
      "nvim-telescope/telescope.nvim",
    },
  },
  {
    "ravitemer/mcphub.nvim",
    dependencies = { { "nvim-lua/plenary.nvim" } },
    cmd = "MCPHub",
    opts = {
      extensions = {
        codecompanion = { show_result_in_chat = false },
      },
    },
  },
}
