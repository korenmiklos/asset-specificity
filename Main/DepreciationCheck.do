clear all

if ("`c(username)'" == "yueranma") |  ("`c(username)'" == "Yueran Ma")  |  ("`c(username)'" == "sony") | ("`c(username)'" == "julienweber") {
	global DATA "../Data"
	global BEA "../Data/BEA"
	global CSTAT "$DATA/Compustat"
	global FIGURES "../Figures"
	global TABLES "../Tables"
}
 
clear all

program define fastload

use "$CSTAT/compustat_ann_out.dta", clear

drop if year>2018
drop if year<2000

drop if sic>=6000 & sic<7000
drop if sic>=9000 & sic!=.

end

************File to Compare BEA Depreciation Rate with Compustat Depreciation Rate************

import excel "$BEA/BEAFixedAssetCategory.xlsx", sheet("Industry") firstrow clear

drop if BEACODE == "--------"
drop if BEACODE == ""
ren BEACODE sector

keep INDUSTRYTITLE INDUSTRYTITLESHORT sector NAICSCodes

gen naics1 = NAICSCodes
forvalues k = 2/8 {
gen naics`k' = ""
}

replace naics1 = "111" if sector=="110C"
replace naics2 = "112" if sector=="110C"

replace naics1 = "113" if sector=="113F"
replace naics2 = "114" if sector=="113F"
replace naics3 = "115" if sector=="113F"

replace naics1 = "3361" if sector=="336M"
replace naics2 = "3362" if sector=="336M"
replace naics3 = "3363" if sector=="336M"

replace naics1 = "3364" if sector=="336O"
replace naics2 = "3365" if sector=="336O"
replace naics3 = "3366" if sector=="336O"
replace naics4 = "3367" if sector=="336O"
replace naics5 = "3368" if sector=="336O"
replace naics6 = "3369" if sector=="336O"

replace naics1 = "311" if sector=="311A"
replace naics2 = "312" if sector=="311A"

replace naics1 = "313" if sector=="313T"
replace naics2 = "314" if sector=="313T"

replace naics1 = "315" if sector=="315A"
replace naics2 = "316" if sector=="315A"

replace naics1 = "44" if sector=="44RT"
replace naics2 = "45" if sector=="44RT"


replace naics1 = "487" if sector=="487S"
replace naics2 = "488" if sector=="487S"
replace naics3 = "492" if sector=="487S"

replace naics1 = "515" if sector=="5130"
replace naics2 = "517" if sector=="5130"

replace naics1 = "518" if sector=="5140"
replace naics2 = "519" if sector=="5140"

replace naics1 = "532" if sector=="5320"
replace naics2 = "533" if sector=="5320"

replace naics1 = "711" if sector=="711A"
replace naics2 = "712" if sector=="711A"

replace naics1 = "5412" if sector=="5412"
replace naics2 = "5413" if sector=="5412"
replace naics3 = "5414" if sector=="5412"
replace naics4 = "5416" if sector=="5412"
replace naics5 = "5417" if sector=="5412"
replace naics6 = "5418" if sector=="5412"
replace naics7 = "5419" if sector=="5412"

destring naics*, replace

keep sector naics*
gen n=_n
reshape long naics, i(n) j(f)
drop n f
drop if naics==.

tempfile sector
save "`sector'"


/* BEA Sector Level Depreciation Rate of Fixed Assets */

use "$DATA/BEA/BEAFixedAssetDep.dta", clear

merge 1:1 sector year AssetCode using "$DATA/BEA/BEAFixedAsset.dta", keep(1 3) keepusing(K)
tab _merge
drop _merge

collapse (sum) K D, by(year sector)

encode sector, gen (ID)

xtset ID year

gen depBEA = D/(l.K)  // K is net fixed asset stock and BEA uses geometric depreciation  

tempfile bea
save "`bea'"


/* Merge the BEA sector code into Compustat */

fastload

tostring naicsh, replace

ren naics naicso

forvalues t = 4(-1)2 {
gen naics = substr(naicsh,1,`t')
destring naics, replace
merge m:1 naics using "`sector'", keepusing(sector) keep(1 3 4 5) update
tab _merge
drop _merge
drop naics
}


/* Calculate Compustat firm depreciation rate */	

xtset
replace dp = dp - am if am!=.
gen amCompustat = am/l.intan
gen depCompustat =  dp/l.ppegt  // this is the rate if firms use linear depreciation 
gen depCompustatalt =  dp/l.ppent 

foreach item of varlist depCompustat depCompustatalt amCompustat{
bysort fyear: egen tmp_ph = pctile(`item'), p(99)
bysort fyear: egen tmp_pl = pctile(`item'), p(1)
replace `item'=. if `item'>tmp_ph 
replace `item'=. if `item'<tmp_pl 
drop tmp_* 
}

merge m:1 sector year using "`bea'", keepusing(depBEA) keep(1 3)
tab _merge
drop _merge

collapse (mean) depCompustat* depBEA , by (sector) 
 
label var depCompustat "Compustat Annual Depreciation Rate"
label var depBEA "BEA Annual Depreciation Rate"

twoway (scatter depCompustat depBEA )   (function y=x, range(0 0.2) lpattern(dash) lcolor(gs6)) , ///
graphregion(color(white)) legend(off)  ylabel(0 (0.05) 0.2) xlabel(0 (0.05) 0.2) ytitle("Compustat Depreciation Rate (Linear)") xtitle("BEA Depreciation Rate (Geometric)")
graph export "$FIGURES/FigureIA14.pdf", replace

gen dif = depCompustat - depBEA
sum dif, detail
 
