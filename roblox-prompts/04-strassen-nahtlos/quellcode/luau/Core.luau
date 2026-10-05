--!native
-- RoadSmooth.Core: reine Rechenfunktionen (keine Roblox-Typen), damit sie ausserhalb von Studio testbar sind.
-- Teile werden als Tabellen beschrieben: { k = Form, x, y, z = Mitte, r = {R00..R22} (Zeilen wie CFrame:GetComponents),
-- sx, sy, sz = Groesse }.  Form k: 0 = Block, 1 = WedgePart, 2 = Zylinder (Achse lokal X), 3 = Kugel.
-- Welt = Mitte + R * lokal  (R in Zeilen: r[1] r[2] r[3] / r[4] r[5] r[6] / r[7] r[8] r[9]).
local Core = {}

Core.P = {
	G = 1, -- Rasterweite (Studs)
	SIGMA = 2, -- erste Glaettung (Studs)
	SIGMA2 = 1, -- zweite Glaettung (Studs)
	LO = 0.4, -- Haut darf hoechstens so weit unter der alten Fahrbahn liegen (grosse Stufen bleiben Rampen)
	TOL = 0.12, -- maximale Abweichung einer Hautplatte von der glatten Flaeche, sonst teilen
	MINPIECE = 3, -- kleinste Kantenlaenge beim Teilen (Studs)
	OVL = 0.25, -- Ueberlappung der Hautplatten (Studs je Seite)
	THICK = 0.4, -- Dicke der Hautplatten
	CLOSE = 2, -- Luecken bis 2*CLOSE Studs zwischen Fahrbahnteilen werden geschlossen
	GAPTOL = 0.08, -- Toleranz der Lueckenkacheln
	GAPMAX = 8, -- maximale Kantenlaenge einer Lueckenkachel (Studs)
	STEP = 1, -- Abtastweite auf Teil-Oberseiten
	UNDER = 3, -- Abtastpunkt gilt als verdeckt, wenn die Flaeche so viel hoeher liegt (Unterfuehrung)
	GAPSLOPE = 0.4, -- Luecken nur zwischen Fahrbahnen schliessen, deren Hoehe hoechstens so steil auseinanderliegt
}

local NEG = -1e30
local abs, floor, ceil, sqrt, max, min, exp = math.abs, math.floor, math.ceil, math.sqrt, math.max, math.min, math.exp

----------------------------------------------------------------------------------------------- Geometrie
-- Senkrechte Linie (x, z): y-Intervall [lo, hi] innerhalb des Teils oder nil
function Core.Interval(p, px, pz)
	local r = p.r
	local dx, dy, dz = px - p.x, -p.y, pz - p.z
	-- a = M^T * (dx, dy, dz),  b = M^T * (0, 1, 0)
	local a1 = r[1] * dx + r[4] * dy + r[7] * dz
	local a2 = r[2] * dx + r[5] * dy + r[8] * dz
	local a3 = r[3] * dx + r[6] * dy + r[9] * dz
	local b1, b2, b3 = r[4], r[5], r[6]
	local hx, hy, hz = p.sx / 2, p.sy / 2, p.sz / 2
	local lo, hi = -1e30, 1e30
	local k = p.k
	local function slab(a, b, h)
		if abs(b) < 1e-9 then
			if abs(a) > h then lo, hi = 1, -1 end
			return
		end
		local t1, t2 = (-h - a) / b, (h - a) / b
		if t1 > t2 then t1, t2 = t2, t1 end
		if t1 > lo then lo = t1 end
		if t2 < hi then hi = t2 end
	end
	local function half(na, nb, d) -- na + t*nb <= d
		if abs(nb) < 1e-9 then
			if na > d then lo, hi = 1, -1 end
			return
		end
		local t = (d - na) / nb
		if nb > 0 then
			if t < hi then hi = t end
		else
			if t > lo then lo = t end
		end
	end
	if k == 3 then
		local rr = min(p.sx, p.sy, p.sz) / 2
		local B = 2 * (a1 * b1 + a2 * b2 + a3 * b3)
		local C = a1 * a1 + a2 * a2 + a3 * a3 - rr * rr
		local disc = B * B - 4 * C
		if disc < 0 then return nil end
		local s = sqrt(disc)
		return (-B - s) / 2, (-B + s) / 2
	end
	slab(a1, b1, hx)
	if k == 2 then
		local rr = min(p.sy, p.sz) / 2
		local A = b2 * b2 + b3 * b3
		local B = 2 * (a2 * b2 + a3 * b3)
		local C = a2 * a2 + a3 * a3 - rr * rr
		if A < 1e-9 then
			if C > 0 then return nil end
		else
			local disc = B * B - 4 * A * C
			if disc < 0 then return nil end
			local s = sqrt(disc)
			local t1, t2 = (-B - s) / (2 * A), (-B + s) / (2 * A)
			if t1 > lo then lo = t1 end
			if t2 < hi then hi = t2 end
		end
	else
		half(-a2, -b2, hy) -- unten: y >= -hy
		if k == 1 then
			local q = p.sy / p.sz -- Schraege: y - q*z <= 0
			half(a2 - q * a3, b2 - q * b3, 0)
		else
			half(a2, b2, hy)
		end
		slab(a3, b3, hz)
	end
	if lo > hi then return nil end
	return lo, hi
end

-- halbe Ausdehnung des Teils in Weltachsen
function Core.Extents(p)
	local r = p.r
	local hx, hy, hz = p.sx / 2, p.sy / 2, p.sz / 2
	return abs(r[1]) * hx + abs(r[2]) * hy + abs(r[3]) * hz,
		abs(r[4]) * hx + abs(r[5]) * hy + abs(r[6]) * hz,
		abs(r[7]) * hx + abs(r[8]) * hy + abs(r[9]) * hz
end

-- Oberseite: lokale Normale (nx, ny, nz) und Art ("rect" | "tri" | "disc" | "slope")
function Core.TopFace(p)
	local r = p.r
	local function up(lx, ly, lz) return r[4] * lx + r[5] * ly + r[6] * lz end
	if p.k == 2 then
		if r[4] >= 0 then return 1, 0, 0, "disc" end
		return -1, 0, 0, "disc"
	end
	if p.k == 1 then
		local q = p.sy / p.sz
		local l = sqrt(1 + q * q)
		local cands = { { 1, 0, 0, "tri" }, { -1, 0, 0, "tri" }, { 0, -1, 0, "rect" }, { 0, 0, 1, "rect" }, { 0, 1 / l, -q / l, "slope" } }
		local best, bv = nil, -2
		for _, c in ipairs(cands) do
			local v = up(c[1], c[2], c[3])
			if v > bv then best, bv = c, v end
		end
		return best[1], best[2], best[3], best[4]
	end
	local best, bv = nil, -2
	for _, c in ipairs({ { 1, 0, 0 }, { -1, 0, 0 }, { 0, 1, 0 }, { 0, -1, 0 }, { 0, 0, 1 }, { 0, 0, -1 } }) do
		local v = up(c[1], c[2], c[3])
		if v > bv then best, bv = c, v end
	end
	return best[1], best[2], best[3], "rect"
end

local function lin(a, b, n) -- n+1 Werte von a bis b
	local t = {}
	for i = 0, n do t[i + 1] = a + (b - a) * i / n end
	return t
end

-- Abtastpunkte (lokal) auf der Oberseite eines Teils mit Groesse (sx, sy, sz)
function Core.FaceSamples(k, nx, ny, nz, ft, sx, sy, sz, step)
	step = step or Core.P.STEP
	local hx, hy, hz = sx / 2, sy / 2, sz / 2
	local pts = {}
	if ft == "disc" then
		local rr = min(sy, sz) / 2
		local n = max(2, ceil(rr / step))
		for _, a in ipairs(lin(-rr, rr, 2 * n)) do
			for _, b in ipairs(lin(-rr, rr, 2 * n)) do
				if a * a + b * b <= rr * rr + 1e-9 then table.insert(pts, { nx * hx, a, b }) end
			end
		end
	elseif ft == "tri" then
		for _, y in ipairs(lin(-hy, hy, max(2, ceil(sy / step)))) do
			for _, z in ipairs(lin(-hz, hz, max(2, ceil(sz / step)))) do
				if y <= -hy + sy * (z / sz + 0.5) + 1e-9 then table.insert(pts, { nx * hx, y, z }) end
			end
		end
	elseif ft == "slope" then
		for _, x in ipairs(lin(-hx, hx, max(2, ceil(sx / step)))) do
			for _, z in ipairs(lin(-hz, hz, max(2, ceil(sz / step)))) do
				table.insert(pts, { x, -hy + sy * (z / sz + 0.5), z })
			end
		end
	else
		local h = { hx, hy, hz }
		local s = { sx, sy, sz }
		local nl = { nx, ny, nz }
		local a = (abs(nx) > 0.5) and 1 or ((abs(ny) > 0.5) and 2 or 3)
		local u, v = (a == 1) and 2 or 1, (a == 3) and 2 or 3
		for _, x in ipairs(lin(-h[u], h[u], max(2, ceil(s[u] / step)))) do
			for _, y in ipairs(lin(-h[v], h[v], max(2, ceil(s[v] / step)))) do
				local q = { 0, 0, 0 }
				q[a] = nl[a] * h[a]
				q[u] = x
				q[v] = y
				table.insert(pts, q)
			end
		end
	end
	return pts
end

----------------------------------------------------------------------------------------------- Raster
-- Raster ueber [x0, x0 + nx*G) x [z0, z0 + nz*G)
function Core.NewGrid(x0, z0, x1, z1, G)
	G = G or Core.P.G
	local nx, nz = ceil((x1 - x0) / G), ceil((z1 - z0) / G)
	local n = nx * nz
	local g = { x0 = x0, z0 = z0, nx = nx, nz = nz, G = G, n = n }
	g.top = buffer.create(n * 4) -- f32 hoechste Fahrbahn-Oberkante
	g.own = buffer.create(n * 4) -- i32 Index des obersten Teils (+1), 0 = leer
	buffer.fill(g.own, 0, 0)
	for i = 0, n - 1 do buffer.writef32(g.top, i * 4, NEG) end
	return g
end

-- Teil (Index idx) in das Raster schreiben: Zelle = hoechste Oberkante
function Core.RasterPart(g, p, idx)
	local ex, _, ez = Core.Extents(p)
	local G = g.G
	local i0 = max(0, floor((p.x - ex - g.x0) / G))
	local i1 = min(g.nx - 1, floor((p.x + ex - g.x0) / G))
	local k0 = max(0, floor((p.z - ez - g.z0) / G))
	local k1 = min(g.nz - 1, floor((p.z + ez - g.z0) / G))
	local n = 0
	for i = i0, i1 do
		local x = g.x0 + (i + 0.5) * G
		for k = k0, k1 do
			local z = g.z0 + (k + 0.5) * G
			local lo, hi = Core.Interval(p, x, z)
			if lo then
				local o = (k * g.nx + i) * 4
				if hi > buffer.readf32(g.top, o) then
					buffer.writef32(g.top, o, hi)
					buffer.writei32(g.own, o, idx)
				end
				n += 1
			end
		end
	end
	return n
end

-- maskierte, separierbare Gauss-Glaettung. src/msk: f32 / u8 buffer, nur Zellen mit msk ~= 0 zaehlen.
-- out: f32 buffer (nur fuer msk ~= 0 gueltig). yieldFn(fortschritt) wird zwischendurch aufgerufen.
function Core.Blur(g, src, msk, sigma, yieldFn)
	local G = g.G
	local s = sigma / G
	local rad = max(1, ceil(3 * s))
	local w = {}
	local sum = 0
	for d = -rad, rad do
		local v = exp(-0.5 * (d / s) ^ 2)
		w[d + rad + 1] = v
		sum += v
	end
	for d = 1, #w do w[d] /= sum end
	local nx, nz, n = g.nx, g.nz, g.n
	local num = buffer.create(n * 4)
	local den = buffer.create(n * 4)
	-- Pass 1 entlang i (x)
	for k = 0, nz - 1 do
		local base = k * nx
		for i = 0, nx - 1 do
			local a, b = 0, 0
			for d = -rad, rad do
				local ii = i + d
				if ii >= 0 and ii < nx then
					local o = base + ii
					if buffer.readu8(msk, o) ~= 0 then
						local ww = w[d + rad + 1]
						a += ww * buffer.readf32(src, o * 4)
						b += ww
					end
				end
			end
			buffer.writef32(num, (base + i) * 4, a)
			buffer.writef32(den, (base + i) * 4, b)
		end
		if yieldFn and k % 64 == 0 then yieldFn(0.5 * k / nz) end
	end
	-- Pass 2 entlang k (z)
	local out = buffer.create(n * 4)
	for k = 0, nz - 1 do
		for i = 0, nx - 1 do
			local o = k * nx + i
			if buffer.readu8(msk, o) ~= 0 then
				local a, b = 0, 0
				for d = -rad, rad do
					local kk = k + d
					if kk >= 0 and kk < nz then
						local oo = kk * nx + i
						local ww = w[d + rad + 1]
						a += ww * buffer.readf32(num, oo * 4)
						b += ww * buffer.readf32(den, oo * 4)
					end
				end
				buffer.writef32(out, o * 4, (b > 1e-12) and (a / b) or buffer.readf32(src, o * 4))
			end
		end
		if yieldFn and k % 64 == 0 then yieldFn(0.5 + 0.5 * k / nz) end
	end
	return out
end

-- Maske aus dem Raster: 1 = Fahrbahn
function Core.Mask(g)
	local m = buffer.create(g.n)
	for o = 0, g.n - 1 do
		if buffer.readi32(g.own, o * 4) ~= 0 then buffer.writeu8(m, o, 1) end
	end
	return m
end

local function dilate(g, m, r, yf)
	local nx, nz = g.nx, g.nz
	local out = buffer.create(g.n)
	local offs = {}
	for di = -r, r do
		for dk = -r, r do
			if di * di + dk * dk <= r * r then table.insert(offs, { di, dk }) end
		end
	end
	for k = 0, nz - 1 do
		for i = 0, nx - 1 do
			if buffer.readu8(m, k * nx + i) ~= 0 then
				for _, d in ipairs(offs) do
					local ii, kk = i + d[1], k + d[2]
					if ii >= 0 and kk >= 0 and ii < nx and kk < nz then buffer.writeu8(out, kk * nx + ii, 1) end
				end
			end
		end
		if yf and k % 128 == 0 then yf() end
	end
	return out
end
local function invert(g, m)
	local out = buffer.create(g.n)
	for o = 0, g.n - 1 do buffer.writeu8(out, o, (buffer.readu8(m, o) == 0) and 1 or 0) end
	return out
end

-- Luecken schliessen (morphologisches Schliessen mit Radius r Zellen). Rueckgabe: Maske 1 = Fahrbahn, 2 = Luecke
function Core.CloseGaps(g, m, r, yf)
	if r <= 0 then return m end
	local d = dilate(g, m, r, yf)
	local e = invert(g, dilate(g, invert(g, d), r, yf))
	local out = buffer.create(g.n)
	for o = 0, g.n - 1 do
		local a = buffer.readu8(m, o)
		if a ~= 0 then
			buffer.writeu8(out, o, 1)
		elseif buffer.readu8(e, o) ~= 0 then
			buffer.writeu8(out, o, 2)
		end
	end
	return out
end

-- Glatte Flaeche: blur, nach unten auf (alt - LO) begrenzt, zweiter blur, nochmal begrenzt. Lueckenzellen werden interpoliert.
function Core.Smooth(g, yieldFn)
	local P = Core.P
	local m = Core.Mask(g)
	local f1 = Core.Blur(g, g.top, m, P.SIGMA, yieldFn and function(t) yieldFn(0.3 * t) end)
	for o = 0, g.n - 1 do
		if buffer.readu8(m, o) ~= 0 then
			local env = buffer.readf32(g.top, o * 4)
			if buffer.readf32(f1, o * 4) < env - P.LO then buffer.writef32(f1, o * 4, env - P.LO) end
		end
	end
	local f2 = Core.Blur(g, f1, m, P.SIGMA2, yieldFn and function(t) yieldFn(0.3 + 0.3 * t) end)
	for o = 0, g.n - 1 do
		if buffer.readu8(m, o) ~= 0 then
			local env = buffer.readf32(g.top, o * 4)
			if buffer.readf32(f2, o * 4) < env - P.LO then buffer.writef32(f2, o * 4, env - P.LO) end
		end
	end
	-- Luecken
	local mc = Core.CloseGaps(g, m, ceil(P.CLOSE / g.G), yieldFn and function() yieldFn(0.6) end)
	local nx, nz = g.nx, g.nz
	local rad = ceil(3 * P.SIGMA / g.G)
	local nGap = 0
	local maxd = 2 * ceil(P.CLOSE / g.G) + 1
	local function firstRoad(i, k, di, dk)
		for d = 1, maxd do
			local ii, kk = i + di * d, k + dk * d
			if ii < 0 or kk < 0 or ii >= nx or kk >= nz then return nil end
			local oo = kk * nx + ii
			if buffer.readu8(m, oo) ~= 0 then return d, buffer.readf32(f2, oo * 4) end
		end
		return nil
	end
	for k = 0, nz - 1 do
		for i = 0, nx - 1 do
			local o = k * nx + i
			if buffer.readu8(mc, o) == 2 then
				-- nur zwischen Fahrbahnen gleicher Ebene schliessen (keine Rampen zwischen Ebenen)
				local ok = true
				for _, dir in ipairs({ { 1, 0 }, { 0, 1 }, { 1, 1 }, { 1, -1 } }) do
					local d1, h1 = firstRoad(i, k, dir[1], dir[2])
					local d2, h2 = firstRoad(i, k, -dir[1], -dir[2])
					if d1 and d2 then
						local run = (d1 + d2) * g.G * ((dir[1] ~= 0 and dir[2] ~= 0) and 1.4142 or 1)
						if abs(h1 - h2) > P.GAPSLOPE * run + 0.3 then ok = false break end
					end
				end
				local a, b = 0, 0
				if ok then
					for kk = max(0, k - rad), min(nz - 1, k + rad) do
						for ii = max(0, i - rad), min(nx - 1, i + rad) do
							local oo = kk * nx + ii
							if buffer.readu8(m, oo) ~= 0 then
								local d2 = ((ii - i) ^ 2 + (kk - k) ^ 2) * g.G * g.G
								local ww = exp(-0.5 * d2 / (P.SIGMA * P.SIGMA))
								a += ww * buffer.readf32(f2, oo * 4)
								b += ww
							end
						end
					end
				end
				if ok and b > 1e-9 then
					buffer.writef32(f2, o * 4, a / b)
					nGap += 1
				else
					buffer.writeu8(mc, o, 0)
				end
			end
		end
		if yieldFn and k % 64 == 0 then yieldFn(0.6 + 0.4 * k / nz) end
	end
	g.f = f2
	g.mask = mc
	g.nGap = nGap
	return f2, mc
end

-- Wert der glatten Flaeche an (x, z) oder nil (bilinear ueber die gueltigen Nachbarzellen)
function Core.FieldAt(g, x, z)
	local fx, fz = (x - g.x0) / g.G - 0.5, (z - g.z0) / g.G - 0.5
	local i0, k0 = floor(fx), floor(fz)
	local tx, tz = fx - i0, fz - k0
	local s, w = 0, 0
	for dk = 0, 1 do
		for di = 0, 1 do
			local i, k = i0 + di, k0 + dk
			if i >= 0 and k >= 0 and i < g.nx and k < g.nz then
				local o = k * g.nx + i
				if buffer.readu8(g.mask, o) ~= 0 then
					local ww = ((di == 1) and tx or (1 - tx)) * ((dk == 1) and tz or (1 - tz))
					s += ww * buffer.readf32(g.f, o * 4)
					w += ww
				end
			end
		end
	end
	if w < 1e-6 then return nil end
	return s / w
end

----------------------------------------------------------------------------------------------- Hautplatten
-- Ebene y = a*x + b*z + c durch Punkte {x, z, y}; Rueckgabe a, b, c, maximaler Fehler
function Core.PlaneFit(pts)
	local n = #pts
	if n < 3 then return nil end
	local sxx, sxz, szz, sx, sz, sxy, szy, sy = 0, 0, 0, 0, 0, 0, 0, 0
	-- zentrieren fuer numerische Stabilitaet
	local mx, mz = 0, 0
	for _, q in ipairs(pts) do mx += q[1]; mz += q[2] end
	mx /= n; mz /= n
	for _, q in ipairs(pts) do
		local x, z, y = q[1] - mx, q[2] - mz, q[3]
		sxx += x * x; sxz += x * z; szz += z * z; sx += x; sz += z
		sxy += x * y; szy += z * y; sy += y
	end
	-- Normalgleichungen [sxx sxz sx; sxz szz sz; sx sz n] [a b c'] = [sxy szy sy]
	-- leichte Regularisierung: bei Punkten auf einer Linie (auch diagonal) bleibt die Steigung entlang der Linie
	-- erhalten und quer dazu wird sie 0 (statt zufaellig)
	local lam = 1e-6 * n + 1e-9 * (sxx + szz)
	local A = { { sxx + lam, sxz, sx, sxy }, { sxz, szz + lam, sz, szy }, { sx, sz, n, sy } }
	for c = 1, 3 do
		local piv, pv = c, abs(A[c][c])
		for r = c + 1, 3 do if abs(A[r][c]) > pv then piv, pv = r, abs(A[r][c]) end end
		if pv < 1e-12 then
			-- entartet (z.B. alle Punkte auf einer Linie): nur Mittelwert
			local yy = 0
			for _, q in ipairs(pts) do yy += q[3] end
			yy /= n
			local e = 0
			for _, q in ipairs(pts) do e = max(e, abs(q[3] - yy)) end
			return 0, 0, yy, e
		end
		A[c], A[piv] = A[piv], A[c]
		for r = 1, 3 do
			if r ~= c then
				local f = A[r][c] / A[c][c]
				for cc = c, 4 do A[r][cc] -= f * A[c][cc] end
			end
		end
	end
	local a, b, cp = A[1][4] / A[1][1], A[2][4] / A[2][2], A[3][4] / A[3][3]
	local c = cp - a * mx - b * mz
	local e = 0
	for _, q in ipairs(pts) do e = max(e, abs(a * q[1] + b * q[2] + c - q[3])) end
	return a, b, c, e
end

local function mat(r) return { { r[1], r[2], r[3] }, { r[4], r[5], r[6] }, { r[7], r[8], r[9] } } end
local function mulv(M, v) -- M (3x3) * v
	return { M[1][1] * v[1] + M[1][2] * v[2] + M[1][3] * v[3], M[2][1] * v[1] + M[2][2] * v[2] + M[2][3] * v[3], M[3][1] * v[1] + M[3][2] * v[2] + M[3][3] * v[3] }
end
local function mulm(A, B)
	local C = { { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 } }
	for i = 1, 3 do for j = 1, 3 do C[i][j] = A[i][1] * B[1][j] + A[i][2] * B[2][j] + A[i][3] * B[3][j] end end
	return C
end
local function unit(v)
	local l = sqrt(v[1] ^ 2 + v[2] ^ 2 + v[3] ^ 2)
	return { v[1] / l, v[2] / l, v[3] / l }
end
local function cross(a, b) return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] } end
local function dot(a, b) return a[1] * b[1] + a[2] * b[2] + a[3] * b[3] end
-- Rotation, die a auf b dreht (Rodrigues)
local function rotBetween(a, b)
	a, b = unit(a), unit(b)
	local v = cross(a, b)
	local c = dot(a, b)
	local s = sqrt(dot(v, v))
	if s < 1e-9 then
		if c > 0 then return { { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 } } end
		return { { -1, 0, 0 }, { 0, -1, 0 }, { 0, 0, -1 } }
	end
	local vx = { { 0, -v[3], v[2] }, { v[3], 0, -v[1] }, { -v[2], v[1], 0 } }
	local vx2 = mulm(vx, vx)
	local f = (1 - c) / (s * s)
	local R = { { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 } }
	for i = 1, 3 do for j = 1, 3 do R[i][j] += vx[i][j] + vx2[i][j] * f end end
	return R
end
local function flat(M) return { M[1][1], M[1][2], M[1][3], M[2][1], M[2][2], M[2][3], M[3][1], M[3][2], M[3][3] } end
local function sgn(x) return (x < 0) and -1 or 1 end

-- Hautplatte: Teil (Mitte c, Drehung M, Groesse s) so drehen/verschieben, dass seine Oberseite auf y = a x + b z + cc liegt
function Core.MakePiece(k, M, c, s, nl, ft, a, b, cc)
	local P = Core.P
	local nNew = unit({ -a, 1, -b })
	local nOld = unit(mulv(M, nl))
	local M2 = mulm(rotBetween(nOld, nNew), M)
	local kind = k
	local s2 = { s[1], s[2], s[3] }
	local ax
	local nl2 = { nl[1], nl[2], nl[3] }
	if ft == "slope" then
		-- Keil mit schraeger Oberseite -> flacher Block ueber derselben Grundflaeche
		local L = sqrt(s[2] ^ 2 + s[3] ^ 2)
		local zdir = mulv(M2, { 0, s[2] / L, s[3] / L })
		local d = dot(zdir, nNew)
		zdir = unit({ zdir[1] - nNew[1] * d, zdir[2] - nNew[2] * d, zdir[3] - nNew[3] * d })
		local xdir = cross(nNew, zdir)
		M2 = { { xdir[1], nNew[1], zdir[1] }, { xdir[2], nNew[2], zdir[2] }, { xdir[3], nNew[3], zdir[3] } }
		s2 = { s[1], P.THICK, L }
		nl2 = { 0, 1, 0 }
		ax = 2
		kind = 0
	elseif ft == "disc" or ft == "tri" then
		ax = 1
	else
		ax = (abs(nl[1]) > 0.5) and 1 or ((abs(nl[2]) > 0.5) and 2 or 3)
	end
	-- Mitte der Oberseite im ORIGINAL-Teil (Drehung erfolgt um diesen Punkt, damit dicke Teile nicht seitlich wandern)
	local top
	if ft == "slope" then
		top = { c[1], c[2], c[3] } -- die Schraege geht durch die lokale Mitte
	else
		local h0 = { s[1] / 2, s[2] / 2, s[3] / 2 }
		local tl = { 0, 0, 0 }
		tl[ax] = sgn(nl[ax]) * h0[ax]
		if ft == "tri" then
			tl[2] = -h0[2] / 3
			tl[3] = h0[3] / 3
		end
		local tw = mulv(M, tl)
		top = { c[1] + tw[1], c[2] + tw[2], c[3] + tw[3] }
	end
	top[2] = a * top[1] + b * top[3] + cc
	local s3 = { s2[1], s2[2], s2[3] }
	s3[ax] = P.THICK
	for i = 1, 3 do if i ~= ax then s3[i] += 2 * P.OVL end end
	if kind == 2 then
		local d = min(s3[2], s3[3])
		s3[2], s3[3] = d, d
	end
	local rel = { 0, 0, 0 }
	rel[ax] = sgn(nl2[ax]) * P.THICK / 2
	if ft == "tri" then
		rel[2] = -s3[2] / 6
		rel[3] = s3[3] / 6
	end
	local rw = mulv(M2, rel)
	return { k = kind, x = top[1] - rw[1], y = top[2] - rw[2], z = top[3] - rw[3], r = flat(M2), sx = s3[1], sy = s3[2], sz = s3[3] }
end

-- Hautplatten fuer ein Fahrbahnteil (geteilt, falls die glatte Flaeche nicht eben genug ist)
function Core.PiecesFor(g, p)
	local P = Core.P
	local nx, ny, nz, ft = Core.TopFace(p)
	local M = mat(p.r)
	local nl = { nx, ny, nz }
	local upc = mulv(M, nl)[2]
	if upc < 0.5 then return {}, "steil" end
	local covered = 0
	local function samplesWorld(cx, cy, cz, sx, sy, sz)
		local loc = Core.FaceSamples(p.k, nx, ny, nz, ft, sx, sy, sz)
		local out = {}
		for _, q in ipairs(loc) do
			local w = mulv(M, q)
			local x, z = cx + w[1], cz + w[3]
			local f = Core.FieldAt(g, x, z)
			if f then
				-- liegt die glatte Flaeche hier deutlich hoeher (andere Ebene darueber), gehoert der Punkt nicht zu diesem Teil
				if f - (cy + w[2]) < P.UNDER then
					table.insert(out, { x, z, f })
				else
					covered += 1
				end
			end
		end
		return out
	end
	local subs = { { p.x, p.y, p.z, p.sx, p.sy, p.sz } }
	if ft == "rect" and p.k == 0 then
		-- rekursiv halbieren (laengere Kante zuerst), bis die Ebene passt oder das Stueck klein ist
		local a = (abs(nx) > 0.5) and 1 or ((abs(ny) > 0.5) and 2 or 3)
		local u, v = (a == 1) and 2 or 1, (a == 3) and 2 or 3
		subs = {}
		local nSplit = 0
		local function rec(cx, cy, cz, s, depth)
			local pts = samplesWorld(cx, cy, cz, s[1], s[2], s[3])
			if #pts < 3 then return end
			local _, _, _, err = Core.PlaneFit(pts)
			local longAx = (s[u] >= s[v]) and u or v
			if err > P.TOL and s[longAx] > P.MINPIECE * 2 and depth < 14 then
				nSplit += 1
				local half = { s[1], s[2], s[3] }
				half[longAx] = s[longAx] / 2
				for _, sg in ipairs({ -1, 1 }) do
					local off = { 0, 0, 0 }
					off[longAx] = sg * s[longAx] / 4
					local w = mulv(M, off)
					rec(cx + w[1], cy + w[2], cz + w[3], half, depth + 1)
				end
			else
				table.insert(subs, { cx, cy, cz, s[1], s[2], s[3] })
			end
		end
		rec(p.x, p.y, p.z, { p.sx, p.sy, p.sz }, 0)
		if #subs == 0 then return {}, "keinFeld" end
	end
	local out = {}
	local rejected = 0
	for _, sb in ipairs(subs) do
		local pts = samplesWorld(sb[1], sb[2], sb[3], sb[4], sb[5], sb[6])
		if #pts >= 3 then
			local a, b, c, err = Core.PlaneFit(pts)
			local up = 1 / sqrt(1 + a * a + b * b)
			-- keine steilen oder schlecht passenden Platten (z.B. an der Kante einer darueberliegenden Ebene)
			if err <= 0.5 and up >= min(upc, 0.9) - 0.1 then
				local pc = Core.MakePiece(p.k == 3 and 0 or p.k, M, { sb[1], sb[2], sb[3] }, { sb[4], sb[5], sb[6] }, nl, ft, a, b, c)
				pc.err = err
				table.insert(out, pc)
			else
				rejected += 1
			end
		end
	end
	if covered > 0 or rejected > 0 then return out, "unter" end
	return out, (#subs > 1) and "geteilt" or "ok"
end

-- Kacheln fuer geschlossene Luecken (Maskenwert 2): achsparallele Quadtree-Kacheln, je eine Ebene
function Core.GapPieces(g)
	local P = Core.P
	local nx, nz, G = g.nx, g.nz, g.G
	local seen = buffer.create(g.n)
	local out = {}
	local maxc = max(1, floor(P.GAPMAX / G))
	local function tile(i0, k0, ni, nk)
		-- Ebene ueber alle Zellen (Fahrbahn + Luecke) im Rechteck, gefittet an Lueckenzellen und Nachbarn
		local pts = {}
		for i = i0, i0 + ni - 1 do
			for k = k0, k0 + nk - 1 do
				local o = k * nx + i
				if buffer.readu8(g.mask, o) ~= 0 then
					table.insert(pts, { g.x0 + (i + 0.5) * G, g.z0 + (k + 0.5) * G, buffer.readf32(g.f, o * 4) })
				end
			end
		end
		if #pts < 3 then
			if #pts == 0 then return end
			local y = pts[1][3]
			pts = { { pts[1][1] - 0.1, pts[1][2], y }, { pts[1][1] + 0.1, pts[1][2], y }, { pts[1][1], pts[1][2] + 0.1, y } }
		end
		local a, b, c, err = Core.PlaneFit(pts)
		if err > P.GAPTOL and (ni > 1 or nk > 1) then
			if ni >= nk then
				local h = floor(ni / 2)
				tile(i0, k0, h, nk)
				tile(i0 + h, k0, ni - h, nk)
			else
				local h = floor(nk / 2)
				tile(i0, k0, ni, h)
				tile(i0, k0 + h, ni, nk - h)
			end
			return
		end
		local cx = g.x0 + (i0 + ni / 2) * G
		local cz = g.z0 + (k0 + nk / 2) * G
		local sx, sz = ni * G, nk * G
		local pc = Core.MakePiece(0, { { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 } }, { cx, a * cx + b * cz + c - 0.5, cz }, { sx, 1, sz }, { 0, 1, 0 }, "rect", a, b, c)
		pc.err = err
		pc.gap = true
		table.insert(out, pc)
	end
	for k = 0, nz - 1 do
		for i = 0, nx - 1 do
			local o = k * nx + i
			if buffer.readu8(g.mask, o) == 2 and buffer.readu8(seen, o) == 0 then
				-- Rechteck um zusammenhaengende Lueckenzellen in diesem Block wachsen lassen
				local i1, k1 = i, k
				while i1 + 1 < nx and i1 - i + 1 < maxc and buffer.readu8(g.mask, k * nx + i1 + 1) == 2 and buffer.readu8(seen, k * nx + i1 + 1) == 0 do
					i1 += 1
				end
				local grow = true
				while grow and k1 + 1 < nz and k1 - k + 1 < maxc do
					for ii = i, i1 do
						local oo = (k1 + 1) * nx + ii
						if buffer.readu8(g.mask, oo) ~= 2 or buffer.readu8(seen, oo) ~= 0 then grow = false break end
					end
					if grow then k1 += 1 end
				end
				for kk = k, k1 do for ii = i, i1 do buffer.writeu8(seen, kk * nx + ii, 1) end end
				tile(i, k, i1 - i + 1, k1 - k + 1)
			end
		end
	end
	return out
end

----------------------------------------------------------------------------------------------- Fahrt-Kennzahlen
-- Aus einer Folge von Zielhoehen (gleicher Abstand) Spruenge bestimmen: |dh - erwartet| > thr
function Core.Jumps(seq, thr, n)
	local out = {}
	n = n or #seq
	for i = 2, n do
		local a, b = seq[i - 1], seq[i]
		if a and b then
			local d = b - a
			local pr = {}
			if i > 2 and seq[i - 2] then table.insert(pr, seq[i - 1] - seq[i - 2]) end
			if i < n and seq[i + 1] then table.insert(pr, seq[i + 1] - seq[i]) end
			local pred = 0
			if #pr == 2 then
				-- der kleinere Nachbar-Anstieg ist die erwartete Steigung (sonst wird eine Stufe dreimal gezaehlt)
				pred = (abs(pr[1]) <= abs(pr[2])) and pr[1] or pr[2]
			elseif #pr == 1 then
				pred = pr[1]
			end
			pred = math.clamp(pred, -0.5, 0.5)
			local j = d - pred
			if abs(j) > thr then table.insert(out, { i = i, j = j }) end
		end
	end
	return out
end

-- Hoehenfilter des neuen Fahrwerks (alpha-beta): folgt Steigungen ohne Verzug, glaettet Spruenge
function Core.NewFilter(alpha, beta)
	return { y = nil, v = 0, a = alpha or 0.3, b = beta or 0.05 }
end
function Core.FilterStep(F, raw, dt, minY)
	if F.y == nil then
		F.y, F.v = raw, 0
	else
		local pred = F.y + F.v * dt
		local res = raw - pred
		F.y = pred + F.a * res
		F.v = F.v + F.b * res / math.max(dt, 1e-4)
	end
	if minY and F.y < minY then
		F.y = minY
		if F.v < 0 then F.v = 0 end
	end
	return F.y
end

return Core
