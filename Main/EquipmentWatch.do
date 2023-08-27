clear all

set matsize 11000
set more off, permanently

if 1 | ("`c(username)'" == "yueranma") |  ("`c(username)'" == "Yueran Ma")  |  ("`c(username)'" == "sony") {
	global DATA "./Data"
}


****** Original Price ******

import delimited "$DATA/EquipmentWatch/original_price.csv", clear case(preserve)

forvalues t = 1990/2019 {
replace Model = subinstr(Model, " (disc. `t')", "", .) 
}
replace Model = subinstr(Model, " ", "", .) 
replace Model = subinstr(Model, "-", "", .) 
replace Model = subinstr(Model, ".", "", .) 
replace Model = lower(Model)

replace Manufacturer = subinstr(Manufacturer, " ", "", .)
replace Manufacturer = subinstr(Manufacturer, "-", "", .)
replace Manufacturer = subinstr(Manufacturer, ".", "", .)
replace Manufacturer = lower(Manufacturer)

ren Manufacturer manufacturer
ren Model model
ren ModelYear year_built

drop if year_built == "No data available"
destring year_built, replace

gen manufacturermodel = manufacturer + model

drop if OriginalPrice==.
duplicates drop manufacturer model year_built, force
 
tempfile price
save "`price'"

****** PPI for Machinery ******

freduse WPS114, clear

ren WPS114 ppi_machinery

gen ym = mofd(daten)

collapse (mean) ppi, by(ym)

tempfile ppi
save "`ppi'"

****** Murfin-Pratt Auction Sample ******

use "$DATA/EquipmentWatch/auctions_full.dta", clear     

gen inusa = 0
replace inusa = 1 if city=="On-Line"
replace inusa = 1 if state_code=="AL"
replace inusa = 1 if state_code=="AK"
replace inusa = 1 if state_code=="AZ"
replace inusa = 1 if state_code=="AR"
replace inusa = 1 if state_code=="CA"
replace inusa = 1 if state_code=="CO"
replace inusa = 1 if state_code=="CT"
replace inusa = 1 if state_code=="DE"
replace inusa = 1 if state_code=="DC"
replace inusa = 1 if state_code=="FL"
replace inusa = 1 if state_code=="GA"
replace inusa = 1 if state_code=="HI"
replace inusa = 1 if state_code=="ID"
replace inusa = 1 if state_code=="IL"
replace inusa = 1 if state_code=="IN"
replace inusa = 1 if state_code=="IA"
replace inusa = 1 if state_code=="KS"
replace inusa = 1 if state_code=="KY"
replace inusa = 1 if state_code=="LA"
replace inusa = 1 if state_code=="ME"
replace inusa = 1 if state_code=="MD"
replace inusa = 1 if state_code=="MA"
replace inusa = 1 if state_code=="MI"
replace inusa = 1 if state_code=="MN"
replace inusa = 1 if state_code=="MS"
replace inusa = 1 if state_code=="MO"
replace inusa = 1 if state_code=="MT"
replace inusa = 1 if state_code=="NE"
replace inusa = 1 if state_code=="NV"
replace inusa = 1 if state_code=="NH"
replace inusa = 1 if state_code=="NJ"
replace inusa = 1 if state_code=="NM"
replace inusa = 1 if state_code=="NY"
replace inusa = 1 if state_code=="NC"
replace inusa = 1 if state_code=="ND"
replace inusa = 1 if state_code=="OH"
replace inusa = 1 if state_code=="OK"
replace inusa = 1 if state_code=="OR"
replace inusa = 1 if state_code=="PA"
replace inusa = 1 if state_code=="PR"
replace inusa = 1 if state_code=="RI"
replace inusa = 1 if state_code=="SC"
replace inusa = 1 if state_code=="SD"
replace inusa = 1 if state_code=="TN"
replace inusa = 1 if state_code=="TX"
replace inusa = 1 if state_code=="UT"
replace inusa = 1 if state_code=="VT"
replace inusa = 1 if state_code=="VA"
replace inusa = 1 if state_code=="WA"
replace inusa = 1 if state_code=="WV"
replace inusa = 1 if state_code=="WI"
replace inusa = 1 if state_code=="WY"

keep if inusa == 1
drop inusa

tab state_name 

gen year = floor(start_date/10^4)
tab year

gen month = floor((start_date - year*10^4)/100)

gen day = mod(start_date, 100)

gen tmp = mdy(month, day, year)
format tmp %td

drop start_date
ren tmp start_date

gen ym = ym(year, month)
format ym %tm

gen quarter = quarter(dofm(ym))
tab quarter

gen yq = yq(year, quarter)
format yq %tq

gen age = year - year_built
tab age

replace model = subinstr(model, " ", "", .) 
replace model = subinstr(model, "-", "", .) 
replace model = subinstr(model, ".", "", .) 
replace model = lower(model)

replace manufacturer = subinstr(manufacturer, " ", "", .)
replace manufacturer = subinstr(manufacturer, "-", "", .)
replace manufacturer = subinstr(manufacturer, ".", "", .)
replace manufacturer = lower(manufacturer)

gen manufacturermodel = manufacturer + model


/* Merge Original Price */

merge m:1 manufacturermodel year_built using "`price'", keep(1 3) keepusing(OriginalPrice)
tab _merge
drop _merge

/* Merge Machinery PPI */

merge m:1 ym using "`ppi'", keep(1 3)
tab _merge
drop _merge

/* Equipment Categories */

gen construction = 1 if strpos(equipment_category, "Lift") | strpos(equipment_category, "Asphalt") | strpos(equipment_category, "Concrete") | strpos(equipment_category, "Crane") | equipment_category=="Compactors" | strpos(equipment_category, "Graders")  | strpos(equipment_category, "Hoists")  | strpos(equipment_category, "Road")  | strpos(equipment_category, "Scraper")  | strpos(equipment_category, "Loader") | strpos(equipment_category, "Aggregate")  
gen agriculture = 1 if strpos(equipment_category, "Agricultural") | strpos(equipment_category, "Forestry") //| strpos(equipment_category, "Tractors") 
gen car = 1 if equipment_category=="Autos & Vehicles" | (strpos(equipment_category, "Truck") & construction!=1) |  (strpos(equipment_category, "Trailer") & construction!=1)
gen utility = 1 if strpos(equipment_category, "Generator")
gen tractor = strpos(equipment_category, "Tractor") |  strpos(equipment_category, "Trencher") 

gen etype = 1 if construction == 1
replace etype = 2 if agriculture == 1
replace etype = 3 if tractor == 1
replace etype = 4 if car == 1
replace etype = 5 if utility == 1

gen l_age=log(1+age)
egen group = group(manufacturer equipment_category)
egen bucket = group(equipment_category age)  
egen group2 = group(manufacturer equipment_category condition age)  
egen season = group(quarter equipment_category)
egen modelyear = group(manufacturermodel year_built)

gen auction_price_df = auction_price_usd/(ppi/100)
gen logauction_price_df = ln(auction_price_df) 
gen logauction_price_usd = ln(auction_price_usd)


/* Estimate Depreciation Rate */

gen age2 = age^2
gen dep1 = .
gen dep2 = .

forvalues t = 1/5 {

reghdfe logauction_price_df age age2 if age>=0 & age<=30 & etype==`t'   , absorb( manufacturermodel ) 
replace dep1 = _b[age] if etype==`t'  
replace dep2 = _b[age2] if etype==`t'  

}

/* Auction Recovery Rate */

gen recover = auction_price_usd/(OriginalPrice*exp(dep1*age+dep2*age2))

foreach item in recover  {
egen tmp_ph=pctile(`item'), p(99)
egen tmp_pl=pctile(`item'), p(1)
replace `item'=. if `item'>tmp_ph 
replace `item'=. if `item'<tmp_pl 
drop tmp_* 
}

sum recover if etype==1  , detail

/* Construction Industry Condition */

preserve

use "$CSTAT/compustat_qtr_out.dta", clear

gen sic2 = floor(sic/100)
xtset

drop salegr
gen salegr = log(saleq/l4.saleq) if l4.saleq>0

foreach item of varlist salegr {
  bysort yq: egen tmp_ph=pctile(`item'), p(99)
  bysort yq: egen tmp_pl=pctile(`item'), p(1)
  replace `item'=. if `item'>tmp_ph 
  replace `item'=. if `item'<tmp_pl 
  drop tmp*
}

keep if sic2>=15 & sic2<=17

collapse (mean)  levmean = lev1 salegravg = salegr   , by(yq)

tempfile ind
save "`ind'"

use "$BEA/OutputbyInd_out.dta", clear

encode sector, gen (id)
xtset id year

gen GOgr = GO/l.GO - 1
gen VAgr = VA/l.VA - 1

keep if sector=="2300"

tempfile sector
save "`sector'"

restore 

replace yq = yq - 1

merge m:1 yq using "`ind'", keep(1 3)
tab _merge
drop _merge

drop yq

merge m:1 year using "`sector'", keep(1 3)
tab _merge
drop _merge

label var salegravg "Industry sales growth"
label var VAgr "Industry value added growth"
label var levmean "Industry leverage"


eststo clear

********Cyclicality Regressions********

eststo: reghdfe recover salegravg   if   etype==1, absorb(group   bucket season ) cluster(year group)
eststo: reghdfe recover salegravg   if   etype==1, absorb(group2 season) cluster(year group)

eststo: reghdfe recover VAgr  if  etype==1, absorb(group bucket season ) cluster(year group)
eststo: reghdfe recover VAgr  if  etype==1, absorb(group2 season) cluster(year group)

eststo: reghdfe recover levmean   if  etype==1, absorb(group bucket season ) cluster(year group)
eststo: reghdfe recover levmean   if  etype==1, absorb(group2 season) cluster(year group)

* FIXME: TABLES macro not defined in the file

#delimit ;
estout using "$TABLES/TableIA6.tex", replace style(tex) label mlabels(none) cells(b(fmt(2) star ) se(fmt(2) par)) keep(salegravg VAgr levmean) order(salegravg VAgr levmean)
starlevels(* .10 ** .05 *** .01)  collabels(none);

estout using "$TABLES/TableIA6_r2.tex", replace style(tex) cells(none) 
stats(N r2_within, fmt(%9.0fc %9.3f) labels("Obs" "R$^2$" ) ) mlabels(none) collabels(none);
#delimit cr
