local Policy = require("modules/policy")
local Modules = require("modules/enums").Modules
local ConstructionContract = require("modules/construction/contract")

---@class TransferRequest : TransferPolicyContext
---@field policyType string TransferEnums.PolicyType

---@class TransferTeamResources
---@field metal EconomyResource
---@field energy EconomyResource

---@class TransferPolicyResult
---@field senderTeamId integer
---@field receiverTeamId integer

---@class TransferUnitPolicyResult : TransferPolicyResult
---@field canShare boolean
---@field sharingModes string[]
---@field stunSeconds number?
---@field stunCategory string?
---@field buildDelaySeconds number?
---@field techBlocking? TechBlockingContext

---@class TransferResourcePolicyResult : TransferPolicyResult
---@field canShare boolean
---@field amountSendable number
---@field amountReceivable number
---@field taxedPortion number
---@field taxRate number
---@field resourceType ResourceName
---@field techBlocking? TechBlockingContext

---@class TransferTakeContext
---@field modOptions table<string, string|number|boolean>

---@class TransferPolicyContext
---@field senderTeamId integer
---@field receiverTeamId integer
---@field sender TransferTeamResources
---@field receiver TransferTeamResources
---@field springRepo Spring
---@field areAlliedTeams boolean
---@field isCheatingEnabled boolean
---@field techBlocking? TechBlockingContext provided by an enricher (tech blocking)
---@field unitSharingModes? string[] Effective sharing modes, provided by an enricher
---@field taxRate? number Effective tax rate, provided by an enricher

---@class TransferTeamContext one team, no pairing: what a single team's terms are
---@field teamId integer
---@field springRepo Spring
---@field opts table<string, string|number|boolean>

---@class TransferTeamTermsFacts: PolicyFacts<TransferTeamContext>
---@field TaxRate "taxRate"

---@type TransferTeamTermsFacts
local TeamTerms = {
	TaxRate = "taxRate",
}

---@class TransferUnitNotesFacts: PolicyFacts<TransferUnitPolicyResult> display notes other modules attach to a unit-terms record; providers get the modoptions as their extra argument
---@field FutureUnlock "futureUnlock"
---@field TechData "techData"

---@type TransferUnitNotesFacts
local UnitNotes = {
	FutureUnlock = "futureUnlock",
	TechData = "techData",
}

---@class TransferResourceNotesFacts: PolicyFacts<TransferResourcePolicyResult> display notes other modules attach to a resource-terms record; providers get the modoptions as their extra argument
---@field TaxUnlock "taxUnlock"

---@type TransferResourceNotesFacts
local ResourceNotes = {
	TaxUnlock = "taxUnlock",
}

---@class TransferTeamPairingFacts: PolicyFacts<TransferPolicyContext>
---@field TechBlocking "techBlocking"
---@field UnitSharingModes "unitSharingModes"
---@field TaxRate "taxRate"

---@type TransferTeamPairingFacts
local TeamPairing = {
	TechBlocking = "techBlocking",
	UnitSharingModes = "unitSharingModes",
	TaxRate = "taxRate",
}

---@class TransferTakePolicy: PolicySteps<TransferTakeContext, TakePolicy>
---@field TakeTerms "TakeTerms"

---@type TransferTakePolicy
local Take = {
	TakeTerms = "TakeTerms",
}

---@class TransferUnitTransferPolicy: PolicySteps<TransferPolicyContext, TransferUnitPolicyResult>
---@field SharingDisabled "SharingDisabled"
---@field Allied "Allied"
---@field ReceiverHasNoPlayers "ReceiverHasNoPlayers"
---@field TransferTerms "TransferTerms"

---@type TransferUnitTransferPolicy
local UnitTransfer = {
	SharingDisabled = "SharingDisabled",
	Allied = "Allied",
	ReceiverHasNoPlayers = "ReceiverHasNoPlayers",
	TransferTerms = "TransferTerms",
}

---@class TransferResourceTransferPolicy: PolicySteps<TransferPolicyContext, TransferResourcePolicyResult>
---@field SharingDisabled "SharingDisabled"
---@field Allied "Allied"
---@field ReceiverHasNoPlayers "ReceiverHasNoPlayers"
---@field RateAndCapacity "RateAndCapacity"

---@type TransferResourceTransferPolicy
local ResourceTransfer = {
	SharingDisabled = "SharingDisabled",
	Allied = "Allied",
	ReceiverHasNoPlayers = "ReceiverHasNoPlayers",
	RateAndCapacity = "RateAndCapacity",
}

---@class MexRegion: Region an area of the layout, in elmos, whose metal is dealt to the teams seated at one start. The deal is keyed by its id; a name is the map's to give, Regions.Names derives one from the group otherwise
---@field type "mex_region"
---@field team integer the start ordinal the region belongs to; start 1 is team 1
---@field group string the region's role on this map, e.g. "anti", "tech"

---@class MexRegionsTeamStart a team, seated at a start
---@field teamID integer
---@field allyTeamID integer the engine's; the layout seats it at start allyTeamID + 1
---@field x number the team's start point: the centre of its start area
---@field z number

---@class MexRegionsDealContext the inputs to the deal: the layout, the map's metal spots, and the seated teams
---@field regions MexRegion[] the layout's regions
---@field spots { x: number, z: number }[] the map's metal spots; a mex is attributed to the spot it mines
---@field teams MexRegionsTeamStart[] in deal order

---@class MexRegionsDeal the outcome: who holds what. Empty, with problems set, when no deal could be made
---@field regions table<string, integer> the team holding each region, by region id
---@field spots table<string, integer[]> the teams holding each metal spot, by spot key; this is what a mex placement is checked against. A spot covered by two regions is held by both teams
---@field problems string[] why no deal was made; empty when one was

---@class TransferMexSplittingPolicy: PolicySteps<MexRegionsDealContext, MexRegionsDeal>
---@field LayoutChecksOut string the layout passes the regions module's set check for mex regions: every region well-formed with its fields set, and every spot covered
---@field SpotsKnown string the map has metal spots; a metal map has none to deal
---@field NearestRoundRobin string a region goes round the teams seated at its start, nearest first; one whose start is empty this match goes round every team. A team left holding nothing means the layout has too few regions, and there is no deal

---@type TransferMexSplittingPolicy
local MexSplitting = {
	LayoutChecksOut = "LayoutChecksOut",
	SpotsKnown = "SpotsKnown",
	NearestRoundRobin = "NearestRoundRobin",
}

---@class MexRegionsHeirContext a team has left the match; decides who inherits its regions
---@field departing MexRegionsTeamStart
---@field heirs { teamID: integer, x: number, z: number, gifted: integer }[] the departing team's living allies in the deal; gifted is how many regions each has already inherited

---@class TransferMexSplittingHeirPolicy: PolicySteps<MexRegionsHeirContext, integer|false>
---@field FewestGiftedThenNearest string the ally that has inherited the fewest regions; ties go to the one starting nearest the departing team

---@type TransferMexSplittingHeirPolicy
local MexSplittingHeir = {
	FewestGiftedThenNearest = "FewestGiftedThenNearest",
}

---@class (partial) TransferContract
---@field Take TransferTakePolicy
---@field UnitTransfer TransferUnitTransferPolicy
---@field ResourceTransfer TransferResourceTransferPolicy
---@field TeamPairing TransferTeamPairingFacts
---@field TeamTerms TransferTeamTermsFacts
---@field UnitTermsNotes TransferUnitNotesFacts
---@field ResourceTermsNotes TransferResourceNotesFacts
---@field MexSplitting TransferMexSplittingPolicy
---@field MexSplittingHeir TransferMexSplittingHeirPolicy

---@class TransferBuildSteps the steps transfer adds to construction's build policy
---@field UnaffordableAssistTax string a build step the assisting team cannot pay the tax on

---@type TransferBuildSteps
local Build = {
	UnaffordableAssistTax = "UnaffordableAssistTax",
}

return Policy.Contract(Modules.Transfer, {
	Build = Policy.Contributes(ConstructionContract.Build, Build),
	Take = Policy.Single(Take),
	UnitTransfer = Policy.Single(UnitTransfer),
	ResourceTransfer = Policy.Single(ResourceTransfer),
	TeamPairing = Policy.Facts(TeamPairing),
	TeamTerms = Policy.Facts(TeamTerms),
	UnitTermsNotes = Policy.Facts(UnitNotes),
	ResourceTermsNotes = Policy.Facts(ResourceNotes),
	MexSplitting = Policy.Single(MexSplitting),
	MexSplittingHeir = Policy.Single(MexSplittingHeir),
})
