********************************************
***Code to record stock return volatility***
********************************************

clear all

set matsize 11000
set more off, permanently

if 1 | ("`c(username)'" == "yueranma") |  ("`c(username)'" == "Yueran Ma")  |  ("`c(username)'" == "sony") {
	global DATA "./Data"
	global BEA "$DATA/BEA"
	global CSTAT "$DATA/Compustat"
	global CRSP "$DATA/CRSP"
}

/****Step 1: Obtain Abnormal Returns *******************************/
	use "$CRSP/crsp_mon.dta", clear

// Rename the variable names as lowercase
	foreach item of varlist _all {
				rename `item', lower
				}

destring ret, force replace

// Rolling regressions (1-year rolling window)
	sort date
	egen months = group(date)
	tsset permno months

keep if trdstat=="A"

gen year = real(substr(date,1,4))

collapse (mean) mean_ret_ann = ret (sd) sd_ret_ann = ret (count) nd=ret, by(year permno) 

save "$CRSP/crsp_ann_out.dta", replace