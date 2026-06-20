-- Tech Blocking modoption tweaks, applied from alldefs_post when modOptions.tech_blocking is set.
--   1. Cheaper / faster T2 labs so the Tech Core path is viable.
--   2. Inject the faction Keystone into T1 mobile constructor build menus.

local cheaperT2Labs = {
	armalab = { energycost = 10000, metalcost = 1700, buildtime = 15000, health = 3500, maxslope = 15, workertime = 200 },
	coralab = { energycost = 10000, metalcost = 1700, buildtime = 15000, health = 3500, maxslope = 15, workertime = 200 },
	legalab = { energycost = 10000, metalcost = 1700, buildtime = 15000, health = 3500, maxslope = 15, workertime = 200 },
	armavp  = { energycost = 10000, metalcost = 1850, buildtime = 16500, health = 3600, maxslope = 15, workertime = 200 },
	coravp  = { energycost = 10000, metalcost = 1850, buildtime = 16500, health = 3600, maxslope = 15, workertime = 200 },
	legavp  = { energycost = 10000, metalcost = 1850, buildtime = 16500, health = 3600, maxslope = 15, workertime = 200 },
	armaap  = { energycost = 11000, metalcost = 2000, buildtime = 20000, health = 3500, maxslope = 15, workertime = 200 },
	coraap  = { energycost = 11000, metalcost = 2000, buildtime = 20000, health = 3500, maxslope = 15, workertime = 200 },
	legaap  = { energycost = 11000, metalcost = 2000, buildtime = 20000, health = 3500, maxslope = 15, workertime = 200 },
}

local keystoneByPrefix = { arm = "armkeystone", cor = "corkeystone", leg = "legkeystone" }
local mexByPrefix      = { arm = "armmex",      cor = "cormex",      leg = "legmex" }

-- Tech-core cons that should build the Keystone but can't build the faction mex
-- (the Voussoir only builds the Springer), so they're allowlisted explicitly.
local extraKeystoneBuilders = { armvoussoir = true, corvoussoir = true, legvoussoir = true }

local function buildsUnit(buildoptions, target)
	for i = 1, #buildoptions do
		if buildoptions[i] == target then
			return true
		end
	end
	return false
end

local function techBlockingTweaks(name, uDef)
	-- Cheaper T2 labs
	local labStats = cheaperT2Labs[name]
	if labStats then
		for key, value in pairs(labStats) do
			uDef[key] = value
		end
	end

	-- Inject Keystone into T1 mobile constructor build menus.
	-- Only general-purpose constructors qualify: we detect them by their ability to
	-- build the faction's basic metal extractor, which excludes specialised builders
	-- (resurrection bots/subs, minelayers) that share the "builder" unitgroup but have
	-- narrow or empty build menus. The Voussoir is allowlisted since it builds no mex.
	if uDef.buildoptions and uDef.speed and uDef.speed > 0 and not (uDef.customparams and uDef.customparams.iscommander) then
		local techLevel = tonumber(uDef.customparams and uDef.customparams.techlevel) or 1
		local keystone = keystoneByPrefix[name:sub(1, 3)]
		if techLevel == 1 and keystone then
			local isGeneralCon = extraKeystoneBuilders[name]
				or buildsUnit(uDef.buildoptions, mexByPrefix[name:sub(1, 3)])
			if isGeneralCon then
				uDef.buildoptions[#uDef.buildoptions + 1] = keystone
			end
		end
	end
end

return {
	Tweaks = techBlockingTweaks,
}
