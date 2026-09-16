
---@class RegionGeometry
local Geometry = {}

---@param vertices { x: number, z: number }[]
---@return number
function Geometry.Area(vertices)
	local n = #vertices
	if n < 3 then
		return 0
	end
	local twice = 0.0
	for i, a in ipairs(vertices) do
		local b = vertices[(i % n) + 1] or a
		twice = twice + (a.x * b.z - b.x * a.z)
	end
	return math.abs(twice) * 0.5
end

---@param vertices { x: number, z: number }[]
---@return number x
---@return number z
function Geometry.Centroid(vertices)
	local n = #vertices
	if n == 0 then
		return 0, 0
	end
	local sx, sz = 0.0, 0.0
	for _, v in ipairs(vertices) do
		sx, sz = sx + v.x, sz + v.z
	end
	return sx / n, sz / n
end

---@param x number
---@param z number
---@param vertices { x: number, z: number }[]
---@return boolean
function Geometry.Contains(x, z, vertices)
	local n = #vertices
	if n < 3 then
		return false
	end
	local inside = false
	local j = n
	for i, vi in ipairs(vertices) do
		local vj = vertices[j] or vi
		if (vi.z > z) ~= (vj.z > z) then
			local crossX = vj.x + (z - vj.z) * (vi.x - vj.x) / (vi.z - vj.z)
			if x < crossX then
				inside = not inside
			end
		end
		j = i
	end
	return inside
end

---@param p { x: number, z: number }
---@param q { x: number, z: number }
---@param r { x: number, z: number }
---@return number
local function orient(p, q, r)
	return (q.x - p.x) * (r.z - p.z) - (q.z - p.z) * (r.x - p.x)
end

local function segmentsCross(a1, a2, b1, b2)
	local d1, d2 = orient(b1, b2, a1), orient(b1, b2, a2)
	local d3, d4 = orient(a1, a2, b1), orient(a1, a2, b2)
	return ((d1 > 0) ~= (d2 > 0) or d1 == 0 or d2 == 0) and ((d3 > 0) ~= (d4 > 0) or d3 == 0 or d4 == 0)
end

---@param a { x: number, z: number }[]
---@param b { x: number, z: number }[]
---@return boolean
function Geometry.Overlaps(a, b)
	if #a < 3 or #b < 3 then
		return false
	end
	for _, v in ipairs(a) do
		if Geometry.Contains(v.x, v.z, b) then
			return true
		end
	end
	for _, v in ipairs(b) do
		if Geometry.Contains(v.x, v.z, a) then
			return true
		end
	end
	local na, nb = #a, #b
	for i = 1, na do
		local a1, a2 = a[i], a[(i % na) + 1]
		for j = 1, nb do
			if segmentsCross(a1, a2, b[j], b[(j % nb) + 1]) then
				return true
			end
		end
	end
	return false
end

---@param ax number
---@param az number
---@param bx number
---@param bz number
---@return number
function Geometry.Distance(ax, az, bx, bz)
	return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
end

return Geometry
