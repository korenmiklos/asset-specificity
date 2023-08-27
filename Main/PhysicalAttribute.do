clear all

set matsize 11000
set more off, permanently

if 1 | ("`c(username)'" == "yueranma") |  ("`c(username)'" == "Yueran Ma")  |  ("`c(username)'" == "sony") {
	global DATA "./Data"
}


/* Physical Determinants */

use "$DATA/RecoveryPhysicsFA97_sic2.dta", clear

sum KEshr
local m = r(mean)
gen KEshr1 = KEshr - `m'

label var wtshare  "Transportation cost"
label var dp_ppent "Depreciation rate"
label var wdshares "Design cost share"
label var KEshr "Equipment share"
label var KEshr1 "Equipment share (demeaned)"
label var saleshrind "Industry size (sales share) "

foreach item of varlist RecoveryPPEMid* {
replace `item' = `item'/100
}

eststo clear

eststo: reg RecoveryPPEMid wtshare  wdshares dp_ppent  KEshr1, robust beta
eststo: reg RecoveryPPEMid wtshare  wdshares dp_ppent   KEshr1  saleshrind, robust beta


use "$DATA/RecoveryPhysicsFA97_bea.dta", clear

drop if RecoveryPPEMid==.
sum KEshr
local m = r(mean)
gen KEshr1 = KEshr - `m'

label var wtshare "Transportation cost"
label var dp_ppent "Depreciation rate"
label var wdshares "Design cost share"
label var KEshr "Equipment share"
label var KEshr1 "Equipment share (demeaned)"
label var VAshr "Industry size (value-added share)"

foreach item of varlist RecoveryPPEMid* {
replace `item' = `item'/100
}

eststo: reg RecoveryPPEMid  wtshare  wdshares dp_ppent   KEshr1 , robust
eststo: reg RecoveryPPEMid  wtshare  wdshares dp_ppent   KEshr1 VAshr , robust
 
#delimit ;
estout using "$TABLES/TableIV_PanelA.tex", replace style(tex) 
label mlabels(none) cells(b(fmt(2) star ) se(fmt(2) par)) 
varlabels(_cons Constant)  
starlevels(* .10 ** .05 *** .01)  collabels(none);

estout using "$TABLES/TableIV_PanelA_r2.tex", replace style(tex) 
cells(none) 
stats(N r2, fmt(%9.0fc %9.2f) labels("Obs" "R$^2$" ) ) 
mlabels(none) collabels(none);
#delimit cr

* Decomposing Contributions *

use "$DATA/RecoveryPhysicsFA97_sic2.dta", clear
 
reg RecoveryPPEMid  dp_ppent wdshares wtshare   KEshr , robust beta
gen insample = e(sample)
foreach item in dp_ppent wdshares wtshare  {
sum `item' if insample==1, detail 
local m`item' = r(mean)

display `m`item''*_b[`item']
}

display _b[KEshr] + _b[_cons] + `mdp_ppent'*_b[dp_ppent] + `mwdshares'*_b[wdshares]  + `mwtshare'*_b[wtshare]

sum  KEshr if insample==1, detail 
local mKEshr = r(mean)
display `mKEshr'*_b[KEshr] + _b[_cons]

/* Extra Depreciation */

use "$DATA/RecoveryPhysicsFA97_sic2.dta", clear

sum KEshr
local m = r(mean)
gen KEshr1 = KEshr - `m'

label var wtshare  "Transportation cost"
label var dp_ppent "Depreciation rate"
label var wdshares "Design cost share"
label var KEshr "Equipment share"
label var KEshr1 "Equipment share (demeaned)"
label var saleshrind "Industry size (sales share) "

foreach item of varlist RecoveryPPEMid* {
replace `item' = `item'/100
}

eststo clear

* NB: RecoveryPPEMidmod does not exist
eststo: reg RecoveryPPEMid wtshare  wdshares dp_ppent  KEshr1, robust beta
eststo: reg RecoveryPPEMid wtshare  wdshares dp_ppent  KEshr1  saleshrind, robust beta

use "$DATA/RecoveryPhysicsFA97_bea.dta", clear

sum KEshr
local m = r(mean)
gen KEshr1 = KEshr - `m'

label var wtshare "Transportation cost"
label var dp_ppent "Depreciation rate"
label var wdshares "Design cost share"
label var KEshr "Equipment share"
label var KEshr1 "Equipment share (demeaned)"
label var VAshr "Industry size (value-added share)"

foreach item of varlist RecoveryPPEMid* {
replace `item' = `item'/100
}

eststo: reg RecoveryPPEMid  wtshare  wdshares dp_ppent   KEshr1, robust
eststo: reg RecoveryPPEMid  wtshare  wdshares dp_ppent   KEshr1 VAshr, robust

* FIXME: TABLES macro not defined

#delimit ;
estout using "$TABLES/TableIA4.tex", replace style(tex) 
label mlabels(none) cells(b(fmt(2) star ) se(fmt(2) par)) 
varlabels(_cons Constant)  
starlevels(* .10 ** .05 *** .01)  collabels(none);

estout using "$TABLES/TableIA4_r2.tex", replace style(tex) 
cells(none) 
stats(N r2, fmt(%9.0fc %9.2f) labels("Obs" "R$^2$" ) ) 
mlabels(none) collabels(none);
#delimit cr

 
/* Checks for Physical Attributes */

use "$DATA/BEA/beafixedassetcomp.dta", clear

gen logavgmiles = log(avgmiles)
gen logvalue_weight = log(value_weight)
gen logweight_value = log(weight_value)

eststo clear
label var logweight_value "Log weight/value"
label var wholesaleshr_value "\% Shipment from wholesaler/retailer (value-weighted)"
label var wholesaleshr_wght "\% Shipment from wholesaler/retailer (weight-weighted)"
label var avgmiles "Average miles transported"
label var logavgmiles "Log average miles transported"

reg tshare logvalue_weight if year==1997 & sector=="110C", robust
eststo: reg tshare logweight_value if year==1997 & sector=="110C", robust
eststo: reg tshare logavgmiles if year==1997 & sector=="110C", robust

eststo: reg dshares wholesaleshr_value if year==1997 & sector=="110C", robust
eststo: reg dshares wholesaleshr_wght if year==1997 & sector=="110C", robust

#delimit ;
estout using "$TABLES/TableIA15.tex", replace style(tex) 
label mlabels(none) cells(b(fmt(3) star ) se(fmt(2) par)) 
varlabels(_cons Constant)  
starlevels(* .10 ** .05 *** .01)  collabels(none);

estout using "$TABLES/TableIA15_r2.tex", replace style(tex) 
cells(none) 
stats(N r2, fmt(%9.0fc %9.2f) labels("Obs" "R$^2$" ) ) 
mlabels(none) collabels(none);
#delimit cr


/* Physical Determinants Summary Statistics */

use "$DATA/RecoveryPhysicsFA97_sic2.dta", clear

eststo clear

label var wtshare  "Transportation cost"
label var dp_ppent "Depreciation rate"
label var wdshares "Design cost share"
label var KEshr "Equipment share"
label var saleshrind "Industry size (sales share) "

estpost tabstat wtshare wdshares dp_ppent KEshr  ,  stats(mean p25 p50 p75 sd) columns(statistics) 
estout using "$TABLES/TableIA16.tex", replace style(tex) mlabels(none) nonumber collabels(none) cells("mean(fmt(3)) p25(fmt(3)) p50(fmt(3)) p75(fmt(3)) sd(fmt(3))") label
 

/* Physical Determinants: Inventory */

use "$DATA/BEA/RecoveryPhysicsInvt97_sic2.dta", clear

label var invwipshr "Work-in-progress share"
label var shelflife "Shelf life"
label var tshareinvt "Transportation cost"
label var dsharesinvt "Design cost"
label var saleshrind "Industry size (sales share)"
 
replace RecoveryInventoryMid = RecoveryInventoryMid/100

eststo clear

estpost tabstat  shelflife  tshareinvt dsharesinvt invwipshr,  stats(mean p25 p50 p75 sd) columns(statistics) 
estout using "$TABLES/TableIA17_PanelA.tex", replace style(tex) mlabels(none) nonumber collabels(none) cells("mean(fmt(3)) p25(fmt(3)) p50(fmt(3)) p75(fmt(3)) sd(fmt(3))") label

eststo clear

eststo: reg RecoveryInventoryMid    c.shelflife##c.tshareinvt c.shelflife##c.dsharesinvt invwipshr, robust
eststo: reg RecoveryInventoryMid    c.shelflife##c.tshareinvt c.shelflife##c.dsharesinvt invwipshr  saleshrind, robust

#delimit ;
estout using "$TABLES/TableIA17_PanelB.tex", replace style(tex) 
label mlabels(none) cells(b(fmt(3) star ) se(fmt(3) par)) 
varlabels(_cons Constant)  
starlevels(* .10 ** .05 *** .01)  collabels(none);

estout using "$TABLES/Table17_PanelB_r2.tex", replace style(tex) 
cells(none) 
stats(N r2, fmt(%9.0fc %9.2f) labels("Obs" "R$^2$" ) ) 
mlabels(none) collabels(none);
#delimit cr
 

/* Rauch */

import delimited "$DATA/BEA/IOCOMMODITIES.csv", clear

/*
w = goods traded on an organized exchange
r = reference priced
n = differentiated products
*/

gen vcon = (con=="w") 
replace vcon = . if con==""

gen vlib = (lib=="w")
replace vlib = . if lib==""

tempfile rauch
save "`rauch'"

import delimited "$DATA/BEA/NAICSUseDetail.txt", clear

ren v1 commodity
replace commodity = subinstr(commodity, " ", "", .)

ren v2 industry
replace industry = subinstr(industry, " ", "", .)

gen iocode = commodity

merge m:1 iocode using "`rauch'", keep(1 3) keepusing(vcon vlib con lib)
tab _merge
drop _merge

gen commodity6 = commodity
merge m:1 commodity6 using "$DATA/BEA/designshr_BEA6.dta", keep(1 3) keepusing(design_share)
tab _merge
drop _merge

merge m:1 commodity6 using "$DATA/BEA/transportation_BEA6.dta", keep(1 3) keepusing(tshare)
tab _merge
drop _merge

duplicates drop commodity, force
eststo clear

ren design_share dsharesinvt
ren tshare tshareinvt

eststo: reg vcon dsharesinvt tshareinvt, robust
eststo: reg vlib dsharesinvt tshareinvt, robust


use "$DATA/BEA/RecoveryPhysicsInvt97_sic2.dta", clear

label var invwipshr "Work-in-progress share"
label var tshareinvt "Transportation cost"
label var dsharesinvt "Design cost"
label var saleshrind "Industry size (sales share)"
label var wshrcon "Frac exchange traded (conservative)"
label var wshrlib "Frac exchange traded (liberal)"
label var shelflife "Shelf life"

replace RecoveryInventoryMid = RecoveryInventoryMid/100

eststo: reg wshrcon  tshareinvt  dsharesinvt shelflife  if RecoveryInventoryMid!=., robust
eststo: reg wshrlib  tshareinvt  dsharesinvt shelflife  if RecoveryInventoryMid!=., robust

 #delimit ;
estout using "$TABLES/TableIA18.tex", replace style(tex) 
label mlabels(none) cells(b(fmt(3) star ) se(fmt(3) par)) 
varlabels(_cons Constant)  
starlevels(* .10 ** .05 *** .01)  collabels(none);

estout using "$TABLES/TableIA18_r2.tex", replace style(tex) 
cells(none) 
stats(N r2, fmt(%9.0fc %9.2f) labels("Obs" "R$^2$" ) ) 
mlabels(none) collabels(none);
#delimit cr


/* Receivables */

clear all

program define fastload

use "$DATA/Compustat/compustat_ann_out.dta", clear

drop if year>2018

drop if sic>=6000 & sic<7000
drop if sic>=9000 & sic!=.

end

* NB: This data file is not referenced in the README
use "$DATA/Compustat/compustat_segment.dta", clear

keep if stype=="GEOSEG"
replace snms = subinstr(snms, ".", "", .)
keep if snms=="United States" | snms=="United States of America"  | snms=="USA" | snms=="US" | snms=="Domestic" 
drop if sales==.

gen yrq = qofd(datadate)
format yrq %tq
destring gvkey, replace

ren sales saleusa
duplicates drop gvkey yrq saleusa , force

sort gvkey yrq datadate srcdate
bysort gvkey yrq: gen n = _n
bysort gvkey yrq: egen nmax = max(n)
keep if nmax==n

keep gvkey yrq saleusa datadate

tempfile saleusa
save "`saleusa'"

fastload

gen yrq = qofd(datadate)
merge m:1 gvkey yrq using "`saleusa'", keep(1 3)
tab _merge
drop _merge
drop yrq

gen saleusashr = saleusa/sale
sum saleusashr, detail

gen rectdays = 360/(sale_at/rect_at)
gen recdshr = recd/rect
gen rectrshr = rectr/rect

sum rectdays, detail

foreach item in rectdays {
bysort fyear: egen tmp_ph=pctile(`item'), p(99)
bysort fyear: egen tmp_pl=pctile(`item'), p(1)
replace `item'=. if `item'>tmp_ph 
replace `item'=. if `item'<tmp_pl 
drop tmp_* 
}

foreach item in saleusashr recdshr rectrshr {
replace `item' = . if `item'<0
replace `item' = . if `item'>1
}

sum rectdays, detail

bysort sic2 year: egen salesum = sum(sale)
bysort year: egen saletot = sum(sale)
gen saleshrind = salesum/saletot  

collapse (mean) rectdays saleusashr* recdshr rectrshr ap_at opast_at opliab_at noa_at accrual_at saleshrind, by(sic2 year)

keep if year==1997

merge 1:1 sic2 using "$DATA/PacerRecovery.dta", keep(1 3) keepusing(RecoveryReceivableMid)
tab _merge
drop _merge

scatter RecoveryReceivableMid saleusashr, mlabel(sic2)
scatter RecoveryReceivableMid ap_at, mlabel(sic2)

scatter RecoveryReceivableMid recdshr, mlabel(sic2)
scatter RecoveryReceivableMid rectrshr, mlabel(sic2)

gen fsaleshr = 1 - saleusashr

label var recdshr "Doubtful receivable share"
label var saleusashr "Domestic sale share"
label var fsaleshr "Foreign sale share"
label var ap_at "Accounts payable"
label var saleshrind "Industry size (sales share) "

replace RecoveryReceivableMid = RecoveryReceivableMid/100

eststo clear

estpost tabstat recdshr fsaleshr ap_at saleshrind,  stats(mean p25 p50 p75 sd) columns(statistics) 
estout using "$TABLES/TableIA19_PanelA.tex", replace style(tex) mlabels(none) nonumber collabels(none) cells("mean(fmt(3)) p25(fmt(3)) p50(fmt(3)) p75(fmt(3)) sd(fmt(3))") label

eststo clear

eststo: reg RecoveryReceivableMid  recdshr fsaleshr  ap_at , robust
eststo: reg RecoveryReceivableMid  recdshr fsaleshr  ap_at saleshrind, robust


#delimit ;
estout using "$TABLES/TableIA19_PanelB.tex", replace style(tex) 
label mlabels(none) cells(b(fmt(3) star ) se(fmt(3) par)) 
varlabels(_cons Constant)  
starlevels(* .10 ** .05 *** .01)  collabels(none);

estout using "$TABLES/TableIA19_PanelB_r2.tex", replace style(tex) 
cells(none) 
stats(N r2, fmt(%9.0fc %9.2f) labels("Obs" "R$^2$" ) ) 
mlabels(none) collabels(none);
#delimit cr

/* Book Intangibles */

fastload

gen yrq = qofd(datadate)

xtset
gen depre = dp - am
replace depre = dp if am==.
gen dp_ppent = depre/l.ppent 
gen am_intan = am/l.intan
gen gdwl_intan = gdwl/intan
replace gdwl_intan = 0 if gdwl==. & intan!=.
gen intano_intan = intano/intan

foreach item of varlist dp_ppent am_intan gdwl_intan intano_intan {
bysort year: egen tmp_ph=pctile(`item'), p(99)
bysort year: egen tmp_pl=pctile(`item'), p(1)
replace `item'=. if `item'>tmp_ph 
replace `item'=. if `item'<tmp_pl 
drop tmp_*      
}

bysort sic2 year: egen salesum = sum(sale)
bysort year: egen saletot = sum(sale)
gen saleshrind = salesum/saletot  

foreach item in ni_at ebitda_at {
replace `item' = . if abs(`item')>1
}

collapse (mean) dp_ppent am_intan gdwl_at gdwl_intan saleshrind intano_intan intan_at ebitda_at ni_at , by(sic2 year)

keep if year==1997

merge m:1 sic2 using "$DATA/PacerRecovery.dta", keep(1 3) keepusing(Recovery*Mid)
tab _merge
drop _merge

replace RecoveryIntanMid = RecoveryIntanMid/100

label var gdwl_intan "Goodwill share in book intangibles"
label var ni_at "Industry-average ROA"
label var saleshrind "Industry size (sales share)"

eststo clear

estpost tabstat gdwl_intan  ni_at saleshrind,  stats(mean p25 p50 p75 sd) columns(statistics) 
estout using "$TABLES/TableIA20_PanelA.tex", replace style(tex) mlabels(none) nonumber collabels(none) cells("mean(fmt(3)) p25(fmt(3)) p50(fmt(3)) p75(fmt(3)) sd(fmt(3))") label

eststo clear

eststo: reg RecoveryIntanMid  gdwl_intan ni_at , robust
eststo: reg RecoveryIntanMid  gdwl_intan  ni_at saleshrind, robust

#delimit ;
estout using "$TABLES/TableIA20_PanelB.tex", replace style(tex) 
label mlabels(none) cells(b(fmt(3) star ) se(fmt(3) par)) 
varlabels(_cons Constant)  
starlevels(* .10 ** .05 *** .01)  collabels(none);

estout using "$TABLES/TableIA20_PanelB_r2.tex", replace style(tex) 
cells(none) 
stats(N r2, fmt(%9.0fc %9.2f) labels("Obs" "R$^2$" ) ) 
mlabels(none) collabels(none);
#delimit cr
