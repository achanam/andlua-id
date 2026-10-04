-- syntaxcheck.lua: validates Lua / AndLua layout (.aly) syntax
local load_ = loadstring or load
local M = {}

-- returns true | false, line, message
function M.check(src, path)
  local code = src
  if path and path:find("%.aly$") then code = "return " .. src end
  local fn, err = load_(code)
  if fn then return true end
  err = tostring(err)
  local line, msg = err:match(":(%d+):%s*(.*)$")
  return false, tonumber(line) or 1, msg or err
end

-- check one file on disk
function M.checkFile(path)
  local f = io.open(path, "r")
  if not f then return false, 1, "file tidak terbaca" end
  local s = f:read("*a")
  f:close()
  return M.check(s, path)
end

-- check all .lua/.aly files in a list of relative paths; returns the errors
function M.checkAll(root, files)
  local errs = {}
  for _, rel in ipairs(files) do
    if rel:find("%.lua$") or rel:find("%.aly$") then
      local ok, line, msg = M.checkFile(root .. rel)
      if not ok then table.insert(errs, { file = rel, line = line, msg = msg }) end
    end
  end
  return errs
end

return M
