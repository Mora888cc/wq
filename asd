--!nocheck
-- Ability Arena — combat suite | single file
-- Paste into executor, execute once. RightShift toggles the UI.

local Players   = game:GetService("Players")
local RunService= game:GetService("RunService")
local Tween     = game:GetService("TweenService")
local UIS       = game:GetService("UserInputService")
local Http      = game:GetService("HttpService")
local Lighting  = game:GetService("Lighting")
local RS        = game:GetService("ReplicatedStorage")
local WS        = game:GetService("Workspace")
local LP        = Players.LocalPlayer

-- ================= CONFIG =================
local DIR, FILE = "OJBS", "OJBS/abilityarena.json"
local DEFAULTS = {
    theme = "Crimson", animations = true, uiScale = 1, openKey = "RightShift",
    features = {}, pos = nil,
    remotes = { attack = "", block = "", parry = "", combo = "", crit = "" },
}
local function dc(t) if type(t) ~= "table" then return t end local c = {} for k,v in pairs(t) do c[k]=dc(v) end return c end
local function loadCfg()
    if type(readfile)~="function" or type(isfile)~="function" then return nil end
    if type(isfolder)=="function" and not isfolder(DIR) then makefolder(DIR) end
    if not isfile(FILE) then return nil end
    local ok,d = pcall(function() return Http:JSONDecode(readfile(FILE)) end)
    if ok and type(d)=="table" then return d end
end
local function saveCfg()
    if type(writefile)~="function" then return end
    if type(isfolder)=="function" and not isfolder(DIR) then makefolder(DIR) end
    local d = { theme=C.theme, animations=C.animations, uiScale=C.uiScale,
        openKey=C.openKey.Name, features=C.features, pos=C.pos, remotes=C.remotes }
    local ok,enc = pcall(function() return Http:JSONEncode(d) end)
    if ok then writefile(FILE, enc) end
end
local saved = loadCfg()
local C = dc(DEFAULTS)
if saved then
    for k,v in pairs(saved) do if k ~= "openKey" then C[k] = v end end
    if type(saved.openKey)=="string" then
        local ok,k = pcall(function() return Enum.KeyCode[saved.openKey] end)
        if ok then C.openKey = k end
    end
end

-- ================= THEMES =================
local Themes = {
    Crimson = { bg=Color3.fromRGB(16,14,20), panel=Color3.fromRGB(24,20,30), light=Color3.fromRGB(34,28,42), accent=Color3.fromRGB(220,40,60), accent2=Color3.fromRGB(255,90,110), text=Color3.fromRGB(240,238,245), dim=Color3.fromRGB(160,152,170), stroke=Color3.fromRGB(48,40,58), off=Color3.fromRGB(50,44,62) },
    Ocean   = { bg=Color3.fromRGB(10,16,24), panel=Color3.fromRGB(16,24,34), light=Color3.fromRGB(24,36,50), accent=Color3.fromRGB(40,160,220), accent2=Color3.fromRGB(90,200,245), text=Color3.fromRGB(235,242,248), dim=Color3.fromRGB(140,160,180), stroke=Color3.fromRGB(30,44,60), off=Color3.fromRGB(36,50,68) },
    Emerald = { bg=Color3.fromRGB(12,20,16), panel=Color3.fromRGB(18,30,24), light=Color3.fromRGB(26,44,34), accent=Color3.fromRGB(40,200,120), accent2=Color3.fromRGB(90,235,160), text=Color3.fromRGB(236,246,240), dim=Color3.fromRGB(145,165,152), stroke=Color3.fromRGB(32,50,40), off=Color3.fromRGB(34,52,42) },
    Amethyst= { bg=Color3.fromRGB(18,12,24), panel=Color3.fromRGB(26,18,36), light=Color3.fromRGB(36,26,50), accent=Color3.fromRGB(150,70,230), accent2=Color3.fromRGB(190,120,255), text=Color3.fromRGB(244,238,250), dim=Color3.fromRGB(160,145,175), stroke=Color3.fromRGB(46,34,62), off=Color3.fromRGB(48,36,64) },
}
local Theme = Themes[C.theme] or Themes.Crimson

-- ================= HELPERS =================
local function cam() return WS.CurrentCamera end
local function myChar()
    local c = LP.Character
    return c, c and c:FindFirstChild("HumanoidRootPart"), c and c:FindFirstChildOfClass("Humanoid")
end
local function allPlayers()
    local t = {}
    for _,p in ipairs(Players:GetPlayers()) do if p ~= LP then table.insert(t, p) end end
    return t
end
local function aliveTarget(p)
    local pc = p.Character
    if not pc then return nil end
    local hrp = pc:FindFirstChild("HumanoidRootPart")
    local hum = pc:FindFirstChildOfClass("Humanoid")
    if hrp and hum and hum.Health > 0 then return hrp, hum end
end
local function nearest(maxDist)
    local _,hrp = myChar(); if not hrp then return nil end
    local best, bd = nil, maxDist or math.huge
    for _,p in ipairs(allPlayers()) do
        local phrp = aliveTarget(p)
        if phrp then
            local d = (phrp.Position - hrp.Position).Magnitude
            if d <= bd then best, bd = p, d end
        end
    end
    return best, bd
end
local function fireRemote(name, ...)
    if name == "" or not name then return end
    local ev = RS:FindFirstChild(name, true)
    if ev and ev:IsA("RemoteEvent") then pcall(function() ev:FireServer(...) end) end
end
local function attack(targetPart)
    local char = LP.Character
    if not char then return end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then
        local rem = tool:FindFirstChildWhichIsA("RemoteEvent", true) or tool:FindFirstChildWhichIsA("RemoteFunction", true)
        if rem and rem:IsA("RemoteEvent") then pcall(function() rem:FireServer(targetPart) end) end
        if tool.Enabled then pcall(function() tool:Activate() end) end
    end
    fireRemote(C.remotes.attack, targetPart)
end
local function notify(text)
    if not C.features["Misc.Notifications"] then return end
    if not _G.__ojbsToasts then _G.__ojbsToasts = true end
end

-- ================= REGISTRY =================
local Mods = {}
local function def(cat, name, settings, onEnable, onDisable)
    Mods[cat] = Mods[cat] or {}
    Mods[cat][name] = { enabled = false, settings = settings or {}, onEnable = onEnable, onDisable = onDisable, cat = cat, name = name }
end
local function setMod(cat, name, state)
    local m = Mods[cat] and Mods[cat][name]
    if not m or m.enabled == state then return end
    m.enabled = state
    if state and m.onEnable then pcall(m.onEnable, m) end
    if (not state) and m.onDisable then pcall(m.onDisable, m) end
    C.features[cat.."."..name] = state
end
local function disableAll()
    for _,mods in pairs(Mods) do
        for _,m in pairs(mods) do
            if m.enabled then
                m.enabled = false
                if m.onDisable then pcall(m.onDisable, m) end
                C.features[m.cat.."."..m.name] = false
            end
        end
    end
end

-- ================= FEATURES =================
-- COMBAT
def("Combat","Kill Aura",{range=14,hitDelay=0.1}, function(m)
    m._t = 0
    m._c = RunService.Heartbeat:Connect(function(dt)
        m._t += dt
        if m._t < m.settings.hitDelay then return end
        m._t = 0
        local _,hrp = myChar()
        if not hrp then return end
        for _,p in ipairs(allPlayers()) do
            local phrp = aliveTarget(p)
            if phrp and (phrp.Position - hrp.Position).Magnitude <= m.settings.range then
                attack(phrp)
            end
        end
    end)
end, function(m) if m._c then m._c:Disconnect() m._c = nil end end)

def("Combat","Aim Aura",{fov=300,smooth=0.35}, function(m)
    m._c = RunService.RenderStepped:Connect(function()
        local _,hrp = myChar()
        if not hrp or not cam() then return end
        local best = nearest(m.settings.fov)
        if best then
            local phrp = aliveTarget(best)
            if phrp then
                local goal = CFrame.lookAt(cam().CFrame.Position, phrp.Position)
                cam().CFrame = cam().CFrame:Lerp(goal, 1 - m.settings.smooth)
            end
        end
    end)
end, function(m) if m._c then m._c:Disconnect() m._c = nil end end)

def("Combat","Trigger Bot",{radius=45}, function(m)
    m._c = RunService.Heartbeat:Connect(function()
        if not cam() then return end
        local mp = UIS:GetMouseLocation()
        for _,p in ipairs(allPlayers()) do
            local phrp = aliveTarget(p)
            if phrp then
                local sp, on = cam():WorldToViewportPoint(phrp.Position)
                if on and (Vector2.new(sp.X,sp.Y) - mp).Magnitude <= m.settings.radius then
                    attack(phrp); break
                end
            end
        end
    end)
end, function(m) if m._c then m._c:Disconnect() m._c = nil end end)

def("Combat","Auto Clicker",{cps=12}, function(m)
    local acc = 0
    m._c = RunService.Heartbeat:Connect(function(dt)
        acc += dt
        if acc < 1/m.settings.cps then return end
        acc = 0
        local char = LP.Character
        if char then
            local tool = char:FindFirstChildOfClass("Tool")
            if tool and tool.Enabled then pcall(function() tool:Activate() end) end
        end
    end)
end, function(m) if m._c then m._c:Disconnect() m._c = nil end end)

def("Combat","Reach",{distance=30}, function(m)
    m._c = RunService.Heartbeat:Connect(function()
        local _,hrp = myChar(); if not hrp then return end
        local best, bd = nil, m.settings.distance
        for _,p in ipairs(allPlayers()) do
            local phrp = aliveTarget(p)
            if phrp then
                local d = (phrp.Position - hrp.Position).Magnitude
                if d <= bd then best, bd = phrp, d end
            end
        end
        if best then attack(best) end
    end)
end, function(m) if m._c then m._c:Disconnect() m._c = nil end end)

def("Combat","Hitbox Expander",{size=12}, function(m)
    m._c = RunService.Heartbeat:Connect(function()
        for _,p in ipairs(allPlayers()) do
            local phrp = aliveTarget(p)
            if phrp then
                phrp.Size = Vector3.new(m.settings.size, m.settings.size, m.settings.size)
                phrp.CanCollide = false
                phrp.Transparency = 0.65
            end
        end
    end)
end, function(m)
    if m._c then m._c:Disconnect() m._c = nil end
    for _,p in ipairs(allPlayers()) do
        local phrp = aliveTarget(p)
        if phrp then phrp.Size = Vector3.new(2,2,1) phrp.Transparency = 1 phrp.CanCollide = true end
    end
end)

def("Combat","Multi Aura",{range=18}, function(m)
    m._c = RunService.Heartbeat:Connect(function()
        local _,hrp = myChar(); if not hrp then return end
        for _,p in ipairs(allPlayers()) do
            local phrp = aliveTarget(p)
            if phrp and (phrp.Position - hrp.Position).Magnitude <= m.settings.range then attack(phrp) end
        end
    end)
end, function(m) if m._c then m._c:Disconnect() m._c = nil end end)

def("Combat","Target Strafe",{speed=14}, function(m)
    m._c = RunService.RenderStepped:Connect(function()
        local _,hrp = myChar(); if not hrp then return end
        local t = nearest(60)
        if t then
            local phrp = aliveTarget(t)
            if phrp then
                local dir = (phrp.Position - hrp.Position).Unit
                local right = Vector3.new(-dir.Z, 0, dir.X)
                hrp.AssemblyLinearVelocity = right * m.settings.speed
            end
        end
    end)
end, function(m) if m._c then m._c:Disconnect() m._c = nil end end)

def("Combat","Auto Block",{}, function(m)
    m._c = RunService.Heartbeat:Connect(function()
        local char = LP.Character; if not char then return end
        local tool = char:FindFirstChildOfClass("Tool")
        if tool then
            local b = tool:FindFirstChild("Block", true)
            if b and b:IsA("RemoteEvent") then pcall(function() b:FireServer(true) end) end
        end
        fireRemote(C.remotes.block, true)
    end)
end, function(m) if m._c then m._c:Disconnect() m._c = nil end end)

def("Combat","Auto Parry",{}, function(m)
    m._c = RunService.Heartbeat:Connect(function()
        local char = LP.Character; if not char then return end
        local tool = char:FindFirstChildOfClass("Tool")
        if tool then
            local p = tool:FindFirstChild("Parry", true)
            if p and p:IsA("RemoteEvent") then pcall(function() p:FireServer() end) end
        end
        fireRemote(C.remotes.parry)
    end)
end, function(m) if m._c then m._c:Disconnect() m._c = nil end end)

def("Combat","Auto Combo",{}, function(m)
    m._c = RunService.Heartbeat:Connect(function()
        local t = nearest(20)
        if t then attack(aliveTarget(t)) end
        fireRemote(C.remotes.combo)
    end)
end, function(m) if m._c then m._c:Disconnect() m._c = nil end end)

def("Combat","Criticals",{}, function(m)
    m._c = RunService.Heartbeat:Connect(function()
        local t = nearest(20)
        if t then
            local phrp = aliveTarget(t)
            if phrp then pcall(function() fireRemote(C.remotes.crit, phrp) end) end
        end
    end)
end, function(m) if m._c then m._c:Disconnect() m._c = nil end end)

def("Combat","Velocity",{value=60}, function(m)
    m._c = RunService.Heartbeat:Connect(function()
        local _,hrp = myChar(); if not hrp then return end
        hrp.AssemblyLinearVelocity = Vector3.new(m.settings.value, hrp.AssemblyLinearVelocity.Y, m.settings.value)
    end)
end, function(m) if m._c then m._c:Disconnect() m._c = nil end end)

def("Combat","Anti Knockback",{}, function(m)
    m._c = RunService.Heartbeat:Connect(function()
        local _,hrp = myChar(); if not hrp then return end
        if hrp.AssemblyLinearVelocity.Y > -5 then
            hrp.AssemblyLinearVelocity = Vector3.new(0, hrp.AssemblyLinearVelocity.Y, 0)
        end
    end)
end, function(m) if m._c then m._c:Disconnect() m._c = nil end end)

def("Combat","Backtrack",{amount=3}, function(m)
    m._c = RunService.RenderStepped:Connect(function()
        local _,hrp = myChar(); if not hrp then return end
        local t = nearest(60)
        if t then
            local phrp = aliveTarget(t)
            if phrp then
                local goal = CFrame.lookAt(hrp.Position, phrp.Position) * CFrame.new(0,0,m.settings.amount)
                hrp.CFrame = hrp.CFrame:Lerp(goal, 0.25)
            end
        end
    end)
end, function(m) if m._c then m._c:Disconnect() m._c = nil end end)

-- MOVEMENT
def("Movement","Speed",{speed=24}, function(m)
    m._c = RunService.Heartbeat:Connect(function()
        local _,_,hum = myChar()
        if hum then hum.WalkSpeed = m.settings.speed end
    end)
end, function(m)
    if m._c then m._c:Disconnect() m._c = nil end
    local _,_,hum = myChar(); if hum then hum.WalkSpeed = 16 end
end)

def("Movement","Fly",{speed=55}, function(m)
    m._c = RunService.RenderStepped:Connect(function()
        local _,hrp = myChar(); if not hrp then return end
        local bv = hrp:FindFirstChild("OJBS_Fly")
        if not bv then
            bv = Instance.new("BodyVelocity")
            bv.Name = "OJBS_Fly"
            bv.MaxForce = Vector3.new(1e6,1e6,1e6)
            bv.Parent = hrp
        end
        local c = cam()
        local v = Vector3.zero
        if c then
            local look = c.CFrame.LookVector
            v = look * (UIS:IsKeyDown(Enum.KeyCode.W) and m.settings.speed or 0)
            v -= look * (UIS:IsKeyDown(Enum.KeyCode.S) and m.settings.speed or 0)
        end
        if UIS:IsKeyDown(Enum.KeyCode.Space) then v += Vector3.new(0,m.settings.speed,0) end
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then v -= Vector3.new(0,m.settings.speed,0) end
        bv.Velocity = v
    end)
end, function(m)
    if m._c then m._c:Disconnect() m._c = nil end
    local _,hrp = myChar()
    if hrp then local bv = hrp:FindFirstChild("OJBS_Fly") if bv then bv:Destroy() end end
end)

def("Movement","Long Jump",{mult=2.5}, function(m)
    m._c = RunService.Heartbeat:Connect(function()
        local _,hrp = myChar(); if not hrp then return end
        local v = hrp.AssemblyLinearVelocity
        if v.Magnitude > 5 then
            hrp.AssemblyLinearVelocity = Vector3.new(v.X*m.settings.mult, v.Y, v.Z*m.settings.mult)
        end
    end)
end, function(m) if m._c then m._c:Disconnect() m._c = nil end end)

def("Movement","High Jump",{power=120}, function(m)
    m._c = RunService.Heartbeat:Connect(function()
        local _,_,hum = myChar()
        if hum then hum.UseJumpPower = true hum.JumpPower = m.settings.power end
    end)
end, function(m)
    if m._c then m._c:Disconnect() m._c = nil end
    local _,_,hum = myChar(); if hum then hum.JumpPower = 50 end
end)

def("Movement","Bunny Hop",{}, function(m)
    m._c = RunService.Heartbeat:Connect(function()
        local _,_,hum = myChar(); if not hum then return end
        if hum:GetState() == Enum.HumanoidStateType.Landed or hum:GetState() == Enum.HumanoidStateType.Running then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end)
end, function(m) if m._c then m._c:Disconnect() m._c = nil end end)

def("Movement","No Slow",{speed=16}, function(m)
    m._c = RunService.Heartbeat:Connect(function()
        local _,_,hum = myChar()
        if hum and hum.WalkSpeed < m.settings.speed then hum.WalkSpeed = m.settings.speed end
    end)
end, function(m) if m._c then m._c:Disconnect() m._c = nil end end)

def("Movement","Auto Sprint",{speed=32}, function(m)
    m._c = RunService.Heartbeat:Connect(function()
        local _,_,hum = myChar()
        if hum and hum.MoveDirection.Magnitude > 0 then hum.WalkSpeed = m.settings.speed end
    end)
end, function(m)
    if m._c then m._c:Disconnect() m._c = nil end
    local _,_,hum = myChar(); if hum then hum.WalkSpeed = 16 end
end)

def("Movement","Spider",{}, function(m)
    m._c = RunService.Heartbeat:Connect(function()
        local char,_,hum = myChar(); if not char or not hum then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local ray = RaycastParams.new()
            ray.FilterDescendantsInstances = {char}
            local hit = WS:Raycast(hrp.Position, hrp.CFrame.LookVector * 2, ray)
            if hit then hum:ChangeState(Enum.HumanoidStateType.Climbing) end
        end
    end)
end, function(m) if m._c then m._c:Disconnect() m._c = nil end end)

-- VISUALS
local function espObjects(m, builder)
    m.objs = {}
    m._c = RunService.Heartbeat:Connect(function()
        for _,p in ipairs(allPlayers()) do
            if p.Character and not m.objs[p] then
                local ok, obj = pcall(builder, p)
                if ok and obj then m.objs[p] = obj end
            end
        end
        for p,obj in pairs(m.objs) do
            if not p.Parent or not p.Character then
                pcall(function() obj:Destroy() end)
                m.objs[p] = nil
            end
        end
    end)
end
local function espCleanup(m)
    if m._c then m._c:Disconnect() m._c = nil end
    for _,obj in pairs(m.objs or {}) do pcall(function() obj:Destroy() end) end
    m.objs = nil
end

def("Visuals","Player ESP",{}, function(m)
    espObjects(m, function(p)
        local h = Instance.new("Highlight")
        h.FillColor = Theme.accent; h.OutlineColor = Theme.accent2
        h.FillTransparency = 0.65
        h.Parent = p.Character
        return h
    end)
end, espCleanup)

def("Visuals","Box ESP",{}, function(m)
    espObjects(m, function(p)
        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local b = Instance.new("BoxHandleAdornment")
        b.Adornee = hrp; b.Size = Vector3.new(4,6,4)
        b.Color3 = Theme.accent; b.Transparency = 0.45; b.AlwaysOnTop = true
        b.Parent = hrp
        return b
    end)
end, espCleanup)

def("Visuals","Health ESP",{}, function(m)
    espObjects(m, function(p)
        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local bg = Instance.new("BillboardGui")
        bg.Size = UDim2.new(0,60,0,8); bg.StudsOffset = Vector3.new(0,3,0); bg.AlwaysOnTop = true
        bg.Parent = hrp
        local back = Instance.new("Frame"); back.Size = UDim2.new(1,0,1,0)
        back.BackgroundColor3 = Color3.fromRGB(30,30,30); back.BorderSizePixel = 0; back.Parent = bg
        local fill = Instance.new("Frame"); fill.Size = UDim2.new(1,0,1,0)
        fill.BackgroundColor3 = Color3.fromRGB(60,220,100); fill.BorderSizePixel = 0; fill.Parent = back
        task.spawn(function()
            while bg.Parent do
                local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
                if hum then fill.Size = UDim2.new(math.clamp(hum.Health/hum.MaxHealth,0,1),0,1,0) end
                RunService.Heartbeat:Wait()
            end
        end)
        return bg
    end)
end, espCleanup)

def("Visuals","Tracers",{}, function(m)
    if not Drawing then return end
    m.lines = {}
    m._c = RunService.RenderStepped:Connect(function()
        local c = cam(); if not c then return end
        for _,p in ipairs(allPlayers()) do
            if p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local line = m.lines[p]
                    if not line then line = Drawing.new("Line") m.lines[p] = line end
                    local sp, on = c:WorldToViewportPoint(hrp.Position)
                    if on then
                        line.Visible = true
                        line.From = Vector2.new(c.ViewportSize.X/2, c.ViewportSize.Y)
                        line.To = Vector2.new(sp.X, sp.Y)
                        line.Color = Theme.accent; line.Thickness = 1.5
                    else
                        line.Visible = false
                    end
                end
            end
        end
    end)
end, function(m)
    if m._c then m._c:Disconnect() m._c = nil end
    for _,l in pairs(m.lines or {}) do pcall(function() l:Remove() end) end
    m.lines = nil
end)

def("Visuals","Chams",{}, function(m)
    espObjects(m, function(p)
        local h = Instance.new("Highlight")
        h.FillColor = Theme.accent; h.OutlineColor = Theme.accent
        h.FillTransparency = 0.2; h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        h.Parent = p.Character
        return h
    end)
end, espCleanup)

def("Visuals","Name Tags",{}, function(m)
    espObjects(m, function(p)
        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local bg = Instance.new("BillboardGui")
        bg.Size = UDim2.new(0,200,0,20); bg.StudsOffset = Vector3.new(0,4,0); bg.AlwaysOnTop = true
        bg.Parent = hrp
        local t = Instance.new("TextLabel")
        t.Size = UDim2.new(1,0,1,0); t.BackgroundTransparency = 1
        t.Text = p.DisplayName or p.Name
        t.TextColor3 = Color3.new(1,1,1); t.TextStrokeTransparency = 0
        t.Font = Enum.Font.GothamBold; t.TextSize = 12; t.Parent = bg
        return bg
    end)
end, espCleanup)

def("Visuals","Skeleton ESP",{}, function(m)
    if not Drawing then return end
    m.lines = {}
    m._c = RunService.RenderStepped:Connect(function()
        local c = cam(); if not c then return end
        for _,p in ipairs(allPlayers()) do
            local pc = p.Character
            if pc then
                local hrp = pc:FindFirstChild("HumanoidRootPart")
                local head = pc:FindFirstChild("Head")
                if hrp and head then
                    local pair = m.lines[p]
                    if not pair then
                        pair = { Drawing.new("Line"), Drawing.new("Line") }
                        m.lines[p] = pair
                    end
                    local a = c:WorldToViewportPoint(head.Position)
                    local b = c:WorldToViewportPoint(hrp.Position)
                    local ca = Vector2.new(a.X,a.Y); local cb = Vector2.new(b.X,b.Y)
                    pair[1].From = ca; pair[1].To = cb
                    pair[1].Color = Theme.accent2; pair[1].Thickness = 1.5
                    pair[1].Visible = a.Z > 0 and b.Z > 0
                    pair[2].From = cb; pair[2].To = Vector2.new(cb.X, cb.Y + 40)
                    pair[2].Color = Theme.accent2; pair[2].Thickness = 1.5
                    pair[2].Visible = b.Z > 0
                end
            end
        end
    end)
end, function(m)
    if m._c then m._c:Disconnect() m._c = nil end
    for _,pair in pairs(m.lines or {}) do
        for _,l in ipairs(pair) do pcall(function() l:Remove() end) end
    end
    m.lines = nil
end)

def("Visuals","Target HUD",{}, function(m)
    m._c = RunService.Heartbeat:Connect(function()
        if not m._label then
            m._label = Instance.new("TextLabel")
            m._label.Size = UDim2.new(0,220,0,24)
            m._label.Position = UDim2.new(0.5,-110,0,14)
            m._label.BackgroundColor3 = Theme.panel
            m._label.TextColor3 = Theme.accent2
            m._label.Font = Enum.Font.GothamBold
            m._label.TextSize = 13
            m._label.Parent = gui
        end
        local t = nearest(200)
        if t then
            local _,hum = aliveTarget(t)
            m._label.Text = string.format("%s  |  HP %d", t.DisplayName or t.Name, hum and math.floor(hum.Health) or 0)
            m._label.Visible = true
        else
            m._label.Visible = false
        end
    end)
end, function(m)
    if m._c then m._c:Disconnect() m._c = nil end
    if m._label then m._label:Destroy() m._label = nil end
end)

-- PLAYER / HUD
local function hudLabel(m, pos, size, align)
    local l = Instance.new("TextLabel")
    l.Size = size; l.Position = pos
    l.BackgroundTransparency = 1
    l.Font = Enum.Font.Code; l.TextSize = 12
    l.TextColor3 = Color3.new(1,1,1); l.TextStrokeTransparency = 0.6
    l.TextXAlignment = align or Enum.TextXAlignment.Left
    l.Parent = gui
    m._label = l
    return l
end
local function killLabel(m) if m._label then m._label:Destroy() m._label = nil end end

def("Player","Player Info",{}, function(m)
    local l = hudLabel(m, UDim2.new(0,12,0,56), UDim2.new(0,220,0,56))
    m._c = RunService.Heartbeat:Connect(function()
        local _,_,hum = myChar()
        l.Text = string.format("HP: %d / %d", hum and math.floor(hum.Health) or 0, hum and math.floor(hum.MaxHealth) or 0)
    end)
end, function(m) if m._c then m._c:Disconnect() m._c = nil end killLabel(m) end)

def("Player","CPS Counter",{}, function(m)
    local l = hudLabel(m, UDim2.new(0,12,0,80), UDim2.new(0,140,0,16))
    m._n = 0
    m._conn = UIS.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then m._n += 1 end
    end)
    m._c = task.spawn(function()
        while m._label do
            l.Text = "CPS: " .. m._n
            m._n = 0
            task.wait(1)
        end
    end)
end, function(m)
    if m._conn then m._conn:Disconnect() m._conn = nil end
    if m._c then task.cancel(m._c) end
    killLabel(m)
end)

def("Player","Hit Counter",{}, function(m)
    local l = hudLabel(m, UDim2.new(0,12,0,100), UDim2.new(0,140,0,16))
    m._hits = 0
    m._prev = {}
    m._c = RunService.Heartbeat:Connect(function()
        for _,p in ipairs(allPlayers()) do
            local _,hum = aliveTarget(p)
            if hum then
                local prev = m._prev[p] or hum.Health
                if hum.Health < prev then m._hits += 1 end
                m._prev[p] = hum.Health
            end
        end
        l.Text = "Hits: " .. m._hits
    end)
end, function(m) if m._c then m._c:Disconnect() m._c = nil end killLabel(m) end)

def("Player","Keystrokes",{}, function(m)
    m._frame = Instance.new("Frame")
    m._frame.Size = UDim2.new(0,120,0,40)
    m._frame.Position = UDim2.new(0,12,0,126)
    m._frame.BackgroundTransparency = 0.4
    m._frame.BackgroundColor3 = Color3.new(0,0,0)
    m._frame.Parent = gui
    local keys = {}
    local names = {"W","A","S","D"}
    for i,k in ipairs(names) do
        local b = Instance.new("TextLabel")
        b.Size = UDim2.new(0.22,0,0.8,0)
        b.Position = UDim2.new(0.02 + (i-1)*0.24, 0, 0.1, 0)
        b.BackgroundColor3 = Color3.fromRGB(40,40,40)
        b.Text = k; b.Font = Enum.Font.GothamBold; b.TextSize = 12
        b.TextColor3 = Color3.fromRGB(160,160,160)
        b.Parent = m._frame
        keys[k] = b
    end
    m._c = RunService.RenderStepped:Connect(function()
        local map = { W = Enum.KeyCode.W, A = Enum.KeyCode.A, S = Enum.KeyCode.S, D = Enum.KeyCode.D }
        for k,code in pairs(map) do
            if UIS:IsKeyDown(code) then
                keys[k].BackgroundColor3 = Theme.accent; keys[k].TextColor3 = Theme.text
            else
                keys[k].BackgroundColor3 = Color3.fromRGB(40,40,40); keys[k].TextColor3 = Color3.fromRGB(160,160,160)
            end
        end
    end)
end, function(m)
    if m._c then m._c:Disconnect() m._c = nil end
    if m._frame then m._frame:Destroy() m._frame = nil end
end)

def("Player","Coordinates",{}, function(m)
    local l = hudLabel(m, UDim2.new(0,12,0,176), UDim2.new(0,220,0,16))
    m._c = RunService.Heartbeat:Connect(function()
        local _,hrp = myChar()
        if hrp then l.Text = string.format("X %.0f  Y %.0f  Z %.0f", hrp.Position.X, hrp.Position.Y, hrp.Position.Z) end
    end)
end, function(m) if m._c then m._c:Disconnect() m._c = nil end killLabel(m) end)

def("Player","FPS Counter",{}, function(m)
    local l = hudLabel(m, UDim2.new(1,-140,0,56), UDim2.new(0,120,0,16), Enum.TextXAlignment.Right)
    m._n, m._t = 0, 0
    m._c = RunService.RenderStepped:Connect(function(dt)
        m._n += 1; m._t += dt
        if m._t >= 1 then
            l.Text = "FPS: " .. m._n
            m._n, m._t = 0, 0
        end
    end)
end, function(m) if m._c then m._c:Disconnect() m._c = nil end killLabel(m) end)

def("Player","Ping Display",{}, function(m)
    local l = hudLabel(m, UDim2.new(1,-140,0,76), UDim2.new(0,120,0,16), Enum.TextXAlignment.Right)
    m._c = RunService.Heartbeat:Connect(function()
        local ok,ping = pcall(function() return LP:GetNetworkPing()*1000 end)
        if ok then l.Text = "Ping: " .. math.floor(ping) end
    end)
end, function(m) if m._c then m._c:Disconnect() m._c = nil end killLabel(m) end)

-- WORLD
def("World","Fullbright",{}, function(m)
    m._old = { amb = Lighting.Ambient, outAmb = Lighting.OutdoorAmbient, bright = Lighting.Brightness, time = Lighting.ClockTime }
    Lighting.Ambient = Color3.new(1,1,1)
    Lighting.OutdoorAmbient = Color3.new(1,1,1)
    Lighting.Brightness = 2
    Lighting.ClockTime = 12
end, function(m)
    if m._old then
        Lighting.Ambient = m._old.amb
        Lighting.OutdoorAmbient = m._old.outAmb
        Lighting.Brightness = m._old.bright
        Lighting.ClockTime = m._old.time
    end
end)

def("World","Time Changer",{time=12}, function(m)
    m._old = Lighting.ClockTime
    m._c = RunService.Heartbeat:Connect(function() Lighting.ClockTime = m.settings.time end)
end, function(m)
    if m._c then m._c:Disconnect() m._c = nil end
    if m._old then Lighting.ClockTime = m._old end
end)

def("World","Weather Changer",{fog=600,color=Color3.fromRGB(120,120,120)}, function(m)
    m._old = { end_ = Lighting.FogEnd, color = Lighting.FogColor, start = Lighting.FogStart }
    Lighting.FogEnd = m.settings.fog
    Lighting.FogColor = m.settings.color
    Lighting.FogStart = 0
end, function(m)
    if m._old then
        Lighting.FogEnd = m._old.end_
        Lighting.FogColor = m._old.color
        Lighting.FogStart = m._old.start
    end
end)

def("World","Custom Sky",{id="6445260524"}, function(m)
    m._sky = Instance.new("Sky")
    m._sky.SkyboxBk = "rbxassetid://" .. m.settings.id
    m._sky.SkyboxDn = "rbxassetid://" .. m.settings.id
    m._sky.SkyboxFt = "rbxassetid://" .. m.settings.id
    m._sky.SkyboxLf = "rbxassetid://" .. m.settings.id
    m._sky.SkyboxRt = "rbxassetid://" .. m.settings.id
    m._sky.SkyboxUp = "rbxassetid://" .. m.settings.id
    m._sky.Parent = Lighting
end, function(m)
    if m._sky then m._sky:Destroy() m._sky = nil end
end)

def("World","World Color",{color=Color3.fromRGB(88,128,200)}, function(m)
    m._old = Lighting.Ambient
    Lighting.Ambient = m.settings.color
end, function(m)
    if m._old then Lighting.Ambient = m._old end
end)

-- MISC
def("Misc","Friend List",{}, function(m) end, function(m) end)
def("Misc","Enemy List",{}, function(m) end, function(m) end)
def("Misc","Target Priority",{mode="Distance"}, function(m) end, function(m) end)
def("Misc","Notifications",{}, function(m) end, function(m) end)
def("Misc","Config Manager",{}, function(m) end, function(m) end)
def("Misc","Panic Button",{}, function(m)
    disableAll()
    if gui then gui.Enabled = false end
end, function(m) end)
def("Misc","Keybind Manager",{}, function(m) end, function(m) end)

-- ================= UI =================
local gui
local BuildConns = {}
local function conn(sig, fn) local c = sig:Connect(fn) table.insert(BuildConns, c) return c end
local function clearConns()
    for _,c in ipairs(BuildConns) do pcall(function() c:Disconnect() end) end
    BuildConns = {}
end
local function new(class, props, parent)
    local o = Instance.new(class)
    for k,v in pairs(props or {}) do o[k] = v end
    o.Parent = parent
    return o
end
local function corner(p, r) return new("UICorner", { CornerRadius = UDim.new(0, r or 8) }, p) end
local function strokep(p, c, t) return new("UIStroke", { Color = c or Theme.stroke, Thickness = t or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, p) end
local function padp(p, n) return new("UIPadding", { PaddingTop = UDim.new(0,n), PaddingBottom = UDim.new(0,n), PaddingLeft = UDim.new(0,n), PaddingRight = UDim.new(0,n) }, p) end
local function tw(o, props, dur)
    local d = C.animations and (dur or 0.16) or 0
    local t = Tween:Create(o, TweenInfo.new(d, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props)
    t:Play(); return t
end

local function makeToggle(parent, label, default, callback)
    local row = new("TextButton", { Size = UDim2.new(1,0,0,26), BackgroundTransparency = 1, Text = "", AutoButtonColor = false }, parent)
    new("TextLabel", { Size = UDim2.new(1,-40,1,0), BackgroundTransparency = 1, Text = label, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Theme.text, TextXAlignment = Enum.TextXAlignment.Left, Active = false, Selectable = false }, row)
    local track = new("Frame", { Size = UDim2.new(0,30,0,16), Position = UDim2.new(1,-30,0.5,-8), BackgroundColor3 = default and Theme.accent or Theme.off, BorderSizePixel = 0 }, row)
    corner(track, 8)
    local knob = new("Frame", { Size = UDim2.new(0,12,0,12), Position = default and UDim2.new(1,-14,0.5,-6) or UDim2.new(0,2,0.5,-6), BackgroundColor3 = Theme.text, BorderSizePixel = 0 }, track)
    corner(knob, 6)
    local state = default and true or false
    local function set(v, silent)
        state = v
        tw(track, { BackgroundColor3 = v and Theme.accent or Theme.off }, 0.12)
        tw(knob, { Position = v and UDim2.new(1,-14,0.5,-6) or UDim2.new(0,2,0.5,-6) }, 0.12)
        if not silent and callback then callback(v) end
    end
    conn(row.MouseButton1Click, function() set(not state) end)
    set(default, true)
    return { set = set, get = function() return state end }
end

local function makeSlider(parent, label, min, max, default, callback)
    local holder = new("Frame", { Size = UDim2.new(1,0,0,34), BackgroundTransparency = 1 }, parent)
    new("TextLabel", { Size = UDim2.new(1,-50,0,16), BackgroundTransparency = 1, Text = label, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Theme.text, TextXAlignment = Enum.TextXAlignment.Left }, holder)
    local val = new("TextLabel", { Size = UDim2.new(0,50,0,16), Position = UDim2.new(1,-50,0,0), BackgroundTransparency = 1, Text = tostring(default), Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Theme.accent2, TextXAlignment = Enum.TextXAlignment.Right }, holder)
    local bar = new("Frame", { Size = UDim2.new(1,0,0,4), Position = UDim2.new(0,0,0,24), BackgroundColor3 = Theme.light, BorderSizePixel = 0 }, holder)
    corner(bar, 2)
    local fill = new("Frame", { Size = UDim2.new((default-min)/(max-min),0,1,0), BackgroundColor3 = Theme.accent, BorderSizePixel = 0 }, bar)
    corner(fill, 2)
    local value, dragging = default, false
    local function apply(mx)
        local rel = math.clamp((mx - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        value = math.floor((min + (max-min)*rel)*100 + 0.5)/100
        fill.Size = UDim2.new(rel,0,1,0)
        val.Text = tostring(value)
        if callback then callback(value) end
    end
    conn(bar.InputBegan, function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; apply(i.Position.X) end end)
    conn(UIS.InputChanged, function(i) if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then apply(i.Position.X) end end)
    conn(UIS.InputEnded, function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
    return { get = function() return value end }
end

local function makeDropdown(parent, label, options, default, callback)
    local holder = new("Frame", { Size = UDim2.new(1,0,0,28), BackgroundTransparency = 1 }, parent)
    new("TextLabel", { Size = UDim2.new(0.4,0,1,0), BackgroundTransparency = 1, Text = label, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Theme.text, TextXAlignment = Enum.TextXAlignment.Left }, holder)
    local btn = new("TextButton", { Size = UDim2.new(0,140,0,22), Position = UDim2.new(1,-140,0.5,-11), BackgroundColor3 = Theme.light, Text = default, Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = Theme.accent2, AutoButtonColor = false }, holder)
    corner(btn, 6)
    local list = new("Frame", { Size = UDim2.new(0,140,0,0), Position = UDim2.new(1,-140,0,30), BackgroundColor3 = Theme.light, Visible = false, ZIndex = 20 }, holder)
    corner(list, 6); new("UIListLayout", { Padding = UDim.new(0,2) }, list); padp(list, 4)
    local open = false
    for _,opt in ipairs(options) do
        local o = new("TextButton", { Size = UDim2.new(1,0,0,20), BackgroundColor3 = Theme.light, Text = opt, Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = Theme.text, AutoButtonColor = false, ZIndex = 21 }, list)
        corner(o, 4)
        conn(o.MouseButton1Click, function() btn.Text = opt; list.Visible = false; open = false; if callback then callback(opt) end end)
    end
    conn(btn.MouseButton1Click, function() open = not open; list.Visible = open; if open then list.AutomaticSize = Enum.AutomaticSize.Y end end)
    return { get = function() return btn.Text end }
end

local function makeButton(parent, label, callback)
    local b = new("TextButton", { Size = UDim2.new(1,0,0,26), BackgroundColor3 = Theme.light, Text = label, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Theme.text, AutoButtonColor = false }, parent)
    corner(b, 7); strokep(b, Theme.stroke, 1)
    conn(b.MouseButton1Click, callback)
    return b
end

local function makeKeybind(parent, label, default, callback)
    local row = new("Frame", { Size = UDim2.new(1,0,0,28), BackgroundTransparency = 1 }, parent)
    new("TextLabel", { Size = UDim2.new(0.4,0,1,0), BackgroundTransparency = 1, Text = label, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Theme.text, TextXAlignment = Enum.TextXAlignment.Left }, row)
    local txt = typeof(default) == "EnumItem" and default.Name or tostring(default)
    local btn = new("TextButton", { Size = UDim2.new(0,90,0,22), Position = UDim2.new(1,-90,0.5,-11), BackgroundColor3 = Theme.light, Text = txt, Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = Theme.accent2, AutoButtonColor = false }, row)
    corner(btn, 6)
    local listening = false
    conn(btn.MouseButton1Click, function() listening = true; btn.Text = "..." end)
    conn(UIS.InputBegan, function(i)
        if not listening then return end
        if i.UserInputType ~= Enum.UserInputType.Keyboard then return end
        listening = false; btn.Text = i.KeyCode.Name
        if callback then callback(i.KeyCode) end
    end)
    return { get = function() return default end }
end

local function makeColorpicker(parent, label, default, callback)
    local row = new("Frame", { Size = UDim2.new(1,0,0,28), BackgroundTransparency = 1 }, parent)
    new("TextLabel", { Size = UDim2.new(1,-40,1,0), BackgroundTransparency = 1, Text = label, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Theme.text, TextXAlignment = Enum.TextXAlignment.Left }, row)
    local sw = new("Frame", { Size = UDim2.new(0,28,0,20), Position = UDim2.new(1,-28,0.5,-10), BackgroundColor3 = default, BorderSizePixel = 0 }, row)
    corner(sw, 5); strokep(sw, Theme.stroke, 1)
    local H,S,V = default:ToHSV()
    local popup = new("Frame", { Size = UDim2.new(0,170,0,150), Position = UDim2.new(1,-170,0,32), BackgroundColor3 = Theme.light, Visible = false, ZIndex = 30 }, row)
    corner(popup, 8); strokep(popup, Theme.stroke, 1)
    local sv = new("ImageLabel", { Size = UDim2.new(1,-16,0,80), Position = UDim2.new(0,8,0,8), BackgroundColor3 = Color3.fromHSV(H,1,1), BorderSizePixel = 0, Image = "rbxassetid://3700752136", ZIndex = 31 }, popup)
    corner(sv, 4)
    local hue = new("Frame", { Size = UDim2.new(1,-16,0,14), Position = UDim2.new(0,8,0,108), BorderSizePixel = 0, ZIndex = 31 }, popup)
    corner(hue, 3)
    new("UIGradient", { Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromHSV(0,1,1)), ColorSequenceKeypoint.new(0.17, Color3.fromHSV(0.17,1,1)),
        ColorSequenceKeypoint.new(0.33, Color3.fromHSV(0.33,1,1)), ColorSequenceKeypoint.new(0.5, Color3.fromHSV(0.5,1,1)),
        ColorSequenceKeypoint.new(0.67, Color3.fromHSV(0.67,1,1)), ColorSequenceKeypoint.new(0.83, Color3.fromHSV(0.83,1,1)),
        ColorSequenceKeypoint.new(1, Color3.fromHSV(1,1,1)),
    }) }, hue)
    local svD, hueD = false, false
    local function svAt(x,y)
        S = math.clamp((x - sv.AbsolutePosition.X)/sv.AbsoluteSize.X, 0, 1)
        V = 1 - math.clamp((y - sv.AbsolutePosition.Y)/sv.AbsoluteSize.Y, 0, 1)
        local c = Color3.fromHSV(H,S,V); sw.BackgroundColor3 = c
        if callback then callback(c) end
    end
    local function hueAt(x)
        H = math.clamp((x - hue.AbsolutePosition.X)/hue.AbsoluteSize.X, 0, 1)
        sv.BackgroundColor3 = Color3.fromHSV(H,1,1)
        local c = Color3.fromHSV(H,S,V); sw.BackgroundColor3 = c
        if callback then callback(c) end
    end
    conn(sv.InputBegan, function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then svD = true; svAt(i.Position.X,i.Position.Y) end end)
    conn(hue.InputBegan, function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then hueD = true; hueAt(i.Position.X) end end)
    conn(UIS.InputChanged, function(i)
        if i.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        if svD then svAt(i.Position.X,i.Position.Y) end
        if hueD then hueAt(i.Position.X) end
    end)
    conn(UIS.InputEnded, function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then svD = false; hueD = false end end)
    conn(sw.InputBegan, function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then popup.Visible = not popup.Visible end end)
    return { get = function() return Color3.fromHSV(H,S,V) end }
end

-- ================= BUILD =================
local function buildUI()
    local PlayerGui = LP:WaitForChild("PlayerGui")
    local old = PlayerGui:FindFirstChild("OJBS_CombatGUI")
    if old then old:Destroy() end

    gui = new("ScreenGui", { Name = "OJBS_CombatGUI", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999 }, PlayerGui)

    local win = new("Frame", { Size = UDim2.new(0,660,0,480), Position = UDim2.new(0.5,-330,0.5,-240), BackgroundColor3 = Theme.bg, BorderSizePixel = 0, ClipsDescendants = true }, gui)
    corner(win, 14); strokep(win, Theme.stroke, 1)
    if C.pos then win.Position = UDim2.new(0, C.pos.x, 0, C.pos.y) end

    local bar = new("Frame", { Size = UDim2.new(1,0,0,46), BackgroundColor3 = Theme.panel, BorderSizePixel = 0, ZIndex = 5 }, win)
    corner(bar, 14)
    new("Frame", { Size = UDim2.new(1,0,0,16), Position = UDim2.new(0,0,1,-16), BackgroundColor3 = Theme.panel, BorderSizePixel = 0 }, bar)
    new("TextLabel", { Size = UDim2.new(0,220,1,0), Position = UDim2.new(0,18,0,0), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, Text = "ABILITY ARENA", TextColor3 = Theme.accent2, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left }, bar)
    new("TextLabel", { Size = UDim2.new(0,220,0,14), Position = UDim2.new(0,19,0,26), BackgroundTransparency = 1, Font = Enum.Font.Gotham, Text = "combat suite", TextColor3 = Theme.dim, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left }, bar)

    local function tbtn(text, xo, col)
        local b = new("TextButton", { Size = UDim2.new(0,26,0,26), Position = UDim2.new(1,xo,0.5,-13), BackgroundColor3 = Theme.light, Text = text, Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = col or Theme.dim, AutoButtonColor = false, ZIndex = 6 }, bar)
        corner(b, 7); return b
    end
    local collapseBtn, themeBtn, closeBtn = tbtn("—",-96), tbtn("◐",-66), tbtn("✕",-36,Theme.accent)

    -- drag
    local dragging, dragStart, startPos = false, nil, nil
    conn(bar.InputBegan, function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; dragStart = i.Position; startPos = win.Position end end)
    conn(UIS.InputChanged, function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            local d = i.Position - dragStart
            win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    conn(UIS.InputEnded, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            if dragging then C.pos = { x = win.Position.X.Offset, y = win.Position.Y.Offset } end
            dragging = false
        end
    end)

    local collapsed = false
    conn(collapseBtn.MouseButton1Click, function()
        collapsed = not collapsed
        if collapsed then tw(win, { Size = UDim2.new(0,660,0,46) }, 0.2); collapseBtn.Text = "+"
        else tw(win, { Size = UDim2.new(0,660,0,480) }, 0.2); collapseBtn.Text = "—" end
    end)

    local order = { "Crimson","Ocean","Emerald","Amethyst" }
    local idx = 1
    for i,t in ipairs(order) do if t == C.theme then idx = i end end
    conn(themeBtn.MouseButton1Click, function()
        idx = idx % #order + 1
        C.theme = order[idx]
        Theme = Themes[C.theme]
        rebuild()
    end)
    conn(closeBtn.MouseButton1Click, function() gui.Enabled = false end)

    local rail = new("Frame", { Size = UDim2.new(0,150,1,-46), Position = UDim2.new(0,0,0,46), BackgroundColor3 = Theme.panel, BorderSizePixel = 0 }, win)
    new("Frame", { Size = UDim2.new(0,1,1,0), Position = UDim2.new(1,-1,0,0), BackgroundColor3 = Theme.stroke, BorderSizePixel = 0 }, rail)
    padp(rail, 8)
    new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0,4) }, rail)

    local content = new("Frame", { Size = UDim2.new(1,-150,1,-46), Position = UDim2.new(0,150,0,46), BackgroundColor3 = Theme.bg, BorderSizePixel = 0, ClipsDescendants = true }, win)

    local Pages, activeTab, tabOrder, secOrder = {}, nil, 0, 0
    local function selectTab(btn, page)
        if activeTab == btn then return end
        for _,p in pairs(Pages) do p.Visible = false end
        for _,c in ipairs(rail:GetChildren()) do
            if c:IsA("TextButton") then c.TextColor3 = Theme.dim; c.BackgroundColor3 = Theme.panel end
        end
        activeTab = btn; btn.TextColor3 = Theme.text; btn.BackgroundColor3 = Theme.light; page.Visible = true
    end
    local function makeTab(name)
        tabOrder += 1
        local btn = new("TextButton", { Size = UDim2.new(1,0,0,30), BackgroundColor3 = Theme.panel, Text = name, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Theme.dim, TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false, LayoutOrder = tabOrder }, rail)
        corner(btn, 7); new("UIPadding", { PaddingLeft = UDim.new(0,10) }, btn)
        local page = new("ScrollingFrame", { Size = UDim2.new(1,-16,1,-16), Position = UDim2.new(0,8,0,8), BackgroundTransparency = 1, ScrollBarThickness = 3, ScrollBarImageColor3 = Theme.stroke, CanvasSize = UDim2.new(0,0,0,0), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false }, content)
        new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0,8) }, page)
        conn(btn.MouseButton1Click, function() selectTab(btn, page) end)
        Pages[name] = page
        if not activeTab then selectTab(btn, page) end
        return page
    end
    local function makeSection(page, title)
        secOrder += 1
        local f = new("Frame", { Size = UDim2.new(1,-2,0,0), BackgroundColor3 = Theme.panel, BorderSizePixel = 0, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = secOrder }, page)
        corner(f, 10); strokep(f, Theme.stroke, 1); padp(f, 8)
        local body = new("Frame", { Size = UDim2.new(1,0,0,0), BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y }, f)
        new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0,2) }, body)
        new("TextLabel", { Size = UDim2.new(1,0,0,18), BackgroundTransparency = 1, Text = title, Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = Theme.accent2, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = -1 }, body)
        return body
    end
    local function feature(parent, cat, name, label, sliders)
        local m = Mods[cat][name]
        makeToggle(parent, label or name, m.enabled, function(v) setMod(cat, name, v) end)
        if sliders then
            for _,s in ipairs(sliders) do
                makeSlider(parent, s.label, s.min, s.max, m.settings[s.key] or s.min, function(v) m.settings[s.key] = v end)
            end
        end
    end

    -- COMBAT
    local p = makeTab("COMBAT"); local s = makeSection(p, "COMBAT")
    feature(s, "Combat", "Kill Aura", "Kill Aura", { {key="range",label="Range",min=1,max=50}, {key="hitDelay",label="Hit Delay (s)",min=0.01,max=0.5} })
    feature(s, "Combat", "Aim Aura", "Aim Aura", { {key="fov",label="FOV",min=10,max=500}, {key="smooth",label="Smooth",min=0,max=1} })
    feature(s, "Combat", "Trigger Bot", "Trigger Bot", { {key="radius",label="Radius",min=5,max=200} })
    feature(s, "Combat", "Auto Clicker", "Auto Clicker", { {key="cps",label="CPS",min=1,max=30} })
    feature(s, "Combat", "Reach", "Reach", { {key="distance",label="Distance",min=5,max=60} })
    feature(s, "Combat", "Hitbox Expander", "Hitbox Expander", { {key="size",label="Size",min=3,max=40} })
    feature(s, "Combat", "Multi Aura", "Multi Aura", { {key="range",label="Range",min=5,max=50} })
    feature(s, "Combat", "Target Strafe", "Target Strafe", { {key="speed",label="Speed",min=2,max=40} })
    feature(s, "Combat", "Auto Block", "Auto Block")
    feature(s, "Combat", "Auto Parry", "Auto Parry")
    feature(s, "Combat", "Auto Combo", "Auto Combo")
    feature(s, "Combat", "Criticals", "Criticals")
    feature(s, "Combat", "Velocity", "Velocity", { {key="value",label="Value",min=10,max=200} })
    feature(s, "Combat", "Anti Knockback", "Anti Knockback")
    feature(s, "Combat", "Backtrack", "Backtrack", { {key="amount",label="Offset",min=0,max=10} })

    -- MOVEMENT
    p = makeTab("MOVEMENT"); s = makeSection(p, "MOVEMENT")
    feature(s, "Movement", "Speed", "Speed", { {key="speed",label="WalkSpeed",min=16,max=250} })
    feature(s, "Movement", "Fly", "Fly", { {key="speed",label="Fly Speed",min=10,max=250} })
    feature(s, "Movement", "Long Jump", "Long Jump", { {key="mult",label="Multiplier",min=1,max=10} })
    feature(s, "Movement", "High Jump", "High Jump", { {key="power",label="Jump Power",min=50,max=500} })
    feature(s, "Movement", "Bunny Hop", "Bunny Hop")
    feature(s, "Movement", "No Slow", "No Slow", { {key="speed",label="Min Speed",min=16,max=250} })
    feature(s, "Movement", "Auto Sprint", "Auto Sprint", { {key="speed",label="Sprint Speed",min=16,max=250} })
    feature(s, "Movement", "Spider", "Spider")

    -- VISUALS
    p = makeTab("VISUALS"); s = makeSection(p, "VISUALS")
    feature(s, "Visuals", "Player ESP", "Player ESP")
    feature(s, "Visuals", "Box ESP", "Box ESP")
    feature(s, "Visuals", "Health ESP", "Health ESP")
    feature(s, "Visuals", "Tracers", "Tracers")
    feature(s, "Visuals", "Chams", "Chams")
    feature(s, "Visuals", "Name Tags", "Name Tags")
    feature(s, "Visuals", "Skeleton ESP", "Skeleton ESP")
    feature(s, "Visuals", "Target HUD", "Target HUD")

    -- PLAYER
    p = makeTab("PLAYER"); s = makeSection(p, "PLAYER")
    feature(s, "Player", "Player Info", "Player Information")
    feature(s, "Player", "CPS Counter", "CPS Counter")
    feature(s, "Player", "Hit Counter", "Hit Counter")
    feature(s, "Player", "Keystrokes", "Keystrokes")
    feature(s, "Player", "Coordinates", "Coordinates")
    feature(s, "Player", "FPS Counter", "FPS Counter")
    feature(s, "Player", "Ping Display", "Ping Display")

    -- WORLD
    p = makeTab("WORLD"); s = makeSection(p, "WORLD")
    feature(s, "World", "Fullbright", "Fullbright")
    feature(s, "World", "Time Changer", "Time Changer", { {key="time",label="Clock Time",min=0,max=24} })
    feature(s, "World", "Weather Changer", "Weather Changer", { {key="fog",label="Fog End",min=50,max=5000} })
    feature(s, "World", "Custom Sky", "Custom Sky")
    feature(s, "World", "World Color", "World Color")
    makeColorpicker(s, "Ambient Color", Mods.World["World Color"].settings.color, function(c) Mods.World["World Color"].settings.color = c end)

    -- MISC
    p = makeTab("MISC"); s = makeSection(p, "MISC")
    feature(s, "Misc", "Friend List", "Friend List")
    feature(s, "Misc", "Enemy List", "Enemy List")
    feature(s, "Misc", "Target Priority", "Target Priority")
    makeDropdown(s, "Priority Mode", { "Distance", "Lowest Health", "Highest Health" }, "Distance", function(v) Mods.Misc["Target Priority"].settings.mode = v end)
    feature(s, "Misc", "Notifications", "Notifications")
    feature(s, "Misc", "Config Manager", "Config Manager")
    feature(s, "Misc", "Panic Button", "Panic Button")
    feature(s, "Misc", "Keybind Manager", "Keybind Manager")

    -- SETTINGS
    p = makeTab("SETTINGS"); s = makeSection(p, "SETTINGS")
    makeDropdown(s, "GUI Theme", { "Crimson","Ocean","Emerald","Amethyst" }, C.theme, function(v) C.theme = v; Theme = Themes[v]; rebuild() end)
    makeDropdown(s, "Animations", { "On","Off" }, C.animations and "On" or "Off", function(v) C.animations = (v == "On") end)
    makeSlider(s, "UI Scale", 0.7, 1.5, C.uiScale, function(v) C.uiScale = v; win.Size = UDim2.new(0, 660*v, 0, 480*v) end)
    makeKeybind(s, "Open / Close", C.openKey, function(k) C.openKey = k end)
    makeKeybind(s, "Panic Key", Enum.KeyCode.RightControl, function(k) C.panicKey = k end)
    makeButton(s, "Save Config", function() saveCfg() end)
    makeButton(s, "Load Config", function()
        local d = loadCfg()
        if d then
            C.theme = d.theme or C.theme
            C.animations = d.animations ~= false
            C.uiScale = d.uiScale or 1
            Theme = Themes[C.theme] or Themes.Crimson
            rebuild()
        end
    end)
    makeButton(s, "Panic — Disable All", function() disableAll(); gui.Enabled = false end)

    if C.uiScale ~= 1 then win.Size = UDim2.new(0, 660*C.uiScale, 0, 480*C.uiScale) end
end

local function destroyUI()
    clearConns()
    if gui then gui:Destroy(); gui = nil end
end
function rebuild()
    destroyUI()
    buildUI()
end

-- open/close + panic
UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == C.openKey then
        if gui then gui.Enabled = not gui.Enabled end
    elseif input.KeyCode == (C.panicKey or Enum.KeyCode.RightControl) then
        disableAll()
        if gui then gui.Enabled = false end
    end
end)

buildUI()

-- re-apply saved feature states
for key,state in pairs(C.features) do
    if state then
        local cat, name = key:match("^(.-)%.(.+)$")
        if cat and name then setMod(cat, name, true) end
    end
end
