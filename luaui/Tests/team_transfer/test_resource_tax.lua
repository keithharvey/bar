function skip()
	return Spring.GetGameFrame() <= 0
end

function setup()
	Test.clearMap()
end

function cleanup()
	Test.clearMap()
end

function test()
	local tax = GG.TeamTransfer.ResourceShareTax
	assert(tax ~= nil, "ResourceShareTax should be exposed")
	
	local result = tax.computeTransfer("metal", 1000, 0.1, 500, 0)
	assert(result.actualSent > 0, "Should calculate sent amount")
	assert(result.actualReceived > 0, "Should calculate received amount")
	assert(result.untaxedPortion == 500, "Should use threshold for untaxed portion")
	assert(result.taxablePortion == 500, "Should calculate taxable portion")
	assert(result.taxAmount == 50, "Should calculate 10% tax on taxable portion")
	assert(result.actualReceived == 950, "Should receive 1000 - 50 tax")
	assert(result.newCumulativeSent == 1000, "Should update cumulative sent")
	
	local energyResult = tax.computeTransfer("energy", 1000, 0.1)
	assert(energyResult.actualReceived == 900, "Should apply 10% tax to energy")
	assert(energyResult.untaxedPortion == 0, "Energy should have no untaxed portion")
	assert(energyResult.taxablePortion == 1000, "All energy should be taxable")
	assert(energyResult.taxAmount == 100, "Should calculate 10% tax on full amount")
	
	local zeroResult = tax.computeTransfer("metal", 0, 0.1, 500, 0)
	assert(zeroResult.actualSent == 0, "Zero amount should result in zero transfer")
	assert(zeroResult.actualReceived == 0, "Zero amount should result in zero received")
	assert(zeroResult.untaxedPortion == 0, "Zero amount should have no untaxed portion")
	assert(zeroResult.taxablePortion == 0, "Zero amount should have no taxable portion")
	
	local cumulativeResult = tax.computeTransfer("metal", 1000, 0.1, 500, 300)
	assert(cumulativeResult.untaxedPortion == 200, "Should use remaining threshold (500-300)")
	assert(cumulativeResult.taxablePortion == 800, "Should tax the excess (1000-200)")
	assert(cumulativeResult.taxAmount == 80, "Should calculate 10% tax on 800")
	assert(cumulativeResult.actualReceived == 920, "Should receive 1000 - 80 tax")
	
	local exceededResult = tax.computeTransfer("metal", 1000, 0.1, 500, 600)
	assert(exceededResult.untaxedPortion == 0, "Should have no untaxed portion when threshold exceeded")
	assert(exceededResult.taxablePortion == 1000, "Should tax full amount when threshold exceeded")
	assert(exceededResult.taxAmount == 100, "Should calculate 10% tax on full amount")
	assert(exceededResult.actualReceived == 900, "Should receive 1000 - 100 tax")
end
