local allowed_globals = {}
for key, _ in pairs(_G) do
  table.insert(allowed_globals, key)
end

return {
  build = {
    { atomic = true,           verbose = true },
    { "fnl/**/*macro*.fnl",    false },
    -- put all lua files inside .compiled/lua, note we must still name the
    -- final directory lua/, due to how nvim RTP works.
    { "fnl/ftplugin/**/*.fnl", function(path) return string.gsub(path, "/fnl/ftplugin/", "/.compiled/ftplugin/") end },
    {
      "fnl/**/*.fnl",
      function(path)
        return string.gsub(path, "/fnl/", "/.compiled/lua/")
      end,
    },
    { "init.fnl", true },
  },
  clean = { { ".compiled/lua/**/*.lua", true } },
  compiler = {
    modules = {
      allowedGlobals = allowed_globals,
    },
  },
}
