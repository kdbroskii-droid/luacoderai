local LuaCoderAI = {}

LuaCoderAI.Context = {
    Scripts = {},
    Objects = {}
}

LuaCoderAI.Knowledge = {
    Services = {
        "Players",
        "Workspace",
        "ReplicatedStorage",
        "ServerStorage",
        "ServerScriptService",
        "StarterGui",
        "StarterPlayer",
        "TweenService",
        "RunService",
        "UserInputService",
        "CollectionService",
        "PathfindingService",
        "PhysicsService",
        "HttpService",
        "DataStoreService",
        "MarketplaceService",
        "Lighting",
        "SoundService"
    },

    Concepts = {
        "instances",
        "events",
        "attributes",
        "values",
        "tables",
        "functions",
        "modules",
        "remote events",
        "remote functions",
        "players",
        "characters",
        "humanoids",
        "tools",
        "gui",
        "animation",
        "pathfinding",
        "raycasting",
        "projectiles",
        "inventory",
        "currency",
        "rounds",
        "teams",
        "npcs",
        "bots",
        "debugging",
        "testing"
    }
}

function LuaCoderAI.ClearContext()
    LuaCoderAI.Context.Scripts = {}
    LuaCoderAI.Context.Objects = {}
end

function LuaCoderAI.RegisterScript(data)
    if type(data) == "table" then
        table.insert(LuaCoderAI.Context.Scripts, data)
        return true
    end

    return false
end

function LuaCoderAI.RegisterObject(data)
    if type(data) == "table" then
        table.insert(LuaCoderAI.Context.Objects, data)
        return true
    end

    return false
end

function LuaCoderAI.ScanGame()
    local scripts = {}
    local objects = {}

    local ok, descendants = pcall(function()
        return game:GetDescendants()
    end)

    if not ok then
        return scripts, objects
    end

    for _, object in ipairs(descendants) do
        local className = object.ClassName

        if className == "Script"
            or className == "LocalScript"
            or className == "ModuleScript" then

            table.insert(scripts, {
                Name = object.Name,
                Path = object:GetFullName(),
                ClassName = className
            })

        else
            table.insert(objects, {
                Name = object.Name,
                Path = object:GetFullName(),
                ClassName = className
            })
        end
    end

    return scripts, objects
end

function LuaCoderAI.FormatContext()
    local lines = {}

    table.insert(lines, "SCRIPTS")

    for _, scriptInfo in ipairs(LuaCoderAI.Context.Scripts) do
        table.insert(
            lines,
            tostring(scriptInfo.Path or scriptInfo.Name)
        )
    end

    table.insert(lines, "")
    table.insert(lines, "OBJECTS")

    for _, objectInfo in ipairs(LuaCoderAI.Context.Objects) do
        table.insert(
            lines,
            tostring(objectInfo.Path or objectInfo.Name)
        )
    end

    return table.concat(lines, "\n")
end

local function parseTranslatedRequest(text)
    local result = {
        Intent = "unknown",
        Action = "unknown",
        Target = "unknown",
        Property = "unknown",
        Value = nil,
        Subject = "unknown",
        Confidence = 0,
        Original = "",
        Matches = {}
    }

    text = tostring(text or "")

    for line in string.gmatch(text, "[^\n]+") do
        local key, value = string.match(line, "^([A-Z_]+)=(.*)$")

        if key then
            if key == "INTENT" then
                result.Intent = value
            elseif key == "ACTION" then
                result.Action = value
            elseif key == "TARGET" then
                result.Target = value
            elseif key == "PROPERTY" then
                result.Property = value
            elseif key == "VALUE" then
                result.Value = tonumber(value) or value
            elseif key == "SUBJECT" then
                result.Subject = value
            elseif key == "CONFIDENCE" then
                result.Confidence = tonumber(value) or 0
            elseif key == "ORIGINAL" then
                result.Original = value
            end
        end
    end

    return result
end

local function makeVariable(name)
    name = tostring(name or "object")
    name = name:gsub("[^%w_]", "_")
    name = name:gsub("^%d", "_%0")

    if name == "" then
        name = "object"
    end

    return name
end

local function generateCreate(request)
    if request.Target == "folder" then
        return [[local folder = Instance.new("Folder")
folder.Name = "NewFolder"
folder.Parent = workspace]]
    end

    if request.Target == "gui" then
        return [[local screenGui = Instance.new("ScreenGui")
screenGui.Name = "NewGui"
screenGui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")]]
    end

    return [[local newObject = Instance.new("Folder")
newObject.Name = "NewObject"
newObject.Parent = workspace]]
end

local function generateFind(request)
    local target = request.Target

    return [[local function findMatchingObjects()
    local results = {}

    for _, object in ipairs(game:GetDescendants()) do
        if string.find(
            string.lower(object.Name),
            string.lower("]] .. target .. [["),
            1,
            true
        ) then
            table.insert(results, object)
        end
    end

    return results
end

local results = findMatchingObjects()

for _, object in ipairs(results) do
    print(object:GetFullName())
end]]
end

local function generateModify(request)
    local property = request.Property
    local value = request.Value or 0

    if property == "speed" then
        return [[local character = game:GetService("Players").LocalPlayer.Character

if character then
    local humanoid = character:FindFirstChildOfClass("Humanoid")

    if humanoid then
        humanoid.WalkSpeed = ]] .. tostring(value) .. [[
    end
end]]
    end

    if property == "health" then
        return [[local character = game:GetService("Players").LocalPlayer.Character

if character then
    local humanoid = character:FindFirstChildOfClass("Humanoid")

    if humanoid then
        humanoid.Health = ]] .. tostring(value) .. [[
    end
end]]
    end

    return [[local targetValue = ]] .. tostring(value) .. [[
print("Modify request prepared:", targetValue)]]
end

local function generateTest(request)
    return [[local results = {}

for _, object in ipairs(game:GetDescendants()) do
    if object.Name then
        table.insert(results, object:GetFullName())
    end
end

print("Test completed")
print("Objects indexed:", #results)]]
end

function LuaCoderAI.Generate(input)
    local request = parseTranslatedRequest(input)

    if request.Intent == "create" then
        return generateCreate(request), request
    end

    if request.Intent == "find" then
        return generateFind(request), request
    end

    if request.Intent == "modify"
        or request.Intent == "set"
        or request.Intent == "increase"
        or request.Intent == "decrease" then

        return generateModify(request), request
    end

    if request.Intent == "test" then
        return generateTest(request), request
    end

    local code = [[print("LuaCoderAI could not select a generation pattern yet")]]
    return code, request
end

return LuaCoderAI    text = text:gsub(from, to)
end

text = text:gsub("[%p]", " ")
text = text:gsub("%s+", " ")
text = text:gsub("^%s+", "")
text = text:gsub("%s+$", "")

return text

end

---

-- KNOWLEDGE

local Actions = {
get = {
"get me", "give me", "show me", "find me",
"retrieve", "fetch", "display", "search",
"get", "give", "show", "find", "grab",
"read", "what is", "what are", "check",
},

set = {
    "change", "modify", "update", "adjust",
    "configure", "replace", "edit", "set",
},

create = {
    "create a", "make a", "build a",
    "generate a", "create", "make",
    "build", "generate", "spawn", "add",
},

remove = {
    "get rid of", "remove", "delete",
    "destroy", "erase", "clear",
},

enable = {
    "turn on", "enable", "activate", "start",
},

disable = {
    "turn off", "disable", "deactivate", "stop",
},

move = {
    "teleport", "move", "position", "send", "bring",
},

wait = {
    "wait", "pause", "delay", "sleep", "hold",
},

print = {
    "print", "output", "log", "debug",
},

check = {
    "see if", "check", "test", "detect",
    "verify", "determine",
},

}

local Targets = {
player = {
"localplayer", "local player", "player",
"players", "user", "person",
},

character = {
    "player character", "character", "avatar",
},

humanoid = {
    "humanoid",
},

npc = {
    "non player character", "npc", "enemy", "bot",
},

part = {
    "basepart", "part", "block", "brick",
},

model = {
    "model", "group",
},

folder = {
    "folder", "directory",
},

tool = {
    "tool", "item",
},

gui = {
    "screengui", "screen gui", "interface",
    "menu", "gui", "ui",
},

button = {
    "textbutton", "imagebutton", "text button",
    "image button", "button",
},

frame = {
    "frame", "panel",
},

textlabel = {
    "textlabel", "text label", "label",
},

textbox = {
    "textbox", "text box",
},

camera = {
    "current camera", "camera",
},

sound = {
    "sound", "audio", "music",
},

remoteevent = {
    "remoteevent", "remote event",
},

remotefunction = {
    "remotefunction", "remote function",
},

team = {
    "teams", "team",
},

datastore = {
    "datastore", "data store",
},

}

local Properties = {
name = {
"player name", "name",
},

displayname = {
    "display name", "displayname",
},

userid = {
    "user id", "userid", "player id",
},

health = {
    "hitpoints", "health", "hp",
},

maxhealth = {
    "maximum health", "max health", "maxhealth",
},

walkspeed = {
    "movement speed", "walk speed",
    "walkspeed", "move speed", "speed",
},

jumppower = {
    "jump power", "jumppower",
},

jumpheight = {
    "jump height", "jumpheight",
},

position = {
    "coordinates", "location", "position",
},

cframe = {
    "rotation", "cframe",
},

size = {
    "dimensions", "scale", "size",
},

color = {
    "colour", "color",
},

transparency = {
    "transparent", "invisible", "transparency",
},

cancollide = {
    "can collide", "collision", "cancollide",
},

anchored = {
    "anchored", "anchor", "freeze",
},

visible = {
    "visibility", "visible", "hide", "show",
},

enabled = {
    "enabled", "enable", "disable",
},

text = {
    "button text", "label text", "message", "text",
},

volume = {
    "sound volume", "audio volume", "volume",
},

playbackspeed = {
    "playback speed", "sound speed",
},

}

local Events = {
player_added = {
"when a player joins", "player joins",
"player joined", "someone joins",
},

player_removing = {
    "when a player leaves", "player leaves", "player left",
},

character_added = {
    "when character spawns", "character spawns",
    "character spawned",
},

touched = {
    "when the part is touched", "when touched",
    "part touched", "touch",
},

clicked = {
    "when the button is clicked",
    "button clicked", "when clicked",
},

input_began = {
    "when a key is pressed", "key pressed", "input began",
},

input_ended = {
    "when a key is released", "key released", "input ended",
},

died = {
    "when the player dies", "when character dies",
    "player died", "humanoid died",
},

heartbeat = {
    "every frame", "each frame", "heartbeat",
},

renderstepped = {
    "every render frame", "render stepped", "renderstepped",
},

}

---

-- MATCHER

local Matcher = {}

function Matcher.Find(text, categories)
local bestMatch = nil
local bestLength = 0

for name, phrases in pairs(categories) do
    for _, phrase in ipairs(phrases) do
        local phraseLower = string.lower(phrase)

        if string.find(text, phraseLower, 1, true) then
            if #phrase > bestLength then
                bestMatch = name
                bestLength = #phrase
            end
        end
    end
end

return bestMatch, bestLength

end

---

-- VALUE PARSER

local ValueParser = {}

function ValueParser.Number(text)
local number = string.match(
text,
"%-?%d+%.?%d*"
)

if number then
    return tonumber(number)
end

return nil

end

function ValueParser.Boolean(text)
if string.find(text, "turn on", 1, true)
or string.find(text, "enable", 1, true)
or string.find(text, "true", 1, true) then

    return true
end

if string.find(text, "turn off", 1, true)
    or string.find(text, "disable", 1, true)
    or string.find(text, "false", 1, true) then

    return false
end

return nil

end

---

-- PARSER

local Parser = {}

function Parser.Parse(request)
local text = Normalizer.Normalize(request)

local action = Matcher.Find(text, Actions)
local target = Matcher.Find(text, Targets)
local property = Matcher.Find(text, Properties)
local event = Matcher.Find(text, Events)

local value = ValueParser.Number(text)

if value == nil then
    value = ValueParser.Boolean(text)
end

return {
    Request = request,
    Normalized = text,

    Action = action,
    Target = target,
    Property = property,
    Event = event,
    Value = value,
}

end

---

-- TEMPLATE ENGINE

local TemplateEngine = {}

function TemplateEngine.Render(code, variables)
for name, value in pairs(variables or {}) do
code = string.gsub(
code,
"{{" .. name .. "}}",
tostring(value)
)
end

return code

end

---

-- CODE TEMPLATES

local Templates = {

Get = {

    health = [[

local Players = game:GetService("Players")

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")

print(Humanoid.Health)
]],

    walkspeed = [[

local Players = game:GetService("Players")

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")

print(Humanoid.WalkSpeed)
]],

    name = [[

local Player = game:GetService("Players").LocalPlayer

print(Player.Name)
]],

    userid = [[

local Player = game:GetService("Players").LocalPlayer

print(Player.UserId)
]],

},

Set = {

    walkspeed = [[

local Players = game:GetService("Players")

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")

Humanoid.WalkSpeed = {{VALUE}}
]],

    health = [[

local Players = game:GetService("Players")

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")

Humanoid.Health = {{VALUE}}
]],

    jumppower = [[

local Players = game:GetService("Players")

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")

Humanoid.JumpPower = {{VALUE}}
]],

    maxhealth = [[

local Players = game:GetService("Players")

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")

Humanoid.MaxHealth = {{VALUE}}
]],

},

Create = {

    part = [[

local Part = Instance.new("Part")

Part.Name = "NewPart"
Part.Size = Vector3.new(4, 1, 4)
Part.Position = Vector3.new(0, 5, 0)

Part.Parent = workspace
]],

    folder = [[

local Folder = Instance.new("Folder")

Folder.Name = "NewFolder"
Folder.Parent = workspace
]],

    button = [[

local Button = Instance.new("TextButton")

Button.Name = "NewButton"
Button.Size = UDim2.fromOffset(200, 50)
Button.Text = "Button"

Button.Parent = script.Parent
]],

    frame = [[

local Frame = Instance.new("Frame")

Frame.Name = "NewFrame"
Frame.Size = UDim2.fromOffset(400, 300)

Frame.Parent = script.Parent
]],

    textlabel = [[

local Label = Instance.new("TextLabel")

Label.Name = "NewLabel"
Label.Size = UDim2.fromOffset(200, 50)
Label.Text = "Hello"

Label.Parent = script.Parent
]],

    remoteevent = [[

local ReplicatedStorage =
game:GetService("ReplicatedStorage")

local Remote =
Instance.new("RemoteEvent")

Remote.Name = "NewRemote"
Remote.Parent = ReplicatedStorage
]],

    sound = [[

local Sound = Instance.new("Sound")

Sound.Name = "NewSound"

Sound.Parent = workspace
]],

},

Events = {

    player_added = [[

local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(Player)

print(Player.Name .. " joined")

end)
]],

    player_removing = [[

local Players = game:GetService("Players")

Players.PlayerRemoving:Connect(function(Player)

print(Player.Name .. " left")

end)
]],

    character_added = [[

local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(Player)

Player.CharacterAdded:Connect(function(Character)

    -- Character spawned

end)

end)
]],

    touched = [[

local Part = script.Parent

Part.Touched:Connect(function(Hit)

local Character = Hit.Parent

if Character then

    local Humanoid =
        Character:FindFirstChildOfClass("Humanoid")

    if Humanoid then

        -- Code here

    end

end

end)
]],

    clicked = [[

local Button = script.Parent

Button.Activated:Connect(function()

-- Code here

end)
]],

    died = [[

local Humanoid = script.Parent

Humanoid.Died:Connect(function()

-- Code here

end)
]],

    heartbeat = [[

local RunService =
game:GetService("RunService")

RunService.Heartbeat:Connect(function(deltaTime)

-- Code here

end)
]],

    renderstepped = [[

local RunService =
game:GetService("RunService")

RunService.RenderStepped:Connect(function(deltaTime)

-- Client frame code

end)
]],

}

}

---

-- GAME CONTEXT

LuaCoderAI.GameContext = {
Scripts = {},
Objects = {},
Services = {},
APIs = {},
}

function LuaCoderAI.RegisterScript(data)
table.insert(
LuaCoderAI.GameContext.Scripts,
data
)

return data

end

function LuaCoderAI.RegisterObject(data)
if not data or not data.Name then
return nil
end

LuaCoderAI.GameContext.Objects[data.Name] = data

return data

end

function LuaCoderAI.RegisterService(data)
table.insert(
LuaCoderAI.GameContext.Services,
data
)

return data

end

function LuaCoderAI.RegisterAPI(data)
if not data or not data.Name then
return nil
end

LuaCoderAI.GameContext.APIs[data.Name] = data

return data

end

function LuaCoderAI.ClearContext()
LuaCoderAI.GameContext = {
Scripts = {},
Objects = {},
Services = {},
APIs = {},
}
end

---

-- FORMAT CONTEXT

function LuaCoderAI.FormatContext()
local output = {}

table.insert(
    output,
    "=== LUA CODER AI GAME CONTEXT ==="
)

table.insert(output, "")
table.insert(output, "=== SCRIPTS ===")

for _, info in ipairs(
    LuaCoderAI.GameContext.Scripts
) do

    table.insert(
        output,
        tostring(info.Path or info.Name or "Unknown")
    )
end

table.insert(output, "")
table.insert(output, "=== OBJECTS ===")

for name, info in pairs(
    LuaCoderAI.GameContext.Objects
) do

    table.insert(
        output,
        tostring(info.Path or name)
    )
end

table.insert(output, "")
table.insert(output, "=== SERVICES ===")

for _, info in ipairs(
    LuaCoderAI.GameContext.Services
) do

    table.insert(
        output,
        tostring(info.Name or info.Path or "Unknown")
    )
end

table.insert(output, "")
table.insert(output, "=== APIS ===")

for name, info in pairs(
    LuaCoderAI.GameContext.APIs
) do

    table.insert(
        output,
        tostring(info.Path or name)
    )
end

return table.concat(output, "\n")

end

---

-- GAME HIERARCHY SCANNER

function LuaCoderAI.GetFullPath(object)
local success, result = pcall(function()
return object:GetFullName()
end)

if success then
    return result
end

return object.Name

end

function LuaCoderAI.ScanGame(roots)
local scripts = {}
local objects = {}

if not roots then
    roots = {
        workspace,
        game:GetService("ReplicatedStorage"),
        game:GetService("StarterGui"),
    }
end

for _, root in ipairs(roots) do

    local success, descendants = pcall(function()
        return root:GetDescendants()
    end)

    if success and descendants then

        for _, object in ipairs(descendants) do

            local info = {
                Name = object.Name,
                ClassName = object.ClassName,
                Path = LuaCoderAI.GetFullPath(object),
            }

            if object:IsA("Script")
                or object:IsA("LocalScript")
                or object:IsA("ModuleScript") then

                table.insert(
                    scripts,
                    info
                )

            end

            if object:IsA("RemoteEvent")
                or object:IsA("RemoteFunction")
                or object:IsA("ScreenGui")
                or object:IsA("TextButton")
                or object:IsA("ImageButton")
                or object:IsA("Tool")
                or object:IsA("Model") then

                table.insert(
                    objects,
                    info
                )

            end

        end

    end

end

return scripts, objects

end

---

-- GENERATOR

function LuaCoderAI.Generate(request)
local data = Parser.Parse(request)
local code = nil

if data.Event then
    code = Templates.Events[data.Event]
end

if not code and data.Action == "get" then
    code = Templates.Get[data.Property]
end

if not code and data.Action == "set" then
    code = Templates.Set[data.Property]
end

if not code and data.Action == "create" then
    code = Templates.Create[data.Target]
end

if not code then

    code =
        "-- LuaCoderAI could not find a matching template yet.\n\n"
        .. "-- Request:\n"
        .. tostring(request)
        .. "\n\n"
        .. "-- Detected Action: "
        .. tostring(data.Action)
        .. "\n"
        .. "-- Detected Target: "
        .. tostring(data.Target)
        .. "\n"
        .. "-- Detected Property: "
        .. tostring(data.Property)
        .. "\n"
        .. "-- Detected Event: "
        .. tostring(data.Event)

end

code = TemplateEngine.Render(
    code,
    {
        VALUE = data.Value or "VALUE"
    }
)

return code, data

end

---

-- PUBLIC KNOWLEDGE ACCESS

LuaCoderAI.Actions = Actions
LuaCoderAI.Targets = Targets
LuaCoderAI.Properties = Properties
LuaCoderAI.Events = Events
LuaCoderAI.Templates = Templates

LuaCoderAI.Normalize = Normalizer.Normalize
LuaCoderAI.Parse = Parser.Parse

---

-- VERSION

LuaCoderAI.Version = "1.0.0"

return LuaCoderAI
