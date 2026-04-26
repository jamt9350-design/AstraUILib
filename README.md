# Astra UI Library

A Roblox/Luau UI library with a Linoria/Obsidian-style API, written as a fresh implementation for this project.

Inspired by the MIT-licensed Obsidian UI Library: https://github.com/deividcomsono/Obsidian

## Files

- `Library.lua` - main UI library
- `addons/ThemeManager.lua` - built-in theme menu and theme helpers
- `addons/SaveManager.lua` - config save/load/autoload menu
- `Example.lua` - full usage example

## Load From GitHub

Use the raw GitHub URL:

```lua
local repo = "https://raw.githubusercontent.com/jamt9350-design/AstraUILib/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()
```

## Make A Window And Tab

```lua
local Window = Library:CreateWindow({
	Title = "My Script",
	Footer = "version: 1.0",
	NotifySide = "Right",
	Resizable = true,
})

local MainTab = Window:AddTab("Main", "user")
local MainBox = MainTab:AddLeftGroupbox("Main")

MainBox:AddToggle("AutoFarm", {
	Text = "Auto Farm",
	Default = false,
	Callback = function(value)
		print("Auto Farm:", value)
	end,
})

MainBox:AddSlider("Speed", {
	Text = "Speed",
	Default = 16,
	Min = 0,
	Max = 100,
	Rounding = 0,
})
```

## Supported Features

- Windows, tabs, key tabs, groupboxes, and tabboxes
- Toggles and checkboxes
- Buttons and double-click buttons
- Labels, wrapped labels, and dividers
- Sliders with suffixes and custom display formatting
- Text inputs
- Dropdowns, searchable dropdowns, multi dropdowns, disabled values, player/team dropdowns
- Color pickers
- Key pickers with `Always`, `Toggle`, `Hold`, and `Press` modes
- Key system box
- Notifications
- Draggable labels
- Menu keybind, keybind menu, mobile toggle button
- DPI scale and corner radius settings
- Theme manager and save manager addons

## Publish To GitHub

1. Create a new public GitHub repo, for example `AstraUILib`.
2. In this folder, run:

```powershell
git add Library.lua addons/ThemeManager.lua addons/SaveManager.lua Example.lua README.md LICENSE NOTICE.md .gitignore
git commit -m "Add Astra UI library"
git branch -M main
git remote add origin https://github.com/jamt9350-design/AstraUILib.git
git push -u origin main
```

3. Open this URL in your browser to confirm raw loading works:

```text
https://raw.githubusercontent.com/jamt9350-design/AstraUILib/main/Library.lua
```

4. Update `Example.lua` if you publish under a different username or repo.

## Notes

Executors usually support `writefile`, `readfile`, and `listfiles`, so `SaveManager` can persist configs. In Roblox Studio, those functions usually do not exist, so configs fall back to memory for the current session.
