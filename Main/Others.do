clear all

if ("`c(username)'" == "yueranma") |  ("`c(username)'" == "Yueran Ma")  |  ("`c(username)'" == "sony") | ("`c(username)'" == "julienweber") {
	global DATA "../Data"
	global CSTAT "$DATA/Compustat"
	global FIGURES "../Figures"
	global TABLES "../Tables"
}

program define fastload

use "$CSTAT/compustat_ann_out.dta", clear

drop if year>2018
drop if year<1985

drop if sic>=6000 & sic<7000
drop if sic>=9000 & sic!=.

end

**************Productivity Dispersion**************

fastload

merge 1:1 gvkey fyear using "$DATA/Compustat/PetersTaylor.dta", keep(1 3) keepusing(k_* q_*)
tab _merge
drop _merge

foreach item in q_tot {
bysort fyear : egen tmp_ph=pctile(`item'), p(99)
bysort fyear : egen tmp_pl=pctile(`item'), p(1)
replace `item'=. if `item'>tmp_ph 
replace `item'=. if `item'<tmp_pl 
drop tmp_* 
}

replace q_tot = . if q_tot>20
replace Q = . if Q>20

gen large = 0 if at!=.
replace large = 1 if at_tile>2 & at_tile!=.
gen small = 1 - large

merge m:1 sic2 using "$DATA/PacerRecovery.dta", keep(1 3) keepusing(Recovery*Mid)
tab _merge
drop _merge

gen liqval = (RecoveryReceivableMid/100)*rect_at + (RecoveryInventoryMid/100)*invt_at + (RecoveryPPEMid/100)*ppent_at 	 

preserve
collapse (mean) liqval (sd) sdQPT = q_tot sdQ = Q , by(sic2 year small)
label var liqval "Industry average liquidation value"
label var small "Small firms"

tempfile bysize
save "`bysize'"
restore

preserve
collapse (mean) liqval  (sd) sdQPT = q_tot sdQ = Q , by(sic2 year)
label var liqval "Ind avg liq val"

tempfile all
save "`all'"
restore

use "`bysize'", clear

binscatter sdQ liqval, by(small) line(none) msymbol(O d) xtitle("Average Firm Liquidation Value in Industry") ytitle("Standard Deviation of Q") legend(label(1 "Large Firms") label(2 "Small Firms"))
graph export "$FIGURES/FigureIA2_PanelA.pdf", as(pdf) replace

binscatter sdQPT liqval, by(small) line(none) msymbol(O d) xtitle("Average Firm Liquidation Value in Industry") ytitle("Standard Deviation of Q") legend(label(1 "Large Firms") label(2 "Small Firms"))
graph export "$FIGURES/FigureIA2_PanelB.pdf", as(pdf) replace



use "`all'", clear

collapse (mean) sdQ liqval, by(sic2)

label var liqval "Ind-avg firm liquidation value"
eststo: reg sdQ liqval , robust

use "`bysize'", clear

collapse (mean) sdQ liqval, by(sic2 small)

label var liqval "Ind-avg firm liquidation value"

eststo: reg  sdQ liqval if small==0 , robust
eststo: reg  sdQ liqval if small==1 , robust

use "`all'", clear

collapse (mean) sdQPT liqval, by(sic2)

label var liqval "Ind-avg firm liquidation value"

eststo: reg sdQPT liqval , robust

use "`bysize'", clear

collapse (mean) sdQPT liqval, by(sic2 small)

label var liqval "Ind-avg firm liquidation value"

eststo: reg  sdQPT liqval if small==0 , robust
eststo: reg  sdQPT liqval if small==1 , robust

#delimit ;
estout using "$TABLES/TableIA10.tex", replace style(tex) 
label mlabels(none) cells(b(fmt(2) star ) se(fmt(2) par)) 
keep(liqval) order(liqval)
starlevels(* .10 ** .05 *** .01)  collabels(none);

estout using "$TABLES/TableIA10_r2.tex", replace style(tex) 
cells(none) 
stats(N r2, fmt(%9.0fc %9.2f) labels("Obs" "R$^2$") ) 
mlabels(none) collabels(none);
#delimit cr

**************Price Rigidity**************

*Gorodnichenko-Weber data
forvalues k = 2/6{
import delimited "$DATA/Macro/FrequencyNaics`k'd.csv", clear 
tempfile weber`k'
save "`weber`k''"
}

fastload

forvalues k = 4(-1)2{
gen naics`k'd = substr(naics, 1, `k')
destring naics`k'd, replace
merge m:1 naics`k'd using "`weber`k''", keep(1 3 4 5) update
tab _merge
drop _merge
}

merge m:1 sic2 using "$DATA/PacerRecovery.dta", keep(1 3) keepusing(Recovery*Mid)
tab _merge
drop _merge

gen liqval = (RecoveryReceivableMid/100)*rect_at + (RecoveryInventoryMid/100)*invt_at + (RecoveryPPEMid/100)*ppent_at 	

collapse (mean) liqval* freq_id , by(sic2)

tempfile master
save "`master'"

use "$DATA/PacerRecovery.dta", clear

merge 1:1 sic2 using "`master'", keep(1 2 3)
tab _merge
drop _merge

*Nakamura-Steinsson data
merge 1:1 sic2 using "$DATA/Macro/SIC2_price_change_freq.dta", keep(1 3)
tab _merge
drop _merge

replace prc_chg_freq = prc_chg_freq/100

twoway (scatter prc_chg_freq liqval) (lfit prc_chg_freq liqval), legend(off) graphregion(color(white)) xtitle("Average Firm Liquidation Value in Industry") ytitle("Price Change Frequency (Nakamura-Steinsson)")
graph export "$FIGURES/FigureIA3_PanelA.pdf", as(pdf) replace

twoway (scatter freq_id liqval) (lfit freq_id liqval), legend(off) graphregion(color(white)) xtitle("Average Firm Liquidation Value in Industry") ytitle("Price Change Frequency (Gorodnichenko-Weber)")
graph export "$FIGURES/FigureIA3_PanelB.pdf", as(pdf) replace
 

replace RecoveryPPEMid = RecoveryPPEMid/100
replace RecoveryInventoryMid = RecoveryInventoryMid/100

label var RecoveryPPEMid "PPE liquidation recovery rate"
label var RecoveryInventoryMid "Inventory liquidation recovery rate"
label var liqval "Ind-avg firm liquidation value"

eststo clear
 
eststo: ivreg2  prc_chg_freq  RecoveryPPEMid  RecoveryInventoryMid , robust
eststo: ivreg2  prc_chg_freq liqval   , robust

eststo: ivreg2 freq_id RecoveryPPEMid RecoveryInventoryMid , robust
eststo: ivreg2 freq_id liqval   , robust


#delimit ;
estout using "$TABLES/TableIA11.tex", replace style(tex) 
label mlabels(none) cells(b(fmt(2) star ) se(fmt(2) par)) 
order(RecoveryPPEMid  RecoveryInventoryMid liqval)
varlabels(_cons Constant)  
starlevels(* .10 ** .05 *** .01)  collabels(none);

estout using "$TABLES/TableIA11_r2.tex", replace style(tex) 
cells(none) 
stats(N r2, fmt(%9.0fc %9.2f) labels("Obs" "R$^2$" ) ) 
mlabels(none) collabels(none);
#delimit cr
 