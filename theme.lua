-- theme.lua: design tokens (Linear style: dark, single lavender accent)
require "import"
local T = {
  primary       = "#5e6ad2",
  primaryHover  = "#828fff",
  onPrimary     = "#ffffff",
  ink           = "#f7f8f8",
  inkMuted      = "#d0d6e0",
  inkSubtle     = "#8a8f98",
  inkTertiary   = "#62666d",
  canvas        = "#010102",
  surface1      = "#0f1011",
  surface2      = "#141516",
  surface3      = "#18191a",
  hairline      = "#23252a",
  hairlineStrong= "#34343a",
  success       = "#27a644",
  danger        = "#e5484d",

  -- radius and spacing in dp
  r = { sm = 6, md = 8, lg = 12, xl = 16, pill = 999 },
  s = { xxs = 4, xs = 8, sm = 12, md = 16, lg = 24, xl = 32 },
}

-- "#rrggbb" -> Android color int
function T.c(name)
  import "android.graphics.Color"
  return Color.parseColor(T[name] or name)
end

-- dp -> px
function T.dp(v)
  return math.floor(v * activity.getResources().getDisplayMetrics().density + 0.5)
end

return T
