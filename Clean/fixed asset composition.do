********************************************
***Code to compile BEA Fixed Asset tables***
********************************************

clear all

set matsize 11000
set more off, permanently

if ("`c(username)'" == "yueranma") |  ("`c(username)'" == "Yueran Ma")  |  ("`c(username)'" == "sony") {
	global DATA "../Data"
	global BEA "$DATA/BEA"
}


***List of Industries***

clear
gen sector = ""
gen AssetCode = ""
gen AssetType = ""

save "$BEA/BEAFixedAsset.dta", replace

import excel "$BEA/BEAFixedAssetCategory.xlsx", sheet("Industry") firstrow clear
drop if BEACODE == "--------"
drop if BEACODE == ""
keep BEACODE
levelsof BEACODE , local(vlist)

***Fixed Assets***

local m = 1
foreach item of local vlist {
import excel "$BEA/detailnonres_stk1.xlsx", sheet("`item'") cellrange(A9:BV80) clear
drop if A=="STRUCTURES"
ren A AssetCode
ren B AssetType

local i = 1947
foreach varn of varlist C-BV {
ren `varn' K`i'
local i = `i'+1
}

gen n = _n
reshape long K, i(n) j(year)
drop n

gen sector = "`item'"

tempfile s`m'
save "`s`m''"

use "$BEA/BEAFixedAsset.dta", clear
append using "`s`m''"
save "$BEA/BEAFixedAsset.dta", replace

local m = `m' + 1
}

***Intangibles***

clear
gen sector = ""
gen AssetCode = ""
gen AssetType = ""

save "$BEA/BEAIP.dta", replace

import excel "$BEA/BEAFixedAssetCategory.xlsx", sheet("Industry") firstrow clear
drop if BEACODE == "--------"
drop if BEACODE == ""
keep BEACODE
levelsof BEACODE , local(vlist)

local m = 1
foreach item of local vlist {
import excel "$BEA/detailnonres_stk1.xlsx", sheet("`item'") cellrange(A82:BV106) clear
ren A AssetCode
ren B AssetType

local i = 1947
foreach varn of varlist C-BV {
ren `varn' IP`i'
local i = `i'+1
}

gen n = _n
reshape long IP, i(n) j(year)
drop n

gen sector = "`item'"

tempfile s`m'
save "`s`m''"

use "$BEA/BEAIP.dta", clear
append using "`s`m''"
save "$BEA/BEAIP.dta", replace

local m = `m' + 1
}

**Fixed Asset Depreciation Rates**

clear
gen sector = ""
gen AssetCode = ""
gen AssetType = ""

save "$BEA/BEAFixedAssetDep.dta", replace

import excel "$BEA/BEAFixedAssetCategory.xlsx", sheet("Industry") firstrow clear

drop if BEACODE == "--------"
keep BEACODE
drop if BEACODE == ""

gen n = _n
levelsof BEACODE , local(vlist)

local m = 1
foreach item of local vlist {
import excel "$BEA/detailnonres_dep1.xlsx", sheet("`item'") cellrange(A9:BV80) clear
drop if A=="STRUCTURES"
ren A AssetCode
ren B AssetType

local i = 1947
foreach varn of varlist C-BV {
ren `varn' D`i'
local i = `i'+1
}

gen n = _n
reshape long D, i(n) j(year)
drop n

gen sector = "`item'"

tempfile s`m'
save "`s`m''"

use "$BEA/BEAFixedAssetDep.dta", clear
append using "`s`m''"
save "$BEA/BEAFixedAssetDep.dta", replace

local m = `m' + 1
}


***Intangible Depreciation***

clear
gen sector = ""
gen AssetCode = ""
gen AssetType = ""

save "$BEA/BEAIPDep.dta", replace

import excel "$BEA/BEAFixedAssetCategory.xlsx", sheet("Industry") firstrow clear
drop if BEACODE == "--------"
drop if BEACODE == ""
keep BEACODE
levelsof BEACODE , local(vlist)

local m = 1
foreach item of local vlist {
import excel "$BEA/detailnonres_dep1.xlsx", sheet("`item'") cellrange(A82:BV106) clear
ren A AssetCode
ren B AssetType

local i = 1947
foreach varn of varlist C-BV {
ren `varn' IPdep`i'
local i = `i'+1
}

gen n = _n
reshape long IPdep, i(n) j(year)
drop n

gen sector = "`item'"

tempfile s`m'
save "`s`m''"

use "$BEA/BEAIPDep.dta", clear
append using "`s`m''"
save "$BEA/BEAIPDep.dta", replace

local m = `m' + 1
}


 