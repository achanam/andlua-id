# AndLua ID

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![Platform: Android](https://img.shields.io/badge/Platform-Android-3DDC84.svg)
![Language: Lua](https://img.shields.io/badge/Language-Lua-2C2D72.svg)
![Interface: Indonesian](https://img.shields.io/badge/Interface-Indonesian-red.svg)

A Lua APK builder that runs on your phone. You write a Lua project, hit build, and get an installable APK, without touching a computer.

It's a stripped-down, redesigned take on [AndLua+](https://github.com/baiyuncode/andlua) by baiyuncode, with the interface in Indonesian.

## Why I made it

AndLua+ is good, but it comes with a lot I never used: login, chat, forum, profiles, and a bunch of stuff that talks to a server. The interface is also in Chinese, which makes it hard to recommend to people here who just want to learn Lua on Android.

So I kept the part I actually care about (projects, editor, builder), translated it, and gave it a new look: dark, minimal, loosely based on the Linear design style.

## What's in it

- Project list, with five templates (Default, DrawerLayout, LuaJava, TabBar, TitleBar)
- Code editor with file tabs, live syntax check (red bar), find / go to line, and format
- APK builder, with the build logic ported from AndLua+ as is
- Per-project settings: app name, package, version, icon, permissions
- Log viewer (logcat with filters)
- Update check against GitHub releases on launch

## What's not

Everything tied to the AndLua+ server: login, chat, forum, profile, notifications, donations. Also left out for now: edit history, plugins, code analysis, color picker.

## Running it

Grab the APK from the [Releases](https://github.com/achanam/andlua-id/releases/latest) page and install it. Your projects live in `/sdcard/AndLua_ID/project`.

To run the source instead, copy this folder to `/sdcard/AndLua/project/` and open it from AndLua+.

The builder uses the app's own APK as the frame for whatever you build, so it needs the Java classes that AndLua+ ships with (those are in `libs/` and `res/`).

One thing to know if you edit `init.lua`: the permission list there is the manifest template for every app the builder produces. Don't remove entries from it.

## Status

I test this by hand on my own phone. There are no automated tests, and some parts have only been looked at once. Expect rough edges. If something breaks, open an issue with a screenshot, that's how I find most bugs.

## Credits and license

Built on the work of baiyuncode ([AndLua+](https://github.com/baiyuncode/andlua)) and Nirenr ([AndroLua+](https://github.com/nirenr/AndroLua_pro)). This is an unofficial project and isn't affiliated with either of them.

Released under the MIT License, see [LICENSE](LICENSE).

Made by Anam (Ach Anam)
