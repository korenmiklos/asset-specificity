*********************************************************
***Code to compile physical attributes of fixed assets***
*********************************************************

clear all

set matsize 11000
set more off, permanently

if 1 | ("`c(username)'" == "yueranma") |  ("`c(username)'" == "Yueran Ma")  |  ("`c(username)'" == "sony") {
	global DATA "./Data"
	global BEA "$DATA/BEA"
	global CSTAT "$DATA/Compustat"
	global PACER "$DATA/PACER"
}

import excel "$BEA/BEAFixedAssetCategory.xlsx", sheet("IO") firstrow clear

keep AssetCode IOCode 

tempfile iocode
save "`iocode'"

***** Asset-Level Attributes ***** 

use "$BEA/BEAFixedAsset.dta", clear
drop if year<1960
drop if year>2018

merge m:1 AssetCode using "`iocode'", keep(1 3)
tab _merge
drop _merge

ren IOCode comm

/* Customization */

forvalues k = 6(-1)4 {
gen commodity`k' = substr(comm, 1, `k')
merge m:1 commodity`k' using "$BEA/designshr_BEA`k'.dta", keep(1 3 4 5) update keepusing(design_share)
tab _merge
drop _merge

drop commodity`k'
}
ren design_share dshares
label var dshare "Design cost share"

merge m:1 AssetCode using "$DATA/CFS/wholesaleshr.dta", keep(1 3) 
tab _merge
drop _merge

/* Mobility */

* Value-weight from Commodity Flow Survey *
merge m:1 AssetCode using "$DATA/CFS/BEAFixedAsset_ValueWeight.dta", keep(1 3) keepusing(value_weight weight_value avgmiles)
tab _merge
drop _merge

* Transportation cost from BEA IO data *
forvalues k = 6(-1)4 {
gen commodity`k' = substr(comm, 1, `k')
merge m:1 commodity`k' using "$BEA/transportation_BEA`k'.dta", keep(1 3 4 5) update keepusing(t*share)
tab _merge
drop _merge

drop commodity`k'
}
label var tshare "Transportation cost"

replace tshare=. if substr(AssetCode, 1, 1)=="S"

drop if AssetCode=="EI11"

save "$BEA/beafixedassetcomp.dta", replace

 
***** Aggregate to BEA Sector Level ***** 

use "$BEA/beafixedassetcomp.dta", clear

bysort sector year: egen Ktot = sum(K)
gen EQ = substr(AssetCode, 1, 1)=="E"
gen KE = K*EQ
bysort sector year: egen KEtot = sum(KE)
gen shr = K/Ktot
gen shr1 = K/KEtot if substr(AssetCode, 1, 1)=="E"
gen KEshr = KEtot/Ktot

label var KEshr "Equipment share"

foreach item of varlist dshares {
gen tmp = shr*`item'
bysort sector year: egen w`item' = sum(tmp)
drop tmp
}

foreach item of varlist t*share*   {
cap drop w`item'
gen tmp = shr1*`item'
bysort sector year: egen w`item' = sum(tmp)
drop tmp
}

foreach item of varlist *share* {
replace `item' = . if K==0
}

collapse (mean)  *share* KEshr (sum) K  , by(sector year) 

merge 1:1 sector year using "$BEA/OutputbyInd_out.dta", keep(1 3) keepusing(GO* VA*)
tab _merge
drop _merge

save "$BEA/beafixedassetout.dta", replace


***** Convert to 2-Digit SIC ***** 

import excel "$BEA/BEAFixedAssetCategory.xlsx", sheet("Industry") firstrow clear

drop if BEACODE == "--------"
drop if BEACODE == ""
ren BEACODE sector

keep sector SIC*
gen n=_n
reshape long SIC, i(n) j(f)
drop n f
drop if SIC==.
ren SIC sic2
duplicates drop sector sic2, force

expand 57
bysort sic2 sector: gen year = _n+1959

merge m:1 sector year using "$BEA/beafixedassetout.dta", keep(1 3)
tab _merge
drop _merge

cap drop Ktot
bysort sic2 year: egen Ktot = sum(K)
gen shr = K/Ktot

foreach item of varlist w*  {
bysort sic2 year: egen tmp2 = mean(`item')
replace `item' = tmp2
drop tmp*
}

collapse (mean)  *share*  KEshr , by(sic2 year) 

label var wtshare "Transportation cost"
label var wdshares "Design cost share"

save "$BEA/beafixedassetout_sic2.dta", replace

***** Compustat Data for 2-Digit SIC ***** 

use "$DATA/Compustat/compustat_ann_out.dta", clear

drop if year<1960
drop if year>2018
drop if sic2<10 | sic2>90
drop if sic2>=60 & sic2<70

xtset

/* Depreciation Rate */

gen depre = dp - am
replace depre = dp if am==.

gen dp_ppegt = depre/l.ppegt  
gen dp_ppent = depre/l.ppent  

foreach item in dp_ppegt dp_ppent {
bysort year: egen tmp_ph=pctile(`item'), p(99)
bysort year: egen tmp_pl=pctile(`item'), p(1)
replace `item'=. if `item'>tmp_ph 
replace `item'=. if `item'<tmp_pl 
drop tmp_*      
}

label var dp_ppent "Depreciation rate"

/* Industry Sales Share */

bysort sic2 year: egen salesum = sum(sale)
bysort year: egen saletot = sum(sale)
gen saleshrind = salesum/saletot 

label var saleshrind "Industry size (sales share)"

collapse  (mean) dp_ppegt dp_ppent saleshrind  , by(sic2 year)

merge m:1 sic2 using "$DATA/PacerRecovery.dta", keep(1 3) keepusing(Recovery*Mid*)
tab _merge
drop _merge

merge 1:1 sic2 year using "$BEA/beafixedassetout_sic2.dta", keep(1 3)  
tab _merge
drop _merge

* Keep 1997 Cross Section *

keep if year==1997

reg RecoveryPPEMid   wtshare wdshares  dp_ppent KEshr , robust  
predict PRecoveryPPEMid

keep sic2 RecoveryPPEMid wtshare wdshares  dp_ppent KEshr saleshrind PRecoveryPPEMid
order sic2 RecoveryPPEMid wtshare wdshares  dp_ppent KEshr saleshrind PRecoveryPPEMid

label var RecoveryPPEMid "PPE liquidation recovery rate"
label var PRecoveryPPEMid "Predicted PPE liquidation recovery rate"
label var wtshare  "Transportation cost"
label var dp_ppent "Depreciation rate"
label var wdshares "Design cost share"
label var KEshr "Equipment share"
label var saleshrind "Industry size (sales share) "

save "$DATA/RecoveryPhysicsFA97_sic2.dta", replace


***** By BEA Industries ***** 

import excel "$BEA/BEAFixedAssetCategory.xlsx", sheet("Industry") firstrow clear

drop if BEACODE == "--------"
drop if BEACODE == ""
ren BEACODE sector

keep sector SIC*
gen n=_n
reshape long SIC, i(n) j(f)
drop n f
drop if SIC==.
ren SIC sic2
duplicates drop sector sic2, force
 
merge m:1 sic2 using "$BEA/RecoveryPhysicsFA97_sic2.dta", keep(1 3) keepusing(dp_ppegt dp_ppent)
tab _merge
drop _merge

collapse (mean) dp_ppegt dp_ppent, by(sector)

expand 57
bysort sector: gen year = _n+1959

merge 1:1 sector year using "$BEA/beafixedassetout.dta", keep(1 3)
tab _merge
drop _merge

gen beaind = sector
merge m:1 beaind using "$DATA/PacerRecoveryBEA.dta", keep(1 3) keepusing(Recovery*Mid*)
tab _merge
drop _merge
drop beaind

* Keep 1997 Cross Section *

keep if year==1997

reg RecoveryPPEMid   wtshare wdshares  dp_ppent KEshr , robust
predict PRecoveryPPEMid

keep sector RecoveryPPEMid wtshare wdshares  dp_ppent KEshr VAshr PRecoveryPPEMid
order sector RecoveryPPEMid wtshare wdshares  dp_ppent KEshr VAshr PRecoveryPPEMid

label var sector "BEA fixed asset industries"
label var RecoveryPPEMid "PPE liquidation recovery rate"
label var PRecoveryPPEMid "Predicted PPE liquidation recovery rate"
label var wtshare "Transportation cost"
label var dp_ppent "Depreciation rate"
label var wdshares "Design cost share"
label var KEshr "Equipment share"
label var VAshr "Industry size (value-added share)"

save "$DATA/RecoveryPhysicsFA97_bea.dta", replace
