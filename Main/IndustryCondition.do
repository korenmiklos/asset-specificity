clear all

set matsize 11000
set more off, permanently

if 1 | ("`c(username)'" == "yueranma") |  ("`c(username)'" == "Yueran Ma")  |  ("`c(username)'" == "sony") {
	global DATA "./Data"
	global BEA "$DATA/BEA"
	global CSTAT "$DATA/Compustat"
	global FIGURES "./Figures"
	global TABLES "./Tables"
}


/* BEA Industry GDP */

use "$BEA/OutputbyInd_out.dta", clear

encode sector, gen (id)
xtset id year

gen GOgr = log(GO/l.GO)
gen VAgr = log(VA/l.VA)

tempfile indgdp
save "`indgdp'"

import excel "$BEA/BEAFixedAssetCategory.xlsx", sheet("Industry") firstrow clear

drop if BEACODE == "--------"
drop if BEACODE == ""
ren BEACODE sector

keep sector SIC*
gen n=_n
reshape long SIC, i(n) j(f)
drop n f
drop if SIC==.
ren SIC sic2
duplicates drop sector sic2, force

expand 61
bysort sic2 sector: gen year = _n+1959

merge m:1 sector year using "`indgdp'", keep(1 3) keepusing(*gr*)
tab _merge
drop _merge

collapse (mean) *gr*, by(sic2 year) 

tempfile indgdpgr
save "`indgdpgr'"

/* CRSP Industry Leverage, Sales Growth */

use "$CSTAT/compustat_qtr_out.dta", clear

xtset

gen salegr = log(saleq/l4.saleq) if l4.saleq>0

foreach item of varlist salegr {
  bysort yq: egen tmp_ph=pctile(`item'), p(99)
  bysort yq: egen tmp_pl=pctile(`item'), p(1)
  replace `item'=. if `item'>tmp_ph 
  replace `item'=. if `item'<tmp_pl 
  drop tmp*
}

collapse (mean) levmean=lev1 salegravg = salegr , by(sic2 yq)

xtset sic2 yq

tempfile ind
save "`ind'"

use "$CSTAT/compustat_qtr_out.dta", clear

xtset

gen salegr = log(saleq/l4.saleq) if l4.saleq>0

foreach item of varlist salegr {
  bysort yq: egen tmp_ph=pctile(`item'), p(99)
  bysort yq: egen tmp_pl=pctile(`item'), p(1)
  replace `item'=. if `item'>tmp_ph 
  replace `item'=. if `item'<tmp_pl 
  drop tmp*
}

replace saleq = . if saleq<0

collapse (mean) salegr [aw=saleq], by(sic2 yq)

bysort sic2: egen lowsalegr = pctile(salegr) if year(dofq(yq))>=2000 & year(dofq(yq))<=2018, p(25)
gen indrec = (salegr<=lowsalegr)  if year(dofq(yq))>=2000 & year(dofq(yq))<=2018
drop lowsalegr

tempfile inda
save "`inda'"

/* Macro Conditions */

freduse USRECQ, clear

tab USRECQ if year(daten)>=2000 & year(daten)<=2018
gen yq = qofd(daten)
drop date*

tempfile recd
save "`recd'"

******************************************************

/* Case Level Liquidation Analysis Data */

use "$DATA/PacerRecovery_detail.dta", clear

gen yq = qofd(DocumentdateLiq)  -1
format yq %tq

gen year = year(dofq(yq))

drop if sic2>=60 & sic2<70
drop if sic2<10

merge m:1 sic2 yq using "`ind'", keep(1 3)
tab _merge
drop _merge

merge m:1 sic2 yq using "`inda'", keep(1 3)
tab _merge
drop _merge

merge m:1 sic2 year using "`indgdpgr'", keep(1 3)
tab _merge
drop _merge

merge m:1 yq using "`recd'", keep(1 3)
tab _merge
drop _merge

//Firm characteristcis at filing (NGR data supplemented with Compustat)
gen levfiling = ActualLiabilities/ActualAssets
gen sale_at = (ActualSales)/ActualAssets

replace levfiling = ltq/atq if levfiling==.
replace sale_at = saleq/atq if sale_at==.

	foreach item of varlist levfiling sale_at{
      egen tmp_ph=pctile(`item'), p(99)
      egen tmp_pl=pctile(`item'), p(1)
      replace `item'= . if `item'>tmp_ph & `item'!=.
	  replace `item'= . if `item'<tmp_pl & `item'!=.
      drop tmp*
    }  

replace RecoveryPPEMid = RecoveryPPEMid/100

tab USRECQ if RecoveryPPEMid!=. 
tab indrec if RecoveryPPEMid!=.  

********Cyclicality Regressions********

label var salegravg "Industry sales growth"
label var VAgr "Industry value added growth"
label var levmean "Industry leverage"
label var sale_at "Sales/assets"
label var levfiling "Liabilities/assets"

eststo clear

local item salegravg
eststo: reghdfe RecoveryPPEMid `item', cluster(year sic2) absorb(sic2)
sum `item' if e(sample), detail
eststo: reghdfe RecoveryPPEMid `item' sale_at levfiling, cluster(year sic2) absorb(sic2)

local item VAgr
eststo: reghdfe RecoveryPPEMid `item', cluster(year sic2) absorb(sic2)
sum `item' if e(sample), detail
eststo: reghdfe RecoveryPPEMid `item' sale_at levfiling , cluster(year sic2) absorb(sic2)

local item levmean  
eststo: reghdfe RecoveryPPEMid `item', cluster(year sic2) absorb(sic2)
sum `item' if e(sample), detail
eststo: reghdfe RecoveryPPEMid `item' sale_at levfiling , cluster(year sic2) absorb(sic2)

estout using "$TABLES/TableIV_PanelB.tex", replace style(tex) label mlabels(none) cells(b(fmt(3) star ) se(fmt(3) par)) ///
keep(salegravg VAgr levmean sale_at levfiling  ) order(salegravg VAgr levmean sale_at levfiling)  /// 
starlevels(* .10 ** .05 *** .01)  collabels(none)

estout using "$TABLES/TableIV_PanelB_r2.tex", replace style(tex) cells(none) ///
stats(N r2_within, fmt(%9.0fc %9.3f) labels("Obs" "R$^2$" ) ) mlabels(none) collabels(none)
