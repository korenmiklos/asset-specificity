****************************************************** 
***Code to compile physical attributes of inventory***
****************************************************** 

clear all

set matsize 11000
set more off, permanently

if ("`c(username)'" == "yueranma") |  ("`c(username)'" == "Yueran Ma")  |  ("`c(username)'" == "sony") {
	global DATA "../Data"
	global PACER "$DATA/PACER"
	global BEA "$DATA/BEA"
}

program define fastload

use "$DATA/Compustat/compustat_ann_out.dta", clear

drop if year>2018
drop if year<1996

drop if sic>=6000 & sic<7000
drop if sic>=9000 & sic!=.

end

****** Match Rauch Data with BEA IO Industries ******

import delimited "$BEA/IOCOMMODITIES.csv", clear

/*
w = goods traded on an organized exchange
r = reference priced
n = differentiated products
*/

gen vcon = 1 if con=="w" 
replace vcon = 2 if con=="r"
replace vcon = 3 if con=="n"

gen vlib = 1 if lib=="w"
replace vlib = 2 if lib=="r"
replace vlib = 3 if lib=="n"

tempfile rauch0
save "`rauch0'"

import delimited "$BEA/NAICSUseDetail.txt", clear

ren v1 commodity
replace commodity = subinstr(commodity, " ", "", .)

ren v2 industry
replace industry = subinstr(industry, " ", "", .)

ren v3 year
drop v4 /* Table number */
ren v5 vproduct

ren v7 transport_rail
ren v8 transport_truck
ren v9 transport_water
ren v10 transport_air
ren v11 transport_pipe
ren v12 transport_gas
ren v13 wholesale_margin
ren v14 retain_margin
ren v15 vpurchase

gen iocode = commodity

merge m:1 iocode using "`rauch0'", keep(1 3) keepusing(vcon vlib)
tab _merge
drop _merge

save "$BEA/Rauch.dta", replace

***********************

forvalues k = 4/6{

use "$BEA/Rauch.dta", clear

//drop if substr(commodity, 1, 1)=="V"

gen industry`k' = substr(industry, 1, `k')

foreach item in con lib {
bysort industry`k': egen T`item' = sum(vproduct) if v`item'!=.
gen s`item' = vproduct/T`item'

*share of exchange traded goods used in an industry
gen wshr_`item' = 0 if v`item'!=.
replace wshr_`item' = 1 if v`item'==1
replace wshr_`item' = wshr_`item'*s`item'

*share of differentiated goods used in an industry
gen nshr_`item' = 0 if v`item'!=.
replace nshr_`item' = 1 if v`item'==3
replace nshr_`item' = nshr_`item'*s`item'
}

collapse (sum) wshr_* nshr_*, by(industry`k')

save "$BEA/Rauch_BEA`k'.dta", replace
}

import delimited "$BEA/Rauch/IOCOMMODITIES.csv", clear

foreach item in con lib{
gen wshr`item'fg = 0 if `item'!=""
replace wshr`item'fg = 1 if `item'=="w"

gen nshr`item'fg = 0 if `item'!=""
replace nshr`item'fg = 1 if `item'=="n"
}

gen BEA4 = substr(iocode, 1, 4)

collapse (mean) wshr* nshr*, by (BEA4)

tempfile rauch
save "`rauch'"


local vers 1

if `vers' == 1 {
local vprice "vproduct"
}
else if `vers' == 2 {
local vprice "vpurchase"
}

****** Industry Code Matching ******

import excel "$BEA/BEA_NAICS.xlsx", firstrow clear sheet(BEA4)

ren NAICS naicscode

tempfile beacode
save "`beacode'"

****** Transportation Cost Input ******

use "$BEA/transportation_BEA6.dta", clear
replace tshare = 1 if substr(commodity, 1, 2)=="23"
ren commodity6 commodity
tempfile tmpf
save "`tmpf'"

import delimited "$BEA/1997detail/NAICSUseDetail.txt", clear

ren v1 commodity
replace commodity = subinstr(commodity, " ", "", .)

ren v2 industry
replace industry = subinstr(industry, " ", "", .)

ren v3 year
drop v4 /* Table number */
ren v5 vproduct

ren v7 transport_rail
ren v8 transport_truck
ren v9 transport_water
ren v10 transport_air
ren v11 transport_pipe
ren v12 transport_gas
ren v13 wholesale_margin
ren v14 retain_margin
ren v15 vpurchase

merge m:1 commodity using "`tmpf'", keep(1 3) keepusing(tshare)
tab _merge
drop _merge

drop if `vprice' <0 
egen tsharerm = rowtotal(transport_*)

gen BEA4 = substr(industry, 1, 4)
replace BEA4 = "1130" if BEA4 == "1133" | BEA4 == "113A"
replace BEA4 = "1140" if BEA4 == "1141" | BEA4 == "1142"
replace BEA4 = "3150" if BEA4 == "3151" | BEA4 == "3152" | BEA4 == "3159"
replace BEA4 = "3160" if BEA4 == "3161" | BEA4 == "3162" | BEA4 == "3169"
replace BEA4 = "6211" if BEA4 == "621A" | BEA4 == "621B"
replace BEA4 = "713A" if substr(BEA4, 1, 3) == "713"
replace BEA4 = "7210" if substr(BEA4, 1, 3) == "721"
replace BEA4 = "7220" if substr(BEA4, 1, 3) == "722"

collapse (sum) tsharerm `vprice', by(BEA4)
replace tsharerm = tsharerm/`vprice'

sum tsharerm, detail

tempfile tsharerm
save "`tsharerm'"

****** Transportation Cost Output ******

import delimited "$BEA/NAICSUseDetail.txt", clear

ren v1 commodity
replace commodity = subinstr(commodity, " ", "", .)

ren v2 industry
replace industry = subinstr(industry, " ", "", .)

ren v3 year
drop v4 /* Table number */
ren v5 vproduct

ren v7 transport_rail
ren v8 transport_truck
ren v9 transport_water
ren v10 transport_air
ren v11 transport_pipe
ren v12 transport_gas
ren v13 wholesale_margin
ren v14 retain_margin
ren v15 vpurchase

egen transport_tot = rowtotal(transport_*)
gen tshare = transport_tot/`vprice'

drop if `vprice'<0
replace tshare = . if tshare==0

gen commodity4 = substr(commodity, 1, 4)
replace commodity4 = "1130" if commodity4 == "1133" | commodity4 == "113A"
replace commodity4 = "1140" if commodity4 == "1141" | commodity4 == "1142"
replace commodity4 = "3150" if commodity4 == "3151" | commodity4 == "3152" | commodity4 == "3159"
replace commodity4 = "3160" if commodity4 == "3161" | commodity4 == "3162" | commodity4 == "3169"
replace commodity4 = "6211" if commodity4 == "621A" | commodity4 == "621B"
replace commodity4 = "713A" if substr(commodity4, 1, 3) == "713"
replace commodity4 = "7210" if substr(commodity4, 1, 3) == "721"
replace commodity4 = "7220" if substr(commodity4, 1, 3) == "722"

replace transport_tot=. if transport_tot==0
replace `vprice'=. if transport_tot==.
collapse (sum) transport_tot `vprice', by(commodity4)
gen tshare = transport_tot/`vprice'
sum tshare, detail

replace tshare = 1 if substr(commodity4, 1, 2)=="23"
* Offices of real estate agents and brokers
replace tshare = 1 if substr(commodity4,1,4)=="5310" & tshare==.
* Cattle farming
sum tshare if commodity4=="112A"
local m = r(mean)
replace tshare = `m' if commodity4=="1121"
* Air transportation
sum tshare if commodity4=="3364"
local m = r(mean)
replace tshare = `m' if commodity4=="4810"
* Rail transportation
sum tshare if commodity4=="3365"
local m = r(mean)
replace tshare = `m' if commodity4=="4820"
* Water transportation
sum tshare if commodity4=="3366"
local m = r(mean)
replace tshare = `m' if commodity4=="4830"
* Truck transportation
sum tshare if commodity4=="3369"
local m = r(mean)
replace tshare = `m' if commodity4=="4840"
* Local transit
sum tshare if commodity4=="3369"
local m = r(mean)
replace tshare = `m' if commodity4=="4850" | commodity4=="48A0" | commodity4=="4920" | commodity4=="4930"

ren tshare tsharefg
ren commodity4 BEA4

tempfile tsharefg
save "`tsharefg'"

****** Design Cost Input ******

use "$BEA/UseDetail.dta", clear

gen commodity6 = commodity
merge m:1 commodity6 using "$BEA/1997detail/designshr_BEA6.dta", keep(1 3) keepusing(design_share)
tab _merge
drop _merge

gen BEA4 = substr(industry, 1, 4)
replace BEA4 = "1130" if BEA4 == "1133" | BEA4 == "113A"
replace BEA4 = "1140" if BEA4 == "1141" | BEA4 == "1142"
replace BEA4 = "3150" if BEA4 == "3151" | BEA4 == "3152" | BEA4 == "3159"
replace BEA4 = "3160" if BEA4 == "3161" | BEA4 == "3162" | BEA4 == "3169"
replace BEA4 = "6211" if BEA4 == "621A" | BEA4 == "621B"
replace BEA4 = "713A" if substr(BEA4, 1, 3) == "713"
replace BEA4 = "7210" if substr(BEA4, 1, 3) == "721"
replace BEA4 = "7220" if substr(BEA4, 1, 3) == "722"

replace `vprice' = . if design_share==.
gen dshares = `vprice'*design_share

collapse (sum) dshares `vprice', by(BEA4)
replace dshares = dshares/`vprice'
ren dshares dsharesrm

tempfile dsharesrm
save "`dsharesrm'"

****** Design Cost Output ******

use "$BEA/UseDetail.dta", clear

gen commodity4 = substr(industry, 1, 4)
replace commodity4 = "1130" if commodity4 == "1133" | commodity4 == "113A"
replace commodity4 = "1140" if commodity4 == "1141" | commodity4 == "1142"
replace commodity4 = "3150" if commodity4 == "3151" | commodity4 == "3152" | commodity4 == "3159"
replace commodity4 = "3160" if commodity4 == "3161" | commodity4 == "3162" | commodity4 == "3169"
replace commodity4 = "6211" if commodity4 == "621A" | commodity4 == "621B"
replace commodity4 = "713A" if substr(commodity4, 1, 3) == "713"
replace commodity4 = "7210" if substr(commodity4, 1, 3) == "721"
replace commodity4 = "7220" if substr(commodity4, 1, 3) == "722"

collapse (sum) `vprice', by(commodity4 design)

reshape wide `vprice', i(commodity4) j(design)
gen design_share = `vprice'1/(`vprice'0+`vprice'1)

ren design_share dsharesfg
ren commodity4 BEA4

tempfile dsharesfg
save "`dsharesfg'"

************************************************
*                   Merge                      *
************************************************

fastload

****** Match NAICS and BEA-IO Codes ******

foreach t in 2007 {
gen tmp = naicsh if year==`t'
bysort gvkey: egen naics`t' = mean(tmp)
drop tmp
tostring naics`t', replace
}

forvalues k = 2/4{
gen naicscode = substr(naics2007, 1, `k')
replace naicscode = substr(naics, 1, `k') if naicscode=="." | naicscode==""
destring naicscode, replace
merge m:1 naicscode using "`beacode'", keep(1 3 4 5) update
tab _merge
drop _merge
drop naicscode
}

gen naicscode07 = substr(naics2007, 1, 4)
replace naicscode07 = substr(naics, 1, 4) if naicscode07=="." | naicscode07==""
replace BEA4 = substr(naicscode07, 1, 4) if BEA4==""
replace BEA4 = subinstr(BEA4, " ", "", .)

/* Adjustments of 2007 NAICS with 1997 BEA */

replace BEA4 = "5141" if BEA4 == "5191"
replace BEA4 = "2301" if substr(naicscode07, 1, 4) == "2361" | substr(naicscode07, 1, 4) == "2332"
replace BEA4 = "2302" if substr(naicscode07, 1, 4) == "2362" | substr(naicscode07, 1, 4) == "2333" | substr(naicscode07, 1, 3) == "234" | substr(naicscode07, 1, 3) == "237"
replace BEA4 = "2303" if substr(naicscode07, 1, 3) == "235" | substr(naicscode07, 1, 3) == "238"
replace BEA4 = "4A00" if substr(naicscode07, 1, 2) == "44" | substr(naicscode07, 1, 2) == "45" 
replace BEA4 = "4910" if BEA4 == "4911"
replace BEA4 = "5131" if BEA4 == "5151"
replace BEA4 = "5132" if BEA4 == "5152"
replace BEA4 = "5133" if substr(naicscode07, 1, 3) == "517"
replace BEA4 = "5133" if substr(naicscode07, 1, 3) == "516"
replace BEA4 = "5141" if BEA4 == "5181"
replace BEA4 = "5142" if BEA4 == "5182"
replace BEA4 = "5141" if BEA4 == "5191"
replace BEA4 = "522A" if BEA4 == "5222" | BEA4 == "5223"
replace BEA4 = "6211" if substr(naicscode07, 1, 3) == "621"
replace BEA4 = "6230" if substr(naicscode07, 1, 3) == "623"
replace BEA4 = "624A" if BEA4 == "6241"
replace BEA4 = "713A" if substr(naicscode07, 1, 3) == "713"
replace BEA4 = "7220" if substr(naicscode07, 1, 3) == "722"

****** Match NAICS and BEA-IO Codes ******

merge m:1 BEA4 using "`dsharesfg'", keep(1 3) keepusing(dsharesfg)
tab _merge
drop _merge

merge m:1 BEA4 using "`tsharefg'", keep(1 3) keepusing(tsharefg)
tab _merge
drop _merge

merge m:1 BEA4 using "`dsharesrm'", keep(1 3) keepusing(dsharesrm)
tab _merge
drop _merge

merge m:1 BEA4 using "`tsharerm'", keep(1 3) keepusing(tsharerm)
tab _merge
drop _merge

sum dsharesrm, detail

****** Rauch data ****** 

gen industry4 = BEA4

merge m:1 industry4 using "$BEA/Rauch_BEA4.dta", keepusing(wshr_* nshr_*) keep(1 3)
tab _merge
drop _merge

drop industry4

merge m:1 BEA4 using "`rauch'", keepusing(wshr* nshr*) keep(1 3)
tab _merge
drop _merge

****** Match Retail & Wholesale Based on Type of Product Sold ****** 

foreach item of varlist tsharefg dsharesfg wshr*fg nshr*fg {
/*auto dealers*/
sum `item' if (substr(naicscode07, 1, 4)=="3361" | substr(naicscode07, 1, 4)=="3362" | substr(naicscode07, 1, 4)=="3363") & year==1997
local m = r(mean)
replace `item' = `m' if substr(naicscode07, 1, 3)=="441" | substr(naicscode07, 1, 4)=="4231" | substr(naicscode07, 1, 3)=="421"

/*furniture stores*/
sum `item' if (substr(naicscode07, 1, 3)=="337") & year==1997
local m = r(mean)
replace `item' = `m' if substr(naicscode07, 1, 3)=="442" | substr(naicscode07, 1, 4)=="4232" 

/*electronic appliances*/
sum `item' if (substr(naicscode07, 1, 3)=="335") & year==1997
local m = r(mean)
replace `item' = `m' if substr(naicscode07, 1, 3)=="443" | substr(naicscode07, 1, 4)=="4236"  | substr(naics, 1, 4)=="4237"

/*building materials*/
sum `item' if (substr(naicscode07, 1, 3)=="321" | substr(naicscode07, 1, 3)=="327" | substr(naicscode07, 1, 3)=="331" | substr(naicscode07, 1, 3)=="332") & year==1997
local m = r(mean)
replace `item' = `m' if substr(naicscode07, 1, 3)=="444" | substr(naicscode07, 1, 4)=="4233"

/*grocery stores*/
sum `item' if (substr(naicscode07, 1, 3)=="311") & year==1997  
local m = r(mean)
replace `item' = `m' if substr(naicscode07, 1, 3)=="445" | substr(naicscode07, 1, 4)=="4244"

/*personal care and chemicals*/
sum `item' if ( substr(naicscode07, 1, 3)=="325") & year==1997
local m = r(mean)
replace `item' = `m' if substr(naicscode07, 1, 3)=="446" | substr(naics, 1, 4)=="4242" | substr(naics, 1, 4)=="4246"

sum `item' if  (substr(naicscode07, 1, 4)=="3254") & year==1997
local m = r(mean)
replace `item' = `m' if substr(naicscode07, 1, 4)=="4242"

sum `item' if  (substr(naicscode07, 1, 3)=="325" | substr(naicscode07, 1, 3)=="326") & year==1997
local m = r(mean)
replace `item' = `m' if substr(naicscode07, 1, 4)=="4246"

/*gas station*/
sum `item' if (substr(naicscode07, 1, 3)=="324") & year==1997
local m = r(mean)
replace `item' = `m' if substr(naicscode07, 1, 3)=="447"  | substr(naicscode07, 1, 4)=="4247"

/*clothing*/
sum `item' if (substr(naicscode07, 1, 3)=="315" | substr(naicscode07, 1, 3)=="316") & year==1997
local m = r(mean)
replace `item' = `m' if substr(naicscode07, 1, 3)=="448" | substr(naicscode07, 1, 4)=="4243"

/*sports and hobby*/
sum `item' if (substr(naicscode07, 1, 3)=="339") & year==1997
local m = r(mean)
replace `item' = `m' if substr(naicscode07, 1, 3)=="451" | substr(naicscode07, 1, 4)=="4239" 

/*general merchandise*/
sum `item' if (substr(naicscode07, 1, 3)=="334" | substr(naicscode07, 1, 3)=="335" | substr(naicscode07, 1, 3)=="337" | substr(naicscode07, 1, 3)=="339" | substr(naicscode07, 1, 2)=="31" | substr(naicscode07, 1, 2)=="32") & year==1997
local m = r(mean)
replace `item' = `m' if substr(naicscode07, 1, 3)=="452" | substr(naicscode07, 1, 3)=="453" | substr(naicscode07, 1, 3)=="454"  | substr(naics, 1, 4)=="4251" | substr(naics, 1, 4)=="4249"

/*eating and drinking places*/
sum `item' if (substr(naicscode07, 1, 3)=="311" ) & year==1997  
local m = r(mean)
replace `item' = `m' if BEA4=="7220" 

sum `item' if (substr(naicscode07, 1, 4)=="3121") & year==1997
local m = r(mean)
replace `item' = `m' if substr(naicscode07, 1, 4)=="4248"

/*paper and printing material*/
sum `item' if (substr(naicscode07, 1, 3)=="322" | substr(naicscode07, 1, 3)=="323") & year==1997
local m = r(mean)
replace `item' = `m' if substr(naicscode07, 1, 3)=="611" | substr(naicscode07, 1, 4)=="4241" 

/*business equipment*/
sum `item' if (substr(naicscode07, 1, 4)=="3333" | substr(naicscode07, 1, 4)=="334") & year==1997
local m = r(mean)
replace `item' = `m' if substr(naicscode07, 1, 4)=="4234"

/*metal*/
sum `item' if (substr(naicscode07, 1, 3)=="327" | substr(naicscode07, 1, 4)=="332") & year==1997
local m = r(mean)
replace `item' = `m' if substr(naicscode07, 1, 4)=="4235"

/*machinery wholesale*/
sum `item' if (substr(naicscode07, 1, 3)=="333") & year==1997
local m = r(mean)
replace `item' = `m' if substr(naicscode07, 1, 4)=="4238"

/*Farm products*/
sum `item' if (substr(naicscode07, 1, 3)=="111" | substr(naicscode07, 1, 3)=="112") & year==1997
local m = r(mean)
replace `item' = `m' if substr(naicscode07, 1, 4)=="4245"

/*Medical*/
sum `item' if (substr(naicscode07, 1, 4)=="3345" | substr(naicscode07, 1, 4)=="3391" | substr(naicscode07, 1, 4)=="3254") & year==1997
local m = r(mean)
replace `item' = `m' if substr(naicscode07, 1, 3)=="621"
}
*/

****** Services use Input rather than Output ****** 

replace tsharefg = tsharerm if substr(BEA4, 1, 1)=="5" | substr(BEA4, 1, 1)=="6" | substr(BEA4, 1, 1)=="7"  | substr(BEA4, 1, 1)=="8"  
replace dsharesfg = dsharesrm if substr(BEA4, 1, 1)=="5" | substr(BEA4, 1, 1)=="6" | substr(BEA4, 1, 1)=="7"  | substr(BEA4, 1, 1)=="8"  
sum dsharesfg dsharesrm tsharefg tsharerm, detail

****** Firm Characteristics ****** 
xtset

gen apdays = 360/(cogs/invt)
gen invrmshr = invrm/invt
gen invfgshr = invfg/invt
gen invwipshr = invwip/invt
gen invchurn =  (cogs + invt - l.invt)*2/(invt + l.invt)  
gen invchurnrm = invtp_at*at/invrm
gen cogs_invt = cogs/invt  

replace invwipshr = 0 if invwipshr==. & invt!=. & invt!=0
replace invrmshr = 0 if invrmshr==. & invt!=. & invt!=0
replace invfgshr = 1 - invrmshr - invwipshr if invfgshr==. & invt!=. & invt!=0

foreach item in apdays invchurn invchurnrm cogs_invt {
bysort fyear: egen tmp_ph=pctile(`item'), p(99)
bysort fyear: egen tmp_pl=pctile(`item'), p(1)
replace `item'=. if `item'>tmp_ph 
replace `item'=. if `item'<tmp_pl 
drop tmp_* 
}

gen shelflife = 1/invchurn

foreach item in invrmshr invfgshr invwipshr{
replace `item' = . if `item'<0
replace `item' = . if `item'>1
}

bysort sic2 year: egen salesum = sum(sale)
bysort year: egen saletot = sum(sale)
gen saleshrind = salesum/saletot  

****** Industry Characteristics ****** 

collapse (mean) invrmshr invfgshr invwipshr invchurn invchurnrm cogs_invt shelflife apdays saleshrind dshares* tshare*  , by(sic2 year)

merge m:1 sic2 using "$DATA/PacerRecovery.dta", keep(1 3) keepusing(RecoveryInventoryMid)
tab _merge
drop _merge

gen dsharesinvt = (dsharesfg*invfgshr + dsharesrm*invrmshr)/(invfgshr+invrmshr)
gen tshareinvt = (tsharefg*invfgshr + tsharerm*invrmshr)/(invfgshr+invrmshr)

gen wshrcon = (wshrconfg*invfgshr + wshr_con*invrmshr)/(invfgshr+invrmshr)
gen nshrcon = (nshrconfg*invfgshr + nshr_con*invrmshr)/(invfgshr+invrmshr)
gen wshrlib = (wshrlibfg*invfgshr + wshr_lib*invrmshr)/(invfgshr+invrmshr)
gen nshrlib = (nshrlibfg*invfgshr + nshr_lib*invrmshr)/(invfgshr+invrmshr)

keep if year==1997
keep sic2 RecoveryInventoryMid shelflife tshareinvt dsharesinvt invwipshr saleshrind wshrcon wshrlib 
order sic2 RecoveryInventoryMid shelflife tshareinvt dsharesinvt invwipshr saleshrind wshrcon wshrlib 

label var invwipshr "Work-in-progress share"
label var shelflife "Shelf life"
label var tshareinvt "Transportation cost"
label var dsharesinvt "Design cost"
label var saleshrind "Industry size (sales share)"

label var wshrcon "Fraction exchange traded using Rauch data (conservative)"
label var wshrlib "Fraction exchange traded using Rauch data (liberal)"

save "$BEA/RecoveryPhysicsInvt97_sic2.dta", replace
