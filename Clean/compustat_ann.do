*************************************************
*Code to clean and process Compustat Annual data*
*************************************************

clear 

set matsize 11000
set more off, permanently

if 1 | ("`c(username)'" == "yueranma") |  ("`c(username)'" == "Yueran Ma")  |  ("`c(username)'" == "sony") {
	global DATA "./Data/"
	global CSTAT "$DATA/Compustat"
	global CRSP "$DATA/CRSP"
}
	
***** CRSP *****

/* Stock Returns */
/*
	use "$CRSP/crsp_mon.dta", clear
	ren *, lower
	
	keep if trdstat == "A"
	
	gen ym = mofd(date)
	format ym %tm
	duplicates drop 
	
	gen shares_adj = shrout*cfacshr
	gen prc_adj = abs(prc)/cfacpr
	
	gen mkval = shares_adj*prc_adj
	
	keep permno cusip ym mkval ret retx shares_adj prc_adj
	duplicates drop 
	xtset permno ym
	
	gen lr12 = (1+l.ret)*(1+l2.ret)*(1+l3.ret)*(1+l4.ret)*(1+l5.ret)*(1+l6.ret)*(1+l7.ret)*(1+l8.ret)*(1+l9.ret)*(1+l10.ret)*(1+l11.ret)*(1+ret) 
	gen lrx_12 = (1+l.retx)*(1+l2.retx)*(1+l3.retx)*(1+l4.retx)*(1+l5.retx)*(1+l6.retx)*(1+l7.retx)*(1+l8.retx)*(1+l9.retx)*(1+l10.retx)*(1+l11.retx)*(1+retx) 
	gen dy = lr12/lrx_12-1

	gen lr24 = lr12*l12.lr12
	gen lrx_24 = lrx_12*l12.lrx_12
	gen lr36 = lr12*l12.lr12*l24.lr12
	gen lrx_36 = lrx_12*l12.lrx_12*l24.lrx_12
	gen fr12 = f12.lr12 
	gen frx_12 = f12.lrx_12
	gen fr24 = f12.lr12*f24.lr12
	gen frx_24 = f12.lrx_12*f24.lrx_12
	
	drop ret*
	
	preserve
	drop permno
	tempfile price1
	save "`price1'"
	restore
	
	preserve
	drop cusip
	ren permno lpermno
	*ren mkval mkval1
	tempfile price2
	save "`price2'"
	restore
	
/* CRSP-Compustat Link */

	use "$CRSP/CCM_qtr.dta", clear
	
	ren *, lower
		
	gen order = 1 if linktype == "LC"
	replace order = 2 if linktype == "LU"
	replace order = 3 if linktype == "LN"
	replace order = 4 if order ==.

	bysort gvkey datadate: egen order_min = min(order)
	keep if order == order_min

	duplicates drop gvkey datadate, force

	tempfile ccm
	save "`ccm'"

***** Compustat *****
*/
	use "$CSTAT/compustat_ann.dta", clear
		
	*merge 1:1 gvkey datadate using "`ccm'", keep (1 3) keepusing(linktype lpermno lpermco)
	*drop _merge
	
	drop if at==.
	drop if fyear==.
	
	*Keep only US companies
	keep if fic=="USA"
	
	destring sic, replace
	*Drop federal agencies
	drop if tic=="3FNMA" //Fannie Mae
	drop if tic=="3FMCC" //Freddie Mac
	*Issuer CUSIP
	replace cusip=substr(cusip,1,8)
	gen cusip6=substr(cusip,1,6)
	
/* Corrections for Operating Leases after 2019 */

	destring gvkey, replace

* FIXME: this data file seems to be missing from the replication package and README. Maybe defined in oplease.do?
/*	merge 1:1 gvkey datadate using "../Lease/lease_firm.dta", keep (1 3) keepusing(rouantq llcq llltq postadoption)
	tab _merge if fyear>=2019
	drop _merge
	
	replace at = at - rouantq if rouantq!=. & postadoption==1
	replace ppent = ppent - rouantq if rouantq!=. & postadoption==1
	replace dlc = dlc - llcq if llcq!=. & postadoption==1
	replace dltt = dltt - llltq if llltq!=. & postadoption==1
	replace lt = lt - llcq - llltq if llcq!=. & llltq!=. & postadoption==1
	replace lt = lt - rouantq if (llcq==. | llltq==.) & rouantq!=. & postadoption==1
	gen debt = dlc + dltt  
*/	
/* Generate Variables */
	
	* keep only INDL format
	keep if indfmt == "INDL"
	*Set Panel
	xtset gvkey fyear 
	
	*Calendar dates
	gen ym = ym(fyear, fyr) if fyr>=6
	replace ym = ym(fyear+1, fyr) if fyr<=5
	gen yq = qofd(dofm(ym))
	gen year = year(dofm(ym))
	gen yrmo = year*100 + month(dofm(ym))
	
/*	merge 1:1 cusip ym using "`price1'", keep(match master)
	tab _merge
	drop _merge
	
	merge m:1 lpermno ym using "`price2'", keep(1 3 4 5) update
	tab _merge
	drop _merge

	replace mkval = mkval/1000
*/		
	*Liability 
	gen lev = at/seq if seq>0
	gen lev1 = (dlc+dltt)/at
	gen lt_at = lt/at
	gen ap_at = ap/at
	
	*Asset 
	gen ppent_at = ppent/at
	gen ppegt_at = ppegt/at
	gen invt_at = invt/at
    gen rect_at = rect/at
	gen cash_at = che/at
	gen gdwl_at = gdwl/at
	gen intan_at = intan/at
	gen intano_at = intano/at
	replace intano_at = intan/at if intano==.
	
	*Cash Flow
	xtset
	gen ni_at = ni/l.at
	gen ebitda_at = ebitda/l.at
	gen ebit_at = ebit/l.at
	gen ib_at = ib/l.at
	gen sale_at = sale/l.at
	
	*Valuations
/*	gen Q = (mkval+dlc+dltt)/at
	gen Q2 = (mkval+at-seq)/at
	gen mtb = mkval/ceq
	gen btm = ceq/mkval
*/		
	*Investment 
	gen capx_at = capx/l.at
	gen capx_ppent = capx/l.ppent
	gen capx_ppegt = capx/l.ppegt
	gen invtgr = invt/l.invt - 1
	gen empgr = emp/l.emp - 1
	gen xrd_at = xrd/l.at
	gen aqc_at = aqc/l.at
	

/* Winsorize */
* QUESTION: is this winsorization well documented? Does it matter for results?
/*	
	foreach item of varlist lev - aqc_at  {
      bysort fyear: egen tmp_ph=pctile(`item'), p(99)
      bysort fyear: egen tmp_pl=pctile(`item'), p(1)
      replace `item'=. if `item'>tmp_ph 
	  replace `item'=. if `item'<tmp_pl 
      drop tmp*
    }  
	
	foreach item of varlist lr* fr*  {
      bysort fyear: egen tmp_ph=pctile(`item'), p(99)
      bysort fyear: egen tmp_pl=pctile(`item'), p(1)
      replace `item'=. if `item'>tmp_ph 
	  replace `item'=. if `item'<tmp_pl 
      drop tmp*
	 
	  replace `item' = `item' - 1
    }
*/
/* Quartiles */

	local k = 3
	foreach item of varlist at {

	forvalues t=1/`k'{
	local h = `t'*(100/(`k'+1))
	bysort year: egen `item'_p`h'=pctile(`item') , p(`h')
	}

	gen `item'_tile = . 

	forvalues t=1/`k'{
	local h = `t'*(100/(`k'+1))
	local b = (`t'-1)*(100/(`k'+1))

	if `t' == 1{
	replace `item'_tile = 1 if `item'<=`item'_p`h' & `item'!=.
	}
	else {
	replace `item'_tile = `t' if `item'<=`item'_p`h' & `item'>`item'_p`b' & `item'!=.
	}
	}
	local s = (100/(`k'+1))*`k'
	replace `item'_tile = `k'+1 if `item'>`item'_p`s' & `item'!=.
	drop `item'_p*
	
	}
	
gen sic2 = floor(sic/100)
gen sic3 = floor(sic/10)	
gen lnsize = ln(at)

save "$CSTAT/compustat_ann_out.dta", replace

	
