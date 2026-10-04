-- projects.lua: read, create and modify projects under CFG.PROJECT
require "import"
import "java.io.File"
import "java.io.FileOutputStream"
import "android.graphics.Bitmap"
import "android.graphics.BitmapFactory"
local CFG = require "config"

local P = {}

local function read(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  return s
end

local function write(path, s)
  local f = io.open(path, "w")
  if not f then return false end
  f:write(s)
  f:close()
  return true
end

function P.list()
  local root = File(CFG.PROJECT)
  if not root.exists() then root.mkdirs() end
  local out = {}
  local fs = root.listFiles()
  if fs then
    fs = luajava.astable(fs)
    for _, f in ipairs(fs) do
      if f.isDirectory() and File(f.getPath() .. "/init.lua").exists() then
        local env = {}
        local fn = loadfile(f.getPath() .. "/init.lua", "bt", env)
        local ok = fn and pcall(fn)
        table.insert(out, {
          dir  = f.getName(),
          path = f.getPath() .. "/",
          name = ok and env.appname or f.getName(),
          ver  = ok and env.appver or "?",
          code = ok and env.appcode or "1",
          pkg  = ok and env.packagename or "?",
          ok   = ok and true or false,
        })
      end
    end
  end
  table.sort(out, function(a, b) return a.dir:lower() < b.dir:lower() end)
  return out
end

function P.validPackage(s)
  return s:match("^[%a_][%w_]*%.[%a_][%w_%.]*$") ~= nil and not s:find("%.%.") and not s:find("%.$")
end

local function clean(s) return (tostring(s):gsub('["\n\r\\]', "")) end

-- update the 4 init.lua fields without touching user_permission etc.
function P.saveInfo(proj, name, pkg, ver, code)
  local s = read(proj.path .. "init.lua")
  if not s then return false, "init.lua tidak terbaca" end
  local function set(key, val)
    local n
    s, n = s:gsub(key .. '%s*=%s*"[^"]*"', function() return key .. '="' .. clean(val) .. '"' end, 1)
    if n == 0 then s = s .. "\n" .. key .. '="' .. clean(val) .. '"\n' end
  end
  set("appname", name)
  set("packagename", pkg)
  set("appver", ver)
  set("appcode", code)
  if not write(proj.path .. "init.lua", s) then return false, "gagal menulis init.lua" end
  return true
end

-- permissions listed in the project's init.lua -> names (original order)
function P.getPermissions(proj)
  local env = {}
  local fn = loadfile(proj.path .. "init.lua", "bt", env)
  local out = {}
  if fn and pcall(fn) and type(env.user_permission) == "table" then
    for _, v in ipairs(env.user_permission) do
      if type(v) == "string" then table.insert(out, v) end
    end
  end
  return out
end

-- rewrite only the user_permission block; names = permission names
function P.savePermissions(proj, names)
  local s = read(proj.path .. "init.lua")
  if not s then return false, "init.lua tidak terbaca" end
  local lines = {}
  for _, n in ipairs(names) do
    table.insert(lines, '  "' .. clean(n) .. '",')
  end
  local block = "user_permission={\n" .. table.concat(lines, "\n") .. (#lines > 0 and "\n" or "") .. "}"
  local n
  s, n = s:gsub("user_permission%s*=%s*%b{}", function() return block end, 1)
  if n == 0 then s = s .. "\n" .. block .. "\n" end
  if not write(proj.path .. "init.lua", s) then return false, "gagal menulis init.lua" end
  return true
end

-- next free name: Aplikasi, Aplikasi1, Aplikasi2, ...
function P.nextName(base)
  local n = base
  local i = 0
  while File(CFG.PROJECT .. "/" .. n).exists() do
    i = i + 1
    n = base .. i
  end
  return n
end

-- delete a project (only direct folders under CFG.PROJECT)
function P.delete(proj)
  if not proj.dir or proj.dir == "" or proj.dir:find("[/\\]") or proj.dir:find("%.%.") then
    return false, "path tidak aman"
  end
  local d = File(CFG.PROJECT .. "/" .. proj.dir)
  if not d.isDirectory() then return false, "folder tidak ditemukan" end
  LuaUtil.rmDir(d)
  if d.exists() then return false, "gagal menghapus" end
  return true
end

function P.templates()
  local dir = File(activity.getLuaDir() .. "/Template/")
  local out = {}
  local fs = dir.listFiles()
  if fs then
    for _, f in ipairs(luajava.astable(fs)) do
      if f.isDirectory() then table.insert(out, f.getName()) end
    end
  end
  table.sort(out)
  return out
end

local JAVA_MAIN = [===[

public class Main
{
  public static void main(String[] args)
  {

  }
}]===]

-- replace placeholders without treating '%' in the replacement as a pattern
local function fill(path, name, pkg)
  local s = read(path)
  if not s then return end
  s = s:gsub("%$AppName%$", function() return name end)
  s = s:gsub("%$PackageName%$", function() return pkg end)
  write(path, s)
end

-- center crop to a square, scale to 192x192, save as PNG
local function saveIcon(bm, destFile)
  local w, h = bm.getWidth(), bm.getHeight()
  local s = math.min(w, h)
  local sq = Bitmap.createBitmap(bm, math.floor((w - s) / 2), math.floor((h - s) / 2), s, s)
  local out = Bitmap.createScaledBitmap(sq, 192, 192, true)
  local fos = FileOutputStream(destFile)
  out.compress(Bitmap.CompressFormat.PNG, 100, fos)
  fos.close()
end

local function setDefaultIcon(destDir)
  pcall(function()
    local src = activity.getLuaDir() .. "/icon.png"
    if not File(src).exists() then return end
    local bm = BitmapFactory.decodeFile(src)
    if bm then saveIcon(bm, destDir .. "/icon.png") end
  end)
end


-- create a project from Template/<tpl>; returns true, path | false, message
function P.createFromTemplate(tpl, name, pkg)
  if name == "" or name:find("[^%w_%-]") then
    return false, "Nama folder: huruf, angka, _ dan - saja"
  end
  if not P.validPackage(pkg) then return false, "Package tidak valid (contoh: com.contoh.app)" end
  local dest = CFG.PROJECT .. "/" .. name
  if File(dest).isDirectory() then return false, "Nama proyek sudah ada" end
  if not File(dest).mkdirs() then return false, "Gagal membuat folder" end
  LuaUtil.copyDir(activity.getLuaDir() .. "/Template/" .. tpl, dest .. "/")
  setDefaultIcon(dest)
  for _, rel in ipairs(P.files(dest .. "/")) do
    if rel:find("%.lua$") or rel:find("%.aly$") then fill(dest .. "/" .. rel, name, pkg) end
  end
  if tpl == "LuaJava" then
    File(dest .. "/java/build/bin/classes/").mkdirs()
    File(dest .. "/java/jar/").mkdirs()
    local jf = dest .. "/java/src/" .. pkg:gsub("%.", "/") .. "/Main.java"
    File(jf).getParentFile().mkdirs()
    write(jf, "package " .. pkg .. ";\n" .. JAVA_MAIN)
  end
  return true, dest .. "/"
end

-- project files (relative), recursive, max depth 4
local okExt = { lua=1, aly=1, json=1, txt=1, xml=1, md=1, java=1 }
function P.files(path)
  local out = {}
  local function walk(dir, rel, depth)
    if depth > 4 or #out > 300 then return end
    local fs = File(dir).listFiles()
    if not fs then return end
    fs = luajava.astable(fs)
    table.sort(fs, function(a, b) return a.getName():lower() < b.getName():lower() end)
    for _, f in ipairs(fs) do
      local n = f.getName()
      if n:sub(1, 1) ~= "." then
        if f.isDirectory() then
          if n ~= "build" then walk(f.getPath(), rel .. n .. "/", depth + 1) end
        else
          local ext = n:match("%.(%w+)$")
          if ext and okExt[ext:lower()] then table.insert(out, rel .. n) end
        end
      end
    end
  end
  walk(path, "", 0)
  return out
end

function P.newFile(path, name)
  name = name:gsub("[^%w_%-%./]", "")
  if name == "" or name:find("%.%.") then return false, "nama tidak valid" end
  if not name:find("%.%w+$") then name = name .. ".lua" end
  local full = path .. name
  if File(full).exists() then return false, "berkas sudah ada" end
  File(full).getParentFile().mkdirs()
  if not write(full, "") then return false, "gagal membuat berkas" end
  return true, name
end

-- load a thumbnail with sampling (safe for large images)
function P.loadIcon(proj, px)
  local f = proj.path .. "icon.png"
  if not File(f).exists() then return nil end
  local o = BitmapFactory.Options()
  o.inJustDecodeBounds = true
  BitmapFactory.decodeFile(f, o)
  local sample = 1
  while o.outWidth / sample > px * 2 do sample = sample * 2 end
  local o2 = BitmapFactory.Options()
  o2.inSampleSize = sample
  return BitmapFactory.decodeFile(f, o2)
end

function P.setIcon(proj, uri)
  local ins = activity.getContentResolver().openInputStream(uri)
  local bm = BitmapFactory.decodeStream(ins)
  ins.close()
  if not bm then return false, "gambar tidak terbaca" end
  saveIcon(bm, proj.path .. "icon.png")
  return true
end

return P
