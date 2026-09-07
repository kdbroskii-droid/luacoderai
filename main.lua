local LuaCoderAI = {}

LuaCoderAI.Version = 4
LuaCoderAI.Context = {
    Scripts = {},
    Objects = {},
    Systems = {},
    Remotes = {},
    Values = {},
    GUI = {},
    Folders = {},
    Models = {},
    Locations = {},
    Checkpoints = {}
}

local function SafeFullName(instance)
    local success, result = pcall(function()
        return instance:GetFullName()
    end)

    if success then
        return result
    end

    return instance.Name
end

local function HasMeaningfulChildren(instance)
    local success, descendants = pcall(function()
        return instance:GetDescendants()
    end)

    if not success then
        return false
    end

    for _, child in ipairs(descendants) do
        if child:IsA("Script")
            or child:IsA("LocalScript")
            or child:IsA("ModuleScript")
            or child:IsA("RemoteEvent")
            or child:IsA("RemoteFunction")
            or child:IsA("Folder")
            or child:IsA("Model")
            or child:IsA("ValueBase") then
            return true
        end
    end

    return false
end

local function IsCheckpointName(name)
    name = string.lower(tostring(name or ""))

    local keywords = {
        "checkpoint",
        "spawn",
        "waypoint",
        "route",
        "zone",
        "area",
        "portal",
        "teleport",
        "base",
        "farm",
        "rare"
    }

    for _, keyword in ipairs(keywords) do
        if string.find(name, keyword, 1, true) then
            return true
        end
    end

    return false
end

local function GetCategory(instance)
    if instance:IsA("RemoteEvent")
        or instance:IsA("RemoteFunction") then
        return "REMOTES"
    end

    if instance:IsA("ValueBase") then
        return "VALUES"
    end

    if instance:IsA("Script")
        or instance:IsA("LocalScript")
        or instance:IsA("ModuleScript") then
        return "SCRIPTS"
    end

    if instance:IsA("ScreenGui")
        or instance:IsA("SurfaceGui")
        or instance:IsA("BillboardGui")
        or instance:IsA("GuiObject") then
        return "GUI"
    end

    if instance:IsA("Folder") then
        return "FOLDERS"
    end

    if instance:IsA("Model") then
        return "MODELS"
    end

    if instance:IsA("BasePart") then
        if IsCheckpointName(instance.Name)
            or HasMeaningfulChildren(instance) then
            return "CHECKPOINTS"
        end

        return "PARTS"
    end

    return "OBJECTS"
end

local function GetAttributes(instance)
    local result = {}

    local success, attributes = pcall(function()
        return instance:GetAttributes()
    end)

    if success then
        for name, value in pairs(attributes) do
            result[name] = tostring(value)
        end
    end

    return result
end

local function CreateObjectInfo(instance, category)
    local parentName = ""

    pcall(function()
        if instance.Parent then
            parentName = instance.Parent.Name
        end
    end)

    local info = {
        Name = instance.Name,
        Path = SafeFullName(instance),
        ClassName = instance.ClassName,
        Category = category,
        ParentName = parentName,
        Attributes = GetAttributes(instance)
    }

    if instance:IsA("ValueBase") then
        local success, value = pcall(function()
            return instance.Value
        end)

        if success then
            info.Value = tostring(value)
        end
    end

    return info
end

function LuaCoderAI.ClearContext()
    LuaCoderAI.Context = {
        Scripts = {},
        Objects = {},
        Systems = {},
        Remotes = {},
        Values = {},
        GUI = {},
        Folders = {},
        Models = {},
        Locations = {},
        Checkpoints = {}
    }
end

function LuaCoderAI.RegisterScript(data)
    if type(data) ~= "table" then
        return false
    end

    table.insert(
        LuaCoderAI.Context.Scripts,
        data
    )

    return true
end

function LuaCoderAI.RegisterObject(data)
    if type(data) ~= "table" then
        return false
    end

    table.insert(
        LuaCoderAI.Context.Objects,
        data
    )

    return true
end

function LuaCoderAI.ScanDataModel()
    LuaCoderAI.ClearContext()

    local scriptList = {}
    local objectList = {}
    local indexed = {}

    local success, descendants = pcall(function()
        return game:GetDescendants()
    end)

    if not success then
        return scriptList, objectList, indexed
    end

    for _, instance in ipairs(descendants) do
        local category = GetCategory(instance)

        if category ~= "PARTS" then
            local info = CreateObjectInfo(
                instance,
                category
            )

            table.insert(indexed, info)

            if category == "SCRIPTS" then
                table.insert(scriptList, info)
                table.insert(
                    LuaCoderAI.Context.Scripts,
                    info
                )

            elseif category == "REMOTES" then
                table.insert(
                    LuaCoderAI.Context.Remotes,
                    info
                )

            elseif category == "VALUES" then
                table.insert(
                    LuaCoderAI.Context.Values,
                    info
                )

            elseif category == "GUI" then
                table.insert(
                    LuaCoderAI.Context.GUI,
                    info
                )

            elseif category == "FOLDERS" then
                table.insert(
                    LuaCoderAI.Context.Folders,
                    info
                )

            elseif category == "MODELS" then
                table.insert(
                    LuaCoderAI.Context.Models,
                    info
                )

                table.insert(
                    LuaCoderAI.Context.Systems,
                    info
                )

            elseif category == "CHECKPOINTS" then
                table.insert(
                    LuaCoderAI.Context.Checkpoints,
                    info
                )

            else
                table.insert(
                    LuaCoderAI.Context.Objects,
                    info
                )
            end

            table.insert(
                objectList,
                info
            )
        end
    end

    return scriptList, objectList, indexed
end

function LuaCoderAI.ScanGame()
    local scripts, objects = LuaCoderAI.ScanDataModel()

    return scripts, objects
end

local function Normalize(text)
    text = string.lower(
        tostring(text or "")
    )

    text = text:gsub(
        "[%p_]",
        " "
    )

    text = text:gsub(
        "%s+",
        " "
    )

    return text
end

local function GetWords(text)
    local words = {}

    for word in Normalize(text):gmatch("%S+") do
        if #word >= 2 then
            table.insert(
                words,
                word
            )
        end
    end

    return words
end

local function ScoreMatch(query, info)
    local queryWords = GetWords(query)

    local searchable = Normalize(
        tostring(info.Name or "")
        .. " "
        .. tostring(info.Path or "")
        .. " "
        .. tostring(info.ClassName or "")
        .. " "
        .. tostring(info.ParentName or "")
        .. " "
        .. tostring(info.Category or "")
    )

    local score = 0

    for _, word in ipairs(queryWords) do
        if string.find(
            searchable,
            word,
            1,
            true
        ) then
            score = score + 20
        end
    end

    local normalizedName = Normalize(
        info.Name
    )

    local normalizedQuery = Normalize(
        query
    )

    if normalizedName ~= ""
        and string.find(
            normalizedQuery,
            normalizedName,
            1,
            true
        ) then
        score = score + 50
    end

    return score
end

function LuaCoderAI.SearchContext(query, options)
    options = options or {}

    local results = {}
    local searchCheckpoints = options.Checkpoints == true

    local categories = {
        LuaCoderAI.Context.Scripts,
        LuaCoderAI.Context.Remotes,
        LuaCoderAI.Context.Values,
        LuaCoderAI.Context.Systems,
        LuaCoderAI.Context.Folders,
        LuaCoderAI.Context.Models,
        LuaCoderAI.Context.GUI,
        LuaCoderAI.Context.Objects
    }

    if searchCheckpoints then
        table.insert(
            categories,
            LuaCoderAI.Context.Checkpoints
        )
    end

    for _, category in ipairs(categories) do
        for _, info in ipairs(category) do
            local score = ScoreMatch(
                query,
                info
            )

            if score > 0 then
                table.insert(
                    results,
                    {
                        Score = score,
                        Object = info
                    }
                )
            end
        end
    end

    table.sort(
        results,
        function(a, b)
            return a.Score > b.Score
        end
    )

    local limited = {}

    for index, result in ipairs(results) do
        if index <= (options.Limit or 25) then
            table.insert(
                limited,
                result
            )
        end
    end

    return limited
end

function LuaCoderAI.FormatContext(options)
    options = options or {}

    local lines = {}

    table.insert(
        lines,
        "GAME_CONTEXT"
    )

    local function AddCategory(
        name,
        list,
        limit
    )
        table.insert(
            lines,
            name .. "=" .. tostring(#list)
        )

        local count = 0

        for _, info in ipairs(list) do
            count = count + 1

            if count > limit then
                break
            end

            table.insert(
                lines,
                name
                    .. "_ITEM="
                    .. tostring(info.Path)
                    .. "|"
                    .. tostring(info.ClassName)
            )
        end
    end

    AddCategory(
        "SCRIPTS",
        LuaCoderAI.Context.Scripts,
        options.ScriptLimit or 50
    )

    AddCategory(
        "REMOTES",
        LuaCoderAI.Context.Remotes,
        options.RemoteLimit or 50
    )

    AddCategory(
        "VALUES",
        LuaCoderAI.Context.Values,
        options.ValueLimit or 50
    )

    AddCategory(
        "SYSTEMS",
        LuaCoderAI.Context.Systems,
        options.SystemLimit or 50
    )

    AddCategory(
        "FOLDERS",
        LuaCoderAI.Context.Folders,
        options.FolderLimit or 50
    )

    AddCategory(
        "GUI",
        LuaCoderAI.Context.GUI,
        options.GUILimit or 50
    )

    if options.IncludeCheckpoints then
        AddCategory(
            "CHECKPOINTS",
            LuaCoderAI.Context.Checkpoints,
            options.CheckpointLimit or 50
        )
    end

    return table.concat(
        lines,
        "\n"
    )
end

local function ExtractContextMatches(request)
    local includeCheckpoints = false

    local normalized = Normalize(request)

    if string.find(
        normalized,
        "autofarm",
        1,
        true
    )
        or string.find(
            normalized,
            "auto farm",
            1,
            true
        )
        or string.find(
            normalized,
            "goto",
            1,
            true
        )
        or string.find(
            normalized,
            "zone",
            1,
            true
        ) then
        includeCheckpoints = true
    end

    return LuaCoderAI.SearchContext(
        request,
        {
            Checkpoints = includeCheckpoints,
            Limit = 20
        }
    )
end

function LuaCoderAI.Generate(request)
    request = tostring(
        request or ""
    )

    local matches = ExtractContextMatches(
        request
    )

    local contextLines = {}

    table.insert(
        contextLines,
        "REQUEST="
            .. request
    )

    table.insert(
        contextLines,
        "MATCH_COUNT="
            .. tostring(#matches)
    )

    for _, match in ipairs(matches) do
        local info = match.Object

        table.insert(
            contextLines,
            "MATCH="
                .. tostring(match.Score)
                .. "|"
                .. tostring(info.Category)
                .. "|"
                .. tostring(info.Path)
        )
    end

    local generated = {}

    table.insert(
        generated,
        "local Request = {}"
    )

    table.insert(
        generated,
        "Request.Prompt = "
            .. string.format(
                "%q",
                request
            )
    )

    table.insert(
        generated,
        "Request.Matches = {}"
    )

    for _, match in ipairs(matches) do
        local info = match.Object

        table.insert(
            generated,
            "table.insert(Request.Matches, "
                .. "{"
                .. "Name="
                .. string.format(
                    "%q",
                    tostring(info.Name)
                )
                .. ", "
                .. "Path="
                .. string.format(
                    "%q",
                    tostring(info.Path)
                )
                .. ", "
                .. "Category="
                .. string.format(
                    "%q",
                    tostring(info.Category)
                )
                .. "}"
                .. ")"
        )
    end

    table.insert(
        generated,
        ""
    )

    table.insert(
        generated,
        "return Request"
    )

    local code = table.concat(
        generated,
        "\n"
    )

    local data = {
        Request = request,
        Matches = matches,
        Context = table.concat(
            contextLines,
            "\n"
        )
    }

    return code, data
end

function LuaCoderAI.GetGameAPI()
    return {
        Scripts = LuaCoderAI.Context.Scripts,
        Objects = LuaCoderAI.Context.Objects,
        Systems = LuaCoderAI.Context.Systems,
        Remotes = LuaCoderAI.Context.Remotes,
        Values = LuaCoderAI.Context.Values,
        GUI = LuaCoderAI.Context.GUI,
        Folders = LuaCoderAI.Context.Folders,
        Models = LuaCoderAI.Context.Models,
        Checkpoints = LuaCoderAI.Context.Checkpoints
    }
end

return LuaCoderAI
