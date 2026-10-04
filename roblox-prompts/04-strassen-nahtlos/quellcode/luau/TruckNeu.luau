-- Truck: Arcade-Fahrwerk für den eigenen LKW (Raycast-Bodenfolge, Gas/Lenkung über VehicleSeat), Tacho
-- [RoadSmooth] Fahrwerk v2:
--   * Bodenstrahlen ignorieren Teile ohne Kollision (Markierungen, Trigger, Marker, Deko-Meshes) und nutzen die
--     Kollisionsgruppe "TruckRay" (sieht die glatte Fahrhaut statt der alten Fahrbahn-Abschnitte).
--   * Hoehe wird mit einem Alpha-Beta-Filter geglaettet: folgt Steigungen ohne Verzug, kleine Kanten werden weich.
--   * Vorausschau-Strahlen an der Stossstange heben den LKW rechtzeitig an, statt gegen Kanten zu fahren.
--   * Neigung (Up-Vektor) wird weich nachgefuehrt.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")
local RS = game:GetService("ReplicatedStorage")
local U = require(RS.Modules.Util)

local Tr = {}
local UI, T
local player = Players.LocalPlayer
local active

-- Fahrwerks-Einstellungen
local ALPHA = 0.2 -- Hoehenfilter: Anteil der Abweichung, der je Frame (60 fps) uebernommen wird
local BETA = 0.03 -- Hoehenfilter: Anpassung der Steiggeschwindigkeit
local CLEAR = 0.25 -- Mindestabstand Kasten-Unterkante ueber dem hoechsten Bodenpunkt (Studs)
local SAG = 0.6 -- so weit darf die gefilterte Hoehe unter der gemessenen liegen (Studs)
local UP_RATE = 10 -- Nachfuehrung der Neigung (1/s)
local LOOKAHEAD = 0.18 -- Sekunden Vorausschau fuer die Stossstangen-Strahlen

local function groupExists(name)
	local ok, res = pcall(function() return PhysicsService:IsCollisionGroupRegistered(name) end)
	return ok and res
end

local function stop()
	if not active then return end
	for _, x in ipairs(active.Objects) do x:Destroy() end
	if active.Conn then active.Conn:Disconnect() end
	if active.Gui then active.Gui.Visible = false end
	active = nil
end

local function start(seat, model)
	stop()
	local root = model.PrimaryPart
	if not root then return end
	local objs = {}
	local att = Instance.new("Attachment")
	att.Name = "DriveAtt"
	att.Parent = root
	table.insert(objs, att)
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	lv.PrimaryTangentAxis = Vector3.new(1, 0, 0)
	lv.SecondaryTangentAxis = Vector3.new(0, 0, 1)
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.MaxForce = root.AssemblyMass * 220
	lv.Parent = root
	table.insert(objs, lv)
	local ap = Instance.new("AlignPosition")
	ap.Mode = Enum.PositionAlignmentMode.OneAttachment
	ap.Attachment0 = att
	ap.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	ap.MaxAxesForce = Vector3.new(0, root.AssemblyMass * 400, 0)
	ap.Responsiveness = 25
	ap.MaxVelocity = 60
	ap.Position = root.Position
	ap.Parent = root
	table.insert(objs, ap)
	local ao = Instance.new("AlignOrientation")
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = att
	ao.MaxTorque = math.huge
	ao.Responsiveness = 30
	ao.CFrame = root.CFrame.Rotation
	ao.Parent = root
	table.insert(objs, ao)
	-- Fahrwerks-Ecken aus den Rädern
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("Wheel") then
			local lp = root.CFrame:PointToObjectSpace(d.Position)
			minX, maxX = math.min(minX, lp.X), math.max(maxX, lp.X)
			minZ, maxZ = math.min(minZ, lp.Z), math.max(maxZ, lp.Z)
		end
	end
	if minX == math.huge then minX, maxX, minZ, maxZ = -3, 3, -6, 6 end
	local corners = { Vector3.new(minX, 0, minZ), Vector3.new(maxX, 0, minZ), Vector3.new(minX, 0, maxZ), Vector3.new(maxX, 0, maxZ) }
	local pivotOff = root.CFrame:ToObjectSpace(model:GetPivot())
	local ride = -pivotOff.Position.Y
	-- Kasten (Kollision): halbe Laenge/Breite und Bodenfreiheit
	local halfL, halfW = root.Size.Z / 2, root.Size.X / 2
	local clearance = ride - root.Size.Y / 2
	local maxSpeed = (model:GetAttribute("MaxSpeed") or 44) * 1.25
	local accel = (model:GetAttribute("Accel") or 14) * 1.3
	local turn = model:GetAttribute("Turn") or 1
	local speed = 0
	local _, yaw = root.CFrame:ToEulerAnglesYXZ()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	if groupExists("TruckRay") then params.CollisionGroup = "TruckRay" end
	local function refreshFilter()
		local list = { model }
		for _, p in ipairs(Players:GetPlayers()) do if p.Character then table.insert(list, p.Character) end end
		local g = workspace:FindFirstChild("ClientGhosts")
		if g then table.insert(list, g) end
		params.FilterDescendantsInstances = list
	end
	refreshFilter()
	local gui = Tr.Gui
	gui.Visible = true
	active = { Objects = objs, Gui = gui }
	local tick = 0
	local lastPos = root.Position
	local studio = RunService:IsStudio()
	-- Filterzustand
	local fy, fv = nil, 0 -- gefilterte Bodenhoehe und deren Aenderungsrate
	local upF = root.CFrame.UpVector
	local function cast(wp)
		local hit = workspace:Raycast(wp + Vector3.new(0, 6, 0), Vector3.new(0, -40, 0), params)
		return hit and hit.Position or nil
	end
	active.Conn = RunService.Heartbeat:Connect(function(dt)
		if not seat.Parent or seat.Occupant == nil or not root.Parent then stop() return end
		tick += dt
		if tick > 2 then tick = 0 refreshFilter() end
		-- vom Server versetzt (Autobahn-Reise, Heimfahrt)? Ausrichtung übernehmen, Tempo zurücksetzen
		local now = root.Position
		if (now - lastPos).Magnitude > 30 then
			local _, y = root.CFrame:ToEulerAnglesYXZ()
			yaw = y
			speed = 0
			ap.Position = now
			fy, fv = nil, 0
			upF = root.CFrame.UpVector
		end
		lastPos = now
		local throttle, steer = seat.ThrottleFloat, seat.SteerFloat
		if studio and seat:GetAttribute("TestThrottle") then
			-- nur in Studio: automatisierte Fahrtests
			throttle = seat:GetAttribute("TestThrottle")
			steer = seat:GetAttribute("TestSteer") or 0
		end
		-- Geschwindigkeit
		if throttle > 0 then
			speed += (speed < 0 and accel * 2.5 or accel) * throttle * dt
		elseif throttle < 0 then
			speed += (speed > 0 and accel * 2.8 or accel * 0.7) * throttle * dt
		else
			local drag = accel * 0.6 * dt
			if math.abs(speed) <= drag then speed = 0 else speed -= drag * math.sign(speed) end
		end
		speed = math.clamp(speed, -maxSpeed * 0.35, maxSpeed)
		-- Lenkung (abhängig vom Tempo)
		local sf = math.clamp(math.abs(speed) / 14, 0, 1) * math.sign(speed)
		yaw -= steer * turn * sf * dt
		-- Boden abtasten
		local rc = root.CFrame
		local flatCF = CFrame.new(rc.Position) * CFrame.Angles(0, yaw, 0)
		local pts, n = {}, 0
		local maxHit = -math.huge
		for _, c in ipairs(corners) do
			local hp = cast(flatCF * c)
			if hp then
				n += 1
				pts[#pts + 1] = hp
				if hp.Y > maxHit then maxHit = hp.Y end
			else
				pts[#pts + 1] = false
			end
		end
		-- Vorausschau an der Stossstange (in Fahrtrichtung): links, Mitte, rechts
		if math.abs(speed) > 1 then
			local dir = (speed > 0) and -1 or 1 -- lokal -Z = vorne
			local ahead = halfL + math.clamp(math.abs(speed) * LOOKAHEAD, 1, 10)
			for _, sx in ipairs({ -halfW + 0.3, 0, halfW - 0.3 }) do
				local hp = cast(flatCF * Vector3.new(sx, 0, dir * ahead))
				if hp and hp.Y > maxHit then maxHit = hp.Y end
			end
		end
		local fwd = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
		if n >= 3 then
			local sum = Vector3.zero
			for _, p in ipairs(pts) do if p then sum += p end end
			local avg = sum / n
			local fl, fr, rl, rr = pts[1] or avg, pts[2] or avg, pts[3] or avg, pts[4] or avg
			local front, rear = (fl + fr) / 2, (rl + rr) / 2
			local left, right = (fl + rl) / 2, (fr + rr) / 2
			local f = (front - rear)
			local r = (right - left)
			local up = r:Cross(f)
			if up.Y < 0 then up = -up end
			up = (up.Magnitude > 0.01) and up.Unit or Vector3.yAxis
			if up.Y < 0.6 then up = Vector3.yAxis end
			-- Hoehenfilter (Alpha-Beta): Steigungen ohne Verzug, Kanten weich
			local raw = avg.Y
			local k = math.clamp(dt * 60, 0.25, 4)
			if fy == nil then
				fy, fv = raw, 0
			else
				local pred = fy + fv * dt
				local res = raw - pred
				fy = pred + math.min(1, ALPHA * k) * res
				fv = fv + math.min(1, BETA * k) * res / math.max(dt, 1e-3)
			end
			-- Sicherheitsgrenzen: nicht zu tief unter dem Boden, Kasten immer ueber dem hoechsten Punkt
			local lb = math.max(raw - SAG, maxHit + CLEAR - clearance)
			if fy < lb then
				fy = lb
				if fv < 0 then fv = 0 end
			end
			-- Neigung weich nachfuehren
			upF = upF:Lerp(up, 1 - math.exp(-UP_RATE * dt))
			upF = (upF.Magnitude > 0.01) and upF.Unit or Vector3.yAxis
			ap.Enabled = true
			ap.Position = Vector3.new(rc.Position.X, fy + ride, rc.Position.Z)
			local look = (fwd - upF * fwd:Dot(upF)).Unit
			ao.CFrame = CFrame.lookAt(Vector3.zero, look, upF)
			lv.MaxForce = root.AssemblyMass * 220
			lv.PlaneVelocity = Vector2.new(fwd.X * speed, fwd.Z * speed)
		else
			fy, fv = nil, 0
			ap.Enabled = false
			upF = Vector3.yAxis
			ao.CFrame = CFrame.lookAt(Vector3.zero, fwd, Vector3.yAxis)
			lv.MaxForce = root.AssemblyMass * 20
			lv.PlaneVelocity = Vector2.new(fwd.X * speed, fwd.Z * speed)
		end
		-- gegen Hindernis gefahren? Tempo an echte Geschwindigkeit angleichen
		local real = root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
		if math.abs(speed) > 6 and real.Magnitude < math.abs(speed) * 0.35 then
			speed *= 0.92
		end
		Tr.SpeedText.Text = tostring(math.floor(math.abs(speed) * 1.6)) .. ""
	end)
end

function Tr.Init(ui)
	UI, T = ui, ui.T
	local g = UI.Panel(UI.HUD, { Name = "Speedo", Size = UDim2.fromOffset(170, 70), Position = UDim2.new(1, -16, 1, -96), AnchorPoint = Vector2.new(1, 1), Visible = false })
	Tr.Gui = g
	Tr.SpeedText = UI.Text(g, "0", 40, { Font = T.FontNumber, AlignX = Enum.TextXAlignment.Right, Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, -62, 0, 46) })
	UI.Text(g, "km/h", 14, { Font = T.FontBold, Color = T.SubText, Position = UDim2.new(1, -56, 0, 22), Size = UDim2.fromOffset(50, 20) })
	UI.Text(g, "Leertaste = Aussteigen", 11, { Color = T.SubText, AlignX = Enum.TextXAlignment.Center, Position = UDim2.new(0, 0, 1, -18), Size = UDim2.new(1, 0, 0, 14) })
	local function hookChar(ch)
		local hum = ch:WaitForChild("Humanoid", 10)
		if not hum then return end
		hum.Seated:Connect(function(on, seat)
			if on and seat and seat:IsA("VehicleSeat") then
				local model = seat:FindFirstAncestorWhichIsA("Model")
				if model and model:GetAttribute("OwnerId") == player.UserId then
					task.wait(0.25)
					start(seat, model)
				end
			else
				stop()
			end
		end)
	end
	player.CharacterAdded:Connect(hookChar)
	if player.Character then task.spawn(hookChar, player.Character) end
end

return Tr
