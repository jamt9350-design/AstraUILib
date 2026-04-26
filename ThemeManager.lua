local ThemeManager = {
	Library = nil,
	Folder = "AtlasUI",
	ThemeOrder = { "Atlas Dark", "Midnight", "Emerald", "Crimson", "Light" },
	Themes = {
		["Atlas Dark"] = {
			Background = Color3.fromRGB(17, 18, 23),
			Surface = Color3.fromRGB(24, 26, 33),
			Panel = Color3.fromRGB(30, 33, 42),
			PanelHover = Color3.fromRGB(39, 43, 54),
			Stroke = Color3.fromRGB(61, 66, 81),
			Text = Color3.fromRGB(238, 241, 247),
			SubText = Color3.fromRGB(157, 166, 184),
			Accent = Color3.fromRGB(85, 170, 255),
			AccentDark = Color3.fromRGB(36, 92, 150),
			Red = Color3.fromRGB(245, 89, 98),
			Green = Color3.fromRGB(92, 214, 142),
			Warning = Color3.fromRGB(242, 189, 100),
		},
		Midnight = {
			Background = Color3.fromRGB(12, 16, 22),
			Surface = Color3.fromRGB(20, 26, 34),
			Panel = Color3.fromRGB(28, 36, 46),
			PanelHover = Color3.fromRGB(38, 49, 62),
			Stroke = Color3.fromRGB(70, 82, 98),
			Text = Color3.fromRGB(235, 241, 248),
			SubText = Color3.fromRGB(148, 163, 184),
			Accent = Color3.fromRGB(125, 211, 252),
			AccentDark = Color3.fromRGB(14, 116, 144),
			Red = Color3.fromRGB(248, 113, 113),
			Green = Color3.fromRGB(74, 222, 128),
			Warning = Color3.fromRGB(251, 191, 36),
		},
		Emerald = {
			Background = Color3.fromRGB(16, 22, 20),
			Surface = Color3.fromRGB(23, 32, 29),
			Panel = Color3.fromRGB(29, 42, 38),
			PanelHover = Color3.fromRGB(38, 55, 50),
			Stroke = Color3.fromRGB(71, 92, 85),
			Text = Color3.fromRGB(239, 248, 244),
			SubText = Color3.fromRGB(158, 179, 170),
			Accent = Color3.fromRGB(52, 211, 153),
			AccentDark = Color3.fromRGB(6, 120, 89),
			Red = Color3.fromRGB(251, 113, 133),
			Green = Color3.fromRGB(52, 211, 153),
			Warning = Color3.fromRGB(245, 158, 11),
		},
		Crimson = {
			Background = Color3.fromRGB(24, 17, 20),
			Surface = Color3.fromRGB(34, 24, 29),
			Panel = Color3.fromRGB(46, 30, 37),
			PanelHover = Color3.fromRGB(62, 40, 49),
			Stroke = Color3.fromRGB(94, 63, 72),
			Text = Color3.fromRGB(248, 240, 243),
			SubText = Color3.fromRGB(184, 151, 162),
			Accent = Color3.fromRGB(251, 113, 133),
			AccentDark = Color3.fromRGB(159, 18, 57),
			Red = Color3.fromRGB(248, 113, 113),
			Green = Color3.fromRGB(74, 222, 128),
			Warning = Color3.fromRGB(251, 191, 36),
		},
		Light = {
			Background = Color3.fromRGB(235, 238, 244),
			Surface = Color3.fromRGB(250, 251, 253),
			Panel = Color3.fromRGB(229, 233, 241),
			PanelHover = Color3.fromRGB(216, 222, 232),
			Stroke = Color3.fromRGB(184, 194, 210),
			Text = Color3.fromRGB(28, 34, 45),
			SubText = Color3.fromRGB(91, 102, 122),
			Accent = Color3.fromRGB(37, 99, 235),
			AccentDark = Color3.fromRGB(30, 64, 175),
			Red = Color3.fromRGB(220, 38, 38),
			Green = Color3.fromRGB(22, 163, 74),
			Warning = Color3.fromRGB(217, 119, 6),
		},
	},
}

local function copyTheme(theme)
	local copy = {}
	for key, value in pairs(theme) do
		copy[key] = value
	end
	return copy
end

function ThemeManager:SetLibrary(library)
	self.Library = library
	return self
end

function ThemeManager:SetFolder(folder)
	self.Folder = tostring(folder or self.Folder)
	return self
end

function ThemeManager:GetThemeNames()
	local names = {}

	for _, name in ipairs(self.ThemeOrder) do
		if self.Themes[name] then
			table.insert(names, name)
		end
	end

	for name in pairs(self.Themes) do
		if not table.find(names, name) then
			table.insert(names, name)
		end
	end

	return names
end

function ThemeManager:ApplyTheme(theme)
	if not self.Library then
		return false
	end

	local source = type(theme) == "table" and theme or self.Themes[tostring(theme)]
	if not source then
		return false
	end

	for key, value in pairs(copyTheme(source)) do
		self.Library.Scheme[key] = value
	end

	self.Library:_applyTheme()
	return true
end

function ThemeManager:AddTheme(name, theme)
	self.Themes[tostring(name)] = copyTheme(theme or {})

	if not table.find(self.ThemeOrder, tostring(name)) then
		table.insert(self.ThemeOrder, tostring(name))
	end

	return self
end

function ThemeManager:ApplyToGroupbox(groupbox)
	if not self.Library or not groupbox then
		return
	end

	local names = self:GetThemeNames()

	groupbox:AddDropdown("ThemeManager.Theme", {
		Text = "Theme",
		Values = names,
		Default = names[1],
		Callback = function(value)
			self:ApplyTheme(value)
		end,
	})

	groupbox:AddLabel("Accent"):AddColorPicker("ThemeManager.Accent", {
		Title = "Accent",
		Default = self.Library.Scheme.Accent,
		Callback = function(value)
			self.Library.Scheme.Accent = value
			self.Library:_applyTheme()
		end,
	})

	groupbox:AddLabel("Background"):AddColorPicker("ThemeManager.Background", {
		Title = "Background",
		Default = self.Library.Scheme.Background,
		Callback = function(value)
			self.Library.Scheme.Background = value
			self.Library:_applyTheme()
		end,
	})

	groupbox:AddLabel("Surface"):AddColorPicker("ThemeManager.Surface", {
		Title = "Surface",
		Default = self.Library.Scheme.Surface,
		Callback = function(value)
			self.Library.Scheme.Surface = value
			self.Library:_applyTheme()
		end,
	})
end

function ThemeManager:ApplyToTab(tab)
	if not tab then
		return
	end

	local groupbox = tab:AddLeftGroupbox("Themes")
	self:ApplyToGroupbox(groupbox)
	return groupbox
end

return ThemeManager
