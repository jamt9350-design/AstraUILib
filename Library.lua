ex = WindowMethods
local TabMethods = {}
TabMethods.__index = TabMethods
local TabboxMethods = {}
TabboxMethods.__index = TabboxMethods
local function safeCall(fn, ...)
	if type(fn) ~= "function" then
		return
	end
	local ok, err = pcall(fn, ...)
	if not ok then
		warn("[AtlasUI] callback error:", err)
	end
end
local function getEnv()
	if type(getgenv) == "function" then
		local ok, env = pcall(getgenv)
		if ok and type(env) == "table" then
			return env
		end
	end
	return _G
end
local function clamp(value, minValue, maxValue)
	if value < minValue then
		return minValue
	end
	if value > maxValue then
		return maxValue
	end
	return value
end
local function roundTo(value, decimals)
	decimals = decimals or 0
	local mult = 10 ^ decimals
	return math.floor(value * mult + 0.5) / mult
end
local function listToSet(list)
	local set = {}
	for _, item in ipairs(list or {}) do
		set[item] = true
	end
	return set
end
local function safeSet(instance, property, value)
	pcall(function()
		instance[property] = value
	end)
end
local function new(className, props, children)
	local instance = Instance.new(className)
	props = props or {}
	for property, value in pairs(props) do
		if property ~= "Parent" then
			safeSet(instance, property, value)
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = instance
	end
	if props.Parent then
		safeSet(instance, "Parent", props.Parent)
	end
	return instance
end
local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(Library.Connections, connection)
	return connection
end
local function theme(instance, property, key)
	table.insert(Library.ThemeObjects, {
		Instance = instance,
		Property = property,
		Key = key,
	})
	safeSet(instance, property, Library.Scheme[key])
	return instance
end
local function addCorner(instance, radius)
	local corner = new("UICorner", {
		CornerRadius = UDim.new(0, radius or Library.CornerRadius),
		Parent = instance,
	})
	table.insert(Library.Corners, corner)
	return corner
end
local function addStroke(instance, colorKey, transparency)
	local stroke = new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Thickness = 1,
		Transparency = transparency or 0,
		Parent = instance,
	})
	theme(stroke, "Color", colorKey or "Stroke")
	return stroke
end
local function addPadding(instance, left, top, right, bottom)
	return new("UIPadding", {
		PaddingLeft = UDim.new(0, left or 0),
		PaddingTop = UDim.new(0, top or 0),
		PaddingRight = UDim.new(0, right or left or 0),
		PaddingBottom = UDim.new(0, bottom or top or 0),
		Parent = instance,
	})
end
local function textLabel(props)
	local label = new("TextLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = Enum.Font.Gotham,
		TextSize = props.TextSize or 13,
		Text = props.Text or "",
		TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left,
		TextYAlignment = props.TextYAlignment or Enum.TextYAlignment.Center,
		TextWrapped = props.TextWrapped or false,
		RichText = props.RichText or false,
		Size = props.Size or UDim2.new(1, 0, 0, 20),
		Position = props.Position or UDim2.fromOffset(0, 0),
		ZIndex = props.ZIndex or 1,
		Parent = props.Parent,
	})
	theme(label, "TextColor3", props.ColorKey or "Text")
	return label
end
local function textButton(props)
	local button = new("TextButton", {
		AutoButtonColor = false,
		BackgroundTransparency = props.BackgroundTransparency or 0,
		BorderSizePixel = 0,
		Font = props.Font or Enum.Font.Gotham,
		TextSize = props.TextSize or 13,
		Text = props.Text or "",
		TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Center,
		TextYAlignment = props.TextYAlignment or Enum.TextYAlignment.Center,
		Size = props.Size or UDim2.new(1, 0, 0, 28),
		Position = props.Position or UDim2.fromOffset(0, 0),
		ZIndex = props.ZIndex or 1,
		Parent = props.Parent,
	})
	theme(button, "TextColor3", props.ColorKey or "Text")
	theme(button, "BackgroundColor3", props.BackgroundKey or "Panel")
	addCorner(button, props.CornerRadius)
	return button
end
local function inputName(input)
	if input.UserInputType == Enum.UserInputType.Keyboard then
		return input.KeyCode.Name
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
		return "MB1"
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		return "MB2"
	elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
		return "MB3"
	end
	return input.UserInputType.Name
end
local function getGuiParent()
	if type(gethui) == "function" then
		local ok, result = pcall(gethui)
		if ok and result then
			return result
		end
	end
	local ok, coreGui = pcall(function()
		return game:GetService("CoreGui")
	end)
	if ok and coreGui then
		return coreGui
	end
	local localPlayer = Players.LocalPlayer
	if localPlayer then
		return localPlayer:WaitForChild("PlayerGui")
	end
	return nil
end
local function createSignalObject(index, value, callback)
	local object = {
		Index = index,
		Value = value,
		Callback = callback,
		ChangedCallbacks = {},
		Visible = true,
		Disabled = false,
	}
	function object:OnChanged(fn)
		table.insert(self.ChangedCallbacks, fn)
		return self
	end
	function object:_fire()
		safeCall(self.Callback, self.Value, self)
		for _, fn in ipairs(self.ChangedCallbacks) do
			safeCall(fn, self.Value, self)
		end
	end
	function object:SetVisible(visible)
		self.Visible = visible ~= false
		if self.Container then
			self.Container.Visible = self.Visible
		end
		return self
	end
	function object:SetDisabled(disabled)
		self.Disabled = disabled == true
		if self.UpdateVisual then
			self:UpdateVisual()
		end
		return self
	end
	return object
end
local function registerOption(index, object, isToggle)
	if not index then
		return object
	end
	if isToggle then
		Library.Toggles[index] = object
	else
		Library.Options[index] = object
	end
	return object
end
function Library:_applyTheme()
	for _, entry in ipairs(self.ThemeObjects) do
		if entry.Instance and entry.Instance.Parent and self.Scheme[entry.Key] then
			safeSet(entry.Instance, entry.Property, self.Scheme[entry.Key])
		end
	end
	for _, keybind in ipairs(self.Keybinds) do
		if keybind.UpdateVisual then
			keybind:UpdateVisual()
		end
	end
end
function Library:_showTooltip(text)
	if not self.Tooltip or not text or text == "" then
		return
	end
	self.TooltipText.Text = text
	self.Tooltip.Size = UDim2.fromOffset(math.clamp(self.TooltipText.TextBounds.X + 18, 120, 340), math.clamp(self.TooltipText.TextBounds.Y + 14, 30, 120))
	self.Tooltip.Visible = true
end
function Library:_hideTooltip()
	if self.Tooltip then
		self.Tooltip.Visible = false
	end
end
function Library:_attachTooltip(target, objectOrText, disabledText)
	connect(target.MouseEnter, function()
		local tooltipText = objectOrText
		if type(objectOrText) == "table" then
			if objectOrText.Disabled and objectOrText.DisabledTooltip then
				tooltipText = objectOrText.DisabledTooltip
			else
				tooltipText = objectOrText.Tooltip
			end
		end
		self:_showTooltip(tooltipText)
	end)
	connect(target.MouseLeave, function()
		self:_hideTooltip()
	end)
end
function Library:_createTooltip(gui)
	if self.Tooltip then
		return
	end
	local tooltip = new("Frame", {
		Name = "Tooltip",
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Visible = false,
		Size = UDim2.fromOffset(220, 36),
		ZIndex = 1000,
		Parent = gui,
	})
	theme(tooltip, "BackgroundColor3", "Panel")
	addCorner(tooltip, 6)
	addStroke(tooltip, "Stroke")
	addPadding(tooltip, 8, 6)
	local label = textLabel({
		Text = "",
		Size = UDim2.new(1, 0, 1, 0),
		TextWrapped = true,
		TextSize = 12,
		ColorKey = "Text",
		ZIndex = 1001,
		Parent = tooltip,
	})
	self.Tooltip = tooltip
	self.TooltipText = label
	connect(RunService.RenderStepped, function()
		if tooltip.Visible then
			local mouse = UserInputService:GetMouseLocation()
			tooltip.Position = UDim2.fromOffset(mouse.X + 14, mouse.Y + 14)
		end
	end)
end
function Library:_createNotificationHolder(gui)
	if self.NotificationHolder then
		return
	end
	local holder = new("Frame", {
		Name = "Notifications",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(320, 1),
		Position = UDim2.new(0, 18, 0, 18),
		Parent = gui,
	})
	local layout = new("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
		Parent = holder,
	})
	self.NotificationHolder = holder
	self.NotificationLayout = layout
	self:SetNotifySide(self.NotifySide)
end
function Library:_createKeybindFrame(gui)
	if self.KeybindFrame then
		return
	end
	local frame = new("Frame", {
		Name = "KeybindFrame",
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Position = UDim2.new(1, -238, 0, 18),
		Size = UDim2.fromOffset(220, 32),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = gui,
	})
	theme(frame, "BackgroundColor3", "Surface")
	addCorner(frame, 8)
	addStroke(frame, "Stroke")
	addPadding(frame, 8, 8)
	textLabel({
		Text = "Keybinds",
		TextSize = 13,
		Size = UDim2.new(1, 0, 0, 18),
		ColorKey = "Text",
		Parent = frame,
	})
	local list = new("Frame", {
		Name = "List",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = frame,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
		Parent = frame,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 3),
		Parent = list,
	})
	self.KeybindFrame = frame
	self.KeybindList = list
end
function Library:_createCursor(gui)
	if self.Cursor then
		return
	end
	local cursor = new("Frame", {
		Name = "CustomCursor",
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(7, 7),
		ZIndex = 1200,
		Visible = self.ShowCustomCursor,
		Parent = gui,
	})
	theme(cursor, "BackgroundColor3", "Accent")
	addCorner(cursor, 8)
	self.Cursor = cursor
	connect(RunService.RenderStepped, function()
		if cursor.Parent then
			cursor.Visible = self.ShowCustomCursor == true
			local mouse = UserInputService:GetMouseLocation()
			cursor.Position = UDim2.fromOffset(mouse.X + 3, mouse.Y + 3)
		end
	end)
end
function Library:_bindGlobalInput()
	if self.GlobalInputBound then
		return
	end
	self.GlobalInputBound = true
	connect(UserInputService.InputBegan, function(input, gameProcessed)
		if self.Unloaded then
			return
		end
		if self.CapturingKeybind then
			local keybind = self.CapturingKeybind
			self.CapturingKeybind = nil
			keybind:SetValue({ inputName(input), keybind.Mode, keybind.Modifiers })
			return
		end
		if gameProcessed or UserInputService:GetFocusedTextBox() then
			return
		end
		if self.ToggleKeybind and self.ToggleKeybind.Matches and self.ToggleKeybind:Matches(input) and self.ActiveWindow then
			self.ActiveWindow:SetVisible(not self.ActiveWindow.Visible)
			return
		end
		for _, keybind in ipairs(self.Keybinds) do
			if keybind.HandleInputBegan then
				keybind:HandleInputBegan(input)
			end
		end
	end)
	connect(UserInputService.InputEnded, function(input)
		if self.Unloaded then
			return
		end
		for _, keybind in ipairs(self.Keybinds) do
			if keybind.HandleInputEnded then
				keybind:HandleInputEnded(input)
			end
		end
	end)
end
function Library:_ensureGui()
	if self.Gui and self.Gui.Parent then
		return self.Gui
	end
	local gui = new("ScreenGui", {
		Name = self.Name,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Global,
	})
	local parent = getGuiParent()
	if parent then
		local ok = pcall(function()
			gui.Parent = parent
		end)
		if not ok and Players.LocalPlayer then
			gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		end
	end
	local scale = new("UIScale", {
		Scale = self.DPIScale / 100,
		Parent = gui,
	})
	self.Gui = gui
	self.ScaleObject = scale
	self:_createTooltip(gui)
	self:_createNotificationHolder(gui)
	self:_createKeybindFrame(gui)
	self:_createCursor(gui)
	self:_bindGlobalInput()
	return gui
end
function Library:SetNotifySide(side)
	self.NotifySide = side == "Right" and "Right" or "Left"
	if not self.NotificationHolder then
		return
	end
	if self.NotifySide == "Right" then
		self.NotificationHolder.AnchorPoint = Vector2.new(1, 0)
		self.NotificationHolder.Position = UDim2.new(1, -18, 0, 18)
	else
		self.NotificationHolder.AnchorPoint = Vector2.new(0, 0)
		self.NotificationHolder.Position = UDim2.new(0, 18, 0, 18)
	end
end
function Library:SetDPIScale(scale)
	self.DPIScale = tonumber(scale) or 100
	if self.ScaleObject then
		self.ScaleObject.Scale = self.DPIScale / 100
	end
end
function Library:Notify(options)
	self:_ensureGui()
	if type(options) == "string" then
		options = {
			Title = "Notification",
			Description = options,
		}
	end
	options = options or {}
	local notice = new("Frame", {
		Name = "Notification",
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(300, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = self.NotificationHolder,
	})
	theme(notice, "BackgroundColor3", "Surface")
	addCorner(notice, 8)
	addStroke(notice, "Stroke")
	addPadding(notice, 10, 8)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
		Parent = notice,
	})
	textLabel({
		Text = tostring(options.Title or "Notification"),
		TextSize = 13,
		Size = UDim2.new(1, 0, 0, 18),
		ColorKey = "Text",
		Parent = notice,
	})
	textLabel({
		Text = tostring(options.Description or options.Content or ""),
		TextSize = 12,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		ColorKey = "SubText",
		Parent = notice,
	})
	notice.BackgroundTransparency = 1
	TweenService:Create(notice, TweenInfo.new(0.15), { BackgroundTransparency = 0 }):Play()
	task.delay(options.Time or 4, function()
		if notice.Parent then
			local tween = TweenService:Create(notice, TweenInfo.new(0.2), { BackgroundTransparency = 1 })
			tween:Play()
			tween.Completed:Wait()
			if notice.Parent then
				notice:Destroy()
			end
		end
	end)
	return notice
end
function Library:OnUnload(callback)
	table.insert(self.UnloadCallbacks, callback)
	return self
end
function Library:Unload()
	if self.Unloaded then
		return
	end
	self.Unloaded = true
	for _, callback in ipairs(self.UnloadCallbacks) do
		safeCall(callback)
	end
	for _, connection in ipairs(self.Connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	if self.Gui then
		self.Gui:Destroy()
	end
end
local function makeDraggable(handle, target, isLocked)
	local dragging = false
	local dragStart
	local startPos
	connect(handle.InputBegan, function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		if isLocked and isLocked() then
			return
		end
		dragging = true
		dragStart = input.Position
		startPos = target.Position
		connect(input.Changed, function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
			end
		end)
	end)
	connect(UserInputService.InputChanged, function(input)
		if not dragging then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local delta = input.Position - dragStart
		target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end)
end
local function makeResizable(handle, target)
	local resizing = false
	local dragStart
	local startSize
	connect(handle.InputBegan, function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		resizing = true
		dragStart = input.Position
		startSize = target.AbsoluteSize
		connect(input.Changed, function()
			if input.UserInputState == Enum.UserInputState.End then
				resizing = false
			end
		end)
	end)
	connect(UserInputService.InputChanged, function(input)
		if not resizing then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local delta = input.Position - dragStart
		target.Size = UDim2.fromOffset(clamp(startSize.X + delta.X, 440, 980), clamp(startSize.Y + delta.Y, 340, 760))
	end)
end
function Library:AddDraggableLabel(text)
	local gui = self:_ensureGui()
	local label = new("TextButton", {
		Name = "DraggableLabel",
		AutoButtonColor = false,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Text = tostring(text or "Draggable Label"),
		Font = Enum.Font.GothamSemibold,
		TextSize = 13,
		Size = UDim2.fromOffset(180, 34),
		Position = UDim2.fromOffset(28, 120),
		Parent = gui,
	})
	theme(label, "BackgroundColor3", "Surface")
	theme(label, "TextColor3", "Text")
	addCorner(label, 8)
	addStroke(label, "Stroke")
	makeDraggable(label, label)
	return label
end
local function nextOrder(group)
	group.Order = (group.Order or 0) + 1
	return group.Order
end
local function createRow(group, height)
	return new("Frame", {
		Name = "Item",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, height or 30),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = nextOrder(group),
		Parent = group.Content,
	})
end
local function formatToggleVisual(object, knob, fill, checkboxMode)
	local active = object.Value == true
	if checkboxMode then
		fill.Visible = active
	else
		fill.Position = active and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
	end
	if object.Disabled then
		knob.BackgroundTransparency = 0.35
		fill.BackgroundTransparency = 0.35
	else
		knob.BackgroundTransparency = 0
		fill.BackgroundTransparency = 0
	end
	if active then
		theme(knob, "BackgroundColor3", "Accent")
	else
		theme(knob, "BackgroundColor3", "Panel")
	end
end
local function createToggle(group, index, options, checkboxMode)
	options = options or {}
	if Library.ForceCheckbox and not checkboxMode then
		checkboxMode = true
	end
	local row = createRow(group, 30)
	local label = textLabel({
		Text = tostring(options.Text or index or "Toggle"),
		Size = UDim2.new(1, -56, 0, 28),
		TextSize = 13,
		ColorKey = options.Risky and "Red" or "Text",
		Parent = row,
	})
	local button = new("TextButton", {
		Name = "ToggleButton",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Text = "",
		Size = checkboxMode and UDim2.fromOffset(20, 20) or UDim2.fromOffset(40, 20),
		Position = UDim2.new(1, checkboxMode and -22 or -42, 0, 4),
		Parent = row,
	})
	theme(button, "BackgroundColor3", "Panel")
	addCorner(button, checkboxMode and 4 or 20)
	addStroke(button, "Stroke")
	local fill
	if checkboxMode then
		fill = new("Frame", {
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(12, 12),
			Position = UDim2.fromOffset(4, 4),
			Visible = false,
			Parent = button,
		})
		theme(fill, "BackgroundColor3", "Accent")
		addCorner(fill, 3)
	else
		fill = new("Frame", {
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(14, 14),
			Position = UDim2.fromOffset(3, 3),
			Parent = button,
		})
		theme(fill, "BackgroundColor3", "Panel")
		addCorner(fill, 14)
	end
	local object = createSignalObject(index, options.Default == true, options.Callback)
	object.Container = row
	object.Tooltip = options.Tooltip
	object.DisabledTooltip = options.DisabledTooltip
	object.Disabled = options.Disabled == true
	object.Visible = options.Visible ~= false
	object.ParentGroup = group
	function object:UpdateVisual()
		row.Visible = self.Visible
		label.TextTransparency = self.Disabled and 0.45 or 0
		button.BackgroundTransparency = self.Disabled and 0.35 or 0
		formatToggleVisual(self, button, fill, checkboxMode)
	end
	function object:SetValue(value, silent)
		self.Value = value == true
		self:UpdateVisual()
		if not silent then
			self:_fire()
		end
		return self
	end
	function object:AddColorPicker(colorIndex, colorOptions)
		return group:AddColorPicker(colorIndex, colorOptions, self)
	end
	function object:AddKeyPicker(keyIndex, keyOptions)
		keyOptions = keyOptions or {}
		keyOptions.ParentToggle = self
		return group:AddKeyPicker(keyIndex, keyOptions, self)
	end
	connect(button.MouseButton1Click, function()
		if object.Disabled then
			return
		end
		object:SetValue(not object.Value)
	end)
	Library:_attachTooltip(row, object)
	object:UpdateVisual()
	registerOption(index, object, true)
	return object
end
function GroupMethods:AddToggle(index, options)
	return createToggle(self, index, options, false)
end
function GroupMethods:AddCheckbox(index, options)
	return createToggle(self, index, options, true)
end
function GroupMethods:AddButton(first, second)
	local options
	if type(first) == "table" then
		options = first
	else
		options = {
			Text = tostring(first or "Button"),
			Func = second,
		}
	end
	options = options or {}
	local row = createRow(self, 32)
	local button = textButton({
		Text = tostring(options.Text or "Button"),
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundKey = options.Risky and "Red" or "Panel",
		Parent = row,
	})
	local object = {
		Container = row,
		Button = button,
		ParentGroup = self,
		Disabled = options.Disabled == true,
		Visible = options.Visible ~= false,
		Tooltip = options.Tooltip,
		DisabledTooltip = options.DisabledTooltip,
		LastClick = 0,
	}
	function object:UpdateVisual()
		row.Visible = self.Visible
		button.TextTransparency = self.Disabled and 0.45 or 0
		button.BackgroundTransparency = self.Disabled and 0.35 or 0
	end
	function object:SetDisabled(disabled)
		self.Disabled = disabled == true
		self:UpdateVisual()
		return self
	end
	function object:SetVisible(visible)
		self.Visible = visible ~= false
		self:UpdateVisual()
		return self
	end
	function object:AddButton(subOptions, subFunc)
		if type(subOptions) ~= "table" then
			subOptions = {
				Text = tostring(subOptions or "Button"),
				Func = subFunc,
			}
		end
		return self.ParentGroup:AddButton(subOptions)
	end
	connect(button.MouseButton1Click, function()
		if object.Disabled then
			return
		end
		if options.DoubleClick then
			local now = os.clock()
			if now - object.LastClick > 1.4 then
				object.LastClick = now
				button.Text = "Click again"
				task.delay(1.4, function()
					if button.Parent then
						button.Text = tostring(options.Text or "Button")
					end
				end)
				return
			end
		end
		safeCall(options.Func)
	end)
	connect(button.MouseEnter, function()
		if not object.Disabled then
			theme(button, "BackgroundColor3", "PanelHover")
		end
	end)
	connect(button.MouseLeave, function()
		theme(button, "BackgroundColor3", options.Risky and "Red" or "Panel")
	end)
	Library:_attachTooltip(row, object)
	object:UpdateVisual()
	return object
end
function GroupMethods:AddLabel(first, second, third)
	local options = {}
	local index
	if type(first) == "table" then
		options = first
	elseif type(second) == "table" then
		index = first
		options = second
	else
		options.Text = tostring(first or "")
		options.DoesWrap = second == true
		index = third
	end
	options.Text = tostring(options.Text or first or "")
	local row = createRow(self, options.DoesWrap and 42 or 24)
	local label = textLabel({
		Text = options.Text,
		Size = UDim2.new(1, 0, 0, options.DoesWrap and 0 or 22),
		AutomaticSize = options.DoesWrap and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
		TextWrapped = options.DoesWrap == true,
		TextSize = options.Size or 13,
		RichText = options.RichText == true,
		ColorKey = options.ColorKey or "Text",
		Parent = row,
	})
	local object = createSignalObject(index, options.Text, options.Callback)
	object.Container = row
	object.Label = label
	object.ParentGroup = self
	function object:SetText(text)
		self.Value = tostring(text or "")
		label.Text = self.Value
		self:_fire()
		return self
	end
	function object:AddColorPicker(colorIndex, colorOptions)
		return self.ParentGroup:AddColorPicker(colorIndex, colorOptions, self)
	end
	function object:AddKeyPicker(keyIndex, keyOptions)
		return self.ParentGroup:AddKeyPicker(keyIndex, keyOptions, self)
	end
	if index then
		Library.Labels[index] = object
	end
	registerOption(index, object, false)
	return object
end
function GroupMethods:AddDivider()
	local row = createRow(self, 18)
	local line = new("Frame", {
		Name = "Divider",
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 0.5, 0),
		Parent = row,
	})
	theme(line, "BackgroundColor3", "Stroke")
	return line
end
local function sliderDisplay(object)
	if object.FormatDisplayValue then
		local display = object.FormatDisplayValue(object, object.Value)
		if display ~= nil then
			return tostring(display)
		end
	end
	local value = tostring(object.Value)
	if object.Suffix then
		value = value .. tostring(object.Suffix)
	end
	if object.HideMax or object.Compact then
		return value
	end
	return value .. " / " .. tostring(object.Max)
end
function GroupMethods:AddSlider(index, options)
	options = options or {}
	local row = createRow(self, options.Compact and 34 or 54)
	local title = textLabel({
		Text = tostring(options.Text or index or "Slider"),
		Size = UDim2.new(1, -96, 0, options.Compact and 0 or 18),
		TextSize = 13,
		Visible = not options.Compact,
		Parent = row,
	})
	local valueLabel = textLabel({
		Text = "",
		Size = UDim2.new(0, 92, 0, 18),
		Position = UDim2.new(1, -92, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextSize = 12,
		ColorKey = "SubText",
		Visible = not options.Compact,
		Parent = row,
	})
	local track = new("TextButton", {
		Name = "SliderTrack",
		AutoButtonColor = false,
		Text = "",
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 8),
		Position = UDim2.new(0, 0, 0, options.Compact and 13 or 34),
		Parent = row,
	})
	theme(track, "BackgroundColor3", "Panel")
	addCorner(track, 8)
	local fill = new("Frame", {
		BorderSizePixel = 0,
		Size = UDim2.new(0, 0, 1, 0),
		Parent = track,
	})
	theme(fill, "BackgroundColor3", "Accent")
	addCorner(fill, 8)
	local object = createSignalObject(index, tonumber(options.Default) or tonumber(options.Min) or 0, options.Callback)
	object.Container = row
	object.Min = tonumber(options.Min) or 0
	object.Max = tonumber(options.Max) or 100
	object.Rounding = tonumber(options.Rounding) or 0
	object.Suffix = options.Suffix
	object.Compact = options.Compact == true
	object.HideMax = options.HideMax == true
	object.FormatDisplayValue = options.FormatDisplayValue
	object.Tooltip = options.Tooltip
	object.DisabledTooltip = options.DisabledTooltip
	object.Disabled = options.Disabled == true
	object.Visible = options.Visible ~= false
	local function valueFromX(x)
		local ratio = clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		return object.Min + (object.Max - object.Min) * ratio
	end
	function object:UpdateVisual()
		row.Visible = self.Visible
		local ratio = (self.Value - self.Min) / math.max(self.Max - self.Min, 1)
		fill.Size = UDim2.new(clamp(ratio, 0, 1), 0, 1, 0)
		valueLabel.Text = sliderDisplay(self)
		title.TextTransparency = self.Disabled and 0.45 or 0
		track.BackgroundTransparency = self.Disabled and 0.35 or 0
	end
	function object:SetValue(value, silent)
		value = tonumber(value) or self.Min
		value = clamp(value, self.Min, self.Max)
		value = roundTo(value, self.Rounding)
		self.Value = value
		self:UpdateVisual()
		if not silent then
			self:_fire()
		end
		return self
	end
	local dragging = false
	connect(track.InputBegan, function(input)
		if object.Disabled then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			object:SetValue(valueFromX(input.Position.X))
		end
	end)
	connect(UserInputService.InputChanged, function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			object:SetValue(valueFromX(input.Position.X))
		end
	end)
	connect(UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	Library:_attachTooltip(row, object)
	object:SetValue(object.Value, true)
	registerOption(index, object, false)
	return object
end
function GroupMethods:AddInput(index, options)
	options = options or {}
	local row = createRow(self, 54)
	textLabel({
		Text = tostring(options.Text or index or "Input"),
		Size = UDim2.new(1, 0, 0, 18),
		TextSize = 13,
		Parent = row,
	})
	local box = new("TextBox", {
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ClearTextOnFocus = options.ClearTextOnFocus ~= false,
		Font = Enum.Font.Gotham,
		PlaceholderText = tostring(options.Placeholder or ""),
		Text = tostring(options.Default or ""),
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 28),
		Position = UDim2.fromOffset(0, 22),
		Parent = row,
	})
	theme(box, "BackgroundColor3", "Panel")
	theme(box, "TextColor3", "Text")
	theme(box, "PlaceholderColor3", "SubText")
	addCorner(box, 6)
	addStroke(box, "Stroke")
	addPadding(box, 8, 0)
	local object = createSignalObject(index, tostring(options.Default or ""), options.Callback)
	object.Container = row
	object.Numeric = options.Numeric == true
	object.Finished = options.Finished == true
	object.MaxLength = options.MaxLength
	object.Tooltip = options.Tooltip
	object.DisabledTooltip = options.DisabledTooltip
	object.Disabled = options.Disabled == true
	object.Visible = options.Visible ~= false
	function object:UpdateVisual()
		row.Visible = self.Visible
		box.TextEditable = not self.Disabled
		box.TextTransparency = self.Disabled and 0.45 or 0
		box.BackgroundTransparency = self.Disabled and 0.35 or 0
	end
	function object:SetValue(value, silent)
		value = tostring(value or "")
		if self.Numeric then
			value = value:gsub("[^%d%.%-]", "")
		end
		if self.MaxLength and #value > self.MaxLength then
			value = value:sub(1, self.MaxLength)
		end
		self.Value = value
		box.Text = value
		if not silent then
			self:_fire()
		end
		return self
	end
	connect(box:GetPropertyChangedSignal("Text"), function()
		if object.Finished then
			return
		end
		if object.Numeric or object.MaxLength then
			object:SetValue(box.Text)
		else
			object.Value = box.Text
			object:_fire()
		end
	end)
	connect(box.FocusLost, function(enterPressed)
		if object.Finished and enterPressed then
			object:SetValue(box.Text)
		end
	end)
	Library:_attachTooltip(row, object)
	object:UpdateVisual()
	registerOption(index, object, false)
	return object
end
local function dropdownDisplay(object)
	if object.Multi then
		local selected = {}
		for _, value in ipairs(object.Values) do
			if object.Value[value] then
				table.insert(selected, object:FormatValue(value))
			end
		end
		return #selected > 0 and table.concat(selected, ", ") or "None"
	end
	if object.Value == nil then
		return "None"
	end
	return object:FormatValue(object.Value)
end
function GroupMethods:AddDropdown(index, options)
	options = options or {}
	local row = createRow(self, 56)
	textLabel({
		Text = tostring(options.Text or index or "Dropdown"),
		Size = UDim2.new(1, 0, 0, 18),
		TextSize = 13,
		Parent = row,
	})
	local button = textButton({
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 28),
		Position = UDim2.fromOffset(0, 22),
		BackgroundKey = "Panel",
		Parent = row,
	})
	addPadding(button, 8, 0)
	local listFrame = new("Frame", {
		Name = "DropdownList",
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		Position = UDim2.fromOffset(0, 54),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = row,
	})
	theme(listFrame, "BackgroundColor3", "Panel")
	addCorner(listFrame, 6)
	addStroke(listFrame, "Stroke")
	addPadding(listFrame, 6, 6)
	local searchBox
	if options.Searchable then
		searchBox = new("TextBox", {
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			ClearTextOnFocus = false,
			Font = Enum.Font.Gotham,
			PlaceholderText = "Search",
			Text = "",
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, 24),
			Parent = listFrame,
		})
		theme(searchBox, "BackgroundColor3", "Surface")
		theme(searchBox, "TextColor3", "Text")
		theme(searchBox, "PlaceholderColor3", "SubText")
		addCorner(searchBox, 5)
		addPadding(searchBox, 6, 0)
	end
	local scroller = new("ScrollingFrame", {
		Name = "Values",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, 0, 0, (options.MaxVisibleDropdownItems or 8) * 26),
		Position = options.Searchable and UDim2.fromOffset(0, 30) or UDim2.fromOffset(0, 0),
		Parent = listFrame,
	})
	theme(scroller, "ScrollBarImageColor3", "Accent")
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 3),
		Parent = scroller,
	})
	local object = createSignalObject(index, nil, options.Callback)
	object.Container = row
	object.Values = options.Values or {}
	object.DisabledValues = listToSet(options.DisabledValues)
	object.Multi = options.Multi == true
	object.Searchable = options.Searchable == true
	object.FormatDisplayValue = options.FormatDisplayValue
	object.SpecialType = options.SpecialType
	object.ExcludeLocalPlayer = options.ExcludeLocalPlayer == true
	object.Tooltip = options.Tooltip
	object.DisabledTooltip = options.DisabledTooltip
	object.Disabled = options.Disabled == true
	object.Visible = options.Visible ~= false
	object.MaxVisibleDropdownItems = options.MaxVisibleDropdownItems or 8
	function object:FormatValue(value)
		if self.FormatDisplayValue then
			local ok, result = pcall(self.FormatDisplayValue, value)
			if ok and result ~= nil then
				return tostring(result)
			end
		end
		return tostring(value)
	end
	function object:GetSpecialValues()
		if self.SpecialType == "Player" then
			local values = {}
			for _, player in ipairs(Players:GetPlayers()) do
				if not (self.ExcludeLocalPlayer and player == Players.LocalPlayer) then
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
	function object:UpdateButton()
		button.Text = "  " .. dropdownDisplay(self)
		row.Visible = self.Visible
		button.TextTransparency = self.Disabled and 0.45 or 0
		button.BackgroundTransparency = self.Disabled and 0.35 or 0
	end
	function object:SetValues(values)
		self.Values = values or {}
		self:Refresh()
		self:UpdateButton()
		return self
	end
	function object:SetValue(value, silent)
		if self.Multi then
			local newValue = {}
			if type(value) == "table" then
				for key, selected in pairs(value) do
					if selected then
						newValue[key] = true
					end
				end
			elseif value ~= nil then
				newValue[value] = true
			end
			self.Value = newValue
		else
			if type(value) == "number" then
				self.Value = self.Values[value]
			else
				self.Value = value
			end
		end
		self:Refresh()
		self:UpdateButton()
		if not silent then
			self:_fire()
		end
		return self
	end
	function object:Refresh(filter)
		for _, child in ipairs(scroller:GetChildren()) do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
		local values = self:GetSpecialValues()
		self.Values = values
		filter = filter and filter:lower() or ""
		for _, value in ipairs(values) do
			local display = self:FormatValue(value)
			if filter == "" or display:lower():find(filter, 1, true) then
				local disabledValue = self.DisabledValues[value] == true
				local item = textButton({
					Text = display,
					TextXAlignment = Enum.TextXAlignment.Left,
					Size = UDim2.new(1, -2, 0, 23),
					BackgroundKey = "Surface",
					ColorKey = disabledValue and "SubText" or "Text",
					Parent = scroller,
				})
				addPadding(item, 7, 0)
				connect(item.MouseButton1Click, function()
					if self.Disabled or disabledValue then
						return
					end
					if self.Multi then
						self.Value[value] = not self.Value[value]
						self:UpdateButton()
						self:_fire()
					else
						self:SetValue(value)
						listFrame.Visible = false
					end
				end)
			end
		end
	end
	connect(button.MouseButton1Click, function()
		if object.Disabled then
			return
		end
		object:Refresh(searchBox and searchBox.Text or "")
		listFrame.Visible = not listFrame.Visible
	end)
	if searchBox then
		connect(searchBox:GetPropertyChangedSignal("Text"), function()
			object:Refresh(searchBox.Text)
		end)
	end
	local default = options.Default
	if object.Multi then
		object.Value = {}
	end
	object:SetValue(default or (object.Values and object.Values[1]), true)
	Library:_attachTooltip(row, object)
	registerOption(index, object, false)
	return object
end
function GroupMethods:AddColorPicker(index, options, parentElement)
	options = options or {}
	local defaultColor = options.Default or Color3.new(1, 1, 1)
	local defaultTransparency = options.Transparency
	local row = createRow(self, defaultTransparency ~= nil and 146 or 116)
	textLabel({
		Text = tostring(options.Title or options.Text or index or "Color"),
		Size = UDim2.new(1, -42, 0, 24),
		TextSize = 13,
		Parent = row,
	})
	local swatch = new("TextButton", {
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Text = "",
		Size = UDim2.fromOffset(30, 20),
		Position = UDim2.new(1, -30, 0, 2),
		Parent = row,
	})
	addCorner(swatch, 5)
	addStroke(swatch, "Stroke")
	local panel = new("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 0, defaultTransparency ~= nil and 108 or 78),
		Visible = false,
		Parent = row,
	})
	local object = createSignalObject(index, defaultColor, options.Callback)
	object.Container = row
	object.ParentElement = parentElement
	object.Transparency = defaultTransparency
	object.R = math.floor(defaultColor.R * 255 + 0.5)
	object.G = math.floor(defaultColor.G * 255 + 0.5)
	object.B = math.floor(defaultColor.B * 255 + 0.5)
	object.A = defaultTransparency or 0
	local componentRows = {}
	local function createComponent(name, key, order)
		local component = new("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 24),
			Position = UDim2.fromOffset(0, (order - 1) * 27),
			Parent = panel,
		})
		textLabel({
			Text = name,
			Size = UDim2.fromOffset(22, 22),
			TextSize = 12,
			ColorKey = "SubText",
			Parent = component,
		})
		local track = new("TextButton", {
			AutoButtonColor = false,
			BorderSizePixel = 0,
			Text = "",
			Size = UDim2.new(1, -70, 0, 8),
			Position = UDim2.fromOffset(28, 7),
			Parent = component,
		})
		theme(track, "BackgroundColor3", "Panel")
		addCorner(track, 8)
		local fill = new("Frame", {
			BorderSizePixel = 0,
			Size = UDim2.fromScale(0, 1),
			Parent = track,
		})
		theme(fill, "BackgroundColor3", "Accent")
		addCorner(fill, 8)
		local valueLabel = textLabel({
			Text = "0",
			Size = UDim2.fromOffset(36, 22),
			Position = UDim2.new(1, -36, 0, 0),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextSize = 12,
			ColorKey = "SubText",
			Parent = component,
		})
		local maxValue = key == "A" and 100 or 255
		local dragging = false
		local function setFromX(x)
			local ratio = clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
			local value = math.floor(ratio * maxValue + 0.5)
			if key == "A" then
				object.A = value / 100
			else
				object[key] = value
			end
			object:SetValueRGB(Color3.fromRGB(object.R, object.G, object.B), object.A)
		end
		connect(track.InputBegan, function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				setFromX(input.Position.X)
			end
		end)
		connect(UserInputService.InputChanged, function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				setFromX(input.Position.X)
			end
		end)
		connect(UserInputService.InputEnded, function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end)
		componentRows[key] = {
			Fill = fill,
			Label = valueLabel,
			Max = maxValue,
		}
	end
	createComponent("R", "R", 1)
	createComponent("G", "G", 2)
	createComponent("B", "B", 3)
	if defaultTransparency ~= nil then
		createComponent("A", "A", 4)
	end
	function object:UpdateVisual()
		local values = {
			R = self.R,
			G = self.G,
			B = self.B,
			A = math.floor((self.A or 0) * 100 + 0.5),
		}
		for key, data in pairs(componentRows) do
			local value = values[key]
			data.Fill.Size = UDim2.new(clamp(value / data.Max, 0, 1), 0, 1, 0)
			data.Label.Text = tostring(value)
		end
		swatch.BackgroundColor3 = self.Value
		swatch.BackgroundTransparency = self.Transparency or 0
	end
	function object:SetValueRGB(color, transparency, silent)
		self.Value = color
		self.R = math.floor(color.R * 255 + 0.5)
		self.G = math.floor(color.G * 255 + 0.5)
		self.B = math.floor(color.B * 255 + 0.5)
		if transparency ~= nil then
			self.Transparency = clamp(transparency, 0, 1)
			self.A = self.Transparency
		end
		self:UpdateVisual()
		if not silent then
			self:_fire()
		end
		return self
	end
	function object:SetValueHSV(h, s, v, transparency)
		return self:SetValueRGB(Color3.fromHSV(h, s, v), transparency)
	end
	function object:SetValue(value, silent)
		if typeof(value) == "Color3" then
			return self:SetValueRGB(value, self.Transparency, silent)
		end
		return self
	end
	connect(swatch.MouseButton1Click, function()
		panel.Visible = not panel.Visible
	end)
	object:SetValueRGB(defaultColor, defaultTransparency, true)
	registerOption(index, object, false)
	return object
end
function GroupMethods:AddKeyPicker(index, options, parentElement)
	options = options or {}
	local row = createRow(self, 32)
	textLabel({
		Text = tostring(options.Text or index or "Keybind"),
		Size = UDim2.new(1, -92, 0, 28),
		TextSize = 13,
		Parent = row,
	})
	local button = textButton({
		Text = "",
		Size = UDim2.fromOffset(84, 26),
		Position = UDim2.new(1, -84, 0, 1),
		BackgroundKey = "Panel",
		Parent = row,
	})
	local object = createSignalObject(index, tostring(options.Default or "None"), options.Callback)
	object.Container = row
	object.Mode = options.Mode or "Toggle"
	object.Modifiers = options.Modifiers
	object.ChangedCallback = options.ChangedCallback
	object.NoUI = options.NoUI == true
	object.SyncToggleState = options.SyncToggleState == true
	object.WaitForCallback = options.WaitForCallback == true
	object.ParentElement = parentElement or options.ParentToggle
	object.State = object.Mode == "Always"
	object.ClickCallbacks = {}
	function object:Matches(input)
		return inputName(input) == self.Value
	end
	function object:OnClick(fn)
		table.insert(self.ClickCallbacks, fn)
		return self
	end
	function object:GetState()
		if self.Mode == "Always" then
			return true
		end
		if self.SyncToggleState and self.ParentElement and self.ParentElement.Value ~= nil then
			return self.ParentElement.Value == true
		end
		return self.State == true
	end
	function object:UpdateVisual()
		button.Text = self.Value == "None" and "None" or (self.Value .. " [" .. self.Mode .. "]")
		if self.MenuStateLabel then
			self.MenuStateLabel.Text = self:GetState() and "on" or "off"
			theme(self.MenuStateLabel, "TextColor3", self:GetState() and "Green" or "SubText")
		end
		if self.MenuKeyLabel then
			self.MenuKeyLabel.Text = self.Value .. " / " .. self.Mode
		end
	end
	function object:_fireClick()
		if self.WaitForCallback and self.Busy then
			return
		end
		self.Busy = true
		safeCall(self.Callback, self:GetState(), self)
		for _, fn in ipairs(self.ClickCallbacks) do
			safeCall(fn, self:GetState(), self)
		end
		self.Busy = false
	end
	function object:_fireChanged()
		safeCall(self.ChangedCallback, self.Value, self.Modifiers)
		for _, fn in ipairs(self.ChangedCallbacks) do
			safeCall(fn, self.Value, self)
		end
	end
	function object:SetValue(value, silent)
		if type(value) == "table" then
			self.Value = tostring(value[1] or value.Key or self.Value)
			self.Mode = tostring(value[2] or value.Mode or self.Mode)
			self.Modifiers = value[3] or value.Modifiers or self.Modifiers
		else
			self.Value = tostring(value or "None")
		end
		self.State = self.Mode == "Always"
		self:UpdateVisual()
		if not silent then
			self:_fireChanged()
		end
		return self
	end
	function object:HandleInputBegan(input)
		if not self:Matches(input) then
			return
		end
		if self.Mode == "Hold" then
			self.State = true
			self:UpdateVisual()
			self:_fireClick()
		elseif self.Mode == "Press" then
			self.State = true
			self:UpdateVisual()
			self:_fireClick()
			self.State = false
			self:UpdateVisual()
		elseif self.Mode == "Always" then
			self.State = true
			self:UpdateVisual()
			self:_fireClick()
		else
			if self.SyncToggleState and self.ParentElement and self.ParentElement.SetValue then
				self.ParentElement:SetValue(not self.ParentElement.Value)
				self.State = self.ParentElement.Value == true
			else
				self.State = not self.State
			end
			self:UpdateVisual()
			self:_fireClick()
		end
	end
	function object:HandleInputEnded(input)
		if self.Mode ~= "Hold" or not self:Matches(input) then
			return
		end
		self.State = false
		self:UpdateVisual()
		self:_fireClick()
	end
	connect(button.MouseButton1Click, function()
		Library.CapturingKeybind = object
		button.Text = "..."
	end)
	if not object.NoUI and Library.KeybindList then
		local menuRow = new("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 22),
			Parent = Library.KeybindList,
		})
		object.MenuKeyLabel = textLabel({
			Text = "",
			Size = Library.ShowToggleFrameInKeybinds and UDim2.new(1, -38, 1, 0) or UDim2.new(1, 0, 1, 0),
			TextSize = 12,
			ColorKey = "SubText",
			Parent = menuRow,
		})
		if Library.ShowToggleFrameInKeybinds then
			object.MenuStateLabel = textLabel({
				Text = "off",
				Size = UDim2.fromOffset(32, 22),
				Position = UDim2.new(1, -32, 0, 0),
				TextXAlignment = Enum.TextXAlignment.Right,
				TextSize = 12,
				ColorKey = "SubText",
				Parent = menuRow,
			})
		end
	end
	object:SetValue({ object.Value, object.Mode, object.Modifiers }, true)
	table.insert(Library.Keybinds, object)
	registerOption(index, object, false)
	return object
end
function GroupMethods:AddKeyBox(callback)
	local row = createRow(self, 62)
	local box = new("TextBox", {
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		Font = Enum.Font.Gotham,
		PlaceholderText = "Enter key",
		Text = "",
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 28),
		Parent = row,
	})
	theme(box, "BackgroundColor3", "Panel")
	theme(box, "TextColor3", "Text")
	theme(box, "PlaceholderColor3", "SubText")
	addCorner(box, 6)
	addStroke(box, "Stroke")
	addPadding(box, 8, 0)
	local submit = textButton({
		Text = "Submit",
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.fromOffset(0, 34),
		BackgroundKey = "Panel",
		Parent = row,
	})
	local function send()
		safeCall(callback, box.Text)
	end
	connect(submit.MouseButton1Click, send)
	connect(box.FocusLost, function(enterPressed)
		if enterPressed then
			send()
		end
	end)
	return box
end
local function createGroup(tab, side, title, icon)
	local parent = side == "Right" and tab.RightColumn or tab.LeftColumn
	local frame = new("Frame", {
		Name = title or "Groupbox",
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = parent,
	})
	theme(frame, "BackgroundColor3", "Surface")
	addCorner(frame, Library.CornerRadius)
	addStroke(frame, "Stroke")
	addPadding(frame, 10, 8)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
		Parent = frame,
	})
	textLabel({
		Text = icon and (tostring(title or "Groupbox")) or tostring(title or "Groupbox"),
		TextSize = 14,
		Size = UDim2.new(1, 0, 0, 24),
		ColorKey = "Text",
		Parent = frame,
	})
	local content = new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = frame,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 5),
		Parent = content,
	})
	local group = setmetatable({
		Window = tab.Window,
		Tab = tab,
		Frame = frame,
		Content = content,
		Order = 0,
	}, GroupMethods)
	return group
end
local function createGroupFromContent(tab, content)
	return setmetatable({
		Window = tab.Window,
		Tab = tab,
		Frame = content,
		Content = content,
		Order = 0,
	}, GroupMethods)
end
function TabMethods:_getDefaultGroup()
	if not self.DefaultGroup then
		self.DefaultGroup = self:AddLeftGroupbox(self.Name)
	end
	return self.DefaultGroup
end
function TabMethods:AddLeftGroupbox(title, icon)
	return createGroup(self, "Left", title, icon)
end
function TabMethods:AddRightGroupbox(title, icon)
	return createGroup(self, "Right", title, icon)
end
function TabMethods:AddLeftTabbox()
	return self:_addTabbox("Left")
end
function TabMethods:AddRightTabbox()
	return self:_addTabbox("Right")
end
function TabMethods:_addTabbox(side)
	local parent = side == "Right" and self.RightColumn or self.LeftColumn
	local frame = new("Frame", {
		Name = "Tabbox",
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = parent,
	})
	theme(frame, "BackgroundColor3", "Surface")
	addCorner(frame, Library.CornerRadius)
	addStroke(frame, "Stroke")
	addPadding(frame, 8, 8)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 7),
		Parent = frame,
	})
	local buttons = new("Frame", {
		Name = "Buttons",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 28),
		Parent = frame,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 5),
		Parent = buttons,
	})
	local holder = new("Frame", {
		Name = "Holder",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = frame,
	})
	local tabbox = setmetatable({
		Tab = self,
		Frame = frame,
		Buttons = buttons,
		Holder = holder,
		Tabs = {},
	}, TabboxMethods)
	return tabbox
end
function TabboxMethods:AddTab(name)
	local page = new("Frame", {
		Name = tostring(name),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = self.Holder,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 5),
		Parent = page,
	})
	local button = textButton({
		Text = tostring(name),
		Size = UDim2.new(0, 100, 1, 0),
		BackgroundKey = "Panel",
		Parent = self.Buttons,
	})
	local group = createGroupFromContent(self.Tab, page)
	group.Button = button
	group.Page = page
	local function select()
		for _, tab in ipairs(self.Tabs) do
			tab.Page.Visible = false
			theme(tab.Button, "BackgroundColor3", "Panel")
		end
		page.Visible = true
		theme(button, "BackgroundColor3", "AccentDark")
	end
	connect(button.MouseButton1Click, select)
	table.insert(self.Tabs, group)
	if #self.Tabs == 1 then
		select()
	end
	return group
end
local function delegateToDefault(methodName)
	TabMethods[methodName] = function(self, ...)
		return self:_getDefaultGroup()[methodName](self:_getDefaultGroup(), ...)
	end
end
delegateToDefault("AddToggle")
delegateToDefault("AddCheckbox")
delegateToDefault("AddButton")
delegateToDefault("AddLabel")
delegateToDefault("AddDivider")
delegateToDefault("AddSlider")
delegateToDefault("AddInput")
delegateToDefault("AddDropdown")
delegateToDefault("AddColorPicker")
delegateToDefault("AddKeyPicker")
delegateToDefault("AddKeyBox")
function TabMethods:UpdateWarningBox(options)
	options = options or {}
	if not self.WarningBox then
		local box = new("Frame", {
			Name = "WarningBox",
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			Size = UDim2.new(1, -16, 0, 58),
			Position = UDim2.fromOffset(8, 8),
			Visible = false,
			Parent = self.Page,
		})
		theme(box, "BackgroundColor3", "Panel")
		addCorner(box, 8)
		addStroke(box, "Warning")
		addPadding(box, 10, 6)
		self.WarningTitle = textLabel({
			Text = "Warning",
			Size = UDim2.new(1, 0, 0, 18),
			TextSize = 13,
			RichText = true,
			ColorKey = "Warning",
			Parent = box,
		})
		self.WarningText = textLabel({
			Text = "",
			Position = UDim2.fromOffset(0, 20),
			Size = UDim2.new(1, 0, 0, 30),
			TextSize = 12,
			TextWrapped = true,
			RichText = true,
			ColorKey = "SubText",
			Parent = box,
		})
		self.WarningBox = box
	end
	self.WarningBox.Visible = options.Visible == true
	self.WarningTitle.Text = tostring(options.Title or "Warning")
	self.WarningText.Text = tostring(options.Text or "")
	if self.WarningBox.Visible then
		self.Body.Position = UDim2.fromOffset(0, 72)
		self.Body.Size = UDim2.new(1, 0, 1, -72)
	else
		self.Body.Position = UDim2.fromOffset(0, 0)
		self.Body.Size = UDim2.new(1, 0, 1, 0)
	end
end
function TabMethods:Show()
	for _, tab in pairs(self.Window.Tabs) do
		tab.Page.Visible = false
		theme(tab.Button, "BackgroundColor3", "Panel")
	end
	self.Page.Visible = true
	theme(self.Button, "BackgroundColor3", "AccentDark")
	self.Window.ActiveTab = self
end
function WindowMethods:SetVisible(visible)
	self.Visible = visible == true
	self.Frame.Visible = self.Visible
	if self.MobileToggle then
		self.MobileToggle.Text = self.Visible and "Hide" or "UI"
	end
	return self
end
function WindowMethods:SetCornerRadius(radius)
	Library.CornerRadius = tonumber(radius) or Library.CornerRadius
	for _, corner in ipairs(Library.Corners) do
		if corner.Parent then
			corner.CornerRadius = UDim.new(0, Library.CornerRadius)
		end
	end
	return self
end
function WindowMethods:SetTitle(title)
	self.Title = tostring(title or "")
	self.TitleLabel.Text = self.Title
	return self
end
function WindowMethods:SetFooter(text)
	self.Footer = tostring(text or "")
	self.FooterLabel.Text = self.Footer
	return self
end
function WindowMethods:AddTab(name, icon)
	local page = new("Frame", {
		Name = tostring(name),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, 0),
		Visible = false,
		Parent = self.Content,
	})
	local body = new("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, 0),
		Parent = page,
	})
	local left = new("ScrollingFrame", {
		Name = "LeftColumn",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.fromOffset(0, 0),
		Size = UDim2.new(0.5, -5, 1, 0),
		Parent = body,
	})
	theme(left, "ScrollBarImageColor3", "Accent")
	addPadding(left, 8, 8)
	local right = new("ScrollingFrame", {
		Name = "RightColumn",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.fromOffset(0, 0),
		Position = UDim2.new(0.5, 5, 0, 0),
		Size = UDim2.new(0.5, -5, 1, 0),
		Parent = body,
	})
	theme(right, "ScrollBarImageColor3", "Accent")
	addPadding(right, 8, 8)
	for _, column in ipairs({ left, right }) do
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 10),
			Parent = column,
		})
	end
	local button = textButton({
		Text = tostring(name),
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -12, 0, 34),
		BackgroundKey = "Panel",
		Parent = self.TabList,
	})
	addPadding(button, 10, 0)
	local tab = setmetatable({
		Name = tostring(name),
		Icon = icon,
		Window = self,
		Page = page,
		Body = body,
		LeftColumn = left,
		RightColumn = right,
		Button = button,
	}, TabMethods)
	connect(button.MouseButton1Click, function()
		tab:Show()
	end)
	self.Tabs[tab.Name] = tab
	table.insert(self.TabOrder, tab)
	if #self.TabOrder == 1 then
		tab:Show()
	end
	return tab
end
function WindowMethods:AddKeyTab(name)
	local tab = self:AddTab(name or "Key System", "key")
	tab.IsKeyTab = true
	return tab
end
function Library:CreateWindow(options)
	options = options or {}
	local gui = self:_ensureGui()
	self.NotifySide = options.NotifySide or self.NotifySide
	self.ShowCustomCursor = options.ShowCustomCursor ~= false
	self:SetNotifySide(self.NotifySide)
	local size = options.Size or UDim2.fromOffset(650, 520)
	local position = options.Position or UDim2.fromOffset(120, 80)
	if options.Center then
		position = UDim2.new(0.5, -size.X.Offset / 2, 0.5, -size.Y.Offset / 2)
	end
	local frame = new("Frame", {
		Name = "Window",
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Position = position,
		Size = size,
		Visible = options.AutoShow ~= false,
		Parent = gui,
	})
	theme(frame, "BackgroundColor3", "Background")
	addCorner(frame, Library.CornerRadius)
	addStroke(frame, "Stroke")
	local topbar = new("Frame", {
		Name = "Topbar",
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 42),
		Parent = frame,
	})
	theme(topbar, "BackgroundColor3", "Surface")
	addCorner(topbar, Library.CornerRadius)
	if options.Icon then
		new("ImageLabel", {
			BackgroundTransparency = 1,
			Image = "rbxassetid://" .. tostring(options.Icon),
			Size = UDim2.fromOffset(24, 24),
			Position = UDim2.fromOffset(12, 9),
			Parent = topbar,
		})
	end
	local titleOffset = options.Icon and 44 or 14
	local title = textLabel({
		Text = tostring(options.Title or "Atlas UI"),
		TextSize = 15,
		Size = UDim2.new(1, -220, 1, 0),
		Position = UDim2.fromOffset(titleOffset, 0),
		ColorKey = "Text",
		Parent = topbar,
	})
	local footer = textLabel({
		Text = tostring(options.Footer or ""),
		TextSize = 12,
		Size = UDim2.new(0, 190, 1, 0),
		Position = UDim2.new(1, -202, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		ColorKey = "SubText",
		Parent = topbar,
	})
	local sidebar = new("Frame", {
		Name = "Sidebar",
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(0, 150, 1, -42),
		Parent = frame,
	})
	theme(sidebar, "BackgroundColor3", "Surface")
	addPadding(sidebar, 8, 10)
	local tabList = new("Frame", {
		Name = "TabList",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, 0),
		Parent = sidebar,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
		Parent = tabList,
	})
	local content = new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(150, 42),
		Size = UDim2.new(1, -150, 1, -42),
		Parent = frame,
	})
	local window = setmetatable({
		Frame = frame,
		Topbar = topbar,
		Title = tostring(options.Title or "Atlas UI"),
		Footer = tostring(options.Footer or ""),
		TitleLabel = title,
		FooterLabel = footer,
		Sidebar = sidebar,
		TabList = tabList,
		Content = content,
		Tabs = {},
		TabOrder = {},
		Visible = frame.Visible,
		Locked = false,
	}, WindowMethods)
	makeDraggable(topbar, frame, function()
		return window.Locked
	end)
	if options.Resizable then
		local handle = new("TextButton", {
			Name = "ResizeHandle",
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Text = "",
			Size = UDim2.fromOffset(22, 22),
			Position = UDim2.new(1, -22, 1, -22),
			Parent = frame,
		})
		makeResizable(handle, frame)
	end
	local side = options.MobileButtonsSide == "Right" and "Right" or "Left"
	local x = side == "Right" and UDim2.new(1, -76, 0, 86) or UDim2.fromOffset(18, 86)
	local mobile = textButton({
		Text = frame.Visible and "Hide" or "UI",
		Size = UDim2.fromOffset(58, 30),
		Position = x,
		BackgroundKey = "AccentDark",
		Parent = gui,
	})
	window.MobileToggle = mobile
	connect(mobile.MouseButton1Click, function()
		window:SetVisible(not window.Visible)
	end)
	local lockPos = side == "Right" and UDim2.new(1, -76, 0, 122) or UDim2.fromOffset(18, 122)
	local lock = textButton({
		Text = "Lock",
		Size = UDim2.fromOffset(58, 30),
		Position = lockPos,
		BackgroundKey = "Panel",
		Parent = gui,
	})
	connect(lock.MouseButton1Click, function()
		window.Locked = not window.Locked
		lock.Text = window.Locked and "Unlock" or "Lock"
	end)
	self.ActiveWindow = window
	table.insert(self.Windows, window)
	return window
end
local env = getEnv()
env.AtlasUILibrary = Library
env.Options = Library.Options
env.Toggles = Library.Toggles
return Library
addons/ThemeManager.lua
addons/SaveManager.lua
Example.lua
README.md
.gitignore




