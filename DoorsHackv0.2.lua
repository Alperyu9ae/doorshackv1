local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/refs/heads/main/"

local ExecutorName = identifyexecutor and identifyexecutor() or "Unknown Executor"

local function GetRequestFunction()
    if syn and syn.request then
        return syn.request
    end

    if http and http.request then
        return http.request
    end

    if request then
        return request
    end

    if http_request then
        return http_request
    end

    if fluxus and fluxus.request then
        return fluxus.request
    end

    return nil
end

local function GetResponseBody(Response)
    if Response == nil then
        return nil
    end

    if type(Response) == "string" then
        return Response
    end

    if type(Response) ~= "table" then
        return nil
    end

    local BodyFields = {
        "Body",
        "body",
        "ResponseBody",
        "responseBody",
        "Content",
        "content",
        "Data",
        "data",
        "Response",
        "response"
    }

    for _, Field in ipairs(BodyFields) do
        local Value = Response[Field]

        if Value ~= nil then
            if type(Value) == "string" then
                return Value
            end

            if type(Value) == "table" then
                local Success, Encoded = pcall(function()
                    return game:GetService("HttpService"):JSONEncode(Value)
                end)

                if Success then
                    return Encoded
                end
            end
        end
    end

    return nil
end

local function DownloadSource(URL)
    local RequestFunction = GetRequestFunction()

    if RequestFunction then
        local Success, Response = pcall(function()
            return RequestFunction({
                Url = URL,
                Method = "GET",
                Headers = {
                    ["Accept"] = "*/*"
                }
            })
        end)

        if Success then
            local Body = GetResponseBody(Response)

            if type(Body) == "string" and #Body > 0 then
                return Body
            end
        end
    end

    local Success, Body = pcall(function()
        return game:HttpGet(URL)
    end)

    if Success and type(Body) == "string" and #Body > 0 then
        return Body
    end

    return nil
end

local function LoadObsidian()
    local Source = DownloadSource(repo .. "Library.lua")

    if type(Source) ~= "string" or #Source == 0 then
        return nil, "Could not download Obsidian Library.lua"
    end

    local Loader, CompileError = loadstring(Source)

    if type(Loader) ~= "function" then
        return nil,
            "Could not compile Obsidian Library.lua: "
            .. tostring(CompileError)
    end

    local Success, Library = pcall(Loader)

    if not Success then
        return nil,
            "Could not initialize Obsidian Library.lua: "
            .. tostring(Library)
    end

    return Library
end

local AuthLibrary, AuthLibraryError = LoadObsidian()

if not AuthLibrary then
    error("DoorsHack: " .. tostring(AuthLibraryError))
end

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Player = Players.LocalPlayer

local KEY_SERVER = "https://doorschackkey.bonto.run"
local KEY_VERIFY_URL = KEY_SERVER .. "/verify"
local KEY_GET_URL = KEY_SERVER

local BYPASS_USERNAME = "alperyuHacker11ae"
local BYPASS_FILE = "BypassKeyCheck.txt"

local function AuthNotify(Title, Description)
    pcall(function()
        AuthLibrary:Notify({
            Title = tostring(Title),
            Description = tostring(Description),
            Time = 4,
        })
    end)
end

local function CopyText(Text)
    local Copied = false

    pcall(function()
        if setclipboard then
            setclipboard(Text)
            Copied = true
        end
    end)

    if not Copied then
        pcall(function()
            if syn and syn.setclipboard then
                syn.setclipboard(Text)
                Copied = true
            end
        end)
    end

    if not Copied then
        pcall(function()
            if toclipboard then
                toclipboard(Text)
                Copied = true
            end
        end)
    end

    return Copied
end

local function VerifyKey(Key)
    local RequestFunction = GetRequestFunction()

    if not RequestFunction then
        return false, "Your executor does not support HTTP requests."
    end

    local Success, Response = pcall(function()
        return RequestFunction({
            Url = KEY_VERIFY_URL,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
                ["Accept"] = "application/json"
            },
            Body = HttpService:JSONEncode({
                key = tostring(Key)
            })
        })
    end)

    if not Success then
        return false, "Request failed: " .. tostring(Response)
    end

    local Body = GetResponseBody(Response)

    if not Body then
        if type(Response) == "table" then
            local Debug = {}

            for KeyName, Value in pairs(Response) do
                table.insert(
                    Debug,
                    tostring(KeyName) .. "=" .. tostring(Value)
                )
            end

            if #Debug > 0 then
                return false,
                    "No response body. Returned: "
                    .. table.concat(Debug, " | ")
            end
        end

        return false, "Server returned no response body."
    end

    local DecodeSuccess, Data = pcall(function()
        return HttpService:JSONDecode(Body)
    end)

    if not DecodeSuccess then
        return false, "Server returned invalid JSON."
    end

    if type(Data) ~= "table" then
        return false, "Server returned an invalid response."
    end

    if Data.valid == true then
        return true, "Key is valid!"
    end

    return false, tostring(Data.error or "Invalid key.")
end

local function ReadBypassFile()
    if Player.Name ~= BYPASS_USERNAME then
        return false
    end

    if not readfile or not isfile then
        return false
    end

    local Success, Exists = pcall(function()
        return isfile(BYPASS_FILE)
    end)

    if not Success or not Exists then
        return false
    end

    local ReadSuccess, Content = pcall(function()
        return readfile(BYPASS_FILE)
    end)

    if not ReadSuccess then
        return false
    end

    return tostring(Content)
        :lower()
        :match("^%s*true%s*$") ~= nil
end

local function WriteBypassFile(Value)
    if Player.Name ~= BYPASS_USERNAME then
        return false
    end

    if not writefile then
        return false
    end

    local Success = pcall(function()
        writefile(
            BYPASS_FILE,
            Value and "true" or "false"
        )
    end)

    return Success
end

local function CreateMainLibrary()
    local Library, ErrorMessage = LoadObsidian()

    if not Library then
        warn("DoorsHack: " .. tostring(ErrorMessage))
        return nil
    end

    return Library
end

local function CreateAddon(FileName, Library)
    local Source =
        DownloadSource(repo .. "addons/" .. FileName)

    if not Source then
        return nil
    end

    local Loader = loadstring(Source)

    if type(Loader) ~= "function" then
        return nil
    end

    local Success, Addon = pcall(Loader)

    if not Success then
        return nil
    end

    if Addon.SetLibrary then
        pcall(function()
            Addon:SetLibrary(Library)
        end)
    end

    return Addon
end

local function LoadMainUI(
    Library,
    SaveManager,
    ThemeManager
)
    local Success, ErrorMessage = pcall(function()

        local function Notify(Title, Description)
            pcall(function()
                Library:Notify({
                    Title = tostring(Title),
                    Description = tostring(Description),
                    Time = 4,
                })
            end)
        end

        local Loading = Library:CreateLoading({
            Title = "DoorsHack",
            Icon = 11358524205,
            TotalSteps = 4
        })

        task.wait(0.2)

        Loading:SetMessage("Initializing...")
        Loading:SetDescription(
            "Waiting for game to load..."
        )

        task.wait(0.5)

        Loading:ShowSidebarPage(true)

        task.wait(0.5)

        Loading:SetCurrentStep(1)
        Loading:SetDescription(
            "Loading configuration..."
        )

        if Loading.Sidebar then
            pcall(function()
                Loading.Sidebar:AddLabel(
                    "User: " .. tostring(Player.Name)
                )

                Loading.Sidebar:AddLabel(
                    "Version: v0.2"
                )
            end)
        end

        task.wait(1)

        Loading:SetCurrentStep(2)

        if Loading.Sidebar then
            pcall(function()
                Loading.Sidebar:AddLabel(" ")
                Loading.Sidebar:AddLabel(
                    "Downloading Obsidian Library"
                )
            end)
        end

        task.wait(1.5)

        Loading:SetCurrentStep(3)

        if Loading.Sidebar then
            pcall(function()
                Loading.Sidebar:AddLabel(
                    "Downloading Hacks"
                )
            end)
        end

        task.wait(1.5)

        Loading:SetCurrentStep(4)
        Loading:SetDescription(
            "Ready to start!"
        )

        task.wait(0.5)

        Loading:Continue()

        task.wait(0.5)

        local Window = Library:CreateWindow({
            Title = "DoorsHack",
            Footer =
                "version: 0.2 | Executor: "
                .. ExecutorName,
            Resizable = true,
            Center = true,
            Icon = 11358524205,
            NotifySide = "Right",
            ShowCustomCursor = true,
        })

        local Tabs = {
            Main = Window:AddTab(
                "Main",
                "user"
            ),

            Visuals = Window:AddTab(
                "Visuals",
                "eye"
            ),

            Troll = Window:AddTab(
                "Troll",
                "zap"
            ),

            ["UI Settings"] = Window:AddTab(
                "UI Settings",
                "settings"
            ),
        }

        local MainGroup =
            Tabs.Main:AddLeftGroupbox(
                "Player"
            )

        local MovementGroup =
            Tabs.Main:AddRightGroupbox(
                "Movement"
            )

        local AutosGroup =
            Tabs.Main:AddLeftGroupbox(
                "Auto's"
            )

        local VisualGroup =
            Tabs.Visuals:AddLeftGroupbox(
                "ESP"
            )

        local NotifierGroup =
            Tabs.Visuals:AddRightGroupbox(
                "Entity Notifier"
            )

        local TrollGroup =
            Tabs.Troll:AddLeftGroupbox(
                "Troll"
            )

        local PromptGroup =
            Tabs.Troll:AddRightGroupbox(
                "Prompts"
            )

        local MenuGroup =
            Tabs["UI Settings"]:AddLeftGroupbox(
                "Menu"
            )

        local ConfigGroup =
            Tabs["UI Settings"]:AddRightGroupbox(
                "Configuration"
            )

        ----------------------------------------------------------------
-- OXYGEN DISPLAY
----------------------------------------------------------------

local OxygenLabel = Library:AddDraggableLabel("Oxygen : ??")

pcall(function()
    OxygenLabel:SetVisible(false)
end)

local OxygenDisplayEnabled = false
local OxygenConnection

local function SetOxygenLabelVisible(Value)
    pcall(function()
        OxygenLabel:SetVisible(Value)
    end)
end

local function SetOxygenText(Text)
    pcall(function()
        OxygenLabel:SetText(Text)
    end)
end

local function UpdateOxygenDisplay()
    if not OxygenDisplayEnabled then
        return
    end

    local PlayerModel =
        workspace:FindFirstChild(Player.Name)

    if not PlayerModel then
        SetOxygenText("Oxygen : ??")
        return
    end

    local Oxygen =
        PlayerModel:GetAttribute("Oxygen")

    if Oxygen == nil then
        SetOxygenText("Oxygen : ??")
    else
        SetOxygenText(
            "Oxygen : " .. tostring(math.round(Oxygen))
        )
    end
end

local function SetOxygenDisplay(State)
    OxygenDisplayEnabled = State

    SetOxygenLabelVisible(State)

    if State then
        UpdateOxygenDisplay()
    end
end

OxygenConnection =
    RunService.Heartbeat:Connect(function()
        if OxygenDisplayEnabled then
            UpdateOxygenDisplay()
        end
    end)

MainGroup:AddToggle(
    "OxygenLevelShower",
    {
        Text = "Oxygen Level Shower",
        Default = false,

        Callback = function(Value)
            SetOxygenDisplay(Value == true)
        end,
    }
)

        ----------------------------------------------------------------
        -- SPEED
        ----------------------------------------------------------------

        _G.CurrentSpeed =
            tonumber(_G.CurrentSpeed) or 16

        if _G.CurrentSpeed < 1 then
            _G.CurrentSpeed = 16
        end

        MovementGroup:AddSlider(
            "SpeedSlider",
            {
                Text = "Speed",
                Default = 16,
                Min = 1,
                Max = 200,
                Rounding = 0,
                Suffix = " Speed",

                Callback = function(Value)
                    local NewSpeed =
                        tonumber(Value)

                    if not NewSpeed then
                        NewSpeed = 16
                    end

                    if NewSpeed < 1 then
                        NewSpeed = 1
                    end

                    if NewSpeed > 200 then
                        NewSpeed = 200
                    end

                    _G.CurrentSpeed = NewSpeed
                end,
            }
        )

        local function ApplySpeed()
            local Character =
                Player.Character

            if not Character then
                return
            end

            local Humanoid =
                Character:FindFirstChildOfClass(
                    "Humanoid"
                )

            if not Humanoid
                or Humanoid.Health <= 0 then
                return
            end

            local Speed =
                tonumber(_G.CurrentSpeed)

            if not Speed or Speed < 1 then
                Speed = 16
                _G.CurrentSpeed = Speed
            end

            if Speed > 200 then
                Speed = 200
                _G.CurrentSpeed = Speed
            end

            if Humanoid.WalkSpeed ~= Speed then
                Humanoid.WalkSpeed = Speed
            end
        end

        RunService.Heartbeat:Connect(
            ApplySpeed
        )

        ----------------------------------------------------------------
        -- AUTO'S
        ----------------------------------------------------------------

        local AutoKeyObtainEnabled = false
        local AutoKeyObtainConnection
        local AutoKeyObtainChildConnection
        local AutoKeyObtainProcessed = {}

        local function TriggerKeyObtain(Object)
            if not AutoKeyObtainEnabled then
                return
            end

            if not Object
                or not Object.Parent
                or Object.Name ~= "KeyObtain" then
                return
            end

            if AutoKeyObtainProcessed[Object] then
                return
            end

            AutoKeyObtainProcessed[Object] = true

            for _, Descendant in ipairs(
                Object:GetDescendants()
            ) do
                if Descendant:IsA(
                    "ProximityPrompt"
                )
                    and Descendant.Name
                        == "ModulePrompt" then

                    pcall(function()
                        fireproximityprompt(
                            Descendant
                        )
                    end)
                end
            end
        end

        local function StopAutoKeyObtain()
            if AutoKeyObtainConnection then
                AutoKeyObtainConnection:Disconnect()
                AutoKeyObtainConnection = nil
            end

            if AutoKeyObtainChildConnection then
                AutoKeyObtainChildConnection:Disconnect()
                AutoKeyObtainChildConnection = nil
            end

            table.clear(
                AutoKeyObtainProcessed
            )
        end

        local function StartAutoKeyObtain()
            StopAutoKeyObtain()

            for _, Object in ipairs(
                workspace:GetDescendants()
            ) do
                if Object:IsA("Model")
                    and Object.Name == "KeyObtain" then

                    TriggerKeyObtain(Object)
                end
            end

            AutoKeyObtainConnection =
                workspace.DescendantAdded:Connect(
                    function(Object)
                        if not AutoKeyObtainEnabled then
                            return
                        end

                        if Object:IsA("Model")
                            and Object.Name
                                == "KeyObtain" then

                            task.defer(function()
                                TriggerKeyObtain(Object)
                            end)
                        end
                    end
                )

            AutoKeyObtainChildConnection =
                workspace.DescendantAdded:Connect(
                    function(Object)
                        if not AutoKeyObtainEnabled then
                            return
                        end

                        if Object.Name
                            == "ModulePrompt"
                            and Object:IsA(
                                "ProximityPrompt"
                            ) then

                            local KeyObtain =
                                Object:FindFirstAncestor(
                                    "KeyObtain"
                                )

                            if KeyObtain then
                                task.defer(function()
                                    TriggerKeyObtain(
                                        KeyObtain
                                    )
                                end)
                            end
                        end
                    end
                )
        end

        AutosGroup:AddToggle(
            "AutoKeyObtain",
            {
                Text = "Auto KeyObtain",
                Default = false,

                Callback = function(Value)
                    AutoKeyObtainEnabled =
                        Value

                    if Value then
                        StartAutoKeyObtain()
                    else
                        StopAutoKeyObtain()
                    end
                end,
            }
        )

        AutosGroup:AddLabel(
            "Automatically fires ModulePrompt inside KeyObtain"
        )

        ----------------------------------------------------------------
        -- FOV
        ----------------------------------------------------------------

        local CurrentFOV = 70

        local function ApplyFOV()
            local Camera =
                workspace.CurrentCamera

            if Camera then
                Camera.FieldOfView =
                    CurrentFOV
            end
        end

        MovementGroup:AddSlider(
            "FOVSlider",
            {
                Text = "Player FOV",
                Default = 70,
                Min = 0,
                Max = 120,
                Rounding = 0,
                Suffix = "°",

                Callback = function(Value)
                    CurrentFOV = Value
                    ApplyFOV()
                end,
            }
        )

        ----------------------------------------------------------------
        -- HIGHLIGHT
        ----------------------------------------------------------------

        local HighlightEnabled = false
        local PlayerLight

        local function SetHighlight(Value)
            HighlightEnabled = Value

            local Character =
                Player.Character

            if not Character then
                return
            end

            local Root =
                Character:FindFirstChild(
                    "HumanoidRootPart"
                )

            if Value then
                if Root and not PlayerLight then
                    PlayerLight =
                        Instance.new("PointLight")

                    PlayerLight.Name =
                        "EntityHubLight"

                    PlayerLight.Range = math.huge
                    PlayerLight.Brightness = 0.6
                    PlayerLight.Shadows = true
                    PlayerLight.Parent = Root
                end
            else
                if PlayerLight then
                    PlayerLight:Destroy()
                    PlayerLight = nil
                end
            end
        end

        local HighlightToggle =
            MainGroup:AddToggle(
                "HighlightToggle",
                {
                    Text = "Highlight",
                    Default = false,

                    Callback = function(Value)
                        SetHighlight(Value)
                    end,
                }
            )

        HighlightToggle:AddKeyPicker(
            "HighlightKeybind",
            {
                Default = "H",
                Text = "Highlight",
                Mode = "Toggle",
                SyncToggleState = true,
            }
        )

        ----------------------------------------------------------------
        -- FLY
        ----------------------------------------------------------------

        local Flying = false
        local FlySpeed = 50
        local BodyGyro
        local BodyVelocity
        local FlyConnection

        local function GetCharacter()
            local Character =
                Player.Character
                or Player.CharacterAdded:Wait()

            local Humanoid =
                Character:FindFirstChildOfClass(
                    "Humanoid"
                )

            local RootPart =
                Character:FindFirstChild(
                    "HumanoidRootPart"
                )

            return Character,
                Humanoid,
                RootPart
        end

        local function StartFly()
            if Flying then
                return
            end

            local Character,
                Humanoid,
                RootPart =
                GetCharacter()

            if not Humanoid or not RootPart then
                return
            end

            Flying = true

            BodyGyro =
                Instance.new("BodyGyro")

            BodyVelocity =
                Instance.new("BodyVelocity")

            BodyGyro.P = 90000

            BodyGyro.MaxTorque =
                Vector3.new(
                    9000000000,
                    9000000000,
                    9000000000
                )

            BodyGyro.CFrame =
                RootPart.CFrame

            BodyGyro.Parent = RootPart

            BodyVelocity.MaxForce =
                Vector3.new(
                    9000000000,
                    9000000000,
                    9000000000
                )

            BodyVelocity.Velocity =
                Vector3.zero

            BodyVelocity.Parent =
                RootPart

            FlyConnection =
                RunService.RenderStepped:Connect(
                    function()
                        if not Flying
                            or not RootPart.Parent then
                            return
                        end

                        local Camera =
                            workspace.CurrentCamera

                        if not Camera then
                            return
                        end

                        local MoveDirection =
                            Vector3.zero

                        if UserInputService:IsKeyDown(
                            Enum.KeyCode.W
                        ) then
                            MoveDirection +=
                                Camera.CFrame.LookVector
                        end

                        if UserInputService:IsKeyDown(
                            Enum.KeyCode.S
                        ) then
                            MoveDirection -=
                                Camera.CFrame.LookVector
                        end

                        if UserInputService:IsKeyDown(
                            Enum.KeyCode.D
                        ) then
                            MoveDirection +=
                                Camera.CFrame.RightVector
                        end

                        if UserInputService:IsKeyDown(
                            Enum.KeyCode.A
                        ) then
                            MoveDirection -=
                                Camera.CFrame.RightVector
                        end

                        if UserInputService:IsKeyDown(
                            Enum.KeyCode.Space
                        ) then
                            MoveDirection +=
                                Vector3.new(
                                    0,
                                    1,
                                    0
                                )
                        end

                        if UserInputService:IsKeyDown(
                            Enum.KeyCode.LeftControl
                        ) then
                            MoveDirection -=
                                Vector3.new(
                                    0,
                                    1,
                                    0
                                )
                        end

                        if MoveDirection.Magnitude > 0 then
                            BodyVelocity.Velocity =
                                MoveDirection.Unit
                                * FlySpeed
                        else
                            BodyVelocity.Velocity =
                                Vector3.zero
                        end

                        BodyGyro.CFrame =
                            Camera.CFrame

                        Humanoid.PlatformStand =
                            true
                    end
                )
        end

        local function StopFly()
            Flying = false

            if FlyConnection then
                FlyConnection:Disconnect()
                FlyConnection = nil
            end

            local _,
                Humanoid =
                GetCharacter()

            if Humanoid then
                Humanoid.PlatformStand =
                    false
            end

            if BodyGyro then
                BodyGyro:Destroy()
                BodyGyro = nil
            end

            if BodyVelocity then
                BodyVelocity:Destroy()
                BodyVelocity = nil
            end
        end

        local FlyToggle =
            MovementGroup:AddToggle(
                "FlyToggle",
                {
                    Text = "Fly",
                    Default = false,

                    Callback = function(Value)
                        if Value then
                            StartFly()
                        else
                            StopFly()
                        end
                    end,
                }
            )

        FlyToggle:AddKeyPicker(
            "FlyKeybind",
            {
                Default = "F",
                Text = "Fly",
                Mode = "Toggle",
                SyncToggleState = true,
            }
        )

        ----------------------------------------------------------------
        -- NOCLIP
        ----------------------------------------------------------------

        local NoclipEnabled = false
        local NoclipConnection
        local SavedCollision = {}

        local function SetNoclip(Value)
            NoclipEnabled = Value

            if NoclipConnection then
                NoclipConnection:Disconnect()
                NoclipConnection = nil
            end

            if not Value then
                for Part, Collision in pairs(
                    SavedCollision
                ) do
                    if Part and Part.Parent then
                        Part.CanCollide =
                            Collision
                    end
                end

                table.clear(SavedCollision)
                return
            end

            NoclipConnection =
                RunService.Stepped:Connect(
                    function()
                        if not NoclipEnabled then
                            return
                        end

                        local Character =
                            Player.Character

                        if not Character then
                            return
                        end

                        for _, Part in ipairs(
                            Character:GetDescendants()
                        ) do
                            if Part:IsA("BasePart") then
                                if SavedCollision[Part]
                                    == nil then

                                    SavedCollision[Part] =
                                        Part.CanCollide
                                end

                                Part.CanCollide =
                                    false
                            end
                        end
                    end
                )
        end

        local NoclipToggle =
            MovementGroup:AddToggle(
                "NoclipToggle",
                {
                    Text = "Noclip",
                    Default = false,

                    Callback = function(Value)
                        SetNoclip(Value)
                    end,
                }
            )

        NoclipToggle:AddKeyPicker(
            "NoclipKeybind",
            {
                Default = "N",
                Text = "Noclip",
                Mode = "Toggle",
                SyncToggleState = true,
            }
        )

        ----------------------------------------------------------------
        -- ANTI TELEPORT
        ----------------------------------------------------------------

        local AntiTPEnabled = false
        local AntiTPConnection
        local DiedConnection

        local LastSafeCF
        local LastSafePosition

        local AntiTPDistance = 50
        local AntiTPRestoring = false
        local LastRestoreTime = 0

        local AntiTPCooldown = 0.15

        local function CleanupAntiTP()
            if AntiTPConnection then
                AntiTPConnection:Disconnect()
                AntiTPConnection = nil
            end

            if DiedConnection then
                DiedConnection:Disconnect()
                DiedConnection = nil
            end

            LastSafeCF = nil
            LastSafePosition = nil

            AntiTPRestoring = false
            LastRestoreTime = 0
        end

        local function GetAntiTPCharacter()
            local Character =
                Player.Character

            if not Character then
                return nil, nil, nil
            end

            local Humanoid =
                Character:FindFirstChildOfClass(
                    "Humanoid"
                )

            local Root =
                Character:FindFirstChild(
                    "HumanoidRootPart"
                )

            if not Humanoid or not Root then
                return nil, nil, nil
            end

            if Humanoid.Health <= 0 then
                return nil, nil, nil
            end

            return Character,
                Humanoid,
                Root
        end

        local function SaveSafePosition(Root)
            if not Root or not Root.Parent then
                return
            end

            LastSafeCF = Root.CFrame
            LastSafePosition = Root.Position
        end

        local function RestoreSafePosition(
            Character,
            Humanoid,
            Root
        )
            if AntiTPRestoring then
                return
            end

            if not LastSafeCF
                or not LastSafePosition then

                SaveSafePosition(Root)
                return
            end

            local Now = os.clock()

            if Now - LastRestoreTime
                < AntiTPCooldown then
                return
            end

            AntiTPRestoring = true
            LastRestoreTime = Now

            pcall(function()
                Root.AssemblyLinearVelocity =
                    Vector3.zero

                Root.AssemblyAngularVelocity =
                    Vector3.zero

                Character:PivotTo(
                    LastSafeCF
                )

                Root.AssemblyLinearVelocity =
                    Vector3.zero

                Root.AssemblyAngularVelocity =
                    Vector3.zero

                if Humanoid then
                    Humanoid:Move(
                        Vector3.zero,
                        false
                    )
                end
            end)

            task.defer(function()
                local CurrentCharacter,
                    CurrentHumanoid,
                    CurrentRoot =
                    GetAntiTPCharacter()

                if CurrentCharacter
                    and CurrentHumanoid
                    and CurrentRoot then

                    LastSafeCF =
                        CurrentRoot.CFrame

                    LastSafePosition =
                        CurrentRoot.Position
                end

                AntiTPRestoring = false
            end)
        end

        local function StartAntiTP()
            CleanupAntiTP()

            if not AntiTPEnabled then
                return
            end

            local Character,
                Humanoid,
                Root =
                GetAntiTPCharacter()

            if not Character
                or not Humanoid
                or not Root then
                return
            end

            SaveSafePosition(Root)

            AntiTPConnection =
                RunService.Heartbeat:Connect(
                    function()
                        if not AntiTPEnabled then
                            return
                        end

                        if AntiTPRestoring then
                            return
                        end

                        local CurrentCharacter,
                            CurrentHumanoid,
                            CurrentRoot =
                            GetAntiTPCharacter()

                        if not CurrentCharacter
                            or not CurrentHumanoid
                            or not CurrentRoot then
                            return
                        end

                        if CurrentRoot ~= Root then
                            Character =
                                CurrentCharacter

                            Humanoid =
                                CurrentHumanoid

                            Root =
                                CurrentRoot

                            SaveSafePosition(
                                CurrentRoot
                            )

                            return
                        end

                        local CurrentPosition =
                            CurrentRoot.Position

                        if not LastSafePosition
                            or not LastSafeCF then

                            SaveSafePosition(
                                CurrentRoot
                            )

                            return
                        end

                        local DistanceMoved =
                            (
                                CurrentPosition
                                - LastSafePosition
                            ).Magnitude

                        if DistanceMoved
                            > AntiTPDistance then

                            RestoreSafePosition(
                                CurrentCharacter,
                                CurrentHumanoid,
                                CurrentRoot
                            )

                            return
                        end

                        LastSafePosition =
                            CurrentPosition

                        LastSafeCF =
                            CurrentRoot.CFrame
                    end
                )

            DiedConnection =
                Humanoid.Died:Connect(
                    function()
                        if AntiTPConnection then
                            AntiTPConnection:Disconnect()
                            AntiTPConnection = nil
                        end

                        if DiedConnection then
                            DiedConnection:Disconnect()
                            DiedConnection = nil
                        end

                        LastSafeCF = nil
                        LastSafePosition = nil
                        AntiTPRestoring = false
                    end
                )
        end

        MainGroup:AddToggle(
            "AntiTeleport",
            {
                Text = "Anti Teleport",
                Default = false,

                Callback = function(Value)
                    AntiTPEnabled = Value

                    if Value then
                        StartAntiTP()
                    else
                        CleanupAntiTP()
                    end
                end,
            }
        )

        MainGroup:AddSlider(
            "AntiTPDistance",
            {
                Text = "Anti TP Distance",
                Default = 50,
                Min = 10,
                Max = 250,
                Rounding = 0,
                Suffix = " studs",

                Callback = function(Value)
                    AntiTPDistance =
                        tonumber(Value) or 50
                end,
            }
        )

        ----------------------------------------------------------------
        -- ESP
        ----------------------------------------------------------------

        local DisplayNames = {
            RushMoving = "Rush",
            BlitzMoving = "Blitz",
            Blitz = "BackdoorRush",
            BackdoorLookman = "Lookman",
            AmbushMoving = "Ambush",
            Eyes = "Eyes",
            Screech = "Screech",
            FigureRig = "Figure",
            Snare = "Snare",
            Dread = "Dread",
            Drones = "Drone",
            BashMoving = "Bash",
            Bash = "Bash",
            ScribblesMoving = "Scribbles",
            Scribbles = "Scribbles",
            GloomPile = "Gloom Eggs",
        }

        local EntityColor =
            Color3.fromRGB(
                255,
                0,
                0
            )

        local ItemColor =
            Color3.fromRGB(
                0,
                170,
                255
            )

        local GoldPileColor =
            Color3.fromRGB(
                255,
                255,
                0
            )

        local StorageItemColor =
            Color3.fromRGB(
                0,
                0,
                139
            )

        local HidingSpotColor =
            Color3.fromRGB(
                139,
                69,
                19
            )

        local DoorColor =
            Color3.fromRGB(
                0,
                255,
                0
            )

        local ESPEnabled = false
        local RainbowMode = false
        local RainbowHue = 0
        local ESPObjects = {}

        local function IsHidingSpot(Object)
            local Name = Object.Name

            return Name == "Wardrobe"
                or Name == "Double_Bed"
                or Name == "Bed"
                or Name == "Locker_Large"
                or Name == "Dumpster"
                or Name == "HdingSpot1"
                or Name == "HdingSpot2"
                or Name == "HdingSpot3"
                or Name == "HdingSpot4"
                or Name == "HdingSpot5"
                or Name == "HdingSpot6"
                or Name == "HdingSpot7"
                or Name == "HdingSpot8"
                or Name == "HdingSpot9"
                or Name == "HdingSpot10"
                or Name == "HdingSpot11"
                or Name == "HdingSpot12"
                or Name == "HdingSpot13"
                or Name == "HdingSpot14"
                or Name == "HdingSpot15"
                or Name == "HdingSpot16"
                or Name == "HdingSpot17"
                or Name == "HdingSpot18"
                or Name == "HdingSpot19"
                or Name == "HdingSpot20"
                
        end

        local function IsStorageItem(Object)
            local Name = Object.Name

            return Name == "Toolshed_Small"
                or Name == "Dresser"
                or Name == "ChestBox"
                or Name == "ChestBoxLocked"
                or Name == "Toolbox"
                or Name == "Toolbox_Locked"
                or Name == "Locker_Small"
                or Name == "OldWoodenTable"
                or Name == "Locker_Small_Locked"
        end

        local function IsLighterObject(Object)
            if not Object or Object.Name ~= "Lighter" then
                return false
            end

            -- Add Lighter when it is a Tool or any non-MeshPart.
            -- A MeshPart named Lighter is intentionally ignored.
            return Object:IsA("Tool")
                or not Object:IsA("MeshPart")
        end

        local function IsItem(Object)
            local Name = Object.Name

            return Name == "GoldPile"
                or Name == "TimerLever"
                or Name == "KeyObtain"
                or Name == "LiveHintBook"
                or Name == "LeverForGate"
                or Name == "Breaker"
                or Name == "LiveBreakerPolePickup"
                or Name == "Shears"
                or Name == "PaperPlane"
                or Name == "SkeletonKey"
                or Name == "Crucifix"
                or Name == "Lockpick"
                or Name == "Candle"
                or Name == "Vitamins"
                or IsLighterObject(Object)
                or Name == "FuseObtain"
        end

        local function IsEyesInFih(Object)
    if not Object or Object.Name ~= "Eyes" then
        return false
    end

    local Current = Object.Parent

    while Current do
        local Name = Current.Name

        if Name == "Fih"
            or Name == "fih"
            or Name == "Fih1"
            or Name == "Fih2"
            or Name == "Fih3" then
            return true
        end

        Current = Current.Parent
    end

    for _, Descendant in ipairs(Object:GetDescendants()) do
        local CurrentDescendant = Descendant

        while CurrentDescendant do
            local Name = CurrentDescendant.Name

            if Name == "Fih"
                or Name == "fih"
                or Name == "Fih1"
                or Name == "Fih2"
                or Name == "Fih3" then
                return true
            end

            if CurrentDescendant == Object then
                break
            end

            CurrentDescendant = CurrentDescendant.Parent
        end
    end

    return false
end

        ----------------------------------------------------------------
        -- ESP IGNORE SYSTEM
        ----------------------------------------------------------------

        local function IsBushObject(Object)
            if not Object then
                return false
            end

            return Object.Name == "Bush"
                or Object.Name == "BushMoving"
        end

        local function IsBushInCurrentRooms(Object)
            if not Object then
                return false
            end

            local Bush = nil

            if IsBushObject(Object) then
                Bush = Object
            else
                Bush =
                    Object:FindFirstAncestor("Bush")
                    or Object:FindFirstAncestor("BushMoving")
            end

            if not Bush then
                return false
            end

            local Parent = Bush.Parent
            local ParentParent =
                Parent and Parent.Parent

            return ParentParent
                and ParentParent.Name == "CurrentRooms"
        end

        local function IsInsideParts(Object)
            if not Object then
                return false
            end

            local Current = Object

            while Current do
                if Current.Name == "Parts" then
                    return true
                end

                Current = Current.Parent
            end

            return false
        end

        local function IsIgnoredESPObject(Object)
            if not Object then
                return true
            end

            -- Ignore Bush/BushMoving when its
            -- parent's parent is CurrentRooms.
            if IsBushInCurrentRooms(Object) then
                return true
            end

            -- Ignore EVERYTHING inside any
            -- instance named "Parts".
            if IsInsideParts(Object) then
                return true
            end

            return false
        end

        local function IsEntity(Object)
            if not Object then
                return false
            end

            if IsIgnoredESPObject(Object) then
                return false
            end

            if Object.Name == "Eyes"
                and IsEyesInFih(Object) then
                return false
            end

            return DisplayNames[Object.Name] ~= nil
        end

        local function IsDoor(Object)
            return Object.Name == "Door"
        end

        local function IsESPObject(Object)
            if not Object then
                return false
            end

            if IsIgnoredESPObject(Object) then
                return false
            end

            return IsEntity(Object)
                or IsHidingSpot(Object)
                or IsItem(Object)
                or IsStorageItem(Object)
                or IsDoor(Object)
        end

        local function GetESPColor(Object)
            if RainbowMode then
                return Color3.fromHSV(
                    RainbowHue,
                    1,
                    1
                )
            end

            if IsEntity(Object) then
                return EntityColor
            end

            if IsHidingSpot(Object) then
                return HidingSpotColor
            end

            if IsDoor(Object) then
                return DoorColor
            end

            if Object.Name == "GoldPile" then
                return GoldPileColor
            end

            if IsStorageItem(Object) then
                return StorageItemColor
            end

            return ItemColor
        end

        local function GetPart(Object)
            if Object:IsA("BasePart") then
                return Object
            end

            if Object:IsA("Model") then
                if Object.PrimaryPart then
                    return Object.PrimaryPart
                end

                local Root =
                    Object:FindFirstChild(
                        "HumanoidRootPart",
                        true
                    )

                if Root
                    and Root:IsA("BasePart") then

                    return Root
                end
            end

            for _, Value in ipairs(
                Object:GetDescendants()
            ) do
                if Value:IsA("BasePart") then
                    return Value
                end
            end

            return nil
        end

        local function UpdateESPColors()
            for Object, Data in pairs(
                ESPObjects
            ) do
                if Object
                    and Object.Parent
                    and not IsIgnoredESPObject(Object) then

                    local Color =
                        GetESPColor(Object)

                    if Data.Highlight then
                        Data.Highlight.FillColor =
                            Color

                        Data.Highlight.OutlineColor =
                            Color
                    end

                    if Data.Label then
                        Data.Label.TextColor3 =
                            Color
                    end

                    if Data.Line then
                        pcall(function()
                            Data.Line.Color =
                                Color
                        end)
                    end
                end
            end
        end

        local function CreateESP(Object)
            if not ESPEnabled then
                return
            end

            if not Object
                or not Object.Parent then
                return
            end

            -- IMPORTANT:
            -- Check this BEFORE creating any ESP.
            if IsIgnoredESPObject(Object) then
                return
            end

            if Object.Name == "Eyes"
                and IsEyesInFih(Object) then
                return
            end

            if ESPObjects[Object] then
                return
            end

            if not IsESPObject(Object) then
                return
            end

            local Part = GetPart(Object)

            if not Part then
                return
            end

            local Color =
                GetESPColor(Object)

            local Highlight =
                Instance.new("Highlight")

            Highlight.Name =
                "DoorsHackESP"

            Highlight.Adornee = Object
            Highlight.FillColor = Color
            Highlight.FillTransparency = 0.4
            Highlight.OutlineColor = Color
            Highlight.OutlineTransparency = 0
            Highlight.DepthMode =
                Enum.HighlightDepthMode.AlwaysOnTop

            Highlight.Parent = Object

            local Billboard =
                Instance.new("BillboardGui")

            Billboard.Name =
                "DoorsHackESPLabel"

            Billboard.Size =
                UDim2.new(
                    0,
                    180,
                    0,
                    45
                )

            Billboard.StudsOffset =
                Vector3.new(
                    0,
                    3,
                    0
                )

            Billboard.AlwaysOnTop = true
            Billboard.MaxDistance = 10000
            Billboard.Adornee = Part
            Billboard.Parent = Object

            local Text =
                Instance.new("TextLabel")

            Text.Size =
                UDim2.new(
                    1,
                    0,
                    1,
                    0
                )

            Text.BackgroundTransparency = 1
            Text.TextColor3 = Color
            Text.TextStrokeTransparency = 0
            Text.TextScaled = true
            Text.Font = Enum.Font.GothamBold
            Text.Parent = Billboard

            local Line

            pcall(function()
                Line = Drawing.new("Line")
                Line.Thickness = 1
                Line.Color = Color
                Line.Visible = false
            end)

            ESPObjects[Object] = {
                Part = Part,
                Highlight = Highlight,
                Billboard = Billboard,
                Label = Text,
                Line = Line
            }
        end

        local function RemoveESP(Object)
            local Data =
                ESPObjects[Object]

            if not Data then
                return
            end

            if Data.Line then
                pcall(function()
                    Data.Line.Visible = false
                    Data.Line:Remove()
                end)
            end

            if Data.Highlight then
                Data.Highlight:Destroy()
            end

            if Data.Billboard then
                Data.Billboard:Destroy()
            end

            ESPObjects[Object] = nil
        end

        local function ClearESP()
            for Object in pairs(
                ESPObjects
            ) do
                RemoveESP(Object)
            end

            table.clear(ESPObjects)
        end

        local function ScanESP()
            if not ESPEnabled then
                return
            end

            for _, Object in ipairs(
                workspace:GetDescendants()
            ) do
                if IsESPObject(Object) then
                    task.spawn(function()
                        for _ = 1, 5 do
                            task.wait(0.1)

                            if not ESPEnabled then
                                return
                            end

                            if IsIgnoredESPObject(Object) then
                                return
                            end

                            if Object.Parent
                                and GetPart(Object) then

                                CreateESP(Object)
                                return
                            end
                        end
                    end)
                end
            end
        end

        workspace.DescendantAdded:Connect(
            function(Object)
                if not ESPEnabled then
                    return
                end

                if IsESPObject(Object) then
                    task.spawn(function()
                        task.wait(0.1)

                        if ESPEnabled
                            and Object.Parent
                            and not IsIgnoredESPObject(Object) then

                            CreateESP(Object)
                        end
                    end)
                end
            end
        )

        RunService.RenderStepped:Connect(
            function()
                if RainbowMode then
                    RainbowHue =
                        (
                            RainbowHue
                            + 0.0025
                        ) % 1
                end

                if not ESPEnabled then
                    return
                end

                local Camera =
                    workspace.CurrentCamera

                local Character =
                    Player.Character

                if not Camera
                    or not Character then
                    return
                end

                local Root =
                    Character:FindFirstChild(
                        "HumanoidRootPart"
                    )

                if not Root then
                    return
                end

                for Object, Data in pairs(
                    ESPObjects
                ) do

                    -- REMOVE ESP if it has become
                    -- part of an ignored Parts folder
                    -- or an ignored Bush.
                    if not Object
                        or not Object.Parent
                        or IsIgnoredESPObject(Object)
                        or not IsESPObject(Object)
                        or not Data.Part
                        or not Data.Part.Parent then

                        RemoveESP(Object)

                    else

                        local Position,
                            Visible =
                            Camera:WorldToViewportPoint(
                                Data.Part.Position
                            )

                        if Data.Line then
                            Data.Line.Visible =
                                Visible

                            if Visible then
                                Data.Line.From =
                                    Vector2.new(
                                        Camera.ViewportSize.X
                                            / 2,
                                        Camera.ViewportSize.Y
                                    )

                                Data.Line.To =
                                    Vector2.new(
                                        Position.X,
                                        Position.Y
                                    )
                            end
                        end

                        local Distance =
                            math.floor(
                                (
                                    Root.Position
                                    - Data.Part.Position
                                ).Magnitude
                            )

                        local Name =
                            DisplayNames[
                                Object.Name
                            ]
                            or Object.Name

                        Data.Label.Text =
                            Name
                            .. " ["
                            .. Distance
                            .. " studs]"

                        local Color =
                            GetESPColor(Object)

                        Data.Highlight.FillColor =
                            Color

                        Data.Highlight.OutlineColor =
                            Color

                        Data.Label.TextColor3 =
                            Color

                        if Data.Line then
                            pcall(function()
                                Data.Line.Color =
                                    Color
                            end)
                        end
                    end
                end
            end
        )

        local ESPToggle =
            VisualGroup:AddToggle(
                "ESP_Toggle",
                {
                    Text = "ESP",
                    Default = false,

                    Callback = function(Value)
                        ESPEnabled = Value

                        if Value then
                            ScanESP()
                        else
                            ClearESP()
                        end
                    end,
                }
            )

        ESPToggle:AddKeyPicker(
            "ESPKeybind",
            {
                Default = "M",
                Text = "ESP",
                Mode = "Toggle",
                SyncToggleState = true,
            }
        )

        VisualGroup:AddToggle(
            "RainbowESP",
            {
                Text = "Rainbow Mode",
                Default = false,

                Callback = function(Value)
                    RainbowMode = Value

                    if not Value then
                        UpdateESPColors()
                    end
                end,
            }
        )

        VisualGroup:AddLabel(
            "Entity Color"
        ):AddColorPicker(
            "EntityColorPicker",
            {
                Default = EntityColor,
                Title = "Entity Color",
                Transparency = 0,

                Callback = function(Value)
                    if typeof(Value)
                        == "Color3" then

                        EntityColor = Value

                        if not RainbowMode then
                            UpdateESPColors()
                        end
                    end
                end,
            }
        )

        VisualGroup:AddLabel(
            "Item Color"
        ):AddColorPicker(
            "ItemColorPicker",
            {
                Default = ItemColor,
                Title = "Item Color",
                Transparency = 0,

                Callback = function(Value)
                    if typeof(Value)
                        == "Color3" then

                        ItemColor = Value

                        if not RainbowMode then
                            UpdateESPColors()
                        end
                    end
                end,
            }
        )

        VisualGroup:AddLabel(
            "GoldPile Color"
        ):AddColorPicker(
            "GoldPileColorPicker",
            {
                Default = GoldPileColor,
                Title = "GoldPile Color",
                Transparency = 0,

                Callback = function(Value)
                    if typeof(Value)
                        == "Color3" then

                        GoldPileColor = Value

                        if not RainbowMode then
                            UpdateESPColors()
                        end
                    end
                end,
            }
        )

        VisualGroup:AddLabel(
            "Storage Color"
        ):AddColorPicker(
            "StorageColorPicker",
            {
                Default = StorageItemColor,
                Title =
                    "Toolshed_Small / Dresser / ChestBox",
                Transparency = 0,

                Callback = function(Value)
                    if typeof(Value)
                        == "Color3" then

                        StorageItemColor =
                            Value

                        if not RainbowMode then
                            UpdateESPColors()
                        end
                    end
                end,
            }
        )

        VisualGroup:AddLabel(
            "Hiding Spot Color"
        ):AddColorPicker(
            "HidingColorPicker",
            {
                Default = HidingSpotColor,
                Title = "Hiding Spot Color",
                Transparency = 0,

                Callback = function(Value)
                    if typeof(Value)
                        == "Color3" then

                        HidingSpotColor =
                            Value

                        if not RainbowMode then
                            UpdateESPColors()
                        end
                    end
                end,
            }
        )

        VisualGroup:AddLabel(
            "Door Color"
        ):AddColorPicker(
            "DoorColorPicker",
            {
                Default = DoorColor,
                Title = "Door Color",
                Transparency = 0,

                Callback = function(Value)
                    if typeof(Value)
                        == "Color3" then

                        DoorColor = Value

                        if not RainbowMode then
                            UpdateESPColors()
                        end
                    end
                end,
            }
        )

        ----------------------------------------------------------------
        -- ENTITY NOTIFIER
        ----------------------------------------------------------------

        local NotifierLoaded = false
        local NotifierConnections = {}

        local function StopNotifier()
            for _, Connection in pairs(
                NotifierConnections
            ) do
                if Connection then
                    Connection:Disconnect()
                end
            end

            table.clear(
                NotifierConnections
            )

            NotifierLoaded = false
        end

        NotifierGroup:AddButton({
            Text = "Run Entity Notifier",

            Func = function()
                if NotifierLoaded then
                    Notify(
                        "Entity Notifier",
                        "Already running!"
                    )

                    return
                end

                NotifierLoaded = true

                local Tracked = {}

                Notify(
                    "Entity Notifier V1.0",
                    "Successfully loaded Entity Notifier!"
                )

                NotifierConnections.ChildAdded =
                    workspace.ChildAdded:Connect(
                        function(Object)
                            if DisplayNames[
                                Object.Name
                            ] then

                                Tracked[Object] =
                                    true

                                local Name =
                                    DisplayNames[
                                        Object.Name
                                    ]

                                Notify(
                                    Name
                                        .. " spawned!",
                                    ""
                                )
                            end
                        end
                    )

                NotifierConnections.ChildRemoved =
                    workspace.ChildRemoved:Connect(
                        function(Object)
                            if Tracked[Object] then
                                local Name =
                                    DisplayNames[
                                        Object.Name
                                    ]

                                Notify(
                                    Name
                                        .. " is Gone!",
                                    ""
                                )

                                Tracked[Object] =
                                    nil
                            end
                        end
                    )
            end
        })

        NotifierGroup:AddButton({
            Text = "Stop Entity Notifier",

            Func = function()
                StopNotifier()

                Notify(
                    "Entity Notifier",
                    "Stopped!"
                )
            end
        })

        ----------------------------------------------------------------
        -- TROLL
        ----------------------------------------------------------------

        TrollGroup:AddButton({
            Text = "Give Special Crucifix",

            Func = function()
                _G.Uses = 99999999999
                _G.Range = 999
                _G.OnAnything = true
                _G.Fail = false

                loadstring(
                    game:HttpGet(
                        "https://raw.githubusercontent.com/PenguinManiack/Crucifix/main/Crucifix.lua"
                    )
                )()
            end
        })

        ----------------------------------------------------------------
        -- MENU
        ----------------------------------------------------------------

        MenuGroup:AddToggle(
            "KeybindMenuOpen",
            {
                Text = "Open Keybind Menu",
                Default =
                    Library.KeybindFrame.Visible,

                Callback = function(Value)
                    Library.KeybindFrame.Visible =
                        Value
                end,
            }
        )

        MenuGroup:AddToggle(
            "ShowCustomCursor",
            {
                Text = "Custom Cursor",
                Default = true,

                Callback = function(Value)
                    Library.ShowCustomCursor =
                        Value
                end,
            }
        )

        MenuGroup:AddLabel(
            "Menu Bind"
        ):AddKeyPicker(
            "MenuKeybind",
            {
                Default = "K",
                NoUI = true,
                Text = "Menu Keybind",

                Callback = function()
                    Library:Toggle()
                end,
            }
        )

        MenuGroup:AddButton({
            Text = "Unload",

            Func = function()
                Library:Unload()
            end
        })

        ----------------------------------------------------------------
        -- BYPASS
        ----------------------------------------------------------------

        if Player.Name == BYPASS_USERNAME then
            local BypassEnabled =
                ReadBypassFile()

            MainGroup:AddToggle(
                "BypassKeyCheck",
                {
                    Text = "Bypass Key Check",
                    Default = BypassEnabled,

                    Callback = function(Value)
                        local WriteSuccess =
                            WriteBypassFile(
                                Value
                            )

                        if WriteSuccess then
                            if Value then
                                Notify(
                                    "DoorsHack",
                                    "Key bypass enabled."
                                )
                            else
                                Notify(
                                    "DoorsHack",
                                    "Key bypass disabled."
                                )
                            end
                        else
                            Notify(
                                "DoorsHack",
                                "Your executor does not support writefile."
                            )
                        end
                    end,
                }
            )

            MainGroup:AddLabel(
                "Bypass available only to "
                    .. BYPASS_USERNAME
            )
        end

        ----------------------------------------------------------------
        -- CONFIG
        ----------------------------------------------------------------

        ConfigGroup:AddLabel(
            "Configuration"
        )

        local ConfigStatus =
            ConfigGroup:AddLabel(
                "Config system loading..."
            )

        pcall(function()
            ThemeManager:SetLibrary(
                Library
            )

            SaveManager:SetLibrary(
                Library
            )

            ThemeManager:SetFolder(
                "DoorsHack"
            )

            SaveManager:SetFolder(
                "DoorsHack"
            )

            SaveManager:SetSubFolder(
                "Lobby"
            )

            SaveManager:IgnoreThemeSettings()

            SaveManager:SetIgnoreIndexes({
                "MenuKeybind"
            })

            SaveManager:BuildConfigSection(
                Tabs["UI Settings"]
            )

            ThemeManager:ApplyToTab(
                Tabs["UI Settings"]
            )

            SaveManager:LoadAutoloadConfig()

            if not tonumber(
                _G.CurrentSpeed
            )
                or tonumber(
                    _G.CurrentSpeed
                ) < 1 then

                _G.CurrentSpeed = 16
            end

            ConfigStatus:SetText(
                "Config system ready"
            )
        end)

        ----------------------------------------------------------------
        -- CHARACTER RESPAWN
        ----------------------------------------------------------------

        Player.CharacterAdded:Connect(
            function(Character)
                task.wait(1)

                ApplySpeed()

                if AntiTPEnabled then
                    StartAntiTP()
                end

                if NoclipEnabled then
                    SetNoclip(true)
                end

                if HighlightEnabled then
                    SetHighlight(true)
                end

                ApplyFOV()

                if ESPEnabled then
                    ScanESP()
                end
            end
        )

        Player.CharacterRemoving:Connect(
            function()
                CleanupAntiTP()

                if PlayerLight then
                    PlayerLight:Destroy()
                    PlayerLight = nil
                end
            end
        )

----------------------------------------------------------------
-- UNLOAD
----------------------------------------------------------------

Library:OnUnload(
    function()
        StopFly()
        SetNoclip(false)
        CleanupAntiTP()
        ClearESP()
        StopNotifier()
        StopAutoKeyObtain()

        if PlayerLight then
            PlayerLight:Destroy()
            PlayerLight = nil
        end

        if OxygenConnection then
            OxygenConnection:Disconnect()
            OxygenConnection = nil
        end

        if OxygenLabel then
            OxygenLabel:SetVisible(false)
        end

        Library.Unloaded = true
    end
)

        Notify(
            "DoorsHack",
            "Everything loaded successfully!"
        )
    end)

    if not Success then
        pcall(function()
            Library:Notify({
                Title = "DoorsHack",
                Description =
                    "Failed to load: "
                    .. tostring(ErrorMessage),
                Time = 4,
            })
        end)
    end
end

----------------------------------------------------------------
-- START MAIN
----------------------------------------------------------------

local function StartMain()
    pcall(function()
        AuthLibrary:Unload()
    end)

    task.wait(0.4)

    local MainLibrary =
        CreateMainLibrary()

    if not MainLibrary then
        warn(
            "DoorsHack: Failed to initialize main library."
        )

        return
    end

    local SaveManager =
        CreateAddon(
            "SaveManager.lua",
            MainLibrary
        )

    local ThemeManager =
        CreateAddon(
            "ThemeManager.lua",
            MainLibrary
        )

    if not SaveManager
        or not ThemeManager then

        warn(
            "DoorsHack: Failed to load Obsidian addons."
        )

        return
    end

    LoadMainUI(
        MainLibrary,
        SaveManager,
        ThemeManager
    )
end

----------------------------------------------------------------
-- BYPASS CHECK
----------------------------------------------------------------

if Player.Name == BYPASS_USERNAME
    and ReadBypassFile() then

    StartMain()
    return
end

----------------------------------------------------------------
-- KEY WINDOW
----------------------------------------------------------------

local KeyWindow =
    AuthLibrary:CreateWindow({
        Title = "DoorsHack",
        Footer = "version: 0.1",
        Resizable = false,
        Center = true,
        Icon = 11358524205,
        NotifySide = "Right",
        ShowCustomCursor = true,
    })

local KeyTab =
    KeyWindow:AddTab(
        "Authentication",
        "key"
    )

local KeyGroup =
    KeyTab:AddLeftGroupbox(
        "Authentication"
    )

KeyGroup:AddLabel(
    "Enter your DoorsHack key."
)

KeyGroup:AddLabel(
    "Keys are valid for 24 hours."
)

local KeyInput = ""

KeyGroup:AddInput(
    "KeyInput",
    {
        Default = "",
        Numeric = false,
        Finished = false,
        Text = "Key",
        Placeholder = "DH-XXXX-XXXX-XXXX",

        Callback = function(Value)
            KeyInput = tostring(Value)
        end,
    }
)

KeyGroup:AddButton({
    Text = "Get Key",

    Func = function()
        local Copied =
            CopyText(KEY_GET_URL)

        if Copied then
            AuthNotify(
                "DoorsHack",
                "Key website copied to clipboard!"
            )
        else
            AuthNotify(
                "DoorsHack",
                KEY_GET_URL
            )
        end
    end
})

KeyGroup:AddButton({
    Text = "Verify Key",

    Func = function()
        local CleanKey =
            tostring(KeyInput)
                :gsub("^%s+", "")
                :gsub("%s+$", "")

        if CleanKey == "" then
            AuthNotify(
                "DoorsHack",
                "Enter a key first."
            )

            return
        end

        AuthNotify(
            "DoorsHack",
            "Checking key..."
        )

        task.spawn(function()
            local Valid,
                Message =
                VerifyKey(CleanKey)

            if not Valid then
                AuthNotify(
                    "DoorsHack",
                    Message
                )

                return
            end

            AuthNotify(
                "DoorsHack",
                "Key verified successfully!"
            )

            task.wait(0.5)

            StartMain()
        end)
    end
})

KeyGroup:AddButton({
    Text = "Copy Key Website",

    Func = function()
        local Copied =
            CopyText(
                "https://lootdest.org/s?rFzGWhmJ"
            )

        if Copied then
            AuthNotify(
                "DoorsHack",
                "Website copied!"
            )
        else
            AuthNotify(
                "DoorsHack",
                "https://lootdest.org/s?rFzGWhmJ"
            )
        end
    end
})

KeyGroup:AddLabel(
    "Key Website:"
)

KeyGroup:AddLabel(
    "https://lootdest.org/s?rFzGWhmJ"
)
