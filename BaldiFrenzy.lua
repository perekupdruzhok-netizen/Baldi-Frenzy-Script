-- Baldi Frenzy utility
-- Rayfield UI, client side

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")

local lp = Players.LocalPlayer
local char, hrp, hum

local mobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local espRate = mobile and 0.2 or 0.05

local flags = {
    stamina = false,
    speed = 16,
    noclip = false,
    esp = false,
    baldiClr = Color3.fromRGB(255, 50, 50),
    studentClr = Color3.fromRGB(0, 255, 120),
    bright = false,
    autoNotebook = false,
    hear = false,
    noDecay = false,
    isBaldi = false,
}

local bypass = {}
bypass.hooked = false
bypass.fakeSpeed = 16

function bypass.hookIndex()
    if bypass.hooked then return end
    local ok, err = pcall(function()
        local old
        old = hookmetamethod(game, "__index", newcclosure(function(self, key)
            if key == "WalkSpeed" and self:IsA("Humanoid") and not checkcaller() then
                return bypass.fakeSpeed
            end
            if key == "CanCollide" and self:IsA("BasePart") and not checkcaller() then
                return true
            end
            return old(self, key)
        end))
    end)
    if ok then
        bypass.hooked = true
        print("index hook ok")
    else
        warn("index hook failed", err)
    end
end

function bypass.setSpeed(h, spd)
    if not h then return end
    bypass.fakeSpeed = 16
    pcall(function() h.WalkSpeed = spd end)
end

function bypass.teleport(root, pos)
    if not root then return end
    pcall(function()
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end)
    local j = Vector3.new(
        math.random() * 2 - 1,
        math.random() * 1.5,
        math.random() * 2 - 1
    ) * 1.5
    pcall(function()
        root.CFrame = CFrame.new(pos + j)
    end)
end

function bypass.setNoclip(m, on)
    if not m then return end
    for _, p in ipairs(m:GetDescendants()) do
        if p:IsA("BasePart") then
            pcall(function() p.CanCollide = not on end)
        end
    end
end

bypass.hookIndex()

local function isBaldi(m)
    if not m then return false end
    if m.Name:lower():find("baldi") then return true end
    local attr = m:GetAttribute("Role")
    if typeof(attr) == "string" and attr:lower() == "baldi" then return true end
    if m:FindFirstChild("Ruler") or m:FindFirstChild("BaldiRuler") then return true end
    local p = Players:GetPlayerFromCharacter(m)
    if p and p.Team and p.Team.Name:lower():find("baldi") then return true end
    return false
end

local function updateRole()
    flags.isBaldi = isBaldi(char)
end

local espTags = {}
local espConn
local lastEsp = 0

local function makeTag(part, text, color)
    if not part or espTags[part] then return end
    local bb = Instance.new("BillboardGui")
    bb.Name = "BF_ESP"
    bb.Size = UDim2.new(0, 120, 0, 32)
    bb.AlwaysOnTop = true
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.Parent = part
    local l = Instance.new("TextLabel")
    l.Name = "Label"
    l.Size = UDim2.new(1, 0, 1, 0)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = color
    l.TextStrokeTransparency = 0.5
    l.TextScaled = true
    l.Font = Enum.Font.SourceSansBold
    l.Parent = bb
    espTags[part] = bb
end

local function dropTag(part)
    local bb = espTags[part]
    if bb and bb.Parent then bb:Destroy() end
    espTags[part] = nil
end

local function dropAll()
    for _, bb in pairs(espTags) do
        if bb and bb.Parent then bb:Destroy() end
    end
    espTags = {}
end

local function repaint()
    for _, bb in pairs(espTags) do
        if bb and bb.Parent then
            local l = bb:FindFirstChild("Label")
            if l then
                local b = l.Text == "BALDI"
                l.TextColor3 = b and flags.baldiClr or flags.studentClr
            end
        end
    end
end

local function espLoop()
    local now = os.clock()
    if now - lastEsp < espRate then return end
    lastEsp = now
    local seen = {}
    for _, m in ipairs(Workspace:GetChildren()) do
        if m:IsA("Model") and (m:FindFirstChildOfClass("Humanoid") or m:FindFirstChild("HumanoidRootPart")) then
            if m ~= char then
                local root = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
                if root and root:IsA("BasePart") then
                    local b = isBaldi(m)
                    local txt = b and "BALDI" or m.Name
                    local clr = b and flags.baldiClr or flags.studentClr
                    local tag = espTags[root]
                    if tag then
                        local l = tag:FindFirstChild("Label")
                        if l then
                            l.Text = txt
                            l.TextColor3 = clr
                        end
                    else
                        makeTag(root, txt, clr)
                    end
                    seen[root] = true
                end
            end
        end
    end
    for part in pairs(espTags) do
        if not seen[part] or not part.Parent then dropTag(part) end
    end
end

local function toggleEsp()
    if flags.esp and not espConn then
        espConn = RunService.Heartbeat:Connect(espLoop)
    elseif not flags.esp and espConn then
        espConn:Disconnect()
        espConn = nil
        dropAll()
    end
end

local function bindChar()
    char = lp.Character
    if not char then return end
    hrp = char:WaitForChild("HumanoidRootPart", 5)
    hum = char:WaitForChild("Humanoid", 5)
    if hum then bypass.setSpeed(hum, flags.speed) end
end

lp.CharacterAdded:Connect(function()
    bindChar()
    task.wait(1)
    updateRole()
end)
bindChar()
updateRole()

local win = Rayfield:CreateWindow({
    Name = "Baldi Frenzy Menu",
    LoadingTitle = "Baldi Frenzy Menu",
    LoadingSubtitle = "utility",
    ConfigurationSaving = {Enabled = true, FolderName = "BaldiFrenzy", FileName = "cfg"},
    KeySystem = false,
    ToggleUIKeybind = mobile and nil or "RightShift",
})

local main = win:CreateTab("Main", 4483362458)

main:CreateSection("Movement")

main:CreateToggle({
    Name = "Infinite Stamina",
    CurrentValue = false,
    Flag = "Stamina",
    Callback = function(v)
        flags.stamina = v
        if v then
            task.spawn(function()
                while flags.stamina do
                    task.wait(mobile and 0.2 or 0.1)
                    local gui = lp:FindFirstChild("PlayerGui")
                    if gui then
                        for _, d in ipairs(gui:GetDescendants()) do
                            if d:IsA("Frame") and d.Name:lower():find("stamina") then
                                local f = d:FindFirstChild("Fill")
                                if f then f.Size = UDim2.new(1, 0, 1, 0) end
                            end
                        end
                    end
                end
            end)
        end
    end,
})

main:CreateSlider({
    Name = "WalkSpeed",
    Range = {16, 120},
    Increment = mobile and 1 or 2,
    Suffix = " studs/s",
    CurrentValue = 16,
    Flag = "Speed",
    Callback = function(v)
        flags.speed = v
        if hum then bypass.setSpeed(hum, v) end
    end,
})

main:CreateToggle({
    Name = "Noclip",
    CurrentValue = false,
    Flag = "Noclip",
    Callback = function(v)
        flags.noclip = v
        if char then bypass.setNoclip(char, v) end
        if v then
            task.spawn(function()
                while flags.noclip do
                    task.wait(mobile and 0.3 or 0.2)
                    if char then bypass.setNoclip(char, true) end
                end
            end)
        end
    end,
})

main:CreateSection("ESP")

main:CreateToggle({
    Name = "Player ESP",
    CurrentValue = false,
    Flag = "Esp",
    Callback = function(v)
        flags.esp = v
        toggleEsp()
    end,
})

main:CreateColorPicker({
    Name = "Baldi Color",
    Color = flags.baldiClr,
    Flag = "BaldiClr",
    Callback = function(c)
        flags.baldiClr = c
        repaint()
    end,
})

main:CreateColorPicker({
    Name = "Student Color",
    Color = flags.studentClr,
    Flag = "StudentClr",
    Callback = function(c)
        flags.studentClr = c
        repaint()
    end,
})

main:CreateToggle({
    Name = "Fullbright",
    CurrentValue = false,
    Flag = "Bright",
    Callback = function(v)
        flags.bright = v
        if v then
            Lighting.Ambient = Color3.fromRGB(200, 200, 200)
            Lighting.OutdoorAmbient = Color3.fromRGB(200, 200, 200)
        else
            Lighting.Ambient = Color3.fromRGB(0, 0, 0)
            Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
        end
    end,
})

main:CreateButton({
    Name = "Clear ESP",
    Callback = function()
        dropAll()
        flags.esp = false
        toggleEsp()
    end,
})

local stu = win:CreateTab("Student", 4483362458)

local nbKeys = {"notebook"}
local exitKeys = {"exit"}

local function hasKw(name, keys)
    local n = name:lower()
    for _, k in ipairs(keys) do
        if n:find(k, 1, true) then return true end
    end
    return false
end

stu:CreateButton({
    Name = "TP to Notebook",
    Callback = function()
        if not hrp then return end
        local best, dist = nil, math.huge
        for _, o in ipairs(Workspace:GetDescendants()) do
            if o:IsA("BasePart") and hasKw(o.Name, nbKeys) then
                local d = (o.Position - hrp.Position).Magnitude
                if d < dist then dist = d; best = o end
            end
        end
        if best then
            bypass.teleport(hrp, best.Position + Vector3.new(0, 5, 0))
            Rayfield:Notify({Title = "Teleport", Content = "done", Duration = 2})
        else
            Rayfield:Notify({Title = "Teleport", Content = "none found", Duration = 2})
        end
    end,
})

stu:CreateButton({
    Name = "TP to Exit",
    Callback = function()
        if not hrp then return end
        for _, o in ipairs(Workspace:GetDescendants()) do
            if o:IsA("BasePart") and hasKw(o.Name, exitKeys) then
                bypass.teleport(hrp, o.Position + Vector3.new(0, 5, 0))
                Rayfield:Notify({Title = "Teleport", Content = "done", Duration = 2})
                return
            end
        end
        Rayfield:Notify({Title = "Teleport", Content = "none found", Duration = 2})
    end,
})

stu:CreateToggle({
    Name = "Auto Notebook",
    CurrentValue = false,
    Flag = "AutoNb",
    Callback = function(v)
        flags.autoNotebook = v
        if v then
            task.spawn(function()
                while flags.autoNotebook do
                    task.wait(mobile and 0.8 or 0.5)
                    if hrp then
                        for _, o in ipairs(Workspace:GetDescendants()) do
                            if o:IsA("BasePart") and hasKw(o.Name, nbKeys) then
                                if (o.Position - hrp.Position).Magnitude < 50 then
                                    pcall(function()
                                        firetouchinterest(hrp, o, 0)
                                        task.wait(0.1)
                                        firetouchinterest(hrp, o, 1)
                                    end)
                                end
                            end
                        end
                    end
                end
            end)
        end
    end,
})

local bt = win:CreateTab("Baldi", 4483362458)

bt:CreateToggle({
    Name = "Always Hear",
    CurrentValue = false,
    Flag = "Hear",
    Callback = function(v)
        flags.hear = v
        if v and not flags.isBaldi then
            Rayfield:Notify({Title = "Always Hear", Content = "only works as Baldi", Duration = 3})
        end
    end,
})

bt:CreateToggle({
    Name = "No Hearing Decay",
    CurrentValue = false,
    Flag = "NoDecay",
    Callback = function(v)
        flags.noDecay = v
        if v then
            task.spawn(function()
                while flags.noDecay do
                    task.wait(mobile and 0.4 or 0.25)
                    local gui = lp:FindFirstChild("PlayerGui")
                    if gui then
                        for _, d in ipairs(gui:GetDescendants()) do
                            if (d:IsA("NumberValue") or d:IsA("IntValue")) and d.Name:lower():find("hearing") then
                                d.Value = 999
                            end
                        end
                    end
                end
            end)
        end
    end,
})

lp.CharacterRemoving:Connect(dropAll)

Rayfield:Notify({
    Title = "Baldi Frenzy Menu",
    Content = mobile and "tap the floating button" or "RightShift to open",
    Duration = 4,
})
