local ThemeManager = {
	Library = nil,
	Folder = "Astra",
	Theme = "Astra Dark",
}

ThemeManager.BuiltInThemes = {
	["Astra Dark"] = {
		Background = Color3.fromRGB(14, 16, 22),
		Panel = Color3.fromRGB(20, 23, 31),
		PanelAlt = Color3.fromRGB(27, 31, 42),
		Outline = Color3.fromRGB(56, 63, 80),
		Text = Color3.fromRGB(236, 240, 247),
		MutedText = Color3.fromRGB(150, 158, 176),
		Accent = Color3.fromRGB(83, 168, 255),
		AccentDark = Color3.fromRGB(42, 92, 150),
		Red = Color3.fromRGB(255, 92, 92),
		Green = Color3.fromRGB(81, 210, 137),
		Yellow = Color3.fromRGB(245, 205, 90),
	},

	["Mint"] = {
		Background = Color3.fromRGB(13, 20, 19),
		Panel = Color3.fromRGB(18, 30, 28),
		PanelAlt = Color3.fromRGB(27, 44, 40),
		Outline = Color3.fromRGB(67, 93, 86),
		Text = Color3.fromRGB(232, 247, 241),
		MutedText = Color3.fromRGB(151, 180, 171),
		Accent = Color3.fromRGB(64, 214, 157),
		AccentDark = Color3.fromRGB(35, 113, 89),
		Red = Color3.fromRGB(255, 101, 121),
		Green = Color3.fromRGB(64, 214, 157),
		Yellow = Color3.fromRGB(239, 207, 103),
	},

	["Rose"] = {
		Background = Color3.fromRGB(22, 16, 21),
		Panel = Color3.fromRGB(32, 22, 31),
		PanelAlt = Color3.fromRGB(46, 31, 44),
		Outline = Color3.fromRGB(88, 61, 84),
		Text = Color3.fromRGB(249, 236, 246),
		MutedText = Color3.fromRGB(181, 151, 173),
		Accent = Color3.fromRGB(238, 106, 161),
		AccentDark = Color3.fromRGB(134, 55, 91),
		Red = Color3.fromRGB(255, 92, 110),
		Green = Color3.fromRGB(105, 218, 146),
		Yellow = Color3.fromRGB(245, 204, 94),
	},

	["Amber"] = {
		Background = Color3.fromRGB(20, 18, 13),
		Panel = Color3.fromRGB(31, 27, 20),
		PanelAlt = Color3.fromRGB(45, 39, 27),
		Outline = Color3.fromRGB(91, 78, 52),
		Text = Color3.fromRGB(248, 241, 226),
		MutedText = Color3.fromRGB(181, 166, 136),
		Accent = Color3.fromRGB(237, 178, 74),
		AccentDark = Color3.fromRGB(134, 93, 36),
		Red = Color3.fromRGB(255, 103, 88),
		Green = Color3.fromRGB(115, 207, 130),
		Yellow = Color3.fromRGB(237, 178, 74),
	},
}

local function canUseFiles()
	return type(writefile) == "function"
		and type(readfile) == "function"
		and type(isfile) == "function"
		and type(makefolder) == "function"
		and type(isfolder) == "function"
end

local function makeFolders(path)
	if not canUseFiles() then
		return
	end

	local current = ""
	for part in string.gmatch(path, "[^/]+") do
		current = current == "" and part or (current .. "/" .. part)
		if not isfolder(current) then
			makefolder(current)
		end
	end
end

local function serializeColor(color)
	return {
		R = math.floor(color.R * 255 + 0.5),
		G = math.floor(color.G * 255 + 0.5),
		B = math.floor(color.B * 255 + 0.5),
	}
end

local function deserializeColor(value)
	if typeof(value) == "Color3" then
		return value
	end
	if type(value) == "table" then
		return Color3.fromRGB(value.R or 255, value.G or 255, value.B or 255)
	end
	return Color3.fromRGB(255, 255, 255)
end

function ThemeManager:SetLibrary(library)
	self.Library = library
end

function ThemeManager:SetFolder(folder)
	self.Folder = folder or self.Folder
end

function ThemeManager:GetThemeNames()
	local names = {}
	for name in pairs(self.BuiltInThemes) do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

function ThemeManager:ApplyTheme(nameOrTheme)
	if not self.Library then
		return
	end

	local theme = type(nameOrTheme) == "table" and nameOrTheme or self.BuiltInThemes[nameOrTheme]
	if not theme then
		return
	end

	if type(nameOrTheme) == "string" then
		self.Theme = nameOrTheme
	end

	self.Library:SetTheme(theme)
end

function ThemeManager:SaveTheme(name)
	if not self.Library or not canUseFiles() then
		return false
	end

	local HttpService = game:GetService("HttpService")
	local path = self.Folder .. "/themes"
	makeFolders(path)

	local data = {}
	for token, color in pairs(self.Library.Scheme) do
		if typeof(color) == "Color3" then
			data[token] = serializeColor(color)
		end
	end

	writefile(path .. "/" .. tostring(name or self.Theme) .. ".json", HttpService:JSONEncode(data))
	return true
end

function ThemeManager:LoadTheme(name)
	if not canUseFiles() then
		self:ApplyTheme(name)
		return false
	end

	local HttpService = game:GetService("HttpService")
	local path = self.Folder .. "/themes/" .. tostring(name) .. ".json"
	if not isfile(path) then
		self:ApplyTheme(name)
		return false
	end

	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(readfile(path))
	end)
	if not ok then
		return false
	end

	local theme = {}
	for token, color in pairs(decoded) do
		theme[token] = deserializeColor(color)
	end

	self:ApplyTheme(theme)
	self.Theme = tostring(name)
	return true
end

function ThemeManager:ApplyToGroupbox(groupbox)
	local themeDropdown = groupbox:AddDropdown("ThemeManager_Theme", {
		Text = "Theme",
		Values = self:GetThemeNames(),
		Default = self.Theme,
		Searchable = false,
		Callback = function(value)
			self:ApplyTheme(value)
		end,
	})

	groupbox:AddButton({
		Text = "Apply Theme",
		Func = function()
			self:ApplyTheme(themeDropdown.Value)
		end,
	})

	groupbox:AddButton({
		Text = "Save Current Theme",
		Func = function()
			self:SaveTheme(themeDropdown.Value or self.Theme)
			if self.Library then
				self.Library:Notify({
					Title = "Theme saved",
					Description = tostring(themeDropdown.Value or self.Theme),
					Time = 3,
				})
			end
		end,
	})

	return groupbox
end

function ThemeManager:ApplyToTab(tab)
	local groupbox = tab:AddLeftGroupbox("Themes", "palette")
	return self:ApplyToGroupbox(groupbox)
end

return ThemeManager
