*************************************
***Code to classify debt contracts***
*************************************

clear 

set matsize 11000
set more off, permanently

if 1 | ("`c(username)'" == "yueranma")|("`c(username)'" == "sony")|("`c(username)'" == "Yueran Ma")  {
	global DATA "./Data"
}


use "$DATA/FISD/fisd_full.dta", clear
keep issuer_cusip offering_amt coupon offering_date maturity convertible mtn asset_backed security_level bond_type issue_name
ren issuer_cusip cusip6
duplicates drop cusip6 coupon maturity, force
gen fisd = 1
tempfile fisd1
save "`fisd1'"

use "$DATA/FISD/fisd_full.dta", clear
keep issuer_cusip offering_amt coupon offering_date maturity convertible mtn asset_backed security_level bond_type issue_name
ren issuer_cusip cusip6
duplicates drop cusip6 coupon offering_date, force
gen fisd = 1
tempfile fisd2
save "`fisd2'"

use "$DATA/FISD/fisd_full.dta", clear
keep issuer_cusip offering_amt coupon offering_date maturity convertible mtn asset_backed security_level bond_type issue_name
ren issuer_cusip cusip6
duplicates drop cusip6 offering_date maturity, force
gen fisd = 1
tempfile fisd3
save "`fisd3'"

use "$DATA/Compustat/compustat_ann_out.dta", clear
destring gvkey, replace
duplicates drop gvkey yq , force
tempfile cpstus
save "`cpstus'"

** Main CapitalIQ Debt Detail File **
use "$DATA/CapitalIQ/debt detail USA.dta", clear

ren *, lower

*Adjust for units
replace dataitemvalue = dataitemvalue/10^6 if unittypeid==0
replace dataitemvalue = dataitemvalue/10^3 if unittypeid==1
 
gen year = year(period)
gen yq = qofd(periodenddate)
format yq %tq
 
destring gvkey, replace
 
keep if latestforfinancialperiodflag==1

** Account for duplicate observations **
// Identify duplicate observations
duplicates tag companyid periodenddate componentid, gen(dup)

// Identify Revolvers
gen byte revolverCIQ = (regexm(descriptiontext, "Revolv"))

// Collapse data to "remove" duplicates by combining them
// When doing this, we sum the dataitemvalues for the 
// revolvers and take the last non-missing value or max for the non-revolvers,
// while keeping the descriptive variables the same 
// (since they are all the same anyway)
gen double revolver_value = dataitemvalue if revolverCIQ==1
gen double nonrevolver_value = dataitemvalue if revolverCIQ==0

gen double dataitemvalue_sum = dataitemvalue

// Consider cases where within a componentid, one of the "duplicates" is a 
// revolver while the other is a nonrevolver as different loans, i.e. not duplicates
// This is done by including revolverCIQ in the "by()" of the collapse below
egen byte rev_max = max(revolverCIQ), by(companyid periodenddate componentid)
egen byte rev_min = min(revolverCIQ), by(companyid periodenddate componentid)
gen long componentid2 = componentid
replace componentid2 = componentid + 10^9 if revolverCIQ==1 & rev_min==0

collapse (lastnm) securedtypeid convertibletypeid filingdate	///
		companyname unittypeid yq capitalstructuredescription 	///
		description* issuedcurrencyid interestratetypeid 	///
		interestratebenchmarktypeid	/// textl = descriptiontext 	///
		/// (firstnm) textf = descriptiontext 	///
		(sum) revolver_value nonrevolver_value dataitemvalue_sum 	///
		(max) dataitemvalue componentid2 interestratehighvalue 	///
			benchmarkspreadhighvalue maturityhigh startdate 	///
		(min) maturitylow interestratelowvalue benchmarkspreadlowvalue	///
		(count) dups = filingflag_company, 	///
		by(companyid periodenddate componentid dup revolverCIQ)
		
// Replace dataitemvalue for duplicate revolvers
replace dataitemvalue = revolver_value if revolverCIQ==1 & dup>0

// If nonrevolver duplicate observations have different dataitemvalues, then
// keep the max of them for now 
//replace dataitemvalue = nonrevolver_value if revolverCIQ==0 & dup>0 & 	///
//				abs(nonrevolver_value/dups - dataitemvalue) > 1
// This happens this many times
count if revolverCIQ==0 & dup>0 & abs(nonrevolver_value/dups - dataitemvalue) > 1

// But this many have duplicates with dataitemvalue==0
count if revolverCIQ==0 & dup>0 & abs(nonrevolver_value/dups - dataitemvalue) > 1 & 	///
		abs(nonrevolver_value - dataitemvalue) < 1

// We use periodenddate instead of yq in the collapse above because occasionally the
// periodenddate for a given componentid does not follow the same pattern
// such as 31dec2005->31mar2006->30jun2006->30sep2006->31dec2006 and instead
// has the pattern 31dec2005->01apr2006->01jul2006->30sep2006->31dec2006.
// The first pattern yields yq values of 2005q4->2006q1->2006q2->2006q3->2006q4
// while the second pattern yields yq values of 2005q4->2006q2->2006q3->2006q3->2006q4
// which has duplicate values for yq (in 2006q3).
// At this point, this occurs in 14,814 of 2,507,079 observations (using componentid2)
// Fix the periodenddate for these instances
duplicates report companyid componentid2 yq

duplicates tag companyid componentid2 yq, gen(sameyq)
egen byte has_sameyq = max(sameyq), by(companyid componentid2)

// Note: Take mode of month and mode of (day<10) and (day>20) to recognize the
// pattern the periodenddate "should" follow. Then correct to follow what the
// mode dictates for each componentid2 with yq duplicates 
gen byte day = day(periodenddate)
gen byte month = month(periodenddate)
gen int year = year(periodenddate)

gen byte month_period = 0
replace month_period = 1 if (day<10)
replace month_period = 2 if (day>20)

gen byte monthmod = mod(month,3)

egen byte monthprd_mode = mode(month_period), by(companyid componentid2)
egen byte monthmod_mode = mode(monthmod), by(companyid componentid2)

// If missing *_mode variables due to a "tie", take the values of the first observation
bysort companyid componentid2 (periodenddate): gen byte mp_f = month_period if _n==1
bysort companyid componentid2 (periodenddate): gen byte mm_f = monthmod if _n==1
egen byte monthprd_first = max(mp_f), by(companyid componentid2)
egen byte monthmod_first = max(mm_f), by(companyid componentid2)

replace monthprd_mode = monthprd_first if missing(monthprd_mode)
replace monthmod_mode = monthmod_first if missing(monthmod_mode)

gen int yq1 = yq
format yq1 %tq

// Fix case with the pattern 01jan2005->01apr2006->01jul2006->30sep2006
// Here monthmod_mode==1 & monthprd_mode==1
replace yq1 = yq1+1 if monthmod < monthmod_mode & 	///
			month_period > monthprd_mode & has_sameyq==1
duplicates tag companyid componentid2 yq1, gen(sameyq1)
egen byte has_sameyq1 = max(sameyq1), by(companyid componentid2)
			
// Fix case with the pattern 31dec2005->01apr2006->01jul2006->30sep2006->31dec2006
// Here monthmod_mode==0 & monthprd_mode==2
replace yq1 = yq1-1 if monthmod > monthmod_mode & 	///
			month_period < monthprd_mode & has_sameyq==1
duplicates tag companyid componentid2 yq1, gen(sameyq2)
egen byte has_sameyq2 = max(sameyq2), by(companyid componentid2)

format yq yq1  %tq
tab sameyq sameyq2

order *yq* month_period monthmod *_mode periodenddate month 

// Remove leftover duplicates
drop if sameyq2==1 & (month_period!=monthprd_mode | monthmod!=monthmod_mode)

duplicates report companyid componentid2 yq1

replace yq = yq1
drop yq1 

merge m:1 companyid yq using "$DATA/CapitalIQ/cpst_bridge_qtr.dta", keep(1 3 4 5) keepusing(gvkey) update
tab _merge
drop _merge
 
drop if gvkey==.

merge m:1 gvkey yq using "`cpstus'", keep(1 3) keepusing(fic tic sic dltt dlc dltis dltr at_tile cik cusip at seq ceq fyear)
********************************
keep if _merge == 3 // this also makes the remaining data annual
********************************
drop _merge

//Try to link same debt and identify new issuance

egen debtissue = group(companyid descriptionid maturityhigh), missing
bysort debtissue: egen tmp = min(yq)
gen new = 0
replace new = 1 if yq == tmp
drop tmp

gen due = 0
replace due = 1 if qofd(maturityhigh) - yq <= 4

*Non-Financial Firms
drop if sic>=6000 & sic<7000
drop if sic>=9000 & sic!=.
 
*Time range
keep if year<2019 & year>2002
 
replace capitalstructuredescription = lower(capitalstructuredescription)
replace capitalstructuredescription = subinstr(capitalstructuredescription, "-", " ", .)
replace descriptiontext = lower(descriptiontext)

*Merge FISD
gen cusip6 = substr(cusip, 1, 6)
gen coupon = interestratehighvalue
gen maturity = maturityhigh
gen offering_date = startdate
gen offeing_amt = dataitemvalue

merge m:1 cusip6 coupon maturity using "`fisd1'", keep(1 3) keepusing(fisd convertible mtn asset_backed security_level bond_type issue_name)
tab _merge
drop _merge
merge m:1 cusip6 coupon offering_date using "`fisd2'", keep(1 3 4 5) update keepusing(fisd convertible mtn asset_backed security_level bond_type issue_name)
tab _merge
drop _merge
merge m:1 cusip6 maturity offering_date using "`fisd3'", keep(1 3 4 5) update keepusing(fisd convertible mtn asset_backed security_level bond_type issue_name)
tab _merge
drop _merge

drop coupon maturity offering_date  

*Data error: IBM 2016, UNS Energy 2013
replace dataitemvalue = dataitemvalue/10^6  if strpos(descriptiontext, "revolv") & year(periodenddate)==2016 & gvkey==6066
replace dataitemvalue = . if year==2013 & componentid==915719391
*Multiple entries for Pfizer Q4
drop if month(periodenddate)==10 & companyid==162270

*****************
**   By Type   **
*****************

gen dtype =.
gen dsubtype = .
label define debttype 1 "loan" 2 "public bond (non-convert)"  3 "convertible" 4 "program debt" 5 "mortgage/equipment" 6 "other" 7 "notes payable & oth" 8 "securitization", replace 
label define debtsubtype 11 "revolver" 12 "term loan" 13 "other loans" 21 "regular" 22 "revenue" 23 "144a" 41 "commercial paper" 42 "mtn" 	///
51 "mortgage" 52 "equipment etc" 61 "acquisition" 62 "capitalized leases" 63 "personal" 64 "government" 65 "misc" 71 "securitization", replace 
label val dtype debttype
label val dsubtype debtsubtype

//mortgage debt
replace dtype = 5 if dtype==. & strpos(descriptiontext, "mortgage") 
local mort  "mortgage"  "real estate" " building"
foreach i in "`mort'" {
	replace dtype = 5 if dtype==. & strpos(capitalstructuredescription, "`i'") 
	replace dsubtype = 51 if dtype==5& dsubtype==. & strpos(capitalstructuredescription, "`i'")
}
replace dtype = 5 if dtype==. & strpos(capitalstructuredescription, "propert") & strpos(capitalstructuredescription, "intellectual propert")
replace dsubtype = 51 if dtype==5& dsubtype==. & strpos(capitalstructuredescription, "propert") & strpos(capitalstructuredescription, "intellectual propert")
local equip "equipment" "machine" "aircraft" "vehicle" "auto loan"  "automob" "oil"  "drill" "reserve base" 
foreach i in "`equip'" {
	replace dtype = 5 if dtype==. & strpos(capitalstructuredescription, "`i'")
	replace dsubtype = 52 if dtype==5&dsubtype==. & strpos(capitalstructuredescription, "`i'")	
} 
replace dsubtype = 51 if dtype==5 & dsubtype==.

//securitization 
replace dtype=8 if dtype==. & (strpos(descriptiontext, "securitiz") | strpos(capitalstructuredescription, "securitiz"))
replace dtype=8 if dtype==. &  strpos(capitalstructuredescription, "factor") &  strpos(capitalstructuredescription, "factory")==0 &  strpos(capitalstructuredescription, "factories")==0  //factoring
replace dtype=8 if dtype==. &  strpos(capitalstructuredescription, "repurchase")  &  strpos(capitalstructuredescription, "stock repurchase")==0  
replace dtype=8 if dtype==. & strpos(descriptiontext, "repurchase") 
replace dtype=8 if dtype==. & strpos(capitalstructuredescription, "sold")  &  strpos(capitalstructuredescription, "not yet purchased") 

//bank 
replace dtype = 1 if dtype==. & strpos(descriptiontext, "bank")
replace dtype = 1 if dtype==. & strpos(capitalstructuredescription, "bank") & strpos(capitalstructuredescription, "development bank")==0
local line  "revolv"  "credit line" "line of credit" "lines of credit" "bank line" "letters of credit" "letter of credit" "borrowing base" "asset based"
local term  "term loan" "term a " "term b " "term c " "term d " "term e " "term f " "credit facilit" "term facilit" 	///
"first lien" "second lien" "third lien"  "syndicate" "first priorit" "second priorit" "various financial" 
foreach i in "`line'" {
	replace dtype = 1 if dtype==. & (strpos(descriptiontext, "`i'") | strpos(capitalstructuredescription, "`i'"))
	replace dsubtype = 11 if dtype==1& dsubtype==. & (strpos(descriptiontext, "`i'") | strpos(capitalstructuredescription, "`i'"))
}
foreach i in "`term'" {
	replace dtype = 1 if dtype==. & (strpos(descriptiontext, "`i'") | strpos(capitalstructuredescription, "`i'"))
	replace dsubtype = 12 if dtype==1&dsubtype==. & (strpos(descriptiontext, "`i'") | strpos(capitalstructuredescription, "`i'"))
}
	replace dsubtype = 13 if dtype==1 & dsubtype==.

//convertible
replace dtype = 3 if dtype==. & convertibletypeid==4 & strpos(capitalstructuredescription, "preferred stock")==0
replace dtype = 3 if dtype==. & strpos(capitalstructuredescription, "convert") & convertibletypeid!=7 & strpos(capitalstructuredescription, "preferred stock")==0

//program
replace dtype = 4 if dtype==. & (strpos(descriptiontext, "commercial paper") |strpos(capitalstructuredescription, "commercial paper"))
replace dsubtype = 41 if dtype == 4&dsubtype==. & (strpos(descriptiontext, "commercial paper") |strpos(capitalstructuredescription, "commercial paper"))
local mtn "medium term note"  "mtn"
foreach i in "`mtn'" {
replace dtype = 4 if dtype==. & strpos(capitalstructuredescription, "`i'")
replace dsubtype = 42 if dtype==4 & dsubtype==. & strpos(capitalstructuredescription, "`i'")
}

//capital leases
replace dtype = 6 if dtype==. & (strpos(descriptiontext,"capital lease") |  strpos(capitalstructuredescription, "capital lease") | strpos(capitalstructuredescription, "capitalized lease"))
replace dsubtype = 62 if dtype == 6&dsubtype==. & (strpos(descriptiontext,"capital lease") |  strpos(capitalstructuredescription, "capital lease") | strpos(capitalstructuredescription, "capitalized lease"))

//bond
//replace dtype = 2 if dtype==. & strpos(descriptiontext,"bonds and notes")
replace dtype = 2 if dtype==. & (strpos(capitalstructuredescription, "debenture") | strpos(descriptiontext,"debenture"))
replace dtype = 2 if dtype==. & strpos(capitalstructuredescription, "senior note") 
replace dtype = 2 if dtype==. & strpos(capitalstructuredescription, "subordinated note") 
*revenue bond
local rev "revenue bond" "industrial bond"  "revenue refunding"  "industrial develop" "industrial authority"  "pollution control" 
foreach i in "`rev'" {
	replace dtype = 2 if dtype==. & strpos(capitalstructuredescription, "`i'")
	replace dsubtype = 22 if dtype == 2 &dsubtype==. & strpos(capitalstructuredescription, "`i'")
}
replace dsubtype = 22 if dtype==2 & strpos(capitalstructuredescription, "industrial") & strpos(capitalstructuredescription, "revenue")
*private placement
replace dtype = 2 if dsubtype==. & strpos(capitalstructuredescription, "144a")
replace dtype = 2 if dsubtype==. & strpos(capitalstructuredescription, "private") &  strpos(capitalstructuredescription, "place")
replace dsubtype = 23 if dtype == 2 &dsubtype==. & strpos(capitalstructuredescription, "144a")
replace dsubtype = 23 if dtype == 2 &dsubtype==. & strpos(capitalstructuredescription, "private") &  strpos(capitalstructuredescription, "place")
replace dsubtype = 21 if dtype ==2 & dsubtype==.
	
//other
*acquisition notes
replace dtype = 6 if dtype==. &  strpos(capitalstructuredescription, "acquisition note")
replace dsubtype = 61 if dtype == 6 &dsubtype==. & strpos(capitalstructuredescription, "acquisition note")
*personal loans
local personal "director" "holder" "officer" "related part" " mr." " mr " " ms." " ms " " mrs." " mrs " " dr. " " estate of " 	///
"individual" "chairman" " ceo" "executiv" "member" "founder" "president" "wife" "john" "robert"  "david" "richard" "kevin" "howard" 	///
"third part" "3rd part" "third member" "3rd member" "parent" "affili" "external part" "related part" "related compan"
foreach i in "`personal'" {
	replace dtype = 6 if dtype==. & strpos(capitalstructuredescription, "`i'")
	replace dsubtype = 63 if dtype == 6 &dsubtype==. & strpos(capitalstructuredescription, "`i'")
}
*government
local govt  "government" "city of" "state of" "county" "municipal" "ministry" "economic development" "development bank" "authority"
foreach i in "`govt'" {
	replace dtype = 6 if dtype==. & strpos(capitalstructuredescription, "`i'")
	replace dsubtype = 64 if dtype == 6 &dsubtype==. & strpos(capitalstructuredescription, "`i'")
}
*misc
local misc "preferred stock" "vendor" "seller" "supplier" "landlord" "tenant" "small business admin" "sba" "capital trust" 	///
"product finan" "minority interest"  "environment"  "employee" "accounts payable" "financing compan" "finance compan" 	///
"project finan" "project debt" "construction" "stock repurchase" "insurance" "index link" "customer" "joint venture"
foreach i in "`misc'" {
	replace dtype = 6 if dtype==. &  strpos(capitalstructuredescription, "`i'")
	replace dsubtype = 65 if dtype == 6 &dsubtype==. & strpos(capitalstructuredescription, "`i'")
}
replace dtype = 6 if dtype==. & (strpos(descriptiontext, "trust prefer") | strpos(capitalstructuredescription, "trust prefer"))
replace dsubtype = 65 if dtype == 6 &dsubtype==. & (strpos(descriptiontext, "trust prefer") | strpos(capitalstructuredescription, "trust prefer"))
replace dtype = 6 if dtype==. &  strpos(capitalstructuredescription, "trust cert")
replace dsubtype = 65 if dtype == 6 &dsubtype==. & strpos(capitalstructuredescription, "trust cert") 

//supplements
replace dtype = 4 if dtype==. & mtn=="Y"
replace dsubtype = 42 if dtype == 4 &dsubtype==. & mtn=="Y"
replace dtype = 4 if dtype==. & strpos(issue_name, " SER ")
replace dsubtype = 42 if dtype == 4 &dsubtype==. & strpos(issue_name, " SER ")
replace dtype = 2 if dtype==. & fisd==1
replace dsubtype = 21 if dtype==2 &dsubtype==. & fisd==1
replace dtype = 1 if dtype==. & strpos(capitalstructuredescription, "senior secured")
replace dsubtype = 12 if  dtype == 1 &dsubtype==. & strpos(capitalstructuredescription, "senior secured")
replace dtype = 1 if dtype==. & (strpos(capitalstructuredescription, "bridge loan")|strpos(capitalstructuredescription, "bridge note"))
replace dsubtype = 12 if  dtype == 1 &dsubtype==. & (strpos(capitalstructuredescription, "bridge loan")|strpos(capitalstructuredescription, "bridge note"))
local wcap "working capital" "receivable" "inventor" 
foreach i in "`wcap'" {
	replace dtype = 1 if dtype==. & strpos(capitalstructuredescription, "`i'")
	replace dsubtype = 11 if dtype == 1 &dsubtype==. & strpos(capitalstructuredescription, "`i'")
}
replace dtype = 6 if dtype==. &  strpos(capitalstructuredescription, "acquisition")
replace dsubtype = 61 if dtype == 6 &dsubtype==. & strpos(capitalstructuredescription, "acquisition")

local item "%" "percent" "fixed rate" "long term note"
foreach i in "`item'" {
	replace dtype = 2 if dtype==. & strpos(capitalstructuredescription, "`i'")
	replace dsubtype = 21 if dtype == 2 &dsubtype==. & strpos(capitalstructuredescription, "`i'")
}
local item "recourse"
foreach i in "`item'" {
	replace dtype = 1 if dtype==. & strpos(capitalstructuredescription, "`i'")
	replace dsubtype = 12 if dtype ==1 &dsubtype==. & strpos(capitalstructuredescription, "`i'")
}
local item "series"
foreach i in "`item'" {
	replace dtype = 4 if dtype==. & strpos(capitalstructuredescription, "`i'")
	replace dsubtype = 42 if dtype ==4 &dsubtype==. & strpos(capitalstructuredescription, "`i'")
}

replace dtype = 1 if dtype==. & strpos(capitalstructuredescription, "loan")  
replace dsubtype = 13 if dsubtype==. & dtype==1 & strpos(capitalstructuredescription, "loan") 
replace dtype = 1 if dtype==. & strpos(capitalstructuredescription, "credit agreement")  
replace dsubtype = 12 if dsubtype==. & dtype==1 & strpos(capitalstructuredescription, "credit agreement") 
replace dtype = 1 if dtype==. & strpos(capitalstructuredescription, "debt agreement")  
replace dsubtype = 12 if dsubtype==. & dtype==1 & strpos(capitalstructuredescription, "debt agreement") 
replace dtype = 1 if dtype==. & strpos(capitalstructuredescription, "lender")  
replace dsubtype = 13 if dsubtype==. & dtype==1 & strpos(capitalstructuredescription, "lender") 

replace dtype = 2 if dtype==. & strpos(capitalstructuredescription, "unsecured") &  strpos(capitalstructuredescription, "note")
replace dsubtype = 21 if dtype == 2 &dsubtype==. &  strpos(capitalstructuredescription, "unsecured") &  strpos(capitalstructuredescription, "note")
local item "euro note" "global note" "zero coupon"
foreach i in "`item'" {
	replace dtype = 2 if dtype==. & strpos(capitalstructuredescription, "`i'")
	replace dsubtype = 21 if dtype == 2 &dsubtype==. & strpos(capitalstructuredescription, "`i'")
}
replace dtype = 5 if dtype==. & strpos(capitalstructuredescription, "asset back")
replace dsubtype = 52 if dtype == 5 &dsubtype==. & strpos(capitalstructuredescription, "asset back")
replace dtype = 1 if dtype==. & strpos(capitalstructuredescription, "secured note")
replace dsubtype = 12 if dtype == 1 &dsubtype==. & strpos(capitalstructuredescription, "secured note")
local item "subordinate" "senior sub" "junior sub"
foreach i in "`item'" {
	replace dtype = 2 if dtype==. & strpos(capitalstructuredescription, "`i'")
	replace dsubtype = 21 if dtype == 2 &dsubtype==. & strpos(capitalstructuredescription, "`i'")
}
replace dtype = 2 if dtype==. & strpos(descriptiontext,"bonds and notes")
replace dsubtype = 21 if dtype == 2 &dsubtype==. & strpos(descriptiontext,"bonds and notes")


//note payable
replace dtype=7 if dtype==. 

*********************
**   By Priority   **
*********************
  
gen dpriority =.
gen dsubprior =.
label define dpri 1"secured" 2 "senior unsecured" 3 "subordinated"
label define dsubpri 11 "secured bonds" 12 "secured loans" 13 "mortgage" 21 "unsecured bond" 22 "unsecured loans" 31 "sub bonds" 32"convertible sub"
label val dpriority dpri
label val dsubprior dsubpri

gen unsecured = 1 if securedtypeid==3
local unsecu "unsecured" "un collateralized" "preferred stock" 
foreach i in "`unsecu'" {
	replace unsecured = 1  if unsecured==. & strpos(capitalstructuredescription, "`i'") 
}
replace unsecured = 1 if unsecured==. & (strpos(descriptiontext, "debenture") | strpos(capitalstructuredescription, "debenture"))
replace unsecured = 1 if unsecured==. & (strpos(descriptiontext, "trust preferred") | strpos(capitalstructuredescription, "trust preferred"))
 
 
//secured 
replace dpriority = 1 if dpriority==. & dtype==5 /*mortgage*/
replace dpriority = 1 if dpriority==. & dtype==8 /*securitization*/
replace dpriority = 1 if dpriority==. & dsubtype==62 /*capital lease*/
replace dpriority = 1 if dpriority==. & dsubtype==22 & unsecured!=1 /*revenue bonds*/
replace dpriority = 1 if dsubtype==11 & unsecured!=1 /*revolver*/
local secu "collateral" "secured" "asset base" "borrowing base" "reserve base" "receivable" "tranch"
foreach i in "`secu'" {
	replace dpriority = 1 if dpriority==. & strpos(capitalstructuredescription, "`i'") & unsecured!=1
}
replace dpriority = 1 if dpriority==. & (securedtypeid==2 | securedtypeid==4 | securedtypeid==5 | securedtypeid==6 | securedtypeid==7)
local secu  "first lien" "second lien" "third lien" "first prior" "second prior" "third prior" "all asset" "all of the" "invent" "working capital" "finance compan" "fixed asset" 	///
"project finance" "recourse"
foreach i in "`secu'" {
	replace dpriority = 1 if dpriority==. & strpos(capitalstructuredescription, "`i'") & unsecured!=1
} 
replace dpriority = 1 if dpriority==. & security_level=="SS"
 
//subordinated
local sub "subordinat" "senior sub" "junior sub" "convertible sub" "capital trust"
foreach i in "`sub'" {
	replace dpriority = 3 if dpriority==. & strpos(capitalstructuredescription, "`i'")
}
replace dpriority = 3 if dpriority==. & (security_level=="SUB"|security_level=="SENS" |security_level=="JUN" |security_level=="JUNS")
replace dpriority = 3 if dpriority==. & (strpos(descriptiontext, "trust prefer") | strpos(capitalstructuredescription, "trust prefer"))

//senior unsecured
local sen  "senior" "bank" "loan" "facil" "revolv" "line of credit" "credit line"
foreach i in "`sen'" {
replace dpriority = 2 if dpriority==. & unsecured==1 & strpos(capitalstructuredescription, "`i'")
}

//supplement
local secu  "revolv" "credit facil" "term facil"  
foreach i in "`secu'" {
	replace dpriority = 1 if dpriority==. & strpos(capitalstructuredescription, "`i'") & unsecured!=1
} 
replace dpriority = 3 if dpriority==.  & dtype==3 /*convertible*/
replace dpriority = 2 if dpriority==.  & strpos(capitalstructuredescription, "senior note")
replace dpriority = 2 if dpriority==.  & strpos(capitalstructuredescription, "commercial paper")
replace dpriority = 2 if dpriority==.  & strpos(capitalstructuredescription, "unsecured")
replace dpriority = 2 if dpriority==.  & strpos(capitalstructuredescription, "uncollateral")
replace dpriority = 2 if dpriority==.  & dsubtype==41

replace dpriority = 2 if dpriority==. & dtype!=7 & dsubtype!=63 & dsubtype!=64 /*senior unsecured, except for unclassified notes payable, personal, and government*/

replace dsubprior = 12 if dpriority==1 & dtype==1
replace dsubprior = 13 if dpriority==1 & dtype==5
replace dsubprior = 11 if dpriority==1 & (dtype==2 | dtype==3 | dtype==4)

replace dsubprior = 22 if dpriority==2 & dtype==1 
replace dsubprior = 21 if dpriority==2 & (dtype==2 | dtype==3 | dtype==4)

replace dsubprior = 32 if dpriority==2 & dtype==3 
replace dsubprior = 31 if dpriority==3 & (dtype==2 | dtype==4)


*********************
**   ABL vs. CFL   **
*********************

gen ctype = 0

label define abl 1 "asset based" 2 "cash flow based" 3 "convertible" 4 "personal" 5 "capital lease" 9 "misc" 
label val ctype abl

replace ctype = 1 if strpos(descriptiontext, "mortgage")  /*abl*/
replace ctype = 1 if strpos(capitalstructuredescription, "mortgage")
replace ctype = 1 if strpos(capitalstructuredescription , "equipment")
replace ctype = 1 if strpos( capitalstructuredescription , "machine")
replace ctype = 1 if strpos( capitalstructuredescription , "real estate")
replace ctype = 1 if strpos( capitalstructuredescription , "building")
replace ctype = 1 if strpos( capitalstructuredescription , "propert")
replace ctype = 1 if strpos( capitalstructuredescription , "aircraft")
replace ctype = 1 if strpos( capitalstructuredescription , "asset based")
replace ctype = 1 if strpos( capitalstructuredescription , " abl facilit")
replace ctype = 1 if strpos( capitalstructuredescription , "asset back")

replace ctype = 2 if strpos( capitalstructuredescription , "cash flow")

replace ctype = 1 if ctype==0 &  strpos( capitalstructuredescription , "sba")
replace ctype = 1 if ctype==0 &  strpos( capitalstructuredescription , "receivable")
replace ctype = 1 if ctype==0 &  strpos( capitalstructuredescription , "inventor")
replace ctype = 1 if ctype==0 &  strpos( capitalstructuredescription , "auto loan")
replace ctype = 1 if ctype==0 &  strpos( capitalstructuredescription , "vehicle")
replace ctype = 1 if ctype==0 &  strpos( capitalstructuredescription , "automob")
replace ctype = 1 if ctype==0 &  strpos( capitalstructuredescription , "oil")
replace ctype = 1 if ctype==0 &  strpos( capitalstructuredescription , "reserve based")
replace ctype = 1 if ctype==0 &  strpos( capitalstructuredescription , "borrowing base")
replace ctype = 1 if ctype==0 &  strpos( capitalstructuredescription , "drill")
replace ctype = 1 if ctype==0 &  strpos( capitalstructuredescription , "securitiz")
replace ctype = 1 if ctype==0 &  strpos( capitalstructuredescription , "factor")
replace ctype = 1 if ctype==0 &  strpos( capitalstructuredescription , "margin loan")
replace ctype = 1 if ctype==0 & strpos( capitalstructuredescription , "working capital")
replace ctype = 1 if ctype==0 &  strpos(capitalstructuredescription, "fixed asset")
replace ctype = 1 if ctype==0 &  strpos(capitalstructuredescription, "finance compan") & securedtypeid!=3
replace ctype = 1 if ctype==0 &  strpos( capitalstructuredescription , "construction")  & strpos( capitalstructuredescription , "construction bank")==0

replace ctype = 5 if ctype==0 &  strpos(descriptiontext, "capital lease") /*capital lease*/
replace ctype = 5 if ctype==0 &  strpos(capitalstructuredescription, "capital lease") /*capital lease*/
replace ctype = 5 if ctype==0 &  strpos(capitalstructuredescription, "capitalized lease") /*capital lease*/

replace ctype = 4 if ctype==0 & strpos( capitalstructuredescription , "director")  /*personal*/
replace ctype = 4 if ctype==0 & strpos( capitalstructuredescription , "holder")
replace ctype = 4 if ctype==0 & strpos( capitalstructuredescription , "officer")
replace ctype = 4 if ctype==0 & strpos( capitalstructuredescription , "related part")
replace ctype = 4 if ctype==0 & strpos( capitalstructuredescription , " mr.")
replace ctype = 4 if ctype==0 & strpos( capitalstructuredescription , " mr ")
replace ctype = 4 if ctype==0 & strpos( capitalstructuredescription , " ms.")
replace ctype = 4 if ctype==0 & strpos( capitalstructuredescription , " ms ")
replace ctype = 4 if ctype==0 & strpos( capitalstructuredescription , " mrs.")
replace ctype = 4 if ctype==0 & strpos( capitalstructuredescription , " mrs ")
replace ctype = 4 if ctype==0 & strpos(capitalstructuredescription, " dr. ")
replace ctype = 4 if ctype==0 & strpos( capitalstructuredescription , " estate of ")
replace ctype = 4 if  ctype==0 &  strpos( capitalstructuredescription , "individual")
replace ctype = 4 if  ctype==0 &  strpos( capitalstructuredescription , "chairman")
replace ctype = 4 if  ctype==0 &  strpos( capitalstructuredescription , " ceo")
replace ctype = 4 if  ctype==0 &  strpos( capitalstructuredescription , "executiv")
replace ctype = 4 if  ctype==0 &  strpos( capitalstructuredescription , "member")
replace ctype = 4 if  ctype==0 &  strpos( capitalstructuredescription , "founder")
replace ctype = 4 if  ctype==0 &  strpos( capitalstructuredescription , "president")
replace ctype = 4 if  ctype==0 &  strpos( capitalstructuredescription , "wife")

replace ctype = 1 if ctype==0 &  strpos( capitalstructuredescription , "revenue bond")
replace ctype = 1 if ctype==0 &  strpos( capitalstructuredescription , "industrial revenue")
replace ctype = 1 if ctype==0 &  strpos( capitalstructuredescription , "revenue refunding")
replace ctype = 1 if ctype==0 &  strpos( capitalstructuredescription , "industrial develop")

replace ctype = 9 if ctype==0 &  strpos( capitalstructuredescription , "government")
replace ctype = 9 if ctype==0 &  strpos( capitalstructuredescription , "pollution control")
replace ctype = 9 if ctype==0 &  strpos( capitalstructuredescription , "city of")
replace ctype = 9 if ctype==0 &  strpos( capitalstructuredescription , "state of")
replace ctype = 9 if ctype==0 &  strpos( capitalstructuredescription , "county of")
replace ctype = 9 if ctype==0 &  strpos( capitalstructuredescription , "municipal")
replace ctype = 9 if ctype==0 &  strpos( capitalstructuredescription , "ministry")
replace ctype = 9 if ctype==0 &  strpos( capitalstructuredescription , "vendor")
replace ctype = 9 if ctype==0 &  strpos( capitalstructuredescription , "seller")
replace ctype = 9 if ctype==0 &  strpos( capitalstructuredescription , "supplier")
replace ctype = 9 if ctype==0 &  strpos( capitalstructuredescription , "landlord")
replace ctype = 9 if ctype==0 &  strpos( capitalstructuredescription , "tenant")
replace ctype = 9 if ctype==0 &  strpos( capitalstructuredescription , "third part")
replace ctype = 9 if ctype==0 &  strpos( capitalstructuredescription , "3rd part")
replace ctype = 9 if ctype==0 &  strpos( capitalstructuredescription , "third member")
replace ctype = 9 if ctype==0 &  strpos( capitalstructuredescription , "3rd member")

replace ctype = 9 if ctype==0 &  strpos( capitalstructuredescription , "insurance")
replace ctype = 9 if ctype==0 &  strpos( capitalstructuredescription , "county")
replace ctype = 9 if ctype==0 &  strpos( capitalstructuredescription , "economic development")
replace ctype = 9 if ctype==0 &  strpos( capitalstructuredescription , "development bank")
replace ctype = 9 if ctype==0 &  strpos( capitalstructuredescription , "economic") & strpos( capitalstructuredescription , "development")
replace ctype = 9 if ctype==0 &  strpos( capitalstructuredescription , "lease") & strpos( capitalstructuredescription , "improve")
replace ctype = 1 if ctype==0 &  strpos(capitalstructuredescription, "facilities loan")
replace ctype = 1 if ctype==0 &  strpos(capitalstructuredescription, "facility loan")

replace ctype = 1 if ctype==0 &  strpos( capitalstructuredescription , " collateralized")

replace ctype = 3 if ctype==0 & convertibletypeid==4  /*converts*/
replace ctype = 3 if ctype==0 & strpos(capitalstructuredescription, "convert") & convertibletypeid!=7 /*converts*/

replace ctype = 9 if ctype==0 &  strpos( capitalstructuredescription , "parent")
replace ctype = 9 if ctype==0 &  strpos( capitalstructuredescription , "affili")
replace ctype = 4 if  ctype==0 &  strpos( capitalstructuredescription , "john")
replace ctype = 4 if  ctype==0 &  strpos( capitalstructuredescription , "robert")
replace ctype = 4 if  ctype==0 &  strpos( capitalstructuredescription , "david")
replace ctype = 4 if  ctype==0 &  strpos( capitalstructuredescription , "richard")
replace ctype = 4 if  ctype==0 &  strpos( capitalstructuredescription , "kevin")
replace ctype = 4 if  ctype==0 &  strpos( capitalstructuredescription , "howard")
replace ctype = 9 if ctype==0 &  strpos( capitalstructuredescription , "external part")

replace ctype = 2 if ctype==0 &  strpos(capitalstructuredescription, "first lien")  
replace ctype = 2 if ctype==0 &  strpos(capitalstructuredescription, "second lien")
replace ctype = 2 if ctype==0 &  strpos(capitalstructuredescription, "third lien")
replace ctype = 2 if ctype==0 &  strpos(capitalstructuredescription, "fourth lien")
replace ctype = 2 if ctype==0 &  strpos(capitalstructuredescription, "blanket lien")
replace ctype = 2 if ctype==0 &  strpos(capitalstructuredescription, "1st lien")  
replace ctype = 2 if ctype==0 &  strpos(capitalstructuredescription, "2nd lien")
replace ctype = 2 if ctype==0 &  strpos(capitalstructuredescription, "3rd lien")
replace ctype = 2 if ctype==0 &  strpos(capitalstructuredescription, "first priorit")
replace ctype = 2 if ctype==0 &  strpos(capitalstructuredescription, "second priorit")
replace ctype = 2 if ctype==0 &  strpos(capitalstructuredescription, "all asset")
replace ctype = 2 if ctype==0 &  strpos(capitalstructuredescription, "all of the")

replace ctype = 2 if ctype==0 &  strpos(capitalstructuredescription, "term a ")
replace ctype = 2 if ctype==0 &  strpos(capitalstructuredescription, "term b ")
replace ctype = 2 if ctype==0 &  strpos(capitalstructuredescription, "term c ")

replace ctype = 2 if ctype==0 &  strpos(capitalstructuredescription, "term loan a")
replace ctype = 2 if ctype==0 &  strpos(capitalstructuredescription, "term loan b")  
replace ctype = 2 if ctype==0 &  strpos(capitalstructuredescription, "term loan c")  
replace ctype = 2 if ctype==0 &  strpos(capitalstructuredescription, "term loan facilit") & strpos(capitalstructuredescription, "short term loan facilit") == 0  & strpos(capitalstructuredescription, "long term loan facilit") == 0
replace ctype = 2 if ctype==0 &  strpos(capitalstructuredescription, "tranch")

replace ctype = 2 if ctype==0 & strpos( capitalstructuredescription , "unsecured")  /*cash flow*/
replace ctype = 2 if ctype==0 & strpos(descriptiontext, "debenture")
replace ctype = 2 if ctype==0 & strpos(capitalstructuredescription, "debenture")
replace ctype = 2 if ctype==0 &  strpos( capitalstructuredescription , "un collateralized")
replace ctype = 1 if ctype==0 &  strpos(descriptiontext, "revolv")  & securedtypeid!=3 /*abl: all revolvers unless unsecured*/
replace ctype = 1 if ctype==0 &  strpos(capitalstructuredescription, "revolv")  & securedtypeid!=3 
replace ctype = 2 if ctype==0 & securedtypeid==3

replace ctype = 2 if ctype==0 &  strpos(capitalstructuredescription, "acquisition line")
replace ctype = 2 if ctype==0 &  strpos(capitalstructuredescription, "bridge loan") & strpos(capitalstructuredescription, "equity bridge loan")==0

replace ctype = 2 if ctype==0 &  strpos(capitalstructuredescription, "credit facilit")
replace ctype = 2 if ctype==0 &  strpos(capitalstructuredescription, "term facilit")
replace ctype = 2 if ctype==0 &  strpos(capitalstructuredescription, "syndicate")

replace ctype = 2 if ctype==0 &  strpos(capitalstructuredescription, "senior note")
replace ctype = 2 if ctype==0 &  strpos(capitalstructuredescription, "senior subordinated")

replace ctype = 2 if ctype==0 &  strpos(descriptiontext, "bond") & securedtypeid!=2 & securedtypeid!=4
replace ctype = 2 if ctype==0 &  strpos( capitalstructuredescription , "bond") & securedtypeid!=2 & securedtypeid!=4

replace ctype = 1 if ctype==0 &  strpos(capitalstructuredescription, "non recourse")
replace ctype = 1 if ctype==0 &  strpos(capitalstructuredescription, "nonrecourse")

replace ctype = 2 if ctype==0 &  strpos(capitalstructuredescription, "private place") & securedtypeid!=2 & securedtypeid!=4
replace ctype = 2 if ctype==0 &  strpos(capitalstructuredescription, "medium term note") & securedtypeid!=2 & securedtypeid!=4 

replace ctype = 2 if ctype==0 & securedtypeid!=2 & securedtypeid!=4  &  (strpos( capitalstructuredescription , "%")|strpos( capitalstructuredescription , "percent"))    
replace ctype = 2  if ctype==0 & securedtypeid!=2 & securedtypeid!=4 & (strpos(capitalstructuredescription, "term loan") | strpos(descriptiontext, "term loan")) & strpos(capitalstructuredescription, "short term loan")==0    
replace ctype = 2 if ctype==0 & securedtypeid!=2 & securedtypeid!=4  &  strpos( capitalstructuredescription , "credit agreement")   
replace ctype = 2 if ctype==0 & securedtypeid!=2 & securedtypeid!=4  &  strpos( capitalstructuredescription , "bridge note")  

replace ctype = 1 if ctype==0 &  strpos(descriptiontext, "term loan") & (securedtypeid==2|securedtypeid==4)
replace ctype = 1 if ctype==0 &  strpos(descriptiontext, "general borrowing")  & (securedtypeid==2|securedtypeid==4)
replace ctype = 1 if ctype==0 &  strpos(descriptiontext, "bank loan")    & (securedtypeid==2|securedtypeid==4)
replace ctype = 1 if ctype==0 &  strpos(descriptiontext, "notes payable")   & (securedtypeid==2|securedtypeid==4)  

replace ctype = 1 if ctype==0 &  strpos( capitalstructuredescription , "financing compan")
replace ctype = 1 if ctype==0 &  strpos( capitalstructuredescription , "finance compan")
replace ctype = 1 if ctype==0 &  strpos( capitalstructuredescription , "project finan")
replace ctype = 1 if ctype==0 &  strpos( capitalstructuredescription , "project debt")

replace ctype = 9 if ctype==0 &  strpos( capitalstructuredescription , "product finan")
replace ctype = 9 if ctype==0 &  strpos( capitalstructuredescription , "minority interest")
replace ctype = 9 if ctype==0 &  strpos( capitalstructuredescription , "preferred stock")
replace ctype = 9 if ctype==0 &  strpos( capitalstructuredescription , "environment")
replace ctype = 9 if ctype==0 &  strpos( capitalstructuredescription , "employee")
replace ctype = 9 if ctype==0 &  strpos( capitalstructuredescription , "accounts payable")

replace ctype = 2 if ctype==0 &  strpos( capitalstructuredescription , "subordinated")
replace ctype = 2 if ctype==0 &  strpos( capitalstructuredescription , "various banks")
replace ctype = 2 if ctype==0 &  strpos( capitalstructuredescription , "various financial")
replace ctype = 2 if ctype==0 &  strpos( capitalstructuredescription , "credit agreement")
replace ctype = 2 if ctype==0 &  strpos( capitalstructuredescription , "senior secured")

replace ctype = 1 if ctype==0 &  strpos( capitalstructuredescription , " motor ")
replace ctype = 1 if ctype==0 &  strpos( capitalstructuredescription , " home ")
replace ctype = 1 if ctype==0 &  strpos( capitalstructuredescription , " truck ")

replace ctype = 1 if ctype==0 &  strpos( capitalstructuredescription , "small business admin")
replace ctype = 2 if ctype==0 &  strpos( capitalstructuredescription , "bank facilit")
replace ctype = 2 if ctype==0 &  strpos( capitalstructuredescription , "term note")
replace ctype = 2 if ctype==0 &  strpos( capitalstructuredescription , "series")

replace ctype = 1 if ctype==0 &  strpos( capitalstructuredescription , " secured ")
replace ctype = 1 if ctype==0 &  strpos( capitalstructuredescription , "collateralized")
replace ctype = 1 if ctype==0 &  (securedtypeid==2 | securedtypeid==4)

foreach item in "brazil" "argentina" "ireland" "nederland" "rural" "china" "chinese" "harbin" "nanjing" "xuchang" "shanghai" "philippi" "japan" "foreign" ///
"taiwan" "israel" "hungar" "zhengzhou" "belgium" "venezuela" "chile" "trust bank" "india" "huaxia" "minsheng" "italy" {
replace ctype = 9 if ctype==0 &  strpos( capitalstructuredescription , "`item'")
}
replace ctype = 9 if ctype==0 &  strpos( capitalstructuredescription , "wholesale")
replace ctype = 9 if ctype==0 &  strpos( capitalstructuredescription , "accounting")

replace ctype = 2 if ctype==0 &  strpos( descriptiontext , "notes payable") & strpos( capitalstructuredescription, "promissory note")==0

gen abl = 0
replace abl = 1 if ctype == 1 | ctype==5
gen cfl = 0
replace cfl = 1 if ctype == 2 | ctype==3

****************************
**   By Type & Priority   **
****************************

***

gen byte dpriorityrsf1b = 1 if dpriority == 1 & dtype == 1 
replace dpriorityrsf1b = 2 if dpriority == 1 & missing(dpriorityrsf1b)
replace dpriorityrsf1b = 3 if dpriority == 2 
replace dpriorityrsf1b = 4 if dpriority == 3 & inlist(dtype, 2, 4)
replace dpriorityrsf1b = 5 if dpriority == 3 & dtype == 3
replace dpriorityrsf1b = 6 if dpriority == 3 & missing(dpriorityrsf1b)
replace dpriorityrsf1b = 7 if missing(dpriorityrsf1b)

label define dprsf1b 1 "bank secured" 2 "nonbank secured" 3 "unsecured" 4 "subordinated bonds" 5 "convertible subordinated" 6 "other subordinated" 7 "missing"
label values dpriorityrsf1b dprsf1b 

***

gen byte dpriorityablcfl = 1 if dpriority == 1 & abl == 1
replace dpriorityablcfl = 2 if dpriority == 1 & cfl == 1
replace dpriorityablcfl = 3 if dpriority == 2 
replace dpriorityablcfl = 4 if dpriority == 3 & dtype != 3
replace dpriorityablcfl = 5 if dpriority == 3 & dtype == 3
replace dpriorityablcfl = 6 if missing(dpriorityablcfl)

label define dpablcfl 1 "asset-based & secured" 2 "cash flow-based & secured" 	///
	3 "unsecured" 4 "subordinated" 5 "convertible" 6 "missing"
label values dpriorityablcfl dpablcfl

***

gen byte dtypeablcfl = 1 if dtype == 1 & abl == 1
replace dtypeablcfl = 2 if dtype == 1 & cfl == 1
replace dtypeablcfl = 3 if inlist(dtype, 2, 4) & abl == 1
replace dtypeablcfl = 4 if inlist(dtype, 2, 4) & cfl == 1
replace dtypeablcfl = 5 if dtypeablcfl==. & abl == 1
replace dtypeablcfl = 6 if dtypeablcfl==. & cfl == 1
replace dtypeablcfl = 7 if inlist(dsubtype, 63, 65)

label define dtablcfl 1 "bank abl" 2 "bank cfl" 	///
	3 "bond abl" 4 "bond cfl" 5 "other abl" 6 "other cfl" 7 "misc"
label values dtypeablcfl dtablcfl

gen revolver_secured = 1 if dsubtype==11  & dpriority==1
gen revolver_unsecured = 1 if dsubtype==11 & dpriority!=1
gen term_secured = 1 if dsubtype==12 & dpriority==1
gen term_unsecured = 1 if dsubtype==12 & dpriority!=1
gen bond_secured = 1 if inlist(dtype, 2, 4) & dpriority==1
gen bond_unsecured = 1 if inlist(dtype, 2, 4) & dpriority!=1

gen revolver_cfl = 1 if dsubtype==11 & cfl==1
gen revolver_abl = 1 if dsubtype==11 & abl==1
gen term_cfl = 1 if dsubtype==12 & cfl==1
gen term_abl = 1 if dsubtype==12 & abl==1

gen bank_cfl_secured = 1 if dtypeablcfl == 2 & dpriority == 1
gen bank_cfl_unsecured = 1 if dtypeablcfl == 2 & dpriority != 1
gen nonbank_cfl_secured = 1 if cfl == 1 & dtypeablcfl!=2 & dpriority == 1
gen nonbank_cfl_unsecured = 1 if cfl == 1 & dtypeablcfl!=2 & dpriority != 1

gen bond_cfl_secured = 1 if dtypeablcfl == 4 & dpriority == 1
gen bond_cfl_unsecured = 1 if dtypeablcfl == 4 & dpriority != 1
gen nonbond_cfl_secured = 1 if cfl == 1 & dtypeablcfl!=4 & dpriority == 1
gen nonbond_cfl_unsecured = 1 if cfl == 1 & dtypeablcfl!=4 & dpriority != 1
 
save "$DATA/CapitalIQ/debttype_detail.dta", replace

********************
**   Firm Level   **
********************

use "$DATA/CapitalIQ/debttype_detail.dta", clear

*Some anamolies*
drop if month(periodenddate)==10 & year==2015 & tic=="KO"

/*Currency Conversion*/

replace issuedcurrencyid = 31 if issuedcurrencyid==30 /*Chile firms: CLF vs CLP*/

ren issuedcurrencyid issuedcurr
merge m:1 issuedcurr using "$CAPIQ/isscurrcode.dta", keep(1 3) 
tab _merge
drop _merge

gen tocurm = Code

merge m:1 tocurm yq using "$CAPIQ/g_exrtUSD_qtr.dta", keep(1 3) keepusing(exrat)
tab _merge
drop _merge

replace dataitemvalue = dataitemvalue/exrat
gen isabl = abl
gen iscfl = cfl

gen instrument = 1
gen instrument_cfl = 1 if cfl == 1
gen instrument_abl = 1 if abl == 1
gen instrument_cfl_secured = 1 if dpriorityablcfl == 2
foreach item in bank_cfl_secured nonbank_cfl_secured {
gen instrument_`item' = 1 if `item'==1
}

foreach var in dtype dsubtype dpriority dsubprior dpriorityrsf1b dpriorityablcfl dtypeablcfl {	
tab `var', gen (`var'_)
foreach item of varlist `var'_*{
replace `item' = `item'*dataitemvalue
}
}

foreach item of varlist abl cfl revolver_secured-nonbond_cfl_unsecured{
replace `item' = `item'*dataitemvalue
}

gen newstd = new*std

collapse (sum) dataitemvalue dtype_* dsubtype_* dpriority_* dsubprior_* abl cfl	revolver_secured-nonbond_cfl_unsecured ///
	dpriorityrsf1b_* dpriorityablcfl_*	dtypeablcfl_* instrument* isabl iscfl (median) sic dltt dlc at_tile at seq ceq fyear (lastnm) tic cusip companyname, by(gvkey yq)

*CapitalIQ summary
**Please update this file to latest**
merge m:1 gvkey yq using "$DATA/CapitalIQ/ciqdt_short_out_pub.dta",  keep(1 3) keepusing(principalamtdbt-trustpreferred) 
drop _merge

gen debttot = dlc+dltt
ren dataitemvalue ciqsum
gen capital = seq+debttot if seq+debttot>0

/* debt share by type */

* 1 "bank" 2 "public bond (non-convert)"  3 "convertible" 4 "program debt" 5 "mortgage/equipment" 6 "other" 7 "notes payable & oth" 8 "securitization", replace 
* 11 "revolver" 12 "term loan" 13 "other bank debt" 21 "regular" 22 "revenue" 23 "144a" 41 "commercial paper" 42 "mtn"$DATA///
* 51 "mortgage" 52 "equipment etc" 61 "acquisition" 62 "capitalized leases" 63 "personal" 64 "government" 65 "misc" 71 "securitization", replace 

ren *dtype_1 *bank
ren *dtype_2 *bond
ren *dtype_3 *convert
ren *dtype_4 *program
ren *dtype_5 *mortgageequip
ren *dtype_6 *other
ren *dtype_7 *notesoth
ren *dtype_8 *securitiz

label var dpriority_1 "secured"
label var dpriority_2 "senior unsecured"
label var dpriority_3 "subordinated"

label var dsubprior_1 "secured bonds"
label var dsubprior_2 "secured loans"
label var dsubprior_3 "mortgage"
label var dsubprior_4 "unsecured bond"
label var dsubprior_5 "unsecured loans"
label var dsubprior_6 "sub bonds"
label var dsubprior_7 "convertible sub"

ren *dsubtype_1 *revolver
ren *dsubtype_2 *termloan
ren *dsubtype_3 *bankoth
ren *dsubtype_4 *pubbond
ren *dsubtype_5 *revenuebond
ren *dsubtype_6 *bond144a
ren *dsubtype_7 *cp
ren *dsubtype_8 *mtn
ren *dsubtype_9 *mortgage 
ren *dsubtype_10 *equipment
ren *dsubtype_11 *acquisition
ren *dsubtype_12 *caplease
ren *dsubtype_13 *personal
ren *dsubtype_14 *govt
ren *dsubtype_15 *misc

rename *dpriorityrsf1b_1 *bank_secured
gen bank_unsecured = bank - bank_secured
order bank_unsecured, after(bank_secured)
rename *dpriorityrsf1b_2 *nonbank_secured
rename *dpriorityrsf1b_3 *senior_unsecured
rename *dpriorityrsf1b_4 *sub_bonds
rename *dpriorityrsf1b_5 *convert_sub
rename *dpriorityrsf1b_6 *other_sub

rename *dpriorityablcfl_1 *abl_secured
gen abl_unsecured = abl - abl_secured
order abl_unsecured, after(abl_secured)
rename *dpriorityablcfl_2 *cfl_secured
gen cfl_unsecured = cfl - cfl_secured
order cfl_unsecured, after(cfl_secured)
rename *dpriorityablcfl_3 *unsecured
rename *dpriorityablcfl_4 *subordinated
rename *dpriorityablcfl_5 *convertible

rename *dtypeablcfl_1 *bank_abl
rename *dtypeablcfl_2 *bank_cfl
rename *dtypeablcfl_3 *bond_abl
rename *dtypeablcfl_4 *bond_cfl
rename *dtypeablcfl_5 *oth_abl
rename *dtypeablcfl_6 *oth_cfl
gen nonbank_abl = abl - bank_abl
gen nonbank_cfl = cfl - bank_cfl
gen nonbond_abl = abl - bond_abl
gen nonbond_cfl = cfl - bond_cfl
order nonbank_abl nonbank_cfl nonbond_abl nonbond_cfl, after(oth_cfl)
rename *dtypeablcfl_7 *unclassified

gen ablnm = abl - mortgage

foreach item of varlist bank-unclassified ablnm invrec realestate ppe ppel blanketlien pother ip {
gen `item'_at = `item'/at
gen `item'_debtciq = `item'/ciqsum
}

/* debt share by priority */

*Main categories
gen secured = secureddbt
replace secured = dpriority_1 if secured==.  
gen srunsec = totsrdbt - secureddbt
replace srunsec = totsrdbt if secureddbt==.
replace srunsec = dpriority_2 if srunsec==.
gen sub = totsubdbt 
replace sub = subdbt if sub==.
replace sub = dpriority_3 if sub==.

gen secured_alt = dpriority_1 
replace secured_alt = secureddbt if secured_alt==0 & secureddbt!=.
gen srunsec_alt = dpriority_2 
replace srunsec_alt = totsrdbt - secureddbt if srunsec_alt==0 & totsrdbt!=. & secureddbt!=.
gen sub_alt = dpriority_3 
replace sub_alt = totsubdbt  if sub_alt==0 & totsubdbt!=.
replace sub_alt = subdbt if sub_alt==0 & subdbt!=.

foreach item in secured srunsec sub{
gen `item'_at = `item'/at
gen `item'_alt_at = `item'_alt/at
gen `item'_debtciq = `item'/ciqsum
gen `item'_alt_debtciq = `item'_alt/ciqsum
}

*Sub-categories

* 1"secured" 2 "senior unsecured" 3 "subordinated"
* 11 "secured bonds" 12 "secured loans" 13 "mortgage" 21 "unsecured bond" 22 "unsecured loans" 31 "sub bonds" 32"convertible sub"

gen secbond = dsubprior_1
gen secloan = dsubprior_2
gen secmortgage = mortgageequip

gen unsecbond = dsubprior_4
gen unsecloan = dsubprior_5

gen subbond = dsubprior_6
gen subconvert = dsubprior_7
 

foreach item of varlist secbond-subconvert {
gen `item'_at = `item'/at
gen `item'_debtciq = `item'/ciqsum
*gen `item'_debt  = `item'/debttot
}

foreach var in ciqsum debttot seq ceq {
gen `var'_at = `var'/at
}

foreach item of varlist debttot principalamtdbtoutstanding sic-ig secureddbt-trustpreferred companyname{
cap drop `item'*
}

save "$DATA/CapitalIQ/debttype_out.dta", replace
