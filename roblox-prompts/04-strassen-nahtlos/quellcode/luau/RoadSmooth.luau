--!native
-- RoadSmooth: nahtlose Strassen fuer den LKW (Edit-Modus-Werkzeug, DevTools).
--   Idee: eine unsichtbare, geglaettete "Fahrhaut" ueber allen Fahrbahnen. Nur sie sieht das Fahrwerk des LKW
--   (Kollisionsgruppe TruckRay); die alten Abschnitte (Gruppe RoadBase) bleiben fuer Figuren, Optik und Kasten-Kollision.
--   Dazu: LKW-genaues Audit mit echten Raycasts, Gelaende-Korrektur, automatische Testfahrt, Mesh-Platzierung.
--
--   local RS = require(game.ServerStorage.DevTools.RoadSmooth)
--   print(RS.Help())
--
-- Alles ist rueckgaengig zu machen: RS.Restore(stadt), RS.RestoreTerrain(stadt), RS.UninstallTruck(), RS.RestoreMeshes(stadt).
local RS = {}

local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local ScriptEditorService = game:GetService("ScriptEditorService")

local Core = require(script:WaitForChild("Core"))
RS.Core = Core
RS.VERSION = "1.0"
RS.LastAudit = nil
RS.LastDrive = nil

RS.CITIES = { "Neustadt", "Portavia", "Metropolis" }
RS.ROADNAMES = {
	Road = true, RoadFill = true, RoadRamp = true, SlitFill = true, RoadBevel = true, Asphalt = true, Joint = true,
	JointSquare = true, Lane = true, LaneJoint = true, LaneLink = true, TurnCircle = true, EndCap = true, Deck = true,
	Track = true, Yard = true,
}
-- Ordner, deren Inhalt nie Fahrbahn ist (auch wenn Teile dort so heissen)
RS.EXCLUDE = {
	CaseScenes = true, Plots = true, FahrHaut = true, StrassenMesh = true, StrassenMesh2 = true, Landschaft = true,
	Fleet = true, Decor = true, Trading = true, Hub = true, Staging = true, Ausflugsschiff = true, Containerschiff = true,
}
RS.GROUP_BASE, RS.GROUP_SKIN, RS.GROUP_RAY = "RoadBase", "RoadSkin", "TruckRay"
RS.UNDER = 3 -- Teil liegt unter einer anderen Fahrbahn (Unterfuehrung), wenn diese mehr als so hoch darueber liegt

-- Van (kleinstes Fahrzeug, haeufigster Fall) und Titan40 (laengstes) fuer das Audit
RS.VEHICLES = {
	Van = { cx = 2.75, zf = -5.4, zr = 5.2, ride = 5.08, halfL = 8.5, halfW = 3.3, height = 7.44 },
	Titan = { cx = 3.75, zf = -17.6, zr = 19.2, ride = 7.88, halfL = 23, halfW = 4.3, height = 11.84 },
}

----------------------------------------------------------------------------------------------- Hilfen
local function cityOfX(x)
	if x > 4000 then return "Portavia" end
	if x < -4000 then return "Metropolis" end
	return "Neustadt"
end
RS.CityOfX = cityOfX

local function world()
	return Workspace:FindFirstChild("World")
end

local function excluded(p)
	local a = p.Parent
	while a and a ~= Workspace do
		if RS.EXCLUDE[a.Name] then return true end
		a = a.Parent
	end
	return false
end

-- Fahrbahnteil? ("Deck" nur bei Bruecken, nicht bei Schiffen/Buehnen)
local function isRoad(p)
	if not RS.ROADNAMES[p.Name] then return false end
	if p.Name == "Deck" and not p:FindFirstAncestor("Bridges") then return false end
	return true
end
RS.IsRoad = isRoad

local function folder(parent, name)
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f
end

local status = { Job = "-", Step = "", Progress = 0, Started = 0, Done = true, Error = nil }
RS.State = status
local function setStep(step, prog)
	status.Step = step
	status.Progress = prog or 0
end
local lastYield = os.clock()
local function yield(prog)
	if prog then status.Progress = prog end
	if os.clock() - lastYield > 0.05 then
		task.wait()
		lastYield = os.clock()
	end
end

-- Teil -> Tabelle fuer Core
function RS.PartInfo(p)
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = p.CFrame:GetComponents()
	local k = 0
	if p:IsA("WedgePart") then
		k = 1
	elseif p:IsA("Part") then
		if p.Shape == Enum.PartType.Cylinder then
			k = 2
		elseif p.Shape == Enum.PartType.Ball then
			k = 3
		elseif p.Shape == Enum.PartType.Wedge then
			k = 1
		end
	end
	return { k = k, x = x, y = y, z = z, r = { r00, r01, r02, r10, r11, r12, r20, r21, r22 }, sx = p.Size.X, sy = p.Size.Y, sz = p.Size.Z }
end

----------------------------------------------------------------------------------------------- Kollisionsgruppen
function RS.Groups()
	for _, g in ipairs({ RS.GROUP_BASE, RS.GROUP_SKIN, RS.GROUP_RAY }) do
		if not PhysicsService:IsCollisionGroupRegistered(g) then PhysicsService:RegisterCollisionGroup(g) end
	end
	-- Fahrwerks-Strahlen sehen die alten Abschnitte nicht mehr, nur die Haut (und alles andere wie bisher)
	PhysicsService:CollisionGroupSetCollidable(RS.GROUP_RAY, RS.GROUP_BASE, false)
	PhysicsService:CollisionGroupSetCollidable(RS.GROUP_RAY, RS.GROUP_SKIN, true)
	-- die Haut existiert fuer alles andere nicht (Figuren, Kasten, andere Raycasts, Overlaps)
	for _, info in ipairs(PhysicsService:GetRegisteredCollisionGroups()) do
		local name = info.name
		if name ~= RS.GROUP_RAY and name ~= RS.GROUP_SKIN then
			PhysicsService:CollisionGroupSetCollidable(RS.GROUP_SKIN, name, false)
		end
	end
	return "Gruppen bereit: RoadBase (alte Fahrbahn), RoadSkin (Haut, nur fuer TruckRay sichtbar), TruckRay (Fahrwerks-Strahlen, ignoriert RoadBase)"
end

----------------------------------------------------------------------------------------------- Sammeln
-- alle Fahrbahnteile einer Stadt
function RS.Collect(city)
	local W = world()
	assert(W, "workspace.World fehlt")
	local out = {}
	for _, p in ipairs(W:GetDescendants()) do
		if p:IsA("BasePart") and isRoad(p) and p.CanCollide and not p:IsA("MeshPart") and not p:IsA("UnionOperation") then
			if cityOfX(p.Position.X) == city and not excluded(p) then table.insert(out, p) end
		end
	end
	return out
end

-- Teile, die (auch nur teilweise) unter einer anderen Fahrbahn liegen (Unterfuehrung): bleiben unveraendert
-- (keine Haut, Gruppe bleibt, Optik bleibt sichtbar). Dichte Abtastung der Oberseite (alle 2 Studs).
function RS.Under(parts)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = parts
	local under = {}
	for i, p in ipairs(parts) do
		local info = RS.PartInfo(p)
		local nx, ny, nz, ft = Core.TopFace(info)
		local loc = Core.FaceSamples(info.k, nx, ny, nz, ft, info.sx, info.sy, info.sz, 2)
		for _, q in ipairs(loc) do
			local wp = p.CFrame:PointToWorldSpace(Vector3.new(q[1], q[2], q[3]))
			local r = Workspace:Raycast(wp + Vector3.new(0, 0.05, 0), Vector3.new(0, 80, 0), rp)
			if r and r.Instance ~= p and r.Distance > RS.UNDER then
				under[p] = true
				break
			end
		end
		if i % 100 == 0 then yield() end
	end
	return under
end

----------------------------------------------------------------------------------------------- Haut bauen
local function skinFolder(city, create)
	local W = world()
	local root = W:FindFirstChild("FahrHaut")
	if not root then
		if not create then return nil end
		root = Instance.new("Folder")
		root.Name = "FahrHaut"
		root.Parent = W
	end
	local f = root:FindFirstChild(city)
	if not f and create then
		-- Persistent: die Haut ist auf jedem Client immer vollstaendig da (kein Streaming-Loch unter dem LKW)
		f = Instance.new("Model")
		f.Name = city
		f.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		f.Parent = root
	end
	return f
end

-- Feld (geglaettete Flaeche) einer Stadt berechnen; Rueckgabe grid, parts, infos, under
function RS.Field(city)
	setStep("Sammeln", 0)
	local parts = RS.Collect(city)
	setStep("Unterfuehrungen", 0.05)
	local under = RS.Under(parts)
	local list, infos = {}, {}
	local x0, z0, x1, z1 = math.huge, math.huge, -math.huge, -math.huge
	for _, p in ipairs(parts) do
		if not under[p] then
			local info = RS.PartInfo(p)
			table.insert(list, p)
			table.insert(infos, info)
			local ex, _, ez = Core.Extents(info)
			x0 = math.min(x0, info.x - ex); x1 = math.max(x1, info.x + ex)
			z0 = math.min(z0, info.z - ez); z1 = math.max(z1, info.z + ez)
		end
	end
	assert(#list > 0, "keine Fahrbahnteile in " .. city)
	local g = Core.NewGrid(math.floor(x0) - 8, math.floor(z0) - 8, math.ceil(x1) + 8, math.ceil(z1) + 8, Core.P.G)
	setStep("Rastern", 0.1)
	for i, info in ipairs(infos) do
		Core.RasterPart(g, info, i)
		if i % 100 == 0 then yield(0.1 + 0.1 * i / #infos) end
	end
	setStep("Glaetten", 0.2)
	Core.Smooth(g, function(t) yield(0.2 + 0.4 * t) end)
	return g, list, infos, under
end

local function makePart(pc)
	local p
	if pc.k == 1 then
		p = Instance.new("WedgePart")
	else
		p = Instance.new("Part")
		if pc.k == 2 then p.Shape = Enum.PartType.Cylinder end
	end
	p.Name = pc.gap and "HautLuecke" or "Haut"
	p.Anchored = true
	p.CanCollide = true
	p.CanQuery = true
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = Vector3.new(pc.sx, pc.sy, pc.sz)
	local r = pc.r
	p.CFrame = CFrame.new(pc.x, pc.y, pc.z, r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9])
	p.CollisionGroup = RS.GROUP_SKIN
	pcall(function() p.AudioCanCollide = false end)
	p.Locked = true
	return p
end

-- Fahrhaut einer Stadt bauen (ersetzt eine vorhandene). opts: { Dry = true } -> nur zaehlen
function RS.Build(city, opts)
	opts = opts or {}
	RS.Groups()
	local t0 = os.clock()
	local g, list, infos, under = RS.Field(city)
	setStep("Hautplatten", 0.6)
	-- nur Teile, die irgendwo oben liegen (andere sind komplett verdeckt)
	local owners = {}
	for o = 0, g.n - 1 do
		local id = buffer.readi32(g.own, o * 4)
		if id ~= 0 then owners[id] = true end
	end
	local pieces, stat = {}, {}
	local partial = {} -- teilweise verdeckt: bleiben fuer die Fahrwerks-Strahlen sichtbar
	for i, info in ipairs(infos) do
		if owners[i] then
			local pc, st = Core.PiecesFor(g, info)
			stat[st] = (stat[st] or 0) + 1
			if st == "unter" then partial[list[i]] = true end
			for _, q in ipairs(pc) do table.insert(pieces, q) end
		end
		if i % 100 == 0 then yield(0.6 + 0.15 * i / #infos) end
	end
	local gaps = Core.GapPieces(g)
	for _, q in ipairs(gaps) do table.insert(pieces, q) end
	-- Abweichung Haut - alte Oberkante (grosse Werte = grosse Stufen, die die Haut nur abmildert)
	local dev = {}
	local big = {}
	for o = 0, g.n - 1 do
		if buffer.readu8(g.mask, o) == 1 then
			local d = buffer.readf32(g.f, o * 4) - buffer.readf32(g.top, o * 4)
			table.insert(dev, d)
			if math.abs(d) > 0.3 and #big < 4000 then
				local i, k = o % g.nx, o // g.nx
				table.insert(big, { g.x0 + (i + 0.5) * g.G, buffer.readf32(g.top, o * 4), g.z0 + (k + 0.5) * g.G, d })
			end
		end
	end
	table.sort(dev)
	local function pct(q) return dev[math.max(1, math.floor(#dev * q))] or 0 end
	local function count(t) local n = 0 for _ in pairs(t) do n += 1 end return n end
	local summary = string.format(
		"%s: %d Fahrbahnteile (%d Unterfuehrung, %d teilweise verdeckt, %d oben), %d Hautplatten (%d Luecken), geteilt %d, Haut-alt: 1%% %.2f / 50%% %.2f / 99%% %.2f, Stellen >0.3: %d",
		city, #list + count(under), count(under), count(partial), count(owners), #pieces, #gaps, stat["geteilt"] or 0, pct(0.01), pct(0.5), pct(0.99), #big)
	if opts.Dry then
		setStep("fertig (Probe)", 1)
		return summary
	end
	-- alte Haut weg, neue anlegen
	setStep("Teile anlegen", 0.75)
	local old = skinFolder(city, false)
	if old then old:Destroy() end
	local f = skinFolder(city, true)
	for i, pc in ipairs(pieces) do
		makePart(pc).Parent = f
		if i % 200 == 0 then yield(0.75 + 0.2 * i / #pieces) end
	end
	-- alte Fahrbahn fuer die Fahrwerks-Strahlen ausblenden (Gruppe RoadBase) - aber nur, wo die Haut sie wirklich abdeckt.
	-- Unterfuehrungen, teilweise verdeckte und nicht abgedeckte Teile bleiben in ihrer Gruppe.
	setStep("Gruppen setzen", 0.95)
	local skinRp = RaycastParams.new()
	skinRp.FilterType = Enum.RaycastFilterType.Include
	skinRp.FilterDescendantsInstances = { f }
	skinRp.CollisionGroup = RS.GROUP_RAY -- die Haut ist nur fuer TruckRay sichtbar
	local toBase = {}
	local notCovered = 0
	for idx, p in ipairs(list) do
		if not partial[p] then
			local info = infos[idx]
			local nx, ny, nz, ft = Core.TopFace(info)
			local loc = Core.FaceSamples(info.k, nx, ny, nz, ft, info.sx, info.sy, info.sz, 2)
			local hit, tot = 0, 0
			for _, q in ipairs(loc) do
				local wp = p.CFrame:PointToWorldSpace(Vector3.new(q[1], q[2], q[3]))
				tot += 1
				local r = Workspace:Raycast(wp + Vector3.new(0, 3, 0), Vector3.new(0, -6, 0), skinRp)
				if r then hit += 1 end
			end
			if tot > 0 and hit >= 0.9 * tot then
				toBase[p] = true
			else
				notCovered += 1
			end
		end
		if idx % 100 == 0 then yield(0.95 + 0.04 * idx / #list) end
	end
	-- fruehere RoadBase-Teile dieser Stadt, die jetzt nicht mehr dazugehoeren, zuruecksetzen
	local nBack = 0
	for _, p in ipairs(world():GetDescendants()) do
		if p:IsA("BasePart") and not toBase[p] then
			local og = p:GetAttribute("RS_Group")
			if og ~= nil and cityOfX(p.Position.X) == city then
				p.CollisionGroup = og
				p:SetAttribute("RS_Group", nil)
				nBack += 1
			end
		end
	end
	local n = 0
	for p in pairs(toBase) do
		if p:GetAttribute("RS_Group") == nil then p:SetAttribute("RS_Group", p.CollisionGroup) end
		p.CollisionGroup = RS.GROUP_BASE
		n += 1
	end
	f:SetAttribute("Version", RS.VERSION)
	f:SetAttribute("Built", os.date("%Y-%m-%d %H:%M"))
	f:SetAttribute("Pieces", #pieces)
	f:SetAttribute("Summary", summary)
	-- grosse Stufen merken (fuer Bericht/Nacharbeit)
	local bigJson = HttpService:JSONEncode(big)
	local rep = folder(ServerStorage, "RoadSmoothReport")
	local sv = rep:FindFirstChild(city .. "_Stufen") or Instance.new("StringValue")
	sv.Name = city .. "_Stufen"
	sv.Value = string.sub(bigJson, 1, 190000)
	sv.Parent = rep
	setStep("fertig", 1)
	return summary .. string.format(" | %d Teile -> RoadBase, %d nicht voll abgedeckt (bleiben sichtbar fuer das Fahrwerk), %d zurueckgesetzt | %.1fs", n, notCovered, nBack, os.clock() - t0)
end

-- Haut entfernen, Gruppen der alten Fahrbahn zuruecksetzen
function RS.Restore(city)
	local f = skinFolder(city, false)
	local nSkin = 0
	if f then
		nSkin = #f:GetChildren()
		f:Destroy()
	end
	local n = 0
	for _, p in ipairs(world():GetDescendants()) do
		if p:IsA("BasePart") and p:GetAttribute("RS_Group") ~= nil and cityOfX(p.Position.X) == city then
			p.CollisionGroup = p:GetAttribute("RS_Group")
			p:SetAttribute("RS_Group", nil)
			n += 1
		end
	end
	return string.format("%s: %d Hautplatten entfernt, %d Teile zurueck in ihre Gruppe", city, nSkin, n)
end

----------------------------------------------------------------------------------------------- Fahrwerk
local function truckScript()
	local sps = StarterPlayer:FindFirstChild("StarterPlayerScripts")
	local client = sps and sps:FindFirstChild("Client")
	return client and client:FindFirstChild("Truck")
end

-- Quelltext setzen: ueber ScriptEditorService (funktioniert auch bei offenem Skript-Tab / Collaborative Editing),
-- sonst direkt .Source
local function setSource(sc, text)
	local ok = pcall(function()
		ScriptEditorService:UpdateSourceAsync(sc, function() return text end)
	end)
	if not ok or sc.Source ~= text then sc.Source = text end
	return sc.Source == text
end

function RS.InstallTruck()
	local tr = truckScript()
	assert(tr and tr:IsA("ModuleScript"), "StarterPlayerScripts.Client.Truck nicht gefunden")
	local src = script:WaitForChild("TruckNeu")
	if tr.Source == src.Source then
		RS.Groups()
		return "Fahrwerk v2 ist schon installiert"
	end
	local bk = folder(ServerStorage, "ScriptBackups")
	local old = bk:FindFirstChild("Truck_vorRoadSmooth")
	if old and old.Source ~= tr.Source then
		-- Truck wurde seit dem letzten Backup geaendert: altes Backup behalten (mit Datum), aktuellen Stand sichern
		old.Name = "Truck_vorRoadSmooth_" .. os.date("%Y%m%d_%H%M%S")
		old = nil
	end
	if not old then
		local c = tr:Clone()
		c.Name = "Truck_vorRoadSmooth"
		c.Parent = bk
	end
	assert(setSource(tr, src.Source), "Quelltext liess sich nicht setzen - Truck-Skript-Tab schliessen und nochmal")
	RS.Groups()
	return "Fahrwerk v2 installiert (Backup: ServerStorage.ScriptBackups.Truck_vorRoadSmooth)"
end

function RS.UninstallTruck(force)
	local tr = truckScript()
	local bk = ServerStorage:FindFirstChild("ScriptBackups")
	local old = bk and bk:FindFirstChild("Truck_vorRoadSmooth")
	assert(tr and old, "Backup oder Truck-Modul fehlt")
	local src = script:FindFirstChild("TruckNeu")
	assert(force or (src and tr.Source == src.Source),
		"Truck-Modul wurde nach der Installation geaendert - RS.UninstallTruck(true) setzt trotzdem das Backup zurueck")
	assert(setSource(tr, old.Source), "Quelltext liess sich nicht setzen - Truck-Skript-Tab schliessen und nochmal")
	return "altes Fahrwerk wiederhergestellt"
end

----------------------------------------------------------------------------------------------- Audit
-- Strahl-Parameter wie im Fahrwerk: "neu" (RespectCanCollide + TruckRay) oder "alt" (wie bisher)
local function rayParams(mode)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local ex = {}
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(ex, pl.Character) end end
	local cg = Workspace:FindFirstChild("ClientGhosts")
	if cg then table.insert(ex, cg) end
	-- LKW-Modelle (alle Modelle mit DriverSeat) ausschliessen
	for _, d in ipairs(Workspace:GetDescendants()) do
		if d:IsA("VehicleSeat") then
			local m = d:FindFirstAncestorWhichIsA("Model")
			if m then table.insert(ex, m) end
		end
	end
	if mode == "alt" then
		-- Ausgangslage wie vor dem Bau: die Haut gibt es fuer diese Strahlen nicht
		local fh = world() and world():FindFirstChild("FahrHaut")
		if fh then table.insert(ex, fh) end
	end
	rp.FilterDescendantsInstances = ex
	if mode ~= "alt" then
		rp.RespectCanCollide = true
		if PhysicsService:IsCollisionGroupRegistered(RS.GROUP_RAY) then rp.CollisionGroup = RS.GROUP_RAY end
	end
	return rp, ex
end

-- Fahrlinien: Mittellinie jedes Fahrbahn-Blocks entlang lokal Z (+1.5 Studs ueber die Enden) und NavData-Linien
local LINE_NAMES = { Road = true, Lane = true, Asphalt = true, RoadRamp = true, Deck = true, Track = true, Yard = true }
local function drivingLines(city, sample)
	local lines = {}
	for _, p in ipairs(RS.Collect(city)) do
		-- nur Fahrbahn-Laengsteile (keine Fugen-/Kreuzungsfueller), lokale Z-Achse = Fahrtrichtung, nicht viel breiter als lang
		if p:IsA("Part") and p.Shape == Enum.PartType.Block and LINE_NAMES[p.Name] and math.abs(p.CFrame.UpVector.Y) > 0.7
			and p.Size.X >= 6 and p.Size.Z >= 12 and p.Size.X <= 2 * p.Size.Z then
			if not sample or math.random() < sample then
				local cf = p.CFrame
				local top = cf.Position + cf.UpVector * (p.Size.Y / 2) * math.sign(cf.UpVector.Y)
				local d = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
				if d.Magnitude > 0.5 then
					d = d.Unit
					local half = p.Size.Z / 2 + 1.5
					local pts = {}
					for t = -half, half, 0.5 do table.insert(pts, top + d * t) end
					table.insert(lines, { pts = pts, src = p })
				end
			end
		end
	end
	local ok, nav = pcall(function()
		local m = ReplicatedStorage.Modules.NavData:Clone()
		local t = require(m)
		m:Destroy()
		return t
	end)
	if ok and type(nav) == "table" then
		for _, r in ipairs(nav) do
			if r.Name == city then
				for _, l in ipairs(r.Lines or {}) do
					if not sample or math.random() < sample then
						local P = l.P
						local pts = {}
						for k = 1, #P // 3 - 1 do
							local a = Vector3.new(P[3 * k - 2], P[3 * k - 1], P[3 * k])
							local b = Vector3.new(P[3 * k + 1], P[3 * k + 2], P[3 * k + 3])
							local L = (Vector3.new(b.X, 0, b.Z) - Vector3.new(a.X, 0, a.Z)).Magnitude
							local n = math.max(1, math.floor(L / 0.5))
							for s = 0, n - 1 do table.insert(pts, a:Lerp(b, s / n)) end
						end
						if #pts > 4 then table.insert(lines, { pts = pts, nav = true }) end
					end
				end
			end
		end
	end
	return lines
end

-- LKW-genaues Audit. opts: { Mode = "neu"|"alt", Vehicle = "Van"|"Titan", Sample = 0..1 (Anteil der Linien), Max = Spots }
function RS.Audit(city, opts)
	opts = opts or {}
	local mode = opts.Mode or "neu"
	local veh = RS.VEHICLES[opts.Vehicle or "Van"]
	local rp, ex = rayParams(mode)
	local skin = skinFolder(city, false)
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Exclude
	local opEx = table.clone(ex)
	if skin then table.insert(opEx, skin) end
	op.FilterDescendantsInstances = opEx
	op.RespectCanCollide = true
	setStep("Audit: Linien", 0)
	local lines = drivingLines(city, opts.Sample)
	local corners = { { -veh.cx, veh.zf }, { veh.cx, veh.zf }, { -veh.cx, veh.zr }, { veh.cx, veh.zr } }
	local clearance = veh.ride - veh.height / 2
	local spots = {}
	local cnt = { samples = 0, sprung15 = 0, sprung40 = 0, sprung100 = 0, neigung = 0, loch = 0, aufsetzen = 0, anstoss = 0 }
	local function addSpot(kind, pos, mag, hit)
		table.insert(spots, { t = kind, x = math.floor(pos.X * 10) / 10, y = math.floor(pos.Y * 10) / 10, z = math.floor(pos.Z * 10) / 10, m = math.floor(mag * 100) / 100, h = hit })
	end
	local function cast(origin)
		local r = Workspace:Raycast(origin, Vector3.new(0, -40, 0), rp)
		return r
	end
	for li, L in ipairs(lines) do
		local pts = L.pts
		local seq, pit, rol = {}, {}, {}
		local hitName = {}
		local groundPrev = nil
		for i, pos in ipairs(pts) do
			local nxt = pts[math.min(#pts, i + 1)]
			local prv = pts[math.max(1, i - 1)]
			local d = Vector3.new(nxt.X - prv.X, 0, nxt.Z - prv.Z)
			if d.Magnitude < 1e-3 then d = Vector3.new(0, 0, -1) end
			d = d.Unit
			local side = Vector3.new(-d.Z, 0, d.X)
			local base = (groundPrev or pos.Y)
			local oy = base + veh.ride + 6
			local hs, n, maxHit = {}, 0, -math.huge
			local hn = nil
			for ci, c in ipairs(corners) do
				local wp = Vector3.new(pos.X, oy, pos.Z) + side * c[1] + d * (-c[2])
				local r = cast(wp)
				if r then
					hs[ci] = r.Position.Y
					n += 1
					if r.Position.Y > maxHit then maxHit = r.Position.Y; hn = r.Instance end
				end
			end
			cnt.samples += 1
			if n >= 3 then
				local s, c = 0, 0
				for ci = 1, 4 do if hs[ci] then s += hs[ci]; c += 1 end end
				local avg = s / c
				for ci = 1, 4 do hs[ci] = hs[ci] or avg end
				seq[i] = avg
				pit[i] = math.deg(math.atan2((hs[1] + hs[2]) / 2 - (hs[3] + hs[4]) / 2, veh.zr - veh.zf))
				rol[i] = math.deg(math.atan2((hs[2] + hs[4]) / 2 - (hs[1] + hs[3]) / 2, 2 * veh.cx))
				hitName[i] = hn and hn.Name or "?"
				groundPrev = avg
				-- Fahrzeug-Ebene aus den 4 Treffern (Steigung nach vorne / zur Seite) - der Kasten kippt mit
				local zmid = (-veh.zf - veh.zr) / 2
				local sF = ((hs[1] + hs[2]) / 2 - (hs[3] + hs[4]) / 2) / (veh.zr - veh.zf) -- Anstieg je Stud in Richtung d
				local sS = ((hs[2] + hs[4]) / 2 - (hs[1] + hs[3]) / 2) / (2 * veh.cx) -- Anstieg je Stud zur Seite
				local function bottomAt(fz, fx) return avg + clearance + sF * (fz - zmid) + sS * fx end
				-- Aufsetzen: Boden unter dem (geneigten) Kasten hoeher als seine Unterkante
				local oy2 = oy + math.abs(sF) * veh.halfL + math.abs(sS) * veh.halfW
				for _, fz in ipairs({ -veh.halfL + 0.3, 0, veh.halfL - 0.3 }) do
					local found = false
					for _, fx in ipairs({ -veh.halfW + 0.3, 0, veh.halfW - 0.3 }) do
						local r = cast(Vector3.new(pos.X, oy2, pos.Z) + side * fx + d * fz)
						local b = bottomAt(fz, fx)
						if r and r.Position.Y > b - 0.05 then
							cnt.aufsetzen += 1
							addSpot("aufsetzen", r.Position, r.Position.Y - b, r.Instance:GetFullName())
							found = true
							break
						end
					end
					if found then break end
				end
				-- Anstossen: etwas Kollidierbares im (geneigten) Kasten-Volumen
				if i % 4 == 0 then
					local fwd = (d + Vector3.yAxis * sF).Unit
					local right0 = (side + Vector3.yAxis * sS).Unit
					local up = right0:Cross(fwd).Unit
					if up.Y < 0 then up = -up end
					local right = fwd:Cross(up).Unit
					local c = Vector3.new(pos.X, avg + clearance - sF * zmid, pos.Z) + up * (veh.height / 2)
					local cf = CFrame.fromMatrix(c, right, up, -fwd)
					local hitParts = Workspace:GetPartBoundsInBox(cf, Vector3.new(veh.halfW * 2 - 0.2, veh.height - 0.2, veh.halfL * 2 - 0.2), op)
					for _, hp in ipairs(hitParts) do
						if hp.CollisionGroup ~= RS.GROUP_SKIN and not (skin and hp:IsDescendantOf(skin)) then
							cnt.anstoss += 1
							addSpot("anstoss", pos, 0, hp:GetFullName())
							break
						end
					end
				end
			else
				seq[i] = false
				cnt.loch += 1
				if not (seq[i - 1] == false) then addSpot("loch", pos, 0, "") end
			end
			if i % 50 == 0 then yield() end
		end
		-- Spruenge (Hoehe) und Neigungs-Rucke
		local s2 = {}
		for i = 1, #pts do s2[i] = seq[i] or nil end
		for _, j in ipairs(Core.Jumps(s2, 0.15, #pts)) do
			local a = math.abs(j.j)
			cnt.sprung15 += 1
			if a > 0.4 then cnt.sprung40 += 1 end
			if a > 1.0 then cnt.sprung100 += 1 end
			if a > 0.4 then addSpot("sprung", pts[j.i], j.j, hitName[j.i] or "?") end
		end
		for i = 2, #pts do
			if pit[i] and pit[i - 1] and (math.abs(pit[i] - pit[i - 1]) > 2 or math.abs((rol[i] or 0) - (rol[i - 1] or 0)) > 2) then
				cnt.neigung += 1
			end
		end
		status.Progress = li / #lines
	end
	-- Spots zusammenfassen (je 6 Studs nur der staerkste je Art)
	local cell = {}
	local merged = {}
	table.sort(spots, function(a, b) return math.abs(a.m) > math.abs(b.m) end)
	for _, s in ipairs(spots) do
		local key = s.t .. ":" .. math.floor(s.x / 6) .. ":" .. math.floor(s.z / 6)
		if not cell[key] then
			cell[key] = true
			table.insert(merged, s)
		end
	end
	local rank = { anstoss = 1, aufsetzen = 2, loch = 3, sprung = 4 }
	table.sort(merged, function(a, b)
		if rank[a.t] ~= rank[b.t] then return rank[a.t] < rank[b.t] end
		return math.abs(a.m) > math.abs(b.m)
	end)
	local max = opts.Max or 1500
	while #merged > max do table.remove(merged) end
	local res = { City = city, Mode = mode, Vehicle = opts.Vehicle or "Van", Lines = #lines, Counts = cnt, Spots = merged, At = os.date("%Y-%m-%d %H:%M") }
	local rep = folder(ServerStorage, "RoadSmoothReport")
	local name = string.format("%s_Audit_%s", city, mode)
	local sv = rep:FindFirstChild(name) or Instance.new("StringValue")
	sv.Name = name
	sv.Value = string.sub(HttpService:JSONEncode(res), 1, 190000)
	sv.Parent = rep
	RS.LastAudit = res
	setStep("fertig", 1)
	return RS.AuditText(res)
end

function RS.AuditText(res)
	local c = res.Counts
	local per = 1000 / math.max(1, c.samples)
	local byType = {}
	for _, s in ipairs(res.Spots) do byType[s.t] = (byType[s.t] or 0) + 1 end
	return string.format(
		"%s [%s, %s] %d Linien, %d Messpunkte | Spruenge >0.15: %d (%.1f/1000)  >0.4: %d  >1: %d | Neigungsrucke >2°: %d | Loecher: %d | Aufsetzen: %d | Anstossen: %d | Stellen: anstoss %d, aufsetzen %d, loch %d, sprung %d",
		res.City, res.Mode, res.Vehicle, res.Lines, c.samples, c.sprung15, c.sprung15 * per, c.sprung40, c.sprung100, c.neigung,
		c.loch, c.aufsetzen, c.anstoss, byType.anstoss or 0, byType.aufsetzen or 0, byType.loch or 0, byType.sprung or 0)
end

-- die schlimmsten Stellen als Text
function RS.Spots(n, typ)
	local res = RS.LastAudit
	if not res then return "erst RS.Audit(stadt) ausfuehren" end
	local out = {}
	for i, s in ipairs(res.Spots) do
		if not typ or s.t == typ then
			table.insert(out, string.format("%d. %s %.2f bei (%.0f, %.1f, %.0f) %s", i, s.t, s.m, s.x, s.y, s.z, s.h or ""))
			if #out >= (n or 20) then break end
		end
	end
	return table.concat(out, "\n")
end

-- Kamera auf eine Stelle richten (fuer Screenshots), i = Index in RS.LastAudit.Spots
function RS.Look(i, dist)
	local s = RS.LastAudit and RS.LastAudit.Spots[i]
	assert(s, "Stelle nicht gefunden")
	dist = dist or 28
	local target = Vector3.new(s.x, s.y, s.z)
	local cam = Workspace.CurrentCamera
	cam.CFrame = CFrame.lookAt(target + Vector3.new(dist * 0.7, dist * 0.6, dist * 0.7), target)
	return string.format("Kamera auf %s (%.0f, %.1f, %.0f)", s.t, s.x, s.y, s.z)
end

----------------------------------------------------------------------------------------------- Gelaende
-- Oberseite eines Blocks: CFrame (UpVector = Normale nach oben, Mitte der Oberseite) und die beiden Kantenlaengen
local function topOf(p)
	local cf, s = p.CFrame, p.Size
	local axes = { { cf.RightVector, s.X }, { cf.UpVector, s.Y }, { cf.LookVector, s.Z } }
	local bi, bv = 1, -1
	for i, a in ipairs(axes) do
		if math.abs(a[1].Y) > bv then bi, bv = i, math.abs(a[1].Y) end
	end
	local n = axes[bi][1] * math.sign(axes[bi][1].Y)
	local center = cf.Position + n * axes[bi][2] / 2
	local u = axes[(bi % 3) + 1]
	local v = axes[((bi + 1) % 3) + 1]
	local vx = u[1]
	local vz = vx:Cross(n)
	return CFrame.fromMatrix(center, vx, n, vz), u[2], v[2]
end
RS.TopOf = topOf

-- Gelaende, das durch die Haut ragt, absenken (FillBlock Luft knapp ueber der Fahrbahn). opts: { Dry = true, Inset = 1 }
function RS.CarveTerrain(city, opts)
	opts = opts or {}
	local inset = opts.Inset or 1
	local skin = skinFolder(city, false)
	assert(skin, "erst RS.Build(" .. city .. ")")
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { Workspace.Terrain }
	local terrain = Workspace.Terrain
	local backups = folder(folder(ServerStorage, "Backups"), "RoadSmoothTerrain_" .. city)
	local pieces = skin:GetChildren()
	local hits, carved, failed = 0, 0, 0
	local carvedPieces = {}
	local seq = #backups:GetChildren()
	for i, p in ipairs(pieces) do
		if p:IsA("Part") and p.Shape == Enum.PartType.Block then
			local topCF, e1, e2 = topOf(p)
			local poke = false
			local ex, ez = e1 / 2 - inset, e2 / 2 - inset
			if ex > 0.2 and ez > 0.2 then
				for _, o in ipairs({ { 0, 0 }, { 0.8, 0.8 }, { -0.8, 0.8 }, { 0.8, -0.8 }, { -0.8, -0.8 } }) do
					local wp = (topCF * CFrame.new(o[1] * ex, 0, o[2] * ez)).Position
					local r = Workspace:Raycast(wp + Vector3.new(0, 6, 0), Vector3.new(0, -6.05, 0), rp)
					if r then poke = true break end
				end
			end
			if poke then
				hits += 1
				if not opts.Dry then
					local cf = topCF * CFrame.new(0, 3.02, 0)
					local sz = Vector3.new(math.max(0.5, e1 - 2 * inset), 6, math.max(0.5, e2 - 2 * inset))
					-- Weltbox des abzutragenden Blocks (+1 Voxel) sichern
					local R, U, L = cf.RightVector, cf.UpVector, cf.LookVector
					local hh = sz / 2
					local ext = Vector3.new(
						math.abs(R.X) * hh.X + math.abs(U.X) * hh.Y + math.abs(L.X) * hh.Z,
						math.abs(R.Y) * hh.X + math.abs(U.Y) * hh.Y + math.abs(L.Y) * hh.Z,
						math.abs(R.Z) * hh.X + math.abs(U.Z) * hh.Y + math.abs(L.Z) * hh.Z)
					local a, b = cf.Position - ext, cf.Position + ext
					local lo = Vector3int16.new(math.floor(a.X / 4) - 1, math.floor(a.Y / 4) - 1, math.floor(a.Z / 4) - 1)
					local hi = Vector3int16.new(math.ceil(b.X / 4) + 1, math.ceil(b.Y / 4) + 1, math.ceil(b.Z / 4) + 1)
					local ok, region = pcall(function() return terrain:CopyRegion(Region3int16.new(lo, hi)) end)
					if ok and region then
						seq += 1
						region.Name = string.format("R%06d", seq)
						region:SetAttribute("Seq", seq)
						region:SetAttribute("CornerX", lo.X)
						region:SetAttribute("CornerY", lo.Y)
						region:SetAttribute("CornerZ", lo.Z)
						region.Parent = backups
						terrain:FillBlock(cf, sz, Enum.Material.Air) -- nur mit Sicherung
						carved += 1
						table.insert(carvedPieces, p)
					else
						failed += 1
						warn("RoadSmooth: Gelaende-Sicherung fehlgeschlagen, nicht abgesenkt bei " .. tostring(cf.Position))
					end
				end
			end
		end
		if i % 100 == 0 then yield(i / #pieces) end
	end
	-- Kontrolle: ragt nach dem Absenken noch Gelaende durch? (FillBlock wirkt auf 4-Stud-Voxel nur anteilig)
	local still = 0
	for _, p in ipairs(carvedPieces) do
		local topCF, e1, e2 = topOf(p)
		local ex, ez = e1 / 2 - inset, e2 / 2 - inset
		for _, o in ipairs({ { 0, 0 }, { 0.8, 0.8 }, { -0.8, -0.8 } }) do
			local wp = (topCF * CFrame.new(o[1] * ex, 0, o[2] * ez)).Position
			if Workspace:Raycast(wp + Vector3.new(0, 6, 0), Vector3.new(0, -6.05, 0), rp) then still += 1 break end
		end
	end
	setStep("fertig", 1)
	return string.format("%s: Gelaende ragt an %d Hautplatten durch, %s", city, hits, opts.Dry and "(Probe, nichts geaendert)"
		or string.format("%d abgesenkt, %d ohne Sicherung uebersprungen, danach ragt noch an %d durch. Sicherung: ServerStorage.Backups.RoadSmoothTerrain_%s", carved, failed, still, city))
end

function RS.RestoreTerrain(city)
	local b = ServerStorage:FindFirstChild("Backups")
	local f = b and b:FindFirstChild("RoadSmoothTerrain_" .. city)
	assert(f, "keine Gelaende-Sicherung fuer " .. city)
	local list = f:GetChildren()
	-- neueste zuerst, damit die aeltesten (urspruenglichen) Daten zuletzt geschrieben werden
	table.sort(list, function(x, y) return (x:GetAttribute("Seq") or 0) > (y:GetAttribute("Seq") or 0) end)
	for i, r in ipairs(list) do
		Workspace.Terrain:PasteRegion(r, Vector3int16.new(r:GetAttribute("CornerX"), r:GetAttribute("CornerY"), r:GetAttribute("CornerZ")), true)
		if i % 50 == 0 then yield() end
	end
	f:Destroy()
	return string.format("%s: %d Gelaende-Bereiche zurueckgeschrieben (Sicherung verbraucht)", city, #list)
end

----------------------------------------------------------------------------------------------- Testfahrt (Play-Modus, Server)
-- Autopilot: setzt die Studio-Testattribute des Sitzes. opts: { Player, City, Lines = Anzahl, Speed = 0..1, Points = {Vector3} }
function RS.DriveTest(opts)
	assert(RunService:IsRunning() and RunService:IsServer(), "nur im Play-Modus auf dem Server")
	opts = opts or {}
	local pl = opts.Player or Players:GetPlayers()[1]
	assert(pl and pl.Character, "kein Spieler mit Figur")
	local hum = pl.Character:FindFirstChildOfClass("Humanoid")
	local seat, model
	for _, d in ipairs(Workspace:GetDescendants()) do
		if d:IsA("VehicleSeat") then
			local m = d:FindFirstAncestorWhichIsA("Model")
			if m and m:GetAttribute("OwnerId") == pl.UserId then seat, model = d, m break end
		end
	end
	assert(seat and model, "kein eigener LKW gefunden")
	local root = model.PrimaryPart
	-- Routen
	local routes = {}
	if opts.Points then
		routes = { opts.Points }
	else
		local m = ReplicatedStorage.Modules.NavData:Clone()
		local nav = require(m)
		m:Destroy()
		local city = opts.City or cityOfX(root.Position.X)
		for _, r in ipairs(nav) do
			if r.Name == city then
				local lines = r.Lines
				local want = opts.Lines or 5
				for _ = 1, want do
					local l = lines[math.random(1, #lines)]
					local P = l.P
					local pts = {}
					for k = 1, #P // 3 do table.insert(pts, Vector3.new(P[3 * k - 2], P[3 * k - 1], P[3 * k])) end
					if math.random() < 0.5 then
						local rev = {}
						for i = #pts, 1, -1 do table.insert(rev, pts[i]) end
						pts = rev
					end
					if #pts >= 3 then table.insert(routes, pts) end
				end
			end
		end
	end
	local result = { Routes = #routes, Bumps = 0, HardBumps = 0, Airborne = 0, Stuck = 0, MaxVAcc = 0, Spots = {} }
	local function clearTest()
		pcall(function()
			seat:SetAttribute("TestThrottle", nil)
			seat:SetAttribute("TestSteer", nil)
			root.Anchored = false
		end)
	end
	local okAll, errAll = pcall(function()
		for ri, pts in ipairs(routes) do
			if #pts < 2 then continue end
			-- Start: Umgebung streamen, LKW an den Routenanfang setzen, Blick zum zweiten Punkt
			local a, b = pts[1], pts[2]
			pcall(function() pl:RequestStreamAroundAsync(a, 10) end)
			root.Anchored = true
			model:PivotTo(CFrame.lookAt(a + Vector3.new(0, 1.5, 0), Vector3.new(b.X, a.Y + 1.5, b.Z)))
			task.wait(0.5)
			root.Anchored = false
			if seat.Occupant ~= hum then seat:Sit(hum) end
			task.wait(1.0)
			pcall(function() root:SetNetworkOwner(pl) end)
			local settleUntil = os.clock() + 1.5 -- Landung nach dem Versetzen nicht als Stoss werten
			local idx, slow = 2, 0
			local lastV, lastT = root.AssemblyLinearVelocity, os.clock()
			local t0 = os.clock()
			while idx <= #pts and os.clock() - t0 < 120 do
				local pos = root.Position
				local tgt = pts[idx]
				local to = Vector3.new(tgt.X - pos.X, 0, tgt.Z - pos.Z)
				local look = root.CFrame.LookVector
				local fwd = Vector3.new(look.X, 0, look.Z)
				fwd = (fwd.Magnitude > 1e-3) and fwd.Unit or Vector3.new(0, 0, -1)
				local dist = to.Magnitude
				local behind = dist > 1e-3 and fwd:Dot(to.Unit) < -0.2
				if dist < 8 or (behind and dist < 25 and idx < #pts) then
					idx += 1 -- erreicht oder schon vorbei: naechster Punkt
				else
					local u = to.Unit
					local ang = math.atan2(fwd:Cross(u).Y, fwd:Dot(u))
					seat:SetAttribute("TestSteer", math.clamp(-ang * 2.5, -1, 1))
					local v0 = root.AssemblyLinearVelocity
					local hv0 = Vector3.new(v0.X, 0, v0.Z).Magnitude
					local thr = opts.Speed or 1
					if math.abs(ang) > 0.35 then thr = (hv0 > 18) and -0.6 or 0.35 end -- in Kurven bremsen
					seat:SetAttribute("TestThrottle", thr)
				end
				task.wait(1 / 30)
				local now = os.clock()
				local v = root.AssemblyLinearVelocity
				if now < settleUntil then
					lastV, lastT = v, now
				elseif now - lastT >= 0.1 then
					local ay = (v.Y - lastV.Y) / (now - lastT)
					local airborne = math.abs(ay + Workspace.Gravity) < 30
					if airborne then
						result.Airborne += 1
					else
						if math.abs(ay) > math.abs(result.MaxVAcc) then result.MaxVAcc = ay end
						if math.abs(ay) > 100 then
							result.Bumps += 1
							if math.abs(ay) > 300 then result.HardBumps += 1 end
							if #result.Spots < 200 then table.insert(result.Spots, { x = math.floor(pos.X), y = math.floor(pos.Y * 10) / 10, z = math.floor(pos.Z), a = math.floor(ay) }) end
						end
					end
					lastV, lastT = v, now
				end
				local hv = Vector3.new(v.X, 0, v.Z).Magnitude
				if hv < 3 and (seat:GetAttribute("TestThrottle") or 0) > 0.2 and now > settleUntil + 1 then
					slow += 1 / 30
					if slow > 1.5 then
						result.Stuck += 1
						table.insert(result.Spots, { x = math.floor(pos.X), y = math.floor(pos.Y * 10) / 10, z = math.floor(pos.Z), a = 0, stuck = true })
						idx += 1
						slow = 0
					end
				else
					slow = 0
				end
			end
			seat:SetAttribute("TestThrottle", 0)
			seat:SetAttribute("TestSteer", 0)
			task.wait(0.5)
			status.Progress = ri / #routes
		end
	end)
	clearTest()
	if not okAll then error(errAll) end
	RS.LastDrive = result
	return string.format("Testfahrt: %d Routen | Stoesse >100: %d, >300: %d, max %.0f studs/s² | haengengeblieben: %d", result.Routes, result.Bumps, result.HardBumps, result.MaxVAcc, result.Stuck)
end

----------------------------------------------------------------------------------------------- Meshes (Optik)
-- Importierte OBJ-Meshes (Datei > 3D importieren) an ihre Weltbox setzen. Daten: script.MeshData
local function meshData()
	local m = script:FindFirstChild("MeshData")
	assert(m, "MeshData fehlt")
	local c = m:Clone()
	c.Parent = m.Parent
	local d = require(c)
	c:Destroy()
	return d
end

-- 24 Achsdrehungen
local ROTS = {}
do
	local perms = { { 1, 2, 3 }, { 1, 3, 2 }, { 2, 1, 3 }, { 2, 3, 1 }, { 3, 1, 2 }, { 3, 2, 1 } }
	for _, pm in ipairs(perms) do
		for _, sx in ipairs({ -1, 1 }) do
			for _, sy in ipairs({ -1, 1 }) do
				for _, sz in ipairs({ -1, 1 }) do
					local m = { { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 } }
					local sg = { sx, sy, sz }
					for r = 1, 3 do m[r][pm[r]] = sg[r] end
					local det = m[1][1] * (m[2][2] * m[3][3] - m[2][3] * m[3][2]) - m[1][2] * (m[2][1] * m[3][3] - m[2][3] * m[3][1])
						+ m[1][3] * (m[2][1] * m[3][2] - m[2][2] * m[3][1])
					if det > 0 then table.insert(ROTS, m) end
				end
			end
		end
	end
end
local function rmul(m, v)
	return Vector3.new(m[1][1] * v.X + m[1][2] * v.Y + m[1][3] * v.Z, m[2][1] * v.X + m[2][2] * v.Y + m[2][3] * v.Z, m[3][1] * v.X + m[3][2] * v.Y + m[3][3] * v.Z)
end
local function rcf(m)
	return CFrame.new(0, 0, 0, m[1][1], m[1][2], m[1][3], m[2][1], m[2][2], m[2][3], m[3][1], m[3][2], m[3][3])
end

function RS.FindImported(city)
	local D = meshData()[city]
	assert(D, "keine Mesh-Daten fuer " .. city)
	local want = {}
	for _, o in ipairs(D.objs) do want[o.name] = o end
	local W = world()
	local placed = W:FindFirstChild("StrassenMesh2")
	local found = {}
	for _, d in ipairs(Workspace:GetDescendants()) do
		if d:IsA("MeshPart") and want[d.Name] and not (placed and d:IsDescendantOf(placed)) then
			found[d.Name] = found[d.Name] or {}
			table.insert(found[d.Name], d)
		end
	end
	return found, D
end

function RS.MeshStatus()
	local out = {}
	for _, city in ipairs(RS.CITIES) do
		local ok, found, D = pcall(RS.FindImported, city)
		if ok then
			local n = 0
			for _ in pairs(found) do n += 1 end
			local root = world():FindFirstChild("StrassenMesh2")
			local m = root and root:FindFirstChild(city)
			table.insert(out, string.format("%s: %d/%d importiert, %d platziert", city, n, #D.objs, m and #m:GetChildren() or 0))
		end
	end
	return table.concat(out, "\n")
end

-- Meshes platzieren; alte Meshes (StrassenMesh) ins Archiv; alte sichtbare Fahrbahnteile ausblenden
function RS.PlaceMeshes(city)
	local found, D = RS.FindImported(city)
	local list, pp = {}, {}
	for _, o in ipairs(D.objs) do
		local arr = found[o.name]
		if arr then
			local c = Vector3.new((o.min[1] + o.max[1]) / 2, (o.min[2] + o.max[2]) / 2, (o.min[3] + o.max[3]) / 2)
			local ext = Vector3.new(o.max[1] - o.min[1], o.max[2] - o.min[2], o.max[3] - o.min[3])
			table.insert(list, { o = o, mp = arr[1], c = c, ext = ext })
			table.insert(pp, { c = c, p = arr[1].Position, ext = ext, size = arr[1].Size })
		end
	end
	if #list == 0 then return city .. ": keine importierten Meshes gefunden (Datei > 3D importieren)" end
	-- Importer-Transformation schaetzen (Drehung aus 24 + Massstab) aus den Mittelpunkten
	local best
	if #pp >= 3 then
		local pm = Vector3.zero
		for _, e in ipairs(pp) do pm += e.p end
		pm /= #pp
		for _, R in ipairs(ROTS) do
			local qs, qm = {}, Vector3.zero
			for i, e in ipairs(pp) do qs[i] = rmul(R, e.c); qm += qs[i] end
			qm /= #pp
			local num, den = 0, 0
			for i, e in ipairs(pp) do
				local a = qs[i] - qm
				num += a:Dot(e.p - pm)
				den += a:Dot(a)
			end
			local s = den > 0 and num / den or 1
			if s > 0 then
				local t = pm - qm * s
				local err = 0
				for i, e in ipairs(pp) do err += ((qs[i] * s + t) - e.p).Magnitude ^ 2 end
				if not best or err < best.err then best = { R = R, s = s, err = math.sqrt(err / #pp) } end
			end
		end
	end
	if not best then
		best = { R = { { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 } }, s = list[1].mp.Size.X / list[1].ext.X, err = -1 }
	end
	local Rinv = rcf(best.R):Inverse()
	local W = world()
	local root = folder(W, "StrassenMesh2")
	local m = root:FindFirstChild(city)
	if not m then
		m = Instance.new("Model")
		m.Name = city
		m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		m.Parent = root
	end
	local report = { string.format("%s: %d Meshes, Massstab %.4f, Restfehler %.3f", city, #list, best.s, best.err) }
	for _, e in ipairs(list) do
		local mp = e.mp
		local oldParent = mp.Parent
		mp.Anchored = true
		mp.Size = mp.Size / best.s
		mp.CFrame = CFrame.new(e.c) * (Rinv * mp.CFrame.Rotation)
		local look = D.look[e.o.cls] or D.look.A
		mp.Material = Enum.Material[look[1]]
		mp.Color = Color3.fromHex(look[2])
		mp.CanCollide = false
		mp.CanQuery = false
		mp.CanTouch = false
		mp.CastShadow = false
		pcall(function() mp.AudioCanCollide = false end)
		pcall(function() mp.RenderFidelity = Enum.RenderFidelity.Precise end)
		pcall(function() mp.CollisionFidelity = Enum.CollisionFidelity.Box end)
		pcall(function() mp.DoubleSided = false end)
		for _, ch in ipairs(mp:GetChildren()) do
			if ch:IsA("SurfaceAppearance") or ch:IsA("Decal") or ch:IsA("Texture") then ch:Destroy() end
		end
		mp:SetAttribute("RoadSmoothMesh", true)
		local prev = m:FindFirstChild(e.o.name)
		if prev and prev ~= mp then prev:Destroy() end
		mp.Parent = m
		-- leere Import-Huellen entfernen
		while oldParent and oldParent ~= Workspace and oldParent ~= m and (oldParent:IsA("Model") or oldParent:IsA("Folder")) and #oldParent:GetChildren() == 0 do
			local up = oldParent.Parent
			oldParent:Destroy()
			oldParent = up
		end
		-- Box pruefen
		local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = mp.CFrame:GetComponents()
		local sz = mp.Size
		local we = Vector3.new(math.abs(r00) * sz.X + math.abs(r01) * sz.Y + math.abs(r02) * sz.Z, math.abs(r10) * sz.X + math.abs(r11) * sz.Y + math.abs(r12) * sz.Z, math.abs(r20) * sz.X + math.abs(r21) * sz.Y + math.abs(r22) * sz.Z)
		if (we - e.ext).Magnitude > 0.05 + 0.002 * e.ext.Magnitude then
			table.insert(report, string.format("  WARNUNG %s: Box %s statt %s", e.o.name, tostring(we), tostring(e.ext)))
		end
	end
	-- alle Meshes da? dann alte Optik umschalten
	local placed = {}
	for _, ch in ipairs(m:GetChildren()) do placed[ch.Name] = true end
	local all = true
	for _, o in ipairs(D.objs) do if not placed[o.name] then all = false end end
	if all then
		local old = W:FindFirstChild("StrassenMesh")
		local oldCity = old and old:FindFirstChild(city)
		if oldCity then
			local arch = folder(ServerStorage, "RoadSmoothMeshArchiv")
			local prev = arch:FindFirstChild(city)
			if prev then prev:Destroy() end
			oldCity.Parent = arch
			table.insert(report, "  alte StrassenMesh-Meshes ins Archiv (ServerStorage.RoadSmoothMeshArchiv)")
		end
		local hidden = 0
		local parts = RS.Collect(city)
		local under = RS.Under(parts)
		for _, p in ipairs(parts) do
			if not under[p] and p.Transparency < 1 and p:GetAttribute("RS_Transparency") == nil then
				p:SetAttribute("RS_Transparency", p.Transparency)
				p.Transparency = 1
				hidden += 1
			end
		end
		local nUnder = 0
		for _ in pairs(under) do nUnder += 1 end
		table.insert(report, string.format("  %d bisher sichtbare Fahrbahnteile ausgeblendet, %d Unterfuehrungs-Teile bleiben sichtbar", hidden, nUnder))
	else
		table.insert(report, "  noch nicht alle Meshes da - alte Optik bleibt vorerst")
	end
	return table.concat(report, "\n")
end

function RS.RestoreMeshes(city)
	local W = world()
	local root = W:FindFirstChild("StrassenMesh2")
	local m = root and root:FindFirstChild(city)
	if m then
		local arch = folder(ServerStorage, "RoadSmoothMeshArchiv")
		local keep = arch:FindFirstChild(city .. "_neu")
		if keep then keep:Destroy() end
		m.Name = city .. "_neu"
		m.Parent = arch
	end
	local arch = ServerStorage:FindFirstChild("RoadSmoothMeshArchiv")
	local old = arch and arch:FindFirstChild(city)
	if old then
		old.Parent = folder(W, "StrassenMesh")
	end
	local n = 0
	for _, p in ipairs(world():GetDescendants()) do
		if p:IsA("BasePart") and p:GetAttribute("RS_Transparency") ~= nil and cityOfX(p.Position.X) == city then
			p.Transparency = p:GetAttribute("RS_Transparency")
			p:SetAttribute("RS_Transparency", nil)
			n += 1
		end
	end
	return string.format("%s: neue Meshes ins Archiv, alte zurueck, %d Teile wieder sichtbar", city, n)
end

----------------------------------------------------------------------------------------------- Hintergrund-Jobs
-- RS.Run("Build", "Neustadt") / RS.Run("Audit", "Neustadt", {Mode="alt"}) ... dann RS.Status() abfragen
local generation = 0
function RS.Run(fname, ...)
	assert(type(RS[fname]) == "function", "unbekannte Funktion " .. tostring(fname))
	assert(status.Done, "es laeuft schon: " .. status.Job .. " (haengt er? RS.Reset())")
	local args = table.pack(...)
	generation += 1
	local gen = generation
	status.Job = fname .. "(" .. tostring(args[1] or "") .. ")"
	status.Done, status.Error, status.Result = false, nil, nil
	status.Step, status.Progress = "", 0
	status.Started = os.clock()
	task.spawn(function()
		local ok, res = xpcall(RS[fname], debug.traceback, table.unpack(args, 1, args.n))
		if gen ~= generation then return end -- inzwischen per RS.Reset() abgeloest
		status.Done = true
		if ok then status.Result = res else status.Error = tostring(res) end
	end)
	return "gestartet: " .. status.Job .. " - Fortschritt mit RS.Status()"
end

-- Notausgang, falls ein Job haengt (z. B. Play-Modus beendet): Status freigeben. Der alte Job wird ignoriert.
function RS.Reset()
	generation += 1
	local was = status.Job
	status.Done, status.Error, status.Result = true, nil, "zurueckgesetzt (vorher: " .. was .. ")"
	return "Status zurueckgesetzt (vorher: " .. was .. ")"
end

function RS.Status()
	local s = status
	if not s.Done then
		return string.format("laeuft: %s | %s %.0f%% | %.0fs", s.Job, s.Step, (s.Progress or 0) * 100, os.clock() - s.Started)
	end
	if s.Error then return "FEHLER in " .. s.Job .. ": " .. s.Error end
	return "fertig: " .. s.Job .. "\n" .. tostring(s.Result or "")
end

function RS.Help()
	return [[RoadSmooth ]] .. RS.VERSION .. [[ - nahtlose Strassen
  RS.Groups()                         Kollisionsgruppen anlegen
  RS.InstallTruck() / UninstallTruck()   neues Fahrwerk (Backup in ServerStorage.ScriptBackups)
  RS.Run("Audit", stadt, {Mode="alt"|"neu", Vehicle="Van"|"Titan", Sample=0.3})   LKW-genaues Audit
  RS.Run("Build", stadt) / RS.Restore(stadt)          Fahrhaut bauen / entfernen ({Dry=true} = Probe)
  RS.Run("CarveTerrain", stadt, {Dry=true})           Gelaende, das durch die Fahrbahn ragt / RS.RestoreTerrain(stadt)
  RS.Status()                         Fortschritt / Ergebnis des Hintergrund-Jobs
  RS.Spots(20, "anstoss"|"aufsetzen"|"loch"|"sprung")  schlimmste Stellen,  RS.Look(i) Kamera dorthin
  RS.Run("DriveTest", {Lines=5})      (nur Play-Modus, Server-Konsole) Autopilot-Testfahrt mit Stossmessung
  RS.MeshStatus() / RS.Run("PlaceMeshes", stadt) / RS.RestoreMeshes(stadt)   neue Strassen-Optik (OBJ-Import)
  RS.Reset()                          haengenden Job-Status freigeben
Staedte: Neustadt, Portavia, Metropolis]]
end

return RS
