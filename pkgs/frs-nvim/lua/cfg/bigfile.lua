local M = {}

M.defaults = {
  enabled = true,
  notify = true,
  size = 1.5 * 1024 * 1024,
  line_length = 1000,
}

local function get_config()
  local ok, snacks = pcall(require, "snacks")
  if ok and snacks and snacks.config and type(snacks.config.get) == "function" then
    return snacks.config.get("bigfile", M.defaults)
  end
  return M.defaults
end

function M.is_bigfile(buf, path)
  buf = buf or 0

  if not vim.api.nvim_buf_is_valid(buf) then
    return false
  end

  if vim.bo[buf].filetype == "bigfile" then
    return true
  end

  path = path or vim.fs.normalize(vim.api.nvim_buf_get_name(buf))
  if not path or path == "" then
    return false
  end

  if path ~= vim.fs.normalize(vim.api.nvim_buf_get_name(buf)) then
    return false
  end

  local opts = get_config()
  local size = vim.fn.getfsize(path)
  if size <= 0 then
    return false
  end

  if size > opts.size then
    return true
  end

  local lines = vim.api.nvim_buf_line_count(buf)
  if lines <= 0 then
    return false
  end

  return (size - lines) / lines > opts.line_length
end

return M
