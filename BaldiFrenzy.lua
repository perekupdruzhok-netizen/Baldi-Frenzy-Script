-- Baldi Frenzy utility
-- Rayfield UI, client side

local ok, Rayfield = pcall(function()
    return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)
if not ok or not Rayfield then
    warn("rayfield load failed")
    return
end

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
    espItems = false,
    baldiClr = Color3.fromRGB(255, 50, 50),
    studentClr = Color3.fromRGB(0, 255, 120),
    bright = false,
    autoNotebook = false,
    hear = false,
    noDecay = false,
    isBaldi = false,
}

local staminaFills = {}
local hearingValues = {}
local notebookCache = {}
local itemCache = {}
local oldAmbient, oldOutdoor

local bypass = {}
bypass.hooked = false
bypass.fakeSpeed = 16

function bypass.hookIndex()
    if bypass.hooked then return end
    local ok2, err = pcall(function()
        local old
        old = hookmetamethod(game, "__index", newcclosure(function(self, key)
            if not checkcaller() then
                if key == "WalkSpeed" and self:IsA("Humanoid")
                    and lp.Character and self:IsDescendantOf(lp.Character) then
                    return bypass.fakeSpeed
                end
            end
            return old(self, key)
        end))
    end)
    if ok2 then
        bypass.hooked = true
        print("index hook ok")
    else
        warn("index hook failed", err)
    end
end

function bypass.setSpeed(h, spd)
    if not h then return end
    bypass.fakeSpeed = spd
    pcall(function() h.WalkSpeed = spd end)
end

function bypass.teleport(root, pos)
    if not root or typeof(pos) ~= "Vector3" then return end
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

local function makeTag(part, text, color, withUnderline)
    if not part or espTags[part] or not part:IsDescendantOf(game) then return end
    local bb = Instance.new("BillboardGui")
    bb.Name = "BF_ESP"
    bb.Size = UDim2.new(0, 140, 0, withUnderline and 44 or 32)
    bb.AlwaysOnTop = true
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.Parent = part

    local l = Instance.new("TextLabel")
    l.Name = "Label"
    l.Size = UDim2.new(1, 0, withUnderline and 0.6 or 1, 0)
    l.Position = UDim2.new(0, 0, 0, 0)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = color
    l.TextStrokeTransparency = 0.5
    l.TextScaled = true
    l.Font = Enum.Font.SourceSansBold
    l.Parent = bb

    if withUnderline then
        local line = Instance.new("Frame")
        line.Name = "Underline"
        line.Size = UDim2.new(0.7, 0, 0, 2)
        line.Position = UDim2.new(0.15, 0, 0.62, 0)
        line.BackgroundColor3 = color
        line.BorderSizePixel = 0
        line.Parent = bb
    end

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
                if l.Text == "BALDI" then
                    l.TextColor3 = flags.baldiClr
                elseif bb:FindFirstChild("Underline") then
                    l.TextColor3 = Color3.fromRGB(255, 220, 80)
                    bb.Underline.BackgroundColor3 = Color3.fromRGB(255, 220, 80)
                else
                    l.TextColor3 = flags.studentClr
                end
            end
        end
    end
end

local function espLoop()
    local now = os.clock()
    if now - lastEsp < espRate then return end
    lastEsp = now
    local seen = {}

    if flags.esp then
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
                            makeTag(root, txt, clr, false)
                        end
                        seen[root] = true
                    end
                end
            end
        end
    end

    if flags.espItems then
        for _, o in ipairs(itemCache) do
            if o and o.Parent then
                local tag = espTags[o]
                if tag then
                    local l = tag:FindFirstChild("Label")
                    if l then l.Text = o.Name end
                else
                    makeTag(o, o.Name, Color3.fromRGB(255, 220, 80), true)
                end
                seen[o] = true
            end
        end
    end

    for part in pairs(espTags) do
        if not seen[part] or not part.Parent then dropTag(part) end
    end
end

local function ensureEspLoop()
    if (flags.esp or flags.espItems) and not espConn then
        espConn = RunService.Heartbeat:Connect(espLoop)
    elseif not flags.esp and not flags.espItems and espConn then
        espConn:Disconnect()
        espConn = nil
        dropAll()
    end
end

local gui = lp:FindFirstChild("PlayerGui")
if gui then
    for _, d in ipairs(gui:GetDescendants()) do
        if d:IsA("Frame") and d.Name:lower():find("stamina") then
            local f = d:FindFirstChild("Fill")
            if f then staminaFills[f] = f.Size end
        end
        if (d:IsA("NumberValue") or d:IsA("IntValue")) and d.Name:lower():find("hearing") then
            hearingValues[d] = d.Value
        end
    end
    gui.DescendantAdded:Connect(function(d)
        if d:IsA("Frame") and d.Name:lower():find("stamina") then
            local f = d:FindFirstChild("Fill")
            if f then staminaFills[f] = f.Size end
        end
        if (d:IsA("NumberValue") or d:IsA("IntValue")) and d.Name:lower():find("hearing") then
            hearingValues[d] = d.Value
        end
    end)
end

local function onChar(c)
    char = c
    hrp = c:WaitForChild("HumanoidRootPart", 5)
    hum = c:WaitForChild("Humanoid", 5)
    if hum then bypass.setSpeed(hum, flags.speed) end
    updateRole()
    c:GetAttributeChangedSignal("Role"):Connect(updateRole)
    c.ChildAdded:Connect(function(d)
        if d.Name == "Ruler" or d.Name == "BaldiRuler" then updateRole() end
    end)
    if flags.noclip then bypass.setNoclip(c, true) end
end
lp.CharacterAdded:Connect(onChar)
if lp.Character then onChar(lp.Character) end

local function isNotebook(o)
    local n = o.Name:lower()
    return n:find("notebook", 1, true) or n:find("notepad", 1, true) or n:find("paper", 1, true)
end

local function isItem(o)
    local n = o.Name:lower()
    for _, k in ipairs({"notebook", "notepad", "exit", "key", "paper", "door"}) do
        if n:find(k, 1, true) then return true end
    end
    return false
end

local function rebuildNotebooks()
    notebookCache = {}
    for _, o in ipairs(Workspace:GetDescendants()) do
        if o:IsA("BasePart") and isNotebook(o) then
            table.insert(notebookCache, o)
        end
    end
end
local function rebuildItems()
    itemCache = {}
    for _, o in ipairs(Workspace:GetDescendants()) do
        if o:IsA("BasePart") and isItem(o) then
            table.insert(itemCache, o)
        end
    end
end
rebuildNotebooks()
rebuildItems()

Workspace.DescendantAdded:Connect(function(d)
    if d:IsA("BasePart") then
        if isNotebook(d) then table.insert(notebookCache, d) end
        if isItem(d) then table.insert(itemCache, d) end
    end
end)
Workspace.DescendantRemoving:Connect(function(d)
    for i, v in ipairs(notebookCache) do
        if v == d then table.remove(notebookCache, i) break end
    end
    for i, v in ipairs(itemCache) do
        if v == d then table.remove(itemCache, i) break end
    end
end)

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
                    for f in pairs(staminaFills) do
                        if f.Parent then
                            pcall(function() f.Size = UDim2.new(1, 0, 1, 0) end)
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
    end,
})

main:CreateSection("ESP")

main:CreateToggle({
    Name = "Player ESP",
    CurrentValue = false,
    Flag = "Esp",
    Callback = function(v)
        flags.esp = v
        ensureEspLoop()
    end,
})

main:CreateToggle({
    Name = "Item ESP",
    CurrentValue = false,
    Flag = "EspItems",
    Callback = function(v)
        flags.espItems = v
        ensureEspLoop()
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
            oldAmbient = Lighting.Ambient
            oldOutdoor = Lighting.OutdoorAmbient
            Lighting.Ambient = Color3.fromRGB(200, 200, 200)
            Lighting.OutdoorAmbient = Color3.fromRGB(200, 200, 200)
        else
            if oldAmbient then Lighting.Ambient = oldAmbient end
            if oldOutdoor then Lighting.OutdoorAmbient = oldOutdoor end
        end
    end,
})

main:CreateButton({
    Name = "Clear ESP",
    Callback = function()
        dropAll()
        flags.esp = false
        flags.espItems = false
        ensureEspLoop()
    end,
})

local stu = win:CreateTab("Student", 4483362458)

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
        for _, o in ipairs(notebookCache) do
            if o and o.Parent then
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
                        for _, o in ipairs(notebookCache) do
                            if o and o.Parent and (o.Position - hrp.Position).Magnitude < 50 then
                                pcall(function()
                                    firetouchinterest(hrp, o, 0)
                                    task.wait(0.1)
                                    firetouchinterest(hrp, o, 1)
                                end)
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
        if v then
            if not flags.isBaldi then
                Rayfield:Notify({Title = "Always Hear", Content = "only works as Baldi", Duration = 3})
            end
            task.spawn(function()
                while flags.hear do
                    task.wait(mobile and 0.4 or 0.25)
                    local target = char and (char:FindFirstChild("Hearing") or char:FindFirstChild("HearRange"))
                    if target then
                        pcall(function() target.Value = 9999 end)
                    end
                end
            end)
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
                    for val in pairs(hearingValues) do
                        if val.Parent then
                            pcall(function() val.Value = 999 end)
                        end
                    end
                end
            end)
        end
    end,
})

Rayfield:Notify({
    Title = "Baldi Frenzy Menu",
    Content = mobile and "tap the floating button" or "RightShift to open",
    Duration = 4,
})
