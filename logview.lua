-- logview.lua: logcat viewer with filters. Arg: project path (optional)
require "import"
import "android.widget.*"
import "android.view.*"
import "android.content.*"
import "android.graphics.Typeface"
local T = require "theme"
local U = require "ui"

activity.setTheme(android.R.style.Theme_Material_NoActionBar)
local win = activity.getWindow()
win.setStatusBarColor(T.c("canvas"))
win.setNavigationBarColor(T.c("canvas"))

local root = U.col()
root.setBackgroundColor(T.c("canvas"))

local top = U.row()
top.setGravity(Gravity.CENTER_VERTICAL)
top.setPadding(T.dp(12), T.dp(10), T.dp(12), T.dp(8))
top.addView(U.backButton(function() activity.finish() end), U.lp(T.dp(44), T.dp(44)))
local tt = U.text("Log", 18, "ink", true)
tt.setPadding(T.dp(12), 0, 0, 0)
top.addView(tt, LinearLayout.LayoutParams(0, -2, 1))
root.addView(top, U.lp(-1, -2))

local hs = HorizontalScrollView(activity)
hs.setHorizontalScrollBarEnabled(false)
local bar = U.row()
bar.setPadding(T.dp(12), 0, T.dp(12), T.dp(8))
hs.addView(bar)
root.addView(hs, U.lp(-1, -2))

local scroll = ScrollView(activity)
local out = TextView(activity)
out.setTextColor(T.c("inkMuted"))
out.setTextSize(11)
out.setTypeface(T.font("mono") or Typeface.MONOSPACE)
out.setTextIsSelectable(true)
out.setPadding(T.dp(12), T.dp(8), T.dp(12), T.dp(16))
scroll.addView(out)
root.addView(scroll, LinearLayout.LayoutParams(-1, 0, 1))

-- runs in a separate thread: no upvalues
local function readlog(spec)
  local p = io.popen("logcat -d -v time " .. spec)
  if not p then return "logcat tidak tersedia" end
  local s = p:read("*a")
  p:close()
  s = s:gsub("%-+ beginning of[^\n]*\n", "")
  if #s == 0 then s = "<jalankan app untuk melihat log>" end
  if #s > 60000 then s = s:sub(-60000) end
  return s
end

local function show(s)
  out.setText(s)
  scroll.post(Runnable({ run = function() scroll.fullScroll(View.FOCUS_DOWN) end }))
end

local function loadLog(spec)
  out.setText("memuat...")
  task(readlog, spec, show)
end

local filters = {
  { "Semua", "" }, { "Lua", "lua:* *:S" }, { "Error", "*:E" },
  { "Warn", "*:W" }, { "Info", "*:I" }, { "Debug", "*:D" },
}
for _, f in ipairs(filters) do
  bar.addView(U.button(f[1], "secondary", function() loadLog(f[2]) end), U.lp(-2, -2, 0, 0, 8, 0))
end
bar.addView(U.button("Salin", "secondary", function()
  local cm = activity.getSystemService(Context.CLIPBOARD_SERVICE)
  cm.setText(out.getText())
  Toast.makeText(activity, "Log disalin", Toast.LENGTH_SHORT).show()
end), U.lp(-2, -2, 0, 0, 8, 0))
bar.addView(U.button("Hapus", "primary", function()
  task(function()
    local p = io.popen("logcat -c")
    if p then p:read("*a") p:close() end
    return ""
  end, show)
end))

activity.setContentView(root)
loadLog("lua:* *:S")
