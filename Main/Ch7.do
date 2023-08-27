clear all

if 1 | ("`c(username)'" == "yueranma") |  ("`c(username)'" == "Yueran Ma")  |  ("`c(username)'" == "sony") {
	global DATA "./Data"
	global CAPIQ "$DATA/CapitalIQ"
	global CSTAT "$DATA/Compustat"
	global PACER "$DATA/PACER"
	global TABLES "../Tables"
}


/* Supplement info for potentially abandoned assets */

use "$CSTAT/compustat_ann_out.dta", clear

gen sic2 = floor(sic/100)
destring gvkey, replace

drop if year>2018
drop if year<2000

drop if sic>=6000 & sic<7000
drop if sic>=9000 & sic!=.

merge 1:1 gvkey fyear using "$CAPIQ/debttype_out.dta", keep(1 3)  keepusing(abl secured*)
tab _merge
drop _merge

drop if ein==""
duplicates drop ein yq, force
gen EINTAXID = subinstr(ein, "-", "", .)
destring EINTAXID, replace

keep EINTAXID yq secured secureddbt abl dm
ren EINTAXID ein

tempfile secured
save "`secured'"

/* Chapter 7 Dataset */

use "$DATA/PACER/Chapter7.dta", clear

forvalues t=0/8{
gen yq = qofd(date) - `t'
merge m:1 ein yq using "`secured'", keep(1 3 4 5) update
tab _merge
drop _merge
drop yq
}

/* Estimate Chapter 7 Total Recovery Rate */

gen liqrecov7 = LiquidationReceipt/ActualAsset
replace liqrecov7 = . if liqrecov7 >2
sum liqrecov7, detail

gen liqrecovm1 = LiquidationReceipt/ActualAsset + 0.5*abl*10^6/ActualAsset
replace liqrecovm1 = . if liqrecovm1 >2
sum liqrecovm1, detail

gen liqrecovm2 = LiquidationReceipt/ActualAsset + 0.5*secured*10^6/ActualAsset
replace liqrecovm2 = . if liqrecovm2 >2
sum liqrecovm2, detail

gen liqrecovh1 = LiquidationReceipt/ActualAsset + 1*abl*10^6/ActualAsset
replace liqrecovh1 = . if liqrecovh1 >2
sum liqrecovh1, detail

gen liqrecovh2 = LiquidationReceipt/ActualAsset + 1*secured*10^6/ActualAsset
replace liqrecovh2 = . if liqrecovh2 >2
sum liqrecovh2, detail

save "$DATA/PACER/Chapter7_out.dta", replace

*** Cross Checks Table ***

use "$DATA/PACER/Chapter7_out.dta", clear

keep if year(date)>=2000 & year(date)<=2018
drop if sic2>=60 & sic2<70
drop if sic2>=90

collapse (mean) liqrecov7 liqrecovm1 liqrecovm2 liqrecovh1 liqrecovh2

gen chapter = "Chapter 7 avg"

format %4.2f liqrecov7 liqrecovm1 liqrecovm2 liqrecovh1 liqrecovh2
order chapter liqrecov7 liqrecovm1 liqrecovm2 liqrecovh1 liqrecovh2

listtex chapter liqrecov7 liqrecovm1 liqrecovm2 liqrecovh1 liqrecovh2  using "$TABLES/TableIA2_PanelA_part1.tex", 	delimiter(&) end(\\) replace	

/* Ch 11 Estimates & Ch 7 Results */

use "$DATA/PACER/Chapter7_out.dta", clear

gen casenum = subinstr(Case, "-", "", .)
replace casenum = subinstr(casenum, " ", "", .) 
destring casenum, replace

tempfile ch7
save "`ch7'"

import excel "$PACER/bankruptcy_filing.xlsx",  firstrow clear

gen date = date(BankruptcyDate, "YMD")
format date %td

gen casenum = subinstr(Case, "-", "", .)
replace casenum = subinstr(casenum, " ", "", .) 
destring casenum, replace

ren EIN ein

gen lnast = log(ActualAssets)
gen lnsale = log(ActualSales)
gen sale_at = ActualSales/ActualAssets
ren SICCode sic
gen sic2 = floor(sic/100)

merge 1:1 casenum date ein using "$DATA/PacerRecovery_detail.dta", keep(1 3) keepusing(GrossLiquidation*)
tab _merge
drop _merge

merge 1:1 casenum date  ein using "`ch7'", keep(1 3) keepusing(LiquidationReceipt liqrecov*)
tab _merge
drop _merge

keep if year(date)>=2000 & year(date)<=2018
drop if sic2>=60 & sic2<70
drop if sic2>=90
gen year = year(date)
keep if Public == "Yes"

gen convert = 0 if FilingType=="Chapter 11"
replace convert = 1 if strpos(Outcome, "Convert")
gen ch7 = 0 if FilingType=="Chapter 11"
replace ch7 = 1 if strpos(Outcome, "Convert")
replace ch7 = 1 if strpos(Outcome, "Liquidate")
replace ch7 = 1 if FilingType=="Chapter 7"

*Ch11 Estimated Liquidation Recovery Rate (Total Liquidation Value for Liquidation Analysis/Book Value for Liquidation Analysis)
gen liqrecov =   GrossLiquidationMid*10^6/ActualAsset   
replace liqrecov = . if liqrecov>2

// Cross Checks Table part 2
sum liqrecov, detail 

preserve
collapse (mean) liqrecov
gen chapter = "Chapter 11 est avg"

format %4.2f liqrecov 
order chapter liqrecov

listtex chapter liqrecov using "$TABLES/TableIA2_PanelA_part2.tex", delimiter(&) end(\\) replace
restore

gen liqval = liqrecov7  // Chapter 7 liquidation value
replace liqval = liqrecov if liqval==.  // Chapter 11 liquidation value
replace liqval = . if liqval>2

forvalues t = 1/2{
gen liqvalm`t' = liqrecovm`t'  // Chapter 7 liquidation value (add asset-based debt)
replace liqvalm`t' = liqrecov if liqrecovm`t'==.  // Chapter 11 liquidation value
replace liqvalm`t' = . if liqvalm`t'>2

gen liqvalh`t' = liqrecovh`t'  // Chapter 7 liquidation value (add all secured debt)
replace liqvalh`t' = liqrecov if liqrecovh`t'==.  // Chapter 11 liquidation value
replace liqvalh`t' = . if liqvalh`t'>2
}

eststo clear

label var liqval "Liquidation Value"
label var ch7 "Chapter 7"

eststo: ivreg2 liqval ch7 lnsale  i.year i.sic2 , cluster(year) partial(i.year i.sic2)
estadd local yearFE "Yes"
estadd local indFE "Yes"

foreach s in "m" "h" {
forvalues t = 1/2 {
	label var liqval`s'`t' "Liquidation Value"
	eststo: ivreg2 liqval`s'`t' ch7 lnsale  i.year i.sic2 , cluster(year) partial(i.year i.sic2)
	estadd local yearFE "Yes"
	estadd local indFE "Yes"
}
}

	esttab using "$TABLES/TableIA2_PanelB.tex", 	b(%5.3f) se(%5.3f)   
			mtitles("Basic" "Medium v1" "Medium v2" "High v1" "High v2") 	///
			mgroups("Total Liquidation Value/Total Assets", 	///
				pattern(1 0 0 0 0) 	///
				prefix(\multicolumn{@span}{c}{) suffix(}) span ) 	///
			scalars("yearFE Time fixed effects" 	///
					"indFE Industry fixed effects") 	///
			sfmt(%12.0fc) drop(lnsale) ///
			label compress nogaps booktabs noobs	///
			fragment wrap varwidth(27) replace	




