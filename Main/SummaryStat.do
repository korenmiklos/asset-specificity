clear all

set matsize 11000
set more off, permanently

if ("`c(username)'" == "yueranma") |  ("`c(username)'" == "Yueran Ma")  |  ("`c(username)'" == "sony") {
	global DATA "../Data"
	global FIGURES "../Figures"
	global TABLES "../Tables"
}


/* Liquidation Recovery Rate by Industry */

use "$DATA/PacerRecovery.dta", clear

drop if sic2>=60 & sic2<70
drop if sic2<10

label var RecoveryPPEMid "PPE"
label var RecoveryInventoryMid "Inventory"
label var RecoveryReceivableMid "Receivable"
label var RecoveryIntanMid "Book intangible"
label var RecoveryIntanNGWMid "Non-goodwill book intangible"

format Recovery* %2.0f
estpost tabstat RecoveryPPEMid RecoveryInventoryMid RecoveryReceivableMid RecoveryIntanMid RecoveryIntanNGWMid, 	///
	stats(mean sd p25 p50 p75) columns(statistics)   
estout using "$TABLES/TableIII_PanelA.tex", replace style(tex) mlabels(none) nonumber collabels(none) cells("mean(fmt(2)) sd(fmt(2)) p25(fmt(2)) p50(fmt(2)) p75(fmt(2))") label

/* Firms in Ch11 Liquidation Analysis Sample */

use  "$DATA/PacerRecovery_detail.dta", clear

gen ratio1 = GrossLiquidationMid/TotalBookValue if RecoveryPPEMid!=. | RecoveryInventoryMid!=.
gen ratio2 = GrossLiquidationMid/GC2 if GC2_ato!=.

label var ratio1 "Total liquidation value/book assets"
label var ratio2 "Total liquidation value/going-concern value"

estpost tabstat ratio1 ratio2, stats(mean sd p25 p50 p75) columns(statistics)   
estout using "$TABLES/TableIII_PanelB_p1.tex", replace style(tex) mlabels(none) nonumber collabels(none) cells("mean(fmt(2)) sd(fmt(2)) p25(fmt(2)) p50(fmt(2)) p75(fmt(2))") label

/* Firms in Compustat */

use "$DATA/Compustat/compustat_ann_out.dta", clear

drop if year>2018
drop if year<2000

drop if sic>=6000 & sic<7000
drop if sic>=9000 & sic!=.

merge m:1 sic2 using "$DATA/PacerRecovery.dta", keep(1 3) keepusing(Recovery*Mid)
tab _merge
drop _merge

gen liqval = cash_at + (RecoveryReceivableMid/100)*rect_at + (RecoveryInventoryMid/100)*invt_at + (RecoveryPPEMid/100)*ppent_at + (RecoveryIntanNGWMid/100)*intano_at if year>=1996 & year<=2018
replace liqval = cash_at + (RecoveryReceivableMid/100)*rect_at + (RecoveryInventoryMid/100)*invt_at + (RecoveryPPEMid/100)*ppent_at + (RecoveryIntanMid/100)*intan_at if year>=1996 & year<=2018 & liqval == .
replace liqval = cash_at + (RecoveryReceivableMid/100)*rect_at + (RecoveryInventoryMid/100)*invt_at + (RecoveryPPEMid/100)*ppent_at if year >=1996 & year<=2018 & liqval == .

gen ratio1 = liqval
gen ratio2 = (liqval)*at/(mkval + dlc + dltt) if Q2!=.

label var ratio1 "Total liquidation value/book assets"
label var ratio2 "Total liquidation value/going-concern value"

estpost tabstat ratio1 ratio2, 	stats(mean sd p25 p50 p75) columns(statistics)   
estout using "$TABLES/TableIII_PanelB_p2.tex", replace style(tex) mlabels(none) nonumber collabels(none) cells("mean(fmt(2)) sd(fmt(2)) p25(fmt(2)) p50(fmt(2)) p75(fmt(2))") label
