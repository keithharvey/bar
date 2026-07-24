--- Sharing mode vocabulary over modules/mode_builder.lua: nouns for the
--- sharing domains, verbs mapping them onto the pipeline's policy identities.
--- Chain mechanics, lock model, and the bundle contract live in the builder;
--- preset files read as:
---
---     Mode("Disabled")
---         .Desc("Disable all sharing.")
---         .Deny(Share.Resources)
---         .Tax(Share.Resources, 0.30).Hidden().Unlocked()

local ModeEnums = VFS.Include("modes/sharing_mode_enums.lua")
local Bundle = VFS.Include("modes/sharing_policy_bundle.lua")
local ModeBuilder = VFS.Include("modules/mode_builder.lua")

local M = {}

-- Nouns: each names the policy domain its verbs act on.
M.Share = {
	Units = { domain = "unit" },
	Resources = { domain = "resource" },
}
M.Assist = {
	Allied = { domain = "assist" },
}
M.Reclaim = {
	AlliedUnits = { domain = "reclaim" },
}
M.Take = { domain = "take" }

local HINT = "Share.*, Assist.*, Reclaim.*, Take"
local ALLOW_DENY = { unit = true, resource = true, assist = true, reclaim = true, take = true }

M.Mode = ModeBuilder.Grammar({
	category = ModeEnums.ModeCategories.Sharing,
	serializers = Bundle.Serializers,
	verbs = {
		---Deny the noun's domain outright.
		Deny = function(name, noun)
			return { ModeBuilder.DomainOf(name, "Deny", noun, ALLOW_DENY, HINT) .. ".deny" }
		end,
		---Tax resource sharing at a rate in [0,1].
		Tax = function(name, noun, rate)
			ModeBuilder.DomainOf(name, "Tax", noun, { resource = true }, "Share.Resources")
			return { "resource.tax", rate = rate }
		end,
	},
})

return M
