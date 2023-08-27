clear all

set matsize 11000
set more off, permanently

if 1 | ("`c(username)'" == "yueranma") |  ("`c(username)'" == "Yueran Ma")  |  ("`c(username)'" == "sony") {
	global DATA "./Data"
	global BEA "$DATA/BEA"
	global CRSP "$DATA/CRSP"
	global CSTAT "$DATA/Compustat"
	global PACER "$DATA//PACER"
	global FIGURES "./Figures"
	global TABLES "./Tables"
}

/* Baseline Results Using Annual Data */

use "$CRSP/CCM_qtr.dta", clear

ren *, lower

gen order = 1 if linktype == "LC"
replace order = 2 if linktype == "LU"
replace order = 3 if linktype == "LN"
replace order = 4 if order ==.

bysort gvkey datadate: egen order_min = min(order)
keep if order == order_min

duplicates drop gvkey datadate, force
destring gvkey, replace

tempfile ccm
save "`ccm'"

use  "$DATA/PacerRecovery_detail.dta", clear

gen sic3 = floor(sic/10)

collapse (mean) Recovery*   , by(sic3)

ren Recovery* Recovery*3

drop if sic3==.

tempfile recovery3d
save "`recovery3d'"

use  "$DATA/PacerRecovery.dta", clear

xtile PPEtile = RecoveryPPEMid, nq(3)
xtile Inventorytile = RecoveryInventoryMid, nq(3)

tempfile recovery
save "`recovery'"

use  "$DATA/PacerRecovery_detail.dta", clear

set seed 12345   
sort filing_date
gen tmp1 = 1 if RecoveryPPEMid!=. | RecoveryInventoryMid!=.
gen tmp2 = runiform(0, 1) if tmp1 !=. 
bysort sic2: egen tmp3 = median(tmp2)  if tmp1 !=.
 
foreach item in RecoveryPPEMid  {
gen `item'G1 = `item' if tmp2<=tmp3
gen `item'G2 = `item' if tmp2>tmp3
}

drop tmp*

collapse (mean) Recovery*G1 Recovery*G2 (count) NRecoveryPPEMid = RecoveryPPEMid  , by(sic2)

tempfile recovery1
save "`recovery1'"

******************************************

use "$CSTAT/compustat_ann_out.dta", clear

destring gvkey, replace
drop if year>2018
drop if year<1985
drop if sic>=6000 & sic<7000
drop if sic>=9000 & sic!=.

merge m:1 sic2 using "`recovery'", keep(1 3) keepusing(Recovery*Mid *tile*)
tab _merge
drop _merge

merge m:1 sic2 using "`recovery1'", keep(1 3)  
tab _merge
drop _merge

merge m:1 sic2 using "$DATA/RecoveryPhysicsFA97_sic2.dta", keep(1 3) keepusing(PRecovery*Mid)
tab _merge
drop _merge

merge m:1 sic3 using "`recovery3d'", keep(1 3)  
tab _merge
drop _merge

merge 1:1 gvkey datadate using "`ccm'", keep (1 3) keepusing(linktype *permno)
drop _merge
ren lpermno permno

merge m:1 permno year using "$CRSP/crsp_ann_out.dta", keep(1 3) 
tab _merge
drop _merge

foreach item of varlist sd_ret_ann mean_ret_ann  {
bysort year: egen tmp_ph=pctile(`item'), p(99)
bysort year: egen tmp_pl=pctile(`item'), p(1)
replace `item'=. if `item'>tmp_ph 
replace `item'=. if `item'<tmp_pl 
drop tmp_* 
}

xtset

gen ppesold = 0 if sppe==0
replace ppesold = 1 if sppe>0 & sppe!=.

egen ind_t = group(sic2 year)

replace RecoveryPPEMid = RecoveryPPEMid/100
replace RecoveryPPEMid3 = RecoveryPPEMid3/100
replace RecoveryPPEMidG1 = RecoveryPPEMidG1/100
replace RecoveryPPEMidG2 = RecoveryPPEMidG2/100
replace PRecoveryPPEMid = PRecoveryPPEMid/100
replace RecoveryInventoryMid = RecoveryInventoryMid/100

label var sd_ret_ann "Vol"
 
label var RecoveryPPEMid "PPE liquidation recovery rate"
label var PRecoveryPPEMid "Predicted PPE liquidation recovery rate"
label var RecoveryInventoryMid "Invt liquidation recovery rate"
label var Q "Q"
label var lev1 "Debt/assets"
label var cash_at "Cash/assets"
label var ebitda_at "EBITDA/l.assets"
label var lnsize "Log(assets)"

eststo clear
xtset

* PPE Sale *

local control "Q lev1 cash_at ebitda_at lnsize " 
eststo: reghdfe  f.ppesold  RecoveryPPEMid `control'   , noa cluster(sic2 year)
eststo: reghdfe f.ppesold  PRecoveryPPEMid `control' if RecoveryPPEMid!=., noa  cluster(sic2 year)

preserve
collapse (mean) ppesold RecoveryPPEMid PRecoveryPPEMid, by(sic2)
eststo: reg  ppesold  RecoveryPPEMid, robust
eststo: reg  ppesold  PRecoveryPPEMid if RecoveryPPEMid!=.,  robust

twoway (scatter ppesold RecoveryPPEMid) (lfit ppesold RecoveryPPEMid), legend(off) graphregion(color(white)) xtitle("PPE Liquidation Recovery Rate") ytitle("Annual % of Firms Selling PPE")
graph export "$FIGURES/FigureI_PanelA.pdf", replace as(pdf)

twoway (scatter ppesold PRecoveryPPEMid) (lfit ppesold PRecoveryPPEMid) , legend(off) graphregion(color(white)) xtitle("Predicted PPE Liquidation Recovery Rate") ytitle("Annual % of Firms Selling PPE")  
graph export "$FIGURES/FigureI_PanelB.pdf", replace as(pdf)
restore

#delimit ;
estout using "$TABLES/TableV.tex", replace style(tex) 
label mlabels(none) cells(b(fmt(3) star ) se(fmt(3) par)) 
keep(RecoveryPPEMid PRecoveryPPEMid Q lev1 cash_at ebitda_at lnsize) 
order(RecoveryPPEMid PRecoveryPPEMid Q lev1 cash_at ebitda_at lnsize )
starlevels(* .10 ** .05 *** .01)  collabels(none);

estout using "$TABLES/TableV_r2.tex", replace style(tex) 
cells(none) 
stats(N r2, fmt(%9.0fc %9.2f) labels("Obs" "R$^2$" ) ) 
mlabels(none) collabels(none);
#delimit cr

* Basic Investment Irreversibility Regressions *

xtset

label var sd_ret_ann "Vol"

eststo clear

local control "Q lev1 cash_at ebitda_at lnsize"  
eststo: reghdfe f.capx_ppent c.sd_ret_ann##c.RecoveryPPEMid  c.mean_ret_ann##c.RecoveryPPEMid `control' , absorb(gvkey ind_t) cluster(sic2 year)

eststo: reghdfe f.invtgr c.sd_ret_ann##c.RecoveryInventoryMid  c.mean_ret_ann##c.RecoveryInventoryMid `control' , absorb(gvkey ind_t) cluster(sic2 year)

#delimit ;
estout using "$TABLES/TableVI_PanelA.tex", replace style(tex) 
label mlabels(none) cells(b(fmt(2) star ) se(fmt(2) par)) 
keep(sd_ret_ann c.sd_ret_ann#c.RecoveryPPEMid c.sd_ret_ann#c.RecoveryInventoryMid ) 
order(sd_ret_ann c.sd_ret_ann#c.RecoveryPPEMid c.sd_ret_ann#c.RecoveryInventoryMid )
starlevels(* .10 ** .05 *** .01)  collabels(none);

estout using "$TABLES/TableVI_PanelA_r2.tex", replace style(tex) 
cells(none) 
stats(N r2_within, fmt(%9.0fc %9.2f) labels("Obs" "R$^2$" ) ) 
mlabels(none) collabels(none);
#delimit cr

 
eststo clear

local control "Q lev1 cash_at ebitda_at lnsize"  
eststo: reghdfe f.capx_ppent c.sd_ret_ann##c.RecoveryPPEMid  c.mean_ret_ann##c.RecoveryPPEMid c.sd_ret_ann##c.RecoveryInventoryMid  c.mean_ret_ann##c.RecoveryInventoryMid `control' , absorb(gvkey ind_t) cluster(sic2 year)

eststo: reghdfe f.invtgr c.sd_ret_ann##c.RecoveryPPEMid  c.mean_ret_ann##c.RecoveryPPEMid c.sd_ret_ann##c.RecoveryInventoryMid  c.mean_ret_ann##c.RecoveryInventoryMid `control' , absorb(gvkey ind_t ) cluster(sic2 year)

eststo: reghdfe f.empgr c.sd_ret_ann##c.RecoveryPPEMid  c.mean_ret_ann##c.RecoveryPPEMid c.sd_ret_ann##c.RecoveryInventoryMid  c.mean_ret_ann##c.RecoveryInventoryMid `control' , absorb(gvkey ind_t) cluster(sic2 year)

#delimit ;
estout using "$TABLES/TableVI_PanelB.tex", replace style(tex) 
label mlabels(none) cells(b(fmt(2) star ) se(fmt(2) par)) 
keep(sd_ret_ann c.sd_ret_ann#c.RecoveryPPEMid c.sd_ret_ann#c.RecoveryInventoryMid ) 
order(sd_ret_ann c.sd_ret_ann#c.RecoveryPPEMid c.sd_ret_ann#c.RecoveryInventoryMid)
starlevels(* .10 ** .05 *** .01)  collabels(none);

estout using "$TABLES/TableVI_PanelB_r2.tex", replace style(tex) 
cells(none) 
stats(N r2_within, fmt(%9.0fc %9.2f) labels("Obs" "R$^2$" ) ) 
mlabels(none) collabels(none);
#delimit cr


* Robustness Checks * 

eststo clear

label var sd_ret_ann "Vol"
 
label var RecoveryPPEMid "PPE liquidation recovery rate"
label var PRecoveryPPEMid "Predicted PPE liquidation recovery rate"
label var RecoveryPPEMid3 "PPE liquidation recovery rate (3-digit)"
label var RecoveryPPEMidG1 "PPE liquidation recovery rate (random half)"
label var Q "Q"
label var lev1 "Debt/assets"
label var cash_at "Cash/assets"
label var ebitda_at "EBITDA/l.assets"
label var lnsize "Log(assets)"
label var ppent_at "Net PPE/assets"

local control "Q lev1 cash_at ebitda_at lnsize "
eststo: reghdfe f.capx_ppent c.sd_ret_ann##c.RecoveryPPEMid3  c.mean_ret_ann##c.RecoveryPPEMid3   `control' , absorb(gvkey ind_t) cluster(sic2 year)

eststo: reghdfe f.capx_ppent    c.sd_ret_ann##c.PRecoveryPPEMid c.mean_ret_ann##c.PRecoveryPPEMid   `control' if RecoveryPPEMid!=., absorb(gvkey ind_t) cluster(sic2 year) 

eststo: ivreghdfe f.capx_ppent sd_ret_ann mean_ret_ann (c.sd_ret_ann#c.RecoveryPPEMidG1 RecoveryPPEMidG1  c.mean_ret_ann#c.RecoveryPPEMidG1 RecoveryPPEMidG1 = c.sd_ret_ann#c.RecoveryPPEMidG2  RecoveryPPEMidG2    c.mean_ret_ann#c.RecoveryPPEMidG2  RecoveryPPEMidG2) `control' if NRecoveryPPEMid>5, absorb(gvkey ind_t) cluster(sic2 year)   

eststo: reghdfe f.capx_ppent c.sd_ret_ann##c.RecoveryPPEMid  c.mean_ret_ann##c.RecoveryPPEMid   c.sd_ret_ann##c.ppent_at c.mean_ret_ann##c.ppent_at `control' , absorb(gvkey ind_t) cluster(sic2 year)

#delimit ;
estout using "$TABLES/TableVII.tex", replace style(tex) 
label mlabels(none) cells(b(fmt(2) star ) se(fmt(2) par)) 
keep(sd_ret_ann c.sd_ret_ann#c.RecoveryPPEMid3 c.sd_ret_ann#c.PRecoveryPPEMid c.sd_ret_ann#c.RecoveryPPEMidG1 ppent_at c.sd_ret_ann#c.ppent_at) 
order(sd_ret_ann c.sd_ret_ann#c.RecoveryPPEMid3 c.sd_ret_ann#c.PRecoveryPPEMid c.sd_ret_ann#c.RecoveryPPEMidG1 ppent_at c.sd_ret_ann#c.ppent_at)
starlevels(* .10 ** .05 *** .01)  collabels(none);

estout using "$TABLES/TableVII_r2.tex", replace style(tex) 
cells(none) 
stats(N r2_within, fmt(%9.0fc %9.2f) labels("Obs" "R$^2$" ) ) 
mlabels(none) collabels(none);
#delimit cr

* Summary Statistics *

label var capx_ppent "CAPX/l.PPE"
label var invtgr "Annual inventory growth"
label var empgr "Annual employment growth"

label var Q "Q"
label var lev1 "Debt/assets"
label var ebitda_at "EBITDA/l.assets"
label var cash_at "Cash/assets"
label var ppent_at "Net PPE/assets"
label var invt_at "Inventory/assets"

label var sd_ret_ann "Vol of daily returns"
label var mean_ret_ann "Mean of daily returns"

estpost tabstat capx_ppent invtgr empgr Q lev1 ebitda_at cash_at ppent_at invt_at sd_ret_ann mean_ret_ann if RecoveryPPEMid!=. , 	///
	stats(mean sd p25 p50 p75) columns(statistics)   
estout using "$TABLES/TableIA6.tex", replace style(tex) mlabels(none) nonumber collabels(none) cells("mean(fmt(3)) sd(fmt(3)) p25(fmt(3)) p50(fmt(3)) p75(fmt(3))") label


* Guiso-Parigi *

eststo clear

gen highspecificty =  PPEtile==1

label var sd_ret_ann "Vol"
label var mean_ret_ann "Level"
label var highspecificty "Low PPE liq val"
label var capx_ppent "Lagged investment rate"
 
eststo clear

eststo: reghdfe f.capx_ppent capx_ppent c.sd_ret_ann##c.mean_ret_ann if RecoveryPPEMid!=., noa cluster(sic2 year)
eststo: reghdfe f.capx_ppent capx_ppent c.sd_ret_ann##c.mean_ret_ann if PPEtile==1, noa  cluster(sic2 year)
eststo: reghdfe f.capx_ppent capx_ppent c.sd_ret_ann##c.mean_ret_ann if PPEtile==3, noa  cluster(sic2 year)
eststo: reghdfe f.capx_ppent capx_ppent c.sd_ret_ann##c.mean_ret_ann##c.highspecificty if RecoveryPPEMid!=., noa  cluster(sic2 year)

#delimit ;
estout using "$TABLES/TableIA8.tex", replace style(tex) 
label mlabels(none) cells(b(fmt(2) star ) se(fmt(2) par)) 
keep(c.sd_ret_ann#c.mean_ret_ann c.sd_ret_ann#c.mean_ret_ann#c.highspecificty  sd_ret_ann c.sd_ret_ann#c.highspecificty mean_ret_ann  c.mean_ret_ann#c.highspecificty highspecificty capx_ppent) 
order(c.sd_ret_ann#c.mean_ret_ann c.sd_ret_ann#c.mean_ret_ann#c.highspecificty  sd_ret_ann c.sd_ret_ann#c.highspecificty mean_ret_ann  c.mean_ret_ann#c.highspecificty highspecificty capx_ppent)
starlevels(* .10 ** .05 *** .01)  collabels(none);

estout using "$TABLES/TableIA8_r2.tex", replace style(tex) 
cells(none) 
stats(N r2_within, fmt(%9.0fc %9.2f) labels("Obs" "R$^2$" ) ) 
mlabels(none) collabels(none);
#delimit cr


/* Additional Results using Quarterly Data */

use "$CRSP/CCM_qtr.dta", clear

ren *, lower

gen order = 1 if linktype == "LC"
replace order = 2 if linktype == "LU"
replace order = 3 if linktype == "LN"
replace order = 4 if order ==.

bysort gvkey datadate: egen order_min = min(order)
keep if order == order_min

duplicates drop gvkey datadate, force
destring gvkey, replace

tempfile ccm
save "`ccm'"

use  "$DATA/PacerRecovery_detail.dta", clear

gen sic3 = floor(sic/10)

collapse (mean) Recovery*   , by(sic3)

ren Recovery* Recovery*3

drop if sic3==.

tempfile recovery3d
save "`recovery3d'"

use  "$DATA/PacerRecovery_detail.dta", clear

set seed 12345   
sort filing_date
gen tmp1 = 1 if RecoveryPPEMid!=. | RecoveryInventoryMid!=.
gen tmp2 = runiform(0, 1) if tmp1 !=. 
bysort sic2: egen tmp3 = median(tmp2)  if tmp1 !=.
 
foreach item in RecoveryPPEMid  {
gen `item'G1 = `item' if tmp2<=tmp3
gen `item'G2 = `item' if tmp2>tmp3
}

drop tmp*

collapse (mean) Recovery*G1 Recovery*G2 (count) NRecoveryPPEMid = RecoveryPPEMid  , by(sic2)

tempfile recovery1
save "`recovery1'"
	
