-- ============================================================
--  Tomato UI Library V.0.0.1
-- ============================================================
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Library = {}

-- ==================== Constants / Core Helpers ====================

local QUAD_OUT  = Enum.EasingStyle.Quad
local FX_TWEEN  = TweenInfo.new(0.15, QUAD_OUT, Enum.EasingDirection.Out)
local OPEN_TWEEN = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local WHITE     = Color3.fromRGB(255, 255, 255)
local GRAY      = Color3.fromRGB(170, 170, 170)
local OFF_COLOR = Color3.fromRGB(70, 70, 70)
local RED       = Color3.fromRGB(235, 70, 70)
local FONT      = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
local FONT_BOLD = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)

local ROW_H, PAD, ROW_BASE = 24, 6, 0.9

local running = setmetatable({}, {__mode = "k"})

-- Separate tweens by channel per instance; repeating the same channel cancels the previous tween
local function tw(inst, channel, info, goal)
	running[inst] = running[inst] or {}
	local old = running[inst][channel]
	if old then old:Cancel() end
	local t = TweenService:Create(inst, info, goal)
	running[inst][channel] = t
	t:Play()
	return t
end

-- hover / press: become darker + slightly shrink the text
local function addButtonFx(btn, getBase, textSize, bgTarget, textTarget)
	bgTarget = bgTarget or btn
	textTarget = textTarget or (btn:IsA("TextButton") and btn or nil)
	local inside, down = false, false

	local function apply(info)
		info = info or FX_TWEEN
		local base = getBase()
		local target = base
		if down then
			target = math.max(base - 0.3, 0)
		elseif inside then
			target = math.max(base - 0.15, 0)
		end
		tw(bgTarget, "bg", info, {BackgroundTransparency = target})
		if textTarget and textSize then
			tw(textTarget, "size", info, {TextSize = down and (textSize - 1) or textSize})
		end
	end

	btn.MouseEnter:Connect(function() inside = true; apply() end)
	btn.MouseLeave:Connect(function() inside = false; down = false; apply() end)
	btn.MouseButton1Down:Connect(function() down = true; apply() end)
	btn.MouseButton1Up:Connect(function() down = false; apply() end)

	return apply
end

-- Fade in during intro
local function popIn(obj, delay)
	local info = TweenInfo.new(0.35, QUAD_OUT, Enum.EasingDirection.Out, 0, false, delay or 0)
	if obj.BackgroundTransparency < 1 then
		local base = obj.BackgroundTransparency
		obj.BackgroundTransparency = 1
		tw(obj, "bg", info, {BackgroundTransparency = base})
	end
	if obj:IsA("TextLabel") or obj:IsA("TextButton") then
		obj.TextTransparency = 1
		tw(obj, "txt", info, {TextTransparency = 0})
	elseif obj:IsA("ImageButton") then
		obj.ImageTransparency = 1
		tw(obj, "txt", info, {ImageTransparency = 0})
	end
end

local function isPtr(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
end

local function round4(v) return math.round(v * 10000) / 10000 end

-- Create Instances with commonly used defaults
local function mk(class, props, parent)
	local o = Instance.new(class)
	if o:IsA("GuiObject") then o.BorderSizePixel = 0 end
	if o:IsA("GuiButton") then o.AutoButtonColor = false end
	if o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox") then
		o.FontFace = FONT
		o.TextColor3 = WHITE
		o.TextSize = 13
		o.Text = ""
	end
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end

local function label(parent, text, props)
	props = props or {}
	props.Text = text
	props.BackgroundTransparency = 1
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	props.TextTruncate = Enum.TextTruncate.AtEnd
	return mk("TextLabel", props, parent)
end

local function round(frame)
	mk("UICorner", {CornerRadius = UDim.new(1, 0)}, frame)
end

-- Transparent overlay for click/drag input
local function overlay(parent)
	return mk("TextButton", {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 10}, parent)
end

-- ============================================================
--  Library:CreateWindow
--  config = {
--      Name   = "UI name",
--      Accent = Color3 (initial accent color),
--      Hotkey = Enum.KeyCode (default UI hide/show key),
--      OnKill = function() end (called when Kill UI is pressed to clean up your script loops),
--  }
-- ============================================================
function Library:CreateWindow(config)
	config = config or {}
	local NAME = tostring(config.Name or "UI")
	local accent = config.Accent or Color3.fromRGB(255, 99, 71)
	local hotkey = config.Hotkey or Enum.KeyCode.RightShift

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local existing = playerGui:FindFirstChild(NAME)
	if existing then existing:Destroy() end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = NAME
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	-- connections to disconnect when the UI is removed
	local connections = {}
	screenGui.Destroying:Connect(function()
		for _, c in ipairs(connections) do c:Disconnect() end
		table.clear(connections)
	end)

	-- topmost screen layer: popup / dialog / toast
	local topLayer = mk("Frame", {
		Name = "topLayer", BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1), ZIndex = 100,
	}, screenGui)

	-- ---------- Accent color system ----------
	local accentFns = {}
	local function bindAccent(fn)
		table.insert(accentFns, fn)
		fn(accent)
	end
	local function setAccent(c)
		accent = c
		for _, fn in ipairs(accentFns) do fn(c) end
	end

	-- ==================== Size ====================
	local BOTTOM, RIGHT, WIDTH = 0, 0, 211
	local TITLE_HEIGHT = 19
	local TAB_HEIGHT = 17
	local PAGES_HEIGHT = 219
	local BODY_HEIGHT = TAB_HEIGHT + PAGES_HEIGHT
	local EXPANDED_HEIGHT = TITLE_HEIGHT + BODY_HEIGHT

	-- window vertical offset (used for slide in/out)
	local slideY = Instance.new("NumberValue")
	slideY.Parent = screenGui

	local main = Instance.new("CanvasGroup")
	main.Name = "main"
	main.AnchorPoint = Vector2.new(1, 1)
	main.Position = UDim2.new(1, -RIGHT, 1, -BOTTOM)
	main.Size = UDim2.new(0, WIDTH, 0, EXPANDED_HEIGHT)
	main.BackgroundColor3 = Color3.fromRGB(29, 29, 29)
	main.BorderColor3 = Color3.fromRGB(0, 0, 0)
	main.BorderSizePixel = 1
	main.Parent = screenGui

	mk("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		HorizontalFlex = Enum.UIFlexAlignment.Fill,
		VerticalFlex = Enum.UIFlexAlignment.None,
	}, main)

	-- ==================== Title ====================
	local Title = mk("Frame", {
		Name = "Title", LayoutOrder = 1, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, TITLE_HEIGHT), Active = true,
	}, main)
	mk("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalFlex = Enum.UIFlexAlignment.Fill,
	}, Title)

	local title = mk("TextLabel", {
		Name = "title", LayoutOrder = 1, Text = NAME,
		TextScaled = true, TextWrapped = true, BackgroundTransparency = 1,
		Size = UDim2.new(0, 179, 0, 17),
	}, Title)

	local setting = Instance.new("ImageButton")
	setting.Name = "setting"
	setting.Image = "rbxassetid://8445471332"
	setting.PressedImage = "rbxassetid://8445471332"
	setting.ImageRectOffset = Vector2.new(604, 404)
	setting.ImageRectSize = Vector2.new(96, 96)
	setting.AutoButtonColor = false
	setting.BackgroundTransparency = 0.9
	setting.BackgroundColor3 = WHITE
	setting.BorderSizePixel = 0
	setting.Size = UDim2.new(0, 19, 0, 19)
	setting.Parent = Title
	mk("UIAspectRatioConstraint", {AspectRatio = 0.9723502993583679, DominantAxis = Enum.DominantAxis.Height}, setting)

	local collapse = mk("TextButton", {
		Name = "collapse", LayoutOrder = 3, Text = "▼", TextSize = 10,
		BackgroundColor3 = WHITE, BackgroundTransparency = 0.9,
		Size = UDim2.new(0, 19, 0, 19),
	}, Title)
	mk("UIAspectRatioConstraint", {AspectRatio = 1, DominantAxis = Enum.DominantAxis.Height}, collapse)

	addButtonFx(collapse, function() return 0.9 end, 10)

	-- ==================== Body ====================
	local body = mk("CanvasGroup", {
		Name = "body", LayoutOrder = 2, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, BODY_HEIGHT),
	}, main)
	mk("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalFlex = Enum.UIFlexAlignment.Fill,
		VerticalFlex = Enum.UIFlexAlignment.None,
	}, body)

	local tabBar = mk("Frame", {
		Name = "tabBar", LayoutOrder = 1, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, TAB_HEIGHT),
	}, body)
	mk("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 1),
		HorizontalFlex = Enum.UIFlexAlignment.Fill,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}, tabBar)

	local pages = mk("Frame", {
		Name = "pages", LayoutOrder = 2, BackgroundTransparency = 1,
		ClipsDescendants = true, Size = UDim2.new(1, 0, 0, PAGES_HEIGHT),
	}, body)

	-- ==================== Page system ====================
	local TAB_ACTIVE_TRANSPARENCY = 0.1
	local TAB_INACTIVE_TRANSPARENCY = 0.9
	local TAB_TWEEN = TweenInfo.new(0.2, QUAD_OUT, Enum.EasingDirection.Out)
	local INSTANT = TweenInfo.new(0)
	local PAGE_SLIDE = 14
	local PAGE_IN  = TweenInfo.new(0.28, QUAD_OUT, Enum.EasingDirection.Out)
	local PAGE_OUT = TweenInfo.new(0.16, QUAD_OUT, Enum.EasingDirection.Out)
	local ACTIVE_TEXT = Color3.fromRGB(29, 29, 29)

	local tabList = {}
	local currentTab, lastTab
	local settingsEntry, settingFx
	local tabCount = 0

	-- elements in the page revealed sequentially
	local function playReveal(t)
		for i, a in ipairs(t.anims) do
			local inner = a.inner
			inner.GroupTransparency = 1
			inner.Position = UDim2.new(0, 12, 0, 0)
			tw(inner, "reveal", TweenInfo.new(0.3, QUAD_OUT, Enum.EasingDirection.Out, 0, false, math.min(i * 0.04, 0.4)), {
				GroupTransparency = 0,
				Position = UDim2.new(0, 0, 0, 0),
			})
		end
	end

	local function playTabsIn()
		for i, t in ipairs(tabList) do
			local info = TweenInfo.new(0.3, QUAD_OUT, Enum.EasingDirection.Out, 0, false, 0.1 + i * 0.05)
			t.button.BackgroundTransparency = 1
			t.button.TextTransparency = 1
			t.fx(info)
			tw(t.button, "txt", info, {TextTransparency = 0})
		end
	end

	local function selectEntry(nextT, instant)
		if currentTab == nextT then return end
		local prev = currentTab
		local dir = prev and (nextT.order > prev.order and 1 or -1) or 1
		currentTab = nextT
		if nextT ~= settingsEntry then lastTab = nextT end

		local info = instant and INSTANT or TAB_TWEEN
		for _, t in ipairs(tabList) do
			t.active = (t == nextT)
			t.fx(info)
			tw(t.button, "color", info, {TextColor3 = t.active and ACTIVE_TEXT or WHITE})
		end
		if settingFx then settingFx(info) end

		if instant then
			nextT.page.Visible = true
			nextT.page.GroupTransparency = 0
			return
		end

		if prev then
			local o = tw(prev.page, "page", PAGE_OUT, {
				GroupTransparency = 1,
				Position = UDim2.new(0, -dir * PAGE_SLIDE, 0, 0),
			})
			o.Completed:Connect(function(state)
				if state == Enum.PlaybackState.Completed and currentTab ~= prev then
					prev.page.Visible = false
				end
			end)
		end

		nextT.page.Visible = true
		nextT.page.GroupTransparency = 1
		nextT.page.Position = UDim2.new(0, dir * PAGE_SLIDE, 0, 0)
		tw(nextT.page, "page", PAGE_IN, {
			GroupTransparency = 0,
			Position = UDim2.new(0, 0, 0, 0),
		})
		playReveal(nextT)
	end

	-- ==================== Popup / drag helpers ====================
	local popups = {}

	local function inside(gui, p)
		local a, s = gui.AbsolutePosition, gui.AbsoluteSize
		return p.X >= a.X and p.X <= a.X + s.X and p.Y >= a.Y and p.Y <= a.Y + s.Y
	end

	local function closeAllPopups()
		for _, o in ipairs(popups) do o.set(false) end
	end

	-- dragging (mouse/finger) disables page scrolling while dragging
	local function dragify(hit, scroll, onMove, onActive)
		local active = false
		hit.InputBegan:Connect(function(input)
			if isPtr(input) then
				active = true
				scroll.ScrollingEnabled = false
				if onActive then onActive(true) end
				onMove(input.Position)
			end
		end)
		table.insert(connections, UserInputService.InputChanged:Connect(function(input)
			if active and (input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch) then
				onMove(input.Position)
			end
		end))
		table.insert(connections, UserInputService.InputEnded:Connect(function(input)
			if active and isPtr(input) then
				active = false
				scroll.ScrollingEnabled = true
				if onActive then onActive(false) end
			end
		end))
	end

	-- floating popup on the topmost layer (does not push other rows or get clipped)
	local function makePopup(header, h, scroll, pageFrame, onToggle)
		local popup = mk("CanvasGroup", {
			BackgroundColor3 = Color3.fromRGB(42, 42, 42),
			GroupTransparency = 1, Visible = false, ZIndex = 1,
			Size = UDim2.fromOffset(0, h),
		}, topLayer)
		mk("UIStroke", {Color = WHITE, Thickness = 1, Transparency = 0.85}, popup)

		local st = {open = false, frame = popup}

		local function place()
			local op, hp = topLayer.AbsolutePosition, header.AbsolutePosition
			local w = header.AbsoluteSize.X
			local x = math.clamp(hp.X - op.X, 0, math.max(topLayer.AbsoluteSize.X - w, 0))
			local y = hp.Y - op.Y + header.AbsoluteSize.Y + 2
			if y + h > topLayer.AbsoluteSize.Y then
				y = math.max(hp.Y - op.Y - h - 2, 0)
			end
			popup.Size = UDim2.fromOffset(w, h)
			popup.Position = UDim2.fromOffset(x, y)
		end

		function st.set(v)
			if v == st.open then return end
			if v then
				for _, o in ipairs(popups) do
					if o ~= st then o.set(false) end
				end
			end
			st.open = v
			if v then
				place()
				local target = popup.Position
				popup.Visible = true
				popup.Position = target + UDim2.fromOffset(0, -6)
				tw(popup, "fade", OPEN_TWEEN, {GroupTransparency = 0})
				tw(popup, "pos", OPEN_TWEEN, {Position = target})
			else
				local t = tw(popup, "fade", FX_TWEEN, {GroupTransparency = 1})
				t.Completed:Connect(function(state)
					if state == Enum.PlaybackState.Completed and not st.open then
						popup.Visible = false
					end
				end)
			end
			if onToggle then onToggle(v) end
		end

		table.insert(popups, st)

		table.insert(connections, UserInputService.InputBegan:Connect(function(input)
			if not st.open or not isPtr(input) then return end
			if inside(popup, input.Position) or inside(header, input.Position) then return end
			st.set(false)
		end))
		scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function() st.set(false) end)
		pageFrame:GetPropertyChangedSignal("Visible"):Connect(function() st.set(false) end)
		body:GetPropertyChangedSignal("Visible"):Connect(function() st.set(false) end)
		main:GetPropertyChangedSignal("Visible"):Connect(function() st.set(false) end)
		main:GetPropertyChangedSignal("Position"):Connect(function() st.set(false) end)

		return st
	end

	-- ============================================================
	--  newContainer: all page components
	-- ============================================================
	local function newContainer(pageFrame, anims)
		local scroll = mk("ScrollingFrame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, 0),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = WHITE,
			ScrollBarImageTransparency = 0.6,
		}, pageFrame)
		mk("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, scroll)
		mk("UIPadding", {
			PaddingTop = UDim.new(0, PAD), PaddingBottom = UDim.new(0, PAD),
			PaddingLeft = UDim.new(0, PAD), PaddingRight = UDim.new(0, PAD + 2),
		}, scroll)

		local ui = {}
		local order = 0

		-- wrapper (inside the layout) + inner CanvasGroup (plays fade/slide)
		local function entry(h, props)
			order += 1
			local wrap = mk("Frame", {
				LayoutOrder = order, BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			}, scroll)
			local p = {BackgroundColor3 = WHITE, BackgroundTransparency = ROW_BASE}
			for k, v in pairs(props or {}) do p[k] = v end
			p.Size = UDim2.new(1, 0, 0, h)
			local inner = mk("CanvasGroup", p, wrap)
			table.insert(anims, {inner = inner})
			return inner
		end

		-- ---------- Section / Label / Divider ----------
		function ui:Section(text)
			local f = entry(18, {BackgroundTransparency = 1})
			local l = label(f, text, {Size = UDim2.fromScale(1, 1), FontFace = FONT_BOLD, TextSize = 14})
			bindAccent(function(c) l.TextColor3 = c end)
			return f
		end

		function ui:Label(text)
			local f = entry(16, {BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y})
			local l = label(f, text, {
				Size = UDim2.new(1, 0, 0, 16), AutomaticSize = Enum.AutomaticSize.Y,
				TextWrapped = true, TextColor3 = GRAY,
			})
			l.TextTruncate = Enum.TextTruncate.None
			local obj = {}
			function obj:Set(t) l.Text = t end
			return obj
		end

		function ui:Divider()
			return entry(1, {BackgroundTransparency = 0.85})
		end

		-- ---------- Button ----------
		function ui:Button(text, cb, color)
			local base = color and 0.7 or ROW_BASE
			local f = entry(ROW_H, color and {BackgroundColor3 = color, BackgroundTransparency = base} or nil)
			local l = label(f, text, {Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center})
			local hit = overlay(f)
			addButtonFx(hit, function() return base end, 13, f, l)
			hit.MouseButton1Click:Connect(function() if cb then cb() end end)
			return f
		end

		-- ---------- Toggle (Switch) ----------
		function ui:Toggle(text, default, cb)
			local f = entry(ROW_H)
			label(f, text, {Position = UDim2.new(0, PAD, 0, 0), Size = UDim2.new(1, -50, 1, 0)})

			local track = mk("Frame", {
				AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -PAD, 0.5, 0),
				Size = UDim2.new(0, 28, 0, 14), BackgroundColor3 = OFF_COLOR,
			}, f)
			round(track)
			local knob = mk("Frame", {
				AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, 0),
				Size = UDim2.new(0, 10, 0, 10), BackgroundColor3 = WHITE,
			}, track)
			round(knob)

			local hit = overlay(f)
			addButtonFx(hit, function() return ROW_BASE end, nil, f)

			local state = false
			local function set(v, silent)
				state = v and true or false
				tw(track, "c", FX_TWEEN, {BackgroundColor3 = state and accent or OFF_COLOR})
				tw(knob, "p", FX_TWEEN, {Position = state and UDim2.new(1, -12, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)})
				if not silent and cb then cb(state) end
			end
			set(default, true)
			bindAccent(function(c)
				if state then tw(track, "c", FX_TWEEN, {BackgroundColor3 = c}) end
			end)
			hit.MouseButton1Click:Connect(function() set(not state) end)

			local obj = {}
			function obj:Set(v) set(v) end
			function obj:Get() return state end
			return obj
		end

		-- ---------- Slider ----------
		function ui:Slider(text, min, max, default, cb, step)
			step = step or 1
			local f = entry(34)
			label(f, text, {Position = UDim2.new(0, PAD, 0, 2), Size = UDim2.new(0.6, 0, 0, 16)})
			local valueLabel = label(f, "", {
				Position = UDim2.new(0.6, 0, 0, 2), Size = UDim2.new(0.4, -PAD, 0, 16),
				TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = GRAY,
			})
			local track = mk("Frame", {
				Position = UDim2.new(0, PAD, 0, 24), Size = UDim2.new(1, -PAD * 2, 0, 4),
				BackgroundColor3 = WHITE, BackgroundTransparency = 0.8,
			}, f)
			local fill = mk("Frame", {Size = UDim2.new(0, 0, 1, 0)}, track)
			bindAccent(function(c) fill.BackgroundColor3 = c end)
			local knob = mk("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
				Size = UDim2.new(0, 10, 0, 10), BackgroundColor3 = WHITE,
			}, fill)
			round(knob)

			local hit = mk("TextButton", {
				BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 14), Size = UDim2.new(1, 0, 0, 20),
			}, f)

			local value = default
			local function setValue(v, silent)
				v = round4(math.clamp(math.floor((v - min) / step + 0.5) * step + min, min, max))
				local changed = v ~= value
				value = v
				tw(fill, "s", TweenInfo.new(0.08, QUAD_OUT, Enum.EasingDirection.Out), {
					Size = UDim2.new((v - min) / (max - min), 0, 1, 0),
				})
				valueLabel.Text = tostring(v)
				if changed and not silent and cb then cb(v) end
			end
			setValue(default, true)

			dragify(hit, scroll, function(pos)
				local rel = math.clamp((pos.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
				setValue(min + rel * (max - min))
			end, function(active)
				tw(knob, "k", FX_TWEEN, {Size = active and UDim2.new(0, 14, 0, 14) or UDim2.new(0, 10, 0, 10)})
			end)

			local obj = {}
			function obj:Set(v) setValue(v) end
			function obj:Get() return value end
			return obj
		end

		-- ---------- Progress (Scorebar) ----------
		function ui:Progress(text, min, max, default)
			local f = entry(30)
			label(f, text, {Position = UDim2.new(0, PAD, 0, 2), Size = UDim2.new(0.6, 0, 0, 16)})
			local valueLabel = label(f, "", {
				Position = UDim2.new(0.6, 0, 0, 2), Size = UDim2.new(0.4, -PAD, 0, 16),
				TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = GRAY,
			})
			local track = mk("Frame", {
				Position = UDim2.new(0, PAD, 0, 21), Size = UDim2.new(1, -PAD * 2, 0, 5),
				BackgroundColor3 = WHITE, BackgroundTransparency = 0.8,
			}, f)
			local fill = mk("Frame", {Size = UDim2.new(0, 0, 1, 0)}, track)
			bindAccent(function(c) fill.BackgroundColor3 = c end)

			local value = default
			local function setValue(v, instant)
				value = math.clamp(v, min, max)
				local rel = (value - min) / (max - min)
				valueLabel.Text = math.floor(rel * 100 + 0.5) .. "%"
				local goal = {Size = UDim2.new(rel, 0, 1, 0)}
				if instant then
					fill.Size = goal.Size
				else
					tw(fill, "s", TweenInfo.new(0.3, QUAD_OUT, Enum.EasingDirection.Out), goal)
				end
			end
			setValue(default, true)

			local obj = {}
			function obj:Set(v) setValue(v) end
			function obj:Get() return value end
			return obj
		end

		-- ---------- Textbox ----------
		function ui:Textbox(text, placeholder, cb)
			local f = entry(ROW_H)
			label(f, text, {Position = UDim2.new(0, PAD, 0, 0), Size = UDim2.new(0.4, -PAD, 1, 0)})
			local box = mk("TextBox", {
				Position = UDim2.new(0.4, 0, 0, 3), Size = UDim2.new(0.6, -PAD, 1, -6),
				BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.6,
				PlaceholderText = placeholder or "", PlaceholderColor3 = GRAY,
				ClearTextOnFocus = false, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
				ClipsDescendants = true,
			}, f)
			mk("UIPadding", {PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4)}, box)

			box.Focused:Connect(function() tw(box, "bg", FX_TWEEN, {BackgroundTransparency = 0.3}) end)
			box.FocusLost:Connect(function(enter)
				tw(box, "bg", FX_TWEEN, {BackgroundTransparency = 0.6})
				if cb then cb(box.Text, enter) end
			end)

			local obj = {}
			function obj:Set(t) box.Text = t end
			function obj:Get() return box.Text end
			return obj
		end

		-- ---------- Dropdown (List) ----------
		function ui:Dropdown(text, options, default, cb)
			local f = entry(ROW_H, {BackgroundTransparency = 1})

			local header = mk("TextButton", {
				BackgroundColor3 = WHITE, BackgroundTransparency = ROW_BASE, Size = UDim2.new(1, 0, 0, ROW_H),
			}, f)
			addButtonFx(header, function() return ROW_BASE end)
			label(header, text, {Position = UDim2.new(0, PAD, 0, 0), Size = UDim2.new(0.5, -PAD, 1, 0)})

			local current = default or options[1]
			local selLabel = label(header, tostring(current), {
				Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0.5, -22, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = GRAY,
			})
			local arrow = label(header, "▼", {
				Position = UDim2.new(1, -18, 0, 0), Size = UDim2.new(0, 14, 1, 0),
				TextSize = 9, TextXAlignment = Enum.TextXAlignment.Center,
			})

			local popupH = math.min(#options * 22 + 2, 112)
			local pop = makePopup(header, popupH, scroll, pageFrame, function(open)
				tw(arrow, "rot", OPEN_TWEEN, {Rotation = open and 180 or 0})
			end)

			local list = mk("ScrollingFrame", {
				BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
				CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollBarThickness = 2, ScrollBarImageColor3 = WHITE,
			}, pop.frame)
			mk("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder}, list)
			mk("UIPadding", {
				PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2),
				PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 2),
			}, list)

			local applies = {}
			local function choose(opt, silent)
				current = opt
				selLabel.Text = tostring(opt)
				for _, a in ipairs(applies) do a() end
				if not silent and cb then cb(opt) end
			end

			for i, opt in ipairs(options) do
				local b = mk("TextButton", {
					LayoutOrder = i, Text = tostring(opt), TextSize = 12,
					TextXAlignment = Enum.TextXAlignment.Left,
					BackgroundColor3 = WHITE, BackgroundTransparency = 0.95, Size = UDim2.new(1, 0, 0, 20),
				}, list)
				mk("UIPadding", {PaddingLeft = UDim.new(0, PAD)}, b)
				table.insert(applies, addButtonFx(b, function()
					return current == opt and 0.8 or 0.95
				end, 12))
				b.MouseButton1Click:Connect(function()
					choose(opt)
					pop.set(false)
				end)
			end
			for _, a in ipairs(applies) do a() end

			header.MouseButton1Click:Connect(function() pop.set(not pop.open) end)

			local obj = {}
			function obj:Set(opt) choose(opt) end
			function obj:Get() return current end
			return obj
		end

		-- ---------- ColorPicker ----------
		function ui:ColorPicker(text, default, cb)
			local PANEL_H = 96
			local f = entry(ROW_H, {BackgroundTransparency = 1})

			local header = mk("TextButton", {
				BackgroundColor3 = WHITE, BackgroundTransparency = ROW_BASE, Size = UDim2.new(1, 0, 0, ROW_H),
			}, f)
			addButtonFx(header, function() return ROW_BASE end)
			label(header, text, {Position = UDim2.new(0, PAD, 0, 0), Size = UDim2.new(1, -50, 1, 0)})
			local swatch = mk("Frame", {
				AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -PAD, 0.5, 0),
				Size = UDim2.new(0, 28, 0, 14), BackgroundColor3 = default,
			}, header)

			local pop = makePopup(header, PANEL_H, scroll, pageFrame)
			local panel = pop.frame

			local sv = mk("Frame", {
				Position = UDim2.new(0, PAD, 0, PAD), Size = UDim2.new(1, -PAD * 2, 0, 64),
				ClipsDescendants = true,
			}, panel)
			local whiteLayer = mk("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE}, sv)
			mk("UIGradient", {Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1),
			})}, whiteLayer)
			local blackLayer = mk("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0)}, sv)
			mk("UIGradient", {Rotation = 90, Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0),
			})}, blackLayer)
			local svCursor = mk("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0, 8, 0, 8),
				BackgroundTransparency = 1, ZIndex = 3,
			}, sv)
			round(svCursor)
			mk("UIStroke", {Color = WHITE, Thickness = 1.5}, svCursor)

			local hueBar = mk("Frame", {
				Position = UDim2.new(0, PAD, 0, 76), Size = UDim2.new(1, -PAD * 2, 0, 12),
				BackgroundColor3 = WHITE,
			}, panel)
			mk("UIGradient", {Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0,     Color3.fromRGB(255, 0, 0)),
				ColorSequenceKeypoint.new(1 / 6, Color3.fromRGB(255, 255, 0)),
				ColorSequenceKeypoint.new(2 / 6, Color3.fromRGB(0, 255, 0)),
				ColorSequenceKeypoint.new(3 / 6, Color3.fromRGB(0, 255, 255)),
				ColorSequenceKeypoint.new(4 / 6, Color3.fromRGB(0, 0, 255)),
				ColorSequenceKeypoint.new(5 / 6, Color3.fromRGB(255, 0, 255)),
				ColorSequenceKeypoint.new(1,     Color3.fromRGB(255, 0, 0)),
			})}, hueBar)
			local hueCursor = mk("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0, 3, 1, 4), BackgroundColor3 = WHITE, ZIndex = 3,
			}, hueBar)

			local h, s, v = default:ToHSV()
			local function update(silent)
				local color = Color3.fromHSV(h, s, v)
				sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
				swatch.BackgroundColor3 = color
				svCursor.Position = UDim2.fromScale(s, 1 - v)
				hueCursor.Position = UDim2.new(h, 0, 0.5, 0)
				if not silent and cb then cb(color) end
			end
			update(true)

			dragify(overlay(sv), scroll, function(pos)
				s = math.clamp((pos.X - sv.AbsolutePosition.X) / sv.AbsoluteSize.X, 0, 1)
				v = 1 - math.clamp((pos.Y - sv.AbsolutePosition.Y) / sv.AbsoluteSize.Y, 0, 1)
				update()
			end, function(active)
				tw(svCursor, "k", FX_TWEEN, {Size = active and UDim2.new(0, 12, 0, 12) or UDim2.new(0, 8, 0, 8)})
			end)
			dragify(overlay(hueBar), scroll, function(pos)
				h = math.clamp((pos.X - hueBar.AbsolutePosition.X) / hueBar.AbsoluteSize.X, 0, 1)
				update()
			end, function(active)
				tw(hueCursor, "k", FX_TWEEN, {Size = active and UDim2.new(0, 5, 1, 6) or UDim2.new(0, 3, 1, 4)})
			end)

			header.MouseButton1Click:Connect(function() pop.set(not pop.open) end)

			local obj = {}
			function obj:Set(c) h, s, v = c:ToHSV(); update() end
			function obj:Get() return Color3.fromHSV(h, s, v) end
			return obj
		end

		-- ---------- Keybind ----------
		-- allowClear = false: pressing Esc does not clear the key (for buttons that cannot be empty)
		function ui:Keybind(text, default, cb, allowClear)
			local f = entry(ROW_H)
			label(f, text, {Position = UDim2.new(0, PAD, 0, 0), Size = UDim2.new(0.6, 0, 1, 0)})
			local keyLabel = label(f, default and default.Name or "None", {
				Position = UDim2.new(0.6, 0, 0, 0), Size = UDim2.new(0.4, -PAD, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = GRAY,
			})
			local hit = overlay(f)
			addButtonFx(hit, function() return ROW_BASE end, nil, f)

			local key, listening = default, false
			hit.MouseButton1Click:Connect(function()
				listening = true
				keyLabel.Text = "..."
				tw(keyLabel, "c", FX_TWEEN, {TextColor3 = accent})
			end)
			table.insert(connections, UserInputService.InputBegan:Connect(function(input, processed)
				if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
				if listening then
					listening = false
					if input.KeyCode == Enum.KeyCode.Escape then
						if allowClear ~= false then key = nil end
					else
						key = input.KeyCode
					end
					keyLabel.Text = key and key.Name or "None"
					tw(keyLabel, "c", FX_TWEEN, {TextColor3 = GRAY})
				elseif key and input.KeyCode == key and not processed then
					if cb then cb(key) end
				end
			end))

			local obj = {}
			function obj:Get() return key end
			return obj
		end

		return ui
	end

	-- ==================== Create pages (internal) ====================
	local function makePage(name, hasTab)
		local e = {name = name, active = false, anims = {}}

		local pageFrame = mk("CanvasGroup", {
			Name = name, BackgroundTransparency = 1, Visible = false,
			Size = UDim2.new(1, 0, 1, 0),
		}, pages)
		e.page = pageFrame

		if hasTab then
			tabCount += 1
			e.order = tabCount

			local button = mk("TextButton", {
				Name = name, LayoutOrder = tabCount, Text = name, TextSize = 12,
				BackgroundColor3 = WHITE, BackgroundTransparency = TAB_INACTIVE_TRANSPARENCY,
				Size = UDim2.new(0, 50, 1, 0),
			}, tabBar)
			e.button = button
			e.fx = addButtonFx(button, function()
				return e.active and TAB_ACTIVE_TRANSPARENCY or TAB_INACTIVE_TRANSPARENCY
			end, 12)
			table.insert(tabList, e)

			button.MouseButton1Click:Connect(function() selectEntry(e) end)
		else
			e.order = 1000 -- Settings page is always on the far right (used to determine slide direction)
		end

		e.ui = newContainer(pageFrame, e.anims)

		if hasTab and not currentTab then
			selectEntry(e, true)
		end
		return e
	end

	-- ==================== Notify / Dialog ====================
	local MAX_TOASTS = 4

	local toastHolder = mk("Frame", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.new(0, 210, 1, -20), BackgroundTransparency = 1, ZIndex = 3,
	}, topLayer)
	mk("UIListLayout", {
		Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
	}, toastHolder)

	local toastOrder = 0
	local aliveToasts = {}

	local function notify(titleText, text, duration, kind)
		duration = duration or 3
		local color = ({
			success = Color3.fromRGB(80, 200, 120),
			warn    = Color3.fromRGB(255, 190, 60),
			error   = RED,
		})[kind or "info"] or accent
		toastOrder += 1

		local wrap = mk("Frame", {
			LayoutOrder = toastOrder, BackgroundTransparency = 1, ClipsDescendants = true,
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		}, toastHolder)

		local t = mk("CanvasGroup", {
			BackgroundColor3 = Color3.fromRGB(29, 29, 29), GroupTransparency = 1,
			Position = UDim2.new(0, 40, 0, 0), Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
		}, wrap)
		mk("UIStroke", {Color = color, Thickness = 1, Transparency = 0.5}, t)
		mk("UIListLayout", {Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder}, t)
		mk("UIPadding", {
			PaddingTop = UDim.new(0, 7), PaddingBottom = UDim.new(0, 7),
			PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
		}, t)

		label(t, titleText or "", {
			LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 16), TextColor3 = color, FontFace = FONT_BOLD, TextSize = 14,
		})
		if text and text ~= "" then
			local msg = label(t, text, {
				LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 14), AutomaticSize = Enum.AutomaticSize.Y,
				TextWrapped = true, TextColor3 = GRAY, TextSize = 12, TextYAlignment = Enum.TextYAlignment.Top,
			})
			msg.TextTruncate = Enum.TextTruncate.None
		end
		local bar = mk("Frame", {
			LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = color, BackgroundTransparency = 0.2,
		}, t)

		local dead = false
		local obj = {}
		function obj.Dismiss()
			if dead then return end
			dead = true
			local i = table.find(aliveToasts, obj)
			if i then table.remove(aliveToasts, i) end

			local h = wrap.AbsoluteSize.Y
			wrap.AutomaticSize = Enum.AutomaticSize.None
			wrap.Size = UDim2.new(1, 0, 0, h)
			tw(t, "fade", TweenInfo.new(0.22, QUAD_OUT, Enum.EasingDirection.In), {
				GroupTransparency = 1, Position = UDim2.new(0, 40, 0, 0),
			})
			local s = tw(wrap, "size", TweenInfo.new(0.25, QUAD_OUT, Enum.EasingDirection.Out, 0, false, 0.15), {
				Size = UDim2.new(1, 0, 0, 0),
			})
			s.Completed:Connect(function() wrap:Destroy() end)
		end

		t.InputBegan:Connect(function(input)
			if isPtr(input) then obj.Dismiss() end
		end)

		table.insert(aliveToasts, obj)
		if #aliveToasts > MAX_TOASTS then aliveToasts[1].Dismiss() end

		tw(t, "fade", OPEN_TWEEN, {GroupTransparency = 0, Position = UDim2.new(0, 0, 0, 0)})
		tw(bar, "timer", TweenInfo.new(duration, Enum.EasingStyle.Linear), {Size = UDim2.new(0, 0, 0, 2)})
		task.delay(duration, obj.Dismiss)

		return obj
	end

	local currentDialog

	local function dialog(opts)
		opts = opts or {}
		if currentDialog then currentDialog.close(true) end

		local d = {}
		currentDialog = d

		local dim = mk("TextButton", {
			BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1), ZIndex = 2,
		}, topLayer)

		local card = mk("CanvasGroup", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 10),
			Size = UDim2.new(0, 230, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Color3.fromRGB(42, 42, 42), GroupTransparency = 1,
			Active = true,
		}, dim)
		mk("UIStroke", {Color = WHITE, Thickness = 1, Transparency = 0.85}, card)
		mk("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, card)
		mk("UIPadding", {
			PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8),
			PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
		}, card)

		label(card, opts.title or "", {
			LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 16), FontFace = FONT_BOLD, TextSize = 14,
		})

		if opts.text and opts.text ~= "" then
			local msg = label(card, opts.text, {
				LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 14), AutomaticSize = Enum.AutomaticSize.Y,
				TextWrapped = true, TextColor3 = GRAY, TextSize = 12, TextYAlignment = Enum.TextYAlignment.Top,
			})
			msg.TextTruncate = Enum.TextTruncate.None
		end

		local input
		if opts.input ~= nil then
			input = mk("TextBox", {
				LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 22),
				BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.6,
				PlaceholderText = tostring(opts.input), PlaceholderColor3 = GRAY,
				ClearTextOnFocus = false, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
				Text = opts.default or "", ClipsDescendants = true,
			}, card)
			mk("UIPadding", {PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4)}, input)
			input.Focused:Connect(function() tw(input, "bg", FX_TWEEN, {BackgroundTransparency = 0.3}) end)
			input.FocusLost:Connect(function() tw(input, "bg", FX_TWEEN, {BackgroundTransparency = 0.6}) end)
		end

		local row = mk("Frame", {LayoutOrder = 4, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22)}, card)
		mk("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder, HorizontalFlex = Enum.UIFlexAlignment.Fill,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}, row)

		local closed = false
		local conn1, conn2

		function d.close(instant)
			if closed then return end
			closed = true
			if currentDialog == d then currentDialog = nil end
			if conn1 then conn1:Disconnect() end
			if conn2 then conn2:Disconnect() end
			if instant then
				dim:Destroy()
				return
			end
			tw(dim, "bg", FX_TWEEN, {BackgroundTransparency = 1})
			tw(card, "fade", FX_TWEEN, {GroupTransparency = 1, Position = UDim2.new(0.5, 0, 0.5, 8)})
			task.delay(0.2, function() dim:Destroy() end)
		end

		for i, b in ipairs(opts.buttons or {{text = "OK", primary = true}}) do
			local base = b.primary and 0.2 or ROW_BASE
			local btn = mk("TextButton", {
				LayoutOrder = i, Text = b.text, TextSize = 12,
				BackgroundColor3 = b.primary and (b.color or accent) or WHITE, BackgroundTransparency = base,
				Size = UDim2.new(0, 50, 1, 0),
			}, row)
			addButtonFx(btn, function() return base end, 12)
			btn.MouseButton1Click:Connect(function()
				local text = input and input.Text
				d.close()
				if b.callback then b.callback(text) end
			end)
		end

		if opts.dismissable ~= false then
			dim.MouseButton1Click:Connect(function() d.close() end)
		end
		conn1 = body:GetPropertyChangedSignal("Visible"):Connect(function()
			if not body.Visible then d.close(true) end
		end)
		conn2 = main:GetPropertyChangedSignal("Visible"):Connect(function()
			if not main.Visible then d.close(true) end
		end)

		tw(dim, "bg", FX_TWEEN, {BackgroundTransparency = 0.45})
		tw(card, "fade", OPEN_TWEEN, {GroupTransparency = 0, Position = UDim2.new(0.5, 0, 0.5, 0)})

		return d
	end

	local function confirm(titleText, text, onYes, onNo)
		return dialog({
			title = titleText, text = text,
			buttons = {
				{text = "Cancel", callback = onNo},
				{text = "Confirm", primary = true, callback = onYes},
			},
		})
	end

	local function prompt(titleText, text, placeholder, onSubmit)
		return dialog({
			title = titleText, text = text, input = placeholder or "",
			buttons = {
				{text = "Cancel"},
				{text = "OK", primary = true, callback = onSubmit},
			},
		})
	end

	-- ==================== Collapse/Expand ====================
	local SIZE_TWEEN_OUT = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	local FADE_TWEEN_OUT = TweenInfo.new(0.18, QUAD_OUT, Enum.EasingDirection.Out)
	local FADE_TWEEN_IN  = TweenInfo.new(0.30, QUAD_OUT, Enum.EasingDirection.Out, 0, false, 0.08)
	local ARROW_TWEEN    = TweenInfo.new(0.30, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	local collapsed = false
	local activeTweens = {}

	local function cancelTweens()
		for _, t in ipairs(activeTweens) do t:Cancel() end
		table.clear(activeTweens)
	end

	local function play(instance, info, goal)
		local t = TweenService:Create(instance, info, goal)
		table.insert(activeTweens, t)
		t:Play()
		return t
	end

	local function setCollapsed(state)
		if state == collapsed then return end
		collapsed = state
		cancelTweens()

		if collapsed then
			play(body, FADE_TWEEN_OUT, {GroupTransparency = 1})
			play(collapse, ARROW_TWEEN, {Rotation = -90})
			local sizeTween = play(main, SIZE_TWEEN_OUT, {Size = UDim2.new(0, WIDTH, 0, TITLE_HEIGHT)})
			sizeTween.Completed:Connect(function(playbackState)
				if playbackState == Enum.PlaybackState.Completed and collapsed then
					body.Visible = false
				end
			end)
		else
			body.Visible = true
			play(body, FADE_TWEEN_IN, {GroupTransparency = 0})
			play(collapse, ARROW_TWEEN, {Rotation = 0})
			play(main, SIZE_TWEEN_OUT, {Size = UDim2.new(0, WIDTH, 0, EXPANDED_HEIGHT)})
			playTabsIn()
			if currentTab then playReveal(currentTab) end
		end
	end

	collapse.MouseButton1Click:Connect(function()
		setCollapsed(not collapsed)
	end)

	-- ==================== Hide/Show (Hotkey) and Kill ====================
	local shown = true
	local closing = false
	local HIDE_TWEEN = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
	local OUTRO = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.In)

	local function setShown(v)
		if closing or v == shown then return end
		shown = v
		if v then
			main.Visible = true
			tw(main, "vis", OPEN_TWEEN, {GroupTransparency = 0})
			tw(slideY, "slide", OPEN_TWEEN, {Value = 0})
		else
			if currentDialog then currentDialog.close(true) end
			closeAllPopups()
			local t = tw(main, "vis", HIDE_TWEEN, {GroupTransparency = 1})
			tw(slideY, "slide", HIDE_TWEEN, {Value = 40})
			t.Completed:Connect(function(state)
				if state == Enum.PlaybackState.Completed and not shown then
					main.Visible = false
				end
			end)
		end
	end

	local function kill()
		if closing then return end
		closing = true
		if config.OnKill then task.spawn(pcall, config.OnKill) end
		if currentDialog then currentDialog.close(true) end
		closeAllPopups()
		if not shown then
			screenGui:Destroy()
			return
		end
		setCollapsed(true)
		task.delay(0.3, function()
			tw(main, "vis", OUTRO, {GroupTransparency = 1})
			tw(slideY, "slide", OUTRO, {Value = 40})
			task.delay(0.4, function() screenGui:Destroy() end)
		end)
	end

	-- ==================== Main Settings page (library internal only) ====================
	settingsEntry = makePage("__settings", false)
	settingFx = addButtonFx(setting, function()
		return currentTab == settingsEntry and 0.6 or 0.9
	end)

	setting.MouseButton1Click:Connect(function()
		if currentTab == settingsEntry then
			selectEntry(lastTab or tabList[1])
		else
			selectEntry(settingsEntry)
		end
	end)

	do
		local s = settingsEntry.ui
		s:Section("Settings")
		s:Keybind("Hide / Show UI", hotkey, function() setShown(not shown) end, false)
		s:ColorPicker("Main Color", accent, function(c) setAccent(c) end)
		s:Divider()
		s:Button("Kill UI", function()
			confirm("Kill UI?", "Close and completely remove this UI", kill)
		end, RED)
		s:Label(NAME .. " • Tomato UI Library • version 0.0.1")
	end

	-- ==================== Drag system (X-axis + smooth damping) ====================
	local SMOOTHNESS = 8
	local dragging = false
	local dragStartX, startOffsetX = 0, 0
	local targetX = main.Position.X.Offset
	local currentX = targetX

	local function getBounds()
		return -(screenGui.AbsoluteSize.X - main.AbsoluteSize.X), -RIGHT
	end

	Title.InputBegan:Connect(function(input)
		if isPtr(input) then
			dragging = true
			dragStartX = input.Position.X
			startOffsetX = targetX
		end
	end)

	table.insert(connections, UserInputService.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement
			and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local minX, maxX = getBounds()
		targetX = math.clamp(startOffsetX + (input.Position.X - dragStartX), minX, maxX)
	end))

	table.insert(connections, UserInputService.InputEnded:Connect(function(input)
		if isPtr(input) then dragging = false end
	end))

	table.insert(connections, RunService.RenderStepped:Connect(function(dt)
		local minX, maxX = getBounds()
		targetX = math.clamp(targetX, minX, maxX)

		if math.abs(targetX - currentX) < 0.05 then
			currentX = targetX
		else
			currentX = currentX + (targetX - currentX) * (1 - math.exp(-SMOOTHNESS * dt))
		end

		main.Position = UDim2.new(1, currentX, 1, -BOTTOM + slideY.Value)
	end))

	-- ==================== Intro ====================
	collapsed = true
	body.Visible = false
	body.GroupTransparency = 1
	collapse.Rotation = -90
	main.Size = UDim2.new(0, WIDTH, 0, TITLE_HEIGHT)
	main.GroupTransparency = 1
	slideY.Value = 40

	popIn(title, 0.15)
	popIn(setting, 0.25)
	popIn(collapse, 0.30)

	local INTRO = TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	tw(main, "vis", INTRO, {GroupTransparency = 0})
	tw(slideY, "slide", INTRO, {Value = 0})

	task.delay(0.5, function()
		if not closing then setCollapsed(false) end
	end)

	-- ==================== Window API (the only thing accessible to external scripts) ====================
	local Window = {}

	function Window:AddPage(name)
		return makePage(tostring(name), true).ui
	end
	function Window:Notify(titleText, text, duration, kind)
		return notify(titleText, text, duration, kind)
	end
	function Window:Dialog(opts)
		return dialog(opts)
	end
	function Window:Confirm(titleText, text, onYes, onNo)
		return confirm(titleText, text, onYes, onNo)
	end
	function Window:Prompt(titleText, text, placeholder, onSubmit)
		return prompt(titleText, text, placeholder, onSubmit)
	end

	return Window
end

return Library
