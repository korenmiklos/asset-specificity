********************************************
***Code to record stock return volatility***
********************************************

clear all

set matsize 11000
set more off, permanently

if ("`c(username)'" == "yueranma") |  ("`c(username)'" == "Yueran Ma")  |  ("`c(username)'" == "sony") {
	global DATA "../Data"
	global BEA "$DATA/BEA"
	global CSTAT "$DATA/Compustat"
	global CRSP "$DATA/CRSP"
}

/****Step 1: Obtain Abnormal Returns *******************************/
	use "$CRSP/crsp_daily.dta", clear

// Rename the variable names as lowercase
	foreach item of varlist _all {
				rename `item', lower
				}


// Merge with factor data from CRSP
	merge m:1 date using "$CRSP/factors_1970-2020.dta"
	keep if _m == 3
	drop _m


// Excess returns
	gen retex = ret - rf 
	

// Rolling regressions (1-year rolling window)
	sort date
	egen days=group(date)
	tsset permno days
* FIXME: this is not a standard Stata command. Install and document?
	bys permno: asreg retex mktrf smb hml, window (days 253) se fit
	
	rename _b_mktrf beta_mktrf
	rename _b_smb beta_smb
	rename _b_hml beta_hml
	rename _residuals ab_3f
	drop _b_cons _se_mktrf _se_smb _se_hml _se_cons _fitted

keep if trdstat=="A"

gen yq = qofd(date)

collapse (mean) mean_ret=ret mean_ab_3f = ab_3f mean_retex=retex (sd) sd_ret=ret sd_ab_3f = ab_3f sd_retex=retex  (count) nd=ret, by(yq permno) 

save "$CRSP/crsp_qtr_out.dta", replace