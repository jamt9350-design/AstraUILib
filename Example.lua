-- Astra UI example
-- Published at https://github.com/jamt9350-design/AstraUILib

local repo = "https://raw.githubusercontent.com/jamt9350-design/AstraUILib/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Options = Library.Options
local Toggles = Library.Toggles

Library.ForceCheckbox = false
Library.ShowToggleFrameInKeybinds = true

local Window = Library:CreateWindow({
	Title = "Astra UI",
	Footer = "version: example",
	Icon = 95816097006870,
	NotifySide = "Right",
	ShowCustomCursor = true,
	Resizable = true,
	MobileButtonsSide = "Right",
})

local Tabs = {
	Main = Window:AddTab("Main", "user"),
	Key = Window:AddKeyTab("Key System"),
	["UI Settings"] = Window:AddTab("UI Settings", "settings"),
}

local LeftGroupBox = Tabs.Main:AddLeftGroupbox("Main Controls", "boxes")

LeftGroupBox:AddToggle("MyToggle", {
	Text = "This is a toggle",
	Tooltip = "Hover tooltip",
	Default = true,
	Callback = function(value)
		print("[cb] MyToggle:", value)
	end,
})
	:AddColorPicker("ToggleColor", {
		Default = Color3.fromRGB(255, 80, 80),
		Title = "Toggle color",
		Transparency = 0,
		Callback = function(value)
			print("[cb] ToggleColor:", value)
		end,
	})

Toggles.MyToggle:OnChanged(function()
	print("MyToggle changed to:", Toggles.MyToggle.Value)
end)

LeftGroupBox:AddCheckbox("MyCheckbox", {
	Text = "This is a checkbox",
	Default = false,
})

LeftGroupBox:AddButton({
	Text = "Button",
	Func = function()
		Library:Notify({
			Title = "Button",
			Description = "You clicked the button.",
			Time = 3,
		})
	end,
	Tooltip = "Single click button",
}):AddButton({
	Text = "Double-click sub button",
	DoubleClick = true,
	Func = function()
		print("Double-clicked")
	end,
})

LeftGroupBox:AddLabel("Normal label")
LeftGroupBox:AddLabel("Wrapped label\nwith multiple lines.", true, "WrappedLabel")
LeftGroupBox:AddDivider()

LeftGroupBox:AddSlider("MySlider", {
	Text = "Slider",
	Default = 2,
	Min = 0,
	Max = 10,
	Rounding = 1,
	Suffix = "x",
	Callback = function(value)
		print("[cb] Slider:", value)
	end,
})

Options.MySlider:OnChanged(function()
	print("MySlider changed to:", Options.MySlider.Value)
end)

LeftGroupBox:AddSlider("DisplaySlider", {
	Text = "Formatted slider",
	Default = 0,
	Min = 0,
	Max = 5,
	Rounding = 0,
	FormatDisplayValue = function(slider, value)
		if value == slider.Min then
			return "Nothing"
		elseif value == slider.Max then
			return "Everything"
		end
	end,
})

LeftGroupBox:AddInput("MyTextbox", {
	Text = "Textbox",
	Default = "Hello",
	Placeholder = "Type here",
	ClearTextOnFocus = false,
	Callback = function(value)
		print("[cb] Text:", value)
	end,
})

LeftGroupBox:AddLabel("Color"):AddColorPicker("MainColor", {
	Default = Color3.fromRGB(0, 255, 140),
	Title = "Main color",
	Transparency = 0,
})

LeftGroupBox:AddLabel("Keybind"):AddKeyPicker("KeyPicker", {
	Default = "MB2",
	Mode = "Hold",
	Text = "Example hold key",
	Callback = function(value)
		print("[cb] Key state:", value)
	end,
	ChangedCallback = function(newKey, modifiers)
		print("[cb] Key changed:", newKey, table.unpack(modifiers or {}))
	end,
})

Options.KeyPicker:OnClick(function()
	print("Key clicked:", Options.KeyPicker:GetState())
end)

local DropdownGroupBox = Tabs.Main:AddRightGroupbox("Dropdowns")

DropdownGroupBox:AddDropdown("MyDropdown", {
	Text = "Dropdown",
	Values = { "This", "is", "a", "dropdown" },
	Default = 1,
	Tooltip = "Normal dropdown",
})

DropdownGroupBox:AddDropdown("SearchableDropdown", {
	Text = "Searchable dropdown",
	Values = { "Alpha", "Bravo", "Charlie", "Delta", "Echo", "Foxtrot" },
	Default = "Alpha",
	Searchable = true,
})

DropdownGroupBox:AddDropdown("FormattedDropdown", {
	Text = "Formatted display",
	Values = { "raw", "formatted", "value" },
	Default = "formatted",
	FormatDisplayValue = function(value)
		return value == "formatted" and "display formatted" or value
	end,
})

DropdownGroupBox:AddDropdown("MultiDropdown", {
	Text = "Multi dropdown",
	Values = { "One", "Two", "Three" },
	Multi = true,
	Default = { One = true },
	Callback = function(value)
		for key, enabled in pairs(value) do
			print(key, enabled)
		end
	end,
})

DropdownGroupBox:AddDropdown("LongDropdown", {
	Text = "Long dropdown",
	Values = { "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten", "Eleven", "Twelve" },
	MaxVisibleDropdownItems = 10,
})

DropdownGroupBox:AddDropdown("PlayerDropdown", {
	Text = "Player dropdown",
	SpecialType = "Player",
	ExcludeLocalPlayer = true,
})

DropdownGroupBox:AddDropdown("TeamDropdown", {
	Text = "Team dropdown",
	SpecialType = "Team",
})

local TabBox = Tabs.Main:AddRightTabbox()
local Tab1 = TabBox:AddTab("Tab 1")
Tab1:AddToggle("Tab1Toggle", { Text = "Tab 1 toggle" })

local Tab2 = TabBox:AddTab("Tab 2")
Tab2:AddSlider("Tab2Slider", {
	Text = "Tab 2 slider",
	Default = 50,
	Min = 0,
	Max = 100,
	Rounding = 0,
})

Tabs.Key:AddLabel({
	Text = "Key: Banana",
	DoesWrap = true,
	Size = 16,
})

Tabs.Key:AddKeyBox(function(receivedKey)
	local success = receivedKey == "Banana"
	Library:Notify({
		Title = "Key System",
		Description = "Received Key: " .. receivedKey .. "\nSuccess: " .. tostring(success),
		Time = 4,
	})
end)

Library:AddDraggableLabel("Draggable Label")

local MenuGroup = Tabs["UI Settings"]:AddLeftGroupbox("Menu", "wrench")

MenuGroup:AddToggle("KeybindMenuOpen", {
	Text = "Open Keybind Menu",
	Default = Library.KeybindFrame.Visible,
	Callback = function(value)
		Library.KeybindFrame.Visible = value
	end,
})

MenuGroup:AddToggle("ShowCustomCursor", {
	Text = "Custom Cursor",
	Default = true,
	Callback = function(value)
		Library.ShowCustomCursor = value
	end,
})

MenuGroup:AddDropdown("NotificationSide", {
	Text = "Notification Side",
	Values = { "Left", "Right" },
	Default = "Right",
	Callback = function(value)
		Library:SetNotifySide(value)
	end,
})

MenuGroup:AddDropdown("DPIDropdown", {
	Text = "DPI Scale",
	Values = { "75%", "100%", "125%", "150%", "175%", "200%" },
	Default = "100%",
	Callback = function(value)
		local dpi = tonumber(value:gsub("%%", ""))
		Library:SetDPIScale(dpi)
	end,
})

MenuGroup:AddSlider("UICornerSlider", {
	Text = "Corner Radius",
	Default = Library.CornerRadius,
	Min = 0,
	Max = 20,
	Rounding = 0,
	Callback = function(value)
		Window:SetCornerRadius(value)
	end,
})

MenuGroup:AddDivider()
MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", {
	Default = "RightShift",
	NoUI = true,
	Text = "Menu keybind",
})

MenuGroup:AddButton("Unload", function()
	Library:Unload()
end)

Library.ToggleKeybind = Options.MenuKeybind

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })

ThemeManager:SetFolder("AstraHub")
SaveManager:SetFolder("AstraHub/specific-game")
SaveManager:SetSubFolder("specific-place")

SaveManager:BuildConfigSection(Tabs["UI Settings"])
ThemeManager:ApplyToTab(Tabs["UI Settings"])

Library:OnUnload(function()
	print("Astra unloaded")
end)

SaveManager:LoadAutoloadConfig()
