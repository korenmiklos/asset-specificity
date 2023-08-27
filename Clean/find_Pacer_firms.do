use "Data/PacerRecovery_detail.dta", clear
keep cik
keep if !missing(cik)
duplicates drop
tempfile cik
generate str file = "Pacer" 
save `cik', replace

use "Data/Compustat/compustat_deletion.dta", clear
keep gvkey fyear indfmt dlrsn dldte
keep if indfmt == "INDL"

* keep only bankruptcies and liquidations
keep if inlist(dlrsn, "02", "03", "09")
generate byte bankrupt = 1 if dlrsn == "02"
bysort gvkey (fyear): keep if _n == _N

generate file = "delete"
tempfile delete
save `delete', replace

use "Data/Compustat/compustat_ann.dta"
destring cik, force replace
keep if !missing(cik)
keep if indfmt == "INDL"

merge m:1 cik using `cik', keep(master match) 
rename _merge merge_Pacer
merge m:1 gvkey using `delete', keep(master match)
rename _merge merge_delete
drop if merge_delete == 1 & merge_Pacer  == 1

* impute zero SPPE
replace sppe = 0 if missing(sppe)
replace sppe = 0 if sppe < 0

keep gvkey cik fyear *ppe* merge* dl*
xtset cik fyear

egen last_ppe_year = max(cond(ppent > 0 & !missing(ppent), fyear, .)), by(gvkey)
drop if fyear > last_ppe_year

generate event_time = fyear - last_ppe_year
keep if event_time >= -10

generate PPE_sale_share = sppe / L.ppent
