****************************************************************
***Calculate Operating Leases From CapitalIQ Debt Detail Data***
****************************************************************

clear all

if 1 | ("`c(username)'" == "yueranma") |  ("`c(username)'" == "Yueran Ma")  {
	global DATA "./Data"
	global CIQ "../Data/CapitalIQ"
	global CSTAT "../Data/Compustat"
}

/* CapitalIQ Debt Detail Data */

use "$DATA/CapitalIQ/capitaliq_debt_2020.dta", clear

cap destring gvkey, replace

*Adjust for units
replace unittypeid = 1 if unittypeid==2 &  companyid==568706872
replace dataitemvalue = dataitemvalue/10^6 if unittypeid==0
replace dataitemvalue = dataitemvalue/10^3 if unittypeid==1
 
tostring periodenddate, replace
gen periodenddate1=date(periodenddate,"YMD")
format periodenddate1 %td
drop periodenddate
rename periodenddate1 periodenddate
 
 
gen year = year(periodenddate)
gen qtr = quarter(periodenddate)
gen yq = qofd(periodenddate)
format yq %tq
gen yearq = year*10 + qtr
 
keep if latestforfinancialperiodflag==1
duplicates drop companyid periodenddate componentid, force

replace capitalstructuredescription = lower(capitalstructuredescription)
replace capitalstructuredescription = subinstr(capitalstructuredescription, "-", " ", .)
replace descriptiontext = lower(descriptiontext)

*Merge in gvkey
merge m:1 companyid yq using "$DATA/CapitalIQ/cpst_bridge_qtr.dta", keep(1 3 4 5) keepusing(gvkey) update
tab _merge
drop _merge

destring gvkey, replace
drop if gvkey==.

/** Lease ROU Asset **/

gen hasoplease = 0
replace hasoplease = 1 if strpos(capitalstructuredescription, "operating lease")
tab hasoplease
gen oplease = hasoplease*dataitemvalue

keep if yearq>=20191

collapse (sum) oplease (max) hasoplease , by(gvkey yq)

/** Firm-Level Opearting Lease Data **/

replace oplease = . if hasoplease==0

label var oplease "Operating Lease"
label var hasoplease "Has Operating Lease Data"

save "$DATA/CapitalIQ/oplease.dta", replace


***********************************
*  Merge with Compustat Snapshot  *
***********************************


/* Add Compustat Snapshot data */
			 
use "$DATA/Compustat/rouant_qtr.dta",clear
destring gvkey, replace
ren *, lower
tempfile rouant_qtr_cleaned
save "`rouant_qtr_cleaned'"


/* Basic Compustat data */
			   
               use "$DATA/Compustat/compustat_qtr.dta", clear
			   
			   keep if fyear>2015
			   
               drop if atq ==.	
               drop if fyearq ==.
               
               destring gvkey, replace
               
               gsort gvkey fyearq fqtr -datadate
               by gvkey fyearq fqtr: gen dup = cond(_N==1,0,_n)
               drop if dup>1
               drop dup
               
               // Remove gvkey datadate duplicates caused by change in fiscal year. 
               // Keep obs with the older fiscal year in this case
               duplicates tag gvkey datadate, gen(tagged)
               bysort gvkey datadate (fyearq fqtr): drop if tagged > 0 & _n > 1
               
               *Keep only US companies
               keep if fic=="USA"
 
               destring sic, replace
               gen sic2 = floor(sic/100)
               *Drop federal agencies
               drop if tic=="3FNMA" //Fannie Mae
               drop if tic=="3FMCC" //Freddie Mac
               *Issuer CUSIP
               replace cusip=substr(cusip,1,8)
               gen cusip6=substr(cusip,1,6)
			
                                             
               ********************************
               *Fiscal year to calendar year 
               ********************************
 
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

/* Match the datadate format in rouant_qtr */
tostring datadate, replace
gen datadate1=date(datadate,"YMD")
format datadate1 %td
drop datadate
rename datadate1 datadate
 

merge m:1 gvkey datadate using "`rouant_qtr_cleaned'", keep(1 3) keepusing(ll* rou*)
tab _merge
drop _merge
order datadate, after(gvkey)  
              
save "$DATA/Compustat/compustat_rouant_qtr.dta",replace


***********************************************
* 1. Merge Compustat data and Capital IQ data *
***********************************************


 
/* Add Capital IQ operating lease data to Compustat data */
				use "$DATA/Compustat/compustat_rouant_qtr.dta", clear
				 
				merge 1:1 gvkey yq using "$DATA/CapitalIQ/oplease.dta", keep(1 3) keepusing(*oplease*)
				tab _merge
				drop _merge
				 
				ren oplease opleaseciq
				gen oplease = rouantq
				replace oplease = opleaseciq if oplease==. & opleaseciq!=.
				

 /* Tag Adoption Date */         
				gen nonpublic = 0
				replace nonpublic = 1 if exchg<=1 | exchg==3 | (exchg>=7 & exchg<=10) | (exchg>=20 & exchg!=.)
				 
				gen adoption = yq if acctchgq=="ASU16-02" | acctchgq=="IFRS16"
				replace adoption = yq if fqtr==1 & fyearq==2019 & adoption==. & fyr==12  
				replace adoption = yq if fqtr==1 & fyearq==2020 & adoption==. & fyr<12 
				bysort gvkey: egen tmp1 = median(adoption)
				gen postadoption = (yq>=tmp1 & yq!=.)
				drop tmp*
				
               xtset
			   
			   gen ppent_at = ppentq/atq
			   save "$DATA/Compustat/lease_firm_noindustry.dta", replace
			   
			   

**************************************************************************************
* 2. Impute operating lease using industry average ratios for remaining missing data *
**************************************************************************************			
			
				use "$DATA/Compustat/lease_firm_noindustry.dta", clear
				
/* Operating Lease Ratios */
				gen oplease_ppentex = oplease/(ppentq - oplease)
				gen oplease_ppentin = oplease/(ppentq)
				gen oplease_atex = oplease/(atq  - oplease)
				gen oplease_atin = oplease/(atq)
				gen oplease_dlcex = llcq/(dlcq - llcq)
				gen oplease_dlcin = llcq/dlcq
				gen oplease_dlttex = llltq/(dlttq - llltq)
				gen oplease_dlttin = llltq/dlttq
				
/* By industry */
 
				keep if yearq==20194
				 
				foreach item of varlist oplease_* {
				egen tmp_ph=pctile(`item'), p(99)
				egen tmp_pl=pctile(`item'), p(1)
				replace `item'=. if `item'>tmp_ph | `item'<tmp_pl
				drop tmp_*
				}
				 
				collapse (median) oplease_*, by(sic2)
				
				tempfile sic2median
                save "`sic2median'"
				 
/* Then go back to firm level data */
				 
				 use "$DATA/Compustat/lease_firm_noindustry.dta", clear
				 merge m:1 sic2 using "`sic2median'" , keep(1 3)
				 tab _merge
				 drop _merge
				 
				 
				 replace rouantq = atq*oplease_atin if rouantq==. & postadoption==1  
				 replace llcq = dlcq*oplease_dlcin if llcq==. & postadoption==1  
				 replace llltq = dlttq*oplease_dlttin if llltq==. & postadoption==1  
							   			   
				 save "$DATA/Compustat/lease_firm.dta",replace
				 
				 
