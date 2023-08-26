clear all

set matsize 11000
set more off, permanently

if ("`c(username)'" == "yueranma") |  ("`c(username)'" == "Yueran Ma")  |  ("`c(username)'" == "sony") {
	global DATA "../Data"
	global BEA "$DATA/BEA"
}

local vers 1

if `vers' == 1 {
local vprice "vproduct"
}
else if `vers' == 2 {
local vprice "vpurchase"
}

/* Transportation Cost from 1997 BEA Standard IO Files */

import delimited "$BEA/NAICSUseDetail.txt", clear

ren v1 commodity
replace commodity = subinstr(commodity, " ", "", .)

ren v2 industry
replace industry = subinstr(industry, " ", "", .)

ren v3 year
drop v4 
ren v5 vproduct

ren v7 transport_rail
ren v8 transport_truck
ren v9 transport_water
ren v10 transport_air
ren v11 transport_pipe
ren v12 transport_gas
ren v13 wholesale_margin
ren v14 retail_margin
ren v15 vpurchase

drop if industry=="F04000" //   Exports of goods and services
drop if industry=="F05000" //	Imports of goods and services

egen transport_tot = rowtotal(transport_*)
gen tshare = transport_tot/`vprice' 

drop if `vprice'<0 

replace tshare = . if tshare==0
sum tshare, detail

sum tshare, detail

forvalues k = 4/6{
preserve

gen commodity`k' = substr(commodity, 1, `k')

drop if transport_tot==0 | transport_tot==.
collapse (sum) transport_tot  vproduct vpurchase, by(commodity`k')
gen tshare = transport_tot/`vprice'  
sum tshare, detail

save "$BEA/transportation_BEA`k'.dta", replace

restore
}



/* CFS Data on Weight and Value */

import delimited "$DATA/CFS/4DCommodity.dat", delimiter(comma) clear

ren v1 sctg
ren v2 commodityname
ren v3 value
ren v4 weight
ren v5 tonmiles
ren v6 avgmiles

drop in 1/3
drop if real(sctg) == .
destring sctg, replace
foreach item of varlist value-avgmiles {
replace `item' = "" if `item' == "S"
destring `item', replace
} 

gen value_weight = value/weight
gen weight_value = weight/value

tempfile cfs4
save "`cfs4'"

import delimited "$DATA/CFS/3DCommodity.dat", delimiter(comma) clear

drop v4 v6 v8
ren v1 sctg
ren v2 commodityname
ren v3 value
ren v5 weight
ren v7 tonmiles
ren v9 avgmiles

drop in 1/3
drop if real(sctg) == .
destring sctg, replace
foreach item of varlist value-avgmiles {
replace `item' = "" if `item' == "S"
destring `item', replace
} 

gen value_weight = value/weight
gen weight_value = weight/value

tempfile cfs3
save "`cfs3'"

import excel "$DATA/BEA/BEAFixedAssetCategory.xlsx", sheet("IO") firstrow clear

ren SCTG sctg

keep if substr(AssetCode, 1, 1) == "E"
drop if substr(AssetCode, 1, 3) == "ENS"

merge m:1 sctg using  "`cfs4'", keep(1 3)
tab _merge
drop _merge

merge m:1 sctg using  "`cfs3'", keep(1 3 4 5) update
tab _merge
drop _merge

save "$DATA/CFS/BEAFixedAsset_ValueWeight.dta", replace
