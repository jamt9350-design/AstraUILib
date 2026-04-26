local HttpService = game:GetService("HttpService")

local SaveManager = {
	Library = nil,
	Folder = "AtlasUI",
	SubFolder = nil,
	IgnoreIndexes = {},
	IgnoreThemes = false,
}

local function fileApiAvailable()
	return type(writefile) == "function"
		and type(readfile) == "function"
		and type(isfile) == "function"
		and type(isfolder) == "function"
		and type(makefolder) == "function"
end

local function sanitize(name)
	name = tostring(name or "default")
	name = name:gsub("[\\/:*?\"<>|]", "_")
	name = name:gsub("^%s+", ""):gsub("%s+$", "")

	if name == "" then
		name = "default"
	end

	return name
end

local function ensureFolder(path)
	if not fileApiAvailable() then
		return false
	end

	local current = ""
	for part in path:gmatch("[^/]+") do
		current = current == "" and part or (current .. "/" .. part)
		if not isfolder(current) then
			makefolder(current)
		end
	end

	return true
end

function SaveManager:SetLibrary(library)
	self.Library = library
	return self
end

function SaveManager:SetFolder(folder)
	self.Folder = tostring(folder or self.Folder)
	return self
end

function SaveManager:SetSubFolder(folder)
	self.SubFolder = folder and tostring(folder) or nil
	return self
end

function SaveManager:SetIgnoreIndexes(indexes)
	self.IgnoreIndexes = {}

	for _, index in ipairs(indexes or {}) do
		self.IgnoreIndexes[index] = true
	end

	return self
end

function SaveManager:IgnoreThemeSettings()
	self.IgnoreThemes = true
	return self
end

function SaveManager:GetFolder()
	local folder = self.Folder .. "/settings"

	if self.SubFolder and self.SubFolder ~= "" then
		folder = folder .. "/" .. self.SubFolder
	end

	return folder
end

function SaveManager:GetPath(name)
	return self:GetFolder() .. "/" .. sanitize(name) .. ".json"
end

function SaveManager:GetAutoloadPath()
	return self.Folder .. "/autoload.json"
end

function SaveManager:ShouldIgnore(index)
	if self.IgnoreIndexes[index] then
		return true
	end

	if self.IgnoreThemes and tostring(index):find("^ThemeManager%.") then
		return true
	end

	return false
end

function SaveManager:Notify(title, description)
	if self.Library and self.Library.Notify then
		self.Library:Notify({
			Title = title,
			Description = description,
			Time = 3,
		})
	end
end

function SaveManager:EncodeObject(object)
	if object.SetValueRGB and typeof(object.Value) == "Color3" then
		return {
			__type = "Color3",
			R = math.floor(object.Value.R * 255 + 0.5),
			G = math.floor(object.Value.G * 255 + 0.5),
			B = math.floor(object.Value.B * 255 + 0.5),
			Transparency = object.Transparency,
		}
	end

	if object.Mode and object.Value then
		return {
			__type = "KeyPicker",
			Key = object.Value,
			Mode = object.Mode,
			Modifiers = object.Modifiers,
		}
	end

	return object.Value
end

function SaveManager:ApplyObject(object, value)
	if not object then
		return
	end

	if type(value) == "table" and value.__type == "Color3" and object.SetValueRGB then
		object:SetValueRGB(Color3.fromRGB(value.R or 255, value.G or 255, value.B or 255), value.Transparency)
	elseif type(value) == "table" and value.__type == "KeyPicker" and object.SetValue then
		object:SetValue({ value.Key, value.Mode, value.Modifiers })
	elseif object.SetValue then
		object:SetValue(value)
	elseif object.SetText then
		object:SetText(value)
	end
end

function SaveManager:Collect()
	local data = {
		Toggles = {},
		Options = {},
	}

	if not self.Library then
		return data
	end

	for index, object in pairs(self.Library.Toggles) do
		if not self:ShouldIgnore(index) then
			data.Toggles[index] = self:EncodeObject(object)
		end
	end

	for index, object in pairs(self.Library.Options) do
		if not self:ShouldIgnore(index) then
			data.Options[index] = self:EncodeObject(object)
		end
	end

	return data
end

function SaveManager:Save(name)
	if not self.Library then
		return false
	end

	if not fileApiAvailable() then
		self:Notify("Config not saved", "The executor does not expose file APIs.")
		return false
	end

	ensureFolder(self:GetFolder())

	local path = self:GetPath(name)
	writefile(path, HttpService:JSONEncode(self:Collect()))
	self:Notify("Config saved", sanitize(name))
	return true
end

function SaveManager:Load(name)
	if not self.Library then
		return false
	end

	if not fileApiAvailable() then
		self:Notify("Config not loaded", "The executor does not expose file APIs.")
		return false
	end

	local path = self:GetPath(name)
	if not isfile(path) then
		self:Notify("Config missing", sanitize(name))
		return false
	end

	local ok, data = pcall(function()
		return HttpService:JSONDecode(readfile(path))
	end)

	if not ok or type(data) ~= "table" then
		self:Notify("Config error", "Could not read " .. sanitize(name))
		return false
	end

	for index, value in pairs(data.Toggles or {}) do
		self:ApplyObject(self.Library.Toggles[index], value)
	end

	for index, value in pairs(data.Options or {}) do
		self:ApplyObject(self.Library.Options[index], value)
	end

	self:Notify("Config loaded", sanitize(name))
	return true
end

function SaveManager:Delete(name)
	if type(delfile) ~= "function" then
		self:Notify("Config not deleted", "The executor does not expose delfile.")
		return false
	end

	local path = self:GetPath(name)
	if isfile(path) then
		delfile(path)
		self:Notify("Config deleted", sanitize(name))
		return true
	end

	return false
end

function SaveManager:GetConfigList()
	if type(listfiles) ~= "function" or not fileApiAvailable() then
		return {}
	end

	local folder = self:GetFolder()
	ensureFolder(folder)

	local configs = {}
	for _, path in ipairs(listfiles(folder)) do
		local name = path:match("([^/\\]+)%.json$")
		if name then
			table.insert(configs, name)
		end
	end

	table.sort(configs)
	return configs
end

function SaveManager:SetAutoloadConfig(name)
	if not fileApiAvailable() then
		self:Notify("Autoload not saved", "The executor does not expose file APIs.")
		return false
	end

	ensureFolder(self.Folder)
	writefile(self:GetAutoloadPath(), HttpService:JSONEncode({
		Config = sanitize(name),
		SubFolder = self.SubFolder,
	}))
	self:Notify("Autoload set", sanitize(name))
	return true
end

function SaveManager:LoadAutoloadConfig()
	if not fileApiAvailable() then
		return false
	end

	local path = self:GetAutoloadPath()
	if not isfile(path) then
		return false
	end

	local ok, data = pcall(function()
		return HttpService:JSONDecode(readfile(path))
	end)

	if ok and type(data) == "table" and data.Config then
		return self:Load(data.Config)
	end

	return false
end

function SaveManager:BuildConfigSection(target)
	if not self.Library or not target then
		return
	end

	local groupbox = target.AddRightGroupbox and target:AddRightGroupbox("Configs") or target
	local configName = groupbox:AddInput("SaveManager.ConfigName", {
		Text = "Config name",
		Default = "default",
		Placeholder = "default",
	})

	local configList = groupbox:AddDropdown("SaveManager.ConfigList", {
		Text = "Configs",
		Values = self:GetConfigList(),
		Default = 1,
		Searchable = true,
	})

	local function selectedName()
		return configName.Value ~= "" and configName.Value or configList.Value or "default"
	end

	local function refresh()
		configList:SetValues(self:GetConfigList())
	end

	groupbox:AddButton({
		Text = "Save",
		Func = function()
			self:Save(selectedName())
			refresh()
		end,
	}):AddButton({
		Text = "Load",
		Func = function()
			self:Load(configList.Value or selectedName())
		end,
	})

	groupbox:AddButton({
		Text = "Set autoload",
		Func = function()
			self:SetAutoloadConfig(configList.Value or selectedName())
		end,
	}):AddButton({
		Text = "Refresh",
		Func = refresh,
	})

	groupbox:AddButton({
		Text = "Delete",
		Func = function()
			self:Delete(configList.Value or selectedName())
			refresh()
		end,
		DoubleClick = true,
	})

	refresh()
	return groupbox
end

return SaveManager
