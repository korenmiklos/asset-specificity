************************************************************
*** Data Cleaning File to Compile CapitalIQ Debt Summary ***
************************************************************

clear 

set matsize 11000
set more off, permanently

if ("`c(username)'" == "")   {
	global DATA "../Data/"
	global CAPIQ "$DATA/CapitalIQ"
}

use "$CAPIQ/ciqdt.dta", clear

missings dropobs principalamtdbtoutstanding-trustpreferredadj, force

format periodenddate %td
format filingdate %td

gen yq = qofd(periodenddate)
format yq %tq

duplicates drop companyid yq, force

merge 1:1 companyid yq using "$CAPIQ/cpst_bridge_qtr.dta", keep(1 3) keepusing(gvkey)
tab _merge
drop _merge

save "$CAPIQ/ciqdt_short_out.dta", replace

use "$CAPIQ/ciqdt_short_out.dta", clear

drop if gvkey==.
sort gvkey yq filingdate
drop if gvkey==gvkey[_n+1] & yq==yq[_n+1] 

save "$CAPIQ/ciqdt_short_out_pub.dta", replace
