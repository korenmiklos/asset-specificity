clear all

set matsize 11000
set more off, permanently

if 1 | ("`c(username)'" == "yueranma") |  ("`c(username)'" == "Yueran Ma")  |  ("`c(username)'" == "sony") {
	global DATA "./Data"
	global BEA "$DATA/BEA"
}

/*      ORBIS Industry Classification     */

use "$DATA/ORBIS/ob_industry_classifications_l.dta", clear

keep bvdid NAICSPCOD2017 NAICSCCOD2017  USSICCCOD USSICPCOD MAJOR_SECTOR

bysort bvdid: gen N = _N
drop if N>1 & MAJOR_SECTOR == ""

drop N MAJOR_SECTOR
save "$DATA/ORBIS/industry_large_out.dta", replace

use "$DATA/ORBIS/ob_industry_classifications_m.dta", clear

keep bvdid NAICSPCOD2017 NAICSCCOD2017  USSICCCOD USSICPCOD MAJOR_SECTOR

bysort bvdid: gen N = _N
drop if N>1 & MAJOR_SECTOR == ""

drop N MAJOR_SECTOR
save "$DATA/ORBIS/industry_medium_out.dta", replace

use "$DATA/ORBIS/ob_industry_classifications_s.dta", clear

keep bvdid NAICSPCOD2017 NAICSCCOD2017  USSICCCOD USSICPCOD MAJOR_SECTOR

bysort bvdid: gen N = _N
drop if N>1 & MAJOR_SECTOR == ""

drop N MAJOR_SECTOR
save "$DATA/ORBIS/industry_small_out.dta", replace


/* Firms with Subsidiaries */

use "$DATA/ORBIS/orbis_sub.dta", clear

drop if strpos(_40025, "Government") 
 
keep CATEGORY_OF_COMPANY bvdid _9305 COUNTRY CTRYISO  

**Parent Industry Code**
merge m:1 bvdid using "$DATA/ORBIS/industry_large_out.dta", keep(1 3) keepusing(*NAICS* *SIC*)
tab _merge
drop _merge

merge m:1 bvdid using "$DATA/ORBIS/industry_medium_out.dta", keep(1 3 4 5) keepusing(*NAICS* *SIC*) update
tab _merge
drop _merge

destring *NAICS* *SIC*, replace

merge m:1 bvdid using "$DATA/ORBIS/industry_small_out.dta", keep(1 3 4 5) keepusing(*NAICS* *SIC*) update
tab _merge
drop _merge

ren NAICSCCOD2017 naics_parent 
ren NAICSPCOD2017 naicsp_parent
ren USSICCCOD sic_parent 
ren USSICPCOD sicp_parent

ren bvdid bvdid_parent

**Subsidiary Industry Code**
ren _9305 bvdid 
merge m:1 bvdid using "$DATA/ORBIS/industry_large_out.dta", keep(1 3) keepusing(*NAICS* *SIC*)
tab _merge
drop _merge

merge m:1 bvdid using "$DATA/ORBIS/industry_medium_out.dta", keep(1 3 4 5) keepusing(*NAICS* *SIC*) update
tab _merge
drop _merge

destring *NAICS* *SIC*, replace

merge m:1 bvdid using "$DATA/ORBIS/industry_small_out.dta", keep(1 3 4 5) keepusing(*NAICS* *SIC*) update
tab _merge
drop _merge

ren NAICSCCOD2017 naics_sub
ren NAICSPCOD2017 naicsp_sub
ren USSICCCOD sic_sub
ren USSICPCOD sicp_sub

save "$DATA/ORBIS/orbis_sub_out.dta", replace

*********************2012 IO Table (NAICS)*********************

use "$BEA/naics4_IO_match.dta", clear

duplicates tag naics, gen (dup)
drop dup
drop if naics == 7225 & input_naics=="7222"
duplicates drop naics, force
replace input_naics ="2300" if naics==23

tempfile ionaics
save "`ionaics'"

use "$DATA/ORBIS/orbis_sub_out.dta", clear

drop if naics_parent==. | naics_sub==.

***Convert NAICS Code to IO Code***
local item  naics_parent 
forvalues t = 4(-1)2 {
gen naics = floor(`item'/10^(4-`t'))
merge m:1 naics using "`ionaics'", keep(1 3 4 5) update
tab _merge
drop _merge
drop naics
}
ren input_naics parent4

local item  naics_sub
forvalues t = 4(-1)2 {
gen naics = floor(`item'/10^(4-`t'))
merge m:1 naics using "`ionaics'", keep(1 3 4 5) update
tab _merge
drop _merge
drop naics
}
ren input_naics sub4

collapse (lastnm) parent4 CTRYISO COUNTRY naics_parent naicsp_parent sic_parent sicp_parent , by(bvdid_parent sub4)

bysort bvdid_parent: gen N  = _N
sum N, detail

save "$DATA/ORBIS/orbis_parent_sub_io12.dta", replace


import excel "$BEA/IOUse_After_Redefinitions_PRO_DET.xlsx", clear sheet("2012") cellrange(A6:PN415) firstrow

foreach iia of varlist A0-T007 {
	local x : variable label `iia'
	rename `iia' output_naics`x'
}

reshape long output_naics, i(Code) j(industry) string
ren output_naics value
drop if Code=="T005"
drop if substr(industry, 1, 1)=="T"

ren Code commodity

ren CommodityDescription Description
replace Description = lower(Description)

gen commodity4 = substr(commodity, 1, 4)
gen industry4 = substr(industry, 1, 4)

replace industry4 = "2300" if substr(industry, 1, 2)=="23"
replace commodity4 = "2300" if substr(commodity, 1, 2)=="23"

drop if  commodity4 == "V00300"
drop if  commodity4 == "V00200"

replace value = 0 if value<0

collapse (sum) value, by(commodity4 industry4)

bysort industry4: egen value_total = sum(value)
gen share = value/value_total

tempfile io2012
save "`io2012'"

use "$DATA/ORBIS/orbis_parent_sub_io12.dta", clear

gen industry4 = parent4
gen commodity4 = sub4

drop if industry4=="" | commodity4==""

merge m:1 industry4 commodity4 using "`io2012'", keep(1 3) keepusing(share)
tab _merge
drop _merge

ren share share1

drop industry4 commodity4

gen industry4 = sub4
gen commodity4 = parent4

merge m:1 industry4 commodity4 using "`io2012'", keep(1 3) keepusing(share)
tab _merge
drop _merge

ren share share2

drop industry4 commodity4

save "$DATA/ORBIS/orbis_parent_sub_io12_out.dta", replace


/* 2018 Sample */

use "$BEA/naics4_IO_match.dta", clear

duplicates tag naics, gen (dup)
drop dup
drop if naics == 7225 & input_naics=="7222"
duplicates drop naics, force
replace input_naics ="2300" if naics==23

tempfile ionaics
save "`ionaics'"

use "$DATA/ORBIS/orbis_sub.dta", clear

drop if strpos(_40025, "Government") 

keep bvdid
duplicates drop bvdid, force
gen isparent = 1

tempfile isparent
save "`isparent'"

use "$DATA/ORBIS/orbis_sub.dta", clear

drop if strpos(_40025, "Government") 

keep _9305
duplicates drop _9305, force
ren _9305 bvdid
gen issub = 1

tempfile issub
save "`issub'"

use "$DATA/ORBIS/orbis_background_2018.dta", clear

keep if strpos(HISTORIC_STATUS_STR, "Active")
drop if CTRYISO==""

keep bvdid CATEGORY_OF_COMPANY CTRYISO
duplicates drop bvdid  CATEGORY_OF_COMPANY, force

**Industry Code**
merge m:1 bvdid using "$DATA/ORBIS/industry_large_out.dta", keep(1 3) keepusing(*NAICS* )
tab _merge
drop _merge

merge m:1 bvdid using "$DATA/ORBIS/industry_medium_out.dta", keep(1 3 4 5) keepusing(*NAICS*  ) update
tab _merge
drop _merge

destring *NAICS*, replace

merge m:1 bvdid using "$DATA/ORBIS/industry_small_out.dta", keep(1 3 4 5) keepusing(*NAICS* ) update
tab _merge
drop _merge

ren NAICSCCOD2017 naics_firm  
ren NAICSPCOD2017 naicsp 

merge m:1 bvdid using "`isparent'", keep(1 3)
tab _merge
ren _merge _merge1

merge m:1 bvdid using "`issub'", keep(1 3)
tab _merge
ren _merge _merge2

drop if issub==1 & isparent!=1 // entities that are only subsidiaries
drop _merge*

local item  naics_firm
forvalues t = 4(-1)2 {
gen naics = floor(`item'/10^(4-`t'))
merge m:1 naics using "`ionaics'", keep(1 3 4 5) update
tab _merge
drop _merge
drop naics
}
ren input_naics parent4
drop naics_firm naicsp

ren bvdid bvdid_parent 
gen active2018=1

drop if parent4 == ""

save "$DATA/ORBIS/orbis_background_2018_entity.dta", replace
