--[[
    ██╗   ██╗███╗   ██╗██╗██╗   ██╗███████╗██████╗ ███████╗ █████╗ ██╗
    ██║   ██║████╗  ██║██║██║   ██║██╔════╝██╔══██╗██╔════╝██╔══██╗██║
    ██║   ██║██╔██╗ ██║██║██║   ██║█████╗  ██████╔╝███████╗███████║██║
    ██║   ██║██║╚██╗██║██║╚██╗ ██╔╝██╔══╝  ██╔══██╗╚════██║██╔══██║██║
    ╚██████╔╝██║ ╚████║██║ ╚████╔╝ ███████╗██║  ██║███████║██║  ██║███████╗
     ╚═════╝ ╚═╝  ╚═══╝╚═╝  ╚═══╝  ╚══════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚══════╝

    UNIVERSAL SCRIPT  —  LUCK + UTILITY ALL-IN-ONE

    Every feature. Every executor. One file.
    Supports: Synapse X, Script-Ware, Krnl, Fluxus, Solara, Delta,
              Arceus X, Codex, Wave, Swift, Evon, Xenon, Hydrogen,
              SirHurt, Trigon Evo, Electron, Nihon, Rogue, and any
              executor with loadstring + standard API support.
--]]

-- =============================================================
-- SERVICES
-- =============================================================
local Players             = game:GetService("Players")
local RunService          = game:GetService("RunService")
local UserInputService    = game:GetService("UserInputService")
local Lighting            = game:GetService("Lighting")
local TeleportService     = game:GetService("TeleportService")
local HttpService         = game:GetService("HttpService")
local StarterGui          = game:GetService("StarterGui")
local Workspace           = game:GetService("Workspace")
local VirtualUser         = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer
local Mouse       = LocalPlayer:GetMouse()

-- =============================================================
-- STATE
-- =============================================================
local State = {
    Walkspeed    = 16,
    JumpPower    = 50,
    HipHeight    = 2,
    InfiniteJump = false,
    Fly          = false,
    FlySpeed     = 100,
    Noclip       = false,
    Fullbright   = false,
    ESP          = false,
    AutoClick       = false,
    AutoClickRate   = 0.05,
    AutoRoll        = false,
    AutoRollDelay   = 0.5,
    LuckEnabled  = true,
    LuckFactor   = 0.85,
    LogRemotes   = true,
    RollPatterns = {
        "hatch","roll","egg","open","spin","gacha","summon","crate",
        "mystery","draw","pull","loot","reward","chest","case",
        "capsule","fortune","luck","rng"
    },
}

local ESPObjects = {}
local FlyBodyVel, FlyBodyGyro
local origMathRandom = math.random
local luckHits = 0

-- =============================================================
-- HELPERS
-- =============================================================
local function notify(title, text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title or "Script",
            Text  = text or "",
            Duration = 4,
        })
    end)
end

local function log(...) print("[Script] ", ...) end
local function getChar() return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait() end

local function getHRP()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart") or nil
end

local function getHum()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid") or nil
end

local function matchRoll(name)
    if type(name) ~= "string" then return false end
    local lower = string.lower(name)
    for _, pat in ipairs(State.RollPatterns) do
        if string.find(lower, pat, 1, true) then return true, pat end
    end
    return false
end

-- =============================================================
-- LUCK ENGINE
-- =============================================================
math.random = function(a, b, c)
    if not State.LuckEnabled or State.LuckFactor <= 0 then
        return origMathRandom(a, b, c)
    end
    if a == nil then
        return origMathRandom()
    elseif b == nil then
        local r = origMathRandom(a)
        local biased = math.floor(r * (1 - State.LuckFactor) + a * State.LuckFactor + 0.5)
        luckHits += 1
        return math.clamp(biased, 1, a)
    else
        local r = origMathRandom(a, b)
        local biased = math.floor(r * (1 - State.LuckFactor) + b * State.LuckFactor + 0.5)
        luckHits += 1
        return math.clamp(biased, a, b)
    end
end
log("math.random hooked")

local RandomMT = getmetatable(Random.new()) or {}
if RandomMT and RandomMT.__index then
    local origNextNumber  = RandomMT.__index.NextNumber
    local origNextInteger = RandomMT.__index.NextInteger

    if origNextNumber then
        RandomMT.__index.NextNumber = function(self, a, b)
            local r = origNextNumber(self, a, b)
            if State.LuckEnabled and State.LuckFactor > 0 and b then
                luckHits += 1
                return r * (1 - State.LuckFactor) + b * State.LuckFactor
            end
            return r
        end
    end
    if origNextInteger then
        RandomMT.__index.NextInteger = function(self, a, b)
            local r = origNextInteger(self, a, b)
            if State.LuckEnabled and State.LuckFactor > 0 and b then
                local biased = math.floor(r * (1 - State.LuckFactor) + b * State.LuckFactor + 0.5)
                luckHits += 1
                return math.clamp(biased, a, b)
            end
            return r
        end
    end
    log("Random.new hooked")
end

local _oldInstanceNew = Instance.new
Instance.new = function(class, parent)
    local obj = _oldInstanceNew(class, parent)
    if class == "RemoteEvent" then
        local orig = obj.FireServer
        obj.FireServer = function(self, ...)
            local isRoll, pat = matchRoll(self.Name)
            if isRoll and State.LogRemotes then log("RemoteEvent:", self.Name, "(matched:", pat..")") end
            return orig(self, ...)
        end
    elseif class == "RemoteFunction" then
        local orig = obj.InvokeServer
        obj.InvokeServer = function(self, ...)
            local isRoll, pat = matchRoll(self.Name)
            local result = orig(self, ...)
            if isRoll and State.LogRemotes then
                log("RemoteFunction:", self.Name, "(matched:", pat..") ->", tostring(result))
            end
            if isRoll and State.LuckEnabled and State.LuckFactor > 0 and type(result) == "number" then
                local maxed = math.floor(result + (1000 - result) * State.LuckFactor)
                luckHits += 1
                return maxed
            end
            return result
        end
    end
    return obj
end
log("Remote hook installed")

task.spawn(function()
    task.wait(2)
    local scanned = 0
    for _, d in ipairs(game:GetDescendants()) do
        if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
            scanned += 1
            local isRoll, pat = matchRoll(d.Name)
            if isRoll then log("Found roll remote:", d.Name, "(matched:", pat..")") end
        end
    end
    log("Scanned", scanned, "remotes")
    for _, t in ipairs({_G, shared}) do
        if type(t) == "table" then
            for k, v in pairs(t) do
                if type(k) == "string" and matchRoll(k) and type(v) == "number" then
                    log("Found luck var:", k, "=", v)
                    pcall(function() t[k] = v * (1 + State.LuckFactor * 100) end)
                end
            end
        end
    end
end)

-- =============================================================
-- CHARACTER SETTINGS
-- =============================================================
local function applyCharSettings()
    local hum = getHum()
    if not hum then return end
    pcall(function() hum.WalkSpeed = State.Walkspeed end)
    pcall(function() hum.JumpPower = State.JumpPower end)
    pcall(function() hum.UseJumpPower = true end)
    pcall(function() hum.HipHeight = State.HipHeight end)
end

function applyFullbright(on)
    pcall(function()
        if on then
            Lighting.Brightness     = 3
            Lighting.ClockTime      = 14
            Lighting.FogEnd         = 100000
            Lighting.GlobalShadows  = false
            Lighting.Ambient        = Color3.fromRGB(178,178,178)
            Lighting.OutdoorAmbient = Color3.fromRGB(178,178,178)
        else
            Lighting.Brightness     = 2
            Lighting.ClockTime      = 14
            Lighting.FogEnd         = 100000
            Lighting.GlobalShadows  = true
            Lighting.Ambient        = Color3.fromRGB(70,70,70)
            Lighting.OutdoorAmbient = Color3.fromRGB(128,128,128)
        end
    end)
end

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    applyCharSettings()
    if State.Fullbright then applyFullbright(true) end
end)

-- =============================================================
-- INFINITE JUMP
-- =============================================================
UserInputService.JumpRequest:Connect(function()
    if not State.InfiniteJump then return end
    local hum = getHum()
    if hum then pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end) end
end)

-- =============================================================
-- NOCLIP
-- =============================================================
RunService.Stepped:Connect(function()
    if not State.Noclip then return end
    local char = LocalPlayer.Character
    if not char then return end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") and p.CanCollide then
            pcall(function() p.CanCollide = false end)
        end
    end
end)

-- =============================================================
-- FLY
-- =============================================================
local function startFly()
    local hrp = getHRP()
    if not hrp then return end
    local hum = getHum()
    if hum then hum.PlatformStand = true end

    FlyBodyVel = Instance.new("BodyVelocity")
    FlyBodyVel.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    FlyBodyVel.Velocity = Vector3.zero
    FlyBodyVel.Parent   = hrp

    FlyBodyGyro = Instance.new("BodyGyro")
    FlyBodyGyro.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
    FlyBodyGyro.P = 1000
    FlyBodyGyro.D = 50
    FlyBodyGyro.CFrame = hrp.CFrame
    FlyBodyGyro.Parent = hrp
end

local function stopFly()
    if FlyBodyVel  then FlyBodyVel:Destroy()  FlyBodyVel = nil  end
    if FlyBodyGyro then FlyBodyGyro:Destroy() FlyBodyGyro = nil end
    local hum = getHum()
    if hum then hum.PlatformStand = false end
end

RunService.RenderStepped:Connect(function()
    if not State.Fly then return end
    local hrp = getHRP()
    if not hrp then return end
    local cam = Workspace.CurrentCamera
    local dir = Vector3.zero
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += cam.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= cam.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= cam.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += cam.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0,1,0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.new(0,1,0) end
    if dir.Magnitude > 0 then dir = dir.Unit end
    if FlyBodyVel  then FlyBodyVel.Velocity = dir * State.FlySpeed end
    if FlyBodyGyro then FlyBodyGyro.CFrame = cam.CFrame end
end)

-- =============================================================
-- ESP
-- =============================================================
local function createESP(plr)
    if plr == LocalPlayer or ESPObjects[plr] then return end
    if not plr.Character then return end
    local hl = Instance.new("Highlight")
    hl.Name = "PlayerESP"
    hl.FillColor = Color3.fromRGB(255, 170, 0)
    hl.OutlineColor = Color3.fromRGB(255,255,255)
    hl.FillTransparency = 0.6
    hl.OutlineTransparency = 0
    hl.Adornee = plr.Character
    hl.Parent = plr.Character
    ESPObjects[plr] = hl
end

local function removeESP(plr)
    if ESPObjects[plr] then
        pcall(function() ESPObjects[plr]:Destroy() end)
        ESPObjects[plr] = nil
    end
end

local function refreshESP()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            if State.ESP then createESP(plr) else removeESP(plr) end
        end
    end
end

Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function() if State.ESP then createESP(plr) end end)
end)
Players.PlayerRemoving:Connect(removeESP)

-- =============================================================
-- AUTO CLICK / AUTO ROLL
-- =============================================================
task.spawn(function()
    while true do
        task.wait(State.AutoClickRate)
        if State.AutoClick then
            pcall(function()
                VirtualUser:Button1Down(Vector2.new(0,0))
                VirtualUser:Button1Up(Vector2.new(0,0))
            end)
            pcall(function()
                VirtualInputManager:SendMouseButtonEvent(Mouse.X, Mouse.Y, 0, true,  game, 1)
                VirtualInputManager:SendMouseButtonEvent(Mouse.X, Mouse.Y, 0, false, game, 1)
            end)
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(State.AutoRollDelay)
        if State.AutoRoll then
            pcall(function()
                for _, d in ipairs(LocalPlayer.PlayerGui:GetDescendants()) do
                    if d:IsA("TextButton") or d:IsA("ImageButton") then
                        local n = string.lower(d.Name)
                        local t = ""
                        if d:IsA("TextButton") then t = string.lower(d.Text) end
                        local hit = false
                        for _, p in ipairs(State.RollPatterns) do
                            if string.find(n, p, 1, true) or string.find(t, p, 1, true) then
                                hit = true; break
                            end
                        end
                        if hit and d.Visible then d:Activate(); break end
                    end
                end
            end)
        end
    end
end)

-- =============================================================
-- ANTI-AFK
-- =============================================================
LocalPlayer.Idled:Connect(function()
    pcall(function()
        VirtualUser:Button2Down(Vector2.new(0,0))
        task.wait(1)
        VirtualUser:Button2Up(Vector2.new(0,0))
    end)
end)

-- =============================================================
-- SERVER HOP / REJOIN
-- =============================================================
local function serverHop()
    local url = "https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100"
    local ok, res = pcall(function() return game:HttpGet(url) end)
    if not ok or not res then notify("Server Hop", "Fetch failed.") return end
    local data = HttpService:JSONDecode(res)
    local list = {}
    for _, s in ipairs(data.data) do
        if s.playing < s.maxPlayers and s.id ~= game.JobId then table.insert(list, s.id) end
    end
    if #list > 0 then
        TeleportService:TeleportToPlaceInstance(game.PlaceId, list[math.random(1,#list)], LocalPlayer)
    else
        notify("Server Hop", "No servers found.")
    end
end

local function rejoin() TeleportService:Teleport(game.PlaceId, LocalPlayer) end

-- =============================================================
-- GUI
-- =============================================================
local function makeGUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "UniversalScript"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.IgnoreGuiInset = true
    pcall(function() if syn and syn.protect_gui then syn.protect_gui(gui) end end)
    gui.Parent = (gethui and gethui()) or game:GetService("CoreGui")

    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, 360, 0, 460)
    main.Position = UDim2.new(0.5, -180, 0.5, -230)
    main.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
    main.BorderSizePixel = 0
    main.Active = true
    main.Draggable = true
    main.Parent = gui
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 38)
    title.BackgroundColor3 = Color3.fromRGB(255, 140, 0)
    title.BorderSizePixel = 0
    title.Text = "UNIVERSAL SCRIPT  |  LUCK + UTIL"
    title.TextColor3 = Color3.fromRGB(255,255,255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.Parent = main
    Instance.new("UICorner", title).CornerRadius = UDim.new(0, 10)

    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, 0, 0, 16)
    status.Position = UDim2.new(0, 0, 0, 38)
    status.BackgroundTransparency = 1
    status.Text = "Luck hits: 0"
    status.TextColor3 = Color3.fromRGB(200,200,200)
    status.Font = Enum.Font.Code
    status.TextSize = 11
    status.Parent = main

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -10, 1, -60)
    scroll.Position = UDim2.new(0, 5, 0, 56)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 4
    scroll.CanvasSize = UDim2.new(0, 0, 0, 1100)
    scroll.Parent = main

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 6)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = scroll

    local function section(t)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -10, 0, 22)
        l.BackgroundTransparency = 1
        l.Text = "— "..t.." —"
        l.TextColor3 = Color3.fromRGB(255,170,0)
        l.Font = Enum.Font.GothamBold
        l.TextSize = 12
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Parent = scroll
    end

    local function button(text, cb)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -10, 0, 30)
        b.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
        b.BorderSizePixel = 0
        b.Text = text
        b.TextColor3 = Color3.fromRGB(235,235,235)
        b.Font = Enum.Font.Gotham
        b.TextSize = 13
        b.Parent = scroll
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
        b.MouseButton1Click:Connect(function()
            local ok, err = pcall(cb)
            if not ok then notify("Error", tostring(err)) end
        end)
    end

    local function toggle(text, key, cb)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -10, 0, 30)
        b.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
        b.BorderSizePixel = 0
        b.Text = text..": OFF"
        b.TextColor3 = Color3.fromRGB(235,235,235)
        b.Font = Enum.Font.Gotham
        b.TextSize = 13
        b.Parent = scroll
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
        b.MouseButton1Click:Connect(function()
            State[key] = not State[key]
            b.Text = text..": "..(State[key] and "ON" or "OFF")
            b.BackgroundColor3 = State[key] and Color3.fromRGB(60,130,60) or Color3.fromRGB(40,40,48)
            if cb then pcall(cb, State[key]) end
        end)
    end

    local function slider(text, min, max, default, cb)
        local f = Instance.new("Frame")
        f.Size = UDim2.new(1, -10, 0, 46)
        f.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
        f.BorderSizePixel = 0
        f.Parent = scroll
        Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -10, 0, 20)
        lbl.Position = UDim2.new(0, 5, 0, 2)
        lbl.BackgroundTransparency = 1
        lbl.Text = text..": "..tostring(default)
        lbl.TextColor3 = Color3.fromRGB(235,235,235)
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 12
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = f

        local bar = Instance.new("TextButton")
        bar.Size = UDim2.new(1, -20, 0, 6)
        bar.Position = UDim2.new(0, 10, 0, 32)
        bar.BackgroundColor3 = Color3.fromRGB(70,70,80)
        bar.BorderSizePixel = 0
        bar.Text = ""
        bar.Parent = f
        Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

        local fill = Instance.new("Frame")
        fill.Size = UDim2.new((default-min)/(max-min), 0, 1, 0)
        fill.BackgroundColor3 = Color3.fromRGB(255, 140, 0)
        fill.BorderSizePixel = 0
        fill.Parent = bar
        Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

        local drag = false
        local function upd(x)
            local rel = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
            local v = min + (max-min) * rel
            if max > 5 then v = math.floor(v + 0.5)
            else v = math.floor(v * 100 + 0.5) / 100 end
            fill.Size = UDim2.new(rel, 0, 1, 0)
            lbl.Text = text..": "..tostring(v)
            cb(v)
        end
        bar.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                drag = true; upd(i.Position.X)
            end
        end)
        bar.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                drag = false
            end
        end)
        UserInputService.InputChanged:Connect(function(i)
            if drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                upd(i.Position.X)
            end
        end)
    end

    section("LUCK")
    toggle("Luck Engine", "LuckEnabled")
    slider("Luck Factor", 0, 1, State.LuckFactor, function(v) State.LuckFactor = v end)
    button("Set Luck 0.85 (safe strong)",  function() State.LuckFactor = 0.85; notify("Luck", "0.85") end)
    button("Set Luck 0.95 (aggressive)",   function() State.LuckFactor = 0.95; notify("Luck", "0.95") end)
    button("Set Luck 1.00 (always max)",   function() State.LuckFactor = 1.00; notify("Luck", "1.00") end)
    toggle("Log Roll Remotes", "LogRemotes")

    section("Movement")
    slider("Walkspeed", 8, 500, State.Walkspeed, function(v) State.Walkspeed = v; applyCharSettings() end)
    slider("JumpPower", 50, 500, State.JumpPower, function(v) State.JumpPower = v; applyCharSettings() end)
    slider("HipHeight", 0, 20, State.HipHeight, function(v) State.HipHeight = v; applyCharSettings() end)
    slider("Fly Speed", 10, 500, State.FlySpeed, function(v) State.FlySpeed = v end)
    toggle("Infinite Jump", "InfiniteJump")
    toggle("Noclip", "Noclip")
    toggle("Fly", "Fly", function(on) if on then startFly() else stopFly() end end)

    section("Visual")
    toggle("Fullbright", "Fullbright", applyFullbright)
    toggle("ESP Players", "ESP", refreshESP)

    section("Automation")
    toggle("Auto Click", "AutoClick")
    slider("Auto Click Rate (s)", 0.01, 0.5, State.AutoClickRate, function(v) State.AutoClickRate = v end)
    toggle("Auto Roll / Auto Hatch", "AutoRoll")
    slider("Auto Roll Delay (s)", 0.1, 5, State.AutoRollDelay, function(v) State.AutoRollDelay = v end)

    section("Utility")
    button("Reset Character",  function() local h = getHum(); if h then h:ChangeState(Enum.HumanoidStateType.Dead) end end)
    button("Rejoin Server",    rejoin)
    button("Server Hop",       serverHop)
    button("Copy Position",    function()
        local hrp = getHRP()
        if hrp then
            if setclipboard then setclipboard(tostring(hrp.Position)) end
            notify("Position", tostring(hrp.Position))
        end
    end)

    section("Teleports")
    local function rebuildTP()
        for _, c in ipairs(scroll:GetChildren()) do
            if c:IsA("TextButton") and string.sub(c.Text, 1, 6) == "TP to " then c:Destroy() end
        end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                button("TP to "..plr.Name, function()
                    local hrp  = getHRP()
                    local thrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                    if hrp and thrp then hrp.CFrame = thrp.CFrame + Vector3.new(0, 3, 0) end
                end)
            end
        end
    end
    rebuildTP()
    Players.PlayerAdded:Connect(function() task.wait(1); rebuildTP() end)

    task.spawn(function()
        while true do
            task.wait(1)
            status.Text = "Luck hits: "..luckHits.."   |   Factor: "..State.LuckFactor
        end
    end)

    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.RightShift then
            main.Visible = not main.Visible
        end
    end)

    notify("Universal Script", "Loaded. RightShift toggles UI.")
end

-- =============================================================
-- INIT
-- =============================================================
task.wait(1)
applyCharSettings()
pcall(makeGUI)
notify("Universal Script", "LUCK + UTIL loaded. RightShift toggles.")
log("=== READY ===")