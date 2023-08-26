*********************************************************
*** Data Cleaning File for CapitalIQ-Compustat Bridge ***
*********************************************************

clear 

set matsize 11000
set more off, permanently

if ("`c(username)'" == "") {
	global DATA "../DATA"
	global CAPIQ "$DATA/CapitalIQ"
}

/* Bridge with GVKEY */

use "$CAPIQ/cpst_bridge_raw.dta", clear

replace startdate = mdy(1, 1, 1980) if startdate==.

sort companyid startdate enddate
gen n = _n

replace enddate = startdate[_n+1] - 1 if companyid[_n+1]==companyid & enddate==.
replace enddate = mdy(12, 31, 2019) if enddate==.

expand 2

sort companyid n
gen yq = qofd(startdate) if n[_n-1]!=n
replace yq = qofd(enddate) if n[_n+1]!=n
format yq %tq

sort companyid n
replace yq = yq-1 if companyid[_n+1]==companyid & yq[_n+1]==yq

duplicates drop companyid yq, force
xtset companyid yq
tsfill

drop startdate enddate n
by companyid: replace gvkey = gvkey[_n-1] if gvkey==""
destring gvkey, replace

save "$CAPIQ/cpst_bridge_qtr.dta", replace