clear all

set matsize 11000
set more off, permanently

if ("`c(username)'" == "yueranma") |  ("`c(username)'" == "Yueran Ma")  |  ("`c(username)'" == "sony") {
	global DATA "../Data"
	global BEA "$DATA/BEA"
	global CSTAT "$DATA/Compustat"
	global PACER "$DATA//PACER"
	global FIGURES "../Figures"
	global TABLES "../Tables"
}


******************************************************
* set graph style
grstyle init
grstyle set plain, horizontal grid
grstyle set legend 6, nobox
grstyle set symbol
******************************************************

/* Total Liquidation Value of Compustat Firms */

use "$CSTAT/compustat_ann_out.dta", clear

destring gvkey, replace

drop if year>2016
drop if year<1990
drop if sic>=6000 & sic<7000
drop if sic<1000
drop if sic>=9000

merge m:1 sic2 using "$DATA/PacerRecovery.dta", keep(1 3) keepusing(Recovery*Mid*)
tab _merge
drop _merge

gen tev = dltt + dlc + mkval 
label var tev "Total enterprise value of firm"

gen tcash = che
gen tliqrect = rect*RecoveryReceivableMid/100 
label var tliqrect "Total receivable liquidation value"
gen tliqinvt = invt*RecoveryInventoryMid/100
label var tliqinvt "Total inventory liquidation value"
gen tliqppe = ppent*RecoveryPPEMid/100
label var tliqppe "Total PPE liquidation value"
gen tliqintan = (intan-gdwl)*RecoveryIntanNGWMid/100
replace tliqintan = (intan)*RecoveryIntanMid/100 if gdwl==.
label var tliqintan "Total book intangible liquidation value"

gen liqval = ppent_at*RecoveryPPEMid/100 + invt_at*RecoveryInventoryMid/100 + rect_at*RecoveryReceivableMid/100
keep if liqval!=.

collapse (sum) tliq* tcash at tev, by(year)

foreach item of varlist tliq* tcash {
gen `item'_tev = `item'/tev
gen `item'_at = `item'/at
}

graph bar  tliqintan_at tliqppe_at tliqinvt_at tliqrect_at tcash_at if year==1990 | year==2003 | year==2016,  graphregion(color(white)) over(year, label(labsize(small))) ylabel(0 (0.2) 1)   legend(order(1 "Book Intangible" 2 "PPE" 3 "Inventory" 4 "Receivable" 5 "Cash" ))  stack bar(2, color(purple*0.75))
graph export "$FIGURES/FigureII.pdf", as(pdf) replace


/* Including Off-Balance Sheet Intangible Assets */

use "$CSTAT/compustat_ann_latest_out.dta", clear

destring gvkey, replace

drop if year>2016
drop if year<1990
gen sic2 = floor(sic/100)
gen sic3 = floor(sic/10)
drop if sic>=6000 & sic<7000
drop if sic>=9000
cap gen lnsize = log(at)

merge m:1 sic2 using "$DATA/PACER/PacerRecovery.dta", keep(1 3) keepusing(*Recovery*Mid*)
tab _merge
drop _merge

merge 1:1 gvkey fyear using "$DATA/Compustat/PetersTaylor.dta", keep(1 3) keepusing(k_* q_*)
tab _merge
drop _merge

replace at = at + k_int_offbs
keep if at!=.

gen tcash = che
gen tliqrect = rect*RecoveryReceivableMid/100 
label var tliqrect "Total receivable liquidation value"
gen tliqinvt = invt*RecoveryInventoryMid/100
label var tliqinvt "Total inventory liquidation value"
gen tliqppe = ppent*RecoveryPPEMid/100
label var tliqppe "Total PPE liquidation value"
gen tliqintan = (intan-gdwl)*RecoveryIntanNGWMid/100
replace tliqintan = (intan)*RecoveryIntanMid/100 if gdwl==.

gen liqval = ppent_at*RecoveryPPEMid/100 + invt_at*RecoveryInventoryMid/100 + rect_at*RecoveryReceivableMid/100
keep if liqval!=.

collapse (sum)  tcash  tliq* at , by(year)

foreach item of varlist tliq* tcash {
gen `item'_at = `item'/at
}

graph bar  tliqintan_at tliqppe_at tliqinvt_at tliqrect_at tcash_at if year==1990 | year==2003 | year==2016,  graphregion(color(white)) over(year, label(labsize(small))) ylabel(0 (0.2) 1)   legend(order(1 "Book Intangible" 2 "PPE" 3 "Inventory" 4 "Receivable" 5 "Cash" ))  stack bar(2, color(purple*0.75))
graph export "$FIGURES/FigureIA1.pdf", as(pdf) replace


/* Compare Liquidation Recovery Rates of PPE and Intangibles */

use "$DATA/PacerRecovery_detail.dta", clear

sicff sic , industry(12) generate(ff12)

collapse (mean) Recovery*Mid   , by(ff12)

label define ff12 1 "Consumer Non-Durables" 2 "Consumer Durables" 3 "Manufacturing" 4 "Energy" 5 "Chemicals" 6 "Business Equipment" 7 "Telecommunications" 8 "Utilities" 9 "Wholesale/Retail" 10 "Health Care" 11 "Finance" 12 "Others"
label values ff12 ff12

graph bar RecoveryPPEMid RecoveryIntanMid RecoveryIntanNGWMid, graphregion(color(white))  by(ff12, note("")) bargap(20) subtitle(, pos(6)) asyvars ytitle("Average Liquidation Recovery Rate") ylabel(0 (20) 100) legend(c(1)) legend(order(1 "PPE" 2 "Book Intangible" 3 "Non-goodwill book Intangible")) bar(1, color(purple*0.75)) bar(2, color(navy)) bar(3, color(navy*0.5)) 
graph export "$FIGURES/FigureIII.pdf", as(pdf) replace


/* Liquidation Recovery Rate and Change in Intangible Prevalence */

**********BEA Data***********

use "$DATA/BEA/BEAIP.dta", clear

collapse (sum) IP , by(sector year)

tempfile ip
save "`ip'"

use "$DATA/BEA/BEAFixedAsset.dta", clear

collapse (sum) K , by(sector year)

drop if substr(sector, 1, 2)=="52"

merge m:1 sector using "$DATA/RecoveryPhysicsFA97_bea.dta", keep(1 3) keepusing(RecoveryPPEMid PRecoveryPPEMid)
tab _merge
drop _merge

merge m:1 sector year using "`ip'", keep(1 3) 
tab _merge
drop _merge

gen IPshr = IP/(IP + K)

encode sector, gen (ID)

xtset ID year

gen Intanshrch = (IPshr - l26.IPshr)

replace RecoveryPPEMid = RecoveryPPEMid/100
replace PRecoveryPPEMid = PRecoveryPPEMid/100

label var RecoveryPPEMid "PPE liquidation recovery rate"
label var PRecoveryPPEMid "Predicted PPE liquidation recovery rate"

twoway (scatter Intanshrch RecoveryPPEMid) (lfit Intanshrch RecoveryPPEMid) if year==2016, graphregion(color(white)) legend(off) xtitle("PPE Liquidation Recovery Rate") ytitle("Intellectual Property Share: 2016 minus 1990")
graph export "$FIGURES/FigureIV_PanelA.pdf", replace as(pdf)

eststo clear

eststo: reg Intanshrch RecoveryPPEMid  if year==2016 , robust
eststo: reg Intanshrch PRecoveryPPEMid  if year==2016, robust

**********Compustat Data************

use "$DATA/Compustat/compustat_ann_out.dta", clear

drop if sic>=6000 & sic<7000
drop if sic>=9000 & sic!=.

merge 1:1 gvkey fyear using "$DATA/Compustat/PetersTaylor.dta", keep(1 3) keepusing(k_* q_*)
tab _merge
drop _merge

merge m:1 sic2 using "$DATA/RecoveryPhysicsFA97_sic2.dta", keep(1 3) keepusing(RecoveryPPEMid  PRecoveryPPEMid)
tab _merge
drop _merge

xtset
gen intanshr = k_int/(k_int+ppent)
gen Intanshrch = intanshr - l26.intanshr
 
replace RecoveryPPEMid = RecoveryPPEMid/100
replace PRecoveryPPEMid = PRecoveryPPEMid/100

label var RecoveryPPEMid "PPE liquidation recovery rate"
label var PRecoveryPPEMid "Predicted PPE liquidation recovery rate"

binscatter Intanshrch RecoveryPPEMid if year==2016, control(lnsize) legend(off) xtitle("PPE Liquidation Recovery Rate") ytitle("Intangible Share: 2016 minus 1990")
graph export "$FIGURES/FigureIV_PanelB.pdf", replace as(pdf)

eststo: reg Intanshrch RecoveryPPEMid  if year==2016, cluster(sic2)
eststo: reg Intanshrch PRecoveryPPEMid  if year==2016, cluster(sic2)

#delimit ;
estout using "$TABLES/TableIA9.tex", replace style(tex) 
label mlabels(none) cells(b(fmt(3) star ) se(fmt(3) par)) 
varlabels(_cons Constant) 
starlevels(* .10 ** .05 *** .01)  collabels(none);

estout using "$TABLES/TableIA9_r2.tex", replace style(tex) 
cells(none) 
stats(N r2, fmt(%9.0fc  %9.2f) labels("Obs" "R$^2$" ) ) 
mlabels(none) collabels(none);
#delimit cr

