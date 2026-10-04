-- ui.lua: small UI components (Linear style, built in code, no .aly)
require "import"
import "android.widget.*"
import "android.view.*"
import "android.graphics.drawable.GradientDrawable"
import "android.graphics.drawable.ColorDrawable"
import "android.graphics.Path"
import "android.graphics.Paint"
import "android.app.AlertDialog"
local T = require "theme"

local U = {}

function U.rect(fill, radius, stroke)
  local d = GradientDrawable()
  d.setColor(T.c(fill))
  d.setCornerRadius(T.dp(radius or 0))
  if stroke then d.setStroke(T.dp(1), T.c(stroke)) end
  return d
end

-- linear LayoutParams: w,h (-1 fill / -2 wrap), margins l,t,r,b in dp
function U.lp(w, h, l, t, r, b)
  local p = LinearLayout.LayoutParams(w, h)
  p.setMargins(T.dp(l or 0), T.dp(t or 0), T.dp(r or 0), T.dp(b or 0))
  return p
end

function U.text(str, size, color, bold)
  local v = TextView(activity)
  v.setText(str)
  v.setTextSize(size or 14)
  v.setTextColor(T.c(color or "ink"))
  if bold then v.getPaint().setFakeBoldText(true) end
  return v
end

function U.col(pad)
  local v = LinearLayout(activity)
  v.setOrientation(LinearLayout.VERTICAL)
  if pad then v.setPadding(T.dp(pad), T.dp(pad), T.dp(pad), T.dp(pad)) end
  return v
end

function U.row()
  local v = LinearLayout(activity)
  v.setOrientation(LinearLayout.HORIZONTAL)
  return v
end

function U.card()
  local v = U.col(16)
  v.setBackground(U.rect("surface1", T.r.lg, "hairline"))
  return v
end

-- kind: "primary" | "secondary" | "danger"
function U.button(label, kind, fn)
  local v = TextView(activity)
  v.setText(label)
  v.setTextSize(14)
  v.setGravity(Gravity.CENTER)
  v.getPaint().setFakeBoldText(true)
  v.setPadding(T.dp(14), T.dp(10), T.dp(14), T.dp(10))
  if kind == "primary" then
    v.setTextColor(T.c("onPrimary"))
    v.setBackground(U.rect("primary", T.r.md))
  elseif kind == "danger" then
    v.setTextColor(T.c("onPrimary"))
    v.setBackground(U.rect("danger", T.r.md))
  else
    v.setTextColor(T.c("ink"))
    v.setBackground(U.rect("surface2", T.r.md, "hairlineStrong"))
  end
  if fn then v.onClick = fn end
  return v
end

function U.input(hint, value)
  local v = EditText(activity)
  v.setHint(hint)
  v.setText(value or "")
  v.setSingleLine(true)
  v.setTextSize(15)
  v.setTextColor(T.c("ink"))
  v.setHintTextColor(T.c("inkTertiary"))
  v.setBackground(U.rect("surface2", T.r.md, "hairlineStrong"))
  v.setPadding(T.dp(12), T.dp(10), T.dp(12), T.dp(10))
  return v
end

function U.field(parent, label, hint, value)
  parent.addView(U.text(label, 12, "inkSubtle"), U.lp(-1, -2, 0, 12, 0, 4))
  local e = U.input(hint, value)
  parent.addView(e, U.lp(-1, -2))
  return e
end

-- Accessibility: spoken labels for icon-only controls (screen readers)
local LABEL = {
  play = "Jalankan", undo = "Urungkan", redo = "Ulangi", more = "Menu",
  back = "Kembali", save = "Simpan", format = "Format", check = "Cek",
  checkall = "Cek semua", search = "Cari", log = "Log", plus = "Tambah",
  build = "Build", info = "Info", trash = "Hapus",
}

function U.describe(view, text)
  pcall(function() view.setContentDescription(text) end)
end

-- decorative views are skipped by screen readers (IMPORTANT_FOR_ACCESSIBILITY_NO = 2)
function U.decorative(view)
  pcall(function() view.setImportantForAccessibility(2) end)
  return view
end

function U.burger(fn)
  local box = U.col()
  box.setGravity(Gravity.CENTER)
  for i = 1, 2 do
    local bar = U.decorative(View(activity))
    bar.setBackground(U.rect("ink", 1))
    box.addView(bar, U.lp(T.dp(20), T.dp(2), 0, i == 1 and 0 or 6, 0, 0))
  end
  U.describe(box, "Menu")
  if fn then box.onClick = fn end
  return box
end

-- burger <-> X animation (open = true gives X); takes the box from U.burger
function U.burgerMorph(box, open)
  local b1, b2 = box.getChildAt(0), box.getChildAt(1)
  U.describe(box, open and "Tutup menu" or "Menu")
  local d = T.dp(4)                              -- tengah antar-garis: (2dp + 6dp) / 2
  b1.animate().rotation(open and 45 or 0).translationY(open and d or 0).setDuration(200).start()
  b2.animate().rotation(open and -45 or 0).translationY(open and -d or 0).setDuration(200).start()
end

-- gradient strip: "from" (theme token or hex) fading to transparent downward
function U.fadeTop(from)
  local v = View(activity)
  local hex = T[from or "canvas"] or from
  local c1 = T.c(hex)
  local c2 = T.c("#00" .. hex:sub(-6))  -- same color at alpha 0
  v.setBackground(GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM, { c1, c2 }))
  return v
end

function U.fadeSide(to)
  local v = View(activity)
  local hex = T[to or "canvas"] or to
  local c1 = T.c("#00" .. hex:sub(-6))
  local c2 = T.c(hex)
  v.setBackground(GradientDrawable(GradientDrawable.Orientation.LEFT_RIGHT, { c1, c2 }))
  return v
end

-- Small vector icons drawn with Canvas (24x24 grid); falls back to a text glyph on failure.
-- fill: undo | redo | play | more
-- stroke: plus | save | format | check | checkall | search | log | chevron | back | build | info | trash | instagram | globe | github
local GLYPH = {
  undo = "↶", redo = "↷", play = "▶", more = "⋯",
  plus = "+", save = "S", format = "≡", check = "✓", checkall = "✓✓", search = "Q", log = ">_", chevron = "▾", back = "‹", build = "B", info = "i", trash = "x",
  instagram = "IG", globe = "◍", github = "GH",
}

function U.icon(kind, color)
  local ok, v = pcall(function()
    local LuaDrawable = luajava.bindClass("com.androlua.LuaDrawable")
    local CW = luajava.bindClass("android.graphics.Path$Direction").CW
    local path = Path()
    local stroke = false
    local sw = 2
    local function poly(...)
      local a = { ... }
      path.moveTo(a[1], a[2])
      for k = 3, #a, 2 do path.lineTo(a[k], a[k + 1]) end
    end

    if kind == "more" then
      path.addCircle(5, 12, 2, CW)
      path.addCircle(12, 12, 2, CW)
      path.addCircle(19, 12, 2, CW)
    elseif kind == "play" then
      poly(8, 5, 8, 19, 19, 12)
      path.close()
    elseif kind == "undo" or kind == "redo" then
      path.moveTo(12.5, 8)
      path.cubicTo(9.85, 8, 7.45, 8.99, 5.6, 10.6)
      path.lineTo(2, 7)
      path.lineTo(2, 16)
      path.lineTo(11, 16)
      path.lineTo(7.38, 12.38)
      path.cubicTo(8.77, 11.22, 10.54, 10.5, 12.5, 10.5)
      path.cubicTo(16.04, 10.5, 19.05, 12.81, 20.1, 16)
      path.lineTo(22.47, 15.22)
      path.cubicTo(21.08, 11.03, 17.15, 8, 12.5, 8)
      path.close()
    elseif kind == "plus" then
      stroke = true
      poly(12, 5, 12, 19)
      poly(5, 12, 19, 12)
    elseif kind == "save" then
      stroke = true
      path.moveTo(19, 21)
      path.lineTo(5, 21)
      path.quadTo(3, 21, 3, 19)
      path.lineTo(3, 5)
      path.quadTo(3, 3, 5, 3)
      path.lineTo(16, 3)
      path.lineTo(21, 8)
      path.lineTo(21, 19)
      path.quadTo(21, 21, 19, 21)
      path.close()
      poly(17, 21, 17, 13, 7, 13, 7, 21)
      poly(7, 3, 7, 8, 15, 8)
    elseif kind == "format" then
      stroke = true
      poly(17, 10, 3, 10)
      poly(21, 6, 3, 6)
      poly(21, 14, 3, 14)
      poly(17, 18, 3, 18)
    elseif kind == "check" then
      stroke = true
      poly(4, 12, 9, 17, 20, 6)
    elseif kind == "checkall" then
      stroke = true
      path.addCircle(12, 12, 9, CW)
      poly(7.5, 12, 10.5, 15, 16.5, 9)
    elseif kind == "search" then
      stroke = true
      path.addCircle(11, 11, 7, CW)
      poly(21, 21, 16.1, 16.1)
    elseif kind == "build" then
      stroke = true
      poly(12, 2.5, 20.5, 7.25, 20.5, 16.75, 12, 21.5, 3.5, 16.75, 3.5, 7.25)
      path.close()
      poly(3.5, 7.25, 12, 12, 20.5, 7.25)
      poly(12, 12, 12, 21.5)
    elseif kind == "info" then
      stroke = true
      path.addCircle(12, 12, 9, CW)
      poly(12, 11, 12, 16.5)
      poly(12, 7.6, 12, 7.7)
    elseif kind == "trash" then
      stroke = true
      poly(3, 6, 21, 6)
      path.moveTo(19, 6)
      path.lineTo(19, 20)
      path.quadTo(19, 22, 17, 22)
      path.lineTo(7, 22)
      path.quadTo(5, 22, 5, 20)
      path.lineTo(5, 6)
      path.moveTo(8, 6)
      path.lineTo(8, 4)
      path.quadTo(8, 2, 10, 2)
      path.lineTo(14, 2)
      path.quadTo(16, 2, 16, 4)
      path.lineTo(16, 6)
      poly(10, 11, 10, 17)
      poly(14, 11, 14, 17)
    elseif kind == "back" then
      stroke = true
      sw = 1.75
      poly(15.5, 5, 8.5, 12, 15.5, 19)
    elseif kind == "chevron" then
      stroke = true
      poly(6, 9, 12, 15, 18, 9)
    elseif kind == "log" then
      stroke = true
      poly(4, 17, 10, 11, 4, 5)
      poly(12, 19, 20, 19)
    elseif kind == "instagram" then
      stroke = true
      local RectF = luajava.bindClass("android.graphics.RectF")
      path.addRoundRect(RectF(3, 3, 21, 21), 5.5, 5.5, CW)
      path.addCircle(12, 12, 4, CW)
      poly(17.5, 6.5, 17.5, 6.6)
    elseif kind == "globe" then
      stroke = true
      local RectF = luajava.bindClass("android.graphics.RectF")
      path.addCircle(12, 12, 9, CW)
      path.addOval(RectF(8, 3, 16, 21), CW)
      poly(3, 12, 21, 12)
    elseif kind == "github" then
      stroke = true
      sw = 1.8
      path.moveTo(9, 19)
      path.cubicTo(4, 20.5, 4, 16.5, 2, 16)
      path.moveTo(16, 22)
      path.lineTo(16, 18.13)
      path.quadTo(16, 16.6, 15.06, 15.52)
      path.cubicTo(18.2, 15.17, 21.5, 13.98, 21.5, 8.52)
      path.quadTo(21.5, 6.2, 20, 4.77)
      path.quadTo(20.2, 2.8, 19.91, 1)
      path.cubicTo(19.91, 1, 18.73, 0.65, 16, 2.48)
      path.quadTo(12.5, 1.9, 9, 2.48)
      path.cubicTo(6.27, 0.65, 5.09, 1, 5.09, 1)
      path.quadTo(4.8, 2.8, 5, 4.77)
      path.quadTo(3.5, 6.2, 3.5, 8.55)
      path.cubicTo(3.5, 13.97, 6.8, 15.16, 9.94, 15.55)
      path.quadTo(9, 16.5, 9, 18.13)
      path.lineTo(9, 22)
    else
      error("ikon tidak dikenal: " .. tostring(kind))
    end

    local paint = Paint()
    paint.setAntiAlias(true)
    paint.setColor(T.c(color or "ink"))
    if stroke then
      paint.setStyle(luajava.bindClass("android.graphics.Paint$Style").STROKE)
      paint.setStrokeWidth(sw)
      paint.setStrokeCap(luajava.bindClass("android.graphics.Paint$Cap").ROUND)
      paint.setStrokeJoin(luajava.bindClass("android.graphics.Paint$Join").ROUND)
    end
    local mirror = (kind == "redo")
    local function draw(c, p, d)
      local b = d.getBounds()
      local w, h = b.width(), b.height()
      local sc = math.min(w, h) / 24
      c.save()
      c.translate((w - 24 * sc) / 2, (h - 24 * sc) / 2)
      c.scale(sc, sc)
      if mirror then
        c.scale(-1, 1)
        c.translate(-24, 0)
      end
      c.drawPath(path, paint)
      c.restore()
    end
    local view = View(activity)
    view.setBackground(LuaDrawable(draw))
    return view
  end)
  if ok and v then return v end
  local t = U.text(GLYPH[kind] or "?", 18, color or "ink")
  t.setGravity(Gravity.CENTER)
  return t
end

function U.iconButton(kind, fn, color, label)
  local box = U.col()
  box.setGravity(Gravity.CENTER)
  box.addView(U.decorative(U.icon(kind, color or "ink")), U.lp(T.dp(22), T.dp(22)))
  U.describe(box, label or LABEL[kind] or kind)
  if fn then box.onClick = fn end
  return box
end

function U.backButton(fn)
  local box = U.col()
  box.setGravity(Gravity.CENTER)
  box.setBackground(U.rect("surface2", T.r.pill, "hairlineStrong"))  -- radius is clamped, so this becomes a circle
  box.addView(U.decorative(U.icon("back", "ink")), U.lp(T.dp(22), T.dp(22)))
  U.describe(box, "Kembali")
  if fn then box.onClick = fn end
  return box
end

-- Themed popup menu (replaces the default PopupMenu); shows below the anchor, right-aligned.
-- items = { {"Label", fn [, "danger"], icon = "name", check = true}, ... } (icon and check are optional)
function U.popup(anchor, items, width)
  local W = width or T.dp(200)  -- optional width in px (e.g. anchor width for dropdowns)
  local hasIcon = false
  for _, it in ipairs(items) do if it.icon then hasIcon = true end end
  local box = U.col(6)
  box.setBackground(U.rect("surface2", T.r.lg, "hairlineStrong"))
  local pw = PopupWindow(box, W, -2, true)  -- focusable: outside tap / back dismisses
  pw.setBackgroundDrawable(ColorDrawable(0))
  pw.setOutsideTouchable(true)
  for _, it in ipairs(items) do
    if it[3] == "danger" then
      local line = View(activity)
      line.setBackgroundColor(T.c("hairline"))
      box.addView(line, U.lp(-1, T.dp(1), 8, 4, 8, 4))
    end
    local clr = (it[3] == "danger") and "danger" or "ink"
    local row = U.row()
    row.setGravity(Gravity.CENTER_VERTICAL)
    row.setPadding(T.dp(12), T.dp(12), T.dp(12), T.dp(12))
    if it.icon then
      row.addView(U.decorative(U.icon(it.icon, clr)), U.lp(T.dp(20), T.dp(20), 0, 0, 12, 0))
    elseif hasIcon then
      row.addView(View(activity), U.lp(T.dp(20), T.dp(20), 0, 0, 12, 0))  -- spacer keeps the text aligned
    end
    row.addView(U.text(it[1], 15, clr), LinearLayout.LayoutParams(0, -2, 1))
    if it.check then
      row.addView(U.decorative(U.icon("check", "primary")), U.lp(T.dp(18), T.dp(18), 8, 0, 0, 0))
      U.describe(row, it[1] .. ", dipilih")
    end
    row.onClick = function()
      pw.dismiss()
      if it[2] then it[2]() end
    end
    box.addView(row, U.lp(-1, -2))
  end
  pw.showAsDropDown(anchor, anchor.getWidth() - W, T.dp(4))
  return pw
end

function U.dialog(view, locked)
  local b = AlertDialog.Builder(activity)
  b.setView(view)
  if locked then b.setCancelable(false) end
  local d = b.create()
  if locked then d.setCanceledOnTouchOutside(false) end
  d.show()
  d.getWindow().setBackgroundDrawable(U.rect("surface1", T.r.xl, "hairline"))
  return d
end

-- round photo from an image file; nil on failure so callers can fall back
function U.avatar(path, sizeDp)
  local ok, v = pcall(function()
    local f = luajava.bindClass("java.io.File")(path)
    if not f.exists() then return nil end
    local BF = luajava.bindClass("android.graphics.BitmapFactory")
    local Bitmap = luajava.bindClass("android.graphics.Bitmap")
    local Canvas = luajava.bindClass("android.graphics.Canvas")
    local Shader = luajava.bindClass("android.graphics.BitmapShader")
    local Mode = luajava.bindClass("android.graphics.Shader$TileMode")
    local S = T.dp(sizeDp)
    local src = BF.decodeFile(path)
    if not src then return nil end
    local scaled = Bitmap.createScaledBitmap(src, S, S, true)
    local out = Bitmap.createBitmap(S, S, Bitmap.Config.ARGB_8888)
    local c = Canvas(out)
    local p = Paint()
    p.setAntiAlias(true)
    p.setShader(Shader(scaled, Mode.CLAMP, Mode.CLAMP))
    c.drawCircle(S / 2, S / 2, S / 2, p)
    local iv = ImageView(activity)
    iv.setImageBitmap(out)
    return iv
  end)
  if ok then return v end
  return nil
end

-- verified badge, white by default
function U.verified(color, checkColor)
  local ok, v = pcall(function()
    local LuaDrawable = luajava.bindClass("com.androlua.LuaDrawable")
    local CW = luajava.bindClass("android.graphics.Path$Direction").CW
    local Style = luajava.bindClass("android.graphics.Paint$Style")
    local Cap = luajava.bindClass("android.graphics.Paint$Cap")
    local Join = luajava.bindClass("android.graphics.Paint$Join")
    local badge = Path()
    badge.addCircle(12, 12, 7.6, CW)
    for k = 0, 7 do
      local a = math.rad(k * 45)
      badge.addCircle(12 + 7.4 * math.cos(a), 12 + 7.4 * math.sin(a), 3.6, CW)
    end
    local tick = Path()
    tick.moveTo(7.8, 12.4)
    tick.lineTo(10.7, 15.2)
    tick.lineTo(16.4, 9.2)
    local fill = Paint()
    fill.setAntiAlias(true)
    fill.setColor(T.c(color or "ink"))
    local line = Paint()
    line.setAntiAlias(true)
    line.setColor(T.c(checkColor or "canvas"))
    line.setStyle(Style.STROKE)
    line.setStrokeWidth(2.2)
    line.setStrokeCap(Cap.ROUND)
    line.setStrokeJoin(Join.ROUND)
    local function draw(c, p, d)
      local b = d.getBounds()
      local sc = math.min(b.width(), b.height()) / 24
      c.save()
      c.translate((b.width() - 24 * sc) / 2, (b.height() - 24 * sc) / 2)
      c.scale(sc, sc)
      c.drawPath(badge, fill)
      c.drawPath(tick, line)
      c.restore()
    end
    local view = View(activity)
    view.setBackground(LuaDrawable(draw))
    return view
  end)
  if ok and v then return v end
  local t = U.text("✓", 14, color or "ink", true)
  t.setGravity(Gravity.CENTER)
  return t
end

return U
