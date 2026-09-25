---@class MexIncome the metal a team's extractors make, and how a team's pooled extraction splits back evenly
local Income = {}

---@param springRepo Spring
---@param teamID integer
---@param mexDefIDs integer[] the unit defs that extract metal
---@return number metal per second the team's extractors make
function Income.Extraction(springRepo, teamID, mexDefIDs)
	local rate = 0.0
	for _, unitID in ipairs(springRepo.GetTeamUnitsByDefs(teamID, mexDefIDs) or {}) do
		local metalMake = springRepo.GetUnitResources(unitID)
		rate = rate + (metalMake or 0)
	end
	return rate
end

---@class MexIncomeSeat one team of an ally team, with what its extractors made this tick
---@field teamID integer
---@field made number

---@param seats MexIncomeSeat[] the teams of one ally team
---@return EconomyTransfer[] what the teams above the even share hand the teams below it
function Income.Even(seats)
	local total = 0.0
	for _, seat in ipairs(seats) do
		total = total + seat.made
	end
	if #seats < 2 or total <= 0 then
		return {}
	end
	local share = total / #seats
	local givers = {} ---@type { teamID: integer, surplus: number }[]
	local takers = {} ---@type { teamID: integer, deficit: number }[]
	for _, seat in ipairs(seats) do
		if seat.made > share then
			givers[#givers + 1] = { teamID = seat.teamID, surplus = seat.made - share }
		elseif seat.made < share then
			takers[#takers + 1] = { teamID = seat.teamID, deficit = share - seat.made }
		end
	end
	local transfers = {} ---@type EconomyTransfer[]
	local t = 1
	for _, giver in ipairs(givers) do
		local left = giver.surplus
		while left > 1e-9 and t <= #takers do
			local taker = takers[t]
			local amount = math.min(left, taker.deficit)
			transfers[#transfers + 1] =
				{ from = giver.teamID, to = taker.teamID, resourceType = "metal", amount = amount }
			left = left - amount
			taker.deficit = taker.deficit - amount
			if taker.deficit <= 1e-9 then
				t = t + 1
			end
		end
	end
	return transfers
end

return Income
