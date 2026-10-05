-- 2D-Laengsschnitt: altes Fahrwerk-v2 (Stand v1) gegen neues (geneigter Kasten, FLOAT, MAX_LIFT)
local VEH = {
	Van = { zf = 5.4, zr = 5.2, ride = 5.08, halfH = 3.72, halfL = 8.5 },
	Titan = { zf = 17.6, zr = 19.2, ride = 7.88, halfH = 5.92, halfL = 23 },
}
local CLEAR, SAG, ALPHA, BETA, LA = 0.25, 0.6, 0.2, 0.03, 0.18
local MLA = 1.0
VAR = 0
MS = 0.25
local function run(newMode, V, prof)
	local clearance = V.ride - V.halfH
	local speed, dt = 50, 1 / 60
	local fy, fv = nil, 0
	local y, v = nil, 0
	local ux, uy = 0, 1 -- upF (x = vorwaerts)
	local worst, maxAcc, floatMax, n100, blocked = math.huge, 0, 0, 0, false
	local s = 0
	while s < 260 do
		local hf, hr = prof(s + V.zf), prof(s - V.zr)
		local raw = (hf + hr) / 2
		local cs = s + (V.zf - V.zr) / 2 -- Mittelpunkt der Ecken
		local slope = (hf - hr) / (V.zf + V.zr)
		local tx, ty = -slope, 1
		local m = math.sqrt(tx * tx + ty * ty); tx, ty = tx / m, ty / m
		local k = 1
		if fy == nil then fy, fv, y = raw, 0, raw + V.ride else
			local pred = fy + fv * dt
			local res = raw - pred
			fy = pred + ALPHA * k * res
			fv = fv + BETA * k * res / dt
		end
		local ahead = V.halfL + math.clamp(speed * LA, 1, 10)
		if not newMode then
			local maxHit = math.max(hf, hr, prof(s + ahead))
			local lb = math.max(raw - SAG, maxHit + CLEAR - clearance)
			if fy < lb then fy = lb; if fv < 0 then fv = 0 end end
			ux, uy = ux + (tx - ux) * (1 - math.exp(-10 * dt)), uy + (ty - uy) * (1 - math.exp(-10 * dt))
			local mm = math.sqrt(ux * ux + uy * uy); ux, uy = ux / mm, uy / mm
		else
			ux, uy = ux + (tx - ux) * (1 - math.exp(-10 * dt)), uy + (ty - uy) * (1 - math.exp(-10 * dt))
			local mm = math.sqrt(ux * ux + uy * uy); ux, uy = ux / mm, uy / mm
			if fy > raw + 0.6 then fy = raw + 0.6; if fv > 0 then fv = 0 end end
			local function need(hp, d) return hp + CLEAR + (V.halfH + ux * d) / math.max(uy, 0.6) - V.ride end
			local lb = raw - SAG
			lb = math.max(lb, need(hf, V.zf), need(hr, -V.zr))
			local function consider(hp, d) local nd = need(hp, d); if VAR == 0 then if nd - raw <= 1.0 then lb = math.max(lb, nd) end else lb = math.max(lb, math.min(nd, raw + 1.0)) end end
			consider(prof(s), 0)
			-- Vorausschau: Strahl von der verlaengerten Ebene + clearance + 2.5 nach unten (hoehere Stufe = nicht gesehen)
			local base = raw + slope * (ahead - (V.zf - V.zr) / 2)
			local hpA = prof(s + ahead)
			if VAR == 0 then
				if hpA <= base + clearance + MLA + 1.5 then local nd = need(hpA, V.halfL); if nd - raw <= MLA then lb = math.max(lb, nd) end end
			else
				-- an der eigenen Stelle, abzueglich Rampen-Toleranz ab der Stossstange; Anheben begrenzt (stetig)
				if hpA <= base + clearance + MLA + MS * (ahead - V.halfL) + 1.5 then
					local nd = need(hpA, ahead) - MS * (ahead - V.halfL)
					lb = math.max(lb, math.min(nd, raw + MLA))
				end
			end
			if fy < lb then fy = lb; if fv < 0 then fv = 0 end end
		end
		if s <= 30 then v = 0 end
		local vdes = math.clamp(25 * (fy + V.ride - y), -60, 60)
		local a = math.clamp((vdes - v) / dt, -596, 204)
		v += a * dt; y += v * dt
		if s > 30 then maxAcc = math.max(maxAcc, math.abs(a)); if math.abs(a) > 100 then n100 += 1 end end
		-- Kasten-Unterkante (geneigt) gegen den Boden unter dem Kasten
		if s > 30 then for d = -V.halfL, V.halfL, 0.5 do
			local bottom = y + (-V.halfH - ux * d) / uy
			local c = bottom - prof(s + d)
			if c < worst then worst = c end
		end end
		if s > 30 then floatMax = math.max(floatMax, (y - V.ride) - math.max(hf, hr)) end
		s += speed * dt
	end
	return worst, maxAcc, floatMax, n100
end
local T12 = math.tan(math.rad(12))
local profiles = {
	step03 = function(s) return s < 100 and 0 or 0.3 end,
	step12 = function(s) return s < 100 and 0 or 1.2 end,
	step20 = function(s) return s < 100 and 0 or 2.0 end,
	drop1 = function(s) return s < 100 and 1 or 0 end,
	ramp12 = function(s) if s < 60 then return 0 elseif s < 140 then return (s - 60) * T12 else return 80 * T12 end end,
	crest = function(s) if s < 60 then return 0 elseif s < 120 then return (s - 60) * T12 else return math.max(0, 60 * T12 - (s - 120) * T12) end end,
	valley = function(s) if s < 60 then return 0 elseif s < 120 then return -(s - 60) * T12 else return math.min(0, -60 * T12 + (s - 120) * T12) end end,
	seams = function(s) return ((math.floor(s / 6) % 2) == 0) and 0 or 0.12 end,
	wall5 = function(s) return (s > 120 and s < 121) and 5 or 0 end,
	crest6 = function(s) if s < 60 then return 0 elseif s < 120 then return (s - 60) * 0.105 else return math.max(0, 60 * 0.105 - (s - 120) * 0.105) end end,
	valley6 = function(s) if s < 60 then return 0 elseif s < 120 then return -(s - 60) * 0.105 else return math.min(0, -60 * 0.105 + (s - 120) * 0.105) end end,
}
for _, vn in ipairs({ "Van", "Titan" }) do
	for _, cfg in ipairs({ { false, 1, 0, 0 }, { true, 1.0, 1, 0.25 } }) do
		local mode = cfg[1]; MLA = cfg[2]; VAR = cfg[3]; MS = cfg[4]
		local line = string.format("%-5s %s %.1f v%d %.2f |", vn, mode and "neu" or "alt", MLA, VAR, MS)
		for _, name in ipairs({ "step03", "step12", "step20", "drop1", "ramp12", "crest", "valley", "crest6", "valley6", "seams", "wall5" }) do
			local c, a, f, n = run(mode, VEH[vn], profiles[name])
			line ..= string.format(" %s clr %.2f acc %.0f fl %.2f n %d |", name, c, a, f, n)
		end
		print(line)
	end
end
