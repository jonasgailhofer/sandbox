local Core = require("./Core")
local city = ... or "Portavia"
local data = require("./data_" .. city)
local t0 = os.clock()
-- Bounds
local x0, z0, x1, z1 = math.huge, math.huge, -math.huge, -math.huge
for _, p in ipairs(data) do
	local ex, _, ez = Core.Extents(p)
	x0 = math.min(x0, p.x - ex); x1 = math.max(x1, p.x + ex)
	z0 = math.min(z0, p.z - ez); z1 = math.max(z1, p.z + ez)
end
x0, z0 = math.floor(x0) - 8, math.floor(z0) - 8
x1, z1 = math.ceil(x1) + 8, math.ceil(z1) + 8
local g = Core.NewGrid(x0, z0, x1, z1, 1)
for i, p in ipairs(data) do Core.RasterPart(g, p, i) end
local t1 = os.clock()
Core.Smooth(g)
local t2 = os.clock()
-- owners
local owners = {}
for o = 0, g.n - 1 do
	local id = buffer.readi32(g.own, o * 4)
	if id ~= 0 then owners[id] = true end
end
local pieces, stat = {}, {}
for i, p in ipairs(data) do
	if owners[i] then
		local pc, st = Core.PiecesFor(g, p)
		stat[st] = (stat[st] or 0) + 1
		for _, q in ipairs(pc) do q.src = p.id; table.insert(pieces, q) end
	end
end
local gaps = Core.GapPieces(g)
for _, q in ipairs(gaps) do q.src = -1; table.insert(pieces, q) end
local t3 = os.clock()
print("# " .. string.format("%s grid %dx%d raster %.2fs smooth %.2fs pieces %.2fs  pieces=%d gaps=%d gapcells=%d", city, g.nx, g.nz, t1 - t0, t2 - t1, t3 - t2, #pieces, #gaps, g.nGap))
for k, v in pairs(stat) do print("# " .. k .. "=" .. v) end

-- output pieces
for _, q in ipairs(pieces) do
	local r = q.r
	print(string.format("P %d %.5f %.5f %.5f %.7f %.7f %.7f %.7f %.7f %.7f %.7f %.7f %.7f %.5f %.5f %.5f %d %.4f", q.k, q.x, q.y, q.z, r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9], q.sx, q.sy, q.sz, q.src, q.err or 0))
end
-- field samples (every 7th masked cell)
local c = 0
for o = 0, g.n - 1, 7 do
	if buffer.readu8(g.mask, o) ~= 0 then
		local i, k = o % g.nx, o // g.nx
		print(string.format("F %.2f %.2f %.4f %d", g.x0 + i + 0.5, g.z0 + k + 0.5, buffer.readf32(g.f, o * 4), buffer.readu8(g.mask, o)))
	end
end
