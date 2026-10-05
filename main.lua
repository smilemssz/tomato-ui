-- ============================================================
--  Tomato UI Library v2.1
--  + 2.1+ family windows can communicate (Hub is shared across scripts)
--  + Edge-snapped (mini) windows can stack like a cake up to 6 layers (can be disabled)
--  + Window:PopupWindow  Windows-style draggable dialog
--  + Lucide icons ("lucide:icon-name") from latte-soft/lucide-roblox
-- ============================================================
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ScriptContext = game:GetService("ScriptContext")

local Library = {Logs = {}, Version = "2.1"}

-- ==================== Constants / shared helpers ====================

local QUAD_OUT   = Enum.EasingStyle.Quad
local FX_TWEEN   = TweenInfo.new(0.15, QUAD_OUT, Enum.EasingDirection.Out)
local OPEN_TWEEN = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local WHITE     = Color3.fromRGB(255, 255, 255)
local GRAY      = Color3.fromRGB(170, 170, 170)
local OFF_COLOR = Color3.fromRGB(70, 70, 70)
local RED       = Color3.fromRGB(235, 70, 70)
local GREEN     = Color3.fromRGB(80, 200, 120)
local FONT      = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
local FONT_BOLD = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)

local ROW_H, PAD, ROW_BASE = 24, 6, 0.9

local running = setmetatable({}, {__mode = "k"})

-- tweens are separated by "channel" per instance; reusing the same channel cancels the previous tween
local function tw(inst, channel, info, goal)
	running[inst] = running[inst] or {}
	local old = running[inst][channel]
	if old then old:Cancel() end
	local t = TweenService:Create(inst, info, goal)
	running[inst][channel] = t
	t:Play()
	return t
end

-- hover / press: becomes darker + text shrinks slightly
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
local function lerp(a, b, t) return a + (b - a) * t end

-- accepts numeric ID / "123" / "rbxassetid://123" / URL
local function toImage(v)
	if type(v) == "number" then return "rbxassetid://" .. v end
	v = tostring(v or "")
	if v:match("^%d+$") then return "rbxassetid://" .. v end
	return v
end

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

local function overlay(parent)
	return mk("TextButton", {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 10}, parent)
end

-- match key: string / table of strings / function(key) -> bool
local function matchKey(spec, input)
	input = tostring(input or "")
	if type(spec) == "function" then
		local ok, res = pcall(spec, input)
		return ok and res and true or false
	elseif type(spec) == "table" then
		for _, k in ipairs(spec) do
			if tostring(k) == input then return true end
		end
		return false
	end
	return spec ~= nil and tostring(spec) == input
end

local function getClipboard()
	return setclipboard or toclipboard
end

-- ==================== Error Log (view/copy popup) ====================

local logGui, logBox, logTitle

local function refreshLog()
	if logBox then logBox.Text = table.concat(Library.Logs, "\n\n") end
	if logTitle then logTitle.Text = "Error Log (" .. #Library.Logs .. ")" end
end

local function showLog()
	if logGui and logGui.Parent then
		refreshLog()
		return
	end
	pcall(function()
		local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
		local old = playerGui:FindFirstChild("TomatoErrorLog")
		if old then old:Destroy() end

		local gui = Instance.new("ScreenGui")
		gui.Name = "TomatoErrorLog"
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = true
		gui.DisplayOrder = 1000
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		gui.Parent = playerGui
		logGui = gui

		local card = mk("CanvasGroup", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 10),
			Size = UDim2.fromOffset(320, 230), BackgroundColor3 = Color3.fromRGB(29, 29, 29),
			GroupTransparency = 1,
		}, gui)
		mk("UIStroke", {Color = RED, Thickness = 1, Transparency = 0.4}, card)

		logTitle = label(card, "", {
			Position = UDim2.new(0, 10, 0, 6), Size = UDim2.new(1, -20, 0, 18),
			TextColor3 = RED, FontFace = FONT_BOLD, TextSize = 14,
		})

		local sc = mk("ScrollingFrame", {
			Position = UDim2.new(0, 8, 0, 30), Size = UDim2.new(1, -16, 1, -68),
			BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.6,
			CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 3, ScrollingDirection = Enum.ScrollingDirection.Y,
		}, card)
		mk("UIPadding", {
			PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4),
			PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4),
		}, sc)
		logBox = mk("TextBox", {
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1, TextWrapped = true, TextEditable = false,
			ClearTextOnFocus = false, MultiLine = true, TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = Color3.fromRGB(230, 230, 230),
		}, sc)

		local row = mk("Frame", {
			BackgroundTransparency = 1, Position = UDim2.new(0, 8, 1, -32), Size = UDim2.new(1, -16, 0, 24),
		}, card)
		mk("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, row)

		local function btn(order, text)
			local b = mk("TextButton", {
				LayoutOrder = order, Text = text, TextSize = 12,
				BackgroundColor3 = WHITE, BackgroundTransparency = ROW_BASE,
				Size = UDim2.new(1 / 3, -4, 1, 0),
			}, row)
			addButtonFx(b, function() return ROW_BASE end, 12)
			return b
		end
		local copyB, clearB, closeB = btn(1, "Copy"), btn(2, "Clear"), btn(3, "Close")

		copyB.MouseButton1Click:Connect(function()
			local f = getClipboard()
			if f and pcall(f, table.concat(Library.Logs, "\n\n")) then
				copyB.Text = "Copied"
			else
				copyB.Text = "Select text manually"
			end
			task.delay(1.4, function() copyB.Text = "Copy" end)
		end)
		clearB.MouseButton1Click:Connect(function()
			table.clear(Library.Logs)
			refreshLog()
		end)
		closeB.MouseButton1Click:Connect(function()
			tw(card, "fade", FX_TWEEN, {GroupTransparency = 1})
			task.delay(0.2, function() gui:Destroy() end)
			logGui, logBox, logTitle = nil, nil, nil
		end)

		refreshLog()
		tw(card, "fade", OPEN_TWEEN, {GroupTransparency = 0, Position = UDim2.new(0.5, 0, 0.5, 0)})
	end)
end

local function logError(tag, err)
	table.insert(Library.Logs, string.format("[%s] %s\n%s", os.date("%H:%M:%S"), tostring(tag), tostring(err)))
	if #Library.Logs > 50 then table.remove(Library.Logs, 1) end
	warn("[Tomato UI] " .. tostring(tag) .. ": " .. tostring(err))
	task.defer(showLog)
end

local function errHandler(e)
	return tostring(e) .. "\n" .. debug.traceback("", 2)
end

-- call callbacks safely: errors are shown in Error Log instead of stopping the script
local function call(tag, fn, ...)
	if type(fn) ~= "function" then return end
	local ok, err = xpcall(fn, errHandler, ...)
	if not ok then logError(tag, err) end
end

Library.LogError = logError
Library.ShowLog = showLog

function Library:Protect(fn, ...)
	local ok, err = xpcall(fn, errHandler, ...)
	if not ok then logError("Script", err) end
	return ok
end

-- ==================== Lucide icons (latte-soft/lucide-roblox) ====================
-- works anywhere an image is accepted: "lucide:settings", "lucide:home", etc.
-- by default loads from the latest release; to change the source: Library:SetIconSource(url or module)

local ICON_URL = "https://github.com/latte-soft/lucide-roblox/releases/latest/download/lucide-roblox.luau"
local Lucide, lucideTried

function Library:SetIconSource(src)
	if type(src) == "table" then
		Lucide, lucideTried = src, true
	elseif type(src) == "string" then
		ICON_URL, Lucide, lucideTried = src, nil, nil
	end
end

local function loadLucide()
	if Lucide or lucideTried then return Lucide end
	lucideTried = true
	local ok, res = pcall(function()
		return loadstring(game:HttpGet(ICON_URL))()
	end)
	if ok and type(res) == "table" and res.GetAsset then
		Lucide = res
	else
		logError("Icons", "Failed to load Lucide: " .. tostring(res))
	end
	return Lucide
end

-- set images for ImageLabel/ImageButton; supports both ID/URL and "lucide:name"
local function setImg(obj, spec, px)
	obj.ImageRectOffset = Vector2.zero
	obj.ImageRectSize = Vector2.zero
	if type(spec) == "string" and spec:sub(1, 7) == "lucide:" then
		local L = loadLucide()
		if L then
			local ok, asset = pcall(L.GetAsset, spec:sub(8), (px or 24) <= 48 and 48 or 256)
			if ok and asset then
				obj.Image = asset.Url
				obj.ImageRectOffset = asset.ImageRectOffset
				obj.ImageRectSize = asset.ImageRectSize
				return true
			end
			logError("Icons", "Icon not found: " .. spec)
		end
		obj.Image = ""
		return false
	end
	obj.Image = toImage(spec)
	return true
end

function Library:GetIcon(name, size)
	local L = loadLucide()
	if not L then return nil end
	local ok, a = pcall(L.GetAsset, name, size or 48)
	return ok and a or nil
end

function Library:IconNames()
	local L = loadLucide()
	return L and L.IconNames or {}
end

-- ==================== Hub: let 2.1+ windows communicate + cake stacking ====================
-- uses a shared global table, so windows can communicate even when the library is loaded by different scripts

local env = (getgenv and getgenv()) or _G
local Hub = env.__TomatoHub21
if not Hub then
	Hub = {
		Version = "2.1", windows = {}, shared = {}, MAX_STACK = 6,
		piles = {left = {list = {}}, right = {list = {}}, top = {list = {}}, bottom = {list = {}}},
	}
	env.__TomatoHub21 = Hub
end

local function hubRegister(ctrl)
	Hub.windows[ctrl.name] = ctrl
end

local function pileLeave(ctrl)
	for _, pile in pairs(Hub.piles) do
		local i = table.find(pile.list, ctrl)
		if i then
			table.remove(pile.list, i)
			if #pile.list == 0 then pile.anchor = nil end
		end
	end
end

local function pileJoin(ctrl, edge, anchor)
	local pile = Hub.piles[edge]
	if table.find(pile.list, ctrl) then return true end
	if #pile.list >= Hub.MAX_STACK then return false end
	if #pile.list == 0 then pile.anchor = anchor end
	table.insert(pile.list, ctrl)
	return true
end

local function hubUnregister(ctrl)
	if Hub.windows[ctrl.name] == ctrl then Hub.windows[ctrl.name] = nil end
	pileLeave(ctrl)
end

-- send message: target = window name, or nil = send to every window except itself
local function hubDeliver(from, target, topic, ...)
	local args = table.pack(...)
	for name, ctrl in pairs(Hub.windows) do
		if (target == nil and name ~= from) or (target ~= nil and name == target) then
			task.spawn(ctrl.deliver, from, topic, table.unpack(args, 1, args.n))
		end
	end
end

local function hubInvoke(from, target, name, ...)
	local c = Hub.windows[target]
	if not c then return false, "Window not found: " .. tostring(target) end
	local f = c.exposed[name]
	if not f then return false, "Not Exposed: " .. tostring(name) end
	return pcall(f, from, ...)
end

local function hubSetShared(from, key, value)
	Hub.shared[key] = value
	for _, ctrl in pairs(Hub.windows) do
		local hs = ctrl.sharedHandlers[key]
		if hs then
			for _, fn in ipairs(hs) do task.spawn(call, "Shared " .. tostring(key), fn, value, from) end
		end
	end
end

function Library:GetWindows()
	local t = {}
	for name in pairs(Hub.windows) do table.insert(t, name) end
	table.sort(t)
	return t
end

-- ============================================================
--  Library:KeySystem
-- ============================================================
function Library:KeySystem(cfg)
	cfg = cfg or {}
	local accent = cfg.Accent or Color3.fromRGB(255, 99, 71)
	local result

	local function check(k)
		if type(cfg.Validate) == "function" then
			local ok, res = pcall(cfg.Validate, k)
			return ok and res and true or false
		end
		return matchKey(cfg.Keys or cfg.Key, k)
	end

	if cfg.SaveFile then
		local ok, saved = pcall(function()
			if isfile and readfile and isfile(cfg.SaveFile) then return readfile(cfg.SaveFile) end
		end)
		if ok and saved and saved ~= "" and check(saved) then
			call("KeySystem.OnSuccess", cfg.OnSuccess, saved)
			return true
		end
	end

	local built, err = xpcall(function()
		local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
		local old = playerGui:FindFirstChild("TomatoKey")
		if old then old:Destroy() end

		local gui = Instance.new("ScreenGui")
		gui.Name = "TomatoKey"
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = true
		gui.DisplayOrder = 900
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		gui.Parent = playerGui

		local dim = mk("Frame", {BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1)}, gui)
		local card = mk("CanvasGroup", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 10),
			Size = UDim2.new(0, 280, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Color3.fromRGB(29, 29, 29), GroupTransparency = 1,
		}, dim)
		mk("UIStroke", {Color = accent, Thickness = 1, Transparency = 0.5}, card)
		mk("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, card)
		mk("UIPadding", {
			PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
			PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10),
		}, card)

		local header = mk("Frame", {LayoutOrder = 1, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20)}, card)
		label(header, cfg.Name or "Key System", {Size = UDim2.new(1, -24, 1, 0), FontFace = FONT_BOLD, TextSize = 16, TextColor3 = accent})
		local closeB = mk("TextButton", {
			Text = "X", TextSize = 12, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(20, 20), BackgroundColor3 = WHITE, BackgroundTransparency = 0.9,
		}, header)
		addButtonFx(closeB, function() return 0.9 end, 12)

		if cfg.Description then
			local d = label(card, cfg.Description, {
				LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 14), AutomaticSize = Enum.AutomaticSize.Y,
				TextWrapped = true, TextColor3 = GRAY, TextSize = 12, TextYAlignment = Enum.TextYAlignment.Top,
			})
			d.TextTruncate = Enum.TextTruncate.None
		end

		if cfg.Url then
			local urlBox = mk("TextBox", {
				LayoutOrder = 3, Text = cfg.Url, Size = UDim2.new(1, 0, 0, 22), TextSize = 12,
				BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.6,
				TextEditable = false, ClearTextOnFocus = false, TextColor3 = GRAY,
				TextXAlignment = Enum.TextXAlignment.Left, ClipsDescendants = true,
			}, card)
			mk("UIPadding", {PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4)}, urlBox)
		end

		local input = mk("TextBox", {
			LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 24), TextSize = 13,
			BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.6,
			PlaceholderText = "Enter Key here...", PlaceholderColor3 = GRAY,
			ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, ClipsDescendants = true,
		}, card)
		mk("UIPadding", {PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6)}, input)

		local status = label(card, "", {LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 14), TextSize = 12, TextColor3 = GRAY})
		local function setStatus(t, c)
			status.Text = t
			status.TextColor3 = c or GRAY
		end

		local row = mk("Frame", {LayoutOrder = 6, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24)}, card)
		mk("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, row)

		local getB = mk("TextButton", {
			LayoutOrder = 1, Text = cfg.GetKeyText or "getkey", TextSize = 13,
			BackgroundColor3 = WHITE, BackgroundTransparency = ROW_BASE, Size = UDim2.new(0.5, -3, 1, 0),
		}, row)
		addButtonFx(getB, function() return ROW_BASE end, 13)
		local checkB = mk("TextButton", {
			LayoutOrder = 2, Text = cfg.CheckText or "Check Key", TextSize = 13,
			BackgroundColor3 = accent, BackgroundTransparency = 0.3, Size = UDim2.new(0.5, -3, 1, 0),
		}, row)
		addButtonFx(checkB, function() return 0.3 end, 13)

		local function finish(v)
			if result ~= nil then return end
			result = v
			tw(dim, "bg", FX_TWEEN, {BackgroundTransparency = 1})
			tw(card, "fade", FX_TWEEN, {GroupTransparency = 1})
			task.delay(0.25, function() gui:Destroy() end)
		end

		local function shake()
			task.spawn(function()
				for i = 1, 4 do
					tw(card, "pos", TweenInfo.new(0.05), {Position = UDim2.new(0.5, i % 2 == 0 and 6 or -6, 0.5, 0)})
					task.wait(0.05)
				end
				tw(card, "pos", TweenInfo.new(0.08), {Position = UDim2.new(0.5, 0, 0.5, 0)})
			end)
		end

		getB.MouseButton1Click:Connect(function()
			if cfg.GetKeyCallback then call("KeySystem.GetKey", cfg.GetKeyCallback) end
			if not cfg.Url then return end
			local f = getClipboard()
			if f and pcall(f, cfg.Url) then
				setStatus("Link copied; open it in your browser", GREEN)
			else
				setStatus("Copy the link from the field above manually", GRAY)
			end
		end)

		local busy = false
		local function doCheck()
			if busy or result ~= nil then return end
			busy = true
			setStatus("Checking...", GRAY)
			task.spawn(function()
				local key = input.Text
				local good = check(key)
				busy = false
				if good then
					setStatus("Success", GREEN)
					if cfg.SaveFile and writefile then pcall(writefile, cfg.SaveFile, key) end
					finish(true)
					call("KeySystem.OnSuccess", cfg.OnSuccess, key)
				else
					setStatus(cfg.WrongText or "Invalid key", RED)
					shake()
				end
			end)
		end
		checkB.MouseButton1Click:Connect(doCheck)
		input.FocusLost:Connect(function(enter) if enter then doCheck() end end)

		closeB.MouseButton1Click:Connect(function()
			finish(false)
			call("KeySystem.OnClose", cfg.OnClose)
		end)

		tw(dim, "bg", FX_TWEEN, {BackgroundTransparency = 0.45})
		tw(card, "fade", OPEN_TWEEN, {GroupTransparency = 0, Position = UDim2.new(0.5, 0, 0.5, 0)})
	end, errHandler)

	if not built then
		logError("KeySystem", err)
		return false
	end

	while result == nil do task.wait(0.1) end
	return result
end

-- ============================================================
--  Library:CreateWindow
--  config = {
--      Name, Accent, Hotkey, OnKill, NotifyDuration, CatchAllErrors,
--      Stack = true   -- enable/disable cake stacking when edge-snapped (can also be changed in Settings)
--  }
-- ============================================================
local function createWindow(config)
	config = config or {}
	local NAME = tostring(config.Name or "UI")
	local accent = config.Accent or Color3.fromRGB(255, 99, 71)
	local hotkey = config.Hotkey or Enum.KeyCode.RightShift
	local defaultDuration = config.NotifyDuration or 3
	local stackEnabled = config.Stack ~= false

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild(NAME)
	if existing then existing:Destroy() end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = NAME
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.DisplayOrder = 50
	screenGui.Parent = playerGui

	local connections = {}
	screenGui.Destroying:Connect(function()
		for _, c in ipairs(connections) do c:Disconnect() end
		table.clear(connections)
	end)

	if config.CatchAllErrors then
		table.insert(connections, ScriptContext.Error:Connect(function(msg, trace)
			logError("Script", tostring(msg) .. "\n" .. tostring(trace))
		end))
	end

	-- ---------- window controller in the Hub (cross-window communication) ----------
	local ctrl = {name = NAME, handlers = {}, exposed = {}, sharedHandlers = {}}
	function ctrl.deliver(from, topic, ...)
		local hs = ctrl.handlers[topic]
		if not hs then return end
		for _, fn in ipairs(hs) do call("On " .. tostring(topic), fn, from, ...) end
	end
	hubRegister(ctrl)
	screenGui.Destroying:Connect(function()
		hubUnregister(ctrl)
		hubDeliver(NAME, nil, "WindowRemoved", NAME)
	end)

	-- top screen layer: Dropdown/ColorPicker popups, dialogs, toasts, PopupWindow
	-- ZIndex order: PopupWindow 2-45 < floating popup 50 < toast 60 < dialog 70
	local topLayer = mk("Frame", {Name = "topLayer", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 100}, screenGui)

	-- ---------- accent color system ----------
	local accentFns = {}
	local function bindAccent(fn)
		table.insert(accentFns, fn)
		fn(accent)
	end
	local function setAccent(c)
		accent = c
		for _, fn in ipairs(accentFns) do fn(c) end
	end

	-- ==================== size / state ====================
	local RIGHT, BOTTOM, WIDTH = 0, 0, 211
	local TITLE_HEIGHT, TAB_HEIGHT, PAGES_HEIGHT = 19, 17, 219
	local DOCK_BODY = TAB_HEIGHT + PAGES_HEIGHT
	local MIN_W, MIN_H = 170, TITLE_HEIGHT + TAB_HEIGHT + 90

	local SNAP_SCALE = 0.75 -- size when edge-snapped (0.75 = shrunk by 25%)
	local SNAP_PEEK  = 0.25 -- portion visible beyond the screen edge (0.25 = 25% visible)
	local EDGE, MARGIN = 6, 12
	local SMOOTHNESS = 8
	local ICON_DOCK, ICON_WINDOW = "□", "▭"

	local function num(v)
		local n = Instance.new("NumberValue")
		n.Value = v
		n.Parent = screenGui
		return n
	end
	local slideY, blend, collapseAlpha, snapScale = num(0), num(0), num(0), num(1)

	local mode = "dock"
	local dockTX, dockCX = -RIGHT, -RIGHT
	local winInit = false
	local winX, winY, winW, winH = 0, 0, 260, 300
	local winCX, winCY = 0, 0
	local snapped, snapEdge = false, nil
	local inPile, stackedCollapse = false, false

	-- ==================== window structure ====================
	local main = mk("CanvasGroup", {
		Name = "main", AnchorPoint = Vector2.new(0, 0),
		Size = UDim2.fromOffset(WIDTH, TITLE_HEIGHT),
		BackgroundColor3 = Color3.fromRGB(29, 29, 29), BorderColor3 = Color3.fromRGB(0, 0, 0),
		GroupTransparency = 1,
	}, screenGui)
	local uiScale = mk("UIScale", {}, main)

	local content = mk("Frame", {Name = "content", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1)}, main)
	mk("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder}, content)

	-- ---------- Title ----------
	local Title = mk("Frame", {
		Name = "Title", LayoutOrder = 1, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, TITLE_HEIGHT), Active = true,
	}, content)
	mk("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder}, Title)

	local title = mk("TextLabel", {
		Name = "title", LayoutOrder = 1, Text = NAME, TextSize = 14, BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -57, 1, 0),
	}, Title)
	mk("UIPadding", {PaddingLeft = UDim.new(0, 6)}, title)

	local modeBtn = mk("TextButton", {
		Name = "mode", LayoutOrder = 2, Text = ICON_DOCK, TextSize = 12,
		BackgroundColor3 = WHITE, BackgroundTransparency = 0.9, Size = UDim2.fromOffset(19, 19),
	}, Title)

	local setting = mk("ImageButton", {
		Name = "setting", LayoutOrder = 3, Image = "rbxassetid://8445471332",
		ImageRectOffset = Vector2.new(604, 404), ImageRectSize = Vector2.new(96, 96),
		BackgroundColor3 = WHITE, BackgroundTransparency = 0.9, Size = UDim2.fromOffset(19, 19),
	}, Title)

	local collapse = mk("TextButton", {
		Name = "collapse", LayoutOrder = 4, Text = "▼", TextSize = 10,
		BackgroundColor3 = WHITE, BackgroundTransparency = 0.9, Size = UDim2.fromOffset(19, 19),
	}, Title)

	addButtonFx(modeBtn, function() return 0.9 end, 12)
	addButtonFx(collapse, function() return 0.9 end, 10)

	-- ---------- Body ----------
	local body = mk("CanvasGroup", {
		Name = "body", LayoutOrder = 2, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, DOCK_BODY),
	}, content)
	mk("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder}, body)

	local tabBar = mk("Frame", {
		Name = "tabBar", LayoutOrder = 1, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, TAB_HEIGHT),
	}, body)
	mk("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 1), HorizontalFlex = Enum.UIFlexAlignment.Fill,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}, tabBar)

	local pages = mk("Frame", {
		Name = "pages", LayoutOrder = 2, BackgroundTransparency = 1,
		ClipsDescendants = true, Size = UDim2.new(1, 0, 0, PAGES_HEIGHT),
	}, body)

	-- ==================== Page system ====================
	local TAB_ACTIVE_TRANSPARENCY, TAB_INACTIVE_TRANSPARENCY = 0.1, 0.9
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

	-- forward declaration
	local notify, dialog, confirm, prompt, makeBodyPopup, makePopupWindow
	local popups, bodyPopups, popupWins = {}, {}, {}

	local function closeAllPopups()
		for _, o in ipairs(popups) do o.set(false) end
	end
	local function closeBodyPopups()
		for _, p in ipairs(bodyPopups) do p:Close(true) end
	end

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
		closeAllPopups()
		closeBodyPopups()

		local info = instant and INSTANT or TAB_TWEEN
		for _, t in ipairs(tabList) do
			t.active = (t == nextT)
			t.fx(info)
			tw(t.button, "color", info, {TextColor3 = t.active and ACTIVE_TEXT or WHITE})
			if t.icon then
				tw(t.icon, "color", info, {ImageColor3 = t.active and ACTIVE_TEXT or WHITE})
			end
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
		tw(nextT.page, "page", PAGE_IN, {GroupTransparency = 0, Position = UDim2.new(0, 0, 0, 0)})
		playReveal(nextT)
	end

	-- ==================== component helpers ====================
	local function inside(gui, p)
		local a, s = gui.AbsolutePosition, gui.AbsoluteSize
		return p.X >= a.X and p.X <= a.X + s.X and p.Y >= a.Y and p.Y <= a.Y + s.Y
	end

	local function dragify(hit, scrolls, onMove, onActive)
		local active = false
		local function freeze(v)
			for _, sc in ipairs(scrolls) do sc.ScrollingEnabled = v end
		end
		hit.InputBegan:Connect(function(input)
			if isPtr(input) then
				active = true
				freeze(false)
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
				freeze(true)
				if onActive then onActive(false) end
			end
		end))
	end

	-- floating popup on the top layer (does not push other rows or get clipped)
	local function makePopup(header, h, scrolls, visFrame, onToggle)
		local popup = mk("CanvasGroup", {
			BackgroundColor3 = Color3.fromRGB(42, 42, 42),
			GroupTransparency = 1, Visible = false, ZIndex = 50, Size = UDim2.fromOffset(0, h),
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
		for _, sc in ipairs(scrolls) do
			sc:GetPropertyChangedSignal("CanvasPosition"):Connect(function() st.set(false) end)
		end
		visFrame:GetPropertyChangedSignal("Visible"):Connect(function() st.set(false) end)
		visFrame:GetPropertyChangedSignal("Position"):Connect(function() st.set(false) end)
		body:GetPropertyChangedSignal("Visible"):Connect(function() st.set(false) end)
		main:GetPropertyChangedSignal("Visible"):Connect(function() st.set(false) end)
		main:GetPropertyChangedSignal("Position"):Connect(function() st.set(false) end)

		return st
	end

	-- component lock
	local function attachLock(f, obj, hook)
		local ov = mk("TextButton", {
			BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1), ZIndex = 30, Visible = false,
		}, f)
		local tag = label(ov, "", {
			Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center,
			TextSize = 11, TextColor3 = GRAY, ZIndex = 31,
		})
		local locked, key = false, nil

		function obj:Lock(k)
			locked, key = true, k
			ov.Visible = true
			tag.Text = k ~= nil and "LOCKED • Tap to enter Key" or "LOCKED"
			tw(ov, "bg", FX_TWEEN, {BackgroundTransparency = 0.35})
			if hook then hook(true) end
		end
		function obj:Unlock()
			locked, key = false, nil
			tag.Text = ""
			local t = tw(ov, "bg", FX_TWEEN, {BackgroundTransparency = 1})
			t.Completed:Connect(function() if not locked then ov.Visible = false end end)
			if hook then hook(false) end
		end
		function obj:IsLocked() return locked end

		ov.MouseButton1Click:Connect(function()
			if key == nil then return end
			prompt("Enter Key", "Enter the key to unlock", "key...", function(txt)
				if matchKey(key, txt) then
					obj:Unlock()
					notify("Unlocked", nil, 2, "success")
				else
					notify("Invalid key", nil, 2, "error")
				end
			end)
		end)
		return obj
	end

	local function finishObj(f, obj, opts, hook)
		attachLock(f, obj, hook)
		if type(opts) == "table" then
			if opts.LockKey ~= nil then obj:Lock(opts.LockKey)
			elseif opts.Lock then obj:Lock() end
		end
		return obj
	end

	-- ============================================================
	--  build: component builder
	-- ============================================================
	local function build(host, scrolls, anims, visFrame)
		local ui = {}
		local order = 0

		local function entry(h, props)
			order += 1
			local wrap = mk("Frame", {
				LayoutOrder = order, BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			}, host)
			local p = {BackgroundColor3 = WHITE, BackgroundTransparency = ROW_BASE}
			for k, v in pairs(props or {}) do p[k] = v end
			p.Size = UDim2.new(1, 0, 0, h)
			local inner = mk(anims and "CanvasGroup" or "Frame", p, wrap)
			if anims then table.insert(anims, {inner = inner}) end
			return inner
		end

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

		-- ---------- Image (supports "lucide:name") ----------
		function ui:Image(image, height, opts)
			opts = opts or {}
			local f = entry(height or 80, {BackgroundTransparency = opts.Background and ROW_BASE or 1})
			local img = mk("ImageLabel", {
				BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
				ScaleType = opts.Crop and Enum.ScaleType.Crop or Enum.ScaleType.Fit,
				ImageColor3 = opts.Color or WHITE,
			}, f)
			setImg(img, image, height or 80)
			if opts.Round then mk("UICorner", {CornerRadius = UDim.new(0, opts.Round)}, img) end
			local obj = {}
			function obj:Set(v) setImg(img, v, height or 80) end
			return obj
		end

		-- ---------- Button (opts.Icon = "lucide:name") ----------
		function ui:Button(text, cb, opts)
			local color = typeof(opts) == "Color3" and opts or (type(opts) == "table" and opts.Color) or nil
			local base = color and 0.7 or ROW_BASE
			local f = entry(ROW_H, color and {BackgroundColor3 = color, BackgroundTransparency = base} or nil)
			local l = label(f, text, {Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center})
			if type(opts) == "table" and opts.Icon then
				local ic = mk("ImageLabel", {
					BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, PAD, 0.5, 0), Size = UDim2.fromOffset(14, 14),
				}, f)
				setImg(ic, opts.Icon, 14)
			end
			local hit = overlay(f)
			addButtonFx(hit, function() return base end, 13, f, l)
			hit.MouseButton1Click:Connect(function() call("Button " .. text, cb) end)
			local obj = {}
			function obj:SetText(t) l.Text = t end
			return finishObj(f, obj, type(opts) == "table" and opts or nil)
		end

		function ui:Buttons(list)
			local f = entry(ROW_H, {BackgroundTransparency = 1})
			mk("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 4), HorizontalFlex = Enum.UIFlexAlignment.Fill,
			}, f)
			local objs = {}
			for i, b in ipairs(list) do
				local base = b.Color and 0.7 or ROW_BASE
				local btn = mk("TextButton", {
					LayoutOrder = i, Text = b.Text or "", TextSize = 13,
					BackgroundColor3 = b.Color or WHITE, BackgroundTransparency = base,
					Size = UDim2.new(0, 50, 1, 0),
				}, f)
				addButtonFx(btn, function() return base end, 13)
				btn.MouseButton1Click:Connect(function() call("Buttons " .. (b.Text or i), b.Callback) end)
				local obj = {}
				function obj:SetText(t) btn.Text = t end
				objs[i] = finishObj(btn, obj, b)
			end
			return objs
		end

		-- ---------- ImageButton (supports "lucide:name") ----------
		function ui:ImageButton(image, text, cb, opts)
			local h = (type(opts) == "table" and opts.Height) or 28
			local f = entry(h)
			local img = mk("ImageLabel", {
				BackgroundTransparency = 1, Size = UDim2.fromOffset(h - 8, h - 8),
				AnchorPoint = text and Vector2.new(0, 0.5) or Vector2.new(0.5, 0.5),
				Position = text and UDim2.new(0, 6, 0.5, 0) or UDim2.fromScale(0.5, 0.5),
			}, f)
			setImg(img, image, h - 8)
			local l
			if text then
				l = label(f, text, {Position = UDim2.new(0, h + 2, 0, 0), Size = UDim2.new(1, -(h + 8), 1, 0)})
			end
			local hit = overlay(f)
			addButtonFx(hit, function() return ROW_BASE end, text and 13 or nil, f, l)
			hit.MouseButton1Click:Connect(function() call("ImageButton", cb) end)
			local obj = {}
			function obj:SetImage(v) setImg(img, v, h - 8) end
			return finishObj(f, obj, opts)
		end

		function ui:Box(opts)
			opts = opts or {}
			local f = entry(opts.Height or 10, {
				BackgroundTransparency = opts.Transparency or 0.93,
				AutomaticSize = opts.Height and Enum.AutomaticSize.None or Enum.AutomaticSize.Y,
			})
			mk("UIStroke", {Color = WHITE, Transparency = 0.9}, f)
			mk("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, f)
			mk("UIPadding", {
				PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4),
				PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4),
			}, f)
			local sub = build(f, scrolls, nil, visFrame)
			if opts.Title then sub:Section(opts.Title) end
			return sub
		end

		function ui:ScrollBox(height, opts)
			opts = opts or {}
			local f = entry(height or 100, {BackgroundTransparency = opts.Transparency or 0.93})
			local sb = mk("ScrollingFrame", {
				BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
				CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 3,
				ScrollBarImageColor3 = WHITE, ScrollBarImageTransparency = 0.5,
			}, f)
			mk("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, sb)
			mk("UIPadding", {
				PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4),
				PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 6),
			}, sb)
			local newScrolls = table.clone(scrolls)
			table.insert(newScrolls, sb)
			local sub = build(sb, newScrolls, nil, visFrame)
			if opts.Title then sub:Section(opts.Title) end
			return sub
		end

		function ui:Popup(opts)
			return makeBodyPopup(opts)
		end

		function ui:Toggle(text, default, cb, opts)
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
				if not silent then call("Toggle " .. text, cb, state) end
			end
			set(default, true)
			bindAccent(function(c)
				if state then tw(track, "c", FX_TWEEN, {BackgroundColor3 = c}) end
			end)
			hit.MouseButton1Click:Connect(function() set(not state) end)

			local obj = {}
			function obj:Set(v) set(v) end
			function obj:Get() return state end
			return finishObj(f, obj, opts)
		end

		function ui:Slider(text, min, max, default, cb, step, opts)
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
				if changed and not silent then call("Slider " .. text, cb, v) end
			end
			setValue(default, true)

			dragify(hit, scrolls, function(pos)
				local rel = math.clamp((pos.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
				setValue(min + rel * (max - min))
			end, function(active)
				tw(knob, "k", FX_TWEEN, {Size = active and UDim2.new(0, 14, 0, 14) or UDim2.new(0, 10, 0, 10)})
			end)

			local obj = {}
			function obj:Set(v) setValue(v) end
			function obj:Get() return value end
			return finishObj(f, obj, opts)
		end

		function ui:Stepper(text, min, max, default, cb, step, opts)
			step = step or 1
			local f = entry(ROW_H)
			label(f, text, {Position = UDim2.new(0, PAD, 0, 0), Size = UDim2.new(1, -90, 1, 0)})
			local value = default

			local function small(txt, xOff)
				local b = mk("TextButton", {
					Text = txt, TextSize = 14, AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, xOff, 0.5, 0), Size = UDim2.fromOffset(18, 18),
					BackgroundColor3 = WHITE, BackgroundTransparency = 0.85,
				}, f)
				addButtonFx(b, function() return 0.85 end, 14)
				return b
			end
			local plus = small("+", -PAD)
			local valLabel = label(f, "", {
				AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -PAD - 20, 0.5, 0),
				Size = UDim2.fromOffset(34, 18), TextXAlignment = Enum.TextXAlignment.Center,
			})
			local minus = small("-", -PAD - 56)

			local function setValue(v, silent)
				v = round4(math.clamp(v, min, max))
				local changed = v ~= value
				value = v
				valLabel.Text = tostring(v)
				if changed and not silent then call("Stepper " .. text, cb, v) end
			end
			setValue(default, true)
			plus.MouseButton1Click:Connect(function() setValue(value + step) end)
			minus.MouseButton1Click:Connect(function() setValue(value - step) end)

			local obj = {}
			function obj:Set(v) setValue(v) end
			function obj:Get() return value end
			return finishObj(f, obj, opts)
		end

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

		function ui:Textbox(text, placeholder, cb, opts)
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
				call("Textbox " .. text, cb, box.Text, enter)
			end)

			local obj = {}
			function obj:Set(t) box.Text = t end
			function obj:Get() return box.Text end
			return finishObj(f, obj, opts, function(on)
				if on then pcall(function() box:ReleaseFocus() end) end
			end)
		end

		function ui:Input(text, placeholder, cb, opts)
			opts = opts or {}
			local multi = opts.MultiLine == true
			local boxH = opts.Height or (multi and 64 or 24)
			local f = entry(20 + boxH + 4)
			label(f, text, {Position = UDim2.new(0, PAD, 0, 3), Size = UDim2.new(1, -PAD * 2, 0, 14)})
			local box = mk("TextBox", {
				Position = UDim2.new(0, PAD, 0, 20), Size = UDim2.new(1, -PAD * 2, 0, boxH),
				BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.6,
				PlaceholderText = placeholder or "", PlaceholderColor3 = GRAY,
				ClearTextOnFocus = false, TextSize = 12, MultiLine = multi, TextWrapped = multi,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = multi and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,
				ClipsDescendants = true,
			}, f)
			mk("UIPadding", {
				PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4),
				PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3),
			}, box)

			box.Focused:Connect(function() tw(box, "bg", FX_TWEEN, {BackgroundTransparency = 0.3}) end)
			box.FocusLost:Connect(function(enter)
				tw(box, "bg", FX_TWEEN, {BackgroundTransparency = 0.6})
				if not opts.Live then call("Input " .. text, cb, box.Text, enter) end
			end)
			if opts.Live then
				box:GetPropertyChangedSignal("Text"):Connect(function() call("Input " .. text, cb, box.Text, false) end)
			end

			local obj = {}
			function obj:Set(t) box.Text = t end
			function obj:Get() return box.Text end
			return finishObj(f, obj, opts, function(on)
				if on then pcall(function() box:ReleaseFocus() end) end
			end)
		end

		function ui:Dropdown(text, options, default, cb, opts)
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
			local pop = makePopup(header, popupH, scrolls, visFrame, function(open)
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
				if not silent then call("Dropdown " .. text, cb, opt) end
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
			return finishObj(f, obj, opts, function(on)
				if on then pop.set(false) end
			end)
		end

		function ui:ColorPicker(text, default, cb, opts)
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

			local pop = makePopup(header, PANEL_H, scrolls, visFrame)
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
				if not silent then call("ColorPicker " .. text, cb, color) end
			end
			update(true)

			dragify(overlay(sv), scrolls, function(pos)
				s = math.clamp((pos.X - sv.AbsolutePosition.X) / sv.AbsoluteSize.X, 0, 1)
				v = 1 - math.clamp((pos.Y - sv.AbsolutePosition.Y) / sv.AbsoluteSize.Y, 0, 1)
				update()
			end, function(active)
				tw(svCursor, "k", FX_TWEEN, {Size = active and UDim2.new(0, 12, 0, 12) or UDim2.new(0, 8, 0, 8)})
			end)
			dragify(overlay(hueBar), scrolls, function(pos)
				h = math.clamp((pos.X - hueBar.AbsolutePosition.X) / hueBar.AbsoluteSize.X, 0, 1)
				update()
			end, function(active)
				tw(hueCursor, "k", FX_TWEEN, {Size = active and UDim2.new(0, 5, 1, 6) or UDim2.new(0, 3, 1, 4)})
			end)

			header.MouseButton1Click:Connect(function() pop.set(not pop.open) end)

			local obj = {}
			function obj:Set(c) h, s, v = c:ToHSV(); update() end
			function obj:Get() return Color3.fromHSV(h, s, v) end
			return finishObj(f, obj, opts, function(on)
				if on then pop.set(false) end
			end)
		end

		function ui:Keybind(text, default, cb, allowClear, opts)
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
					call("Keybind " .. text, cb, key)
				end
			end))

			local obj = {}
			function obj:Get() return key end
			return finishObj(f, obj, opts)
		end

		return ui
	end

	-- ==================== create page (internal) ====================
	local function makePage(name, hasTab, icon)
		local e = {name = name, active = false, anims = {}}

		local pageFrame = mk("CanvasGroup", {
			Name = name, BackgroundTransparency = 1, Visible = false, Size = UDim2.new(1, 0, 1, 0),
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
			if icon then
				local ic = mk("ImageLabel", {
					BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 4, 0.5, 0), Size = UDim2.fromOffset(11, 11), ZIndex = 2,
				}, button)
				setImg(ic, icon, 11)
				mk("UIPadding", {PaddingLeft = UDim.new(0, 12)}, button)
				e.icon = ic
			end
			e.fx = addButtonFx(button, function()
				return e.active and TAB_ACTIVE_TRANSPARENCY or TAB_INACTIVE_TRANSPARENCY
			end, 12)
			table.insert(tabList, e)
			button.MouseButton1Click:Connect(function() selectEntry(e) end)
		else
			e.order = 1000
		end

		local scroll = mk("ScrollingFrame", {
			BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0),
			CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 3,
			ScrollBarImageColor3 = WHITE, ScrollBarImageTransparency = 0.6,
		}, pageFrame)
		mk("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, scroll)
		mk("UIPadding", {
			PaddingTop = UDim.new(0, PAD), PaddingBottom = UDim.new(0, PAD),
			PaddingLeft = UDim.new(0, PAD), PaddingRight = UDim.new(0, PAD + 2),
		}, scroll)

		e.ui = build(scroll, {scroll}, e.anims, pageFrame)

		if hasTab and not currentTab then
			selectEntry(e, true)
		end
		return e
	end

	-- ==================== Popup inside body ====================
	makeBodyPopup = function(opts)
		opts = opts or {}
		local H = opts.Height or 140

		local dim = mk("TextButton", {
			Name = "popupDim", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1), ZIndex = 5, Visible = false,
		}, pages)

		local card = mk("CanvasGroup", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 8),
			Size = opts.Width and UDim2.fromOffset(opts.Width, H) or UDim2.new(1, -16, 0, H),
			BackgroundColor3 = Color3.fromRGB(42, 42, 42), GroupTransparency = 1, Active = true,
		}, dim)
		mk("UIStroke", {Color = WHITE, Thickness = 1, Transparency = 0.85}, card)

		label(card, opts.Title or "", {
			Position = UDim2.new(0, 8, 0, 2), Size = UDim2.new(1, -34, 0, 20), FontFace = FONT_BOLD, TextSize = 14,
		})
		local closeB = mk("TextButton", {
			Text = "X", TextSize = 12, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -3, 0, 3),
			Size = UDim2.fromOffset(16, 16), BackgroundColor3 = WHITE, BackgroundTransparency = 0.9,
		}, card)
		addButtonFx(closeB, function() return 0.9 end, 12)

		local sc = mk("ScrollingFrame", {
			BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 24), Size = UDim2.new(1, 0, 1, -24),
			CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 3,
			ScrollBarImageColor3 = WHITE, ScrollBarImageTransparency = 0.6,
		}, card)
		mk("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, sc)
		mk("UIPadding", {
			PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, PAD),
			PaddingLeft = UDim.new(0, PAD), PaddingRight = UDim.new(0, PAD + 2),
		}, sc)

		local sub = build(sc, {sc}, nil, dim)
		local isOpen = false

		function sub:Open()
			if isOpen then return end
			isOpen = true
			closeAllPopups()
			dim.Visible = true
			dim.BackgroundTransparency = 1
			card.GroupTransparency = 1
			card.Position = UDim2.new(0.5, 0, 0.5, 8)
			tw(dim, "bg", FX_TWEEN, {BackgroundTransparency = 0.5})
			tw(card, "fade", OPEN_TWEEN, {GroupTransparency = 0, Position = UDim2.new(0.5, 0, 0.5, 0)})
		end
		function sub:Close(instant)
			if not isOpen then return end
			isOpen = false
			if instant then
				dim.Visible = false
				return
			end
			tw(dim, "bg", FX_TWEEN, {BackgroundTransparency = 1})
			tw(card, "fade", FX_TWEEN, {GroupTransparency = 1, Position = UDim2.new(0.5, 0, 0.5, 8)})
			task.delay(0.2, function() if not isOpen then dim.Visible = false end end)
		end
		function sub:Toggle()
			if isOpen then sub:Close() else sub:Open() end
		end
		function sub:IsOpen() return isOpen end

		closeB.MouseButton1Click:Connect(function() sub:Close() end)
		if opts.Closable == false then
			closeB.Visible = false
		else
			dim.MouseButton1Click:Connect(function() sub:Close() end)
		end
		body:GetPropertyChangedSignal("Visible"):Connect(function()
			if not body.Visible then sub:Close(true) end
		end)

		table.insert(bodyPopups, sub)
		return sub
	end

	-- ==================== PopupWindow: Windows-style draggable dialog ====================
	-- Window:PopupWindow({Title, Icon, Text, Width, Height, Position=Vector2, Closable,
	--                     Buttons={ {Text, Callback, Primary, Color, Keep} }})
	local pwZ, pwCount = 2, 0

	makePopupWindow = function(opts)
		opts = opts or {}
		pwCount += 1
		local W, H = opts.Width or 240, opts.Height or 170
		local hasBtns = opts.Buttons and #opts.Buttons > 0

		local card = mk("CanvasGroup", {
			Size = UDim2.fromOffset(W, H), BackgroundColor3 = Color3.fromRGB(36, 36, 36),
			GroupTransparency = 1, Visible = false, ZIndex = 2, Active = true,
		}, topLayer)
		mk("UIStroke", {Color = WHITE, Thickness = 1, Transparency = 0.8}, card)

		local bar = mk("Frame", {BackgroundColor3 = Color3.fromRGB(52, 52, 52), Size = UDim2.new(1, 0, 0, 22), Active = true}, card)
		local x0 = PAD
		if opts.Icon then
			local ic = mk("ImageLabel", {
				BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 6, 0.5, 0), Size = UDim2.fromOffset(14, 14),
			}, bar)
			setImg(ic, opts.Icon, 14)
			x0 = 24
		end
		local ttl = label(bar, opts.Title or "", {
			Position = UDim2.new(0, x0, 0, 0), Size = UDim2.new(1, -(x0 + 26), 1, 0),
			FontFace = FONT_BOLD, TextSize = 13,
		})
		local closeB = mk("TextButton", {
			Text = "X", TextSize = 12, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -3, 0.5, 0),
			Size = UDim2.fromOffset(18, 16), BackgroundColor3 = RED, BackgroundTransparency = 0.6,
		}, bar)
		addButtonFx(closeB, function() return 0.6 end, 12)

		local footH = hasBtns and 30 or 0
		local sc = mk("ScrollingFrame", {
			BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 22),
			Size = UDim2.new(1, 0, 1, -(22 + footH)),
			CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 3,
			ScrollBarImageColor3 = WHITE, ScrollBarImageTransparency = 0.6,
		}, card)
		mk("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, sc)
		mk("UIPadding", {
			PaddingTop = UDim.new(0, PAD), PaddingBottom = UDim.new(0, PAD),
			PaddingLeft = UDim.new(0, PAD), PaddingRight = UDim.new(0, PAD + 2),
		}, sc)

		local sub = build(sc, {sc}, nil, card)
		if opts.Text and opts.Text ~= "" then sub:Label(opts.Text) end

		local isOpen, placed = false, false

		function sub:Open()
			if isOpen then return end
			isOpen = true
			closeAllPopups()
			if not placed then
				placed = true
				local s = topLayer.AbsoluteSize
				local x, y
				if opts.Position then
					x, y = opts.Position.X, opts.Position.Y
				else
					local c = ((pwCount - 1) % 5) * 18
					x, y = (s.X - W) / 2 + c, (s.Y - H) / 2 + c
				end
				card.Position = UDim2.fromOffset(math.clamp(x, 0, math.max(s.X - W, 0)), math.clamp(y, 0, math.max(s.Y - H, 0)))
			end
			pwZ = math.min(pwZ + 1, 45)
			card.ZIndex = pwZ
			card.Visible = true
			tw(card, "fade", OPEN_TWEEN, {GroupTransparency = 0})
		end
		function sub:Close(instant)
			if not isOpen then return end
			isOpen = false
			if instant then
				card.Visible = false
				card.GroupTransparency = 1
				return
			end
			local t = tw(card, "fade", FX_TWEEN, {GroupTransparency = 1})
			t.Completed:Connect(function(state)
				if state == Enum.PlaybackState.Completed and not isOpen then card.Visible = false end
			end)
		end
		function sub:Toggle()
			if isOpen then sub:Close() else sub:Open() end
		end
		function sub:IsOpen() return isOpen end
		function sub:SetTitle(t) ttl.Text = t end

		-- window footer buttons
		if hasBtns then
			local row = mk("Frame", {
				BackgroundTransparency = 1, Position = UDim2.new(0, 6, 1, -28), Size = UDim2.new(1, -12, 0, 24),
			}, card)
			mk("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder, HorizontalFlex = Enum.UIFlexAlignment.Fill,
			}, row)
			for i, b in ipairs(opts.Buttons) do
				local base = b.Primary and 0.2 or ROW_BASE
				local btn = mk("TextButton", {
					LayoutOrder = i, Text = b.Text or "OK", TextSize = 12,
					BackgroundColor3 = b.Primary and (b.Color or accent) or (b.Color or WHITE),
					BackgroundTransparency = base, Size = UDim2.new(0, 50, 1, 0),
				}, row)
				addButtonFx(btn, function() return base end, 12)
				btn.MouseButton1Click:Connect(function()
					call("PopupWindow " .. tostring(b.Text), b.Callback)
					if not b.Keep then sub:Close() end
				end)
			end
		end

		-- drag window from title bar + click to bring it to front
		local dragging, dStart, dOrigin = false, Vector3.zero, UDim2.new()
		bar.InputBegan:Connect(function(input)
			if isPtr(input) then
				dragging, dStart, dOrigin = true, input.Position, card.Position
				pwZ = math.min(pwZ + 1, 45)
				card.ZIndex = pwZ
			end
		end)
		card.InputBegan:Connect(function(input)
			if isPtr(input) and not dragging then
				pwZ = math.min(pwZ + 1, 45)
				card.ZIndex = pwZ
			end
		end)
		table.insert(connections, UserInputService.InputChanged:Connect(function(input)
			if not dragging then return end
			if input.UserInputType ~= Enum.UserInputType.MouseMovement
				and input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			local d = input.Position - dStart
			local s = topLayer.AbsoluteSize
			card.Position = UDim2.fromOffset(
				math.clamp(dOrigin.X.Offset + d.X, 0, math.max(s.X - W, 0)),
				math.clamp(dOrigin.Y.Offset + d.Y, 0, math.max(s.Y - H, 0))
			)
		end))
		table.insert(connections, UserInputService.InputEnded:Connect(function(input)
			if isPtr(input) then dragging = false end
		end))

		closeB.MouseButton1Click:Connect(function() sub:Close() end)
		if opts.Closable == false then closeB.Visible = false end

		table.insert(popupWins, sub)
		return sub
	end

	-- ==================== Notify ====================
	local MAX_TOASTS = 4

	local toastHolder = mk("Frame", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.new(0, 210, 1, -20), BackgroundTransparency = 1, ZIndex = 60,
	}, topLayer)
	mk("UIListLayout", {
		Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
	}, toastHolder)

	local toastOrder = 0
	local aliveToasts = {}

	notify = function(a, b, c, d)
		local o
		if type(a) == "table" then
			o = a
		else
			o = {Title = a, Text = b, Duration = c, Kind = d}
		end
		local dur = o.Duration
		if dur == nil then dur = defaultDuration end
		local color = o.Color or ({
			success = GREEN, warn = Color3.fromRGB(255, 190, 60), error = RED,
		})[o.Kind or "info"] or accent
		local btns = o.Buttons
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

		label(t, o.Title or "", {
			LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 16), TextColor3 = color, FontFace = FONT_BOLD, TextSize = 14,
		})
		if o.Text and o.Text ~= "" then
			local msg = label(t, o.Text, {
				LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 14), AutomaticSize = Enum.AutomaticSize.Y,
				TextWrapped = true, TextColor3 = GRAY, TextSize = 12, TextYAlignment = Enum.TextYAlignment.Top,
			})
			msg.TextTruncate = Enum.TextTruncate.None
		end

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

		if btns and #btns > 0 then
			local row = mk("Frame", {LayoutOrder = 3, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20)}, t)
			mk("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4),
				SortOrder = Enum.SortOrder.LayoutOrder, HorizontalFlex = Enum.UIFlexAlignment.Fill,
			}, row)
			for i, b2 in ipairs(btns) do
				local base = b2.Color and 0.5 or ROW_BASE
				local bt = mk("TextButton", {
					LayoutOrder = i, Text = b2.Text or "OK", TextSize = 12,
					BackgroundColor3 = b2.Color or WHITE, BackgroundTransparency = base,
					Size = UDim2.new(0, 40, 1, 0),
				}, row)
				addButtonFx(bt, function() return base end, 12)
				bt.MouseButton1Click:Connect(function()
					call("Notify button", b2.Callback)
					if not b2.Keep then obj.Dismiss() end
				end)
			end
		else
			t.InputBegan:Connect(function(input)
				if isPtr(input) then obj.Dismiss() end
			end)
		end

		if dur > 0 then
			local bar = mk("Frame", {
				LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = color, BackgroundTransparency = 0.2,
			}, t)
			tw(bar, "timer", TweenInfo.new(dur, Enum.EasingStyle.Linear), {Size = UDim2.new(0, 0, 0, 2)})
			task.delay(dur, obj.Dismiss)
		end

		table.insert(aliveToasts, obj)
		if #aliveToasts > MAX_TOASTS then aliveToasts[1].Dismiss() end

		tw(t, "fade", OPEN_TWEEN, {GroupTransparency = 0, Position = UDim2.new(0, 0, 0, 0)})
		return obj
	end

	-- ==================== Dialog / Confirm / Prompt ====================
	local currentDialog

	dialog = function(opts)
		opts = opts or {}
		if currentDialog then currentDialog.close(true) end

		local d = {}
		currentDialog = d

		local dim = mk("TextButton", {
			BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1), ZIndex = 70,
		}, topLayer)

		local card = mk("CanvasGroup", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 10),
			Size = UDim2.new(0, 230, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Color3.fromRGB(42, 42, 42), GroupTransparency = 1, Active = true,
		}, dim)
		mk("UIStroke", {Color = WHITE, Thickness = 1, Transparency = 0.85}, card)
		mk("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, card)
		mk("UIPadding", {
			PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8),
			PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
		}, card)

		label(card, opts.title or "", {LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 16), FontFace = FONT_BOLD, TextSize = 14})

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
				call("Dialog " .. tostring(b.text), b.callback, text)
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

	confirm = function(titleText, text, onYes, onNo)
		return dialog({
			title = titleText, text = text,
			buttons = {
				{text = "Cancel", callback = onNo},
				{text = "Confirm", primary = true, callback = onYes},
			},
		})
	end

	prompt = function(titleText, text, placeholder, onSubmit)
		return dialog({
			title = titleText, text = text, input = placeholder or "",
			buttons = {
				{text = "Cancel"},
				{text = "OK", primary = true, callback = onSubmit},
			},
		})
	end

	-- ==================== collapse/expand ====================
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
		closeAllPopups()

		if collapsed then
			play(body, FADE_TWEEN_OUT, {GroupTransparency = 1})
			play(collapse, ARROW_TWEEN, {Rotation = -90})
			local t = play(collapseAlpha, SIZE_TWEEN_OUT, {Value = 0})
			t.Completed:Connect(function(state2)
				if state2 == Enum.PlaybackState.Completed and collapsed then
					body.Visible = false
				end
			end)
		else
			body.Visible = true
			play(body, FADE_TWEEN_IN, {GroupTransparency = 0})
			play(collapse, ARROW_TWEEN, {Rotation = 0})
			play(collapseAlpha, SIZE_TWEEN_OUT, {Value = 1})
			playTabsIn()
			if currentTab then playReveal(currentTab) end
		end
	end

	collapse.MouseButton1Click:Connect(function() setCollapsed(not collapsed) end)

	-- ==================== Window mode + edge snapping (cake stacking) + resizing ====================
	local MODE_TWEEN = TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	local SNAP_TWEEN = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

	-- dark overlay when edge-snapped (click to return) + window name label in the visible portion
	local snapDim = mk("TextButton", {
		Name = "snapDim", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1), ZIndex = 60, Visible = false,
	}, main)
	local snapLabel = mk("TextLabel", {
		Text = NAME, TextSize = 10, BackgroundTransparency = 1, ZIndex = 61,
		TextTruncate = Enum.TextTruncate.AtEnd, TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(0.3, 0, 0, 13),
	}, snapDim)

	local function layoutSnapLabel(edge)
		if edge == "left" then
			snapLabel.AnchorPoint, snapLabel.Position, snapLabel.Size = Vector2.new(1, 0), UDim2.fromScale(1, 0), UDim2.new(0.3, 0, 0, 13)
		elseif edge == "right" then
			snapLabel.AnchorPoint, snapLabel.Position, snapLabel.Size = Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.new(0.3, 0, 0, 13)
		elseif edge == "top" then
			snapLabel.AnchorPoint, snapLabel.Position, snapLabel.Size = Vector2.new(0, 1), UDim2.fromScale(0, 1), UDim2.new(1, 0, 0, 13)
		else
			snapLabel.AnchorPoint, snapLabel.Position, snapLabel.Size = Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.new(1, 0, 0, 13)
		end
	end

	local function unsnap()
		if not snapped then return end
		snapped = false
		local s = screenGui.AbsoluteSize
		if snapEdge == "left" then winX = MARGIN
		elseif snapEdge == "right" then winX = s.X - winW - MARGIN
		elseif snapEdge == "top" then winY = MARGIN
		elseif snapEdge == "bottom" then winY = s.Y - winH - MARGIN end
		snapEdge = nil
		-- leave the cake stack and restore the previous minimized state
		if inPile then
			pileLeave(ctrl)
			inPile = false
			if stackedCollapse then
				stackedCollapse = false
				setCollapsed(false)
			end
		end
		tw(snapScale, "s", SNAP_TWEEN, {Value = 1})
		local t = tw(snapDim, "bg", FX_TWEEN, {BackgroundTransparency = 1})
		t.Completed:Connect(function() if not snapped then snapDim.Visible = false end end)
	end

	local function snapTo(edge)
		closeAllPopups()
		if stackEnabled then
			-- join this edge's cake stack (includes all 2.1+ family windows, up to Hub.MAX_STACK layers)
			if not pileJoin(ctrl, edge, Vector2.new(winX, winY)) then
				notify("Stack full", "This edge stack is full (maximum " .. Hub.MAX_STACK .. "  layers)", 2.5, "warn")
				return
			end
			inPile = true
			stackedCollapse = not collapsed
			if stackedCollapse then setCollapsed(true) end -- collapse to the title bar as a thin layer
		end
		snapped, snapEdge = true, edge
		layoutSnapLabel(edge)
		tw(snapScale, "s", SNAP_TWEEN, {Value = SNAP_SCALE})
		snapDim.Visible = true
		tw(snapDim, "bg", SNAP_TWEEN, {BackgroundTransparency = 0.5})
	end

	snapDim.MouseButton1Click:Connect(unsnap)

	local function setMode(m)
		if m == mode then return end
		closeAllPopups()
		unsnap()
		mode = m
		if m == "window" and not winInit then
			winInit = true
			local s = screenGui.AbsoluteSize
			winW = math.min(260, math.max(s.X - 20, MIN_W))
			winH = math.min(300, math.max(s.Y - 20, MIN_H))
			winX, winY = (s.X - winW) / 2, (s.Y - winH) / 2
			winCX, winCY = winX, winY
		end
		modeBtn.Text = (m == "window") and ICON_WINDOW or ICON_DOCK
		tw(blend, "b", MODE_TWEEN, {Value = m == "window" and 1 or 0})
	end

	modeBtn.MouseButton1Click:Connect(function()
		setMode(mode == "dock" and "window" or "dock")
	end)

	local corners = {
		{ax = 0, ay = 0, sx = -1, sy = -1, size = 14},
		{ax = 1, ay = 0, sx = 1,  sy = -1, size = 7},
		{ax = 0, ay = 1, sx = -1, sy = 1,  size = 14},
		{ax = 1, ay = 1, sx = 1,  sy = 1,  size = 14},
	}
	local resizing, rsStart, rsX, rsY, rsW, rsH
	for _, c in ipairs(corners) do
		c.gui = mk("TextButton", {
			AnchorPoint = Vector2.new(c.ax, c.ay), Position = UDim2.fromScale(c.ax, c.ay),
			Size = UDim2.fromOffset(c.size, c.size), BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.8, ZIndex = 40, Visible = false,
		}, main)
		c.gui.InputBegan:Connect(function(input)
			if isPtr(input) and not snapped then
				resizing = c
				rsStart = input.Position
				rsX, rsY, rsW, rsH = winX, winY, winW, winH
				closeAllPopups()
			end
		end)
	end

	local dragging = false
	local dragStart = Vector3.zero
	local sDockX, sWinX, sWinY = 0, 0, 0

	Title.InputBegan:Connect(function(input)
		if not isPtr(input) or snapped then return end
		dragging = true
		dragStart = input.Position
		sDockX, sWinX, sWinY = dockTX, winX, winY
		closeAllPopups()
	end)

	table.insert(connections, UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseMovement
			and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local s = screenGui.AbsoluteSize

		if resizing then
			local d = input.Position - rsStart
			local nw, nh, nx, ny = rsW, rsH, rsX, rsY
			if resizing.sx == 1 then
				nw = math.clamp(rsW + d.X, MIN_W, math.max(s.X - rsX, MIN_W))
			else
				nw = math.clamp(rsW - d.X, MIN_W, math.max(rsX + rsW, MIN_W))
				nx = rsX + rsW - nw
			end
			if resizing.sy == 1 then
				nh = math.clamp(rsH + d.Y, MIN_H, math.max(s.Y - rsY, MIN_H))
			else
				nh = math.clamp(rsH - d.Y, MIN_H, math.max(rsY + rsH, MIN_H))
				ny = rsY + rsH - nh
			end
			winW, winH, winX, winY = nw, nh, nx, ny
			winCX, winCY = nx, ny
		elseif dragging then
			local d = input.Position - dragStart
			if mode == "dock" then
				dockTX = math.clamp(sDockX + d.X, math.min(-(s.X - WIDTH), -RIGHT), -RIGHT)
			else
				winX = math.clamp(sWinX + d.X, 0, math.max(s.X - winW, 0))
				winY = math.clamp(sWinY + d.Y, 0, math.max(s.Y - winH, 0))
			end
		end
	end))

	table.insert(connections, UserInputService.InputEnded:Connect(function(input)
		if not isPtr(input) then return end
		resizing = nil
		if dragging then
			dragging = false
			if mode == "window" and not snapped and blend.Value > 0.9 then
				local s = screenGui.AbsoluteSize
				if winX <= EDGE then snapTo("left")
				elseif winX + winW >= s.X - EDGE then snapTo("right")
				elseif winY <= EDGE then snapTo("top")
				elseif winY + winH >= s.Y - EDGE then snapTo("bottom") end
			end
		end
	end))

	-- ---------- main loop ----------
	local lastBody
	local function approach(cur, tgt, dt)
		if math.abs(tgt - cur) < 0.05 then return tgt end
		return cur + (tgt - cur) * (1 - math.exp(-SMOOTHNESS * dt))
	end

	table.insert(connections, RunService.RenderStepped:Connect(function(dt)
		local s = screenGui.AbsoluteSize
		local b, ca = blend.Value, collapseAlpha.Value

		local winBody = winH - TITLE_HEIGHT
		local bodyH = lerp(DOCK_BODY, winBody, b)
		local W = lerp(WIDTH, winW, b)
		local Hd = TITLE_HEIGHT + DOCK_BODY * ca
		local Hw = TITLE_HEIGHT + winBody * ca
		local H = lerp(Hd, Hw, b)

		dockTX = math.clamp(dockTX, math.min(-(s.X - WIDTH), -RIGHT), -RIGHT)
		dockCX = approach(dockCX, dockTX, dt)

		local tx, ty
		if snapped then
			local lh = TITLE_HEIGHT * SNAP_SCALE
			local sw = winW * SNAP_SCALE
			local sh = inPile and lh or Hw * SNAP_SCALE
			local idx, n, ax, ay = 1, 1, winX, winY
			local pile = Hub.piles[snapEdge]
			if inPile and pile then
				idx = table.find(pile.list, ctrl) or 1
				n = #pile.list
				if pile.anchor then ax, ay = pile.anchor.X, pile.anchor.Y end
			end
			local step = lh + 3
			local peekY = inPile and math.max(lh * SNAP_PEEK, 12) or sh * SNAP_PEEK

			if snapEdge == "left" or snapEdge == "right" then
				tx = (snapEdge == "left") and (-sw * (1 - SNAP_PEEK)) or (s.X - sw * SNAP_PEEK)
				if inPile then
					-- cake layers stack upward from the stack origin
					local lo = (n - 1) * step
					local base = math.clamp(ay, lo, math.max(s.Y - lh, lo))
					ty = base - (idx - 1) * step
				else
					ty = math.clamp(winY, 0, math.max(s.Y - sh, 0))
				end
			elseif snapEdge == "top" then
				tx = math.clamp(inPile and ax or winX, 0, math.max(s.X - sw, 0))
				ty = -sh + peekY + (idx - 1) * step -- stack hangs down from the top edge
			else
				tx = math.clamp(inPile and ax or winX, 0, math.max(s.X - sw, 0))
				ty = s.Y - peekY - (idx - 1) * step -- stack rises upward from the bottom edge
			end
		else
			winX = math.clamp(winX, 0, math.max(s.X - winW, 0))
			winY = math.clamp(winY, 0, math.max(s.Y - winH, 0))
			tx, ty = winX, winY
		end
		winCX = approach(winCX, tx, dt)
		winCY = approach(winCY, ty, dt)

		local dockX = s.X + dockCX - WIDTH
		local dockY = s.Y - Hd - BOTTOM
		main.Position = UDim2.fromOffset(lerp(dockX, winCX, b), lerp(dockY, winCY, b) + slideY.Value)
		main.Size = UDim2.fromOffset(W, H)
		uiScale.Scale = snapScale.Value

		if lastBody ~= bodyH then
			lastBody = bodyH
			body.Size = UDim2.new(1, 0, 0, bodyH)
			pages.Size = UDim2.new(1, 0, 0, bodyH - TAB_HEIGHT)
		end

		local showGrips = b > 0.98 and ca > 0.98 and not snapped
		for _, c in ipairs(corners) do
			if c.gui.Visible ~= showGrips then c.gui.Visible = showGrips end
		end
	end))

	-- ==================== hide/show (Hotkey) and Kill ====================
	local shown, closing = true, false
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
			closeBodyPopups()
			for _, p in ipairs(popupWins) do p:Close(true) end
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
		call("OnKill", config.OnKill)
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

	-- ==================== main Settings page (inside the library only) ====================
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
		s:Toggle("Stack on edge (max " .. Hub.MAX_STACK .. ")", stackEnabled, function(v) stackEnabled = v end)
		s:Divider()
		s:Button("Kill UI", function()
			confirm("Kill UI?", "close and remove this entire UI", kill)
		end, RED)
		s:Label(NAME .. " • Tomato UI Library v" .. Library.Version)
	end

	-- ==================== Intro ====================
	collapsed = true
	body.Visible = false
	body.GroupTransparency = 1
	collapse.Rotation = -90
	slideY.Value = 40

	popIn(title, 0.15)
	popIn(modeBtn, 0.20)
	popIn(setting, 0.25)
	popIn(collapse, 0.30)

	local INTRO = TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	tw(main, "vis", INTRO, {GroupTransparency = 0})
	tw(slideY, "slide", INTRO, {Value = 0})

	task.delay(0.5, function()
		if not closing then setCollapsed(false) end
	end)

	-- tell other family windows that a new window exists
	task.defer(hubDeliver, NAME, nil, "WindowAdded", NAME)

	-- ==================== Window API ====================
	local Window = {}

	function Window:AddPage(name, icon)
		return makePage(tostring(name), true, icon).ui
	end
	function Window:Notify(a, b, c, d) return notify(a, b, c, d) end
	function Window:Dialog(opts) return dialog(opts) end
	function Window:Confirm(t, text, onYes, onNo) return confirm(t, text, onYes, onNo) end
	function Window:Prompt(t, text, ph, onSubmit) return prompt(t, text, ph, onSubmit) end
	function Window:Popup(opts) return makeBodyPopup(opts) end
	function Window:PopupWindow(opts) return makePopupWindow(opts) end
	function Window:Log(msg) logError("Log", msg) end

	-- ---------- cross-window communication (2.1+ family windows only) ----------
	-- receive messages: Window:On("topic", function(from, ...) end)  disconnect: conn:Disconnect()
	function Window:On(topic, fn)
		ctrl.handlers[topic] = ctrl.handlers[topic] or {}
		table.insert(ctrl.handlers[topic], fn)
		return {Disconnect = function()
			local t = ctrl.handlers[topic]
			local i = t and table.find(t, fn)
			if i then table.remove(t, i) end
		end}
	end
	function Window:Send(target, topic, ...) hubDeliver(NAME, target, topic, ...) end
	function Window:Broadcast(topic, ...) hubDeliver(NAME, nil, topic, ...) end
	-- expose a function for other windows to call: Window:Expose("name", function(from, ...) return ... end)
	function Window:Expose(name, fn) ctrl.exposed[name] = fn end
	-- call another window function: local ok, result = Window:Invoke("window name", "name", ...)
	function Window:Invoke(target, name, ...) return hubInvoke(NAME, target, name, ...) end
	function Window:List()
		local t = {}
		for name in pairs(Hub.windows) do
			if name ~= NAME then table.insert(t, name) end
		end
		table.sort(t)
		return t
	end
	-- values shared by all windows
	function Window:SetShared(key, value) hubSetShared(NAME, key, value) end
	function Window:GetShared(key) return Hub.shared[key] end
	function Window:OnShared(key, fn)
		ctrl.sharedHandlers[key] = ctrl.sharedHandlers[key] or {}
		table.insert(ctrl.sharedHandlers[key], fn)
		return {Disconnect = function()
			local t = ctrl.sharedHandlers[key]
			local i = t and table.find(t, fn)
			if i then table.remove(t, i) end
		end}
	end

	return Window
end

-- empty object that safely ignores any method call (used when CreateWindow fails)
local function dummy()
	local d = {}
	return setmetatable(d, {__index = function() return function() return d end end})
end

function Library:CreateWindow(config)
	local ok, res = xpcall(createWindow, errHandler, config)
	if ok then return res end
	logError("CreateWindow", res)
	return dummy()
end

return Library
