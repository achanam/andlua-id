require "import"
import "android.widget.*"
import "android.view.*"
import "java.io.File"
import "java.lang.Runnable"
import "android.content.*"
import "android.net.Uri"
local T   = require "theme"
local U   = require "ui"
local CFG = require "config"
local P   = require "projects"
local PERMS = require "permissions"
local bin = require "Builder"

activity.setTheme(android.R.style.Theme_Material_NoActionBar)
local win = activity.getWindow()
-- edge-to-edge: content and menu overlay draw behind the status/navigation bars
win.setStatusBarColor(T.c("#00000000"))
win.setNavigationBarColor(T.c("#00000000"))
pcall(function() win.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS) end)
pcall(function() win.setNavigationBarContrastEnforced(false) end)
win.getDecorView().setSystemUiVisibility(1792)  -- LAYOUT_STABLE | HIDE_NAVIGATION | FULLSCREEN

---- layout
local frame = FrameLayout(activity)
frame.setBackgroundColor(T.c("canvas"))

local root = U.col()
root.setBackgroundColor(T.c("canvas"))
frame.addView(root, FrameLayout.LayoutParams(-1, -1))

local NAV_BG = "#B3010102"  -- ~70% opaque

-- list runs under the translucent navbar
local NAV_H = 72
local content = FrameLayout(activity)

local scroll = ScrollView(activity)
local listBox = U.col()
listBox.setPadding(T.dp(16), T.dp(NAV_H + 12), T.dp(16), T.dp(96))
scroll.addView(listBox)
content.addView(scroll, FrameLayout.LayoutParams(-1, -1))

local nav = U.row()
nav.setGravity(Gravity.CENTER_VERTICAL)
nav.setPadding(T.dp(20), T.dp(8), T.dp(16), 0)
nav.setBackgroundColor(T.c(NAV_BG))
nav.addView(U.text("AndLua ID", 20, "ink", true), LinearLayout.LayoutParams(0, -2, 1))
content.addView(nav, FrameLayout.LayoutParams(-1, T.dp(NAV_H), Gravity.TOP))

-- fade below the navbar instead of a divider line
local fadeLp = FrameLayout.LayoutParams(-1, T.dp(24), Gravity.TOP)
fadeLp.setMargins(0, T.dp(NAV_H), 0, 0)
local navFade = U.fadeTop(NAV_BG)
content.addView(navFade, fadeLp)

root.addView(content, LinearLayout.LayoutParams(-1, 0, 1))

local bar = U.col()
bar.setPadding(T.dp(16), T.dp(8), T.dp(16), T.dp(16))
root.addView(bar, U.lp(-1, -2))

local refresh

---- permissions dialog
local function editPermissions(proj, onSaved)
  local sel, known, extras = {}, {}, {}
  for _, it in ipairs(PERMS) do known[it[1]] = true end
  for _, n in ipairs(P.getPermissions(proj)) do
    if known[n] then sel[n] = true else table.insert(extras, n) end  -- keep permissions that are not in the known list
  end

  local v = U.col(20)
  v.addView(U.text("Izin aplikasi", 18, "ink", true))
  local count = U.text("", 12, "inkSubtle")
  v.addView(count, U.lp(-1, -2, 0, 2, 0, 0))

  local boxes = {}
  local function paint(name)
    local b = boxes[name]
    if sel[name] then
      b.setText("✓")
      b.setBackground(U.rect("primary", 6))
    else
      b.setText("")
      b.setBackground(U.rect("surface2", 6, "hairlineStrong"))
    end
  end
  local function recount()
    local n = 0
    for _ in pairs(sel) do n = n + 1 end
    count.setText(n .. " dari " .. #PERMS .. " dipilih")
  end

  local tools = U.row()
  v.addView(tools, U.lp(-1, -2, 0, 12, 0, 8))
  tools.addView(U.button("Pilih semua", "secondary", function()
    for _, it in ipairs(PERMS) do sel[it[1]] = true paint(it[1]) end
    recount()
  end), U.lp(-2, -2, 0, 0, 8, 0))
  tools.addView(U.button("Kosongkan", "secondary", function()
    for _, it in ipairs(PERMS) do sel[it[1]] = nil paint(it[1]) end
    recount()
  end))

  local sv = ScrollView(activity)
  local list = U.col()
  sv.addView(list)
  local maxH = math.floor(activity.getResources().getDisplayMetrics().heightPixels * 0.5)
  v.addView(sv, U.lp(-1, maxH))

  for _, it in ipairs(PERMS) do
    local name, desc = it[1], it[2]
    local row = U.row()
    row.setGravity(Gravity.CENTER_VERTICAL)
    row.setPadding(T.dp(4), T.dp(10), T.dp(4), T.dp(10))

    local box = TextView(activity)
    box.setGravity(Gravity.CENTER)
    box.setTextSize(14)
    box.setTextColor(T.c("onPrimary"))
    boxes[name] = box
    row.addView(box, U.lp(T.dp(22), T.dp(22), 0, 0, 12, 0))

    local info = U.col()
    info.addView(U.text(desc, 14, "ink"))
    info.addView(U.text(name, 11, "inkTertiary"), U.lp(-1, -2, 0, 1, 0, 0))
    row.addView(info, LinearLayout.LayoutParams(0, -2, 1))

    row.onClick = function()
      sel[name] = (not sel[name]) or nil
      paint(name)
      recount()
    end
    list.addView(row, U.lp(-1, -2))

    local line = View(activity)
    line.setBackgroundColor(T.c("hairline"))
    list.addView(line, U.lp(-1, T.dp(1)))
    paint(name)
  end
  recount()

  local err = U.text("", 12, "danger")
  v.addView(err, U.lp(-1, -2, 0, 8, 0, 0))
  local btns = U.row()
  btns.setGravity(Gravity.RIGHT)
  v.addView(btns, U.lp(-1, -2, 0, 12, 0, 0))

  local dlg = U.dialog(v)
  btns.addView(U.button("Batal", "secondary", function() dlg.dismiss() end))
  btns.addView(U.button("Simpan", "primary", function()
    local names = {}
    for _, it in ipairs(PERMS) do
      if sel[it[1]] then table.insert(names, it[1]) end
    end
    for _, n in ipairs(extras) do table.insert(names, n) end
    local ok, why = P.savePermissions(proj, names)
    if not ok then err.setText(why) return end
    dlg.dismiss()
    if onSaved then onSaved(#names) end
  end), U.lp(-2, -2, 8, 0, 0, 0))
end

---- info dialog
local pickIcon  -- forward declaration, defined in the icon section below
local function editInfo(proj)
  local v = U.col(20)
  v.addView(U.text("Info aplikasi", 18, "ink", true))
  v.addView(U.text(proj.dir, 12, "inkSubtle"), U.lp(-1, -2, 0, 2, 0, 0))

  local iconRow = U.row()
  iconRow.setGravity(Gravity.CENTER_VERTICAL)
  iconRow.setPadding(T.dp(12), T.dp(10), T.dp(12), T.dp(10))
  iconRow.setBackground(U.rect("surface2", T.r.md, "hairlineStrong"))
  local icView = ImageView(activity)
  icView.setScaleType(ImageView.ScaleType.CENTER_CROP)
  icView.setBackground(U.rect("surface3", T.r.md, "hairline"))
  iconRow.addView(icView, U.lp(T.dp(44), T.dp(44), 0, 0, 12, 0))
  local icText = U.col()
  icText.addView(U.text("Ikon aplikasi", 14, "ink"))
  icText.addView(U.text("Ketuk untuk ganti", 12, "inkSubtle"), U.lp(-1, -2, 0, 2, 0, 0))
  iconRow.addView(icText, LinearLayout.LayoutParams(0, -2, 1))
  iconRow.addView(U.text("›", 18, "inkSubtle"))
  v.addView(iconRow, U.lp(-1, -2, 0, 14, 0, 2))
  local function showIcon()
    local bm = P.loadIcon(proj, 44)
    if bm then icView.setImageBitmap(bm) end
  end
  showIcon()
  iconRow.onClick = function() pickIcon(proj, showIcon) end

  local eName = U.field(v, "Nama aplikasi", "My App", proj.name)
  local ePkg  = U.field(v, "Package", "com.contoh.app", proj.pkg)
  local row = U.row()
  v.addView(row, U.lp(-1, -2))
  local c1, c2 = U.col(), U.col()
  c2.setPadding(T.dp(8), 0, 0, 0)
  row.addView(c1, LinearLayout.LayoutParams(0, -2, 1))
  row.addView(c2, LinearLayout.LayoutParams(0, -2, 1))
  local eVer  = U.field(c1, "Versi", "1.0", proj.ver)
  local eCode = U.field(c2, "Kode versi", "1", tostring(proj.code))

  v.addView(U.text("Izin (permission)", 12, "inkSubtle"), U.lp(-1, -2, 0, 12, 0, 4))
  local permRow = U.row()
  permRow.setGravity(Gravity.CENTER_VERTICAL)
  permRow.setPadding(T.dp(12), T.dp(12), T.dp(12), T.dp(12))
  permRow.setBackground(U.rect("surface2", T.r.md, "hairlineStrong"))
  local permLabel = U.text("", 14, "ink")
  permRow.addView(permLabel, LinearLayout.LayoutParams(0, -2, 1))
  permRow.addView(U.text("›", 18, "inkSubtle"))
  v.addView(permRow, U.lp(-1, -2))
  local function setPermLabel(n) permLabel.setText(n .. " izin dipilih") end
  setPermLabel(#P.getPermissions(proj))
  permRow.onClick = function() editPermissions(proj, setPermLabel) end

  local err = U.text("", 12, "danger")
  v.addView(err, U.lp(-1, -2, 0, 10, 0, 0))

  local btns = U.row()
  btns.setGravity(Gravity.RIGHT)
  v.addView(btns, U.lp(-1, -2, 0, 16, 0, 0))

  local scroller = ScrollView(activity)  -- scrolls when the keyboard is open
  scroller.addView(v)
  local dlg = U.dialog(scroller)
  btns.addView(U.button("Batal", "secondary", function() dlg.dismiss() end))
  btns.addView(U.button("Simpan", "primary", function()
    local name, pkg = eName.getText().toString(), ePkg.getText().toString()
    local ver, code = eVer.getText().toString(), eCode.getText().toString()
    if name == "" then err.setText("Nama tidak boleh kosong") return end
    if not P.validPackage(pkg) then err.setText("Package tidak valid (contoh: com.contoh.app)") return end
    if ver == "" or not tonumber(code) then err.setText("Versi/kode versi tidak valid") return end
    local ok, why = P.saveInfo(proj, name, pkg, ver, tostring(math.floor(tonumber(code))))
    if not ok then err.setText(why) return end
    dlg.dismiss()
    refresh()
  end), U.lp(-2, -2, 8, 0, 0, 0))
end

---- new project dialog
local function newProject()
  local tpls = P.templates()
  local chosen = tpls[1] or "Default"
  local v = U.col(20)
  v.addView(U.text("Proyek baru", 18, "ink", true))
  v.addView(U.text("Template", 12, "inkSubtle"), U.lp(-1, -2, 0, 12, 0, 4))

  local dd = U.row()
  dd.setGravity(Gravity.CENTER_VERTICAL)
  dd.setPadding(T.dp(14), T.dp(12), T.dp(12), T.dp(12))
  dd.setBackground(U.rect("surface2", T.r.md, "hairlineStrong"))
  local ddLabel = U.text(chosen, 15, "ink")
  dd.addView(ddLabel, LinearLayout.LayoutParams(0, -2, 1))
  dd.addView(U.decorative(U.icon("chevron", "inkSubtle")), U.lp(T.dp(18), T.dp(18)))
  v.addView(dd, U.lp(-1, -2))
  dd.onClick = function()
    local items = {}
    for _, name in ipairs(tpls) do
      items[#items + 1] = {
        name,
        function() chosen = name ddLabel.setText(name) end,
        check = (name == chosen),
      }
    end
    U.popup(dd, items, dd.getWidth())
  end

  local defName = P.nextName("Aplikasi")
  local eName = U.field(v, "Nama proyek", "Aplikasi", defName)
  local ePkg  = U.field(v, "Package", "com.andlua.aplikasi", "com.andlua." .. defName:lower())
  local err = U.text("", 12, "danger")
  v.addView(err, U.lp(-1, -2, 0, 10, 0, 0))
  local row = U.row()
  row.setGravity(Gravity.RIGHT)
  v.addView(row, U.lp(-1, -2, 0, 16, 0, 0))
  local dlg = U.dialog(v)
  row.addView(U.button("Batal", "secondary", function() dlg.dismiss() end))
  row.addView(U.button("Buat", "primary", function()
    local ok, r = P.createFromTemplate(chosen, eName.getText().toString(), ePkg.getText().toString())
    if not ok then err.setText(r) return end
    dlg.dismiss()
    refresh()
    activity.newActivity("editor", { r })
  end), U.lp(-2, -2, 8, 0, 0, 0))
end

---- delete dialog
local function confirmDelete(proj)
  local v = U.col(20)
  v.addView(U.text("Hapus proyek?", 18, "ink", true))
  v.addView(U.text((proj.name and proj.name ~= "") and proj.name or proj.dir, 14, "ink", true), U.lp(-1, -2, 0, 10, 0, 0))
  v.addView(U.text("Semua berkas di dalamnya akan dihapus permanen dan tidak bisa dikembalikan.", 12, "inkSubtle"),
    U.lp(-1, -2, 0, 6, 0, 0))
  local err = U.text("", 12, "danger")
  v.addView(err, U.lp(-1, -2, 0, 8, 0, 0))
  local row = U.row()
  row.setGravity(Gravity.RIGHT)
  v.addView(row, U.lp(-1, -2, 0, 14, 0, 0))
  local dlg = U.dialog(v)
  row.addView(U.button("Batal", "secondary", function() dlg.dismiss() end))
  row.addView(U.button("Hapus", "danger", function()
    local ok, why = P.delete(proj)
    if not ok then err.setText(why) return end
    dlg.dismiss()
    refresh()
  end), U.lp(-2, -2, 8, 0, 0, 0))
end

---- icon
local pendingIcon, pendingDone
pickIcon = function(proj, onDone)
  pendingIcon, pendingDone = proj, onDone
  local i = Intent(Intent.ACTION_GET_CONTENT)
  i.setType("image/*")
  activity.startActivityForResult(i, 77)
end

function onActivityResult(req, res, data)
  if req == 77 and res == -1 and data and pendingIcon then
    local ok, r, why = pcall(P.setIcon, pendingIcon, data.getData())
    if ok and r then
      Toast.makeText(activity, "Ikon dipasang (192x192)", Toast.LENGTH_SHORT).show()
      if pendingDone then pcall(pendingDone) end  -- refresh the preview in the info dialog
    else
      Toast.makeText(activity, "Gagal: " .. tostring(ok and why or r), Toast.LENGTH_LONG).show()
    end
    pendingIcon, pendingDone = nil, nil
    refresh()
  end
end

---- project list
function refresh()
  listBox.removeAllViews()
  local items = P.list()

  if #items == 0 then
    local empty = U.card()
    empty.addView(U.text("Belum ada proyek", 16, "ink", true))
    empty.addView(U.text("Taruh folder proyek di\n" .. CFG.PROJECT .. "\natau buat baru di bawah.", 13, "inkSubtle"),
      U.lp(-1, -2, 0, 6, 0, 0))
    listBox.addView(empty, U.lp(-1, -2, 0, 8, 0, 0))
    return
  end

  for _, proj in ipairs(items) do
    local card = U.card()
    card.setPadding(T.dp(14), T.dp(12), T.dp(12), T.dp(12))

    local head = U.row()
    head.setGravity(Gravity.CENTER_VERTICAL)
    card.addView(head, U.lp(-1, -2))

    local ic = ImageView(activity)
    ic.setScaleType(ImageView.ScaleType.CENTER_CROP)
    ic.setBackground(U.rect("surface3", T.r.md, "hairline"))
    local bm = P.loadIcon(proj, 48)
    if bm then ic.setImageBitmap(bm) end
    head.addView(U.decorative(ic), U.lp(T.dp(48), T.dp(48), 0, 0, 12, 0))

    local info = U.col()
    info.addView(U.text(proj.name, 17, "ink", true))
    info.addView(U.text("v" .. proj.ver .. "  |  " .. proj.pkg, 12, "inkSubtle"), U.lp(-1, -2, 0, 2, 0, 0))
    head.addView(info, LinearLayout.LayoutParams(0, -2, 1))

    local more = U.button("⋯", "secondary", nil)
    U.describe(more, "Opsi " .. proj.name)
    head.addView(more)
    more.onClick = function(v)
      U.popup(v, {
        { "Build",         function() bin(proj.path) end, icon = "build" },
        { "Info aplikasi", function() editInfo(proj) end, icon = "info" },
        { "Log",           function() activity.newActivity("logview", { proj.path }) end, icon = "log" },
        { "Hapus proyek",  function() confirmDelete(proj) end, "danger", icon = "trash" },
      })
    end

    if not proj.ok then
      card.addView(U.text("init.lua bermasalah", 12, "danger"), U.lp(-1, -2, 0, 8, 0, 0))
    end

    card.onClick = function()
      activity.newActivity("editor", { proj.path })
    end

    listBox.addView(card, U.lp(-1, -2, 0, 8, 0, 0))
  end
end

---- menu overlay
local PANEL_W = T.dp(260)
local EDGE_W  = T.dp(1)  -- left edge stroke
local WRAP_W  = PANEL_W + EDGE_W
local menuOpen = false

-- blur needs Android 12+ (API 31); below that, use a near-solid dark panel
local CAN_BLUR = luajava.bindClass("android.os.Build$VERSION").SDK_INT >= 31
local GLASS      = CAN_BLUR and "#26FFFFFF" or "#F5141516"
local BLUR_R = 24

local function setBlur(r)
  if not CAN_BLUR then return end
  pcall(function()
    if r <= 0.5 then
      root.setRenderEffect(nil)
    else
      local RE = luajava.bindClass("android.graphics.RenderEffect")
      local TM = luajava.bindClass("android.graphics.Shader$TileMode")
      root.setRenderEffect(RE.createBlurEffect(r, r, TM.CLAMP))
    end
  end)
end

local function animBlur(from, to)
  if not CAN_BLUR then return end
  local ok = pcall(function()
    local a = luajava.bindClass("android.animation.ValueAnimator").ofFloat({ from, to })
    a.setDuration(200)
    a.addUpdateListener(luajava.bindClass("android.animation.ValueAnimator$AnimatorUpdateListener")({
      onAnimationUpdate = function(an) setBlur(an.getAnimatedValue()) end
    }))
    a.start()
  end)
  if not ok then setBlur(to) end
end

local overlay = FrameLayout(activity)
overlay.setBackgroundColor(T.c(CAN_BLUR and "#59000000" or "#99000000"))
overlay.setVisibility(View.GONE)
frame.addView(overlay, FrameLayout.LayoutParams(-1, -1))

local wrap = U.row()
overlay.addView(wrap, FrameLayout.LayoutParams(WRAP_W, -1, Gravity.RIGHT))
local edge = View(activity)
edge.setBackgroundColor(T.c("#40FFFFFF"))
wrap.addView(edge, LinearLayout.LayoutParams(EDGE_W, -1))

local panel = U.col()
panel.setBackground(U.rect(GLASS, 0))
panel.setPadding(0, T.dp(20), 0, T.dp(16))
panel.onClick = function() end  -- swallow taps so the panel doesn't close the overlay
wrap.addView(panel, LinearLayout.LayoutParams(PANEL_W, -1))

-- burger is added last so it stays above the overlay and morphs into X
local burger = U.burger()
local burgerLp = FrameLayout.LayoutParams(T.dp(40), T.dp(40), Gravity.TOP + Gravity.RIGHT)
burgerLp.setMargins(0, T.dp(20), T.dp(16), 0)  -- top is corrected in applyInsets
frame.addView(burger, burgerLp)

local function closeMenu()
  if not menuOpen then return end
  menuOpen = false
  U.burgerMorph(burger, false)
  animBlur(BLUR_R, 0)
  local function hide()
    if not menuOpen then overlay.setVisibility(View.GONE) end
  end
  local ok = pcall(function()
    overlay.animate().alpha(0).setDuration(150).start()
    wrap.animate().translationX(WRAP_W).setDuration(160)
      .withEndAction(Runnable({ run = hide })).start()
  end)
  if not ok then hide() end
end

local function openMenu()
  menuOpen = true
  U.burgerMorph(burger, true)
  animBlur(0, BLUR_R)
  overlay.setVisibility(View.VISIBLE)
  overlay.setAlpha(0)
  wrap.setTranslationX(WRAP_W)
  overlay.animate().alpha(1).setDuration(160).start()
  wrap.animate().translationX(0).setDuration(180).start()
end

overlay.onClick = function() closeMenu() end
burger.onClick = function()
  if menuOpen then closeMenu() else openMenu() end
end

local menuLabel = U.text("MENU", 11, "inkTertiary", true)
menuLabel.setPadding(T.dp(20), 0, T.dp(20), 0)
menuLabel.setGravity(Gravity.CENTER_VERTICAL)
panel.addView(menuLabel, U.lp(-1, T.dp(40), 0, 0, 0, 8))

local function addMenuItem(label, fn)
  local t = U.text(label, 16, "ink")
  t.setPadding(T.dp(12), T.dp(14), T.dp(12), T.dp(14))
  t.onClick = fn
  panel.addView(t, U.lp(-1, -2, 8, 0, 8, 0))
end

---- developer & credits dialogs
local CRED = require "credits"

local function openUrl(url)
  pcall(function() activity.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url))) end)
end

local DM = activity.getResources().getDisplayMetrics()
local DLG_W = math.min(DM.widthPixels - T.dp(40), T.dp(400))
local MS = View.MeasureSpec

-- shared by the Developer dialog and the Credits height measurement
local function buildDeveloper(onClose)
  local D = CRED.developer
  local v = U.col(20)
  v.setGravity(Gravity.CENTER_HORIZONTAL)

  local photo = U.avatar(activity.getLuaDir() .. "/avatar.png", 84)
  if photo then
    v.addView(photo, U.lp(T.dp(84), T.dp(84), 0, 4, 0, 0))
  else
    local initials = ""
    for w in (D.alias or D.name):gmatch("%S+") do initials = initials .. w:sub(1, 1):upper() end
    local av = U.col()
    av.setGravity(Gravity.CENTER)
    av.setBackground(U.rect("surface3", T.r.pill, "primary"))
    local it = U.text(initials, 24, "primaryHover", true)
    it.setGravity(Gravity.CENTER)
    av.addView(it, U.lp(-2, -2))
    v.addView(av, U.lp(T.dp(84), T.dp(84), 0, 4, 0, 0))
  end

  local nameRow = U.row()
  nameRow.setGravity(Gravity.CENTER)
  nameRow.addView(U.text(D.name, 22, "ink", true), U.lp(-2, -2))
  nameRow.addView(U.verified("ink", "surface1"), U.lp(T.dp(20), T.dp(20), 6, 2, 0, 0))
  v.addView(nameRow, U.lp(-1, -2, 0, 14, 0, 0))

  if D.alias then
    local al = U.text("Also known as " .. D.alias, 12, "inkSubtle")
    al.setGravity(Gravity.CENTER)
    v.addView(al, U.lp(-1, -2, 0, 2, 0, 0))
  end

  local function pill(txt)
    local t = U.text(txt, 11, "inkMuted")
    t.setPadding(T.dp(10), T.dp(4), T.dp(10), T.dp(4))
    t.setBackground(U.rect("surface2", T.r.pill, "hairline"))
    return t
  end
  local rolesBox = U.col()
  rolesBox.setGravity(Gravity.CENTER_HORIZONTAL)
  local rowA, rowB = U.row(), U.row()
  rowA.setGravity(Gravity.CENTER)
  rowB.setGravity(Gravity.CENTER)
  for i, r in ipairs(D.roles) do
    local target = (i <= 2) and rowA or rowB
    target.addView(pill(r), U.lp(-2, -2, 3, 0, 3, 0))
  end
  rolesBox.addView(rowA, U.lp(-2, -2))
  rolesBox.addView(rowB, U.lp(-2, -2, 0, 6, 0, 0))
  v.addView(rolesBox, U.lp(-2, -2, 0, 12, 0, 0))

  local line = View(activity)
  line.setBackgroundColor(T.c("hairline"))
  v.addView(line, U.lp(-1, T.dp(1), 0, 20, 0, 12))

  for _, l in ipairs(D.links) do
    local row = U.row()
    row.setGravity(Gravity.CENTER_VERTICAL)
    row.setPadding(T.dp(14), T.dp(12), T.dp(14), T.dp(12))
    row.setBackground(U.rect("surface2", T.r.md, "hairline"))
    row.addView(U.decorative(U.icon(l.kind, "inkMuted")), U.lp(T.dp(22), T.dp(22)))
    local tx = U.col()
    tx.addView(U.text(l.title, 14, "ink", true))
    tx.addView(U.text(l.sub, 12, "inkSubtle"), U.lp(-1, -2, 0, 1, 0, 0))
    local tlp = LinearLayout.LayoutParams(0, -2, 1)
    tlp.setMargins(T.dp(14), 0, T.dp(8), 0)
    row.addView(tx, tlp)
    row.addView(U.text("›", 20, "inkTertiary"), U.lp(-2, -2))
    row.onClick = function() openUrl(l.url) end
    v.addView(row, U.lp(-1, -2, 0, 8, 0, 0))
  end

  local brow = U.row()
  brow.setGravity(Gravity.RIGHT)
  v.addView(brow, U.lp(-1, -2, 0, 18, 0, 0))
  brow.addView(U.button("Close", "secondary", function() if onClose then onClose() end end))
  return v
end

local devHeight
local function getDevHeight()
  if devHeight then return devHeight end
  local ok, h = pcall(function()
    local v = buildDeveloper(nil)
    v.measure(MS.makeMeasureSpec(DLG_W, MS.EXACTLY), MS.makeMeasureSpec(0, MS.UNSPECIFIED))
    return v.getMeasuredHeight()
  end)
  devHeight = math.min((ok and h) or T.dp(520), DM.heightPixels - T.dp(96))
  return devHeight
end

local function developerDialog()
  local dlg
  local v = buildDeveloper(function() dlg.dismiss() end)
  local scroller = ScrollView(activity)
  scroller.addView(v)
  dlg = U.dialog(scroller)
  pcall(function() dlg.getWindow().setLayout(DLG_W, -2) end)
end

-- same style as Developer: fixed title, scrollable body, sticky Close button
local function stickyDialog(title, sub, fillBody)
  local dlg
  local outer = U.col()

  local head = U.col()
  head.setPadding(T.dp(20), T.dp(20), T.dp(20), T.dp(8))
  head.addView(U.text(title, 18, "ink", true))
  if sub then
    head.addView(U.text(sub, 13, "inkSubtle"), U.lp(-1, -2, 0, 4, 0, 0))
  end
  outer.addView(head, U.lp(-1, -2))

  local body = U.col()
  body.setPadding(T.dp(20), T.dp(4), T.dp(20), T.dp(12))
  fillBody(body)
  local scroller = ScrollView(activity)
  scroller.addView(body)
  outer.addView(scroller, LinearLayout.LayoutParams(-1, 0, 1))

  local wrap = U.col()
  local fline = View(activity)
  fline.setBackgroundColor(T.c("hairline"))
  wrap.addView(fline, U.lp(-1, T.dp(1)))
  local foot = U.col()
  foot.setPadding(T.dp(20), T.dp(12), T.dp(20), T.dp(16))
  local brow = U.row()
  brow.setGravity(Gravity.RIGHT)
  brow.addView(U.button("Close", "secondary", function() dlg.dismiss() end))
  foot.addView(brow, U.lp(-1, -2))
  wrap.addView(foot, U.lp(-1, -2))
  outer.addView(wrap, U.lp(-1, -2))

  dlg = U.dialog(outer)
  pcall(function() dlg.getWindow().setLayout(DLG_W, getDevHeight()) end)
end

local function creditsDialog()
  stickyDialog("Credits", "AndLua ID is built upon the following work:", function(body)
    for _, src in ipairs(CRED.sources) do
      local card = U.col(12)
      card.setBackground(U.rect("surface2", T.r.md, "hairline"))
      card.addView(U.text(src.name, 15, "ink", true))
      card.addView(U.text("by " .. src.by, 12, "inkSubtle"), U.lp(-1, -2, 0, 2, 0, 0))
      card.addView(U.text(src.note, 13, "inkMuted"), U.lp(-1, -2, 0, 6, 0, 0))
      if src.url then
        local link = U.text(src.url, 12, "primary")
        link.setPadding(0, T.dp(6), 0, T.dp(2))
        link.onClick = function() openUrl(src.url) end
        card.addView(link, U.lp(-1, -2))
      end
      body.addView(card, U.lp(-1, -2, 0, 8, 0, 0))
    end
    body.addView(U.text(CRED.disclaimer, 12, "inkSubtle"), U.lp(-1, -2, 0, 14, 0, 0))
    body.addView(U.text(CRED.mitTitle, 12, "inkSubtle", true), U.lp(-1, -2, 0, 14, 0, 4))
    local mit = U.text(CRED.mit, 11, "inkTertiary")
    mit.setTextIsSelectable(true)
    body.addView(mit, U.lp(-1, -2))
  end)
end

local function aboutDialog()
  local A = CRED.about
  stickyDialog(A.title, A.sub, function(body)
    for i, sec in ipairs(A.sections) do
      body.addView(U.text(sec.heading, 14, "ink", true), U.lp(-1, -2, 0, i == 1 and 4 or 16, 0, 4))
      if sec.text then
        local t = U.text(sec.text, 13, "inkMuted")
        pcall(function() t.setLineSpacing(0, 1.2) end)
        body.addView(t, U.lp(-1, -2))
      end
      if sec.items then
        for _, it in ipairs(sec.items) do
          local r = U.row()
          r.addView(U.text("•", 13, "primaryHover"), U.lp(-2, -2, 0, 0, 8, 0))
          r.addView(U.text(it, 13, "inkMuted"), LinearLayout.LayoutParams(0, -2, 1))
          body.addView(r, U.lp(-1, -2, 0, 3, 0, 0))
        end
      end
    end
  end)
end

addMenuItem("Developer", function()
  closeMenu()
  developerDialog()
end)
addMenuItem("Credits", function()
  closeMenu()
  creditsDialog()
end)
addMenuItem("About", function()
  closeMenu()
  aboutDialog()
end)
-- back button closes the menu first
function onKeyDown(code, event)
  if code == KeyEvent.KEYCODE_BACK and menuOpen then
    closeMenu()
    return true
  end
end

bar.addView(U.button("+  Proyek baru", "primary", newProject), U.lp(-1, -2))

---- system bar insets
local function applyInsets(top, bottom)
  nav.setPadding(T.dp(20), top + T.dp(8), T.dp(16), 0)
  local nlp = nav.getLayoutParams()
  nlp.height = top + T.dp(NAV_H)
  nav.setLayoutParams(nlp)
  listBox.setPadding(T.dp(16), top + T.dp(NAV_H + 12), T.dp(16), T.dp(96))
  fadeLp.setMargins(0, top + T.dp(NAV_H), 0, 0)
  navFade.setLayoutParams(fadeLp)
  bar.setPadding(T.dp(16), T.dp(8), T.dp(16), T.dp(16) + bottom)
  panel.setPadding(0, top + T.dp(20), 0, bottom + T.dp(16))
  burgerLp.setMargins(0, top + T.dp(20), T.dp(16), 0)
  burger.setLayoutParams(burgerLp)
end

local function barH(name)
  local r = activity.getResources()
  local id = r.getIdentifier(name, "dimen", "android")
  return id > 0 and r.getDimensionPixelSize(id) or 0
end
applyInsets(barH("status_bar_height"), 0)  -- initial value; the listener below corrects it

frame.setOnApplyWindowInsetsListener(View.OnApplyWindowInsetsListener({
  onApplyWindowInsets = function(v, ins)
    pcall(function()
      applyInsets(ins.getSystemWindowInsetTop(), ins.getSystemWindowInsetBottom())
    end)
    return ins
  end
}))

activity.setContentView(frame)
refresh()

function onResume()
  refresh()
end
