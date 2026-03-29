vim.bo.expandtab = true
vim.bo.softtabstop = 4
vim.bo.shiftwidth = 4

vim.bo.smartindent = true
vim.bo.autoindent = true

if vim.env.NVIM_STARTUP_DEBUG == "1" then
  vim.print("ftplugin nu")
end
