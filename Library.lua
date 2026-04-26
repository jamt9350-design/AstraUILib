--[[
	Astra UI Library
	A fresh Roblox/Luau UI library with a Linoria/Obsidian-style API.

	Original compatibility target:
	https://github.com/deividcomsono/Obsidian (MIT)
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Teams = game:GetService("Teams")

local LocalPlayer = Players.LocalPlayer

local Library = {
	Name = "Astra",
	Version = "1.0.0",

	Options = {},
	Toggles = {},
	Labels = {},
	Windows = {},
	Keybinds = {},
	ThemeObjects = {},

	ForceCheckbox = false,
	ShowToggleFrameInKeybinds = true,
	ShowCustomCursor = true,
	NotifySide = "Left",
	CornerRadius = 6,
	DPIScale = 100,
	Unloaded = false,

	Scheme = {
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
}

local env = (getgenv and getgenv()) or _G
env.Astra = Library
env.Options = Library.Options
env.Toggles = Library.Toggles

local function safeCall(callback, ...)
	if type(callback) ~= "function" then
		return
	end

	local ok, err = pcall(callback, ...)
	if not ok then
		warn("[Astra] callback error:", err)
	end
end

local function addConnection(connection)
	table.insert(Library._connections, connection)
	return connection
end

Library._connections = {}
Library._unloadCallbacks = {}

local function create(className, props, children)
	local instance = Instance.new(className)

	for key, value in pairs(props or {}) do
		if key ~= "Parent" then
			instance[key] = value
		end
	end

	for _, child in ipairs(children or {}) do
		child.Parent = instance
	end

	if props and props.Parent then
		instance.Parent = props.Parent
	end

	return instance
end

local function applyCorner(instance, radius)
	return create("UICorner", {
		CornerRadius = UDim.new(0, radius or Library.CornerRadius),
		Parent = instance,
	})
end

local function applyStroke(instance, token, thickness)
	local stroke = create("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Thickness = thickness or 1,
		Parent = instance,
	})
	Library:RegisterThemeable(stroke, "Color", token or "Outline")
	return stroke
end

local function applyPadding(instance, left, top, right, bottom)
	return create("UIPadding", {
		PaddingLeft = UDim.new(0, left or 0),
		PaddingTop = UDim.new(0, top or 0),
		PaddingRight = UDim.new(0, right or left or 0),
		PaddingBottom = UDim.new(0, bottom or top or 0),
		Parent = instance,
	})
end

local function applyList(instance, padding, horizontal)
	return create("UIListLayout", {
		FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, padding or 6),
		Parent = instance,
	})
end

local function screenParent()
	local ok, coreGui = pcall(function()
		return game:GetService("CoreGui")
	end)

	if ok and coreGui then
		return coreGui
	end

	local playerGui = LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		return playerGui
	end

	return nil
end

local function protectGui(gui)
	pcall(function()
		if syn and syn.protect_gui then
			syn.protect_gui(gui)
		end
	end)
end

local function getAsset(value)
	if value == nil or value == "" then
		return ""
	end
	if type(value) == "number" then
		return "rbxassetid://" .. tostring(value)
	end
	if type(value) == "string" and value:match("^%d+$") then
		return "rbxassetid://" .. value
	end
	return tostring(value)
end

local function roundTo(value, places)
	places = places or 0
	local factor = 10 ^ places
	return math.floor((value * factor) + 0.5) / factor
end

local function shallowCopy(source)
	local copy = {}
	for key, value in pairs(source or {}) do
		copy[key] = value
	end
	return copy
end

local function mergeColors(base, overrides)
	local merged = shallowCopy(base)
	for key, value in pairs(overrides or {}) do
		merged[key] = value
	end
	return merged
end

local function enumFromKeyName(key)
	if typeof(key) == "EnumItem" then
		return key
	end

	key = tostring(key or "")
	if key == "MB1" then
		return Enum.UserInputType.MouseButton1
	elseif key == "MB2" then
		return Enum.UserInputType.MouseButton2
	elseif key == "MB3" then
		return Enum.UserInputType.MouseButton3
	end

	local ok, enum = pcall(function()
		return Enum.KeyCode[key]
	end)

	if ok and enum then
		return enum
	end

	return Enum.KeyCode.Unknown
end

local function keyNameFromInput(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		return "MB1"
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		return "MB2"
	elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
		return "MB3"
	elseif input.UserInputType == Enum.UserInputType.Keyboard then
		return input.KeyCode.Name
	end

	return input.UserInputType.Name
end

local function inputMatchesKey(input, keyName)
	local enum = enumFromKeyName(keyName)
	if enum.EnumType == Enum.UserInputType then
		return input.UserInputType == enum
	end

	return input.KeyCode == enum
end

local function getPressedModifiers()
	local modifiers = {}
	local keys = {
		Enum.KeyCode.LeftControl,
		Enum.KeyCode.RightControl,
		Enum.KeyCode.LeftShift,
		Enum.KeyCode.RightShift,
		Enum.KeyCode.LeftAlt,
		Enum.KeyCode.RightAlt,
	}

	for _, key in ipairs(keys) do
		if UserInputService:IsKeyDown(key) then
			table.insert(modifiers, key)
		end
	end

	return modifiers
end

local function modifiersMatch(expected)
	if not expected or #expected == 0 then
		return true
	end

	for _, modifier in ipairs(expected) do
		local key = typeof(modifier) == "EnumItem" and modifier or enumFromKeyName(modifier)
		if key.EnumType == Enum.KeyCode and not UserInputService:IsKeyDown(key) then
			return false
		end
	end

	return true
end

local function displayMultiValue(value)
	local selected = {}
	for key, enabled in pairs(value or {}) do
		if enabled then
			table.insert(selected, tostring(key))
		end
	end
	table.sort(selected)
	return #selected > 0 and table.concat(selected, ", ") or "None"
end

local function setVisibleState(instance, visible)
	if instance then
		instance.Visible = visible
	end
end

function Library:RegisterThemeable(instance, property, token)
	if not instance then
		return
	end

	table.insert(self.ThemeObjects, {
		Object = instance,
		Property = property,
		Token = token,
	})

	local value = self.Scheme[token]
	if value ~= nil then
		pcall(function()
			instance[property] = value
		end)
	end
end

function Library:SetTheme(colors)
	self.Scheme = mergeColors(self.Scheme, colors)

	for index = #self.ThemeObjects, 1, -1 do
		local entry = self.ThemeObjects[index]
		if entry.Object and entry.Object.Parent ~= nil then
			local value = self.Scheme[entry.Token]
			if value ~= nil then
				pcall(function()
					entry.Object[entry.Property] = value
				end)
			end
		else
			table.remove(self.ThemeObjects, index)
		end
	end
end

function Library:SetDPIScale(dpi)
	self.DPIScale = tonumber(dpi) or 100

	for _, window in ipairs(self.Windows) do
		if window.Scale then
			window.Scale.Scale = self.DPIScale / 100
		end
	end
end

function Library:SetNotifySide(side)
	self.NotifySide = side == "Right" and "Right" or "Left"

	for _, window in ipairs(self.Windows) do
		if window.NotificationHolder then
			local right = self.NotifySide == "Right"
			window.NotificationHolder.AnchorPoint = right and Vector2.new(1, 0) or Vector2.new(0, 0)
			window.NotificationHolder.Position = right and UDim2.new(1, -16, 0, 18) or UDim2.fromOffset(16, 18)
		end
	end
end

function Library:OnUnload(callback)
	table.insert(self._unloadCallbacks, callback)
end

function Library:Unload()
	if self.Unloaded then
		return
	end

	self.Unloaded = true

	for _, callback in ipairs(self._unloadCallbacks) do
		safeCall(callback)
	end

	for _, connection in ipairs(self._connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end

	for _, window in ipairs(self.Windows) do
		if window.Gui then
			window.Gui:Destroy()
		end
	end

	table.clear(self.Windows)
	table.clear(self._connections)
end

local function makeDraggable(frame, handle)
	handle = handle or frame
	local dragging = false
	local dragStart
	local startPosition

	addConnection(handle.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		dragging = true
		dragStart = input.Position
		startPosition = frame.Position

		addConnection(input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
			end
		end))
	end))

	addConnection(UserInputService.InputChanged:Connect(function(input)
		if not dragging then
			return
		end

		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		local delta = input.Position - dragStart
		frame.Position = UDim2.new(
			startPosition.X.Scale,
			startPosition.X.Offset + delta.X,
			startPosition.Y.Scale,
			startPosition.Y.Offset + delta.Y
		)
	end))
end

local function makeTooltip(window, target, text, disabledText, disabledGetter)
	if not window or not window.Tooltip or (not text and not disabledText) then
		return
	end

	addConnection(target.MouseEnter:Connect(function()
		local useDisabled = disabledGetter and disabledGetter()
		local tooltipText = useDisabled and disabledText or text
		if not tooltipText or tooltipText == "" then
			return
		end

		window.Tooltip.Text = tostring(tooltipText)
		window.Tooltip.Visible = true
	end))

	addConnection(target.MouseLeave:Connect(function()
		window.Tooltip.Visible = false
	end))
end

local function registerOption(index, object, isToggle)
	if not index then
		return
	end

	if isToggle then
		Library.Toggles[index] = object
	else
		Library.Options[index] = object
	end
end

local function fireCallbacks(object, value)
	safeCall(object.Callback, value)
	for _, callback in ipairs(object.Callbacks or {}) do
		safeCall(callback, value)
	end
end

local function addCommonMethods(object)
	function object:OnChanged(callback)
		table.insert(self.Callbacks, callback)
		return self
	end

	function object:SetVisible(value)
		self.Visible = value ~= false
		setVisibleState(self.Root, self.Visible)
		return self
	end

	function object:SetDisabled(value)
		self.Disabled = value == true
		if self.Update then
			self:Update()
		end
		return self
	end

	function object:SetText(text)
		self.Text = tostring(text or "")
		if self.Label then
			self.Label.Text = self.Text
		end
		if self.Update then
			self:Update()
		end
		return self
	end
end

local ContainerMethods = {}
ContainerMethods.__index = ContainerMethods

local function refreshCanvas(scroller, layout)
	local function update()
		scroller.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 12)
	end

	update()
	addConnection(layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(update))
end

local function makeElementRow(container, height)
	local row = create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, height or 32),
		Parent = container.Content,
	})

	return row
end

local function makeAccessory(row)
	local accessory = create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(96, 24),
		Parent = row,
	})

	applyList(accessory, 4, true)
	return accessory
end

local function createPopup(window, size, title)
	local popup = create("Frame", {
		BackgroundColor3 = Library.Scheme.Panel,
		BorderSizePixel = 0,
		Size = size,
		Visible = false,
		ZIndex = 80,
		Parent = window.Gui,
	})
	Library:RegisterThemeable(popup, "BackgroundColor3", "Panel")
	applyCorner(popup, Library.CornerRadius)
	applyStroke(popup, "Outline")
	applyPadding(popup, 10, 8, 10, 10)
	applyList(popup, 6)

	if title then
		local label = create("TextLabel", {
			BackgroundTransparency = 1,
			Font = window.Font,
			Text = title,
			TextColor3 = Library.Scheme.Text,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, 18),
			ZIndex = 81,
			Parent = popup,
		})
		Library:RegisterThemeable(label, "TextColor3", "Text")
	end

	return popup
end

local function positionPopupNear(popup, anchor)
	local pos = anchor.AbsolutePosition
	local size = anchor.AbsoluteSize
	popup.Position = UDim2.fromOffset(pos.X, pos.Y + size.Y + 6)
end

local function attachColorPicker(parentObject, index, info)
	info = info or {}

	local window = parentObject.Window
	local accessory = parentObject.Accessory or makeAccessory(parentObject.Root)
	parentObject.Accessory = accessory

	local button = create("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = info.Default or Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(22, 22),
		Text = "",
		ZIndex = 15,
		Parent = accessory,
	})
	applyCorner(button, 5)
	applyStroke(button, "Outline")

	local object = {
		Type = "ColorPicker",
		Index = index,
		Root = button,
		Button = button,
		Window = window,
		ParentObject = parentObject,
		Value = info.Default or Color3.new(1, 1, 1),
		Transparency = info.Transparency,
		Title = info.Title or "Color",
		Callback = info.Callback or info.Changed,
		Callbacks = {},
	}
	addCommonMethods(object)

	local popup = createPopup(window, UDim2.fromOffset(190, info.Transparency ~= nil and 174 or 142), object.Title)
	object.Popup = popup

	local boxes = {}
	local labels = { "R", "G", "B" }

	local function updateButton()
		button.BackgroundColor3 = object.Value
	end

	local function setFromBoxes()
		local r = math.clamp(tonumber(boxes.R.Text) or 255, 0, 255)
		local g = math.clamp(tonumber(boxes.G.Text) or 255, 0, 255)
		local b = math.clamp(tonumber(boxes.B.Text) or 255, 0, 255)
		local transparency = object.Transparency
		if boxes.A then
			transparency = math.clamp((tonumber(boxes.A.Text) or 0) / 100, 0, 1)
		end
		object:SetValueRGB(Color3.fromRGB(r, g, b), transparency)
	end

	local function addBox(labelName)
		local line = create("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 24),
			ZIndex = 81,
			Parent = popup,
		})

		local label = create("TextLabel", {
			BackgroundTransparency = 1,
			Font = window.Font,
			Text = labelName,
			TextColor3 = Library.Scheme.MutedText,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.fromOffset(28, 24),
			ZIndex = 82,
			Parent = line,
		})
		Library:RegisterThemeable(label, "TextColor3", "MutedText")

		local box = create("TextBox", {
			BackgroundColor3 = Library.Scheme.PanelAlt,
			BorderSizePixel = 0,
			ClearTextOnFocus = false,
			Font = window.Font,
			Text = "0",
			TextColor3 = Library.Scheme.Text,
			TextSize = 12,
			Position = UDim2.fromOffset(34, 0),
			Size = UDim2.new(1, -34, 1, 0),
			ZIndex = 82,
			Parent = line,
		})
		Library:RegisterThemeable(box, "BackgroundColor3", "PanelAlt")
		Library:RegisterThemeable(box, "TextColor3", "Text")
		applyCorner(box, 4)

		addConnection(box.FocusLost:Connect(setFromBoxes))
		boxes[labelName] = box
	end

	for _, labelName in ipairs(labels) do
		addBox(labelName)
	end

	if info.Transparency ~= nil then
		addBox("A")
	end

	function object:UpdateBoxes()
		boxes.R.Text = tostring(math.floor((self.Value.R * 255) + 0.5))
		boxes.G.Text = tostring(math.floor((self.Value.G * 255) + 0.5))
		boxes.B.Text = tostring(math.floor((self.Value.B * 255) + 0.5))
		if boxes.A then
			boxes.A.Text = tostring(math.floor(((self.Transparency or 0) * 100) + 0.5))
		end
	end

	function object:SetValue(hsv, transparency)
		hsv = hsv or {}
		local h = hsv.H or hsv[1] or 0
		local s = hsv.S or hsv[2] or 1
		local v = hsv.V or hsv[3] or 1
		return self:SetValueRGB(Color3.fromHSV(h, s, v), transparency)
	end

	function object:SetValueRGB(color, transparency)
		if typeof(color) ~= "Color3" then
			return self
		end

		self.Value = color
		if transparency ~= nil then
			self.Transparency = math.clamp(tonumber(transparency) or 0, 0, 1)
		end
		updateButton()
		self:UpdateBoxes()
		fireCallbacks(self, self.Value)
		return self
	end

	function object:AddColorPicker(nextIndex, nextInfo)
		return attachColorPicker(self.ParentObject, nextIndex, nextInfo)
	end

	function object:AddKeyPicker(nextIndex, nextInfo)
		return attachKeyPicker(self.ParentObject, nextIndex, nextInfo)
	end

	addConnection(button.MouseButton1Click:Connect(function()
		positionPopupNear(popup, button)
		popup.Visible = not popup.Visible
	end))

	object:UpdateBoxes()
	registerOption(index, object, false)
	return object
end

local function attachKeyPicker(parentObject, index, info)
	info = info or {}

	local window = parentObject.Window
	local accessory = parentObject.Accessory or makeAccessory(parentObject.Root)
	parentObject.Accessory = accessory

	local button = create("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = Library.Scheme.PanelAlt,
		BorderSizePixel = 0,
		Font = window.Font,
		Text = tostring(info.Default or "None"),
		TextColor3 = Library.Scheme.Text,
		TextSize = 11,
		Size = UDim2.fromOffset(58, 22),
		ZIndex = 15,
		Parent = accessory,
	})
	Library:RegisterThemeable(button, "BackgroundColor3", "PanelAlt")
	Library:RegisterThemeable(button, "TextColor3", "Text")
	applyCorner(button, 5)
	applyStroke(button, "Outline")

	local object = {
		Type = "KeyPicker",
		Index = index,
		Root = button,
		Button = button,
		Window = window,
		ParentToggle = parentObject.Type == "Toggle" and parentObject or nil,
		Text = info.Text or index or "Keybind",
		Value = tostring(info.Default or "None"),
		Mode = info.Mode or "Toggle",
		Modes = info.Modes or { "Always", "Toggle", "Hold", "Press" },
		Modifiers = info.DefaultModifiers,
		SyncToggleState = info.SyncToggleState == true,
		NoUI = info.NoUI == true,
		WaitForCallback = info.WaitForCallback == true,
		Callback = info.Callback,
		ChangedCallback = info.ChangedCallback or info.Changed,
		Clicked = info.Clicked,
		Callbacks = {},
		State = false,
		Listening = false,
		Busy = false,
	}
	addCommonMethods(object)

	function object:Update()
		local text = self.Value
		if self.Listening then
			text = "..."
		end
		button.Text = text

		if self.MenuButton then
			self.MenuButton.Text = string.format("%s [%s]", self.Text, self.Mode)
		end
	end

	function object:SetValue(value)
		if type(value) == "table" then
			self.Value = tostring(value[1] or self.Value)
			self.Mode = tostring(value[2] or self.Mode)
			self.Modifiers = value[3] or value.Modifiers or self.Modifiers
		else
			self.Value = tostring(value)
		end

		self.State = self.Mode == "Always"
		self:Update()
		safeCall(self.ChangedCallback, enumFromKeyName(self.Value), self.Modifiers)
		for _, callback in ipairs(self.Callbacks) do
			safeCall(callback, self.Value)
		end
		return self
	end

	function object:GetState()
		if self.Mode == "Always" then
			return true
		end
		return self.State == true
	end

	function object:OnClick(callback)
		self.Clicked = callback
		return self
	end

	addConnection(button.MouseButton1Click:Connect(function()
		object.Listening = true
		object:Update()
	end))

	addConnection(UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed and not object.Listening then
			return
		end

		if object.Listening then
			local name = keyNameFromInput(input)
			if name ~= "MouseMovement" then
				object.Listening = false
				object.Modifiers = getPressedModifiers()
				object:SetValue({ name, object.Mode, object.Modifiers })
			end
			return
		end

		if not inputMatchesKey(input, object.Value) or not modifiersMatch(object.Modifiers) then
			return
		end

		if object.WaitForCallback and object.Busy then
			return
		end

		object.Busy = true

		if object.Mode == "Hold" then
			object.State = true
			safeCall(object.Callback, true)
		elseif object.Mode == "Press" then
			safeCall(object.Callback, true)
			safeCall(object.Clicked, true)
		elseif object.Mode == "Always" then
			object.State = true
			safeCall(object.Callback, true)
			safeCall(object.Clicked, true)
		else
			object.State = not object.State
			if object.SyncToggleState and object.ParentToggle then
				object.ParentToggle:SetValue(object.State)
			end
			safeCall(object.Callback, object.State)
			safeCall(object.Clicked, object.State)
		end

		object.Busy = false
	end))

	addConnection(UserInputService.InputEnded:Connect(function(input)
		if object.Mode ~= "Hold" then
			return
		end

		if inputMatchesKey(input, object.Value) then
			object.State = false
			safeCall(object.Callback, false)
		end
	end))

	table.insert(Library.Keybinds, object)
	Library:_AddKeybindToMenu(object)

	object:Update()
	registerOption(index, object, false)
	return object
end

local function parseLabelArgs(a, b, c)
	if type(a) == "table" then
		return nil, a
	end

	if type(b) == "table" then
		return a, b
	end

	return c, {
		Text = tostring(a or ""),
		DoesWrap = b == true,
	}
end

function ContainerMethods:_adopt(window, content, layout)
	self.Window = window
	self.Content = content
	self.Layout = layout
	return self
end

function ContainerMethods:AddLabel(a, b, c)
	local index, info = parseLabelArgs(a, b, c)
	info = info or {}

	local row = makeElementRow(self, info.DoesWrap and 54 or 24)
	if info.DoesWrap then
		row.AutomaticSize = Enum.AutomaticSize.Y
	end

	local label = create("TextLabel", {
		BackgroundTransparency = 1,
		Font = self.Window.Font,
		Text = tostring(info.Text or ""),
		TextColor3 = Library.Scheme.Text,
		TextSize = info.Size or 13,
		TextWrapped = info.DoesWrap == true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, -6, 0, info.DoesWrap and 48 or 24),
		AutomaticSize = info.DoesWrap and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
		Parent = row,
	})
	Library:RegisterThemeable(label, "TextColor3", "Text")

	local object = {
		Type = "Label",
		Index = index,
		Root = row,
		Label = label,
		Window = self.Window,
		Text = label.Text,
		Callbacks = {},
	}
	addCommonMethods(object)

	function object:SetText(text)
		self.Text = tostring(text or "")
		self.Label.Text = self.Text
		return self
	end

	function object:AddColorPicker(colorIndex, colorInfo)
		return attachColorPicker(self, colorIndex, colorInfo)
	end

	function object:AddKeyPicker(keyIndex, keyInfo)
		return attachKeyPicker(self, keyIndex, keyInfo)
	end

	if index then
		Library.Labels[index] = object
		registerOption(index, object, false)
	end

	return object
end

function ContainerMethods:AddDivider()
	local row = makeElementRow(self, 13)
	local line = create("Frame", {
		BackgroundColor3 = Library.Scheme.Outline,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(1, 0, 0, 1),
		Parent = row,
	})
	Library:RegisterThemeable(line, "BackgroundColor3", "Outline")
	return line
end

local function createToggle(container, index, info, checkbox)
	info = info or {}
	local row = makeElementRow(container, 30)

	local hit = create("TextButton", {
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		Text = "",
		Parent = row,
	})

	local box = create("Frame", {
		BackgroundColor3 = Library.Scheme.PanelAlt,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.fromOffset(17, 17),
		Parent = row,
	})
	Library:RegisterThemeable(box, "BackgroundColor3", "PanelAlt")
	applyCorner(box, checkbox and 4 or 9)
	applyStroke(box, "Outline")

	local fill = create("Frame", {
		BackgroundColor3 = Library.Scheme.Accent,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.new(1, -6, 1, -6),
		Visible = false,
		Parent = box,
	})
	Library:RegisterThemeable(fill, "BackgroundColor3", "Accent")
	applyCorner(fill, checkbox and 3 or 7)

	local label = create("TextLabel", {
		BackgroundTransparency = 1,
		Font = container.Window.Font,
		Text = tostring(info.Text or index or "Toggle"),
		TextColor3 = info.Risky and Library.Scheme.Red or Library.Scheme.Text,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(26, 0),
		Size = UDim2.new(1, -126, 1, 0),
		Parent = row,
	})
	Library:RegisterThemeable(label, "TextColor3", info.Risky and "Red" or "Text")

	local object = {
		Type = "Toggle",
		Index = index,
		Root = row,
		Button = hit,
		Label = label,
		Box = box,
		Fill = fill,
		Window = container.Window,
		Text = label.Text,
		Value = info.Default == true,
		Visible = info.Visible ~= false,
		Disabled = info.Disabled == true,
		Callback = info.Callback,
		Callbacks = {},
		Style = checkbox and "Checkbox" or "Toggle",
	}
	addCommonMethods(object)

	function object:Update()
		fill.Visible = self.Value == true
		label.TextTransparency = self.Disabled and 0.45 or 0
		box.BackgroundTransparency = self.Disabled and 0.35 or 0
	end

	function object:SetValue(value)
		self.Value = value == true
		self:Update()
		fireCallbacks(self, self.Value)
		return self
	end

	function object:AddColorPicker(colorIndex, colorInfo)
		return attachColorPicker(self, colorIndex, colorInfo)
	end

	function object:AddKeyPicker(keyIndex, keyInfo)
		return attachKeyPicker(self, keyIndex, keyInfo)
	end

	addConnection(hit.MouseButton1Click:Connect(function()
		if object.Disabled then
			return
		end
		object:SetValue(not object.Value)
	end))

	makeTooltip(container.Window, row, info.Tooltip, info.DisabledTooltip, function()
		return object.Disabled
	end)

	object:Update()
	object:SetVisible(object.Visible)
	registerOption(index, object, true)
	return object
end

function ContainerMethods:AddToggle(index, info)
	return createToggle(self, index, info, Library.ForceCheckbox)
end

function ContainerMethods:AddCheckbox(index, info)
	return createToggle(self, index, info, true)
end

function ContainerMethods:AddButton(a, b)
	local info
	if type(a) == "table" then
		info = a
	else
		info = { Text = tostring(a or "Button"), Func = b }
	end
	info = info or {}

	local row = makeElementRow(self, 31)
	local button = create("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = Library.Scheme.PanelAlt,
		BorderSizePixel = 0,
		Font = self.Window.Font,
		Text = tostring(info.Text or "Button"),
		TextColor3 = info.Risky and Library.Scheme.Red or Library.Scheme.Text,
		TextSize = 13,
		Size = UDim2.new(1, 0, 1, -3),
		Parent = row,
	})
	Library:RegisterThemeable(button, "BackgroundColor3", "PanelAlt")
	Library:RegisterThemeable(button, "TextColor3", info.Risky and "Red" or "Text")
	applyCorner(button, Library.CornerRadius)
	applyStroke(button, "Outline")

	local object = {
		Type = "Button",
		Root = row,
		Button = button,
		Window = self.Window,
		Container = self,
		Text = button.Text,
		Disabled = info.Disabled == true,
		Visible = info.Visible ~= false,
		LastClick = 0,
	}
	addCommonMethods(object)

	function object:Update()
		button.TextTransparency = self.Disabled and 0.45 or 0
		button.BackgroundTransparency = self.Disabled and 0.35 or 0
	end

	function object:AddButton(nextInfo, nextFunc)
		return self.Container:AddButton(nextInfo, nextFunc)
	end

	addConnection(button.MouseButton1Click:Connect(function()
		if object.Disabled then
			return
		end

		if info.DoubleClick then
			local now = os.clock()
			if now - object.LastClick > 0.7 then
				object.LastClick = now
				button.Text = "Click again"
				task.delay(0.7, function()
					if button and button.Parent then
						button.Text = object.Text
					end
				end)
				return
			end
		end

		safeCall(info.Func)
	end))

	makeTooltip(self.Window, row, info.Tooltip, info.DisabledTooltip, function()
		return object.Disabled
	end)

	object:Update()
	object:SetVisible(object.Visible)
	return object
end

function ContainerMethods:AddSlider(index, info)
	info = info or {}
	local compact = info.Compact == true
	local row = makeElementRow(self, compact and 36 or 53)

	local label = create("TextLabel", {
		BackgroundTransparency = 1,
		Font = self.Window.Font,
		Text = tostring(info.Text or index or "Slider"),
		TextColor3 = Library.Scheme.Text,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -82, 0, compact and 0 or 20),
		Visible = not compact,
		Parent = row,
	})
	Library:RegisterThemeable(label, "TextColor3", "Text")

	local valueLabel = create("TextLabel", {
		BackgroundTransparency = 1,
		Font = self.Window.Font,
		TextColor3 = Library.Scheme.MutedText,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.new(1, -78, 0, 0),
		Size = UDim2.fromOffset(78, compact and 18 or 20),
		Parent = row,
	})
	Library:RegisterThemeable(valueLabel, "TextColor3", "MutedText")

	local bar = create("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = Library.Scheme.PanelAlt,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, compact and 8 or 26),
		Size = UDim2.new(1, 0, 0, 16),
		Text = "",
		Parent = row,
	})
	Library:RegisterThemeable(bar, "BackgroundColor3", "PanelAlt")
	applyCorner(bar, 8)

	local fill = create("Frame", {
		BackgroundColor3 = Library.Scheme.Accent,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = bar,
	})
	Library:RegisterThemeable(fill, "BackgroundColor3", "Accent")
	applyCorner(fill, 8)

	local object = {
		Type = "Slider",
		Index = index,
		Root = row,
		Label = label,
		Window = self.Window,
		Text = label.Text,
		Value = tonumber(info.Default) or 0,
		Min = tonumber(info.Min) or 0,
		Max = tonumber(info.Max) or 100,
		Rounding = tonumber(info.Rounding) or 0,
		Suffix = info.Suffix or "",
		HideMax = info.HideMax == true,
		FormatDisplayValue = info.FormatDisplayValue,
		Disabled = info.Disabled == true,
		Visible = info.Visible ~= false,
		Callback = info.Callback,
		Callbacks = {},
	}
	addCommonMethods(object)

	local function displayValue()
		local formatted
		if type(object.FormatDisplayValue) == "function" then
			formatted = object.FormatDisplayValue(object, object.Value)
		end
		if formatted == nil then
			formatted = tostring(object.Value) .. tostring(object.Suffix)
			if not object.HideMax and not compact then
				formatted = formatted .. " / " .. tostring(object.Max) .. tostring(object.Suffix)
			end
		end
		return formatted
	end

	function object:Update()
		local range = math.max(self.Max - self.Min, 0.0001)
		local ratio = math.clamp((self.Value - self.Min) / range, 0, 1)
		fill.Size = UDim2.fromScale(ratio, 1)
		valueLabel.Text = displayValue()
		label.TextTransparency = self.Disabled and 0.45 or 0
		bar.BackgroundTransparency = self.Disabled and 0.35 or 0
	end

	function object:SetValue(value)
		value = tonumber(value) or self.Min
		value = math.clamp(value, self.Min, self.Max)
		value = roundTo(value, self.Rounding)
		self.Value = value
		self:Update()
		fireCallbacks(self, self.Value)
		return self
	end

	local dragging = false
	local function setFromX(x)
		if object.Disabled then
			return
		end

		local ratio = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
		object:SetValue(object.Min + ((object.Max - object.Min) * ratio))
	end

	addConnection(bar.MouseButton1Down:Connect(function(x)
		dragging = true
		setFromX(x)
	end))

	addConnection(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end))

	addConnection(UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setFromX(input.Position.X)
		end
	end))

	makeTooltip(self.Window, row, info.Tooltip, info.DisabledTooltip, function()
		return object.Disabled
	end)

	object:SetValue(object.Value)
	object:SetVisible(object.Visible)
	registerOption(index, object, false)
	return object
end

function ContainerMethods:AddInput(index, info)
	info = info or {}
	local row = makeElementRow(self, 52)

	local label = create("TextLabel", {
		BackgroundTransparency = 1,
		Font = self.Window.Font,
		Text = tostring(info.Text or index or "Input"),
		TextColor3 = Library.Scheme.Text,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 20),
		Parent = row,
	})
	Library:RegisterThemeable(label, "TextColor3", "Text")

	local box = create("TextBox", {
		BackgroundColor3 = Library.Scheme.PanelAlt,
		BorderSizePixel = 0,
		ClearTextOnFocus = info.ClearTextOnFocus == true,
		Font = self.Window.Font,
		PlaceholderText = info.Placeholder or "",
		Text = tostring(info.Default or ""),
		TextColor3 = Library.Scheme.Text,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 0, 24),
		Parent = row,
	})
	Library:RegisterThemeable(box, "BackgroundColor3", "PanelAlt")
	Library:RegisterThemeable(box, "TextColor3", "Text")
	applyCorner(box, Library.CornerRadius)
	applyStroke(box, "Outline")
	applyPadding(box, 8, 0)

	if info.MaxLength then
		box:GetPropertyChangedSignal("Text"):Connect(function()
			if #box.Text > info.MaxLength then
				box.Text = box.Text:sub(1, info.MaxLength)
			end
		end)
	end

	local object = {
		Type = "Input",
		Index = index,
		Root = row,
		Label = label,
		Box = box,
		Window = self.Window,
		Text = label.Text,
		Value = box.Text,
		Disabled = info.Disabled == true,
		Visible = info.Visible ~= false,
		Callback = info.Callback,
		Callbacks = {},
	}
	addCommonMethods(object)

	function object:Update()
		label.TextTransparency = self.Disabled and 0.45 or 0
		box.TextEditable = not self.Disabled
		box.BackgroundTransparency = self.Disabled and 0.35 or 0
	end

	function object:SetValue(value)
		value = tostring(value or "")
		if info.Numeric then
			value = value:gsub("[^%d%.%-]", "")
		end
		self.Value = value
		box.Text = value
		fireCallbacks(self, self.Value)
		return self
	end

	local function commit(enterPressed)
		if info.Finished and not enterPressed then
			return
		end
		object:SetValue(box.Text)
	end

	addConnection(box.FocusLost:Connect(commit))
	if not info.Finished then
		addConnection(box:GetPropertyChangedSignal("Text"):Connect(function()
			if box:IsFocused() then
				object:SetValue(box.Text)
			end
		end))
	end

	makeTooltip(self.Window, row, info.Tooltip, info.DisabledTooltip, function()
		return object.Disabled
	end)

	object:Update()
	object:SetVisible(object.Visible)
	registerOption(index, object, false)
	return object
end

function ContainerMethods:AddDropdown(index, info)
	info = info or {}
	local row = makeElementRow(self, 55)
	row.AutomaticSize = Enum.AutomaticSize.Y

	local label = create("TextLabel", {
		BackgroundTransparency = 1,
		Font = self.Window.Font,
		Text = tostring(info.Text or index or "Dropdown"),
		TextColor3 = Library.Scheme.Text,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 20),
		Parent = row,
	})
	Library:RegisterThemeable(label, "TextColor3", "Text")

	local button = create("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = Library.Scheme.PanelAlt,
		BorderSizePixel = 0,
		Font = self.Window.Font,
		Text = "",
		TextColor3 = Library.Scheme.Text,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 0, 25),
		Parent = row,
	})
	Library:RegisterThemeable(button, "BackgroundColor3", "PanelAlt")
	Library:RegisterThemeable(button, "TextColor3", "Text")
	applyCorner(button, Library.CornerRadius)
	applyStroke(button, "Outline")
	applyPadding(button, 8, 0)

	local menu = create("Frame", {
		BackgroundColor3 = Library.Scheme.Panel,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 55),
		Size = UDim2.new(1, 0, 0, 0),
		Visible = false,
		Parent = row,
	})
	Library:RegisterThemeable(menu, "BackgroundColor3", "Panel")
	applyCorner(menu, Library.CornerRadius)
	applyStroke(menu, "Outline")
	applyPadding(menu, 6, 6)

	local searchBox
	if info.Searchable then
		searchBox = create("TextBox", {
			BackgroundColor3 = Library.Scheme.PanelAlt,
			BorderSizePixel = 0,
			ClearTextOnFocus = false,
			Font = self.Window.Font,
			PlaceholderText = "Search...",
			Text = "",
			TextColor3 = Library.Scheme.Text,
			TextSize = 12,
			Size = UDim2.new(1, 0, 0, 24),
			Parent = menu,
		})
		Library:RegisterThemeable(searchBox, "BackgroundColor3", "PanelAlt")
		Library:RegisterThemeable(searchBox, "TextColor3", "Text")
		applyCorner(searchBox, 5)
		applyPadding(searchBox, 8, 0)
	end

	local list = create("ScrollingFrame", {
		Active = true,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(0, 0),
		Position = UDim2.fromOffset(0, info.Searchable and 30 or 0),
		ScrollBarThickness = 3,
		Size = UDim2.new(1, 0, 1, info.Searchable and -30 or 0),
		Parent = menu,
	})
	local listLayout = applyList(list, 3)

	local object = {
		Type = "Dropdown",
		Index = index,
		Root = row,
		Label = label,
		Button = button,
		Menu = menu,
		List = list,
		Window = self.Window,
		Text = label.Text,
		Values = info.Values or {},
		DisabledValues = info.DisabledValues or {},
		Value = info.Multi and {} or nil,
		Multi = info.Multi == true,
		AllowNull = info.AllowNull == true,
		Searchable = info.Searchable == true,
		SpecialType = info.SpecialType,
		ExcludeLocalPlayer = info.ExcludeLocalPlayer == true,
		MaxVisibleDropdownItems = tonumber(info.MaxVisibleDropdownItems) or 8,
		FormatDisplayValue = info.FormatDisplayValue,
		FormatListValue = info.FormatListValue,
		Disabled = info.Disabled == true,
		Visible = info.Visible ~= false,
		Callback = info.Callback,
		Callbacks = {},
		Items = {},
	}
	addCommonMethods(object)

	local function disabledMap()
		local map = {}
		for _, value in ipairs(object.DisabledValues or {}) do
			map[tostring(value)] = true
		end
		return map
	end

	function object:GetSpecialValues()
		if self.SpecialType == "Player" then
			local values = {}
			for _, player in ipairs(Players:GetPlayers()) do
				if not (self.ExcludeLocalPlayer and player == LocalPlayer) then
					table.insert(values, player.Name)
				end
			end
			return values
		elseif self.SpecialType == "Team" then
			local values = {}
			for _, team in ipairs(Teams:GetTeams()) do
				table.insert(values, team.Name)
			end
			return values
		end

		return self.Values
	end

	function object:Format(value)
		if type(self.FormatDisplayValue) == "function" then
			local formatted = self.FormatDisplayValue(value)
			if formatted ~= nil then
				return tostring(formatted)
			end
		end
		return tostring(value)
	end

	function object:FormatList(value)
		if type(self.FormatListValue) == "function" then
			local formatted = self.FormatListValue(value)
			if formatted ~= nil then
				return tostring(formatted)
			end
		end
		return self:Format(value)
	end

	function object:UpdateButton()
		if self.Multi then
			button.Text = displayMultiValue(self.Value)
		else
			button.Text = self.Value ~= nil and self:Format(self.Value) or "None"
		end
		label.TextTransparency = self.Disabled and 0.45 or 0
		button.BackgroundTransparency = self.Disabled and 0.35 or 0
	end

	function object:SetOpen(open)
		if self.Disabled then
			open = false
		end

		if open and self.SpecialType then
			self.Values = self:GetSpecialValues()
			self:Refresh()
		end

		menu.Visible = open
		local itemCount = math.min(#self:GetSpecialValues(), self.MaxVisibleDropdownItems)
		local height = (itemCount * 25) + 12 + (self.Searchable and 30 or 0)
		menu.Size = UDim2.new(1, 0, 0, height)
	end

	function object:Refresh()
		for _, item in ipairs(self.Items) do
			item:Destroy()
		end
		table.clear(self.Items)

		local disabled = disabledMap()
		local values = self:GetSpecialValues()

		for _, value in ipairs(values) do
			local itemButton = create("TextButton", {
				AutoButtonColor = false,
				BackgroundColor3 = Library.Scheme.PanelAlt,
				BackgroundTransparency = 0.2,
				BorderSizePixel = 0,
				Font = self.Window.Font,
				Text = self:FormatList(value),
				TextColor3 = disabled[tostring(value)] and Library.Scheme.MutedText or Library.Scheme.Text,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(1, -2, 0, 23),
				Parent = list,
			})
			Library:RegisterThemeable(itemButton, "BackgroundColor3", "PanelAlt")
			applyCorner(itemButton, 4)
			applyPadding(itemButton, 7, 0)

			addConnection(itemButton.MouseButton1Click:Connect(function()
				if disabled[tostring(value)] then
					return
				end

				if self.Multi then
					local current = shallowCopy(self.Value)
					current[tostring(value)] = not current[tostring(value)]
					self:SetValue(current)
				else
					if self.AllowNull and self.Value == value then
						self:SetValue(nil)
					else
						self:SetValue(value)
					end
					self:SetOpen(false)
				end
			end))

			table.insert(self.Items, itemButton)
		end

		list.CanvasSize = UDim2.fromOffset(0, listLayout.AbsoluteContentSize.Y + 6)
	end

	function object:SetValue(value)
		if self.Multi then
			local result = {}
			if type(value) == "table" then
				for key, enabled in pairs(value) do
					if type(key) == "number" then
						result[tostring(enabled)] = true
					elseif enabled then
						result[tostring(key)] = true
					end
				end
			elseif type(value) == "number" then
				local values = self:GetSpecialValues()
				result[tostring(values[value] or value)] = true
			elseif value ~= nil then
				result[tostring(value)] = true
			end
			self.Value = result
		else
			if type(value) == "number" then
				value = self:GetSpecialValues()[value]
			end
			self.Value = value
		end

		self:UpdateButton()
		fireCallbacks(self, self.Value)
		return self
	end

	function object:SetValues(values)
		self.Values = values or {}
		self:Refresh()
		self:UpdateButton()
		return self
	end

	function object:AddValues(values)
		if type(values) ~= "table" then
			values = { values }
		end
		for _, value in ipairs(values) do
			table.insert(self.Values, value)
		end
		self:Refresh()
		return self
	end

	function object:SetDisabledValues(values)
		self.DisabledValues = values or {}
		self:Refresh()
		return self
	end

	function object:AddDisabledValues(values)
		if type(values) ~= "table" then
			values = { values }
		end
		for _, value in ipairs(values) do
			table.insert(self.DisabledValues, value)
		end
		self:Refresh()
		return self
	end

	local function filterItems()
		local query = searchBox and searchBox.Text:lower() or ""
		for _, item in ipairs(object.Items) do
			item.Visible = query == "" or item.Text:lower():find(query, 1, true) ~= nil
		end
	end

	addConnection(button.MouseButton1Click:Connect(function()
		object:SetOpen(not menu.Visible)
	end))

	if searchBox then
		addConnection(searchBox:GetPropertyChangedSignal("Text"):Connect(filterItems))
	end

	addConnection(listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		list.CanvasSize = UDim2.fromOffset(0, listLayout.AbsoluteContentSize.Y + 6)
	end))

	makeTooltip(self.Window, row, info.Tooltip, info.DisabledTooltip, function()
		return object.Disabled
	end)

	object:Refresh()
	if info.Default ~= nil then
		object:SetValue(info.Default)
	elseif object.Multi then
		object:SetValue({})
	else
		object:UpdateButton()
	end
	object:SetVisible(object.Visible)
	registerOption(index, object, false)
	return object
end

function ContainerMethods:AddKeyBox(callback)
	local row = makeElementRow(self, 58)

	local box = create("TextBox", {
		BackgroundColor3 = Library.Scheme.PanelAlt,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		Font = self.Window.Font,
		PlaceholderText = "Enter key...",
		Text = "",
		TextColor3 = Library.Scheme.Text,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 26),
		Parent = row,
	})
	Library:RegisterThemeable(box, "BackgroundColor3", "PanelAlt")
	Library:RegisterThemeable(box, "TextColor3", "Text")
	applyCorner(box, Library.CornerRadius)
	applyStroke(box, "Outline")
	applyPadding(box, 8, 0)

	local submit = create("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = Library.Scheme.Accent,
		BorderSizePixel = 0,
		Font = self.Window.Font,
		Text = "Submit",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 13,
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.new(1, 0, 0, 24),
		Parent = row,
	})
	Library:RegisterThemeable(submit, "BackgroundColor3", "Accent")
	applyCorner(submit, Library.CornerRadius)

	addConnection(submit.MouseButton1Click:Connect(function()
		safeCall(callback, box.Text)
	end))

	addConnection(box.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			safeCall(callback, box.Text)
		end
	end))

	return {
		Root = row,
		Box = box,
		Button = submit,
	}
end

local function createGroupbox(window, parent, title, icon)
	local root = create("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Library.Scheme.Panel,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -2, 0, 0),
		Parent = parent,
	})
	Library:RegisterThemeable(root, "BackgroundColor3", "Panel")
	applyCorner(root, Library.CornerRadius)
	applyStroke(root, "Outline")

	local header = create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 31),
		Parent = root,
	})

	local titleLabel = create("TextLabel", {
		BackgroundTransparency = 1,
		Font = window.Font,
		Text = tostring(title or "Groupbox"),
		TextColor3 = Library.Scheme.Text,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -20, 1, 0),
		Parent = header,
	})
	Library:RegisterThemeable(titleLabel, "TextColor3", "Text")

	local content = create("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 33),
		Size = UDim2.new(1, -20, 0, 0),
		Parent = root,
	})
	applyPadding(content, 0, 0, 0, 10)
	local layout = applyList(content, 6)

	local group = setmetatable({
		Type = "Groupbox",
		Window = window,
		Root = root,
		Title = titleLabel,
		Content = content,
		Layout = layout,
		Icon = icon,
	}, ContainerMethods)

	return group
end

local function createColumn(parent)
	local scroller = create("ScrollingFrame", {
		Active = true,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(0, 0),
		ScrollBarImageTransparency = 0.25,
		ScrollBarThickness = 4,
		Size = UDim2.new(0.5, -5, 1, 0),
		Parent = parent,
	})
	local layout = applyList(scroller, 8)
	applyPadding(scroller, 0, 0, 4, 8)
	refreshCanvas(scroller, layout)
	return scroller, layout
end

local function createTabbox(window, parent)
	local root = create("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Library.Scheme.Panel,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -2, 0, 180),
		Parent = parent,
	})
	Library:RegisterThemeable(root, "BackgroundColor3", "Panel")
	applyCorner(root, Library.CornerRadius)
	applyStroke(root, "Outline")

	local tabRow = create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -14, 0, 30),
		Position = UDim2.fromOffset(7, 7),
		Parent = root,
	})
	local tabLayout = applyList(tabRow, 5, true)

	local pages = create("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 42),
		Size = UDim2.new(1, -16, 0, 130),
		Parent = root,
	})

	local tabbox = {
		Type = "Tabbox",
		Window = window,
		Root = root,
		TabRow = tabRow,
		Pages = pages,
		Tabs = {},
		Selected = nil,
	}

	function tabbox:Select(tab)
		for _, entry in ipairs(self.Tabs) do
			entry.Page.Visible = entry == tab
			entry.Button.BackgroundColor3 = entry == tab and Library.Scheme.AccentDark or Library.Scheme.PanelAlt
		end
		self.Selected = tab
	end

	function tabbox:AddTab(name)
		local button = create("TextButton", {
			AutoButtonColor = false,
			BackgroundColor3 = Library.Scheme.PanelAlt,
			BorderSizePixel = 0,
			Font = window.Font,
			Text = tostring(name or "Tab"),
			TextColor3 = Library.Scheme.Text,
			TextSize = 12,
			Size = UDim2.fromOffset(92, 26),
			Parent = tabRow,
		})
		Library:RegisterThemeable(button, "TextColor3", "Text")
		applyCorner(button, 5)

		local page = create("ScrollingFrame", {
			Active = true,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.fromOffset(0, 0),
			ScrollBarThickness = 3,
			Size = UDim2.new(1, 0, 0, 130),
			Visible = false,
			Parent = pages,
		})
		local layout = applyList(page, 6)
		refreshCanvas(page, layout)

		local tab = setmetatable({
			Type = "TabboxTab",
			Window = window,
			Root = page,
			Content = page,
			Layout = layout,
			Button = button,
			Page = page,
			Name = name,
		}, ContainerMethods)

		addConnection(button.MouseButton1Click:Connect(function()
			self:Select(tab)
		end))

		table.insert(self.Tabs, tab)
		if not self.Selected then
			self:Select(tab)
		end

		tabRow.Size = UDim2.new(1, -14, 0, tabLayout.AbsoluteContentSize.Y)
		return tab
	end

	return tabbox
end

local WindowMethods = {}
WindowMethods.__index = WindowMethods

local TabMethods = {}
TabMethods.__index = TabMethods

function TabMethods:AddLeftGroupbox(title, icon)
	return createGroupbox(self.Window, self.LeftColumn, title, icon)
end

function TabMethods:AddRightGroupbox(title, icon)
	return createGroupbox(self.Window, self.RightColumn, title, icon)
end

function TabMethods:AddLeftTabbox()
	return createTabbox(self.Window, self.LeftColumn)
end

function TabMethods:AddRightTabbox()
	return createTabbox(self.Window, self.RightColumn)
end

function TabMethods:_defaultGroup()
	if not self.DefaultGroup then
		self.DefaultGroup = self:AddLeftGroupbox(self.Name)
	end
	return self.DefaultGroup
end

function TabMethods:AddLabel(...)
	return self:_defaultGroup():AddLabel(...)
end

function TabMethods:AddKeyBox(...)
	return self:_defaultGroup():AddKeyBox(...)
end

function TabMethods:AddToggle(...)
	return self:_defaultGroup():AddToggle(...)
end

function TabMethods:AddCheckbox(...)
	return self:_defaultGroup():AddCheckbox(...)
end

function TabMethods:AddButton(...)
	return self:_defaultGroup():AddButton(...)
end

function TabMethods:AddSlider(...)
	return self:_defaultGroup():AddSlider(...)
end

function TabMethods:AddInput(...)
	return self:_defaultGroup():AddInput(...)
end

function TabMethods:AddDropdown(...)
	return self:_defaultGroup():AddDropdown(...)
end

function TabMethods:UpdateWarningBox(info)
	info = info or {}
	if not self.WarningBox then
		self.WarningBox = create("Frame", {
			BackgroundColor3 = Library.Scheme.PanelAlt,
			BorderSizePixel = 0,
			Size = UDim2.new(1, -2, 0, 74),
			Parent = self.LeftColumn,
		})
		Library:RegisterThemeable(self.WarningBox, "BackgroundColor3", "PanelAlt")
		applyCorner(self.WarningBox, Library.CornerRadius)
		applyStroke(self.WarningBox, "Yellow")

		self.WarningTitle = create("TextLabel", {
			BackgroundTransparency = 1,
			Font = self.Window.Font,
			RichText = true,
			TextColor3 = Library.Scheme.Yellow,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(10, 6),
			Size = UDim2.new(1, -20, 0, 20),
			Parent = self.WarningBox,
		})
		Library:RegisterThemeable(self.WarningTitle, "TextColor3", "Yellow")

		self.WarningText = create("TextLabel", {
			BackgroundTransparency = 1,
			Font = self.Window.Font,
			RichText = true,
			TextColor3 = Library.Scheme.Text,
			TextSize = 12,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(10, 28),
			Size = UDim2.new(1, -20, 1, -34),
			Parent = self.WarningBox,
		})
		Library:RegisterThemeable(self.WarningText, "TextColor3", "Text")
	end

	self.WarningBox.Visible = info.Visible == true
	self.WarningTitle.Text = info.Title or "Warning"
	self.WarningText.Text = info.Text or ""
end

function WindowMethods:SelectTab(tab)
	for _, entry in pairs(self.Tabs) do
		entry.Page.Visible = entry == tab
		entry.Button.BackgroundColor3 = entry == tab and Library.Scheme.AccentDark or Library.Scheme.Panel
	end
	self.SelectedTab = tab
end

function WindowMethods:AddTab(name, icon)
	local button = create("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = Library.Scheme.Panel,
		BorderSizePixel = 0,
		Font = self.Font,
		Text = tostring(name or "Tab"),
		TextColor3 = Library.Scheme.Text,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -10, 0, 31),
		Parent = self.TabList,
	})
	Library:RegisterThemeable(button, "TextColor3", "Text")
	applyCorner(button, 5)
	applyPadding(button, 10, 0)

	local page = create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		Visible = false,
		Parent = self.Content,
	})

	local leftColumn, leftLayout = createColumn(page)
	leftColumn.Position = UDim2.fromOffset(0, 0)

	local rightColumn, rightLayout = createColumn(page)
	rightColumn.AnchorPoint = Vector2.new(1, 0)
	rightColumn.Position = UDim2.new(1, 0, 0, 0)

	local tab = setmetatable({
		Type = "Tab",
		Name = tostring(name or "Tab"),
		Icon = icon,
		Window = self,
		Button = button,
		Page = page,
		LeftColumn = leftColumn,
		RightColumn = rightColumn,
		LeftLayout = leftLayout,
		RightLayout = rightLayout,
	}, TabMethods)

	self.Tabs[tab.Name] = tab
	table.insert(self.TabOrder, tab)

	addConnection(button.MouseButton1Click:Connect(function()
		self:SelectTab(tab)
	end))

	if not self.SelectedTab then
		self:SelectTab(tab)
	end

	return tab
end

function WindowMethods:AddKeyTab(name)
	return self:AddTab(name or "Key System", "key")
end

function WindowMethods:Toggle()
	self.Main.Visible = not self.Main.Visible
end

function WindowMethods:ChangeTitle(title)
	self.Title = tostring(title or "")
	self.TitleLabel.Text = self.Title
end

function WindowMethods:SetFooter(text)
	self.Footer = tostring(text or "")
	self.FooterLabel.Text = self.Footer
end

function WindowMethods:SetBackgroundImage(image)
	if not self.BackgroundImage then
		return
	end
	self.BackgroundImage.Image = getAsset(image)
end

function WindowMethods:SetCornerRadius(radius)
	Library.CornerRadius = tonumber(radius) or Library.CornerRadius
	for _, corner in ipairs(self.Corners) do
		if corner and corner.Parent then
			corner.CornerRadius = UDim.new(0, Library.CornerRadius)
		end
	end
end

function WindowMethods:GetSidebarWidth()
	return self.Sidebar.Size.X.Offset
end

function WindowMethods:IsSidebarCompacted()
	return self.SidebarCompacted == true
end

function WindowMethods:SetSidebarWidth(width)
	width = math.clamp(tonumber(width) or self.SidebarWidth, self.MinSidebarWidth, 320)
	self.SidebarWidth = width
	self.Sidebar.Size = UDim2.new(0, width, 1, 0)
	self.Content.Position = UDim2.fromOffset(width + 8, 0)
	self.Content.Size = UDim2.new(1, -(width + 8), 1, 0)
end

function WindowMethods:SetCompact(compact)
	self.SidebarCompacted = compact == true
	if self.SidebarCompacted then
		self.LastSidebarWidth = self.SidebarWidth
		self:SetSidebarWidth(self.SidebarCompactWidth)
	else
		self:SetSidebarWidth(self.LastSidebarWidth or self.MinSidebarWidth)
	end
end

function WindowMethods:ApplyLayout()
	self:SetSidebarWidth(self.SidebarWidth)
end

function Library:_AddKeybindToMenu(keybind)
	if keybind.NoUI or not self.KeybindFrame then
		return
	end

	local row = create("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = self.Scheme.PanelAlt,
		BorderSizePixel = 0,
		Font = Enum.Font.Gotham,
		Text = "",
		TextColor3 = self.Scheme.Text,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 24),
		Parent = self.KeybindList,
	})
	self:RegisterThemeable(row, "BackgroundColor3", "PanelAlt")
	self:RegisterThemeable(row, "TextColor3", "Text")
	applyCorner(row, 4)
	applyPadding(row, 7, 0)

	keybind.MenuButton = row
	keybind:Update()

	addConnection(row.MouseButton1Click:Connect(function()
		keybind.State = not keybind.State
		if keybind.SyncToggleState and keybind.ParentToggle then
			keybind.ParentToggle:SetValue(keybind.State)
		end
		safeCall(keybind.Callback, keybind.State)
		safeCall(keybind.Clicked, keybind.State)
	end))
end

function Library:Notify(message)
	local info = type(message) == "table" and message or { Title = "Astra", Description = tostring(message) }
	local window = self.Windows[#self.Windows]

	if not window then
		return
	end

	local holder = window.NotificationHolder
	local card = create("Frame", {
		BackgroundColor3 = self.Scheme.Panel,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(286, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = holder,
	})
	self:RegisterThemeable(card, "BackgroundColor3", "Panel")
	applyCorner(card, self.CornerRadius)
	applyStroke(card, "Outline")
	applyPadding(card, 10, 8, 10, 8)

	local title = create("TextLabel", {
		BackgroundTransparency = 1,
		Font = window.Font,
		Text = tostring(info.Title or "Notification"),
		TextColor3 = self.Scheme.Text,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 20),
		Parent = card,
	})
	self:RegisterThemeable(title, "TextColor3", "Text")

	local body = create("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Font = window.Font,
		Text = tostring(info.Description or info.Content or ""),
		TextColor3 = self.Scheme.MutedText,
		TextSize = 12,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(0, 22),
		Size = UDim2.new(1, 0, 0, 18),
		Parent = card,
	})
	self:RegisterThemeable(body, "TextColor3", "MutedText")

	task.delay(tonumber(info.Time) or 4, function()
		if card and card.Parent then
			TweenService:Create(card, TweenInfo.new(0.18), { BackgroundTransparency = 1 }):Play()
			task.wait(0.2)
			card:Destroy()
		end
	end)
end

function Library:AddDraggableLabel(text)
	local window = self.Windows[#self.Windows]
	if not window then
		return nil
	end

	local label = create("TextLabel", {
		BackgroundColor3 = self.Scheme.Panel,
		BorderSizePixel = 0,
		Font = window.Font,
		Text = tostring(text or "Label"),
		TextColor3 = self.Scheme.Text,
		TextSize = 13,
		Position = UDim2.fromOffset(30, 130),
		Size = UDim2.fromOffset(180, 28),
		Parent = window.Gui,
		ZIndex = 55,
	})
	self:RegisterThemeable(label, "BackgroundColor3", "Panel")
	self:RegisterThemeable(label, "TextColor3", "Text")
	applyCorner(label, self.CornerRadius)
	applyStroke(label, "Outline")
	makeDraggable(label)
	return label
end

function Library:CreateWindow(config)
	config = config or {}
	self.Unloaded = false
	self.NotifySide = config.NotifySide or self.NotifySide
	self.ShowCustomCursor = config.ShowCustomCursor ~= false
	self.CornerRadius = tonumber(config.CornerRadius) or self.CornerRadius

	local gui = create("ScreenGui", {
		Name = "AstraUILibrary",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	protectGui(gui)
	gui.Parent = screenParent()

	local size = config.Size or UDim2.fromOffset(640, 520)
	local position = config.Position or UDim2.new(0.5, -320, 0.5, -260)
	if config.Center == true then
		position = UDim2.new(0.5, -size.X.Offset / 2, 0.5, -size.Y.Offset / 2)
	end

	local main = create("Frame", {
		BackgroundColor3 = self.Scheme.Background,
		BorderSizePixel = 0,
		Position = position,
		Size = size,
		Visible = config.AutoShow ~= false,
		Parent = gui,
	})
	self:RegisterThemeable(main, "BackgroundColor3", "Background")
	local mainCorner = applyCorner(main, self.CornerRadius)
	applyStroke(main, "Outline")

	local scale = create("UIScale", {
		Scale = self.DPIScale / 100,
		Parent = main,
	})

	local header = create("Frame", {
		BackgroundColor3 = self.Scheme.Panel,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 42),
		Parent = main,
	})
	self:RegisterThemeable(header, "BackgroundColor3", "Panel")
	local headerCorner = applyCorner(header, self.CornerRadius)

	if config.Icon then
		create("ImageLabel", {
			BackgroundTransparency = 1,
			Image = getAsset(config.Icon),
			Position = UDim2.fromOffset(12, 8),
			Size = config.IconSize or UDim2.fromOffset(24, 24),
			Parent = header,
		})
	end

	local titleLabel = create("TextLabel", {
		BackgroundTransparency = 1,
		Font = config.Font or Enum.Font.GothamMedium,
		Text = tostring(config.Title or "Astra"),
		TextColor3 = self.Scheme.Text,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(config.Icon and 44 or 14, 0),
		Size = UDim2.new(1, -80, 1, 0),
		Parent = header,
	})
	self:RegisterThemeable(titleLabel, "TextColor3", "Text")

	local body = create("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 52),
		Size = UDim2.new(1, -20, 1, -84),
		Parent = main,
	})

	local sidebarWidth = config.SidebarCompacted and (config.SidebarCompactWidth or 58) or 154
	local sidebar = create("Frame", {
		BackgroundColor3 = self.Scheme.Panel,
		BorderSizePixel = 0,
		Size = UDim2.new(0, sidebarWidth, 1, 0),
		Parent = body,
	})
	self:RegisterThemeable(sidebar, "BackgroundColor3", "Panel")
	local sidebarCorner = applyCorner(sidebar, self.CornerRadius)

	local tabList = create("ScrollingFrame", {
		Active = true,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(0, 0),
		Position = UDim2.fromOffset(6, 8),
		ScrollBarThickness = 2,
		Size = UDim2.new(1, -12, 1, -16),
		Parent = sidebar,
	})
	local tabListLayout = applyList(tabList, 5)
	refreshCanvas(tabList, tabListLayout)

	local content = create("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(sidebarWidth + 8, 0),
		Size = UDim2.new(1, -(sidebarWidth + 8), 1, 0),
		Parent = body,
	})

	local footerLabel = create("TextLabel", {
		BackgroundTransparency = 1,
		Font = config.Font or Enum.Font.Gotham,
		Text = tostring(config.Footer or ""),
		TextColor3 = self.Scheme.MutedText,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.new(0, 12, 1, -26),
		Size = UDim2.new(1, -24, 0, 20),
		Parent = main,
	})
	self:RegisterThemeable(footerLabel, "TextColor3", "MutedText")

	local right = self.NotifySide == "Right"
	local notifyHolder = create("Frame", {
		AnchorPoint = right and Vector2.new(1, 0) or Vector2.new(0, 0),
		BackgroundTransparency = 1,
		Position = right and UDim2.new(1, -16, 0, 18) or UDim2.fromOffset(16, 18),
		Size = UDim2.fromOffset(300, 600),
		Parent = gui,
	})
	applyList(notifyHolder, 8)

	local tooltip = create("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = self.Scheme.Panel,
		BorderSizePixel = 0,
		Font = config.Font or Enum.Font.Gotham,
		Text = "",
		TextColor3 = self.Scheme.Text,
		TextSize = 12,
		Visible = false,
		Position = UDim2.fromOffset(18, 18),
		Size = UDim2.fromOffset(20, 20),
		ZIndex = 100,
		Parent = gui,
	})
	self:RegisterThemeable(tooltip, "BackgroundColor3", "Panel")
	self:RegisterThemeable(tooltip, "TextColor3", "Text")
	applyCorner(tooltip, 4)
	applyStroke(tooltip, "Outline")
	applyPadding(tooltip, 7, 4)

	addConnection(UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			tooltip.Position = UDim2.fromOffset(input.Position.X + 14, input.Position.Y + 14)
		end
	end))

	local keybindFrame = create("Frame", {
		BackgroundColor3 = self.Scheme.Panel,
		BorderSizePixel = 0,
		Position = UDim2.new(1, -236, 0, 70),
		Size = UDim2.fromOffset(220, 260),
		Visible = false,
		Parent = gui,
		ZIndex = 60,
	})
	self:RegisterThemeable(keybindFrame, "BackgroundColor3", "Panel")
	applyCorner(keybindFrame, self.CornerRadius)
	applyStroke(keybindFrame, "Outline")
	applyPadding(keybindFrame, 8, 8)
	makeDraggable(keybindFrame)

	local keybindTitle = create("TextLabel", {
		BackgroundTransparency = 1,
		Font = config.Font or Enum.Font.GothamMedium,
		Text = "Keybinds",
		TextColor3 = self.Scheme.Text,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 22),
		ZIndex = 61,
		Parent = keybindFrame,
	})
	self:RegisterThemeable(keybindTitle, "TextColor3", "Text")

	local keybindList = create("ScrollingFrame", {
		Active = true,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(0, 0),
		Position = UDim2.fromOffset(0, 28),
		ScrollBarThickness = 3,
		Size = UDim2.new(1, 0, 1, -28),
		ZIndex = 61,
		Parent = keybindFrame,
	})
	local keybindLayout = applyList(keybindList, 5)
	refreshCanvas(keybindList, keybindLayout)

	local window = setmetatable({
		Type = "Window",
		Gui = gui,
		Main = main,
		Header = header,
		Body = body,
		Sidebar = sidebar,
		TabList = tabList,
		Content = content,
		FooterLabel = footerLabel,
		TitleLabel = titleLabel,
		NotificationHolder = notifyHolder,
		Tooltip = tooltip,
		KeybindFrame = keybindFrame,
		KeybindList = keybindList,
		Scale = scale,
		Tabs = {},
		TabOrder = {},
		Title = titleLabel.Text,
		Footer = footerLabel.Text,
		Font = config.Font or Enum.Font.Gotham,
		SidebarWidth = sidebarWidth,
		MinSidebarWidth = config.MinSidebarWidth or 130,
		SidebarCompactWidth = config.SidebarCompactWidth or 58,
		SidebarCompacted = config.SidebarCompacted == true,
		Corners = { mainCorner, headerCorner, sidebarCorner },
	}, WindowMethods)

	self.Window = window
	self.KeybindFrame = keybindFrame
	self.KeybindList = keybindList
	table.insert(self.Windows, window)

	for _, keybind in ipairs(self.Keybinds) do
		self:_AddKeybindToMenu(keybind)
	end

	makeDraggable(main, header)

	if config.Resizable then
		local handle = create("Frame", {
			AnchorPoint = Vector2.new(1, 1),
			BackgroundColor3 = self.Scheme.Accent,
			BorderSizePixel = 0,
			Position = UDim2.new(1, -4, 1, -4),
			Size = UDim2.fromOffset(12, 12),
			Parent = main,
		})
		self:RegisterThemeable(handle, "BackgroundColor3", "Accent")
		applyCorner(handle, 6)

		local resizing = false
		addConnection(handle.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				resizing = true
			end
		end))
		addConnection(UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				resizing = false
			end
		end))
		addConnection(UserInputService.InputChanged:Connect(function(input)
			if resizing and input.UserInputType == Enum.UserInputType.MouseMovement then
				local relative = input.Position - main.AbsolutePosition
				main.Size = UDim2.fromOffset(math.max(relative.X, 430), math.max(relative.Y, 330))
			end
		end))
	end

	if config.BackgroundImage then
		local background = create("ImageLabel", {
			BackgroundTransparency = 1,
			Image = getAsset(config.BackgroundImage),
			ImageTransparency = 0.82,
			ScaleType = Enum.ScaleType.Crop,
			Size = UDim2.fromScale(1, 1),
			Parent = main,
			ZIndex = 0,
		})
		window.BackgroundImage = background
	end

	local toggleKey = config.ToggleKeybind or Enum.KeyCode.RightShift
	addConnection(UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		local configured = Library.ToggleKeybind
		if configured and configured.Type == "KeyPicker" then
			if inputMatchesKey(input, configured.Value) then
				window:Toggle()
			end
			return
		end

		if input.KeyCode == toggleKey then
			window:Toggle()
		end
	end))

	if config.ShowMobileButtons ~= false then
		local side = config.MobileButtonsSide == "Right" and "Right" or "Left"
		local x = side == "Right" and UDim2.new(1, -96, 1, -54) or UDim2.new(0, 18, 1, -54)

		local mobileToggle = create("TextButton", {
			AutoButtonColor = false,
			BackgroundColor3 = self.Scheme.Panel,
			BorderSizePixel = 0,
			Font = window.Font,
			Text = "UI",
			TextColor3 = self.Scheme.Text,
			TextSize = 13,
			Position = x,
			Size = UDim2.fromOffset(38, 38),
			Parent = gui,
		})
		self:RegisterThemeable(mobileToggle, "BackgroundColor3", "Panel")
		self:RegisterThemeable(mobileToggle, "TextColor3", "Text")
		applyCorner(mobileToggle, 19)
		applyStroke(mobileToggle, "Outline")

		addConnection(mobileToggle.MouseButton1Click:Connect(function()
			window:Toggle()
		end))
	end

	if self.ShowCustomCursor then
		local cursor = create("Frame", {
			BackgroundColor3 = self.Scheme.Accent,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(6, 6),
			Visible = true,
			ZIndex = 1000,
			Parent = gui,
		})
		self:RegisterThemeable(cursor, "BackgroundColor3", "Accent")
		applyCorner(cursor, 3)
		window.Cursor = cursor

		addConnection(UserInputService.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				cursor.Position = UDim2.fromOffset(input.Position.X - 3, input.Position.Y - 3)
				cursor.Visible = Library.ShowCustomCursor
			end
		end))
	end

	return window
end

return Library
