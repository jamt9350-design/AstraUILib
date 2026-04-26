local SaveManager = {
	Library = nil,
	Folder = "Astra",
	SubFolder = nil,
	Ignore = {},
	IgnoreThemes = false,
	Autoload = nil,
	Memory = {},
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

local function colorToTable(color)
	return {
		R = math.floor(color.R * 255 + 0.5),
		G = math.floor(color.G * 255 + 0.5),
		B = math.floor(color.B * 255 + 0.5),
	}
end

local function tableToColor(value)
	if typeof(value) == "Color3" then
		return value
	end
	return Color3.fromRGB(value.R or 255, value.G or 255, value.B or 255)
end

local function shallowCopy(source)
	local copy = {}
	for key, value in pairs(source or {}) do
		copy[key] = value
	end
	return copy
end

local function serializeModifiers(modifiers)
	local result = {}
	for _, modifier in ipairs(modifiers or {}) do
		if typeof(modifier) == "EnumItem" then
			table.insert(result, modifier.Name)
		else
			table.insert(result, tostring(modifier))
		end
	end
	return result
end

function SaveManager:SetLibrary(library)
	self.Library = library
end

function SaveManager:IgnoreThemeSettings()
	self.IgnoreThemes = true
	self.Ignore.ThemeManager_Theme = true
end

function SaveManager:SetIgnoreIndexes(indexes)
	for _, index in ipairs(indexes or {}) do
		self.Ignore[index] = true
	end
end

function SaveManager:SetFolder(folder)
	self.Folder = folder or self.Folder
end

function SaveManager:SetSubFolder(folder)
	self.SubFolder = folder
end

function SaveManager:GetFolder()
	local path = self.Folder .. "/settings"
	if self.SubFolder and self.SubFolder ~= "" then
		path = path .. "/" .. self.SubFolder
	end
	return path
end

function SaveManager:GetPath(name)
	return self:GetFolder() .. "/" .. tostring(name) .. ".json"
end

function SaveManager:GetAutoloadPath()
	return self:GetFolder() .. "/autoload.txt"
end

function SaveManager:GetConfigNames()
	local names = { "default" }
	if not canUseFiles() or type(listfiles) ~= "function" then
		for name in pairs(self.Memory) do
			table.insert(names, name)
		end
		table.sort(names)
		return names
	end

	makeFolders(self:GetFolder())
	for _, file in ipairs(listfiles(self:GetFolder())) do
		local name = file:match("([^/\\]+)%.json$")
		if name then
			table.insert(names, name)
		end
	end
	table.sort(names)
	return names
end

function SaveManager:Collect()
	local data = {
		Options = {},
		Toggles = {},
	}

	if not self.Library then
		return data
	end

	for index, toggle in pairs(self.Library.Toggles) do
		if not self.Ignore[index] then
			data.Toggles[index] = toggle.Value == true
		end
	end

	for index, option in pairs(self.Library.Options) do
		if not self.Ignore[index] then
			if option.Type == "ColorPicker" then
				data.Options[index] = {
					Type = option.Type,
					Value = colorToTable(option.Value),
					Transparency = option.Transparency,
				}
			elseif option.Type == "KeyPicker" then
				data.Options[index] = {
					Type = option.Type,
					Value = option.Value,
					Mode = option.Mode,
					Modifiers = serializeModifiers(option.Modifiers),
				}
			elseif option.Type == "Dropdown" and option.Multi then
				data.Options[index] = {
					Type = option.Type,
					Value = shallowCopy(option.Value),
				}
			elseif option.Type ~= "Label" and option.Value ~= nil then
				data.Options[index] = {
					Type = option.Type,
					Value = option.Value,
				}
			end
		end
	end

	return data
end

function SaveManager:Apply(data)
	if not self.Library or type(data) ~= "table" then
		return false
	end

	for index, value in pairs(data.Toggles or {}) do
		local toggle = self.Library.Toggles[index]
		if toggle and not self.Ignore[index] then
			toggle:SetValue(value)
		end
	end

	for index, optionData in pairs(data.Options or {}) do
		local option = self.Library.Options[index]
		if option and not self.Ignore[index] then
			if option.Type == "ColorPicker" and optionData.Value then
				option:SetValueRGB(tableToColor(optionData.Value), optionData.Transparency)
			elseif option.Type == "KeyPicker" then
				option:SetValue({ optionData.Value, optionData.Mode, optionData.Modifiers })
			elseif option.SetValue then
				option:SetValue(optionData.Value)
			elseif option.SetText and optionData.Value then
				option:SetText(optionData.Value)
			end
		end
	end

	return true
end

function SaveManager:Save(name)
	name = tostring(name or "default")
	local data = self:Collect()

	if canUseFiles() then
		local HttpService = game:GetService("HttpService")
		makeFolders(self:GetFolder())
		writefile(self:GetPath(name), HttpService:JSONEncode(data))
	else
		self.Memory[name] = data
	end

	return true
end

function SaveManager:Load(name)
	name = tostring(name or "default")

	if canUseFiles() and isfile(self:GetPath(name)) then
		local HttpService = game:GetService("HttpService")
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(readfile(self:GetPath(name)))
		end)
		if ok then
			return self:Apply(decoded)
		end
	elseif self.Memory[name] then
		return self:Apply(self.Memory[name])
	end

	return false
end

function SaveManager:Delete(name)
	name = tostring(name or "default")
	self.Memory[name] = nil

	if canUseFiles() and isfile(self:GetPath(name)) and type(delfile) == "function" then
		delfile(self:GetPath(name))
	end
end

function SaveManager:SetAutoloadConfig(name)
	name = tostring(name or "default")
	self.Autoload = name

	if canUseFiles() then
		makeFolders(self:GetFolder())
		writefile(self:GetAutoloadPath(), name)
	end
end

function SaveManager:LoadAutoloadConfig()
	local name = self.Autoload
	if canUseFiles() and isfile(self:GetAutoloadPath()) then
		name = readfile(self:GetAutoloadPath())
	end

	if name and name ~= "" then
		return self:Load(name)
	end

	return false
end

function SaveManager:BuildConfigSection(tab)
	self.Ignore.SaveManager_ConfigName = true
	self.Ignore.SaveManager_ConfigList = true

	local groupbox = tab:AddRightGroupbox("Configs", "save")

	local configName = groupbox:AddInput("SaveManager_ConfigName", {
		Text = "Config name",
		Default = "default",
		Placeholder = "default",
		Finished = false,
	})

	local configList = groupbox:AddDropdown("SaveManager_ConfigList", {
		Text = "Configs",
		Values = self:GetConfigNames(),
		Default = "default",
		Searchable = true,
	})

	groupbox:AddButton({
		Text = "Save",
		Func = function()
			local name = configName.Value ~= "" and configName.Value or "default"
			self:Save(name)
			configList:SetValues(self:GetConfigNames())
			configList:SetValue(name)
			if self.Library then
				self.Library:Notify({ Title = "Config saved", Description = name, Time = 3 })
			end
		end,
	})

	groupbox:AddButton({
		Text = "Load",
		Func = function()
			local name = configList.Value or configName.Value or "default"
			if self:Load(name) and self.Library then
				self.Library:Notify({ Title = "Config loaded", Description = tostring(name), Time = 3 })
			end
		end,
	})

	groupbox:AddButton({
		Text = "Set Autoload",
		Func = function()
			local name = configList.Value or configName.Value or "default"
			self:SetAutoloadConfig(name)
			if self.Library then
				self.Library:Notify({ Title = "Autoload set", Description = tostring(name), Time = 3 })
			end
		end,
	})

	groupbox:AddButton({
		Text = "Delete",
		DoubleClick = true,
		Func = function()
			local name = configList.Value or configName.Value or "default"
			self:Delete(name)
			configList:SetValues(self:GetConfigNames())
			configList:SetValue("default")
			if self.Library then
				self.Library:Notify({ Title = "Config deleted", Description = tostring(name), Time = 3 })
			end
		end,
	})

	return groupbox
end

return SaveManager
