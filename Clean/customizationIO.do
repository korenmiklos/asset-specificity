clear all

set matsize 11000
set more off, permanently

if 1 | ("`c(username)'" == "yueranma") |  ("`c(username)'" == "Yueran Ma")  |  ("`c(username)'" == "sony") {
	global DATA "./Data"
	global BEA "$DATA/BEA"
}


/* BEA IO Data on Design Cost Share */

local vers 1

if `vers' == 1 {
local vprice "vproduct"
}
else if `vers' == 2 {
local vprice "vpurchase"
}


import excel "$BEA/IO-CodeDetail.xls", firstrow clear

replace Description = lower(Description)

gen design = 0
replace design = 1 if strpos(Description, "design")
replace design = 1 if strpos(Description, "information services")
replace design = 1 if strpos(Description, "data processing services")
replace design = 1 if strpos(Description, "custom computer programming services")
replace design = 1 if strpos(Description, "management consulting")
replace design = 1 if strpos(Description, "research")
replace design = 1 if strpos(Description, "advertising")
replace design = 1 if strpos(Description, "business support services")
replace design = 1 if strpos(Description, "all other miscellaneous professional and technical services")

replace Industrycode = subinstr(Industrycode, " ", "", .)

tempfile custom
save "`custom'"

import delimited "$BEA/NAICSUseDetail.txt", clear

ren v1 commodity
replace commodity = subinstr(commodity, " ", "", .)

ren v2 industry
replace industry = subinstr(industry, " ", "", .)

ren v3 year
drop v4 /* Table number */
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

egen transport_tot = rowtotal(transport_*)

gen Industrycode = commodity

merge m:1 Industrycode using "`custom'", keep(1 3) 
tab _merge
drop _merge

save "$BEA/UseDetail.dta", replace

forvalues k = 4/6{

use "$BEA/UseDetail.dta", clear

gen commodity`k' = substr(industry, 1, `k')

collapse (sum) `vprice', by(commodity`k' design)
reshape wide `vprice', i(commodity`k') j(design)
gen design_share = `vprice'1/(`vprice'0+`vprice'1)

gsort -design_share

save "$BEA/designshr_BEA`k'.dta", replace
}


/* CFS Data on Wholesale/Retail Shipment Share */


import delimited "$DATA/CFS/cfs_2012_pumf_csv.txt", clear

drop if export_yn == "Y"

tostring naics, replace 
  
gen wholesale = 0
replace wholesale = 1 if substr(naics, 1, 1)=="4"  & substr(naics, 1, 2)!="49"

foreach item in shipmt_value shipmt_wght {

gen `item'_wholesale = `item'*wholesale

}

gen mwgt_factor = round(wgt_factor)

collapse (sum) shipmt_value* shipmt_wght* [fw=mwgt_factor], by(sctg)

gen wholesaleshr_value = shipmt_value_wholesale/shipmt_value
gen wholesaleshr_wght = shipmt_wght_wholesale/shipmt_wght

tempfile cfs
save "`cfs'"

import excel "$DATA/BEA/BEAFixedAssetCategory.xlsx", sheet("IO") firstrow clear

keep if substr(AssetCode, 1, 1) == "E"
drop if substr(AssetCode, 1, 3) == "ENS"

keep AssetCode SCTG
tostring SCTG, replace

gen sctg = substr(SCTG, 1, 2)

keep AssetCode sctg

merge m:1 sctg using "`cfs'", keep(1 3)
tab _merge
drop _merge

save "$DATA/CFS/wholesaleshr.dta", replace
