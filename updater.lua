-- updater.lua: checks GitHub latest release and shows an update dialog
local M = {}

local REPO = "achanam/andlua-id"

-- runs in a separate Lua state (no upvalues): returns tag, url or nil
local function fetch(repo)
  local ok, a, b = pcall(function()
    local URL = luajava.bindClass("java.net.URL")
    local Scanner = luajava.bindClass("java.util.Scanner")
    local conn = URL("https://api.github.com/repos/" .. repo .. "/releases/latest").openConnection()
    conn.setConnectTimeout(8000)
    conn.setReadTimeout(8000)
    conn.setRequestProperty("Accept", "application/vnd.github+json")
    conn.setRequestProperty("User-Agent", "AndLuaID")
    if conn.getResponseCode() ~= 200 then return nil end
    local sc = Scanner(conn.getInputStream(), "UTF-8").useDelimiter("\\A")
    local body = sc.hasNext() and tostring(sc.next()) or ""
    sc.close()
    local tag = body:match('"tag_name"%s*:%s*"([^"]+)"')
    local url = body:match('"html_url"%s*:%s*"(https://github%.com/[^"]-/releases/tag/[^"]+)"')
    return tag, url
  end)
  if ok then return a, b end
end

-- "v1.3-beta2" -> {1, 3, rank, n}; stable > rc > beta > alpha
local function parse(v)
  v = tostring(v or ""):gsub("^[vV]", "")
  local core, pre = v:match("^([%d%.]+)[%-%+]?(.*)$")
  if not core then return nil end
  local key = {}
  for n in core:gmatch("%d+") do key[#key + 1] = tonumber(n) end
  while #key < 3 do key[#key + 1] = 0 end
  local rank, num = 99, 0
  if pre and pre ~= "" then
    local word = pre:lower():match("^%a+") or ""
    rank = ({ alpha = 1, a = 1, beta = 2, b = 2, rc = 3 })[word] or 0
    num = tonumber(pre:match("%d+")) or 0
  end
  key[#key + 1] = rank
  key[#key + 1] = num
  return key
end

local function isNewer(remote, current)
  local a, b = parse(remote), parse(current)
  if not a or not b then return false end
  for i = 1, math.max(#a, #b) do
    local x, y = a[i] or 0, b[i] or 0
    if x ~= y then return x > y end
  end
  return false
end

-- installed version: this app's init.lua first, then the package version
local function currentVersion()
  local v
  pcall(function()
    local env = {}
    local f = loadfile(activity.getLuaDir() .. "/init.lua", "bt", env)
    if f then f() end
    v = env.appver
  end)
  if not v or v == "" then
    pcall(function()
      local pm = activity.getPackageManager()
      v = pm.getPackageInfo(activity.getPackageName(), 0).versionName
    end)
  end
  return v
end

M.isNewer = isNewer

-- check(onNewer): calls onNewer(tag, url) on the UI thread only if a newer release exists
function M.check(onNewer)
  local cur = currentVersion()
  if not cur then return end
  task(fetch, REPO, function(tag, url)
    if tag and isNewer(tag, cur) then
      onNewer(tag, url or ("https://github.com/" .. REPO .. "/releases/latest"))
    end
  end)
end

return M
