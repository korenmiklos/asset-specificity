****************************************************
*Code to clean and process Compustat Quarterly data*
****************************************************

clear all

set matsize 11000
set more off, permanently

if ("`c(username)'" == "yueranma") |  ("`c(username)'" == "Yueran Ma")  |  ("`c(username)'" == "sony") {
	global DATA "../Data/"
	global CSTAT "$DATA/Compustat"
	global CRSP "$DATA/CRSP"
}

***** CRSP *****

/* Stock Returns */

	use "$CRSP/crsp_mon.dta", clear
	ren *, lower
	
	keep if trdstat == "A"

	gen ym = mofd(date)
	format ym %tm
	duplicates drop 
	
	gen shares_adj = shrout*cfacshr
	gen prc_adj = abs(prc)/cfacpr
	
	gen mkval = shares_adj*prc_adj
	
	keep permno cusip ym mkval ret retx shrout cfacshr shares_adj prc_adj
	duplicates drop 
	xtset permno ym
	
	gen lr12 = (1+l.ret)*(1+l2.ret)*(1+l3.ret)*(1+l4.ret)*(1+l5.ret)*(1+l6.ret)*(1+l7.ret)*(1+l8.ret)*(1+l9.ret)*(1+l10.ret)*(1+l11.ret)*(1+ret) 
	gen lrx_12 = (1+l.retx)*(1+l2.retx)*(1+l3.retx)*(1+l4.retx)*(1+l5.retx)*(1+l6.retx)*(1+l7.retx)*(1+l8.retx)*(1+l9.retx)*(1+l10.retx)*(1+l11.retx)*(1+retx) 
	gen dp = lr12/lrx_12-1

	gen lr24 = lr12*l12.lr12
	gen lrx_24 = lrx_12*l12.lrx_12
	gen lr36 = lr12*l12.lr12*l24.lr12
	gen lrx_36 = lrx_12*l12.lrx_12*l24.lrx_12
	gen fr12 = f12.lr12 
	gen frx_12 = f12.lrx_12
	gen fr24 = f12.lr12*f24.lr12
	gen frx_24 = f12.lrx_12*f24.lrx_12
	
	drop ret*  cfacshr
	
	preserve
	drop permno
	tempfile price1
	save "`price1'"
	restore
	
	preserve
	drop cusip
	ren permno lpermno
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
	
	destring gvkey, replace

	tempfile ccm
	save "`ccm'"

***** Compustat *****

	use "$CSTAT/compustat_qtr.dta", clear
	
	drop if atq==.
	
/* Corrections for Operating Leases after 2019 */
	
	destring gvkey, replace
	
	merge m:1 gvkey datadate using "../Lease/lease_firm.dta", keep (1 3) keepusing(rouantq llcq llltq postadoption)
	tab _merge if fyear>=2019
	drop _merge
	
	replace atq = atq - rouantq if rouantq!=. & postadoption==1
	replace ppentq = ppentq - rouantq if rouantq!=. & postadoption==1
	replace dlcq = dlcq - llcq if llcq!=. & postadoption==1
	replace dlttq = dlttq - llltq if llltq!=. & postadoption==1
	replace ltq = ltq - llcq - llltq if llcq!=. & llltq!=. & postadoption==1
	replace ltq = ltq - rouantq if (llcq==. | llltq==.) & rouantq!=. & postadoption==1
	gen debt = dlcq + dlttq  
	
	merge m:1 gvkey datadate using "`ccm'", keep (1 3) keepusing(linktype lpermno lpermco)
	drop _merge
	
	*Keep only US companies
	keep if fic=="USA"

	destring sic, replace
	*Drop federal agencies
	drop if tic=="3FNMA" //Fannie Mae
	drop if tic=="3FMCC" //Freddie Mac
	replace cusip=substr(cusip,1,8)
	gen cusip6=substr(cusip,1,6)
	
    gsort gvkey fyearq fqtr -datadate
	by gvkey fyearq fqtr: gen dup = cond(_N==1,0,_n)
	drop if dup>1
	drop dup
	
/* Generate Variables */
	
	gen fyq = yq(fyearq, fqtr)
	xtset gvkey fyq
	
	gen capx = capxy-l.capxy
	replace capx = capxy if fqtr==1
	
    gen acq=aqcy-l.aqcy
    replace acq=aqcy if fqtr==1
	
/*Fiscal Dates to Calendar Dates */	 

	gen month=fqtr*3
	gen date=mdy(month,1,fyearq)
	gen ym = mofd(date)
	
		replace ym = ym - 6 if fyr==6
		replace ym = ym - 5 if fyr==7
		replace ym = ym - 4 if fyr==8
		replace ym = ym - 3 if fyr==9
		replace ym = ym - 2 if fyr==10
		replace ym = ym - 1 if fyr==11
		replace ym = ym + 1 if fyr==1
		replace ym = ym + 2 if fyr==2
		replace ym = ym + 3 if fyr==3
		replace ym = ym + 4 if fyr==4
		replace ym = ym + 5 if fyr==5
		replace date = dofm(ym)
		replace month = month(date)
		gen year = year(date)
		gen qtr = quarter(date)
			
	gen yrmo=100*year+month 
	gen yearq = year*10+qtr 
	gen yq = yq(year, qtr) 
	gen fyrq = yq(fyearq, fqtr)

	format ym %tm
	format yq %tq
	
	gsort gvkey yq -datadate -fyearq -fqtr  
	by gvkey yq: gen dup = cond(_N==1,0,_n)
	drop if dup>1
	drop dup
	
	xtset gvkey yq
	
replace cusip=substr(cusip,1,8)
ren tic ticker
drop if ticker==""
drop mkval*
	
	merge 1:1 cusip ym using "`price1'", keep(match master)
	tab _merge
	drop _merge
	
	merge m:1 lpermno ym using "`price2'", keep(1 3 4 5) update
	tab _merge
	drop _merge
	
	replace mkval = mkval/1000	

xtset

	*Liability
	gen lev = atq/seqq if seqq>0
	gen lev1 = (dlcq+dlttq)/atq
	gen lt_at = ltq/atq
	
	*Asset
	gen ppent_at = ppentq/atq
	gen ppegt_at = ppegtq/atq
	gen invt_at = invtq/atq
    gen rect_at = rectq/atq
	gen cash_at = cheq/atq
	gen gdwl_at = gdwlq/atq
	gen intan_at = intanq/atq
	
	*Cash and Cash Flow
	xtset
	gen ni_at = niq/l.atq
	gen cf_at = (ibq+dpq)/l.atq
	gen ib_at = ibq/l.atq
	gen ebit_at = oiadpq/l.atq
	gen ebitda_at = ebitdaq/l.atq
	gen sale_at = saleq/l.atq

	*Valuation
	gen Q = (mkval+dlcq+dlttq)/atq
	gen Q2 = (mkval+atq-seqq)/atq
	gen mtb = mkval/ceqq
	gen btm = ceqq/mkval
	
	*Investment 
	gen capx_at = capx/l.atq
	gen capx_ppent = capx/l.ppentq
	gen capx_ppegt = capx/l.ppegtq
	gen xrd_at = xrdq/l.atq
	gen acq_at = acq/l.atq
	

/* Winsorize */

	foreach item of varlist lev - acq_at {
      bysort yq: egen tmp_ph=pctile(`item'), p(99)
      bysort yq: egen tmp_pl=pctile(`item'), p(1)
      replace `item'=. if `item'>tmp_ph 
	  replace `item'=. if `item'<tmp_pl 
      drop tmp*
    }  
	
xtset 

/* Quartiles */
	
	local k = 3
	foreach item of varlist atq {

	forvalues t=1/`k'{
	local h = `t'*(100/(`k'+1))
	bysort yq: egen `item'_p`h'=pctile(`item') , p(`h')
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

save "$CSTAT/compustat_qtr_out.dta", replace
