use "Data/PacerRecovery_detail.dta", clear

keep sic2 RecoveryPPEMid RecoveryInventoryMid RecoveryReceivableMid RecoveryIntanMid RecoveryIntanNGWMid ValuationMidpoint

* weight by valuation
collapse (mean) RecoveryPPEMid RecoveryInventoryMid RecoveryReceivableMid RecoveryIntanMid RecoveryIntanNGWMid [w=ValuationMidpoint], by(sic2)

label var RecoveryPPEMid "PPE"
label var RecoveryInventoryMid "Inventory"
label var RecoveryReceivableMid "Receivable"
label var RecoveryIntanMid "Book intangible"
label var RecoveryIntanNGWMid "Non-goodwill book intangible"

list

save "Data/PacerRecovery.dta", replace