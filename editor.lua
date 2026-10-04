-- editor.lua: code editor Activity. Arg: project path (ends with "/")
require "import"
import "android.widget.*"
import "android.view.*"
import "java.io.File"
import "android.text.TextUtils"
import "android.os.Handler"
import "android.os.Looper"
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

-- Build / Log buttons (icon + label) above the file tabs
local function actionButton(label, icon, kind, fn)
  local primary = kind == "primary"
  local clr = primary and "onPrimary" or "ink"
  local box = U.row()
  box.setGravity(Gravity.CENTER_VERTICAL)
  box.setPadding(T.dp(12), T.dp(8), T.dp(14), T.dp(8))
  if primary then
    box.setBackground(U.rect("primary", T.r.md))
  else
    box.setBackground(U.rect("surface2", T.r.md, "hairlineStrong"))
  end
  box.addView(U.decorative(U.icon(icon, clr)), U.lp(T.dp(18), T.dp(18), 0, 0, 8, 0))
  local t = U.text(label, 14, clr, true)
  box.addView(t)
  U.describe(box, label)
  if fn then box.onClick = fn end
  return box
end

local buildBtn = actionButton("Build", "build", "primary")  -- handler attached below
local buildRow = U.row()
buildRow.setPadding(T.dp(12), 0, T.dp(12), T.dp(8))
buildRow.addView(buildBtn, U.lp(-2, -2))
buildRow.addView(actionButton("Log", "log", "secondary", function()
  activity.newActivity("logview", { projPath })
end), U.lp(-2, -2, 8, 0, 0, 0))
root.addView(buildRow, U.lp(-1, -2))

local tabsHs = HorizontalScrollView(activity)
tabsHs.setHorizontalScrollBarEnabled(false)
local tabs = U.row()
tabs.setPadding(T.dp(12), 0, T.dp(12), T.dp(8))
tabsHs.addView(tabs)
root.addView(tabsHs, U.lp(-1, -2))

-- red bar with the first syntax error (tap = jump to the line)
local errBar = U.text("", 13, "onPrimary", true)
errBar.setSingleLine(true)
errBar.setEllipsize(TextUtils.TruncateAt.END)
errBar.setPadding(T.dp(12), T.dp(8), T.dp(12), T.dp(8))
errBar.setBackground(U.rect("danger", T.r.md))
errBar.setVisibility(8)
root.addView(errBar, U.lp(-1, -2, 12, 0, 12, 8))

-- editor fills the rest of the screen; the status line floats over its bottom edge
local body = FrameLayout(activity)
root.addView(body, LinearLayout.LayoutParams(-1, 0, 1))

editor = LuaEditor(activity)
body.addView(editor, FrameLayout.LayoutParams(-1, -1))
pcall(function() editor.setTypeface(T.font("mono")) end)

local status = U.text("", 12, "inkSubtle")
status.setPadding(T.dp(12), T.dp(6), T.dp(12), T.dp(6))
status.setSingleLine(true)
status.setBackgroundColor(T.c("surface1"))
status.setVisibility(8)  -- GONE until there is a message
local slp = FrameLayout.LayoutParams(-1, -2)
slp.gravity = Gravity.BOTTOM
body.addView(status, slp)

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
  status.setVisibility(msg == "" and 8 or 0)
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

local errLine
local lastTxt, changedAt, pending = nil, 0, false

local function updateErrBar()
  errLine = nil
  errBar.setVisibility(8)
  if not curFile or not (curFile:find("%.lua$") or curFile:find("%.aly$")) then return end
  local ok, line, msg = SC.check(editor.getText().toString(), curFile)
  if ok then return end
  errLine = line
  errBar.setText("Baris " .. line .. ": " .. msg)
  errBar.setVisibility(0)
end

errBar.onClick = function()
  if errLine then editor.gotoLine(errLine) end
end

-- poll for edits; check once the text has been idle for a moment
local handler = Handler(Looper.getMainLooper())
local ticker
ticker = Runnable({ run = function()
  pcall(function()
    local txt = editor.getText().toString()
    local now = luajava.bindClass("java.lang.System").currentTimeMillis()
    if txt ~= lastTxt then
      lastTxt = txt
      changedAt = now
      pending = true
    elseif pending and now - changedAt >= 250 then
      pending = false
      updateErrBar()
    end
  end)
  handler.postDelayed(ticker, 120)
end })

function openFile(path)
  if curFile then save() end
  curFile = path
  editor.setText(readFile(path))
  title.setText(projName)
  sub.setText("../project/" .. (projPath:match("([^/]+)/?$") or ""))
  setStatus("", "inkSubtle")
  buildTabs()
  lastTxt = editor.getText().toString()
  pending = false
  updateErrBar()
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

---- overflow menu
buildBtn.onClick = function()
  save()
  local ok, bin = pcall(require, "Builder")
  if ok and type(bin) == "function" then
    bin(projPath)
  else
    Toast.makeText(activity, "Builder gagal dimuat: " .. tostring(bin), Toast.LENGTH_LONG).show()
  end
end

moreBtn.onClick = function(v)
  U.popup(moreBtn, {
    { "Berkas baru", newFileDialog, icon = "plus" },
    { "Format", function() editor.format() end, icon = "format" },
    { "Cari / ke baris", findDialog, icon = "search" },
  })
end

---- start
activity.setContentView(root)

local first = projPath .. "main.lua"
if not File(first).exists() then
  local fl = fileList
  first = fl[1] and (projPath .. fl[1]) or nil
end
if first then openFile(first) else setStatus("Proyek kosong", "inkSubtle") end

handler.postDelayed(ticker, 120)

function onPause()
  save()
end

function onDestroy()
  handler.removeCallbacks(ticker)
end
