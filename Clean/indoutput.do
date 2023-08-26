******************************
*** GDP and VA by Industry ***
******************************

clear all

set matsize 11000
set more off, permanently

if ("`c(username)'" == "yueranma") |  ("`c(username)'" == "Yueran Ma")  |  ("`c(username)'" == "sony") {
	global DATA "../Data"
	global BEA "$DATA/BEA"
}

/* Gross Output */

import excel "$BEA/GrossOutput_Ind_pre98.xls", sheet("Sheet0") cellrange(B7:BA95) clear

ren B sectorname
drop if sectorname == ""

local k = 1947
foreach item of varlist C-BA {
ren `item'  GO`k'
local k = `k'+1
}

drop GO1997

replace sectorname = subinstr(sectorname, " ", "", .)

tempfile GOpre98
save "`GOpre98'"

keep if sectorname == "Allindustries" | sectorname =="Privateindustries"
destring GO*, replace

gen n = _n
reshape long GO, i(n) j(year)
drop sectorname
reshape wide GO, i(year) j(n)
ren GO1 GOall
ren GO2 GOprivate

tempfile GOpre98all
save "`GOpre98all'"

import excel "$BEA/GrossOutput_Ind_post97.xls", sheet("Sheet0") cellrange(B7:Z95) clear

ren B sectorname
drop if sectorname == ""

local k = 1997
foreach item of varlist C-Z {
ren `item'  GO`k'
local k = `k'+1
}

replace sectorname = subinstr(sectorname, " ", "", .)

tempfile GOpost98
save "`GOpost98'"

keep if sectorname == "Allindustries" | sectorname =="Privateindustries"

gen n = _n
reshape long GO, i(n) j(year)
drop sectorname
reshape wide GO, i(year) j(n)
ren GO1 GOall
ren GO2 GOprivate

append using "`GOpre98all'"

tsset year

tempfile GOall
save "`GOall'"


/* Value Added */

import excel "$BEA/ValueAdded_Ind_pre98.xls", sheet("Sheet0") cellrange(B7:BA95) clear

ren B sectorname
drop if sectorname == ""

local k = 1947
foreach item of varlist C-BA {
ren `item' VA`k'
local k = `k'+1
}

drop VA1997

replace sectorname = subinstr(sectorname, " ", "", .)

tempfile VApre98
save "`VApre98'"

keep if sectorname == "Grossdomesticproduct" | sectorname =="Privateindustries"
destring VA*, replace

gen n = _n
reshape long VA, i(n) j(year)
drop sectorname
reshape wide VA, i(year) j(n)
ren VA1 VAall
ren VA2 VAprivate

tempfile VApre98all
save "`VApre98all'"

import excel "$BEA/ValueAdded_Ind_post97.xls", sheet("Sheet0") cellrange(B7:Z95) clear

ren B sectorname
drop if sectorname == ""

local k = 1997
foreach item of varlist C-Z {
ren `item'  VA`k'
local k = `k'+1
}

replace sectorname = subinstr(sectorname, " ", "", .)

tempfile VApost98
save "`VApost98'"

keep if sectorname == "Grossdomesticproduct" | sectorname =="Privateindustries"
gen n = _n
reshape long VA, i(n) j(year)
drop sectorname
reshape wide VA, i(year) j(n)
ren VA1 VAall
ren VA2 VAprivate

append using "`VApre98all'"

tsset year

tempfile VAall
save "`VAall'"


/* Combine */

import excel "$BEA/BEAFixedAssetCategory.xlsx", sheet("Industry") firstrow clear

drop if BEACODE == "--------"
drop if BEACODE == ""
ren INDUSTRYTITLESHORT sectorname
ren BEACODE sector
replace sectorname = subinstr(sectorname, " ", "", .)

keep sector*
gen n = _n

merge 1:1 sectorname using "`GOpre98'", keep(1 3)
tab _merge
drop _merge

merge 1:1 sectorname using "`GOpost98'", keep(1 3)
tab _merge
drop _merge

merge 1:1 sectorname using "`VApre98'", keep(1 3)
tab _merge
drop _merge

merge 1:1 sectorname using "`VApost98'", keep(1 3)
tab _merge
drop _merge

foreach item of varlist *GO* *VA* {
cap replace `item' = "" if `item'=="..."
}

destring *GO* *VA*, replace

reshape long GO VA PGO PVA, i(n) j(year)
drop n

merge m:1 year using "`GOall'", keep(1 3) 
tab _merge
drop _merge

merge m:1 year using "`VAall'", keep(1 3) 
tab _merge
drop _merge

save "$BEA/OutputbyInd_out.dta", replace