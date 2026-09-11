-- SERVICES

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local Vgxmod_Config = {
    WallHopEnabled = false,
    WallHopMode = "Default",
    WallHopAngle = 90,
    AutoFlingEnabled = false,
    AutoFlingDirection = "Both",
    AutoFlingCooldown = 3,
    AutoLockEnabled = false,
    AutoLockMode = "Default",
    AutoLockDistance = 10,
    AutoLockTargetPart = "Head",
    AutoLockVerticalOffset = 0,
    AutoLockRotationAngle = 45,
    ESPEnabled = false,
    TeamCheckEnabled = true,
    BlockAssist1Enabled = false,
    BlockAssist2Enabled = false,
    BlockAssist3Enabled = false,
    BlockAssistArena5Enabled = false,
    HitboxEnabled = false,
    HitboxMaxSize = 11,
    HitboxInterval = 0.1,
    TPWalkEnabled = false,
    TPWalkSpeed = 0.03,
    JumpBoostEnabled = false,
    JumpBoost = 53,
    SnapRotateEnabled = false,
    SnapRotateSpeed = 0.5,
    HeadlessEnabled = false,
    KorbloxEnabled = false,
    TrailEnabled = false,
    TrailColor = Color3.fromRGB(255, 0, 0),
    HeadFireEnabled = false,
    PlayerTrackEnabled = false,
    PlayerTrackMode = "Default",
    PlayerTrackBombTimer = 2,
    PlayerTrackDistance = 6,
    FPSBoostEnabled = false,
    FPSBoostMode = "MEDIUM",
    ShowTrackButton = false,
    LockTrackButtonPosition = false,
    BombTimeESPEnabled = false,
}


-- LIBRARY LOADER

local repo = "https://library2.ugirecode.workers.dev/"

local function Load(url, name)
    local ok, result = pcall(function()
        local code = game:HttpGet(url)
        local func, err = loadstring(code)
        if not func then error(err) end
        return func()
    end)

    if not ok then
        warn("[Vgxmod] " .. name .. ": " .. tostring(result))
    end

    return ok and result or nil
end

local Library = Load(repo, "Library")
local ThemeManager = Load(repo .. "theme", "ThemeManager")
local SaveManager = Load(repo .. "save", "SaveManager")

if not Library then error("[Vgxmod] Library failed") end

local Options = Library.Options
local Toggles = Library.Toggles

-- TEAM CHECK

local Arenas = workspace:WaitForChild("Arenas")
local Vgxmod_TeamCheck = workspace:FindFirstChild("TeamCheck")
if not Vgxmod_TeamCheck then
	Vgxmod_TeamCheck = Instance.new("Folder")
	Vgxmod_TeamCheck.Name = "TeamCheck"
	Vgxmod_TeamCheck.Parent = workspace
end

local function Vgxmod_reset(plr)
	plr:SetAttribute("Ingame", false)
	plr:SetAttribute("Arena", 0)
	plr:SetAttribute("Team", "")
	plr:SetAttribute("Alive", false)
end

local function Vgxmod_getplr(val)
	if typeof(val) == "Instance" and val:IsA("Player") then
		return val
	end
	if typeof(val) == "string" then
		val = val:gsub("^@", "")
		for _, v in ipairs(Players:GetPlayers()) do
			if v.Name:lower() == val:lower() then
				return v
			end
		end
	end
	return nil
end

local function Vgxmod_getattr(obj, name, default)
	local val = obj:GetAttribute(name)
	if val == nil then
		return default
	end
	return val
end

local function Vgxmod_update()
	for _, v in ipairs(Players:GetPlayers()) do
		Vgxmod_reset(v)
	end
	for _, arena in ipairs(Arenas:GetChildren()) do
		local data = arena:FindFirstChild("Data")
		local slots = arena:FindFirstChild("Slots")
		if data and slots then
			local inProgress = data:GetAttribute("InProgress") == true
			local arenaNum = tonumber(arena.Name:match("%d+")) or 0
			if inProgress then
				for _, side in ipairs(slots:GetChildren()) do
					if side.Name == "Left" or side.Name == "Right" then
						for _, slot in ipairs(side:GetChildren()) do
							local slotData = slot:FindFirstChild("Data")
							local playerObj = slotData and slotData:FindFirstChild("Player")
							if playerObj then
								local success, val = pcall(function()
									return playerObj.Value
								end)
								if success and val ~= nil then
									local plr = Vgxmod_getplr(val)
									if plr then
										plr:SetAttribute("Ingame", true)
										plr:SetAttribute("Arena", arenaNum)
										plr:SetAttribute("Team", side.Name)
										plr:SetAttribute("Alive", Vgxmod_getattr(slotData, "Alive", false))
									end
								end
							end
						end
					end
				end
			end
		end
	end
end

for _, v in ipairs(Players:GetPlayers()) do
	Vgxmod_reset(v)
end
Players.PlayerAdded:Connect(function(plr)
	Vgxmod_reset(plr)
end)
Players.PlayerRemoving:Connect(function(plr)
	Vgxmod_reset(plr)
end)
task.spawn(function()
	while true do
		if Vgxmod_Config.TeamCheckEnabled then
			pcall(Vgxmod_update)
		end
		task.wait(0.5)
	end
end)


-- WALLHOP
local Vgxmod_HOLD = 0.08
local Vgxmod_RETURN_DELAY = 0.03
local Vgxmod_SEARCH_DISTANCE = 2

local Flicking = false
local CanWallHop = true

local Vgxmod_Arena3 = Workspace.Arenas.Arena3
local Vgxmod_WallFolder = Vgxmod_Arena3.Map.Wall
local Vgxmod_DDWalls = {}

function Vgxmod_updateDD()
    table.clear(Vgxmod_DDWalls)
    local walls = {}
    for _, obj in ipairs(Vgxmod_Arena3:GetDescendants()) do
        if obj.Name == "Wall" and obj:IsA("BasePart") then
            table.insert(walls, obj)
        end
    end
    if #walls == 0 then
        return
    end
    local highest = -math.huge
    for _, wall in ipairs(walls) do
        if wall.Position.Y > highest then
            highest = wall.Position.Y
        end
    end
    for _, wall in ipairs(walls) do
        if math.abs(wall.Position.Y - highest) <= 1 then
            table.insert(Vgxmod_DDWalls, wall)
        end
    end
end
Vgxmod_updateDD()

function Vgxmod_validWall(hit)
    if not hit or not hit:IsA("BasePart") then
        return false
    end
    local mode = Vgxmod_Config.WallHopMode or "Default"
    if mode == "Double Decker" then
        for _, wall in ipairs(Vgxmod_DDWalls) do
            if hit == wall then
                return true
            end
        end
        return false
    end
    return true
end

function Vgxmod_findWall()
    local char = LocalPlayer.Character
    if not char then
        return nil
    end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then
        return nil
    end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {char}
    local dirs = {
        root.CFrame.LookVector,
        -root.CFrame.LookVector,
        root.CFrame.RightVector,
        -root.CFrame.RightVector
    }
    local maxDist = Vgxmod_SEARCH_DISTANCE
    local closest = nil
    for _, dir in ipairs(dirs) do
        local result = Workspace:Raycast(
            root.Position,
            dir * 2,
            params
        )
        if result and result.Instance and Vgxmod_validWall(result.Instance) and result.Distance < maxDist then
            maxDist = result.Distance
            closest = result
        end
    end
    return closest
end

local function getYaw(CFrameValue)
    local Look = CFrameValue.LookVector
    return math.atan2(-Look.X, -Look.Z)
end

local function angleDifference(A, B)
    return math.atan2(
        math.sin(B - A),
        math.cos(B - A)
    )
end

local function easeOut(Value)
    return 1 - math.pow(1 - Value, 3)
end

local function performFlick(Root, Humanoid, WallNormal)
    if Flicking then
        return
    end
    
    Flicking = true
    local OriginalAutoRotate = Humanoid.AutoRotate
    Humanoid.AutoRotate = false
    
    local StartCFrame = Root.CFrame
    local StartYaw = getYaw(StartCFrame)
    
    local WallDirection = Vector3.new(
        WallNormal.X,
        0,
        WallNormal.Z
    )
    
    if WallDirection.Magnitude < 0.01 then
        Humanoid.AutoRotate = OriginalAutoRotate
        Flicking = false
        return
    end
    
    WallDirection = WallDirection.Unit
    local WallYaw = math.atan2(
        -WallDirection.X,
        -WallDirection.Z
    )
    
    local Difference = angleDifference(
        StartYaw,
        WallYaw
    )
    
    local FlickAngle = Vgxmod_Config.WallHopAngle or 90
    local Direction = Difference >= 0 and 1 or -1
    local TargetYaw = StartYaw + math.rad(FlickAngle) * Direction
    local StartTime = os.clock()
    
    while true do
        if not Root.Parent or not Humanoid.Parent then
            break
        end
        
        local Elapsed = os.clock() - StartTime
        local Alpha = math.clamp(
            Elapsed / Vgxmod_HOLD,
            0,
            1
        )
        local SmoothAlpha = easeOut(Alpha)
        local CurrentYaw = StartYaw + math.rad(FlickAngle) * Direction * SmoothAlpha
        local Position = Root.Position
        Root.CFrame = CFrame.new(Position) * CFrame.Angles(0, CurrentYaw, 0)
        
        if Alpha >= 1 then
            break
        end
        RunService.Heartbeat:Wait()
    end
    
    local Position = Root.Position
    Root.CFrame = CFrame.new(Position) * CFrame.Angles(0, TargetYaw, 0)
    task.wait(Vgxmod_RETURN_DELAY)
    
    if Root.Parent and Humanoid.Parent then
        Humanoid.AutoRotate = OriginalAutoRotate
    end
    Flicking = false
end

if Vgxmod_WallHopConnection then
    Vgxmod_WallHopConnection:Disconnect()
end

Vgxmod_WallHopConnection = UserInputService.JumpRequest:Connect(function()
    if not Vgxmod_Config.WallHopEnabled then
        return
    end
    
    if not CanWallHop then
        return
    end
    
    if Flicking then
        return
    end
    
    local char = LocalPlayer.Character
    if not char then
        return
    end
    
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    local cam = Workspace.CurrentCamera
    
    if not (hum and root and cam) then
        return
    end
    
    local wallHit = Vgxmod_findWall()
    if not wallHit then
        return
    end
    
    CanWallHop = false
    hum:ChangeState(Enum.HumanoidStateType.Jumping)
    
    task.spawn(function()
        performFlick(root, hum, wallHit.Normal)
    end)
    
    task.delay(0.2, function()
        CanWallHop = true
    end)
end)

LocalPlayer.CharacterAdded:Connect(function(Character)
    Flicking = false
    CanWallHop = true
    local Humanoid = Character:WaitForChild("Humanoid")
    if Humanoid then
        Humanoid.AutoRotate = true
    end
end)


-- AUTO FLING

local Vgxmod_rightMovement = {
    {cframe = {134.3416748046875, 4.947039604187012, -56.988677978515625, 0.5241867899894714, 0.0014072328340262175, -0.8516021370887756, -0.000011834919860120863, 0.9999986290931702, 0.001645166426897049, 0.8516033291816711, -0.000852295896038413, 0.5241861343383789}, time = 0.267243072},
    {cframe = {134.34292602539062, 4.538743019104004, -56.989471435546875, 0.5244876742362976, -0.006393485702574253, -0.8513940572738647, -0.00007482519868062809, 0.9999714493751526, -0.007555312477052212, 0.8514180779457092, 0.004026373848319054, 0.524472177028656}, time = 0.281447031},
    {cframe = {134.3438262939453, 4.075960636138916, -56.990028381347656, 0.5245234370231628, -0.0024315642658621073, -0.8513925671577454, -0.000022523290681419894, 0.9999958872795105, -0.002869849093258381, 0.8513960242271423, 0.0015244792448356748, 0.5245211720466614}, time = 0.299462968},
    {cframe = {134.34397888183594, 4.961854457855225, -56.9901123046875, 0.5245259404182434, 0.0020712031982839108, -0.8513919711112976, 0.000027901365683646873, 0.9999970197677612, 0.002449908060953021, 0.8513944745063782, -0.0013087952975183725, 0.5245242714881897}, time = 0.315950468},
    {cframe = {134.31573486328125, 5.502064228057861, -56.97322082519531, 0.5220112800598145, 0.019747275859117508, -0.852709949016571, -0.00009604669321561232, 0.9997333288192749, 0.02309328131377697, 0.8529385924339294, -0.011973053216934204, 0.521873950958252}, time = 0.331792343},
    {cframe = {134.1021270751953, 5.563347816467285, -56.86342239379883, 0.5128415822982788, 0.1494331657886505, -0.8453775644302368, -0.026448365300893784, 0.9870166778564453, 0.15842531621456146, 0.858075737953186, -0.058888234198093414, 0.5101354718208313}, time = 0.351875833},
    {cframe = {133.49850463867188, 5.919736862182617, -56.625755310058594, 0.5034668445587158, 0.44723808765411377, -0.7392558455467224, -0.08235596865415573, 0.8765507936477661, 0.474211186170578, 0.8600805997848511, -0.17786748707294464, 0.4781470000743866}, time = 0.365333593},
    {cframe = {132.60946655273438, 6.639885425567627, -56.28135299682617, 0.4471997022628784, 0.793727457523346, -0.4123215973377228, -0.1539926379919052, 0.5224268436431885, 0.8386635184288025, 0.8810781240463257, -0.3115555942058563, 0.35585731267929077}, time = 0.382372083},
    {cframe = {131.65113830566406, 7.6365790367126465, -55.9178352355957, 0.33745521306991577, 0.7432620525360107, -0.5776551365852356, -0.12100163847208023, 0.6428096890449524, 0.7564088106155396, 0.9335322976112366, -0.18535687029361725, 0.3068554103374481}, time = 0.399792239},
    {cframe = {130.64381408691406, 8.6273775100708, -55.534385681152344, 0.450793594121933, 0.329801082611084, -0.8294675350189209, -0.05158628150820732, 0.9373143315315247, 0.34464579820632935, 0.8911363482475281, -0.1125749796628952, 0.4395484924316406}, time = 0.415326406},
    {cframe = {129.7131805419922, 9.498638153076172, -55.17124938964844, 0.5226753950119019, 0.06417104601860046, -0.8501132726669312, -0.003854602575302124, 0.9973307847976685, 0.07291387766599655, 0.8525230884552002, -0.03483343869447708, 0.5215275883674622}, time = 0.431783177},
    {cframe = {128.87118530273438, 10.299460411071777, -54.840492248535156, 0.5261311531066895, -0.007600806653499603, -0.8503694534301758, 0.004473328124731779, 0.9999709725379944, -0.006170293316245079, 0.850391685962677, -0.0005575977847911417, 0.5261498689651489}, time = 0.449033749},
    {cframe = {128.0851593017578, 11.045038223266602, -54.532527923583984, 0.5247268676757812, -0.010990789160132408, -0.8511996865272522, 0.002547621726989746, 0.9999324679374695, -0.011340747587382793, 0.8512668609619141, 0.003782259998843074, 0.5247194170951843}, time = 0.465313229},
    {cframe = {127.33892822265625, 11.736143112182617, -54.24077224731445, 0.5245441198348999, -0.004295010585337877, -0.8513724207878113, 0.000682187732309103, 0.9999890923500061, -0.004624446388334036, 0.8513829708099365, 0.0018449303461238742, 0.5245413184165955}, time = 0.482529635},
    {cframe = {126.62882995605469, 12.372735023498535, -53.96332550048828, 0.5245301127433777, -0.0007506651454605162, -0.8513915538787842, 0.00002653706178534776, 0.9999996423721313, -0.0008653425611555576, 0.8513919115066528, 0.0004313048266340047, 0.5245299339294434}, time = 0.499215885},
    {cframe = {125.95498657226562, 12.954824447631836, -53.7000617980957, 0.524529218673706, 0.00014328134420793504, -0.8513924479484558, -0.000066385131503921, 1, 0.00012739177327603102, 0.8513924479484558, -0.00001030090879794443, 0.524529218673706}, time = 0.516582395},
    {cframe = {125.31789398193359, 13.482413291931152, -53.451148986816406, 0.524528980255127, 0.00015422885189764202, -0.8513925671577454, -0.00003431331424508244, 1, 0.0001600090618012473, 0.8513925671577454, -0.00005471528857015073, 0.524528980255127}, time = 0.531849374},
    {cframe = {124.71778106689453, 13.9555025100708, -53.21666717529297, 0.524527370929718, 0.000056023880460998043, -0.8513935804367065, -0.00000847466890263604, 1, 0.00006058148210286163, 0.8513935804367065, -0.00002456136826367583, 0.524527370929718}, time = 0.548873385},
    {cframe = {124.15467071533203, 14.374091148376465, -52.996646881103516, 0.5245277881622314, 0.000008536539098713547, -0.8513933420181274, -2.142935073834451e-08, 1, 0.000010013349310611375, 0.8513933420181274, -0.000005234035143075744, 0.5245277881622314}, time = 0.565515989},
    {cframe = {123.62857055664062, 14.738180160522461, -52.79108810424805, 0.5245283842086792, -0.0000024596088223916013, -0.8513929843902588, 9.69753500612569e-07, 1, -0.0000022914748569746735, 0.8513929843902588, 3.763021823033341e-07, 0.5245283842086792}, time = 0.581636614},
    {cframe = {123.13948059082031, 15.047769546508789, -52.59998321533203, 0.5245288014411926, -0.0000021446376194944605, -0.8513926863670349, 4.5890601541032083e-07, 1, -0.0000022362514755513985, 0.8513926863670349, 7.822691259207204e-07, 0.5245288014411926}, time = 0.599459895},
    {cframe = {122.6873779296875, 15.30285930633545, -52.42333984375, 0.5245293974876404, -7.250247904266871e-07, -0.8513923287391663, 1.0386806792439529e-07, 1, -7.87583985584206e-07, 0.8513923287391663, 3.2467846722283866e-07, 0.5245293974876404}, time = 0.615474062},
    {cframe = {122.27227783203125, 15.503448486328125, -52.261146545410156, 0.5245279669761658, -9.328165617716877e-08, -0.8513932228088379, -4.170961354077463e-09, 1, -1.1213319339731243e-07, 0.8513932228088379, 6.23681231104456e-08, 0.5245279669761658}, time = 0.632419479},
    {cframe = {121.89418029785156, 15.649538040161133, -52.1134147644043, 0.5245286822319031, 5.1669605483084524e-08, -0.8513928055763245, -1.5510682516151064e-08, 1, 5.113246004384564e-08, 0.8513928055763245, -1.3614758209712363e-08, 0.5245286822319031}, time = 0.648640729},
    {cframe = {121.55307006835938, 15.741127014160156, -51.98013687133789, 0.5245298147201538, 1.0471755018670592e-07, -0.8513920903205872, -1.4457190111727414e-08, 1, 1.140888272743723e-07, 0.8513920903205872, -4.75342538663881e-08, 0.5245298147201538}, time = 0.665453489},
    {cframe = {121.24897003173828, 15.778216361999512, -51.86131286621094, 0.5245283842086792, 1.2279670613679627e-07, -0.8513929843902588, -1.002712934905503e-08, 1, 1.3805279763801082e-07, 0.8513929843902588, -6.387558215692479e-08, 0.5245283842086792}, time = 0.681879114},
    {cframe = {120.98186492919922, 15.760805130004883, -51.75695037841797, 0.5245295166969299, 1.4086025146298198e-07, -0.8513922691345215, -5.600892638568666e-09, 1, 1.619963256871415e-07, 0.8513922691345215, -8.020329289593064e-08, 0.5245295166969299}, time = 0.698479895},
}

local Vgxmod_leftMovement = {
    {cframe = {99.52750396728516, 3.9999992847442627, -56.97442626953125, 0.46946316957473755, -4.154482979856766e-09, 0.8829520344734192, 2.748812732988881e-09, 1, 3.2436830998960886e-09, -0.8829520344734192, 9.042801507597176e-10, 0.46946316957473755}, time = 0.079876407},
    {cframe = {99.52750396728516, 3.9999992847442627, -56.97442626953125, 0.46946316957473755, 3.33789529349815e-08, 0.8829520344734192, -2.2084870821004188e-08, 1, -2.6061345081984655e-08, -0.8829520344734192, -7.265040569137682e-09, 0.46946316957473755}, time = 0.097236302},
    {cframe = {99.52750396728516, 3.9999992847442627, -56.97442626953125, 0.46946316957473755, 7.088032560886859e-08, 0.8829520344734192, -4.689733756890746e-08, 1, -5.534134928097956e-08, -0.8829520344734192, -1.5427373156740032e-08, 0.46946316957473755}, time = 0.113892188},
    {cframe = {99.52750396728516, 3.9999992847442627, -56.97442626953125, 0.46946316957473755, 1.0834966701622761e-07, 0.8829520344734192, -7.168859639250513e-08, 1, -8.459633704660519e-08, -0.8829520344734192, -2.3582728658766428e-08, 0.46946316957473755}, time = 0.131578177},
    {cframe = {99.52750396728516, 3.9999992847442627, -56.97442626953125, 0.46946316957473755, 7.753167352575474e-08, 0.8829520344734192, -5.129814795168386e-08, 1, -6.053451784282515e-08, -0.8829520344734192, -1.6875077335498645e-08, 0.46946316957473755}, time = 0.146474688},
    {cframe = {99.52750396728516, 4.661014556884766, -56.97442626953125, 0.46946316957473755, 5.443545703087693e-08, 0.8829520344734192, -3.601675047093522e-08, 1, -4.250164664654221e-08, -0.8829520344734192, -1.1848105607725756e-08, 0.46946316957473755}, time = 0.162907136},
    {cframe = {99.52750396728516, 5.700258255004883, -56.97442626953125, 0.46946316957473755, 1.5974650935390855e-08, 0.8829520344734192, -1.0569520370040664e-08, 1, -1.247253500480383e-08, -0.8829520344734192, -3.4769838119785845e-09, 0.46946316957473755}, time = 0.179930938},
    {cframe = {99.60142517089844, 5.298228740692139, -56.948307037353516, 0.469323992729187, -0.017425362020730972, 0.8828541040420532, 0.002476912457495928, 0.9998273253440857, 0.01841740310192108, -0.8830225467681885, -0.006456976290792227, 0.46928611397743225}, time = 0.196941875},
    {cframe = {99.6124038696289, 4.943913459777832, -56.94453048706055, 0.4694348871707916, -0.0014881669776514173, 0.8829658627510071, 0.00029534444911405444, 0.9999988079071045, 0.0015283945249393582, -0.8829670548439026, -0.00045670263352803886, 0.4694347679615021}, time = 0.214731823},
    {cframe = {99.6111068725586, 4.5350446701049805, -56.94503402709961, 0.46946680545806885, 0.006640626583248377, 0.8829251527786255, -0.0009330909233540297, 0.9999749064445496, -0.007024836260825396, -0.8829496502876282, 0.0024740779772400856, 0.46946123242378235}, time = 0.230810886},
    {cframe = {99.61017608642578, 4.071688652038574, -56.94537353515625, 0.4694615602493286, 0.002531249774619937, 0.8829492926597595, -0.0003737526712939143, 0.9999963641166687, -0.0026680785231292248, -0.8829528093338013, 0.0009225556277669966, 0.46946078538894653}, time = 0.247480938},
    {cframe = {99.61003875732422, 4.957582950592041, -56.94542694091797, 0.4694652557373047, -0.002147853374481201, 0.8829483389854431, 0.0002906309673562646, 0.9999973773956299, 0.0022780566941946745, -0.8829509019851685, -0.0008128563640639186, 0.46946462988853455}, time = 0.264475365},
    {cframe = {99.63864135742188, 5.500062942504883, -56.933597564697266, 0.46996867656707764, -0.01983392797410488, 0.8824602365493774, 0.0022517938632518053, 0.9997711777687073, 0.021271346136927605, -0.8826802372932434, -0.00800974853336811, 0.469905823469162}, time = 0.280428959},
    {cframe = {99.8426513671875, 5.557954788208008, -56.84584426879883, 0.47103753685951233, -0.1338093876838684, 0.8719052076339722, 0.010882752016186714, 0.9892341494560242, 0.14593631029129028, -0.8820460438728333, -0.059252750128507614, 0.46742263436317444}, time = 0.297325990},
    {cframe = {100.42105102539062, 5.760643005371094, -56.58469772338867, 0.46553507447242737, -0.423098623752594, 0.7773445844650269, 0.03336578607559204, 0.8860922457655789, 0.46230649948120117, -0.8844002485275269, -0.18928319215774536, 0.42662402987480164}, time = 0.313879896},
    {cframe = {101.265625, 6.554233074188232, -56.20363235473633, 0.44213733077049255, -0.7779374122619629, 0.44646158814430237, 0.061451345682144165, 0.522859513759613, 0.8502009510993958, -0.8948398232460022, -0.34846991300582886, 0.2789810299873352}, time = 0.330400104},
    {cframe = {102.20428466796875, 7.5512614250183105, -55.783668518066406, 0.39268171787261963, -0.739112138748169, 0.5472790002822876, 0.04716621711850166, 0.6104810237884521, 0.7906252145767212, -0.918464183807373, -0.284650981426239, 0.2745858430862427}, time = 0.349065886},
    {cframe = {103.19661712646484, 8.557190895080566, -55.33934783935547, 0.43588486313819885, -0.3473532497882843, 0.8302710652351379, 0.021037345752120018, 0.9262011647224426, 0.3764422833919525, -0.8997565507888794, -0.1466187983751297, 0.4110244810581207}, time = 0.365025261},
    {cframe = {104.1204605102539, 9.440471649169922, -54.92157745361328, 0.46827462315559387, -0.074355848133564, 0.8804488182067871, 0.0014966237358748913, 0.9965181946754456, 0.0833621695637703, -0.8835816979408264, -0.03771869093179703, 0.4667554795742035}, time = 0.379196563},
    {cframe = {104.9556655883789, 10.250682830810547, -54.542518615722656, 0.4701787829399109, 0.005445409100502729, 0.8825544118881226, -0.0018916272092610598, 0.999984860420227, -0.005162201356142759, -0.8825691938400269, 0.0007576936623081565, 0.47018197178840637}, time = 0.395883438},
    {cframe = {105.54358673095703, 10.821833610534668, -54.275840759277344, 0.4695419669151306, 0.012187809683382511, 0.882826030254364, -0.00132866227068007, 0.9999133348464966, -0.01309758611023426, -0.8829091787338257, 0.004976888652890921, 0.46951746940612793}, time = 0.412711042},
    {cframe = {106.47299194335938, 11.705678939819336, -53.854610443115234, 0.4694766700267792, 0.004624559078365564, 0.8829327821731567, -0.0002809193101711571, 0.999987006187439, -0.00508828554302454, -0.8829448223114014, 0.0021407983731478453, 0.46947187185287476}, time = 0.429630886},
    {cframe = {107.17646026611328, 12.351430892944336, -53.53590393066406, 0.46946510672569275, 0.0008859693771228194, 0.8829506039619446, -0.000009503080036665779, 0.9999995231628418, -0.000998365692794323, -0.882951021194458, 0.00046030711382627487, 0.46946486830711365}, time = 0.447288073},
    {cframe = {107.68084716796875, 12.799976348876953, -53.307403564453125, 0.4694644808769226, -0.00001197745314129861, 0.8829513788223267, 0.00002771819526969921, 1, -0.000001172493284684606, -0.8829513788223267, 0.000025024261049111374, 0.4694644808769226}, time = 0.463348646},
    {cframe = {108.47663116455078, 13.479427337646484, -52.94688415527344, 0.4694630801677704, -0.0001578327064635232, 0.882952094078064, 0.000014280461073212791, 1, 0.00017116281378548592, -0.882952094078064, -0.00006774565554223955, 0.4694630801677704}, time = 0.480375938},
    {cframe = {109.07262420654297, 13.961675643920898, -52.676876068115234, 0.46946287155151367, -0.00006067766298656352, 0.8829522132873535, 0.0000034831509765353985, 1, 0.00006686936103506014, -0.8829522132873535, -0.000028317226679064333, 0.46946287155151367}, time = 0.497358281},
    {cframe = {109.63241577148438, 14.389423370361328, -52.42326736450195, 0.4694625437259674, -0.000010310252946510445, 0.8829523921012878, -1.1697436796964666e-08, 1, 0.000011683239790727384, -0.8829523921012878, -0.000005495171535585541, 0.4694625437259674}, time = 0.514704792},
    {cframe = {110.15601348876953, 14.76267147064209, -52.18605422973633, 0.4694632887840271, 0.0000021628563899867004, 0.8829519748687744, -4.082312443642877e-07, 1, -0.000002232518681921647, -0.8829519748687744, 6.876369411656924e-07, 0.4694632887840271}, time = 0.531789583},
    {cframe = {110.64342498779297, 15.081418991088867, -51.96523666381836, 0.46946287155151367, 0.0000022100427941040834, 0.8829522132873535, -1.9078638047176355e-07, 1, -0.000002401574647592497, -0.8829522132873535, 9.589948604116216e-07, 0.46946287155151367}, time = 0.546918750},
    {cframe = {110.98523712158203, 15.284714698791504, -51.81037902832031, 0.4694638252258301, 0.000001082573817257071, 0.8829517364501953, -5.5013156696759324e-08, 1, -0.0000011968346598223434, -0.8829517364501953, 5.132965839038661e-07, 0.4694638252258301}, time = 0.562276302},
    {cframe = {111.50969696044922, 15.555416107177734, -51.57277297973633, 0.4694613814353943, 1.1275615463546274e-07, 0.8829529881477356, 1.017386086488159e-08, 1, -1.3311284874362173e-07, -0.8829529881477356, 7.147438196852818e-08, 0.4694613814353943}, time = 0.580070781},
    {cframe = {111.88855743408203, 15.710664749145508, -51.401126861572266, 0.4694617986679077, -5.0378485383362204e-08, 0.8829527497291565, 8.466404466389577e-09, 1, 5.2555282792354774e-08, -0.8829527497291565, -1.7197262280888026e-08, 0.4694617986679077}, time = 0.596821719},
    {cframe = {112.23123931884766, 15.811412811279297, -51.24587631225586, 0.46946126222610474, -1.0081255652494292e-07, 0.8829530477523804, 3.3723093206816657e-09, 1, 1.1238353181397542e-07, -0.8829530477523804, -4.978212686523875e-08, 0.46946126222610474}, time = 0.613685365},
}

local Vgxmod_rightBox = Instance.new("Part")
Vgxmod_rightBox.Name = "RightMovementTrigger"
Vgxmod_rightBox.Size = Vector3.new(1, 2, 1)
Vgxmod_rightBox.Position = Vector3.new(135, 1, -57)
Vgxmod_rightBox.Anchored = true
Vgxmod_rightBox.CanCollide = false
Vgxmod_rightBox.CanTouch = true
Vgxmod_rightBox.Transparency = 1
Vgxmod_rightBox.Material = Enum.Material.Neon
Vgxmod_rightBox.Color = Color3.fromRGB(168, 85, 247)
Vgxmod_rightBox.Parent = workspace

local Vgxmod_leftBox = Instance.new("Part")
Vgxmod_leftBox.Name = "LeftMovementTrigger"
Vgxmod_leftBox.Size = Vector3.new(1, 2, 1)
Vgxmod_leftBox.Position = Vector3.new(99, 1, -57)
Vgxmod_leftBox.Anchored = true
Vgxmod_leftBox.CanCollide = false
Vgxmod_leftBox.CanTouch = true
Vgxmod_leftBox.Transparency = 1
Vgxmod_leftBox.Material = Enum.Material.Neon
Vgxmod_leftBox.Color = Color3.fromRGB(168, 85, 247)
Vgxmod_leftBox.Parent = workspace

local Vgxmod_playing = false
local Vgxmod_cooldown = false

local function Vgxmod_playMove(movement)
	if Vgxmod_playing or Vgxmod_cooldown or #movement == 0 then
		return
	end
	local char = LocalPlayer.Character
	if not char then
		return
	end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum then
		return
	end
	Vgxmod_playing = true
	Vgxmod_cooldown = true
	local oldSpeed = hum.WalkSpeed
	local oldJump = hum.JumpPower
	local oldRotate = hum.AutoRotate
	hum.WalkSpeed = 0
	hum.JumpPower = 0
	hum.AutoRotate = false
	local start = os.clock()
	local idx = 1
	while idx <= #movement do
		local elapsed = os.clock() - start
		while idx <= #movement and elapsed >= movement[idx].time do
			local c = movement[idx].cframe
			hrp.CFrame = CFrame.new(
				c[1], c[2], c[3],
				c[4], c[5], c[6],
				c[7], c[8], c[9],
				c[10], c[11], c[12]
			)
			idx = idx + 1
		end
		if idx <= #movement then
			RunService.Heartbeat:Wait()
		end
	end
	if hum and hum.Parent then
		hum.WalkSpeed = oldSpeed
		hum.JumpPower = oldJump
		hum.AutoRotate = oldRotate
	end
	Vgxmod_playing = false
	task.delay(Vgxmod_Config.AutoFlingCooldown, function()
		Vgxmod_cooldown = false
	end)
end

local Vgxmod_rightConn
local Vgxmod_leftConn

local function Vgxmod_setupConns()
	if Vgxmod_rightConn then
		Vgxmod_rightConn:Disconnect()
		Vgxmod_rightConn = nil
	end
	if Vgxmod_leftConn then
		Vgxmod_leftConn:Disconnect()
		Vgxmod_leftConn = nil
	end
	if not Vgxmod_Config.AutoFlingEnabled then
		return
	end
	if Vgxmod_Config.AutoFlingDirection == "Both" or Vgxmod_Config.AutoFlingDirection == "Right" then
		Vgxmod_rightConn = Vgxmod_rightBox.Touched:Connect(function(hit)
			local char = LocalPlayer.Character
			if char and hit:IsDescendantOf(char) then
				task.spawn(function()
					Vgxmod_playMove(Vgxmod_rightMovement)
				end)
			end
		end)
	end
	if Vgxmod_Config.AutoFlingDirection == "Both" or Vgxmod_Config.AutoFlingDirection == "Left" then
		Vgxmod_leftConn = Vgxmod_leftBox.Touched:Connect(function(hit)
			local char = LocalPlayer.Character
			if char and hit:IsDescendantOf(char) then
				task.spawn(function()
					Vgxmod_playMove(Vgxmod_leftMovement)
				end)
			end
		end)
	end
end

local function Vgxmod_toggleFling(state)
	Vgxmod_Config.AutoFlingEnabled = state
	Vgxmod_setupConns()
end

local function Vgxmod_updateDir(dir)
	Vgxmod_Config.AutoFlingDirection = dir
	Vgxmod_setupConns()
end

local function Vgxmod_updateCooldown(val)
	Vgxmod_Config.AutoFlingCooldown = val
end


-- AUTO LOCK

local Vgxmod_char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Vgxmod_root = Vgxmod_char:WaitForChild("HumanoidRootPart")

local function Vgxmod_hasBomb()
	if not Vgxmod_char then return false end
	local equipped = Vgxmod_char:FindFirstChild("Bomb")
	if equipped and equipped:IsA("Tool") then
		return true
	end
	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
	if backpack then
		local tool = backpack:FindFirstChild("Bomb")
		if tool and tool:IsA("Tool") then
			return true
		end
	end
	return false
end

local function Vgxmod_getClosest()
	local closest = nil
	local shortest = Vgxmod_Config.AutoLockDistance
	for _, plr in pairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
			local pos = plr.Character.HumanoidRootPart.Position
			local dist = (pos - Vgxmod_root.Position).Magnitude
			if dist < shortest then
				shortest = dist
				closest = plr
			end
		end
	end
	return closest
end

RunService.RenderStepped:Connect(function()
	if Vgxmod_root and Vgxmod_root.Parent then
		local canLock = Vgxmod_Config.AutoLockEnabled
		if canLock and Vgxmod_Config.AutoLockMode == "Bomb" then
			canLock = Vgxmod_hasBomb()
		end
		local target = canLock and Vgxmod_getClosest() or nil
		if target and target.Character then
			local targetPart = target.Character:FindFirstChild(Vgxmod_Config.AutoLockTargetPart) or target.Character:FindFirstChild("HumanoidRootPart")
			if targetPart then
				local targetPos = targetPart.Position + Vector3.new(0, Vgxmod_Config.AutoLockVerticalOffset, 0)
				local dir = (Vector3.new(targetPos.X, Vgxmod_root.Position.Y, targetPos.Z) - Vgxmod_root.Position).Unit
				local baseCFrame = CFrame.new(Vgxmod_root.Position, Vgxmod_root.Position + dir)
				Vgxmod_root.CFrame = baseCFrame * CFrame.Angles(0, math.rad(Vgxmod_Config.AutoLockRotationAngle), 0)
			end
		end
	end
end)

LocalPlayer.CharacterAdded:Connect(function(char)
	Vgxmod_char = char
	Vgxmod_root = char:WaitForChild("HumanoidRootPart")
end)


-- ESP PLAYER

local Vgxmod_ESPFolder = Instance.new("Folder")
Vgxmod_ESPFolder.Name = "TeamCheckESP"
Vgxmod_ESPFolder.Parent = workspace

local Vgxmod_tracked = {}
local Vgxmod_RED = Color3.fromRGB(255, 0, 0)
local Vgxmod_BLUE = Color3.fromRGB(0, 100, 255)
local Vgxmod_GREEN = Color3.fromRGB(0, 255, 0)

local function Vgxmod_hide(plr)
	local data = Vgxmod_tracked[plr]
	if data and data.Highlight then
		data.Highlight.Enabled = false
	end
end

local function Vgxmod_destroy(plr)
	local data = Vgxmod_tracked[plr]
	if data then
		if data.Highlight then
			data.Highlight:Destroy()
		end
		Vgxmod_tracked[plr] = nil
	end
end

local function Vgxmod_should(plr)
	if not Vgxmod_Config.ESPEnabled then
		return false
	end
	if plr == LocalPlayer then
		return false
	end
	if plr:GetAttribute("Ingame") ~= true then
		return false
	end
	if plr:GetAttribute("Alive") ~= true then
		return false
	end
	local localIngame = LocalPlayer:GetAttribute("Ingame") == true
	local localArena = LocalPlayer:GetAttribute("Arena")
	local localTeam = LocalPlayer:GetAttribute("Team")
	if not localIngame then
		return true
	end
	local plrArena = plr:GetAttribute("Arena")
	local plrTeam = plr:GetAttribute("Team")
	if plrArena ~= localArena then
		return false
	end
	if plrTeam ~= "Left" and plrTeam ~= "Right" then
		return false
	end
	return true
end

local function Vgxmod_updateESP(plr)
	if not Vgxmod_should(plr) then
		Vgxmod_hide(plr)
		return
	end
	local char = plr.Character
	if not char then
		Vgxmod_hide(plr)
		return
	end
	local team = plr:GetAttribute("Team")
	local arena = plr:GetAttribute("Arena")
	local localIngame = LocalPlayer:GetAttribute("Ingame") == true
	local localArena = LocalPlayer:GetAttribute("Arena")
	local localTeam = LocalPlayer:GetAttribute("Team")
	local color
	if localIngame and arena == localArena and team == localTeam then
		color = Vgxmod_GREEN
	elseif team == "Left" then
		color = Vgxmod_RED
	elseif team == "Right" then
		color = Vgxmod_BLUE
	else
		Vgxmod_hide(plr)
		return
	end
	local data = Vgxmod_tracked[plr]
	if not data or data.Character ~= char then
		Vgxmod_destroy(plr)
		local highlight = Instance.new("Highlight")
		highlight.Name = "TeamESP"
		highlight.Adornee = char
		highlight.FillTransparency = 0.5
		highlight.OutlineTransparency = 2
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.Parent = Vgxmod_ESPFolder
		data = {
			Character = char,
			Highlight = highlight
		}
		Vgxmod_tracked[plr] = data
	end
	data.Highlight.Adornee = char
	data.Highlight.FillColor = color
	data.Highlight.OutlineColor = color
	data.Highlight.Enabled = true
end

local function Vgxmod_updateAll()
	for _, v in ipairs(Players:GetPlayers()) do
		Vgxmod_updateESP(v)
	end
end

local function Vgxmod_setup(plr)
	plr:GetAttributeChangedSignal("Ingame"):Connect(Vgxmod_updateAll)
	plr:GetAttributeChangedSignal("Alive"):Connect(function()
		Vgxmod_updateESP(plr)
	end)
	plr:GetAttributeChangedSignal("Arena"):Connect(Vgxmod_updateAll)
	plr:GetAttributeChangedSignal("Team"):Connect(Vgxmod_updateAll)
	plr.CharacterAdded:Connect(function(char)
		task.spawn(function()
			local head = char:WaitForChild("Head", 5)
			if head then
				Vgxmod_updateESP(plr)
			end
		end)
	end)
	plr.CharacterRemoving:Connect(function()
		Vgxmod_hide(plr)
	end)
	Vgxmod_updateESP(plr)
end

for _, v in ipairs(Players:GetPlayers()) do
	Vgxmod_setup(v)
end

Players.PlayerAdded:Connect(function(plr)
	Vgxmod_setup(plr)
	Vgxmod_updateAll()
end)

Players.PlayerRemoving:Connect(function(plr)
	Vgxmod_destroy(plr)
end)

task.spawn(function()
	while true do
		if Vgxmod_Config.ESPEnabled then
			Vgxmod_updateAll()
		end
		task.wait(1)
	end
end)


-- PLAYER TRACK UI

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Vgxmod_UIConfig = {
	TOGGLE_KEY = Enum.KeyCode.R,
	MAIN_COLOR = Color3.fromRGB(168, 85, 247),
	MAIN_COLOR_BRIGHT = Color3.fromRGB(192, 132, 252),
	BG_COLOR = Color3.fromRGB(25, 19, 53),
	BG_COLOR_ON = Color3.fromRGB(38, 20, 65),
	SIZE = 84,
	GLOW_SIZE = 105,
	DEFAULT_POSITION = UDim2.new(0.85, 0, 0.10, 0),
	ICON_ID = "rbxthumb://type=Asset&id=10455604811&w=420&h=420",
	CLICK_SOUND_ID = "rbxassetid://138656262630730",
	CLICK_VOLUME = 0.7,
	TOGGLE_COOLDOWN = 0.35,
	ROTATION_ANGLE = 45
}
local Vgxmod_GuiName = "PlayerTrackGui_v2"
local Vgxmod_oldGui = PlayerGui:FindFirstChild(Vgxmod_GuiName)
if Vgxmod_oldGui then
	Vgxmod_oldGui:Destroy()
end
local Vgxmod_State = {
	Enabled = false,
	Destroyed = false,
	LastToggle = 0
}
local Vgxmod_ScreenGui
local Vgxmod_Glow
local Vgxmod_Button
local Vgxmod_Stroke
local Vgxmod_StatusLabel
local Vgxmod_KeyLabel
local Vgxmod_DragButton

local function Vgxmod_tween(obj, dur, props, style, dir)
	local info = TweenInfo.new(
		dur,
		style or Enum.EasingStyle.Quad,
		dir or Enum.EasingDirection.Out
	)
	return TweenService:Create(obj, info, props)
end

local function Vgxmod_getChar()
	return LocalPlayer.Character
end

local function Vgxmod_getHumanoid()
	local char = Vgxmod_getChar()
	if not char then return nil end
	return char:FindFirstChildOfClass("Humanoid")
end

local function Vgxmod_getRoot()
	local char = Vgxmod_getChar()
	if not char then return nil end
	return char:FindFirstChild("HumanoidRootPart")
end

local function Vgxmod_getBombChar()
	local chars = workspace:FindFirstChild("Characters")
	if not chars then return nil end
	return chars:FindFirstChild(LocalPlayer.Name)
end

local function Vgxmod_hasBombTool()
	local char = Vgxmod_getBombChar()
	if not char then return false end
	return char:FindFirstChild("Bomb") ~= nil
end

local function Vgxmod_inArena(target)
	local data = target:FindFirstChild("Data")
	if not data then return false end
	local active = data:FindFirstChild("ActiveArena")
	if not active then return false end
	return active.Value ~= "" and active.Value ~= nil
end

local function Vgxmod_hasGreenESP(target)
	local char = target.Character
	if not char then return false end
	for _, v in ipairs(char:GetChildren()) do
		if v:IsA("Highlight") and v.FillColor == Color3.fromRGB(0, 255, 0) then
			return true
		end
	end
	for _, v in ipairs(workspace:GetChildren()) do
		if v:IsA("Highlight") and v.Adornee == char and v.FillColor == Color3.fromRGB(0, 255, 0) then
			return true
		end
	end
	return false
end

local function Vgxmod_isSpectator(target)
	local data = target:FindFirstChild("Data")
	if not data then return false end
	local active = data:FindFirstChild("ActiveArena")
	if not active then return false end
	return active.Value == "" or active.Value == nil
end

local function Vgxmod_sameTeam(target)
	local myIngame = LocalPlayer:GetAttribute("Ingame") or false
	local targetIngame = target:GetAttribute("Ingame") or false
	if myIngame and targetIngame then
		local myArena = LocalPlayer:GetAttribute("Arena") or 0
		local targetArena = target:GetAttribute("Arena") or 0
		if myArena == targetArena and myArena ~= 0 then
			local myTeam = LocalPlayer:GetAttribute("Team") or ""
			local targetTeam = target:GetAttribute("Team") or ""
			if myTeam ~= "" and targetTeam ~= "" then
				return myTeam == targetTeam
			end
		end
	end
	if not target.Team or not LocalPlayer.Team then return false end
	return target.Team.Name == LocalPlayer.Team.Name
end

local function Vgxmod_getNearest()
	local char = Vgxmod_getChar()
	if not char then return nil end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	local nearest = nil
	local nearestDist = math.huge
	for _, target in ipairs(Players:GetPlayers()) do
		if target == LocalPlayer then continue end
		local tChar = target.Character
		if not tChar then continue end
		local tRoot = tChar:FindFirstChild("HumanoidRootPart")
		local tHum = tChar:FindFirstChildOfClass("Humanoid")
		if not tRoot or not tHum or tHum.Health <= 0 then
			continue
		end
		if Vgxmod_isSpectator(target) then continue end
		if not Vgxmod_inArena(target) then continue end
		if Vgxmod_sameTeam(target) then continue end
		if Vgxmod_hasGreenESP(target) then continue end
		local dist = (root.Position - tRoot.Position).Magnitude
		if dist < nearestDist then
			nearestDist = dist
			nearest = target
		end
	end
	return nearest
end

local Vgxmod_moveKeys = {
	[Enum.KeyCode.W] = true,
	[Enum.KeyCode.A] = true,
	[Enum.KeyCode.S] = true,
	[Enum.KeyCode.D] = true,
	[Enum.KeyCode.Up] = true,
	[Enum.KeyCode.Down] = true,
	[Enum.KeyCode.Left] = true,
	[Enum.KeyCode.Right] = true
}
local Vgxmod_keysDown = {}
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if Vgxmod_moveKeys[input.KeyCode] then
		Vgxmod_keysDown[input.KeyCode] = true
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if Vgxmod_moveKeys[input.KeyCode] then
		Vgxmod_keysDown[input.KeyCode] = nil
	end
end)

local function Vgxmod_isMoving()
	for _, pressed in pairs(Vgxmod_keysDown) do
		if pressed then return true end
	end
	local hum = Vgxmod_getHumanoid()
	if hum and hum.MoveDirection.Magnitude > 0.05 then
		return true
	end
	return false
end

local function Vgxmod_isLocked()
	if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
		return true
	end
	if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
		local mouse = LocalPlayer:GetMouse()
		if mouse then
			local viewport = workspace.CurrentCamera.ViewportSize
			local center = Vector2.new(viewport.X / 2, viewport.Y / 2)
			local dist = (Vector2.new(mouse.X, mouse.Y) - center).Magnitude
			if dist < 5 then
				return true
			end
		end
	end
	return false
end

local function Vgxmod_updateUI(anim)
	if not Vgxmod_Button or not Vgxmod_Stroke then return end
	local btnColor = Vgxmod_State.Enabled and Vgxmod_UIConfig.BG_COLOR_ON or Vgxmod_UIConfig.BG_COLOR
	local strokeColor = Vgxmod_State.Enabled and Vgxmod_UIConfig.MAIN_COLOR_BRIGHT or Vgxmod_UIConfig.MAIN_COLOR
	if anim then
		Vgxmod_tween(Vgxmod_Button, 0.2, { BackgroundColor3 = btnColor }):Play()
		Vgxmod_tween(Vgxmod_Stroke, 0.2, { Color = strokeColor }):Play()
	else
		Vgxmod_Button.BackgroundColor3 = btnColor
		Vgxmod_Stroke.Color = strokeColor
	end
	if Vgxmod_StatusLabel then
		if Vgxmod_State.Enabled then
			Vgxmod_StatusLabel.Text = "TRACKING"
			Vgxmod_StatusLabel.TextColor3 = Vgxmod_UIConfig.MAIN_COLOR_BRIGHT
		else
			Vgxmod_StatusLabel.Text = "OFF"
			Vgxmod_StatusLabel.TextColor3 = Color3.fromRGB(210, 210, 220)
		end
	end
end

local function Vgxmod_playClick()
	local sound = Instance.new("Sound")
	sound.Name = "PlayerTrackClick_v2"
	sound.SoundId = Vgxmod_UIConfig.CLICK_SOUND_ID
	sound.Volume = Vgxmod_UIConfig.CLICK_VOLUME
	sound.Parent = SoundService
	sound:Play()
	task.delay(2, function()
		if sound and sound.Parent then
			sound:Destroy()
		end
	end)
end

local function Vgxmod_animatePress()
	if not Vgxmod_Button then return end
	local normal = UDim2.new(0, Vgxmod_UIConfig.SIZE, 0, Vgxmod_UIConfig.SIZE)
	local pressed = UDim2.new(0, Vgxmod_UIConfig.SIZE - 6, 0, Vgxmod_UIConfig.SIZE - 6)
	local shrink = Vgxmod_tween(Vgxmod_Button, 0.06, { Size = pressed })
	local grow = Vgxmod_tween(Vgxmod_Button, 0.12, { Size = normal }, Enum.EasingStyle.Back)
	shrink:Play()
	shrink.Completed:Once(function()
		if Vgxmod_Button and Vgxmod_Button.Parent then
			grow:Play()
		end
	end)
end

local function Vgxmod_toggle()
	local now = os.clock()
	if Vgxmod_State.Destroyed then return end
	if now - Vgxmod_State.LastToggle < Vgxmod_UIConfig.TOGGLE_COOLDOWN then return end
	Vgxmod_State.LastToggle = now
	Vgxmod_State.Enabled = not Vgxmod_State.Enabled
	Vgxmod_playClick()
	Vgxmod_animatePress()
	Vgxmod_updateUI(true)
	local hum = Vgxmod_getHumanoid()
	if hum then
		hum.AutoRotate = not Vgxmod_State.Enabled
	end
end

function setPlayerTrack(Value)
	Vgxmod_Config.ShowTrackButton = Value
	if Vgxmod_Button then
		Vgxmod_Button.Visible = Value
	end
	if Vgxmod_Glow then
		Vgxmod_Glow.Visible = Value
	end
end

function setTrackButtonLocked(Value)
	Vgxmod_Config.LockTrackButtonPosition = Value
end

local function Vgxmod_glowLoop()
	if not Vgxmod_Glow then return end
	task.spawn(function()
		while not Vgxmod_State.Destroyed and Vgxmod_Glow and Vgxmod_Glow.Parent do
			local trans = Vgxmod_State.Enabled and 0.68 or 0.82
			local first = Vgxmod_tween(Vgxmod_Glow, 1.2, { BackgroundTransparency = trans }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			first:Play()
			first.Completed:Wait()
			if Vgxmod_State.Destroyed or not Vgxmod_Glow or not Vgxmod_Glow.Parent then
				break
			end
			local second = Vgxmod_tween(Vgxmod_Glow, 1.2, { BackgroundTransparency = math.min(trans + 0.08, 0.95) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			second:Play()
			second.Completed:Wait()
		end
	end)
end

local function Vgxmod_buildGUI()
	Vgxmod_ScreenGui = Instance.new("ScreenGui")
	Vgxmod_ScreenGui.Name = Vgxmod_GuiName
	Vgxmod_ScreenGui.ResetOnSpawn = false
	Vgxmod_ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	Vgxmod_ScreenGui.DisplayOrder = 999
	Vgxmod_ScreenGui.Parent = PlayerGui
	Vgxmod_Glow = Instance.new("Frame")
	Vgxmod_Glow.Name = "Glow_v2"
	Vgxmod_Glow.AnchorPoint = Vector2.new(0.5, 0.5)
	Vgxmod_Glow.Position = Vgxmod_UIConfig.DEFAULT_POSITION
	Vgxmod_Glow.Size = UDim2.new(0, Vgxmod_UIConfig.GLOW_SIZE, 0, Vgxmod_UIConfig.GLOW_SIZE)
	Vgxmod_Glow.BackgroundColor3 = Vgxmod_UIConfig.MAIN_COLOR
	Vgxmod_Glow.BackgroundTransparency = 0.82
	Vgxmod_Glow.BorderSizePixel = 0
	Vgxmod_Glow.Visible = false
	Vgxmod_Glow.ZIndex = 1
	Vgxmod_Glow.Parent = Vgxmod_ScreenGui
	local corner1 = Instance.new("UICorner")
	corner1.CornerRadius = UDim.new(0, 28)
	corner1.Parent = Vgxmod_Glow
	Vgxmod_Button = Instance.new("Frame")
	Vgxmod_Button.Name = "PlayerTrackButton_v2"
	Vgxmod_Button.AnchorPoint = Vector2.new(0.5, 0.5)
	Vgxmod_Button.Position = Vgxmod_UIConfig.DEFAULT_POSITION
	Vgxmod_Button.Size = UDim2.new(0, Vgxmod_UIConfig.SIZE, 0, Vgxmod_UIConfig.SIZE)
	Vgxmod_Button.BackgroundColor3 = Vgxmod_UIConfig.BG_COLOR
	Vgxmod_Button.BackgroundTransparency = 0.05
	Vgxmod_Button.BorderSizePixel = 0
	Vgxmod_Button.Visible = false
	Vgxmod_Button.ZIndex = 5
	Vgxmod_Button.Parent = Vgxmod_ScreenGui
	local corner2 = Instance.new("UICorner")
	corner2.CornerRadius = UDim.new(0, 22)
	corner2.Parent = Vgxmod_Button
	Vgxmod_Stroke = Instance.new("UIStroke")
	Vgxmod_Stroke.Name = "Outline_v2"
	Vgxmod_Stroke.Thickness = 2.5
	Vgxmod_Stroke.Color = Vgxmod_UIConfig.MAIN_COLOR
	Vgxmod_Stroke.Transparency = 0
	Vgxmod_Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	Vgxmod_Stroke.Parent = Vgxmod_Button
	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon_v2"
	icon.BackgroundTransparency = 1
	icon.Image = Vgxmod_UIConfig.ICON_ID
	icon.Size = UDim2.new(0.72, 0, 0.72, 0)
	icon.Position = UDim2.new(0.5, 0, 0.46, 0)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.ImageColor3 = Color3.fromRGB(255, 255, 255)
	icon.ScaleType = Enum.ScaleType.Fit
	icon.ZIndex = 7
	icon.Parent = Vgxmod_Button
	Vgxmod_StatusLabel = Instance.new("TextLabel")
	Vgxmod_StatusLabel.Name = "Status_v2"
	Vgxmod_StatusLabel.BackgroundTransparency = 1
	Vgxmod_StatusLabel.Size = UDim2.new(1, 0, 0, 15)
	Vgxmod_StatusLabel.Position = UDim2.new(0.5, 0, 0.91, 0)
	Vgxmod_StatusLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	Vgxmod_StatusLabel.Text = "OFF"
	Vgxmod_StatusLabel.TextColor3 = Color3.fromRGB(210, 210, 220)
	Vgxmod_StatusLabel.TextSize = 8
	Vgxmod_StatusLabel.Font = Enum.Font.GothamBold
	Vgxmod_StatusLabel.TextXAlignment = Enum.TextXAlignment.Center
	Vgxmod_StatusLabel.ZIndex = 8
	Vgxmod_StatusLabel.Parent = Vgxmod_Button
	Vgxmod_KeyLabel = Instance.new("TextLabel")
	Vgxmod_KeyLabel.Name = "Key_v2"
	Vgxmod_KeyLabel.BackgroundColor3 = Vgxmod_UIConfig.MAIN_COLOR
	Vgxmod_KeyLabel.Size = UDim2.new(0, 18, 0, 18)
	Vgxmod_KeyLabel.Position = UDim2.new(0.88, 0, 0.10, 0)
	Vgxmod_KeyLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	Vgxmod_KeyLabel.Text = "R"
	Vgxmod_KeyLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	Vgxmod_KeyLabel.TextSize = 9
	Vgxmod_KeyLabel.Font = Enum.Font.GothamBold
	Vgxmod_KeyLabel.ZIndex = 10
	Vgxmod_KeyLabel.Parent = Vgxmod_Button
	local corner3 = Instance.new("UICorner")
	corner3.CornerRadius = UDim.new(1, 0)
	corner3.Parent = Vgxmod_KeyLabel
	Vgxmod_DragButton = Instance.new("TextButton")
	Vgxmod_DragButton.Name = "DragButton_v2"
	Vgxmod_DragButton.Size = UDim2.new(1, 0, 1, 0)
	Vgxmod_DragButton.BackgroundTransparency = 1
	Vgxmod_DragButton.Text = ""
	Vgxmod_DragButton.AutoButtonColor = false
	Vgxmod_DragButton.ZIndex = 20
	Vgxmod_DragButton.Parent = Vgxmod_Button
	Vgxmod_updateUI(false)
	Vgxmod_glowLoop()
end

local function Vgxmod_setupDrag()
	local dragging = false
	local dragStart = nil
	local startPos = nil
	local moved = false
	Vgxmod_DragButton.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			moved = false
			dragStart = input.Position
			startPos = Vgxmod_Button.Position
		end
	end)
	Vgxmod_DragButton.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			if Vgxmod_Config.LockTrackButtonPosition then return end
			local delta = input.Position - dragStart
			if delta.Magnitude > 5 then
				moved = true
			end
			local newPos = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + delta.X,
				startPos.Y.Scale,
				startPos.Y.Offset + delta.Y
			)
			Vgxmod_Button.Position = newPos
			Vgxmod_Glow.Position = newPos
		end
	end)
	Vgxmod_DragButton.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if dragging then
				if not moved then
					Vgxmod_toggle()
				end
				dragging = false
			end
		end
	end)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Vgxmod_UIConfig.TOGGLE_KEY then
		Vgxmod_toggle()
	end
end)

RunService.RenderStepped:Connect(function()
	if not Vgxmod_State.Enabled then return end
	local char = Vgxmod_getChar()
	if not char then return end
	local hum = Vgxmod_getHumanoid()
	local root = Vgxmod_getRoot()
	if not hum or not root then return end
	if not Vgxmod_hasBombTool() then
		hum.AutoRotate = true
		return
	end
	if Vgxmod_isMoving() then
		hum.AutoRotate = true
		return
	end
	local target = Vgxmod_getNearest()
	if not target then return end
	local tChar = target.Character
	if not tChar then return end
	local tRoot = tChar:FindFirstChild("HumanoidRootPart")
	if not tRoot then return end
	local dir = tRoot.Position - root.Position
	dir = Vector3.new(dir.X, 0, dir.Z)
	if dir.Magnitude > 2 then
		dir = dir.Unit
		hum:Move(dir, false)
		local locked = Vgxmod_isLocked()
		if not locked then
			local rotated = CFrame.Angles(0, math.rad(Vgxmod_UIConfig.ROTATION_ANGLE), 0):VectorToWorldSpace(dir)
			root.CFrame = CFrame.lookAt(root.Position, root.Position + rotated)
			hum.AutoRotate = false
		else
			root.CFrame = CFrame.lookAt(root.Position, root.Position + dir)
			hum.AutoRotate = true
		end
	else
		hum:Move(Vector3.zero, false)
	end
end)

LocalPlayer.CharacterAdded:Connect(function(char)
	local hum = char:WaitForChild("Humanoid")
	if Vgxmod_State.Enabled and Vgxmod_hasBombTool() then
		hum.AutoRotate = false
	else
		hum.AutoRotate = true
	end
	if Vgxmod_Button then
		Vgxmod_Button.Visible = Vgxmod_Config.ShowTrackButton
	end
	if Vgxmod_Glow then
		Vgxmod_Glow.Visible = Vgxmod_Config.ShowTrackButton
	end
end)

Vgxmod_buildGUI()
Vgxmod_setupDrag()


-- BLOCK ASSIST

local Vgxmod_visualBox = nil

local function Vgxmod_getWall()
	local success, wall = pcall(function()
		return workspace.Arenas.Arena3.Map.Wall.Wall
	end)
	return success and wall or nil
end

local function Vgxmod_createBox()
	if Vgxmod_visualBox then
		Vgxmod_visualBox:Destroy()
		Vgxmod_visualBox = nil
	end
	local src = Vgxmod_getWall()
	if not src then return end
	local box = Instance.new("Part")
	box.Name = "VisualBox_BlockAssist3"
	box.Size = Vector3.new(15, 1, 3)
	box.Position = Vector3.new(117.09, 1, -60.49)
	box.Anchored = true
	box.CanCollide = true
	box.Transparency = 0
	box.Color = src.Color
	box.Material = src.Material
	box.MaterialVariant = src.MaterialVariant
	box.Reflectance = src.Reflectance
	for _, child in ipairs(src:GetChildren()) do
		if child:IsA("Texture") or child:IsA("Decal") or child:IsA("SurfaceAppearance") then
			local clone = child:Clone()
			clone.Parent = box
		end
	end
	box.Parent = workspace
	Vgxmod_visualBox = box
	return box
end

local function Vgxmod_removeBox()
	if Vgxmod_visualBox then
		Vgxmod_visualBox:Destroy()
		Vgxmod_visualBox = nil
	end
end

local function Vgxmod_apply3(enable)
	if enable then
		Vgxmod_createBox()
	else
		Vgxmod_removeBox()
	end
end

local function Vgxmod_apply2(enable)
	local arena3 = workspace:FindFirstChild("Arenas") and workspace.Arenas:FindFirstChild("Arena3")
	if not arena3 then return end
	local walls = {}
	for _, obj in ipairs(arena3:GetDescendants()) do
		if obj.Name == "Wall" and obj:IsA("BasePart") then
			if obj.Position.Y < 5 then
				table.insert(walls, obj)
			end
		end
	end
	for _, wall in ipairs(walls) do
		if enable then
			wall.Size = Vector3.new(11, 3, 2)
		else
			wall.Size = Vector3.new(10, 3, 1)
		end
	end
end

local function Vgxmod_apply1(enable)
	if enable then
		local old = workspace:FindFirstChild("VGX_Cross")
		if old then
			old:Destroy()
		end
		local folder = Instance.new("Folder")
		folder.Name = "VGX_Cross"
		folder.Parent = workspace
		local center = Vector3.new(117.000, 0.6, -30.000)
		local function makeBlock(name, size, pos)
			local block = Instance.new("Part")
			block.Name = name
			block.Size = size
			block.Position = pos
			block.Anchored = true
			block.CanCollide = true
			block.Color = Color3.fromRGB(218, 133, 65)
			block.Material = Enum.Material.Wood
			block.Transparency = 0
			block.Reflectance = 0
			block.Parent = folder
		end
		makeBlock("Center", Vector3.new(3, 3, 10), center)
		makeBlock("Left", Vector3.new(4.5, 3, 3), center + Vector3.new(-2.75, 0, 0))
		makeBlock("Right", Vector3.new(4.5, 3, 3), center + Vector3.new(2.75, 0, 0))
	else
		local old = workspace:FindFirstChild("VGX_Cross")
		if old then
			old:Destroy()
		end
	end
end

local function Vgxmod_apply5(enable)
	local arenas = workspace:FindFirstChild("Arenas")
	if not arenas then return end
	local arena5 = arenas:FindFirstChild("Arena5")
	if not arena5 then return end
	for _, wall in ipairs(arena5:GetDescendants()) do
		if wall:IsA("BasePart") and wall.Name == "Wall" then
			if enable then
				wall.Size = Vector3.new(11, 3, 2)
			else
				wall.Size = Vector3.new(10, 3, 1)
			end
		end
	end
end


-- SPEED / JUMP / SNAP ROTATE

local Vgxmod_charSpeed, Vgxmod_hum, Vgxmod_hrp

local function Vgxmod_setupCharSpeed(c)
	Vgxmod_charSpeed = c
	Vgxmod_hum = c:WaitForChild("Humanoid")
	Vgxmod_hrp = c:WaitForChild("HumanoidRootPart")
end

if LocalPlayer.Character then
	Vgxmod_setupCharSpeed(LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(function(c)
	task.wait(0.1)
	Vgxmod_setupCharSpeed(c)
end)

RunService.Stepped:Connect(function()
	if Vgxmod_Config.TPWalkEnabled and Vgxmod_charSpeed and Vgxmod_hum and Vgxmod_hrp then
		if Vgxmod_hum.Health <= 0 then
			return
		end
		local dir = Vgxmod_hum.MoveDirection
		if dir.Magnitude > 0 then
			Vgxmod_hrp.CFrame = Vgxmod_hrp.CFrame + (dir * Vgxmod_Config.TPWalkSpeed)
		end
	end
end)

local Vgxmod_jChar, Vgxmod_jHum, Vgxmod_jHrp
local Vgxmod_jumpConn

local function Vgxmod_setupJump(c)
	Vgxmod_jChar = c
	Vgxmod_jHum = c:WaitForChild("Humanoid")
	Vgxmod_jHrp = c:WaitForChild("HumanoidRootPart")
	if Vgxmod_jumpConn then
		Vgxmod_jumpConn:Disconnect()
		Vgxmod_jumpConn = nil
	end
	Vgxmod_jumpConn = Vgxmod_jHum.StateChanged:Connect(function(_, newState)
		if not Vgxmod_Config.JumpBoostEnabled then
			return
		end
		if newState == Enum.HumanoidStateType.Jumping then
			if Vgxmod_jHum.Health <= 0 or not Vgxmod_jHrp then
				return
			end
			local vel = Vgxmod_jHrp.AssemblyLinearVelocity
			Vgxmod_jHrp.AssemblyLinearVelocity = Vector3.new(
				vel.X,
				vel.Y + Vgxmod_Config.JumpBoost,
				vel.Z
			)
		end
	end)
end

if LocalPlayer.Character then
	Vgxmod_setupJump(LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(function(c)
	task.wait(0.1)
	Vgxmod_setupJump(c)
end)

local Vgxmod_rotConn

local function Vgxmod_setupRotate(char)
	local hum = char:WaitForChild("Humanoid")
	local hrp = char:WaitForChild("HumanoidRootPart")
	hum.AutoRotate = true
	if Vgxmod_rotConn then
		Vgxmod_rotConn:Disconnect()
		Vgxmod_rotConn = nil
	end
	Vgxmod_rotConn = RunService.RenderStepped:Connect(function()
		if not hum or not hrp or hum.Health <= 0 then return end
		if not Vgxmod_Config.SnapRotateEnabled then return end
		local dir = hum.MoveDirection
		if dir.Magnitude > 0.1 then
			local target = CFrame.lookAt(hrp.Position, hrp.Position + dir)
			hrp.CFrame = hrp.CFrame:Lerp(target, Vgxmod_Config.SnapRotateSpeed)
		end
	end)
end

LocalPlayer.CharacterAdded:Connect(Vgxmod_setupRotate)
if LocalPlayer.Character then
	Vgxmod_setupRotate(LocalPlayer.Character)
end


-- HEADLESS / KORBLOX

local Vgxmod_KORBLOX = "rbxassetid://101851696"
local Vgxmod_KORBLOX_TEX = "rbxassetid://101851254"
local Vgxmod_BLACK = Color3.fromRGB(17, 17, 17)
local Vgxmod_headData = {}
local Vgxmod_legData = {}

local function Vgxmod_applyHead(char, enable)
	local head = char:WaitForChild("Head", 5)
	if not head then return end
	if not Vgxmod_headData[char] then
		local face = head:FindFirstChild("face")
		Vgxmod_headData[char] = {
			Transparency = head.Transparency,
			FaceTransparency = face and face.Transparency or 0
		}
	end
	if enable then
		head.Transparency = 1
		local face = head:FindFirstChild("face")
		if face and face:IsA("Decal") then
			face.Transparency = 1
		end
	else
		local data = Vgxmod_headData[char]
		head.Transparency = data and data.Transparency or 0
		local face = head:FindFirstChild("face")
		if face and face:IsA("Decal") then
			face.Transparency = data and data.FaceTransparency or 0
		end
	end
end

local function Vgxmod_applyKorblox(char, enable)
	local leg = char:WaitForChild("Right Leg", 5) or char:WaitForChild("RightLeg", 5)
	if not leg then return end
	if not Vgxmod_legData[char] then
		Vgxmod_legData[char] = {
			Color = leg.Color,
			Material = leg.Material
		}
	end
	if enable then
		leg.Color = Vgxmod_BLACK
		for _, child in ipairs(leg:GetChildren()) do
			if child:IsA("SpecialMesh") or child:IsA("CharacterMesh") then
				child:Destroy()
			end
		end
		local mesh = Instance.new("SpecialMesh")
		mesh.Name = "KorbloxMesh"
		mesh.MeshType = Enum.MeshType.FileMesh
		mesh.MeshId = Vgxmod_KORBLOX
		mesh.TextureId = Vgxmod_KORBLOX_TEX
		mesh.Scale = Vector3.new(1, 1, 1)
		mesh.Parent = leg
	else
		local data = Vgxmod_legData[char]
		leg.Color = data and data.Color or Color3.fromRGB(255, 255, 255)
		leg.Material = data and data.Material or Enum.Material.Plastic
		local mesh = leg:FindFirstChild("KorbloxMesh")
		if mesh then
			mesh:Destroy()
		end
	end
end

LocalPlayer.CharacterAdded:Connect(function(char)
	Vgxmod_headData[char] = nil
	Vgxmod_legData[char] = nil
	task.wait(0.5)
	if Vgxmod_Config.HeadlessEnabled then
		Vgxmod_applyHead(char, true)
	end
	if Vgxmod_Config.KorbloxEnabled then
		Vgxmod_applyKorblox(char, true)
	end
end)


-- TRAIL EFFECT

local Vgxmod_activeTrail = nil

local function Vgxmod_updateTrail()
	local char = LocalPlayer.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	if Vgxmod_Config.TrailEnabled then
		if not Vgxmod_activeTrail then
			local att0 = Instance.new("Attachment")
			att0.Name = "TrailAttachment0"
			att0.Position = Vector3.new(0, 1, 0)
			att0.Parent = root
			local att1 = Instance.new("Attachment")
			att1.Name = "TrailAttachment1"
			att1.Position = Vector3.new(0, -1, 0)
			att1.Parent = root
			local trail = Instance.new("Trail")
			trail.Name = "CustomTrail"
			trail.Attachment0 = att0
			trail.Attachment1 = att1
			trail.Color = ColorSequence.new(Vgxmod_Config.TrailColor)
			trail.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.2),
				NumberSequenceKeypoint.new(1, 1)
			})
			trail.Lifetime = 0.6
			trail.Parent = root
			Vgxmod_activeTrail = trail
		else
			Vgxmod_activeTrail.Color = ColorSequence.new(Vgxmod_Config.TrailColor)
		end
	else
		if Vgxmod_activeTrail then
			local att0 = Vgxmod_activeTrail.Attachment0
			local att1 = Vgxmod_activeTrail.Attachment1
			Vgxmod_activeTrail:Destroy()
			if att0 then att0:Destroy() end
			if att1 then att1:Destroy() end
			Vgxmod_activeTrail = nil
		end
	end
end

local function Vgxmod_updateColor(color)
	Vgxmod_Config.TrailColor = color
	if Vgxmod_activeTrail then
		Vgxmod_activeTrail.Color = ColorSequence.new(color)
	end
end

local function Vgxmod_setupTrailChar(char)
	char:WaitForChild("HumanoidRootPart")
	if Vgxmod_Config.TrailEnabled then
		Vgxmod_activeTrail = nil
		Vgxmod_updateTrail()
	end
end

LocalPlayer.CharacterAdded:Connect(Vgxmod_setupTrailChar)
if LocalPlayer.Character then
	task.spawn(function()
		Vgxmod_setupTrailChar(LocalPlayer.Character)
	end)
end


-- HEAD FIRE

local Vgxmod_fireAttach = nil
local Vgxmod_fireParticle = nil
local Vgxmod_fireConn = nil

local function Vgxmod_createFire()
	local char = LocalPlayer.Character
	if not char then return end
	local head = char:FindFirstChild("Head")
	if not head then return end
	Vgxmod_fireAttach = Instance.new("Attachment")
	Vgxmod_fireAttach.Name = "FireAttachment"
	Vgxmod_fireAttach.Position = Vector3.new(0, 1.5, 0)
	Vgxmod_fireAttach.Parent = head
	local template = game.ReplicatedStorage:FindFirstChild("Assets") and
		game.ReplicatedStorage.Assets:FindFirstChild("World") and
		game.ReplicatedStorage.Assets.World:FindFirstChild("Particles") and
		game.ReplicatedStorage.Assets.World.Particles:FindFirstChild("Fire")
	if template then
		Vgxmod_fireParticle = template:Clone()
		Vgxmod_fireParticle.Parent = Vgxmod_fireAttach
		Vgxmod_fireParticle.Enabled = true	
		Vgxmod_fireParticle.Rate = 100
		Vgxmod_fireParticle.Lifetime = NumberRange.new(0.3, 0.6)
		Vgxmod_fireParticle.Acceleration = Vector3.new(0, 15, 0)
	else
		Vgxmod_fireParticle = Instance.new("ParticleEmitter")
		Vgxmod_fireParticle.Name = "FireParticle"
		Vgxmod_fireParticle.Texture = "rbxasset://textures/particles/fire_main.dds"
		Vgxmod_fireParticle.Color = ColorSequence.new(Color3.fromRGB(255, 150, 0), Color3.fromRGB(255, 50, 0))
		Vgxmod_fireParticle.Size = NumberSequence.new(3, 6)
		Vgxmod_fireParticle.Transparency = NumberSequence.new(0, 0.8)
		Vgxmod_fireParticle.Rate = 100
		Vgxmod_fireParticle.Lifetime = NumberRange.new(0.3, 0.6)
		Vgxmod_fireParticle.SpreadAngle = Vector2.new(30, 30)
		Vgxmod_fireParticle.VelocityInheritance = 0.5
		Vgxmod_fireParticle.Acceleration = Vector3.new(0, 15, 0)
		Vgxmod_fireParticle.Drag = 0.3
		Vgxmod_fireParticle.LockedToPart = true
		Vgxmod_fireParticle.Parent = Vgxmod_fireAttach
		Vgxmod_fireParticle.Enabled = true
	end
end

local function Vgxmod_removeFire()
	if Vgxmod_fireParticle then
		Vgxmod_fireParticle:Destroy()
		Vgxmod_fireParticle = nil
	end
	if Vgxmod_fireAttach then
		Vgxmod_fireAttach:Destroy()
		Vgxmod_fireAttach = nil
	end
end

local function Vgxmod_toggleFire(state)
	Vgxmod_Config.HeadFireEnabled = state
	if Vgxmod_fireConn then
		Vgxmod_fireConn:Disconnect()
		Vgxmod_fireConn = nil
	end
	if state then
		Vgxmod_createFire()
		Vgxmod_fireConn = LocalPlayer.CharacterAdded:Connect(function(char)
			task.wait(0.5)
			if Vgxmod_Config.HeadFireEnabled then
				Vgxmod_removeFire()
				Vgxmod_createFire()
			end
		end)
	else
		Vgxmod_removeFire()
	end
end

Vgxmod_toggleFire(false)


-- HITBOX

local HitboxSizes = {3, 5, 7, 9, 11}
local CurrentIndex = 1
local Timer = 0
local GREEN = Color3.fromRGB(0, 255, 0)
local cachedPlayers = {}
local lastCheck = 0
local CHECK_INTERVAL = 0.5

local function isSpectator(player)
	local data = player:FindFirstChild("Data")
	if not data then return false end
	local activeArena = data:FindFirstChild("ActiveArena")
	if not activeArena then return false end
	return activeArena.Value == "" or activeArena.Value == nil
end

local function isPlayerInArena(player)
	local data = player:FindFirstChild("Data")
	if not data then return false end
	local activeArena = data:FindFirstChild("ActiveArena")
	if not activeArena then return false end
	return activeArena.Value ~= "" and activeArena.Value ~= nil
end

local function isPlayerOnMyTeam(player)
	if not player.Team or not LocalPlayer.Team then return false end
	return player.Team.Name == LocalPlayer.Team.Name
end

local function playerHasGreenESP(player)
	local character = player.Character
	if not character then return false end
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Highlight") and child.FillColor == GREEN then
			return true
		end
	end
	for _, child in ipairs(workspace:GetChildren()) do
		if child:IsA("Highlight") and child.Adornee == character and child.FillColor == GREEN then
			return true
		end
	end
	return false
end

local function shouldApplyHitbox(player)
	if player == LocalPlayer then return false end
	if isSpectator(player) then return false end
	if not isPlayerInArena(player) then return false end
	if isPlayerOnMyTeam(player) then return false end
	if playerHasGreenESP(player) then return false end
	return true
end

local function updateValidPlayers()
	cachedPlayers = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if shouldApplyHitbox(player) then
			table.insert(cachedPlayers, player)
		end
	end
end

updateValidPlayers()

Players.PlayerAdded:Connect(updateValidPlayers)
Players.PlayerRemoving:Connect(updateValidPlayers)

RunService.Heartbeat:Connect(function(deltaTime)
	if not Vgxmod_Config.HitboxEnabled then return end

	Timer += deltaTime

	if Timer >= Vgxmod_Config.HitboxInterval then
		Timer = 0
		CurrentIndex += 1
		if CurrentIndex > #HitboxSizes then
			CurrentIndex = 1
		end
	end

	lastCheck += deltaTime
	if lastCheck >= CHECK_INTERVAL then
		lastCheck = 0
		updateValidPlayers()
	end

	local size = Vector3.new(HitboxSizes[CurrentIndex], HitboxSizes[CurrentIndex], HitboxSizes[CurrentIndex])

	for _, player in ipairs(cachedPlayers) do
		local character = player.Character
		if not character then continue end
		
		local left = character:FindFirstChild("LeftHand") or character:FindFirstChild("Left Arm")
		local right = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
		
		if left then
			left.Size = size
			left.Transparency = 1
			left.CanCollide = false
			left.Massless = true
		end
		
		if right then
			right.Size = size
			right.Transparency = 1
			right.CanCollide = false
			right.Massless = true
		end
	end
end)

-- FPS BOOSTER
local Vgxmod_settings = {
	LOW = {
		textures = false,
		effects = false,
		lights = false,
		shadows = true,
		accessories = false,
		clothing = false,
		materials = false,
		sky = false,
		terrain = false
	},
	MEDIUM = {
		textures = true,
		effects = true,
		lights = true,
		shadows = true,
		accessories = false,
		clothing = false,
		materials = true,
		sky = false,
		terrain = true
	},
	ULTRA = {
		textures = true,
		effects = true,
		lights = true,
		shadows = true,
		accessories = true,
		clothing = true,
		materials = true,
		sky = true,
		terrain = true
	}
}
local Vgxmod_config = Vgxmod_settings[Vgxmod_Config.FPSBoostMode]
local Vgxmod_conns = {}
local Vgxmod_saved = {}
local Vgxmod_savedLighting = {}

local function Vgxmod_save(obj, key, value)
	if not Vgxmod_saved[obj] then
		Vgxmod_saved[obj] = {}
	end
	if Vgxmod_saved[obj][key] == nil then
		Vgxmod_saved[obj][key] = value
	end
end

local function Vgxmod_optimize(obj)
	if Vgxmod_config.textures then
		if obj:IsA("Decal") or obj:IsA("Texture") then
			pcall(function()
				Vgxmod_save(obj, "Transparency", obj.Transparency)
				obj.Transparency = 1
			end)
		end
	end
	if Vgxmod_config.effects then
		if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
			pcall(function()
				Vgxmod_save(obj, "Enabled", obj.Enabled)
				obj.Enabled = false
			end)
		end
	end
	if Vgxmod_config.lights then
		if obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
			pcall(function()
				Vgxmod_save(obj, "Enabled", obj.Enabled)
				obj.Enabled = false
			end)
		end
	end
	if Vgxmod_config.shadows and obj:IsA("BasePart") then
		pcall(function()
			Vgxmod_save(obj, "CastShadow", obj.CastShadow)
			obj.CastShadow = false
		end)
	end
	if Vgxmod_config.materials and obj:IsA("BasePart") then
		pcall(function()
			Vgxmod_save(obj, "Material", obj.Material)
			obj.Material = Enum.Material.Plastic
		end)
	end
	if Vgxmod_config.accessories and obj:IsA("Accessory") then
		pcall(function()
			Vgxmod_save(obj, "Parent", obj.Parent)
			obj.Parent = nil
		end)
	end
	if Vgxmod_config.clothing then
		if obj:IsA("Shirt") or obj:IsA("Pants") or obj:IsA("ShirtGraphic") then
			pcall(function()
				Vgxmod_save(obj, "Parent", obj.Parent)
				obj.Parent = nil
			end)
		end
	end
end

local function Vgxmod_optimizeChar(char)
	if not char then return end
	for _, obj in ipairs(char:GetDescendants()) do
		if Vgxmod_config.accessories and obj:IsA("Accessory") then
			pcall(function()
				Vgxmod_save(obj, "Parent", obj.Parent)
				obj.Parent = nil
			end)
		elseif Vgxmod_config.clothing then
			if obj:IsA("Shirt") or obj:IsA("Pants") or obj:IsA("ShirtGraphic") then
				pcall(function()
					Vgxmod_save(obj, "Parent", obj.Parent)
					obj.Parent = nil
				end)
			end
		end
		if Vgxmod_config.textures and obj:IsA("Decal") then
			pcall(function()
				Vgxmod_save(obj, "Transparency", obj.Transparency)
				obj.Transparency = 1
			end)
		end
	end
end

local function Vgxmod_restore()
	for obj, data in pairs(Vgxmod_saved) do
		if obj and typeof(obj) == "Instance" then
			pcall(function()
				if data.Transparency ~= nil then obj.Transparency = data.Transparency end
				if data.Enabled ~= nil then obj.Enabled = data.Enabled end
				if data.CastShadow ~= nil then obj.CastShadow = data.CastShadow end
				if data.Material ~= nil then obj.Material = data.Material end
				if data.Parent ~= nil then obj.Parent = data.Parent end
			end)
		end
	end
	Vgxmod_saved = {}
	for k, v in pairs(Vgxmod_savedLighting) do
		pcall(function()
			Lighting[k] = v
		end)
	end
	Vgxmod_savedLighting = {}
end

local function Vgxmod_setupPlr(plr)
	if plr.Character then
		Vgxmod_optimizeChar(plr.Character)
	end
	plr.CharacterAdded:Connect(function(char)
		task.wait(0.5)
		if Vgxmod_Config.FPSBoostEnabled and plr.Character == char then
			Vgxmod_optimizeChar(char)
		end
	end)
end

local function Vgxmod_start()
	for _, obj in ipairs(Workspace:GetDescendants()) do
		Vgxmod_optimize(obj)
	end
	local conn1 = Workspace.DescendantAdded:Connect(function(obj)
		task.defer(function()
			if Vgxmod_Config.FPSBoostEnabled then
				Vgxmod_optimize(obj)
			end
		end)
	end)
	table.insert(Vgxmod_conns, conn1)
	if Vgxmod_config.sky then
		for _, obj in ipairs(Lighting:GetChildren()) do
			if obj:IsA("Sky") then
				pcall(function()
					Vgxmod_save(obj, "Parent", obj.Parent)
					obj.Parent = nil
				end)
			elseif obj:IsA("Atmosphere") or obj:IsA("BloomEffect") or obj:IsA("BlurEffect") or obj:IsA("ColorCorrectionEffect") or obj:IsA("DepthOfFieldEffect") or obj:IsA("SunRaysEffect") then
				pcall(function()
					Vgxmod_save(obj, "Enabled", obj.Enabled)
					obj.Enabled = false
				end)
			end
		end
		local conn2 = Lighting.ChildAdded:Connect(function(obj)
			if not Vgxmod_Config.FPSBoostEnabled then return end
			if obj:IsA("Sky") then
				pcall(function()
					Vgxmod_save(obj, "Parent", obj.Parent)
					obj.Parent = nil
				end)
			elseif obj:IsA("Atmosphere") or obj:IsA("BloomEffect") or obj:IsA("BlurEffect") or obj:IsA("ColorCorrectionEffect") or obj:IsA("DepthOfFieldEffect") or obj:IsA("SunRaysEffect") then
				pcall(function()
					Vgxmod_save(obj, "Enabled", obj.Enabled)
					obj.Enabled = false
				end)
			end
		end)
		table.insert(Vgxmod_conns, conn2)
	end
	pcall(function()
		if Vgxmod_config.terrain then
			Workspace.Terrain.Decoration = false
		end
	end)
	if Vgxmod_config.shadows then
		pcall(function()
			Vgxmod_savedLighting.GlobalShadows = Lighting.GlobalShadows
			Vgxmod_savedLighting.EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale
			Vgxmod_savedLighting.EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale
			Lighting.GlobalShadows = false
			Lighting.EnvironmentDiffuseScale = 0
			Lighting.EnvironmentSpecularScale = 0
		end)
	end
	for _, plr in ipairs(Players:GetPlayers()) do
		Vgxmod_setupPlr(plr)
	end
	local conn3 = Players.PlayerAdded:Connect(Vgxmod_setupPlr)
	table.insert(Vgxmod_conns, conn3)
end

local function Vgxmod_stop()
	for _, conn in ipairs(Vgxmod_conns) do
		pcall(function()
			conn:Disconnect()
		end)
	end
	Vgxmod_conns = {}
	Vgxmod_restore()
end

local function Vgxmod_toggleFPS(state)
	Vgxmod_Config.FPSBoostEnabled = state
	if state then
		Vgxmod_start()
	else
		Vgxmod_stop()
	end
end

local function Vgxmod_setMode(mode)
	Vgxmod_Config.FPSBoostMode = string.upper(mode)
	Vgxmod_config = Vgxmod_settings[Vgxmod_Config.FPSBoostMode]
	if Vgxmod_Config.FPSBoostEnabled then
		Vgxmod_stop()
		Vgxmod_start()
	end
end

-- AUTO TRACK

local Vgxmod_TrackPlayers = game:GetService("Players")
local Vgxmod_TrackLocalPlayer = Vgxmod_TrackPlayers.LocalPlayer
local Vgxmod_TrackUIS = game:GetService("UserInputService")
local Vgxmod_TrackRS = game:GetService("RunService")

local Vgxmod_TrackMoveKeys = {
	[Enum.KeyCode.W]     = true,
	[Enum.KeyCode.A]     = true,
	[Enum.KeyCode.S]     = true,
	[Enum.KeyCode.D]     = true,
	[Enum.KeyCode.Up]    = true,
	[Enum.KeyCode.Down]  = true,
	[Enum.KeyCode.Left]  = true,
	[Enum.KeyCode.Right] = true,
}

local Vgxmod_TrackKeysDown = {}

Vgxmod_TrackUIS.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if Vgxmod_TrackMoveKeys[input.KeyCode] then
		Vgxmod_TrackKeysDown[input.KeyCode] = true
	end
end)

Vgxmod_TrackUIS.InputEnded:Connect(function(input)
	if Vgxmod_TrackMoveKeys[input.KeyCode] then
		Vgxmod_TrackKeysDown[input.KeyCode] = nil
	end
end)

local function Vgxmod_TrackIsTeammate(player)
	if not Vgxmod_TrackLocalPlayer then return false end

	local myIngame = Vgxmod_TrackLocalPlayer:GetAttribute("Ingame") or false
	local targetIngame = player:GetAttribute("Ingame") or false

	if myIngame and targetIngame then
		local myArena = Vgxmod_TrackLocalPlayer:GetAttribute("Arena") or 0
		local targetArena = player:GetAttribute("Arena") or 0

		local myTeam = Vgxmod_TrackLocalPlayer:GetAttribute("Team") or ""
		local targetTeam = player:GetAttribute("Team") or ""

		if myArena == targetArena and myArena ~= 0 then
			return myTeam == targetTeam
		end
	end

	if Vgxmod_TrackLocalPlayer.Team and player.Team then
		return Vgxmod_TrackLocalPlayer.Team == player.Team
	end

	return false
end

local function Vgxmod_TrackGetBomb()
	if not Vgxmod_TrackLocalPlayer then return nil end
	local character = Vgxmod_TrackLocalPlayer.Character
	if not character then return nil end

	local bomb = character:FindFirstChild("Bomb", true)
	if bomb then return bomb end

	local charactersFolder = workspace:FindFirstChild("Characters")
	if charactersFolder then
		local playerCharacter = charactersFolder:FindFirstChild(Vgxmod_TrackLocalPlayer.Name)
		if playerCharacter then
			bomb = playerCharacter:FindFirstChild("Bomb", true)
			if bomb then return bomb end
		end
	end

	return nil
end

local function Vgxmod_TrackHasBomb()
	return Vgxmod_TrackGetBomb() ~= nil
end

local function Vgxmod_TrackGetBombTime()
	local bomb = Vgxmod_TrackGetBomb()
	if not bomb then return nil end

	local bombHandle = bomb:FindFirstChild("BombHandle", true)
	if not bombHandle then return nil end

	local uiAttachment = bombHandle:FindFirstChild("UIAttachment", true)
	if not uiAttachment then return nil end

	local ui = uiAttachment:FindFirstChild("UI", true)
	if not ui then return nil end

	local timeLeft = ui:FindFirstChild("TimeLeft", true)
	if not timeLeft then return nil end

	local value = timeLeft:IsA("ValueBase") and timeLeft.Value or timeLeft.Text

	if typeof(value) == "number" then
		return value
	end

	if typeof(value) == "string" then
		return tonumber(value:match("[%d%.]+"))
	end

	return nil
end

local function Vgxmod_TrackIsMoving()
	for _, pressed in pairs(Vgxmod_TrackKeysDown) do
		if pressed then return true end
	end

	if not Vgxmod_TrackLocalPlayer then return false end
	local character = Vgxmod_TrackLocalPlayer.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.MoveDirection.Magnitude > 0.05 then
			return true
		end
	end

	return false
end

local function Vgxmod_TrackIsLocked()
	if Vgxmod_TrackUIS.MouseBehavior == Enum.MouseBehavior.LockCenter then
		return true
	end

	if Vgxmod_TrackUIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
		if not Vgxmod_TrackLocalPlayer then return false end
		local mouse = Vgxmod_TrackLocalPlayer:GetMouse()
		if mouse then
			local camera = workspace.CurrentCamera
			if camera then
				local viewport = camera.ViewportSize
				local center = Vector2.new(viewport.X / 2, viewport.Y / 2)
				local mousePosition = Vector2.new(mouse.X, mouse.Y)
				if (mousePosition - center).Magnitude < 5 then
					return true
				end
			end
		end
	end

	return false
end

local function Vgxmod_TrackGetNearestPlayer()
	if not Vgxmod_TrackLocalPlayer then return nil, nil end
	local character = Vgxmod_TrackLocalPlayer.Character
	if not character then return nil, nil end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return nil, nil end

	local nearestPlayer   = nil
	local nearestDistance = math.huge

	for _, player in ipairs(Vgxmod_TrackPlayers:GetPlayers()) do
		if player ~= Vgxmod_TrackLocalPlayer then
			if player:GetAttribute("Alive") == false then
				continue
			end

			if Vgxmod_TrackIsTeammate(player) then
				continue
			end

			local targetCharacter = player.Character
			if targetCharacter then
				local targetRoot     = targetCharacter:FindFirstChild("HumanoidRootPart")
				local targetHumanoid = targetCharacter:FindFirstChildOfClass("Humanoid")

				if targetRoot and targetHumanoid and targetHumanoid.Health > 0 then
					local distance = (rootPart.Position - targetRoot.Position).Magnitude
					if distance < nearestDistance then
						nearestDistance = distance
						nearestPlayer   = player
					end
				end
			end
		end
	end

	return nearestPlayer, nearestDistance
end

Vgxmod_TrackRS.RenderStepped:Connect(function()
	if not Vgxmod_Config.PlayerTrackEnabled or not Vgxmod_TrackLocalPlayer then return end

	if Vgxmod_Config.PlayerTrackMode == "Bomb" and not Vgxmod_TrackHasBomb() then
		local character = Vgxmod_TrackLocalPlayer.Character
		local humanoid  = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.AutoRotate = true
		end
		return
	end

	local character = Vgxmod_TrackLocalPlayer.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart then return end

	if Vgxmod_TrackIsMoving() then
		humanoid.AutoRotate = true
		return
	end

	local targetPlayer, distance = Vgxmod_TrackGetNearestPlayer()
	if not targetPlayer then return end

	local targetCharacter = targetPlayer.Character
	local targetRoot      = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")
	if not targetRoot then return end

	local bombTime      = Vgxmod_TrackGetBombTime()
	local emergencyMode = bombTime ~= nil and bombTime <= Vgxmod_Config.PlayerTrackBombTimer

	local direction = targetRoot.Position - rootPart.Position
	direction = Vector3.new(direction.X, 0, direction.Z)

	if direction.Magnitude < 0.01 then
		humanoid:Move(Vector3.zero, false)
		return
	end

	local unitDirection = direction.Unit

	if emergencyMode then
		if distance > 2.5 then
			humanoid:Move(unitDirection, false)
		else
			humanoid:Move(Vector3.zero, false)
		end
	else
		if distance > Vgxmod_Config.PlayerTrackDistance + 0.25 then
			humanoid:Move(unitDirection, false)
		elseif distance < Vgxmod_Config.PlayerTrackDistance - 0.25 then
			humanoid:Move(-unitDirection, false)
		else
			humanoid:Move(Vector3.zero, false)
		end
	end

	local locked = Vgxmod_TrackIsLocked()
	local angle  = emergencyMode and 45 or 150

	if locked then
		humanoid.AutoRotate = true
		rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + unitDirection)
	else
		humanoid.AutoRotate = false
		local rotatedDirection = CFrame.Angles(0, math.rad(angle), 0):VectorToWorldSpace(unitDirection)
		rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + rotatedDirection)
	end
end)

if Vgxmod_TrackLocalPlayer then
	Vgxmod_TrackLocalPlayer.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		if Vgxmod_Config.PlayerTrackEnabled and (Vgxmod_Config.PlayerTrackMode == "Default" or Vgxmod_TrackHasBomb()) then
			humanoid.AutoRotate = false
		else
			humanoid.AutoRotate = true
		end
	end)
end


-- BOMB TIME ESP

local BombESP_RunService = game:GetService("RunService")
local BombESP_Characters = workspace:WaitForChild("Characters")

local BombESP_Folder = Instance.new("Folder")
BombESP_Folder.Name = "BombTimeESP"
BombESP_Folder.Parent = workspace

local BombESP_Color = Color3.fromRGB(168, 85, 247)

local BombESP_tracked = {}
local BombESP_enabled = false
local BombESP_connections = {}

local function BombESP_removeESP(character)
	local data = BombESP_tracked[character]
	if data then
		if data.billboard then
			data.billboard:Destroy()
		end
		BombESP_tracked[character] = nil
	end
end

local function BombESP_clearAll()
	for character in pairs(BombESP_tracked) do
		BombESP_removeESP(character)
	end
	BombESP_tracked = {}
end

local function BombESP_getColor(num)
	if num <= 2 then
		return Color3.fromRGB(255, 60, 60)
	elseif num <= 4 then
		return Color3.fromRGB(255, 215, 0)
	elseif num <= 6 then
		return Color3.fromRGB(60, 220, 60)
	else
		return BombESP_Color
	end
end

local function BombESP_scanCharacter(character)
	if not BombESP_enabled then return end
	if not character:IsA("Model") then
		return
	end

	local bomb = character:FindFirstChild("Bomb")
	if not bomb then
		BombESP_removeESP(character)
		return
	end

	local handle = bomb:FindFirstChild("BombHandle")
	local attachment = handle and handle:FindFirstChild("UIAttachment")
	local ui = attachment and attachment:FindFirstChild("UI")
	local timeLeft = ui and ui:FindFirstChild("TimeLeft")

	if not timeLeft or not timeLeft:IsA("TextLabel") then
		BombESP_removeESP(character)
		return
	end

	if not BombESP_tracked[character] then
		local root = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
		if not root then
			return
		end

		local bill = Instance.new("BillboardGui")
		bill.Name = "DynamicBombESP"
		bill.AlwaysOnTop = true
		bill.Size = UDim2.new(0, 36, 0, 36)
		bill.Adornee = root
		bill.StudsOffset = Vector3.new(0, 2.5, 0)
		bill.Parent = BombESP_Folder

		local container = Instance.new("Frame", bill)
		container.Size = UDim2.new(1, 0, 1, 0)
		container.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
		container.BackgroundTransparency = 0.35
		container.BorderSizePixel = 0

		local uiCorner = Instance.new("UICorner", container)
		uiCorner.CornerRadius = UDim.new(0, 6)

		local uiStroke = Instance.new("UIStroke", container)
		uiStroke.Name = "BorderStroke"
		uiStroke.Thickness = 1.5
		uiStroke.Color = BombESP_Color

		local label = Instance.new("TextLabel", container)
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.TextColor3 = BombESP_Color
		label.TextSize = 14
		label.TextScaled = false
		label.Font = Enum.Font.GothamBold
		label.TextStrokeTransparency = 0.5
		label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)

		BombESP_tracked[character] = {
			billboard = bill,
			label = label,
			stroke = uiStroke,
			timeLeft = timeLeft
		}
	end

	BombESP_tracked[character].timeLeft = timeLeft
end

local function BombESP_scanAll()
	if not BombESP_enabled then return end

	for _, character in ipairs(BombESP_Characters:GetChildren()) do
		BombESP_scanCharacter(character)
	end

	for character in pairs(BombESP_tracked) do
		if not character.Parent then
			BombESP_removeESP(character)
		end
	end
end

local function BombESP_start()
	if BombESP_enabled then return end
	BombESP_enabled = true

	table.insert(BombESP_connections, BombESP_Characters.ChildAdded:Connect(function(character)
		task.wait()
		BombESP_scanCharacter(character)

		character.ChildAdded:Connect(function()
			task.wait()
			BombESP_scanCharacter(character)
		end)
	end))

	table.insert(BombESP_connections, BombESP_Characters.ChildRemoved:Connect(function(character)
		BombESP_removeESP(character)
	end))

	table.insert(BombESP_connections, BombESP_RunService.Heartbeat:Connect(function()
		BombESP_scanAll()

		for character, data in pairs(BombESP_tracked) do
			local bomb = character:FindFirstChild("Bomb")
			local root = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart

			if not bomb or not root or not data.timeLeft or not data.timeLeft.Parent then
				BombESP_removeESP(character)
			else
				data.billboard.Adornee = root
				data.label.Text = data.timeLeft.Text

				local num = tonumber(data.timeLeft.Text:match("%d+"))
				if num then
					local color = BombESP_getColor(num)
					data.label.TextColor3 = color
					data.stroke.Color = color
				end
			end
		end
	end))

	BombESP_scanAll()
end

local function BombESP_stop()
	if not BombESP_enabled then return end
	BombESP_enabled = false

	for _, conn in ipairs(BombESP_connections) do
		pcall(function() conn:Disconnect() end)
	end
	BombESP_connections = {}

	BombESP_clearAll()
end

function BombESP_toggle(state)
	if state then
		BombESP_start()
	else
		BombESP_stop()
	end
end

-- UI

Library.ForceCheckbox = false 
Library.ShowToggleFrameInKeybinds = true 

local Window = Library:CreateWindow({
	Title = "Vgxmod Hub",
	Font = Font.new("rbxasset://fonts/families/Jura.json"),
	Size = Library.IsMobile and UDim2.fromOffset(450, 480) or UDim2.fromOffset(720, 600),
	Footer = "https://discord.gg/n9gtmefsjc | Made by Ugire0",
	CornerRadius = 15,
	Icon = 107772605758737,
	NotifySide = "Right",
	ShowCustomCursor = false,
})

local Tabs = {
	Main = Window:AddTab("Vgxmod Hub", "house", "Main Features"),
	Visual = Window:AddTab("Vgxmod Hub", "eye", "Visual Features"),
	Server = Window:AddTab("Vgxmod Hub", "hard-drive-download", "Server Features"),
	Protect = Window:AddTab("Vgxmod Hub", "shield", "Protection Features"),
	Readme = Window:AddTab("Vgxmod Hub", "book-open", "Readme Features"),
	["UI Settings"] = Window:AddTab("Vgxmod Hub", "settings", "UI Settings"),
}

local Box1 = Tabs.Main:AddLeftGroupbox("AutoFarm", "play")
local TabBox = Box1:AddTabbox({})
local Tab1 = TabBox:AddTab("", "sword")
local Tab2 = TabBox:AddTab("", "rabbit")
local Tab3 = TabBox:AddTab("", "user")
local Box2 = Tabs.Main:AddRightGroupbox("Assist", "brick-wall")
local Box3 = Tabs.Main:AddLeftGroupbox("LockAim", "crosshair")
local Box4 = Tabs.Main:AddRightGroupbox("AutoTrack", "target")

local VBox1 = Tabs.Visual:AddLeftGroupbox("EspVisual", "eye")
local VBox2 = Tabs.Visual:AddRightGroupbox("Customize", "sparkles")
local VBox3 = Tabs.Visual:AddLeftGroupbox("Optimize", "brush-cleaning")
local VBox4 = Tabs.Visual:AddRightGroupbox("Emote", "brush-cleaning")

local SBox1 = Tabs.Server:AddRightGroupbox("Arena", "land-plot")
local SBox2 = Tabs.Server:AddRightGroupbox("Server", "server")

SBox1:AddButton({
	Text = "Pro Server",
	Func = function()
		local Prompt = workspace:FindFirstChild("ProServerPortal")
		if Prompt then
			Prompt = Prompt:FindFirstChild("PromptPart")
			if Prompt then
				Prompt = Prompt:FindFirstChildOfClass("ProximityPrompt")
			end
		end
		if Prompt then
			pcall(function()
				fireproximityprompt(Prompt)
			end)
		end
	end,
})

SBox2:AddButton({
	Text = "Join FFA",
	Func = function()
		pcall(function()
			game:GetService("ReplicatedStorage").Remotes.Arena.JoinFFA:FireServer(workspace.Arenas.FFA)
		end)
	end,
})


Tab1:AddToggle("PlainToggleHitbox", {
	Text = "Hitbox",
	Default = Vgxmod_Config.HitboxEnabled,	
	Callback = function(Value)
		Vgxmod_Config.HitboxEnabled = Value
		if Value then
			CurrentIndex = 1
			Timer = 0
		end
	end,
})

Tab1:AddSlider("PlainSliderHitboxSize", {
	Text = "Hitbox Size",
	Default = Vgxmod_Config.HitboxMaxSize,
	Min = 5,
	Max = 15,
	Rounding = 0,
	Callback = function(Value)
		Vgxmod_Config.HitboxMaxSize = Value
		HitboxSizes = {}
		local start = 3
		while start <= Value do
			table.insert(HitboxSizes, start)
			start += 2
		end
		if CurrentIndex > #HitboxSizes then
			CurrentIndex = 1
		end
	end,
})

Tab1:AddToggle("PlainToggleSpoofPass", {
	Text = "Spoof Pass Delay",
	Default = false,	
	Callback = function(Value)
		
	end,
})

Tab1:AddSlider("PlainSliderDelayTime", {
	Text = "Delay Time",
	Default = 0.5,
	Min = 0,
	Max = 1,
	Rounding = 1,
	Callback = function(Value) 
	end,
})

Tab1:AddToggle("PlainToggleAutoPass", {
	Text = "Auto Pass (Bomb)",
	Default = false,
	Lock = true,
	ColorText = "red",
	Tooltip = "This Features Risky!",
	DisabledTooltip = "This Features Risky!",
	Callback = function(Value)
		
	end,
})

Tab1:AddDropdown("PlainDropdownPassMode", {
	Values = { "Teleport", "Lag Position", "Teleport Fly" },
	Default = 1,
	Text = "Pass Mode",
	Callback = function(Value) 
	
    end,
})

Tab2:AddToggle("LadderFlickWallHop", {
	Text = "WallHop",
	Default = Vgxmod_Config.WallHopEnabled,
	Callback = function(Value)
		Vgxmod_Config.WallHopEnabled = Value
	end,
})
Tab2:AddDropdown("WallHopMode", {
	Values = { "Double Decker", "Default" },
	Default = 2,
	Text = "WallHop Mode",
	Callback = function(Value)
		Vgxmod_Config.WallHopMode = Value
	end,
})
Tab2:AddDropdown("WallHopAngle", {
	Values = { "45", "90", "150" },
	Default = 2,
	Text = "Flick Angle",
	Callback = function(Value)
		Vgxmod_Config.WallHopAngle = tonumber(Value) or 90
	end,
})

Tab2:AddLabel("text1", {
	Text = "Auto fling only work on arena (Double Decker) use it like a pro how to use simply join my discord watch the video",
	DoesWrap = true,
})

Tab2:AddToggle("AutoFling", {
	Text = "Auto Fling",
	Default = Vgxmod_Config.AutoFlingEnabled,
	Callback = function(Value)
		Vgxmod_toggleFling(Value)
	end,
})
Tab2:AddDropdown("FlingDirection", {
	Values = { "Both", "Left", "Right" },
	Default = 1,
	Text = "Fling Mode",
	Callback = function(Value)
		Vgxmod_updateDir(Value)
	end,
})
Tab2:AddSlider("FlingCooldown", {
	Text = "Fling Cooldown",
	Default = Vgxmod_Config.AutoFlingCooldown,
	Min = 1,
	Max = 10,
	Rounding = 0,
	Callback = function(Value)
		Vgxmod_updateCooldown(Value)
	end,
})

Tab3:AddToggle("TPWalkToggle", {
	Text = "Speed Boost",
	Default = Vgxmod_Config.TPWalkEnabled,
	Callback = function(state)
		Vgxmod_Config.TPWalkEnabled = state
	end
})
Tab3:AddSlider("TPWalkSpeedSlider", {
	Text = "Speed Boost Level",
	Default = 3,
	Min = 1,
	Max = 10,
	Rounding = 0,
	Callback = function(value)
		Vgxmod_Config.TPWalkSpeed = value * 0.01
	end
})
Tab3:AddToggle("JumpBoostToggle", {
	Text = "Jump Boost",
	Default = Vgxmod_Config.JumpBoostEnabled,
	Callback = function(state)
		Vgxmod_Config.JumpBoostEnabled = state
	end
})
Tab3:AddSlider("JumpBoostSlider", {
	Text = "Jump Boost Level",
	Default = 3,
	Min = 1,
	Max = 20,
	Rounding = 0,
	Callback = function(value)
		Vgxmod_Config.JumpBoost = 50 + value
	end
})

Tab3:AddToggle("SmoothRotateToggle", {
	Text = "Snap Rotate",
	Default = Vgxmod_Config.SnapRotateEnabled,
	Callback = function(state)
		Vgxmod_Config.SnapRotateEnabled = state
	end
})
Tab3:AddSlider("SmoothRotateSpeed", {
	Text = "Rotate Speed",
	Default = 5,
	Min = 1,
	Max = 10,
	Rounding = 1,
	Callback = function(value)
		Vgxmod_Config.SnapRotateSpeed = value / 10
	end
})

Box2:AddLabel("text1", {
	Text = "This assist build for map (Double Decker)",
	DoesWrap = true,
})
Box2:AddToggle("BlockAssist1", {
	Text = "Block Assist 1",
	Default = Vgxmod_Config.BlockAssist1Enabled,
	Callback = function(Value)
		Vgxmod_Config.BlockAssist1Enabled = Value
		Vgxmod_apply1(Value)
	end,
})
Box2:AddToggle("BlockAssist2", {
	Text = "Block Assist 2",
	Default = Vgxmod_Config.BlockAssist2Enabled,
	Callback = function(Value)
		Vgxmod_Config.BlockAssist2Enabled = Value
		Vgxmod_apply2(Value)
	end,
})
Box2:AddToggle("BlockAssist3", {
	Text = "Block Assist 3",
	Default = Vgxmod_Config.BlockAssist3Enabled,
	Callback = function(Value)
		Vgxmod_Config.BlockAssist3Enabled = Value
		Vgxmod_apply3(Value)
	end,
})
Box2:AddLabel("text2", {
	Text = "This assist build for map (Suspend)",
	DoesWrap = true,
})
Box2:AddToggle("BlockAssistArena5", {
	Text = "Block Assist 1",
	Default = Vgxmod_Config.BlockAssistArena5Enabled,
	Callback = function(Value)
		Vgxmod_Config.BlockAssistArena5Enabled = Value
		Vgxmod_apply5(Value)
	end,
})

VBox1:AddToggle("TeamCheckESPToggle", {
	Text = "ESP Player",
	Default = Vgxmod_Config.ESPEnabled,
	Callback = function(Value)
		Vgxmod_Config.ESPEnabled = Value
		Vgxmod_updateAll()
	end,
})

VBox1:AddCheckbox("TeamCheckToggle", {
	Text = "Team Check",
	Default = Vgxmod_Config.TeamCheckEnabled,
	Lock = true,
	Callback = function(Value)
		Vgxmod_Config.TeamCheckEnabled = Value
		
		if Value then
			pcall(Vgxmod_update)
		else
			for _, plr in ipairs(Players:GetPlayers()) do
				Vgxmod_reset(plr)
			end
		end
	end,
})

VBox1:AddToggle("BombTimeESPToggle", {
    Text = "Bomb Time ESP",
    Default = Vgxmod_Config.BombTimeESPEnabled,
    Callback = function(Value)
        Vgxmod_Config.BombTimeESPEnabled = Value
        BombESP_toggle(Value)
    end,
})

Box3:AddToggle("AutoLockToggle", {
	Text = "Auto Lock",
	Default = Vgxmod_Config.AutoLockEnabled,
	Callback = function(Value)
		Vgxmod_Config.AutoLockEnabled = Value
	end,
})
Box3:AddDropdown("LockModeDropdown", {
	Values = { "Default", "Bomb" },
	Default = 1,
	Text = "Lock Mode",
	Callback = function(Value)
		Vgxmod_Config.AutoLockMode = Value
	end,
})
Box3:AddSlider("LockDistanceSlider", {
	Text = "Lock Distance",
	Default = Vgxmod_Config.AutoLockDistance,
	Min = 5,
	Max = 100,
	Rounding = 0,
	Callback = function(Value)
		Vgxmod_Config.AutoLockDistance = Value
	end,
})

Box4:AddLabel("plugin1", {
	Text = "This button has already plugin inside",
	DoesWrap = true,
})

Box4:AddToggle("ShowTrackButton", {
    Text = "Show track button",
    Default = Vgxmod_Config.ShowTrackButton,
    Callback = function(Value)
        setPlayerTrack(Value)
    end,
})
Box4:AddCheckbox("LockTrackButtonPosition", {
    Text = "Lock button position",
    Default = Vgxmod_Config.LockTrackButtonPosition,
    Callback = function(Value)
        setTrackButtonLocked(Value)
    end,
})

Box4:AddLabel("plugin2", {
	Text = "Auto track set your own settings combined it with your skill",
	DoesWrap = true,
})

Box4:AddToggle("PlayerTrackToggle", {
    Text = "Tracking",
    Default = Vgxmod_Config.PlayerTrackEnabled,
    Callback = function(Value)
        Vgxmod_Config.PlayerTrackEnabled = Value
        local character = LocalPlayer.Character
        local humanoid  = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.AutoRotate = not Value
        end
    end,
})
Box4:AddDropdown("ModeDropdown", {
    Values = { "Default", "Bomb" },
    Default = 1,
    Text = "Mode Select",
    Callback = function(Value)
        Vgxmod_Config.PlayerTrackMode = Value
    end,
})
Box4:AddSlider("BombTimerSlider", {
    Text = "Unhold Bomb Timer",
    Default = Vgxmod_Config.PlayerTrackBombTimer,
    Min = 0, Max = 10, Rounding = 1,
    Callback = function(Value)
        Vgxmod_Config.PlayerTrackBombTimer = Value
    end,
})
Box4:AddSlider("DistanceSlider", {
    Text = "Target Distance",
    Default = Vgxmod_Config.PlayerTrackDistance,
    Min = 1, Max = 30, Rounding = 1,
    Callback = function(Value)
        Vgxmod_Config.PlayerTrackDistance = Value
    end,
})

VBox2:AddToggle("HeadlessToggle", {
	Text = "Headless",
	Default = Vgxmod_Config.HeadlessEnabled,
	Callback = function(Value)
		Vgxmod_Config.HeadlessEnabled = Value
		if LocalPlayer.Character then
			Vgxmod_applyHead(LocalPlayer.Character, Value)
		end
	end,
})
VBox2:AddToggle("KorbloxToggle", {
	Text = "Korblox Right Leg",
	Default = Vgxmod_Config.KorbloxEnabled,
	Callback = function(Value)
		Vgxmod_Config.KorbloxEnabled = Value
		if LocalPlayer.Character then
			Vgxmod_applyKorblox(LocalPlayer.Character, Value)
		end
	end,
})

VBox2:AddToggle("ESPToggle", {
	Text = "Trail",
	Default = Vgxmod_Config.TrailEnabled,
	Callback = function(Value)
		Vgxmod_Config.TrailEnabled = Value
		Vgxmod_updateTrail()
	end,
})
	:AddColorPicker("ESPColor", {
		Default = Vgxmod_Config.TrailColor,
		Title = "Trail Color",
		Transparency = 0,
		Callback = function(Value)
			Vgxmod_updateColor(Value)
		end,
	})

VBox2:AddToggle("FireToggle", {
	Text = "Head Fire",
	Default = Vgxmod_Config.HeadFireEnabled,
	Callback = function(Value)
		Vgxmod_toggleFire(Value)
	end,
})

VBox3:AddToggle("FPSBoostToggle", {
	Text = "FPS Booster",
	Default = Vgxmod_Config.FPSBoostEnabled,
	Callback = function(Value)
		Vgxmod_toggleFPS(Value)
	end,
})
VBox3:AddDropdown("FPSModeDropdown", {
	Values = { "LOW", "MEDIUM", "ULTRA" },
	Default = 2,
	Text = "FPS Mode",
	Callback = function(Value)
		Vgxmod_setMode(Value)
	end,
})

VBox4:AddButton({
	Text = "Laugh Emote",
	Func = function()
		local TextChatService = game:GetService("TextChatService")
		local Vgx = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
		if Vgx then
			pcall(function()
				Vgx:SendAsync("/e laugh")
			end)
		end
	end,
})

VBox4:AddButton({
	Text = "Celebrate",
	Func = function()
		local TextChatService = game:GetService("TextChatService")
		local Vgx = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
		if Vgx then
			pcall(function()
				Vgx:SendAsync("/e dance1")
			end)
		end
	end,
})

VBox4:AddButton({
	Text = "Swirl",
	Func = function()
		local TextChatService = game:GetService("TextChatService")
		local Vgx = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
		if Vgx then
			pcall(function()
				Vgx:SendAsync("/e dance2")
			end)
		end
	end,
})

VBox4:AddButton({
	Text = "Happy",
	Func = function()
		local TextChatService = game:GetService("TextChatService")
		local Vgx = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
		if Vgx then
			pcall(function()
				Vgx:SendAsync("/e dance3")
			end)
		end
	end,
})

-- PROTECTION

local PBox1 = Tabs.Protect:AddLeftGroupbox("Bypass", "shield-check")

PBox1:AddToggle("Bypass", {
	Text = "Bypass Anti Cheat",
	Default = true,
	Lock = true,	
	Tooltip = "Bypass Anti Gay!",
	DisabledTooltip = "Bypass Anti Gay!",
	Callback = function(Value)		
	end,
})

PBox1:AddToggle("Bypass2", {
	Text = "Anti Webhook",
	Default = true,
	Lock = true,	
	Tooltip = "Bypass Anti Gay!",
	DisabledTooltip = "Bypass Anti Gay!",
	Callback = function(Value)		
	end,
})

local PBox2 = Tabs.Protect:AddRightGroupbox("BypassInfo", "shield-alert")

PBox2:AddLabel("text1", {
	Text = "This bypass is not 100% accurate. Please use it at your own risk, but I've been using it for months now and I haven't gotten banned.",
	DoesWrap = true,
})

PBox2:AddLabel("text2", {
	Text = "Avoid being record or exploit report from discord",
	DoesWrap = true,
})


-- README

local ReadmeBox3 = Tabs.Readme:AddLeftGroupbox("Join Now", "link-2")
ReadmeBox3:AddLabel("text1", {
	Text = "Click the button to copy discord link",
	DoesWrap = true,
})
ReadmeBox3:AddButton({
	Text = "Copy Discord Invite",
	Tooltip = "Copy the Discord invite to your clipboard",
	Func = function()
		if setclipboard then
			setclipboard("https://discord.gg/n9gtmefsjc")
		elseif toclipboard then
			toclipboard("https://discord.gg/n9gtmefsjc")
		end
	end,
})

local ReadmeBox1 = Tabs.Readme:AddLeftGroupbox("Reminder", "file-exclamation-point")
local ReadmeBox2 = Tabs.Readme:AddRightGroupbox("For Sell", "badge-dollar-sign")

ReadmeBox1:AddLabel("text1", {
	Text = "This script is made for fun, so please enjoy it!\n\nPlease keep in mind that I'm a solo developer, so I may not be able to update the script regularly because I'm often busy. Thank you for your patience and support!",
	DoesWrap = true,
})

ReadmeBox1:AddDivider()

ReadmeBox1:AddLabel("text3", {
	Text = "You can suggest new features or improvements for this script.\n\nYou can also request a script for a game, as long as there isn't already a script available for that game.\n\nPlease make sure the game has at least 5,000+ active players.",
	DoesWrap = true,
})

ReadmeBox2:AddLabel("text2", {
	Text = "If you hate ads, simply create a ticket and purchase a Premium Key.\n\nI also sell the Open Source version.\n• High-quality and clean code\n• Beautified for better readability\n• Easy to rewrite and rebrand\n• Regularly updated",
	DoesWrap = true,
})

ReadmeBox2:AddDivider()

ReadmeBox2:AddLabel("text4", {
	Text = "I also create custom UI libraries. Simply open a ticket, send your offer, and tell me whether you want an existing UI recreated or a completely custom design.\n\nPlease don't expect an exact replica copy I can only make a similar design.\n\nCurrent support includes up to 10 UI elements, and I can also create custom notification designs.",
	DoesWrap = true,
})


-- UI SETTINGS

local MenuGroup = Tabs["UI Settings"]:AddLeftGroupbox("Menu", "wrench")

MenuGroup:AddToggle("KeybindMenuOpen", {
	Default = Library.KeybindFrame.Visible,
	Text = "Open Keybind Menu",
	Callback = function(value)
		Library.KeybindFrame.Visible = value
	end,
})
MenuGroup:AddToggle("ShowCustomCursor", {
	Text = "Custom Cursor",
	Default = true,
	Callback = function(Value)
		Library.ShowCustomCursor = Value
	end,
})
MenuGroup:AddDropdown("NotificationSide", {
	Values = { "Left", "Right" },
	Default = "Right",
	Text = "Notification Side",
	Callback = function(Value)
		Library:SetNotifySide(Value)
	end,
})
MenuGroup:AddDropdown("DPIDropdown", {
	Values = { "50%", "75%", "100%", "125%", "150%", "175%", "200%" },
	Default = "100%",
	Text = "DPI Scale",
	Callback = function(Value)
		Value = Value:gsub("%%", "")
		local DPI = tonumber(Value)
		Library:SetDPIScale(DPI)
	end,
})

MenuGroup:AddSlider("UICornerSlider", {
	Text = "Corner Radius",
	Default = Library.CornerRadius,
	Min = 0,
	Max = 20,
	Rounding = 0,
	Callback = function(value)
		Window:SetCornerRadius(value)
	end
})

MenuGroup:AddDivider()
MenuGroup:AddLabel("Menu bind")
	:AddKeyPicker("MenuKeybind", { Default = "RightShift", NoUI = true, Text = "Menu keybind" })

MenuGroup:AddButton("Unload", function()
	Library:Unload()
end)

Library.ToggleKeybind = Options.MenuKeybind 
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
ThemeManager:SetFolder("MyScriptHub")
SaveManager:SetFolder("MyScriptHub/specific-game")
SaveManager:SetSubFolder("specific-place") 
SaveManager:BuildConfigSection(Tabs["UI Settings"])
ThemeManager:ApplyToTab(Tabs["UI Settings"])
SaveManager:LoadAutoloadConfig()
