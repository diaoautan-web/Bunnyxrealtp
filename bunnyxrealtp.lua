--[[
	BUNNYXTP (12 LOCKED DOTS • BRISK CARPET TP • CARRY SPEED 25 • INF JUMP • NO DIE)
	- Brisk carpet flight: 82 studs/s on DOTS 1-5, 114 studs/s on DOTS 6-12 (after DOT 5)
	- 5.3-stud arrival check, 0.82s dot cap, and 9-stud micro-steps above 31 studs
	- Carry Speed 25 toggle keeps carry movement speed at 25 studs/s
	- Infinite Jump Bypass toggle + No Die guard + 3D "OWNER" head tag + 12 locked dots
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
if not player then
	Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
	player = Players.LocalPlayer
end

local playerGui = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 15)
if not playerGui then
	return
end

pcall(function()
	for _, name in ipairs({ "BunnyxTP_UI", "SkitzoTP_UI" }) do
		local old = playerGui:FindFirstChild(name)
		if old then old:Destroy() end
	end
end)

pcall(function()
	for _, name in ipairs({ "BunnyxTP_Checkpoints", "SkitzoTP_Checkpoints" }) do
		local oldFolder = Workspace:FindFirstChild(name)
		if oldFolder then oldFolder:Destroy() end
	end
end)

local PAL = {
	BgDark = Color3.fromRGB(10, 14, 22),
	BtnDark = Color3.fromRGB(14, 20, 32),
	BoxDark = Color3.fromRGB(12, 18, 28),
	HeaderDark = Color3.fromRGB(16, 26, 44),
	TextBlue = Color3.fromRGB(90, 215, 255),
	BrightBlue = Color3.fromRGB(145, 238, 255),
	BorderBlue = Color3.fromRGB(45, 165, 255),
	ActiveBlue = Color3.fromRGB(22, 65, 115),
}

local DOT_COUNT = 12
local FAST_AFTER_DOT = 5
local CARRY_SPEED_VALUE = 25

local LANE_OFFSETS = {
	Vector3.new(0, 0, 0),     -- DOT 1  (middle of your base)
	Vector3.new(0, 0, -8),    -- DOT 2
	Vector3.new(0, 0, -16),   -- DOT 3
	Vector3.new(0, 0, -24),   -- DOT 4
	Vector3.new(0, 0, -32),   -- DOT 5  (faster flight starts AFTER this dot)
	Vector3.new(0, 0, -40),   -- DOT 6
	Vector3.new(0, 0, -48),   -- DOT 7
	Vector3.new(0, 0, -56),   -- DOT 8
	Vector3.new(0, 0, -64),   -- DOT 9
	Vector3.new(0, 0, -72),   -- DOT 10 (reaches Base 3; turns right after this)
	Vector3.new(16, 0, -72),  -- DOT 11 (turns right +16)
	Vector3.new(32, 0, -72),  -- DOT 12 (turns right +32 and stops)
}

local envStore = (type(getgenv) == "function" and getgenv()) or _G
if type(envStore.BunnyxTP_LockedDots12R) ~= "table" then
	envStore.BunnyxTP_LockedDots12R = {}
end

local checkpoints = table.create(DOT_COUNT, nil)
local checkpointMarkers = table.create(DOT_COUNT, nil)
local selectedDot = 1
local nextOrderIndex = 1
local autoLoopToken = 0

local state = {
	OwnerHeadTag = true,
	AutoSwitch = false,
	NormalFlySpeed = 82,
	FastFlySpeed = 114,
	CarrySpeed = true,
	InfiniteJump = true,
	ArriveRadius = 5.3,
	DotTimeout = 0.82,
	MicroStepAssist = true,
	UseCarpet = true,
	AntiDie = true,
	PlayerESP = false,
	PlayerTags = false,
	BrainrotESP = false,
}

local espVisuals = {}
local isTeleporting = false
local statusLabel = nil
local dotButtonRefs = {}
local toggleSyncs = {}
local antiDieConn = nil
local healthConn = nil
local carryLoopConn = nil
local jumpReqConn = nil
local ownerTagGui = nil

local markerFolder = Instance.new("Folder")
markerFolder.Name = "BunnyxTP_Checkpoints"
pcall(function()
	markerFolder.Parent = Workspace
end)

local function setStatus(msg)
	if statusLabel and statusLabel.Parent then
		statusLabel.Text = tostring(msg)
	end
end

local function getChar()
	return player.Character
end

local function getHRP()
	local char = getChar()
	if not char then return nil end
	return char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart", 3)
end

local function getHumanoid()
	local char = getChar()
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function clearOwnerHeadTag()
	if ownerTagGui then
		pcall(function() ownerTagGui:Destroy() end)
		ownerTagGui = nil
	end
end

local function applyOwnerHeadTag(char)
	clearOwnerHeadTag()
	if not (state.OwnerHeadTag and char) then
		return
	end

	task.spawn(function()
		local head = char:FindFirstChild("Head") or char:WaitForChild("Head", 6)
		local hrp = char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart", 6)
		local adornee = head or hrp
		if not (adornee and state.OwnerHeadTag and char.Parent) then
			return
		end

		pcall(function()
			local bb = Instance.new("BillboardGui")
			bb.Name = "BunnyxTP_OwnerTag"
			bb.Adornee = adornee
			bb.Size = UDim2.new(0, 128, 0, 32)
			bb.StudsOffset = Vector3.new(0, 2.7, 0)
			bb.AlwaysOnTop = true
			bb.Parent = adornee

			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.new(1, 0, 1, 0)
			lbl.BackgroundColor3 = PAL.BgDark
			lbl.BackgroundTransparency = 0.18
			lbl.Text = "OWNER"
			lbl.TextColor3 = PAL.BrightBlue
			lbl.Font = Enum.Font.GothamBlack
			lbl.TextSize = 14
			lbl.Parent = bb
			Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 7)

			local stroke = Instance.new("UIStroke", lbl)
			stroke.Color = PAL.BorderBlue
			stroke.Thickness = 1.6

			ownerTagGui = bb
		end)
	end)
end

local function isFastStage(dotIndex)
	return dotIndex > FAST_AFTER_DOT
end

local function syncToggleBadges(key, on)
	local entries = toggleSyncs[key]
	if not entries then return end
	for _, sync in ipairs(entries) do
		if sync.badge and sync.badge.Parent then
			sync.badge.Text = on and "ON" or "OFF"
			sync.badge.BackgroundColor3 = on and PAL.ActiveBlue or PAL.BgDark
		end
	end
end

local function setToggleState(key, on, runCallback)
	state[key] = on
	syncToggleBadges(key, on)
	if runCallback then
		local entries = toggleSyncs[key]
		if entries then
			for _, sync in ipairs(entries) do
				if sync.cb then
					sync.cb(on)
					break
				end
			end
		end
	end
end

local function protectHumanoid(hum)
	if not (state.AntiDie and hum and hum.Parent) then
		return
	end
	pcall(function()
		hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
		hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
		if hum.MaxHealth <= 0 or hum.MaxHealth < 100 then
			hum.MaxHealth = 100
		end
		if hum.Health < hum.MaxHealth then
			hum.Health = hum.MaxHealth
		end
	end)
end

local function applyNoDieToChar(char)
	if antiDieConn then
		pcall(function() antiDieConn:Disconnect() end)
		antiDieConn = nil
	end
	if healthConn then
		pcall(function() healthConn:Disconnect() end)
		healthConn = nil
	end
	if not (state.AntiDie and char) then
		return
	end

	local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 6)
	if not hum then
		return
	end

	protectHumanoid(hum)

	healthConn = hum.HealthChanged:Connect(function(newHealth)
		if state.AntiDie and hum.Parent and newHealth < hum.MaxHealth then
			protectHumanoid(hum)
		end
	end)

	antiDieConn = RunService.Heartbeat:Connect(function()
		if not state.AntiDie or not char.Parent or not hum.Parent then
			return
		end
		protectHumanoid(hum)
	end)
end

local function startCarrySpeedLoop()
	if carryLoopConn then
		pcall(function() carryLoopConn:Disconnect() end)
		carryLoopConn = nil
	end

	carryLoopConn = RunService.Heartbeat:Connect(function()
		if not state.CarrySpeed or isTeleporting or state.AutoSwitch then
			return
		end
		local char = getChar()
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not (char and hum and hrp) then
			return
		end

		pcall(function()
			if hum.WalkSpeed < CARRY_SPEED_VALUE then
				hum.WalkSpeed = CARRY_SPEED_VALUE
			end
			local moveDir = hum.MoveDirection
			if moveDir.Magnitude > 0.05 then
				local flatDir = Vector3.new(moveDir.X, 0, moveDir.Z)
				if flatDir.Magnitude > 0.01 then
					local targetVel = flatDir.Unit * CARRY_SPEED_VALUE
					local curVel = hrp.AssemblyLinearVelocity
					if Vector3.new(curVel.X, 0, curVel.Z).Magnitude < CARRY_SPEED_VALUE - 1 then
						hrp.AssemblyLinearVelocity = Vector3.new(targetVel.X, curVel.Y, targetVel.Z)
					end
				end
			end
		end)
	end)
end

local function startInfiniteJumpBypass()
	if jumpReqConn then
		pcall(function() jumpReqConn:Disconnect() end)
		jumpReqConn = nil
	end

	jumpReqConn = UserInputService.JumpRequest:Connect(function()
		if not state.InfiniteJump then
			return
		end
		local char = getChar()
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not (char and hum and hrp) then
			return
		end

		pcall(function()
			hum:ChangeState(Enum.HumanoidStateType.Jumping)
			local curVel = hrp.AssemblyLinearVelocity
			hrp.AssemblyLinearVelocity = Vector3.new(curVel.X, math.max(curVel.Y, 50), curVel.Z)
		end)
	end)
end

local function equipAndUseCarpet()
	local char = getChar()
	local hum = getHumanoid()
	local bp = player:FindFirstChildOfClass("Backpack")
	if not (char and hum) then
		return nil
	end

	for _, tool in ipairs(char:GetChildren()) do
		if tool:IsA("Tool") and tool.Name:lower():find("carpet") then
			pcall(function() tool:Activate() end)
			return tool
		end
	end

	if state.UseCarpet and bp then
		for _, tool in ipairs(bp:GetChildren()) do
			if tool:IsA("Tool") and tool.Name:lower():find("carpet") then
				pcall(function()
					hum:EquipTool(tool)
					tool:Activate()
				end)
				return tool
			end
		end
	end
	return nil
end

local function updateDotVisual(index)
	if checkpointMarkers[index] then
		pcall(function() checkpointMarkers[index]:Destroy() end)
		checkpointMarkers[index] = nil
	end

	local cf = checkpoints[index]
	if not cf then
		return
	end

	pcall(function()
		local part = Instance.new("Part")
		part.Name = "BunnyxTP_CP_" .. tostring(index)
		part.Size = Vector3.new(3.4, 0.4, 3.4)
		part.Shape = Enum.PartType.Cylinder
		part.CFrame = cf * CFrame.new(0, -2.8, 0) * CFrame.Angles(0, 0, math.rad(90))
		part.Anchored = true
		part.CanCollide = false
		part.Material = Enum.Material.Neon
		part.Color = PAL.BorderBlue
		part.Transparency = 0.25
		part.Parent = markerFolder

		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.new(0, 120, 0, 30)
		bb.StudsOffset = Vector3.new(0, 2.5, 0)
		bb.AlwaysOnTop = true
		bb.Parent = part

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, 0, 1, 0)
		lbl.BackgroundColor3 = PAL.BgDark
		lbl.BackgroundTransparency = 0.2
		lbl.Text = "DOT " .. tostring(index)
		lbl.TextColor3 = PAL.BrightBlue
		lbl.Font = Enum.Font.GothamBlack
		lbl.TextSize = 13
		lbl.Parent = bb
		Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 6)
		local stroke = Instance.new("UIStroke", lbl)
		stroke.Color = PAL.BorderBlue
		stroke.Thickness = 1.5

		checkpointMarkers[index] = part
	end)
end

local function refreshDotButtons()
	for i = 1, DOT_COUNT do
		local info = dotButtonRefs[i]
		if info and info.btn and info.btn.Parent then
			local hasPos = checkpoints[i] ~= nil
			info.btn.Text = tostring(i) .. (hasPos and "*" or "")
			info.btn.BackgroundColor3 = (selectedDot == i) and PAL.ActiveBlue or PAL.BtnDark
			info.stroke.Thickness = (selectedDot == i) and 2 or 1.2
		end
	end
end

local function saveDotAtCurrentSpot(index)
	local hrp = getHRP()
	if not hrp then
		return false
	end
	checkpoints[index] = hrp.CFrame
	envStore.BunnyxTP_LockedDots12R[index] = hrp.CFrame
	updateDotVisual(index)
	refreshDotButtons()
	return true
end

local function hasAllLockedDots()
	for i = 1, DOT_COUNT do
		if typeof(envStore.BunnyxTP_LockedDots12R[i]) ~= "CFrame" then
			return false
		end
	end
	return true
end

local function ensureLockedDots(forceReanchorHere)
	if forceReanchorHere or not hasAllLockedDots() then
		local hrp = getHRP()
		if not hrp then
			setStatus("WAITING FOR CHARACTER...")
			return
		end
		local baseCF = hrp.CFrame
		local rotOnly = baseCF - baseCF.Position
		for i = 1, DOT_COUNT do
			if forceReanchorHere or typeof(envStore.BunnyxTP_LockedDots12R[i]) ~= "CFrame" then
				local offset = LANE_OFFSETS[i] or Vector3.new(0, 0, -8 * (i - 1))
				envStore.BunnyxTP_LockedDots12R[i] = CFrame.new(baseCF.Position + offset) * rotOnly
			end
		end
	end

	for i = 1, DOT_COUNT do
		checkpoints[i] = envStore.BunnyxTP_LockedDots12R[i]
		updateDotVisual(i)
	end

	refreshDotButtons()
	setStatus("BUNNYXTP • BRISK CARPET READY")
end

local function getNextOrderedDot()
	for idx = nextOrderIndex, DOT_COUNT do
		if checkpoints[idx] then
			return idx, checkpoints[idx]
		end
	end
	return nil, nil
end

local function flyCarpetToTarget(targetCF, fastMode, stopOnCancelFn)
	local char = getChar()
	local hrp = getHRP()
	local hum = getHumanoid()
	if not (char and hrp and hum and targetCF) then
		return false
	end

	protectHumanoid(hum)
	equipAndUseCarpet()

	local goalPos = targetCF.Position
	local flySpeed = fastMode and state.FastFlySpeed or state.NormalFlySpeed
	local oldWalkSpeed = hum.WalkSpeed
	local startTime = os.clock()
	local lastReactivate = 0

	local att, lv = nil, nil
	pcall(function()
		att = Instance.new("Attachment")
		att.Name = "BunnyxTP_CarpetAtt"
		att.Parent = hrp

		lv = Instance.new("LinearVelocity")
		lv.Name = "BunnyxTP_CarpetVel"
		lv.Attachment0 = att
		lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
		lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
		lv.MaxAxesForce = Vector3.new(2.2e5, 4.5e4, 2.2e5)
		lv.RelativeTo = Enum.ActuatorRelativeTo.World
		lv.Parent = hrp
	end)

	local arrived = false
	while (os.clock() - startTime) < state.DotTimeout do
		if stopOnCancelFn and stopOnCancelFn() then
			break
		end

		char = getChar()
		hrp = getHRP()
		hum = getHumanoid()
		if not (char and hrp and hum and hrp.Parent and hum.Parent) then
			break
		end

		protectHumanoid(hum)
		pcall(function()
			if hum.Sit then
				hum.Sit = false
			end
			hum.WalkSpeed = math.max(oldWalkSpeed, flySpeed)
		end)

		if (os.clock() - lastReactivate) >= 0.24 then
			equipAndUseCarpet()
			lastReactivate = os.clock()
		end

		local curPos = hrp.Position
		local flatDelta = Vector3.new(goalPos.X - curPos.X, 0, goalPos.Z - curPos.Z)
		local flatDist = flatDelta.Magnitude

		if flatDist <= state.ArriveRadius then
			arrived = true
			break
		end

		local dir = flatDelta.Unit
		local desiredY = math.clamp((goalPos.Y + 1.2 - curPos.Y) * 6, -15, 18)

		pcall(function()
			if lv and lv.Parent then
				lv.VectorVelocity = Vector3.new(dir.X * flySpeed, desiredY, dir.Z * flySpeed)
			end
			if state.MicroStepAssist and flatDist > 31 then
				local stepVec = dir * 9
				local nextPos = Vector3.new(
					curPos.X + stepVec.X,
					curPos.Y + math.clamp(goalPos.Y - curPos.Y, -2.2, 2.2),
					curPos.Z + stepVec.Z
				)
				hrp.CFrame = CFrame.lookAt(nextPos, Vector3.new(goalPos.X, nextPos.Y, goalPos.Z))
			end
			hum:MoveTo(Vector3.new(goalPos.X, curPos.Y, goalPos.Z))
		end)

		RunService.Heartbeat:Wait()
	end

	pcall(function() if lv then lv:Destroy() end end)
	pcall(function() if att then att:Destroy() end end)
	pcall(function()
		if hrp and hrp.Parent then
			hrp.AssemblyLinearVelocity = Vector3.zero
			hrp.AssemblyAngularVelocity = Vector3.zero
		end
		if hum and hum.Parent then
			hum.WalkSpeed = state.CarrySpeed and CARRY_SPEED_VALUE or oldWalkSpeed
		end
	end)

	return arrived
end

local function clearESP()
	for _, v in ipairs(espVisuals) do
		pcall(function() v:Destroy() end)
	end
	table.clear(espVisuals)
end

local function refreshESP()
	clearESP()
	local myHRP = getHRP()

	if state.PlayerESP or state.PlayerTags then
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= player and plr.Character then
				local pHRP = plr.Character:FindFirstChild("HumanoidRootPart")
				if state.PlayerESP then
					pcall(function()
						local hl = Instance.new("Highlight")
						hl.Adornee = plr.Character
						hl.FillColor = PAL.BorderBlue
						hl.OutlineColor = PAL.BrightBlue
						hl.FillTransparency = 0.65
						hl.OutlineTransparency = 0
						hl.Parent = plr.Character
						table.insert(espVisuals, hl)
					end)
				end
				if state.PlayerTags and pHRP then
					pcall(function()
						local dist = myHRP and math.floor((pHRP.Position - myHRP.Position).Magnitude) or 0
						local bb = Instance.new("BillboardGui")
						bb.Adornee = pHRP
						bb.Size = UDim2.new(0, 150, 0, 30)
						bb.StudsOffset = Vector3.new(0, 3.2, 0)
						bb.AlwaysOnTop = true
						bb.Parent = pHRP
						table.insert(espVisuals, bb)

						local tl = Instance.new("TextLabel")
						tl.Size = UDim2.new(1, 0, 1, 0)
						tl.BackgroundColor3 = PAL.BgDark
						tl.BackgroundTransparency = 0.25
						tl.Text = plr.Name .. " [" .. tostring(dist) .. "m]"
						tl.TextColor3 = PAL.BrightBlue
						tl.Font = Enum.Font.GothamBlack
						tl.TextSize = 11
						tl.Parent = bb
						Instance.new("UICorner", tl).CornerRadius = UDim.new(0, 6)
					end)
				end
			end
		end
	end

	if state.BrainrotESP then
		local checked = 0
		for _, obj in ipairs(Workspace:GetDescendants()) do
			checked += 1
			if checked > 2500 then
				break
			end
			if (obj:IsA("Model") or obj:IsA("BasePart")) and not obj:FindFirstChildOfClass("Humanoid") then
				if not (player.Character and obj:IsDescendantOf(player.Character)) then
					local n = obj.Name:lower()
					if n:find("brainrot") or n:find("secret") or n:find("50m") or n:find("100m") or n:find("dragon") then
						pcall(function()
							local hl = Instance.new("Highlight")
							hl.Adornee = obj
							hl.FillColor = PAL.BrightBlue
							hl.OutlineColor = PAL.BorderBlue
							hl.FillTransparency = 0.5
							hl.OutlineTransparency = 0
							hl.Parent = obj
							table.insert(espVisuals, hl)
						end)
					end
				end
			end
		end
	end
end

-- =========================================================================
-- BUNNYXTP GUI
-- =========================================================================
local sg = Instance.new("ScreenGui")
sg.Name = "BunnyxTP_UI"
sg.ResetOnSpawn = false
sg.IgnoreGuiInset = true
sg.DisplayOrder = 999999
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function()
	sg.Parent = playerGui
end)

local togglePill = Instance.new("TextButton")
togglePill.Size = UDim2.new(0, 134, 0, 38)
togglePill.Position = UDim2.new(0, 16, 0, 72)
togglePill.BackgroundColor3 = PAL.BgDark
togglePill.Text = "bunnyxTP"
togglePill.TextColor3 = PAL.BrightBlue
togglePill.Font = Enum.Font.GothamBlack
togglePill.TextSize = 13
togglePill.Active = true
togglePill.Draggable = true
togglePill.Parent = sg
Instance.new("UICorner", togglePill).CornerRadius = UDim.new(0, 10)
local pillStroke = Instance.new("UIStroke", togglePill)
pillStroke.Color = PAL.BorderBlue
pillStroke.Thickness = 2

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 356, 0, 465)
main.Position = UDim2.new(0.5, -178, 0.5, -232)
main.BackgroundColor3 = PAL.BgDark
main.Active = true
main.Draggable = true
main.Visible = true
main.Parent = sg
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)
local mainStroke = Instance.new("UIStroke", main)
mainStroke.Color = PAL.BorderBlue
mainStroke.Thickness = 2

togglePill.MouseButton1Click:Connect(function()
	main.Visible = not main.Visible
end)

local header = Instance.new("Frame")
header.Size = UDim2.new(1, -20, 0, 38)
header.Position = UDim2.new(0, 10, 0, 10)
header.BackgroundColor3 = PAL.HeaderDark
header.Parent = main
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 8)
local hStroke = Instance.new("UIStroke", header)
hStroke.Color = PAL.BorderBlue
hStroke.Thickness = 1.5

local titleLbl = Instance.new("TextLabel")
titleLbl.Size = UDim2.new(1, -44, 1, 0)
titleLbl.Position = UDim2.new(0, 12, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "bunnyxTP • BRISK CARPET"
titleLbl.TextColor3 = PAL.BrightBlue
titleLbl.Font = Enum.Font.GothamBlack
titleLbl.TextSize = 15
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.Parent = header

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -34, 0.5, -14)
closeBtn.BackgroundColor3 = PAL.BtnDark
closeBtn.Text = "X"
closeBtn.TextColor3 = PAL.BrightBlue
closeBtn.Font = Enum.Font.GothamBlack
closeBtn.TextSize = 13
closeBtn.Parent = header
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 7)
local cStroke = Instance.new("UIStroke", closeBtn)
cStroke.Color = PAL.BorderBlue
cStroke.Thickness = 1.2
closeBtn.MouseButton1Click:Connect(function()
	main.Visible = false
end)

statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 0, 30)
statusLabel.Position = UDim2.new(0, 10, 0, 54)
statusLabel.BackgroundColor3 = PAL.BoxDark
statusLabel.Text = "BUNNYXTP BRISK • 82/114 • CARRY 25"
statusLabel.TextColor3 = PAL.TextBlue
statusLabel.Font = Enum.Font.GothamBold
statusLabel.TextSize = 11
statusLabel.Parent = main
Instance.new("UICorner", statusLabel).CornerRadius = UDim.new(0, 8)
local stStroke = Instance.new("UIStroke", statusLabel)
stStroke.Color = PAL.BorderBlue
stStroke.Thickness = 1.2

local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, -20, 0, 32)
tabBar.Position = UDim2.new(0, 10, 0, 90)
tabBar.BackgroundTransparency = 1
tabBar.Parent = main

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 6)
tabLayout.Parent = tabBar

local function makePage()
	local frame = Instance.new("ScrollingFrame")
	frame.Size = UDim2.new(1, -20, 1, -138)
	frame.Position = UDim2.new(0, 10, 0, 128)
	frame.BackgroundTransparency = 1
	frame.CanvasSize = UDim2.new(0, 0, 0, 540)
	frame.ScrollBarThickness = 4
	frame.ScrollBarImageColor3 = PAL.BorderBlue
	frame.Visible = false
	frame.Parent = main

	local ll = Instance.new("UIListLayout")
	ll.Padding = UDim.new(0, 8)
	ll.Parent = frame
	return frame
end

local tpPage = makePage()
local guardPage = makePage()
local espPage = makePage()
tpPage.Visible = true

local tabStrokes = {}
local function addTab(label, page, defaultOn)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0.32, 0, 1, 0)
	b.BackgroundColor3 = defaultOn and PAL.ActiveBlue or PAL.BtnDark
	b.Text = label
	b.TextColor3 = PAL.BrightBlue
	b.Font = Enum.Font.GothamBlack
	b.TextSize = 11
	b.Parent = tabBar
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
	local s = Instance.new("UIStroke", b)
	s.Color = PAL.BorderBlue
	s.Thickness = defaultOn and 1.8 or 1.2

	b.MouseButton1Click:Connect(function()
		tpPage.Visible = false
		guardPage.Visible = false
		espPage.Visible = false
		page.Visible = true
		for _, item in ipairs(tabStrokes) do
			item.btn.BackgroundColor3 = PAL.BtnDark
			item.stroke.Thickness = 1.2
		end
		b.BackgroundColor3 = PAL.ActiveBlue
		s.Thickness = 1.8
	end)
	table.insert(tabStrokes, { btn = b, stroke = s })
end

addTab("12 DOTS TP", tpPage, true)
addTab("NO DIE / MOVE", guardPage, false)
addTab("ESP", espPage, false)

local function addBtn(parent, text, cb)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 40)
	b.BackgroundColor3 = PAL.BtnDark
	b.Text = text
	b.TextColor3 = PAL.BrightBlue
	b.Font = Enum.Font.GothamBlack
	b.TextSize = 12
	b.Parent = parent
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
	local s = Instance.new("UIStroke", b)
	s.Color = PAL.BorderBlue
	s.Thickness = 1.4
	b.MouseButton1Click:Connect(cb)
	return b
end

local function addToggle(parent, key, label, cb)
	local row = Instance.new("TextButton")
	row.Size = UDim2.new(1, 0, 0, 40)
	row.BackgroundColor3 = PAL.BtnDark
	row.Text = ""
	row.AutoButtonColor = false
	row.Parent = parent
	Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
	local s = Instance.new("UIStroke", row)
	s.Color = PAL.BorderBlue
	s.Thickness = 1.4

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -76, 1, 0)
	lbl.Position = UDim2.new(0, 12, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = label
	lbl.TextColor3 = PAL.TextBlue
	lbl.Font = Enum.Font.GothamBlack
	lbl.TextSize = 11
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = row

	local badge = Instance.new("TextLabel")
	badge.Size = UDim2.new(0, 54, 0, 24)
	badge.Position = UDim2.new(1, -64, 0.5, -12)
	badge.BackgroundColor3 = state[key] and PAL.ActiveBlue or PAL.BgDark
	badge.Text = state[key] and "ON" or "OFF"
	badge.TextColor3 = PAL.BrightBlue
	badge.Font = Enum.Font.GothamBlack
	badge.TextSize = 10
	badge.Parent = row
	Instance.new("UICorner", badge).CornerRadius = UDim.new(0, 6)
	local bs = Instance.new("UIStroke", badge)
	bs.Color = PAL.BorderBlue
	bs.Thickness = 1.2

	toggleSyncs[key] = toggleSyncs[key] or {}
	table.insert(toggleSyncs[key], { badge = badge, cb = cb })

	row.MouseButton1Click:Connect(function()
		local nextVal = not state[key]
		state[key] = nextVal
		syncToggleBadges(key, nextVal)
		if cb then
			cb(nextVal)
		end
	end)
end

-- =========================================================================
-- TAB 1: 12 DOTS • BRISK CARPET • CARRY 25 • INF JUMP • NO DIE
-- =========================================================================
local function makeDotRow()
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 38)
	row.BackgroundTransparency = 1
	row.Parent = tpPage

	local ll = Instance.new("UIListLayout")
	ll.FillDirection = Enum.FillDirection.Horizontal
	ll.Padding = UDim.new(0, 5)
	ll.Parent = row
	return row
end

local dotRow1 = makeDotRow()
local dotRow2 = makeDotRow()

local function createDotBtn(i, parentRow, widthScale)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(widthScale, 0, 1, 0)
	b.BackgroundColor3 = (i == 1) and PAL.ActiveBlue or PAL.BtnDark
	b.Text = tostring(i)
	b.TextColor3 = PAL.BrightBlue
	b.Font = Enum.Font.GothamBlack
	b.TextSize = 11
	b.Parent = parentRow
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
	local s = Instance.new("UIStroke", b)
	s.Color = PAL.BorderBlue
	s.Thickness = (i == 1) and 2 or 1.2

	b.MouseButton1Click:Connect(function()
		selectedDot = i
		nextOrderIndex = i
		refreshDotButtons()
		local cf = checkpoints[i]
		if cf then
			setStatus("DOT " .. tostring(i) .. " SELECTED (" .. math.floor(cf.X) .. ", " .. math.floor(cf.Y) .. ", " .. math.floor(cf.Z) .. ")")
		else
			setStatus("DOT " .. tostring(i) .. " SELECTED")
		end
	end)
	dotButtonRefs[i] = { btn = b, stroke = s }
end

for i = 1, 6 do
	createDotBtn(i, dotRow1, 0.152)
end
for i = 7, DOT_COUNT do
	createDotBtn(i, dotRow2, 0.152)
end

addToggle(tpPage, "AutoSwitch", "BRISK CARPET TP (82 / 114, R >10)", function(on)
	autoLoopToken += 1
	local myToken = autoLoopToken

	if on then
		ensureLockedDots(false)
		nextOrderIndex = 1
		task.spawn(function()
			while state.AutoSwitch and sg.Parent and autoLoopToken == myToken do
				local targetIdx, targetCF = getNextOrderedDot()
				if targetIdx and targetCF then
					local fastMode = isFastStage(targetIdx)
					isTeleporting = true
					selectedDot = targetIdx
					refreshDotButtons()
					local suffix = (targetIdx > 10) and " [RIGHT]" or ""
					setStatus((fastMode and "BRISK 114 -> " or "CARPET 82 -> ") .. "DOT " .. tostring(targetIdx) .. suffix)

					flyCarpetToTarget(targetCF, fastMode, function()
						return (not state.AutoSwitch) or (autoLoopToken ~= myToken)
					end)
					isTeleporting = false

					if not state.AutoSwitch or autoLoopToken ~= myToken then
						break
					end

					if targetIdx >= DOT_COUNT then
						nextOrderIndex = 1
						setToggleState("AutoSwitch", false, nil)
						setStatus("HIT DOT 12 (BRISK RUN DONE) — STOPPED")
						break
					end

					nextOrderIndex = targetIdx + 1
				else
					nextOrderIndex = 1
					setToggleState("AutoSwitch", false, nil)
					setStatus("DONE — STOPPED")
					break
				end
			end
			isTeleporting = false
		end)
	else
		isTeleporting = false
		setStatus("BRISK CARPET TP STOPPED")
	end
end)

addToggle(tpPage, "CarrySpeed", "CARRY SPEED (25)", function(on)
	setStatus("CARRY SPEED 25: " .. (on and "ON" or "OFF"))
end)

addToggle(tpPage, "InfiniteJump", "INFINITE JUMP BYPASS", function(on)
	setStatus("INFINITE JUMP BYPASS: " .. (on and "ON" or "OFF"))
end)

addToggle(tpPage, "AntiDie", "NO DIE", function(on)
	if on and player.Character then
		applyNoDieToChar(player.Character)
	elseif not on then
		if antiDieConn then pcall(function() antiDieConn:Disconnect() end) antiDieConn = nil end
		if healthConn then pcall(function() healthConn:Disconnect() end) healthConn = nil end
	end
	setStatus("NO DIE: " .. (on and "ON" or "OFF"))
end)

addBtn(tpPage, "LOCK / SAVE SELECTED DOT HERE", function()
	if saveDotAtCurrentSpot(selectedDot) then
		setStatus("LOCKED DOT " .. tostring(selectedDot) .. " AT CURRENT SPOT")
	end
end)

addBtn(tpPage, "CARPET FLY -> SELECTED DOT", function()
	ensureLockedDots(false)
	local target = checkpoints[selectedDot]
	if not target or isTeleporting then
		return
	end
	isTeleporting = true
	local fastMode = isFastStage(selectedDot)
	task.spawn(function()
		setStatus((fastMode and "BRISK 114 -> " or "CARPET 82 -> ") .. "DOT " .. tostring(selectedDot))
		flyCarpetToTarget(target, fastMode, function()
			return not sg.Parent
		end)
		setStatus("AT DOT " .. tostring(selectedDot))
		isTeleporting = false
	end)
end)

addBtn(tpPage, "RESTORE ALL 12 LOCKED DOTS", function()
	ensureLockedDots(false)
	setStatus("ALL 12 LOCKED DOTS RESTORED")
end)

-- =========================================================================
-- TAB 2: NO DIE / MOVE & CARPET SETTINGS
-- =========================================================================
addToggle(guardPage, "CarrySpeed", "CARRY SPEED (25)", function(on)
	setStatus("CARRY SPEED 25: " .. (on and "ON" or "OFF"))
end)

addToggle(guardPage, "InfiniteJump", "INFINITE JUMP BYPASS", function(on)
	setStatus("INFINITE JUMP BYPASS: " .. (on and "ON" or "OFF"))
end)

addToggle(guardPage, "AntiDie", "NO DIE GUARD", function(on)
	if on and player.Character then
		applyNoDieToChar(player.Character)
	elseif not on then
		if antiDieConn then pcall(function() antiDieConn:Disconnect() end) antiDieConn = nil end
		if healthConn then pcall(function() healthConn:Disconnect() end) healthConn = nil end
	end
	setStatus("NO DIE: " .. (on and "ON" or "OFF"))
end)

addToggle(guardPage, "MicroStepAssist", "MICRO-STEP ASSIST (ANTI-PULLBACK)", function(on)
	setStatus("MICRO-STEP ASSIST: " .. (on and "ON" or "OFF"))
end)

addToggle(guardPage, "OwnerHeadTag", "OWNER OVERHEAD HEAD TAG", function(on)
	if on then
		applyOwnerHeadTag(player.Character)
	else
		clearOwnerHeadTag()
	end
	setStatus("OWNER HEAD TAG: " .. (on and "ON" or "OFF"))
end)

addToggle(guardPage, "UseCarpet", "AUTO-EQUIP FLYING CARPET")

addBtn(guardPage, "RE-ANCHOR 12 DOTS TO MID BASE", function()
	ensureLockedDots(true)
	setStatus("RE-LOCKED 12 DOTS FROM MID BASE")
end)

-- =========================================================================
-- TAB 3: ESP
-- =========================================================================
addToggle(espPage, "PlayerESP", "PLAYER HIGHLIGHT ESP", function()
	refreshESP()
end)

addToggle(espPage, "PlayerTags", "PLAYER NAME & DISTANCE TAGS", function()
	refreshESP()
end)

addToggle(espPage, "BrainrotESP", "BRAINROT / HIGH-VALUE ESP", function()
	refreshESP()
end)

addBtn(espPage, "REFRESH ESP NOW", function()
	refreshESP()
	setStatus("ESP REFRESHED")
end)

startCarrySpeedLoop()
startInfiniteJumpBypass()

task.spawn(function()
	local char = player.Character or player.CharacterAdded:Wait()
	if char then
		char:WaitForChild("HumanoidRootPart", 10)
		applyNoDieToChar(char)
		applyOwnerHeadTag(char)
		ensureLockedDots(false)
	end
end)

player.CharacterAdded:Connect(function(newChar)
	autoLoopToken += 1
	isTeleporting = false
	nextOrderIndex = 1
	setToggleState("AutoSwitch", false, nil)
	setStatus("RESPAWNED — 12 DOTS STILL LOCKED")
	task.spawn(function()
		newChar:WaitForChild("HumanoidRootPart", 10)
		applyNoDieToChar(newChar)
		applyOwnerHeadTag(newChar)
		ensureLockedDots(false)
		if state.PlayerESP or state.PlayerTags or state.BrainrotESP then
			refreshESP()
		end
	end)
end)

Players.PlayerAdded:Connect(function(plr)
	plr.CharacterAdded:Connect(function()
		if state.PlayerESP or state.PlayerTags then
			refreshESP()
		end
	end)
end)

Players.PlayerRemoving:Connect(function()
	if state.PlayerESP or state.PlayerTags then
		refreshESP()
	end
end)
