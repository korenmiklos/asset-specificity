use "Data/PacerRecovery_detail.dta", clear

keep sic2 RecoveryPPEMid RecoveryInventoryMid RecoveryReceivableMid RecoveryIntanMid RecoveryIntanNGWMid ValuationMidpoint

* unweighted
collapse (mean) RecoveryPPEMid RecoveryInventoryMid RecoveryReceivableMid RecoveryIntanMid RecoveryIntanNGWMid, by(sic2)

label var RecoveryPPEMid "PPE"
label var RecoveryInventoryMid "Inventory"
label var RecoveryReceivableMid "Receivable"
label var RecoveryIntanMid "Book intangible"
label var RecoveryIntanNGWMid "Non-goodwill book intangible"

list