
function setup()
	_G.VFS = _G.VFS or {}
	VFS.Include = function(path)
		if path:match("resource_share_tax") then
			return require_resource_tax_module()
		end
		return {}
	end
end

function cleanup()
	_G.VFS = nil
end

function require_resource_tax_module()
	local Tax = {}
	
	function Tax.computeTransfer(resourceName, amount, taxRate, threshold, cumulativeSent)
		threshold = threshold or 0
		cumulativeSent = cumulativeSent or 0
		taxRate = taxRate or 0
		
		if amount <= 0 then
			return {
				actualSent = 0,
				actualReceived = 0,
				untaxedPortion = 0,
				taxablePortion = 0,
				taxAmount = 0
			}
		end
		
		local untaxedPortion = 0
		local taxablePortion = amount
		
		if resourceName == "metal" and threshold > 0 then
			local remainingThreshold = math.max(0, threshold - cumulativeSent)
			untaxedPortion = math.min(amount, remainingThreshold)
			taxablePortion = amount - untaxedPortion
		end
		
		local taxAmount = taxablePortion * taxRate
		local actualReceived = amount - taxAmount
		
		return {
			actualSent = amount,
			actualReceived = actualReceived,
			untaxedPortion = untaxedPortion,
			taxablePortion = taxablePortion,
			taxAmount = taxAmount
		}
	end
	
	function Tax.calculateTaxRate(baseRate, modifiers)
		modifiers = modifiers or {}
		local rate = baseRate or 0
		
		if modifiers.allyBonus then
			rate = rate * 0.5 -- 50% reduction for allies
		end
		if modifiers.earlyGameBonus and modifiers.gameTime and modifiers.gameTime < 300 then
			rate = rate * 0.25 -- 75% reduction in first 5 minutes
		end
		
		return math.max(0, math.min(1, rate)) -- Clamp between 0 and 1
	end
	
	return Tax
end

function test()
	local Tax = VFS.Include("luarules/gadgets/team_transfer/resource_share_tax.lua")
	
	local metalResult = Tax.computeTransfer("metal", 1000, 0.1, 500, 0)
	assert(metalResult.actualSent == 1000, "Should send full amount")
	assert(metalResult.untaxedPortion == 500, "Should use threshold for untaxed portion")
	assert(metalResult.taxablePortion == 500, "Should calculate taxable portion")
	assert(metalResult.taxAmount == 50, "Should calculate 10% tax on taxable portion")
	assert(metalResult.actualReceived == 950, "Should receive amount minus tax")
	
	local metalResult2 = Tax.computeTransfer("metal", 300, 0.1, 500, 200)
	assert(metalResult2.untaxedPortion == 300, "Should use remaining threshold")
	assert(metalResult2.taxablePortion == 0, "Should have no taxable portion")
	assert(metalResult2.taxAmount == 0, "Should have no tax")
	assert(metalResult2.actualReceived == 300, "Should receive full amount")
	
	local metalResult3 = Tax.computeTransfer("metal", 400, 0.1, 500, 450)
	assert(metalResult3.untaxedPortion == 50, "Should use remaining threshold")
	assert(metalResult3.taxablePortion == 350, "Should calculate correct taxable portion")
	assert(metalResult3.taxAmount == 35, "Should calculate tax on excess")
	assert(metalResult3.actualReceived == 365, "Should receive amount minus tax")
	
	local energyResult = Tax.computeTransfer("energy", 1000, 0.1)
	assert(energyResult.actualSent == 1000, "Should send full amount")
	assert(energyResult.untaxedPortion == 0, "Energy should have no untaxed portion")
	assert(energyResult.taxablePortion == 1000, "Energy should be fully taxable")
	assert(energyResult.taxAmount == 100, "Should calculate 10% tax")
	assert(energyResult.actualReceived == 900, "Should receive amount minus tax")
	
	local zeroResult = Tax.computeTransfer("metal", 0, 0.1, 500, 0)
	assert(zeroResult.actualSent == 0, "Zero amount should result in zero transfer")
	assert(zeroResult.actualReceived == 0, "Zero amount should result in zero received")
	assert(zeroResult.taxAmount == 0, "Zero amount should result in zero tax")
	
	local negativeResult = Tax.computeTransfer("metal", -100, 0.1, 500, 0)
	assert(negativeResult.actualSent == 0, "Negative amount should be treated as zero")
	assert(negativeResult.actualReceived == 0, "Negative amount should result in zero received")
	
	local highTaxResult = Tax.computeTransfer("energy", 1000, 0.9)
	assert(highTaxResult.taxAmount == 900, "Should calculate 90% tax")
	assert(highTaxResult.actualReceived == 100, "Should receive 10% of amount")
	
	local noTaxResult = Tax.computeTransfer("energy", 1000, 0)
	assert(noTaxResult.taxAmount == 0, "Should have no tax")
	assert(noTaxResult.actualReceived == 1000, "Should receive full amount")
	
	local baseRate = 0.2
	local normalRate = Tax.calculateTaxRate(baseRate, {})
	assert(normalRate == 0.2, "Should return base rate with no modifiers")
	
	local allyRate = Tax.calculateTaxRate(baseRate, { allyBonus = true })
	assert(allyRate == 0.1, "Should apply 50% ally bonus")
	
	local earlyGameRate = Tax.calculateTaxRate(baseRate, { earlyGameBonus = true, gameTime = 200 })
	assert(earlyGameRate == 0.05, "Should apply early game bonus")
	
	local lateGameRate = Tax.calculateTaxRate(baseRate, { earlyGameBonus = true, gameTime = 400 })
	assert(lateGameRate == 0.2, "Should not apply early game bonus after 5 minutes")
	
	local clampedLow = Tax.calculateTaxRate(-0.1, {})
	assert(clampedLow == 0, "Should clamp negative rates to 0")
	
	local clampedHigh = Tax.calculateTaxRate(1.5, {})
	assert(clampedHigh == 1, "Should clamp rates above 1 to 1")
	
	local transfer1 = Tax.computeTransfer("metal", 400, 0.15, 500, 0)
	assert(transfer1.untaxedPortion == 400, "First transfer should be fully untaxed")
	
	local transfer2 = Tax.computeTransfer("metal", 300, 0.15, 500, 400)
	assert(transfer2.untaxedPortion == 100, "Second transfer should use remaining threshold")
	assert(transfer2.taxablePortion == 200, "Second transfer should tax excess")
	assert(transfer2.taxAmount == 30, "Should calculate 15% tax on 200")
	assert(transfer2.actualReceived == 270, "Should receive 300 - 30 tax")
end
