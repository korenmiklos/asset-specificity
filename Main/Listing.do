clear all

set matsize 11000
set more off, permanently

if 1 | ("`c(username)'" == "yueranma") |  ("`c(username)'" == "Yueran Ma")  |  ("`c(username)'" == "sony") {
	global DATA "./Data"
	global FIGURES "./Figures"
	global TABLES "./Tables"
}

/* Liquidation Recovery Rate by Industry */

use "$DATA/PacerRecovery.dta", clear

sort sic2

keep sic2 RecoveryPPEMid RecoveryInventoryMid RecoveryReceivableMid RecoveryIntanMid RecoveryIntanNGWMid
order sic2 RecoveryPPEMid RecoveryInventoryMid RecoveryReceivableMid RecoveryIntanMid RecoveryIntanNGWMid

drop if  RecoveryPPEMid==.

label define sicl2 10 "Metal mining" 12 "Coal mining" 13 "Oil/gas extraction" 	///
	14 "Quarrying-nonmetals" 15 "Building construction" 	///
	16 "Other heavy construction" 17 "Construction contractors" 	///
	20 "Food products" 21 "Tobacco products" 22 "Textile products" 	///
	23 "Apparel products" 24 "Wood products" 25 "Furniture and fixtures" 	///
	26 "Paper products" 27 "Printing and publishing" 	///
	28 "Chemical products" 29 "Petroleum refining" 	///
	30 "Rubber and plastics products" 31 "Leather products" 	///
	32 "Stone, clay, glass, and concrete" 33 "Primary metal" 	///
	34 "Fabricated metal" 	///
	35 "Machinery" 	///
	36 "Electronic equipment" 	///
	37 "Transportation equipment" 	///
	38 "Analytical instruments" 	///
	39 "Misc. manufacturing" 	///
	40 "Railroad transportation" 41 "Local transit" 	///
	42 "Motor freight" 43 "USPS" 	///
	44 "Water transportation" 45 "Transportation by air" 46 "Pipelines" 	///
	47 "Transportation services" 48 "Communications" 49 "Electric and gas" 	///
	50 "Wholesale durables" 51 "Wholesale non-durables" 	///
	52 "Building materials dealers" 	///
	53 "General merchandise stores" 54 "Grocery stores" 	///
	55 "Automotive dealers" 56 "Apparel stores" 	///
	57 "Furniture stores" 58 "Restaurants" 	///
	59 "Misc. retail" 	///
	70 "Lodging" 72 "Personal services" 	///
	73 "Business services" 75 "Automotive repair" 	///
	76 "Misc. repair services" 78 "Motion pictures" 	///
	79 "Amusement and recreation" 80 "Health services" 81 "Legal services" 	///
	82 "Educational services" 83 "Social services" 	///
	84 "Museums" 86 "Membership organizations" 	87 "Professional services"
label values sic2 sicl2	

decode sic2, gen(sic2_str)
label drop sicl2
label values sic2

tostring sic2, replace
replace sic2_str = sic2 + " " + sic2_str
destring sic2, replace

gen int N = 1

foreach item of varlist Recovery*Mid*{
replace `item' = `item'/100
gen `item'_r = round(`item', 0.01)
gen `item'_s = string(`item'_r, "%03.2f")
}

// Output 
listtab  sic2_str RecoveryPPEMid_s RecoveryInventoryMid_s RecoveryReceivableMid_s RecoveryIntanMid_s RecoveryIntanNGWMid_s using "$TABLES/TableII.tex", 	///
	delimiter(&) end(\\) replace


/* Number Per Industry */

use "$DATA/PacerRecovery_detail.dta", clear

label define sicl2 10 "Metal mining" 12 "Coal mining" 13 "Oil/gas extraction" 	///
	14 "Quarrying-nonmetals" 15 "Building construction" 	///
	16 "Other heavy construction" 17 "Construction contractors" 	///
	20 "Food products" 21 "Tobacco products" 22 "Textile products" 	///
	23 "Apparel products" 24 "Wood products" 25 "Furniture and fixtures" 	///
	26 "Paper products" 27 "Printing and publishing" 	///
	28 "Chemical products" 29 "Petroleum refining" 	///
	30 "Rubber and plastics products" 31 "Leather products" 	///
	32 "Stone, clay, glass, and concrete" 33 "Primary metal" 	///
	34 "Fabricated metal" 	///
	35 "Machinery" 	///
	36 "Electronic equipment" 	///
	37 "Transportation equipment" 	///
	38 "Analytical instruments" 	///
	39 "Misc. manufacturing" 	///
	40 "Railroad transportation" 41 "Local transit" 	///
	42 "Motor freight" 43 "USPS" 	///
	44 "Water transportation" 45 "Transportation by air" 46 "Pipelines" 	///
	47 "Transportation services" 48 "Communications" 49 "Electric and gas" 	///
	50 "Wholesale durables" 51 "Wholesale non-durables" 	///
	52 "Building materials dealers" 	///
	53 "General merchandise stores" 54 "Grocery stores" 	///
	55 "Automotive dealers" 56 "Apparel stores" 	///
	57 "Furniture stores" 58 "Restaurants" 	///
	59 "Misc. retail" 	///
	70 "Lodging" 72 "Personal services" 	///
	73 "Business services" 75 "Automotive repair" 	///
	76 "Misc. repair services" 78 "Motion pictures" 	///
	79 "Amusement and recreation" 80 "Health services" 81 "Legal services" 	///
	82 "Educational services" 83 "Social services" 	///
	84 "Museums" 86 "Membership organizations" 	87 "Professional services"
label values sic2 sicl2	

decode sic2, gen(sic2_str)
label drop sicl2
label values sic2

tostring sic2, replace
replace sic2_str = sic2 + " " + sic2_str
destring sic2, replace

drop if missing(RecoveryReceivableMid) & missing(RecoveryInventoryMid) & 	///
	missing(RecoveryPPEMid)

gen int N = 1
drop if missing(sic2)

collapse (sum) N, by(sic2 sic2_str)

// Output
listtex   sic2_str N using "$TABLES/TableIA1.tex", 	///
	delimiter(&) end(\\) replace
	

/* Physical Attributes by Industry */

use "$DATA/RecoveryPhysicsFA97_sic2.dta", clear

keep sic2 wtshare  dp_ppent   wdshares   KEshr
order sic2 wtshare  dp_ppent  wdshares   KEshr

label define sicl2 10 "Metal mining" 12 "Coal mining" 13 "Oil/gas extraction" 	///
	14 "Quarrying-nonmetals" 15 "Building construction" 	///
	16 "Other heavy construction" 17 "Construction contractors" 	///
	20 "Food products" 21 "Tobacco products" 22 "Textile products" 	///
	23 "Apparel products" 24 "Wood products" 25 "Furniture and fixtures" 	///
	26 "Paper products" 27 "Printing and publishing" 	///
	28 "Chemical products" 29 "Petroleum refining" 	///
	30 "Rubber and plastics products" 31 "Leather products" 	///
	32 "Stone, clay, glass, and concrete" 33 "Primary metal" 	///
	34 "Fabricated metal" 	///
	35 "Machinery" 	///
	36 "Electronic equipment" 	///
	37 "Transportation equipment" 	///
	38 "Analytical instruments" 	///
	39 "Misc. manufacturing" 	///
	40 "Railroad transportation" 41 "Local transit" 	///
	42 "Motor freight" 43 "USPS" 	///
	44 "Water transportation" 45 "Transportation by air" 46 "Pipelines" 	///
	47 "Transportation services" 48 "Communications" 49 "Electric and gas" 	///
	50 "Wholesale durables" 51 "Wholesale non-durables" 	///
	52 "Building materials dealers" 	///
	53 "General merchandise stores" 54 "Grocery stores" 	///
	55 "Automotive dealers" 56 "Apparel stores" 	///
	57 "Furniture stores" 58 "Restaurants" 	///
	59 "Misc. retail" 	///
	70 "Lodging" 72 "Personal services" 	///
	73 "Business services" 75 "Automotive repair" 	///
	76 "Misc. repair services" 78 "Motion pictures" 	///
	79 "Amusement and recreation" 80 "Health services" 81 "Legal services" 	///
	82 "Educational services" 83 "Social services" 	///
	84 "Museums" 86 "Membership organizations" 	87 "Professional services"
label values sic2 sicl2	

decode sic2, gen(sic2_str)
label drop sicl2
label values sic2

tostring sic2, replace
replace sic2_str = sic2 + " " + sic2_str
destring sic2, replace

gen int N = 1

foreach item of varlist wtshare  dp_ppent wdshares   KEshr{
gen `item'_r = round(`item', 0.001)
gen `item'_s = string(`item'_r, "%04.3f")
}

// Output 
listtab  sic2_str wtshare_s  dp_ppent_s   wdshares_s   KEshr_s using "$TABLES/TableIA3.tex", 	///
	delimiter(&) end(\\) replace
	
/* Operating Leases */

use "$DATA/Compustat/lease_firm.dta", clear

keep if yearq==20194

collapse (mean) oplease_atex oplease_ppentex, by(sic2)

drop if sic2>=60 & sic2<70
drop if sic2<10

merge m:1 sic2 using "$DATA/PacerRecovery.dta", keep(1 3)  keepusing(RecoveryPPEMid)
tab _merge
drop _merge

keep if RecoveryPPEMid!=. 
drop Recovery*Mid

label define sicl2 10 "Metal mining" 12 "Coal mining" 13 "Oil/gas extraction" 	///
	14 "Quarrying-nonmetals" 15 "Building construction" 	///
	16 "Other heavy construction" 17 "Construction contractors" 	///
	20 "Food products" 21 "Tobacco products" 22 "Textile products" 	///
	23 "Apparel products" 24 "Wood products" 25 "Furniture and fixtures" 	///
	26 "Paper products" 27 "Printing and publishing" 	///
	28 "Chemical products" 29 "Petroleum refining" 	///
	30 "Rubber and plastics products" 31 "Leather products" 	///
	32 "Stone, clay, glass, and concrete" 33 "Primary metal" 	///
	34 "Fabricated metal" 	///
	35 "Machinery" 	///
	36 "Electronic equipment" 	///
	37 "Transportation equipment" 	///
	38 "Analytical instruments" 	///
	39 "Misc. manufacturing" 	///
	40 "Railroad transportation" 41 "Local transit" 	///
	42 "Motor freight" 43 "USPS" 	///
	44 "Water transportation" 45 "Transportation by air" 46 "Pipelines" 	///
	47 "Transportation services" 48 "Communications" 49 "Electric and gas" 	///
	50 "Wholesale durables" 51 "Wholesale non-durables" 	///
	52 "Building materials dealers" 	///
	53 "General merchandise stores" 54 "Grocery stores" 	///
	55 "Automotive dealers" 56 "Apparel stores" 	///
	57 "Furniture stores" 58 "Restaurants" 	///
	59 "Misc. retail" 	///
	70 "Lodging" 72 "Personal services" 	///
	73 "Business services" 75 "Automotive repair" 	///
	76 "Misc. repair services" 78 "Motion pictures" 	///
	79 "Amusement and recreation" 80 "Health services" 81 "Legal services" 	///
	82 "Educational services" 83 "Social services" 	///
	84 "Museums" 86 "Membership organizations" 	87 "Professional services"
label values sic2 sicl2	

decode sic2, gen(sic2_str)
label drop sicl2
label values sic2

tostring sic2, replace
replace sic2_str = sic2 + " " + sic2_str
destring sic2, replace

gen int N = 1

foreach item of varlist oplease_atex oplease_ppentex{
gen `item'_r = round(`item', 0.001)
gen `item'_s = string(`item'_r, "%04.3f")
}

// Output 
listtab  sic2_str oplease_atex_s oplease_ppentex_s using "$TABLES/TableIA21.tex", delimiter(&) end(\\) replace