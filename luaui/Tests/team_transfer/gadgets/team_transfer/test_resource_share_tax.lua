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
	
	local function sanitizeNumber(n, fallback)
		if type(n) ~= 'number' or n ~= n then
			return fallback or 0
		end
		return n
	end

	function Tax.computeTransfer(resourceName, amount, taxRate, threshold, cumulativeSent)
		resourceName = resourceName == 'm' and 'metal' or (resourceName == 'e' and 'energy' or resourceName)
		amount = sanitizeNumber(amount, 0)
		if amount < 0 then amount = 0 end
		taxRate = sanitizeNumber(taxRate, 0)
		if taxRate < 0 then taxRate = 0 end
		if taxRate > 1 then taxRate = 1 end
		threshold = sanitizeNumber(threshold, 0)
		cumulativeSent = sanitizeNumber(cumulativeSent, 0)

		local actualSent = 0
		local actualReceived = 0
		local untaxedPortion = 0
		local taxablePortion = 0
		local allowanceRemaining = 0
		local newCumulative = nil

		if resourceName == 'metal' and threshold > 0 then
			allowanceRemaining = math.max(0, threshold - cumulativeSent)
			untaxedPortion = math.min(amount, allowanceRemaining)
		taxablePortion = amount - untaxedPortion
		if taxablePortion > 0 then
			local taxedPortionReceived = taxablePortion * (1 - taxRate)
			local taxedPortionSent
			if taxRate == 1 then
				taxedPortionSent = taxablePortion
			else
				taxedPortionSent = taxablePortion / (1 - taxRate)
			end
			actualReceived = untaxedPortion + taxedPortionReceived
			actualSent = untaxedPortion + taxedPortionSent
		else
			actualReceived = untaxedPortion
			actualSent = untaxedPortion
		end
			newCumulative = cumulativeSent + actualSent
		else
			actualReceived = amount * (1 - taxRate)
			if taxRate == 1 then
				actualSent = amount
			else
				actualSent = (1 - taxRate) > 0 and (actualReceived / (1 - taxRate)) or amount
			end
			untaxedPortion = 0
			taxablePortion = amount
			allowanceRemaining = 0
		end

		return {
			actualSent = actualSent,
			actualReceived = actualReceived,
			untaxedPortion = untaxedPortion,
			taxablePortion = taxablePortion,
			allowanceRemaining = allowanceRemaining,
			newCumulative = newCumulative,
		}
	end
	
	return Tax
end

function test()
	local Tax = VFS.Include("luarules/gadgets/team_transfer/resource_share_tax.lua")
	
	local metalResult = Tax.computeTransfer("metal", 1000, 0.1, 500, 0)
	assert(math.abs(metalResult.actualSent - 1055.56) < 0.1, "Should send amount adjusted for tax calculation")
	assert(metalResult.untaxedPortion == 500, "Should use threshold for untaxed portion")
	assert(metalResult.taxablePortion == 500, "Should calculate taxable portion")
	assert(math.abs(metalResult.actualReceived - 950) < 0.1, "Should receive 500 untaxed + 450 after 10% tax on 500")
	assert(metalResult.allowanceRemaining == 500, "Should calculate remaining allowance")
	assert(math.abs(metalResult.newCumulative - 1055.56) < 0.1, "Should update cumulative with actual sent amount")
	
	local metalResult2 = Tax.computeTransfer("metal", 300, 0.1, 500, 200)
	assert(metalResult2.untaxedPortion == 300, "Should use remaining threshold")
	assert(metalResult2.taxablePortion == 0, "Should have no taxable portion")
	assert(metalResult2.actualReceived == 300, "Should receive full amount")
	assert(metalResult2.allowanceRemaining == 300, "Should calculate correct remaining allowance")
	
	local energyResult = Tax.computeTransfer("energy", 1000, 0.1)
	assert(energyResult.actualSent == 1000, "Should send full amount for energy")
	assert(energyResult.untaxedPortion == 0, "Energy should have no untaxed portion")
	assert(energyResult.taxablePortion == 1000, "Energy should be fully taxable")
	assert(energyResult.actualReceived == 900, "Should receive amount minus tax")
	assert(energyResult.allowanceRemaining == 0, "Energy should have no allowance")
	
	local zeroResult = Tax.computeTransfer("metal", 0, 0.1, 500, 0)
	assert(zeroResult.actualSent == 0, "Zero amount should result in zero transfer")
	assert(zeroResult.actualReceived == 0, "Zero amount should result in zero received")
	
	local negativeResult = Tax.computeTransfer("metal", -100, 0.1, 500, 0)
	assert(negativeResult.actualSent == 0, "Negative amount should be treated as zero")
	assert(negativeResult.actualReceived == 0, "Negative amount should result in zero received")
	
	local highTaxResult = Tax.computeTransfer("energy", 1000, 0.9)
	assert(math.abs(highTaxResult.actualReceived - 100) < 0.1, "Should receive 10% of amount with 90% tax")
	assert(math.abs(highTaxResult.actualSent - 1000) < 0.1, "Should send full amount even with high tax")
	
	local noTaxResult = Tax.computeTransfer("energy", 1000, 0)
	assert(noTaxResult.actualReceived == 1000, "Should receive full amount with no tax")
	assert(noTaxResult.actualSent == 1000, "Should send full amount with no tax")
	
	local shortFormMetal = Tax.computeTransfer("m", 100, 0.1, 50, 0)
	assert(shortFormMetal.untaxedPortion == 50, "Should handle short form metal")
	
	local shortFormEnergy = Tax.computeTransfer("e", 100, 0.1)
	assert(shortFormEnergy.actualReceived == 90, "Should handle short form energy")
	
	local nanResult = Tax.computeTransfer("metal", 0/0, 0.1, 500, 0)
	assert(nanResult.actualSent == 0, "Should handle NaN input")
	
	local clampedTaxResult = Tax.computeTransfer("energy", 100, 1.5)
	assert(clampedTaxResult.actualReceived == 0, "Should clamp tax rate above 1")
end
