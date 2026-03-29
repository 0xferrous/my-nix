return {
  {
    "nvim-neorg/neorg",
    version = "*",
    ft = "norg",
    config = function()
      vim.api.nvim_create_autocmd("Filetype", {
        pattern = "norg",
        callback = function()
          local function nmap(lhs, rhs, desc)
            vim.keymap.set("n", lhs, rhs, { buffer = true, desc = desc })
          end

          nmap("<LocalLeader>td", "<Plug>(neorg.qol.todo-items.todo.task-done)", "Mark Neorg task as done")
          nmap("<LocalLeader>tu", "<Plug>(neorg.qol.todo-items.todo.task-undone)", "Mark Neorg task as undone")
          nmap("<LocalLeader>tp", "<Plug>(neorg.qol.todo-items.todo.task-pending)", "Mark Neorg task as pending")
          nmap("<LocalLeader>th", "<Plug>(neorg.qol.todo-items.todo.task-on_hold)", "Mark Neorg task as on hold")
          nmap("<LocalLeader>tc", "<Plug>(neorg.qol.todo-items.todo.task-cancelled)", "Mark Neorg task as cancelled")
          nmap("<LocalLeader>tr", "<Plug>(neorg.qol.todo-items.todo.task-recurring)", "Mark Neorg task as recurring")
          nmap("<LocalLeader>ti", "<Plug>(neorg.qol.todo-items.todo.task-important)", "Mark Neorg task as important")
          nmap("<C-Space>", "<Plug>(neorg.qol.todo-items.todo.task-cycle)", "Cycle Neorg task state")
          nmap("<S-Right>", "<Plug>(neorg.qol.todo-items.todo.task-cycle)", "Cycle Neorg task state")
        end,
      })

      local load = {}
      load["core.defaults"] = {}
      load["core.concealer"] = {}

      local dirman = {
        config = {
          workspaces = {
            work = "~/neorg/work",
            personal = "~/neorg/personal",
          },
          default_workspace = "personal",
        },
      }
      load["core.dirman"] = dirman

      load["core.ui.calendar"] = {}
      load["core.summary"] = {}
      load["core.tangle"] = {}
      load["core.looking-glass"] = {}
      load["core.export"] = {}
      load["core.export.markdown"] = {}

      require("neorg").setup({ load = load })
      vim.wo.foldlevel = 99
    end,
  },
}
