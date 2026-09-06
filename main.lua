local LuaCoderAI = {}

LuaCoderAI.Context = {
    Scripts = {},
    Objects = {},
    Systems = {},
    Values = {}
}

LuaCoderAI.Knowledge = {
    Actions = {
        "create",
        "find",
        "set",
        "change",
        "increase",
        "decrease",
        "add",
        "remove",
        "enable",
        "disable",
        "test",
        "move"
    },

    RobloxWords = {
        "player",
        "character",
        "humanoid",
        "workspace",
        "folder",
        "model",
        "part",
        "value",
        "attribute",
        "event",
        "remote",
        "script",
        "module",
        "gui",
        "button",
        "tool",
        "npc",
        "bot",
        "round",
        "team",
        "inventory",
        "currency",
        "money",
        "cash",
        "coins",
        "health",
        "speed",
        "position",
        "size"
    }
}

local function normalize(text)
    text = string.lower(tostring(text or ""))
    text = text:gsub("[%p]", " ")
    text = text:gsub("%s+", " ")
    return text:match("^%s*(.-)%s*$")
end

local function splitWords(text)
    local result = {}

    for word in string.gmatch(normalize(text), "%S+") do
        table.insert(result, word)
    end

    return result
end

local function similarity(a, b)
    a = normalize(a)
    b = normalize(b)

    if a == b then
        return 100
    end

    if a == "" or b == "" then
        return 0
    end

    if string.find(a, b, 1, true) then
        return 90
    end

    if string.find(b, a, 1, true) then
        return 90
    end

    local common = 0
    local used = {}

    for i = 1, #a do
        local char = a:sub(i, i)

        for j = 1, #b do
            if not used[j] and char == b:sub(j, j) then
                common = common + 1
                used[j] = true
                break
            end
        end
    end

    return math.floor(
        (common / math.max(#a, #b)) * 100
    )
end

function LuaCoderAI.ClearContext()
    LuaCoderAI.Context.Scripts = {}
    LuaCoderAI.Context.Objects = {}
    LuaCoderAI.Context.Systems = {}
    LuaCoderAI.Context.Values = {}
end

function LuaCoderAI.RegisterScript(data)
    if type(data) ~= "table" then
        return false
    end

    table.insert(LuaCoderAI.Context.Scripts, {
        Name = tostring(data.Name or ""),
        Path = tostring(data.Path or ""),
        ClassName = tostring(data.ClassName or ""),
        Tags = data.Tags or {},
        Keywords = data.Keywords or {},
        Description = data.Description or "",
        API = data.API or {}
    })

    return true
end

function LuaCoderAI.RegisterObject(data)
    if type(data) ~= "table" then
        return false
    end

    table.insert(LuaCoderAI.Context.Objects, {
        Name = tostring(data.Name or ""),
        Path = tostring(data.Path or ""),
        ClassName = tostring(data.ClassName or ""),
        Tags = data.Tags or {}
    })

    return true
end

function LuaCoderAI.RegisterSystem(data)
    if type(data) ~= "table" then
        return false
    end

    table.insert(LuaCoderAI.Context.Systems, {
        Name = tostring(data.Name or ""),
        Path = tostring(data.Path or ""),
        Keywords = data.Keywords or {},
        Description = tostring(data.Description or ""),
        Values = data.Values or {},
        Actions = data.Actions or {}
    })

    return true
end

function LuaCoderAI.RegisterValue(data)
    if type(data) ~= "table" then
        return false
    end

    table.insert(LuaCoderAI.Context.Values, {
        Name = tostring(data.Name or ""),
        Path = tostring(data.Path or ""),
        Type = tostring(data.Type or ""),
        Keywords = data.Keywords or {}
    })

    return true
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
                ClassName = className,
                Tags = {}
            })
        else
            table.insert(objects, {
                Name = object.Name,
                Path = object:GetFullName(),
                ClassName = className,
                Tags = {}
            })
        end
    end

    return scripts, objects
end

function LuaCoderAI.Search(query)
    local results = {}
    local words = splitWords(query)

    local function scoreEntry(entry)
        local score = 0

        local searchable = {
            entry.Name,
            entry.Path,
            entry.Description
        }

        for _, tag in ipairs(entry.Tags or {}) do
            table.insert(searchable, tag)
        end

        for _, keyword in ipairs(entry.Keywords or {}) do
            table.insert(searchable, keyword)
        end

        for _, word in ipairs(words) do
            for _, text in ipairs(searchable) do
                score = score + similarity(word, text)
            end
        end

        return score
    end

    for _, entry in ipairs(LuaCoderAI.Context.Scripts) do
        local score = scoreEntry(entry)

        if score > 0 then
            table.insert(results, {
                Type = "Script",
                Data = entry,
                Score = score
            })
        end
    end

    for _, entry in ipairs(LuaCoderAI.Context.Systems) do
        local score = scoreEntry(entry)

        if score > 0 then
            table.insert(results, {
                Type = "System",
                Data = entry,
                Score = score
            })
        end
    end

    for _, entry in ipairs(LuaCoderAI.Context.Values) do
        local score = scoreEntry(entry)

        if score > 0 then
            table.insert(results, {
                Type = "Value",
                Data = entry,
                Score = score
            })
        end
    end

    table.sort(results, function(a, b)
        return a.Score > b.Score
    end)

    return results
end

function LuaCoderAI.FormatContext()
    local lines = {}

    table.insert(lines, "GAME_CONTEXT")

    table.insert(lines, "SCRIPTS")

    for _, entry in ipairs(LuaCoderAI.Context.Scripts) do
        table.insert(
            lines,
            tostring(entry.Path or entry.Name)
        )
    end

    table.insert(lines, "SYSTEMS")

    for _, entry in ipairs(LuaCoderAI.Context.Systems) do
        table.insert(
            lines,
            tostring(entry.Name)
        )
    end

    table.insert(lines, "VALUES")

    for _, entry in ipairs(LuaCoderAI.Context.Values) do
        table.insert(
            lines,
            tostring(entry.Path or entry.Name)
        )
    end

    return table.concat(lines, "\n")
end

local function parseRequest(input)
    local request = {
        Intent = "unknown",
        Action = "unknown",
        Target = "unknown",
        Property = "unknown",
        Value = nil,
        Subject = "unknown",
        OriginalPrompt = tostring(input or "")
    }

    for line in string.gmatch(
        tostring(input or ""),
        "[^\r\n]+"
    ) do
        local key, value = string.match(
            line,
            "^([A-Z_]+)=(.*)$"
        )

        if key == "INTENT" then
            request.Intent = value
        elseif key == "ACTION" then
            request.Action = value
        elseif key == "TARGET" then
            request.Target = value
        elseif key == "PROPERTY" then
            request.Property = value
        elseif key == "VALUE" then
            request.Value = tonumber(value) or value
        elseif key == "SUBJECT" then
            request.Subject = value
        elseif key == "ORIGINAL" then
            request.OriginalPrompt = value
        end
    end

    return request
end

local function makeFindCode(target)
    return [[
local results = {}

for _, object in ipairs(game:GetDescendants()) do
    if string.find(
        string.lower(object.Name),
        string.lower("]] .. tostring(target) .. [["),
        1,
        true
    ) then
        table.insert(results, object)
    end
end

for _, object in ipairs(results) do
    print(object:GetFullName())
end
]]
end

local function makeSetValueCode(target, value)
    return [[
local targetName = "]] .. tostring(target) .. [["
local newValue = ]] .. tostring(value or 0) .. [[

for _, object in ipairs(game:GetDescendants()) do
    if string.lower(object.Name) == string.lower(targetName) then
        if object:IsA("NumberValue")
            or object:IsA("IntValue") then

            object.Value = newValue
            print("Changed:", object:GetFullName())

            break
        end
    end
end
]]
end

local function makeCreateCode(target)
    return [[
local object = Instance.new("Folder")
object.Name = "]] .. tostring(target) .. [["
object.Parent = workspace
]]
end

function LuaCoderAI.Generate(input)
    local request = parseRequest(input)

    local searchQuery = request.Target

    if searchQuery == "unknown" then
        searchQuery = request.OriginalPrompt
    end

    local matches = LuaCoderAI.Search(searchQuery)

    local bestMatch = matches[1]

    if request.Intent == "find" then
        return makeFindCode(searchQuery), {
            Request = request,
            Matches = matches
        }
    end

    if request.Intent == "set"
        or request.Intent == "modify" then

        return makeSetValueCode(
            searchQuery,
            request.Value
        ), {
            Request = request,
            Matches = matches,
            BestMatch = bestMatch
        }
    end

    if request.Intent == "create" then
        return makeCreateCode(searchQuery), {
            Request = request,
            Matches = matches
        }
    end

    return [[
print("LuaCoderAI needs more information for this request")
]], {
        Request = request,
        Matches = matches
    }
end

return LuaCoderAI
