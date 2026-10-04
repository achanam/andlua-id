-- credits.lua: developer and credits data (edit here only)
-- To edit: set OWN_NAME below; it feeds the Developer menu and the MIT copyright line.
-- Keep the AndLua+ and AndroLua+ copyright lines (MIT license requirement).

local OWN_NAME = "Ach Anam"
local OWN_YEAR = "2026"

-- copyright lines: yours first, then the original authors
local copyrights = {
  "AndLua ID\nCopyright (c) " .. OWN_YEAR .. " " .. OWN_NAME,
  "AndLua+\nCopyright (c) 2023 三亖三",
  "AndroLua+\nCopyright (C) 2015-2016 by Nirenr",
}

local MIT_BODY = [[Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.]]

return {
  -- Developer menu
  developer = {
    name  = "Anam",
    alias = OWN_NAME,
    roles = { "Creative Developer", "Visual Designer", "Tech Explorer" },
    -- kind = icon name in ui.lua (instagram | globe | github)
    links = {
      { kind = "instagram", title = "Instagram", sub = "@_achanam",        url = "https://instagram.com/_achanam" },
      { kind = "globe",     title = "Website",   sub = "achanam.com",      url = "https://achanam.com" },
      { kind = "github",    title = "GitHub",    sub = "github.com/achanam", url = "https://github.com/achanam" },
    },
  },

  -- Credits menu (card order = list order)
  sources = {
    {
      name = "AndLua+",
      by   = "baiyuncode (三亖三)",
      note = "Project base: APK build logic, host libraries, and project templates.",
      url  = "https://github.com/baiyuncode/andlua",
    },
    {
      name = "AndroLua+ (AndroLua_pro)",
      by   = "Nirenr",
      note = "Lua engine for Android and core classes.",
      url  = "https://github.com/nirenr/AndroLua_pro",
    },
  },

  -- About text (English)
  about = {
    title = "About",
    sub   = "Why AndLua ID exists",
    sections = {
      {
        heading = "What it is",
        text = "AndLua ID is a lightweight Lua APK builder for Android. Write a Lua project, run it, and package it into an installable APK, all straight from your phone.",
      },
      {
        heading = "Why it was made",
        text = "AndLua+ by baiyuncode is a powerful all-in-one environment, but it carries many features beyond building apps. AndLua ID keeps only the essence: managing projects, editing code, and building APKs. The goal is simple: make getting from an idea to an installable app easier, with fewer steps and less clutter.",
      },
      {
        heading = "Made for Indonesia",
        text = "The original AndLua+ is written mainly in Chinese, which can be a barrier for many Indonesian developers. AndLua ID translates the interface from Mandarin into Indonesian, so learning Lua and building Android apps feels familiar and approachable.",
      },
      {
        heading = "What is different",
        text = "The build logic comes from AndLua+, so your projects keep working the way you expect. The interface, however, is redesigned from scratch with a modern, minimal dark look: clean spacing, clear typography, and a calm layout that keeps the focus on your code.",
      },
      {
        heading = "Highlights",
        items = {
          "Simple project list with templates",
          "Code editor with syntax check",
          "One-tap APK build",
          "Permission picker per project",
          "Modern dark interface",
          "Fully in Indonesian",
        },
      },
      {
        heading = "Thanks",
        text = "Full credit goes to baiyuncode and Nirenr, whose open-source work makes this project possible. See Credits for details.",
      },
    },
  },

  disclaimer = "AndLua ID is an unofficial project and is not affiliated with the authors above.",

  mitTitle = "MIT License",
  mit = table.concat(copyrights, "\n\n") .. "\n\n" .. MIT_BODY,
}
