clear all

set matsize 11000
set more off, permanently

if 1 | ("`c(username)'" == "yueranma") |  ("`c(username)'" == "Yueran Ma")  |  ("`c(username)'" == "sony") {
	global DATA "./Data"
	global BEA "$DATA/BEA"
	global CSTAT "$DATA/Compustat"
	global PACER "$DATA/PACER"
	global FIGURES "./Figures"
	global TABLES "./Tables"
} 

//Calculate asset specificity per IO industry

use "$BEA/naics4_IO_match.dta", clear

duplicates tag naics, gen (dup)
drop dup
drop if naics == 7225 & input_naics=="7222"
duplicates drop naics, force
replace input_naics ="2300" if naics==23

tempfile ionaics
save "`ionaics'"

use "$CSTAT/compustat_ann_out.dta", clear

drop if year>2018
drop if year<1985

gen sic2 = floor(sic/100)
drop if sic>=6000 & sic<7000
drop if sic>=9000 & sic!=.

merge m:1 sic2 using "$DATA/PacerRecovery.dta", keep(1 3) keepusing(Recovery*Mid)
tab _merge
drop _merge

gen double liqval = (RecoveryReceivableMid/100)*rect_at + (RecoveryInventoryMid/100)*invt_at + (RecoveryPPEMid/100)*ppent_at if year >=1996 & year<=2018

ren naics naics12
destring naics12, replace

local item  naics12
forvalues t = 4(-1)2 {
gen naics = floor(`item'/10^(4-`t'))
merge m:1 naics using "`ionaics'", keep(1 3 4 5) update
tab _merge
drop _merge
drop naics
}
ren input_naics parent4

gen externalfin = iequity_at - capx_at

	foreach item of varlist externalfin* {
      bysort fyear: egen tmp_ph=pctile(`item'), p(99)
      bysort fyear: egen tmp_pl=pctile(`item'), p(1)
      replace `item'=. if `item'>tmp_ph 
	  replace `item'=. if `item'<tmp_pl 
      drop tmp*
    } 
	
merge m:1 sic2 using "$DATA/RecoveryPhysicsFA97_sic2.dta", keep(1 3) keepusing(PRecoveryPPEMid)
tab _merge
drop _merge
	
keep if year==2018
collapse (mean) RecoveryPPEMid PRecoveryPPEMid liqval ppent_at externalfin* , by(parent4)

tempfile cpst
save "`cpst'"

//GDP
import excel "$DATA/International/GDPPC.xls", sheet("Data") firstrow clear

drop Indicator*

reshape long GDPPC, i(Code) j(year)
encode Code, gen (ID)
xtset ID year
gen gdpgr = GDPPC/l.GDPPC - 1
gen lngdp = ln(GDPPC)

tempfile gdppc
save "`gdppc'"

//World Bank business sophistication
import delimited "$DATA/International/governance_data.csv", clear 
keep if indicator=="Business Sophistication"
drop if subindicatortype=="Rank"
replace v11 = v10 if v11 == .
replace v11 = v12 if v11 == .
replace v17 = v15 if v17 == .

keep  countryiso3 v17
ren  countryiso3 Code
ren v17 sophisticate
tempfile sophisticate
save "`sophisticate'"

//Country code

import excel "$DATA/International/isocode.xlsx", sheet("Sheet1") firstrow clear
drop if Alpha3code == ""
gen CTRYISO = Alpha2code
tempfile isocode
save "`isocode'"

//Merge

use "$DATA/ORBIS/orbis_parent_sub_io12_out.dta", clear

drop if CTRYISO==""

merge m:1 bvdid_parent using "$DATA/ORBIS/orbis_background_2018_entity.dta", keep(1 2 3) update
tab _merge
keep if _merge==3
drop _merge

collapse (sum) share* (lastnm) parent4  CTRYISO  , by(bvdid_parent)

collapse (mean) share*  , by(parent4  CTRYISO )

gen shareavg = (share1 + share2)/2

sum share*, detail

merge m:1 CTRYISO using "`isocode'", keep(1 3) keepusing(Alpha3code)
tab _merge
drop _merge

gen code = Alpha3code
gen year = 2018
merge m:1 code year using "$DATA/International/wgidataset.dta", keep(1 3) keepusing(rle)
tab _merge
drop _merge

gen Code = Alpha3code

merge m:1 parent4 using "`cpst'", keep(1 3)
tab _merge
drop _merge

merge m:1 Code year using "`gdppc'", keep(1 3) keepusing(*gdp*)
tab _merge
drop _merge

merge m:1 Code using "`sophisticate'", keep(1 3) 
tab _merge
drop _merge


replace RecoveryPPEMid = RecoveryPPEMid/100
replace PRecoveryPPEMid = PRecoveryPPEMid/100

label var share1 "VI when Parent is Downstream"
label var share2 "VI when Sub is Downstream"
label var shareavg "Average VI"

label var RecoveryPPEMid "PPE liquidation recovery rate"
label var PRecoveryPPEMid "Predicted PPE liquidation recovery rate"
label var rle "Rule of law"
label var lngdp "Log GDP per capita"
label var ppent_at "PPE/assets"
label var externalfin "External finance dependence"
label var sophisticate "Business sophistication"

eststo clear

local condition "if substr(parent4, 1, 2)!="52"  & substr(parent4, 1, 2)!="55" "
local control "c.rle##c.ppent_at c.rle##c.externalfin "
eststo: reghdfe share1 c.rle##c.RecoveryPPEMid  ppent_at externalfin lngdp sophisticate  `condition', cluster(CTRYISO parent4) noa
eststo: reghdfe share1 c.rle##c.RecoveryPPEMid  ppent_at externalfin lngdp sophisticate  `control' `condition', cluster(CTRYISO parent4) noa

eststo: reghdfe share1 c.rle##c.RecoveryPPEMid   `control'  lngdp sophisticate `condition', cluster(CTRYISO parent4) absorb(CTRYISO parent4)
eststo: reghdfe share1 c.rle##c.PRecoveryPPEMid   `control'  lngdp sophisticate `condition' & RecoveryPPEMid!=., cluster(CTRYISO parent4) absorb(CTRYISO parent4)

eststo: reghdfe share2 c.rle##c.RecoveryPPEMid  ppent_at externalfin lngdp sophisticate  `condition', cluster(CTRYISO parent4) noa
eststo: reghdfe share2 c.rle##c.RecoveryPPEMid  ppent_at externalfin lngdp sophisticate  `control' `condition', cluster(CTRYISO parent4) noa 

eststo: reghdfe share2 c.rle##c.RecoveryPPEMid   `control'  lngdp sophisticate `condition', cluster(CTRYISO parent4) absorb(CTRYISO parent4)
eststo: reghdfe share2 c.rle##c.PRecoveryPPEMid   `control'  lngdp sophisticate `condition'  & RecoveryPPEMid!=., cluster(CTRYISO parent4) absorb(CTRYISO parent4)

#delimit ;
estout using "$TABLES/TableIA12.tex", replace style(tex) 
label mlabels(none) cells(b(fmt(3) star ) se(fmt(3) par)) 
keep(rle  c.rle#c.RecoveryPPEMid  c.rle#c.PRecoveryPPEMid RecoveryPPEMid PRecoveryPPEMid ppent_at externalfin c.rle#c.ppent_at c.rle#c.externalfin lngdp sophisticate) 
order(rle  c.rle#c.RecoveryPPEMid  c.rle#c.PRecoveryPPEMid RecoveryPPEMid PRecoveryPPEMid ppent_at externalfin c.rle#c.ppent_at c.rle#c.externalfin lngdp sophisticate)
starlevels(* .10 ** .05 *** .01)  collabels(none);

estout using "$TABLES/TableIA12_r2.tex", replace style(tex) 
cells(none) 
stats(N r2_within, fmt(%9.0fc %9.2f) labels("Obs" "R$^2$" ) ) 
mlabels(none) collabels(none);
#delimit cr

