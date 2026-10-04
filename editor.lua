-- editor.lua: code editor Activity. Arg: project path (ends with "/")
require "import"
import "android.widget.*"
import "android.view.*"
import "java.io.File"
import "android.text.TextUtils"
local T  = require "theme"
local U  = require "ui"
local P  = require "projects"
local SC = require "syntaxcheck"
pcall(function() import "com.androlua.LuaEditor" end)

local projPath = ...
local curFile
local openFile, buildTabs
local editor
local run  -- forward declaration (the play button in the top bar uses it)
local fileList = P.files(projPath)

local projName
do
  local env = {}
  local fn = loadfile(projPath .. "init.lua", "bt", env)
  if fn and pcall(fn) and type(env.appname) == "string" and env.appname ~= "" then
    projName = env.appname
  end
  projName = projName or projPath:match("([^/]+)/?$") or "Proyek"
end

activity.setTheme(android.R.style.Theme_Material_NoActionBar)
local win = activity.getWindow()
win.setStatusBarColor(T.c("canvas"))
win.setNavigationBarColor(T.c("canvas"))
win.setSoftInputMode(0x10) -- ADJUST_RESIZE

---- utils
local function readFile(p)
  local f = io.open(p, "r")
  if not f then return "" end
  local s = f:read("*a")
  f:close()
  return s
end

local function writeFile(p, s)
  local f = io.open(p, "w")
  if not f then return false end
  f:write(s)
  f:close()
  return true
end

---- layout
local root = U.col()
root.setBackgroundColor(T.c("canvas"))

local top = U.row()
top.setGravity(Gravity.CENTER_VERTICAL)
top.setPadding(T.dp(12), T.dp(10), T.dp(12), T.dp(10))
root.addView(top, U.lp(-1, -2))

local back = U.backButton(function() activity.finish() end)
top.addView(back, U.lp(T.dp(44), T.dp(44)))

local titleBox = U.col()
titleBox.setPadding(T.dp(12), 0, T.dp(8), 0)
local title = U.text("", 15, "ink", true)
title.setSingleLine(true)
title.setEllipsize(TextUtils.TruncateAt.END)
local sub = U.text("", 11, "inkSubtle")
sub.setSingleLine(true)
sub.setEllipsize(TextUtils.TruncateAt.END)
titleBox.addView(title)
titleBox.addView(sub)
top.addView(titleBox, LinearLayout.LayoutParams(0, -2, 1))

top.addView(U.iconButton("play", function() run() end, "primary"), U.lp(T.dp(40), T.dp(40)))
top.addView(U.iconButton("undo", function() editor.undo() end), U.lp(T.dp(40), T.dp(40)))
top.addView(U.iconButton("redo", function() editor.redo() end), U.lp(T.dp(40), T.dp(40)))
-- menu items are attached below (the function is defined later)
local moreBtn = U.iconButton("more", nil)
top.addView(moreBtn, U.lp(T.dp(40), T.dp(40)))

local tabsHs = HorizontalScrollView(activity)
tabsHs.setHorizontalScrollBarEnabled(false)
local tabs = U.row()
tabs.setPadding(T.dp(12), 0, T.dp(12), T.dp(8))
tabsHs.addView(tabs)
root.addView(tabsHs, U.lp(-1, -2))

editor = LuaEditor(activity)
root.addView(editor, LinearLayout.LayoutParams(-1, 0, 1))

local status = U.text("", 12, "inkSubtle")
status.setPadding(T.dp(12), T.dp(6), T.dp(12), T.dp(6))
status.setSingleLine(true)
root.addView(status, U.lp(-1, -2))

local sh = HorizontalScrollView(activity)
sh.setHorizontalScrollBarEnabled(false)
local sym = U.row()
sym.setPadding(T.dp(8), T.dp(4), T.dp(8), T.dp(8))
sh.addView(sym)
root.addView(sh, U.lp(-1, -2))

-- editor colors (method names vary between versions; safe if missing)
local function tryset(m, v)
  pcall(function() editor[m](v) end)
end
tryset("setBackgroundColor", T.c("canvas"))
tryset("setTextColor", T.c("ink"))
tryset("setBaseWordColor", T.c("inkMuted"))
tryset("setKeywordColor", T.c("primaryHover"))
tryset("setStringColor", T.c("success"))
tryset("setCommentColor", T.c("inkTertiary"))
tryset("setUserwordColor", T.c("inkMuted"))
tryset("setPanelBackgroundColor", T.c("surface2"))
tryset("setPanelTextColor", T.c("ink"))

---- actions
local function setStatus(msg, color)
  status.setText(msg)
  status.setTextColor(T.c(color or "inkSubtle"))
end

local function save()
  if not curFile then return end
  if writeFile(curFile, editor.getText().toString()) then
    setStatus("Tersimpan", "inkSubtle")
  else
    setStatus("Gagal menyimpan", "danger")
  end
end

local function checkNow(silent)
  if not curFile then return true end
  if not (curFile:find("%.lua$") or curFile:find("%.aly$")) then
    if not silent then setStatus("Bukan berkas Lua/aly", "inkSubtle") end
    return true
  end
  local ok, line, msg = SC.check(editor.getText().toString(), curFile)
  if ok then
    if not silent then setStatus("Sintaks OK", "success") end
    return true
  end
  editor.gotoLine(line)
  setStatus("Baris " .. line .. ": " .. msg, "danger")
  return false
end

function openFile(path)
  if curFile then save() end
  curFile = path
  editor.setText(readFile(path))
  title.setText(projName)
  sub.setText("../project/" .. (projPath:match("([^/]+)/?$") or ""))
  setStatus("", "inkSubtle")
  buildTabs()
end

local function newFileDialog()
  local d = U.col(20)
  d.addView(U.text("Berkas baru", 18, "ink", true))
  local e = U.field(d, "Nama (mis. page2 atau sub/util.lua)", "page2", "")
  local err = U.text("", 12, "danger")
  d.addView(err, U.lp(-1, -2, 0, 8, 0, 0))
  local d2 = U.dialog(d)
  d.addView(U.button("Buat", "primary", function()
    local ok, r = P.newFile(projPath, e.getText().toString())
    if not ok then err.setText(r) return end
    d2.dismiss()
    fileList = P.files(projPath)
    openFile(projPath .. r)
  end), U.lp(-1, -2, 0, 12, 0, 0))
end

function buildTabs()
  tabs.removeAllViews()
  for _, rel in ipairs(fileList) do
    local active = (projPath .. rel == curFile)
    local t = U.text(rel, 13, active and "ink" or "inkSubtle", active)
    t.setSingleLine(true)
    t.setPadding(T.dp(12), T.dp(7), T.dp(12), T.dp(7))
    if active then
      t.setBackground(U.rect("surface2", T.r.md, "primary"))
    else
      t.setBackground(U.rect("surface1", T.r.md, "hairline"))
    end
    t.onClick = function() openFile(projPath .. rel) end
    tabs.addView(t, U.lp(-2, -2, 0, 0, 6, 0))
    if active then
      tabsHs.post(Runnable({ run = function() tabsHs.smoothScrollTo(math.max(0, t.getLeft() - T.dp(24)), 0) end }))
    end
  end
end

local function findDialog()
  local d = U.col(20)
  d.addView(U.text("Cari / ke baris", 18, "ink", true))
  local eFind = U.field(d, "Cari teks", "kata", "")
  local eLine = U.field(d, "Ke baris nomor", "1", "")
  local dlg = U.dialog(d)
  local row = U.row()
  row.setGravity(Gravity.RIGHT)
  d.addView(row, U.lp(-1, -2, 0, 14, 0, 0))
  row.addView(U.button("Cari", "secondary", function()
    local q = eFind.getText().toString()
    if q ~= "" then dlg.dismiss() editor.findNext(q) end
  end))
  row.addView(U.button("Ke baris", "primary", function()
    local n = tonumber(eLine.getText().toString())
    if n then dlg.dismiss() editor.gotoLine(math.floor(n)) end
  end), U.lp(-2, -2, 8, 0, 0, 0))
end

local function checkAll()
  save()
  local errs = SC.checkAll(projPath, P.files(projPath))
  if #errs == 0 then
    setStatus("Semua berkas OK", "success")
    return
  end
  local e = errs[1]
  setStatus(#errs .. " error · " .. e.file .. ":" .. e.line .. "  " .. e.msg, "danger")
  openFile(projPath .. e.file)
  editor.gotoLine(e.line)
end

run = function()
  save()
  if File(projPath .. "java/").isDirectory() then
    setStatus("Proyek ada folder java/ — pakai Build", "danger")
    return
  end
  local errs = SC.checkAll(projPath, P.files(projPath))
  if #errs > 0 then
    local e = errs[1]
    openFile(projPath .. e.file)
    editor.gotoLine(e.line)
    setStatus(e.file .. ":" .. e.line .. "  " .. e.msg, "danger")
    return
  end
  activity.newActivity(projPath .. "main.lua")
end

---- overflow menu & symbols
moreBtn.onClick = function(v)
  U.popup(moreBtn, {
    { "Build", function()
        save()
        local ok, bin = pcall(require, "Builder")
        if ok and type(bin) == "function" then
          bin(projPath)
        else
          Toast.makeText(activity, "Builder gagal dimuat: " .. tostring(bin), Toast.LENGTH_LONG).show()
        end
      end, icon = "build" },
    { "Berkas baru", newFileDialog, icon = "plus" },
    { "Simpan", save, icon = "save" },
    { "Format", function() editor.format() end, icon = "format" },
    { "Cek", function() checkNow(false) end, icon = "check" },
    { "Cek semua", checkAll, icon = "checkall" },
    { "Cari / ke baris", findDialog, icon = "search" },
    { "Log", function() activity.newActivity("logview", { projPath }) end, icon = "log" },
  })
end

local pairs_ = { ["("] = ")", ["["] = "]", ["{"] = "}", ['"'] = '"', ["'"] = "'" }
local symbols = { "Tab", "(", ")", "[", "]", "{", "}", '"', "'", "=", ":", ".", ",", ";",
  "_", "+", "-", "*", "/", "\\", "|", "%", "#", "$", "?", "<", ">", "~", "@" }
for _, s in ipairs(symbols) do
  local b = U.button(s, "secondary", function()
    if s == "Tab" then
      editor.paste("  ")
    elseif pairs_[s] then
      editor.paste(s .. pairs_[s])
      editor.setSelection(editor.getSelectionEnd() - 1)
    else
      editor.paste(s)
    end
  end)
  b.setPadding(T.dp(12), T.dp(8), T.dp(12), T.dp(8))
  sym.addView(b, U.lp(-2, -2, 0, 0, 6, 0))
end

---- start
activity.setContentView(root)

local first = projPath .. "main.lua"
if not File(first).exists() then
  local fl = fileList
  first = fl[1] and (projPath .. fl[1]) or nil
end
if first then openFile(first) else setStatus("Proyek kosong", "inkSubtle") end

function onPause()
  save()
end
