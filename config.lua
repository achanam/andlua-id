-- config.lua: single place for builder settings and paths.
-- Change ROOT here and every path follows.
local ROOT = "/sdcard/AndLua_ID"

return {
  ROOT     = ROOT,
  PROJECT  = ROOT .. "/project",
  BIN      = ROOT .. "/bin",
  KEYS     = ROOT .. "/keys",
  CACHE    = ROOT .. "/cache",
  BACKUP   = ROOT .. "/backup",
  LUALIBS  = ROOT .. "/lualibs",

  -- replaces res/set203/207/211/220.LY and res/jks
  compile      = true,      -- set211: compile .lua/.aly to bytecode
  minimalDex   = false,     -- set203: true = dex.zip, false = dex_full.zip
  useFileProv  = true,      -- set207: install via FileProvider (Android 7+)
  binDex       = false,     -- set220: BinDex mode. Confirmed unusable: requires
                             -- org.eclipse.jdt.internal.compiler.batch.Main (ECJ Java
                             -- compiler), which isn't bundled anywhere in this app's
                             -- lineage -- checked every classes*.dex in the original
                             -- APP.zip, not present. compile=true above already strips
                             -- debug info (local var names, line numbers, comments)
                             -- from the bytecode shipped in the APK, which is the
                             -- baseline protection actually in effect.
  keystore     = "default", -- "default" = bundled keys/, or a .jks name in KEYS
}
