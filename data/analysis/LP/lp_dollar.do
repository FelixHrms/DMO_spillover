* ------------------------------------------------------------------------------
* LP: German bond yields x US 10y auction surprise x dollar-repo exposure
*
* y_{i,t+h} - y_{i,t-1} = a_i + b_h (z1_t x dollar_i) + c_h z1_t + d_h dollar_i + e
*
* z1 scaled so 1 = one sd of the auction-day surprise; z1 > 0 = futures prices
* up = yields down ("strong auction"). b_h = extra bp response per 1pp of
* dollar_measure. Requires reghdfe (ssc install reghdfe).
* ------------------------------------------------------------------------------

clear all
set more off

global path "C:/Users/hermesf/Projects/BanksFC"
global data "$path/data"
global datasets "$data/build/datasets"
global graphs "$data/output/graphs"
global results "$data/output/results"

local H = 10   // max horizon (business days); stays clear of the next auction

* --- Panel ---
import delimited "$datasets/dollar_panel.csv", clear
gen dated = date(date, "YMD")
format dated %td
drop date
ren dated date

* bad quotes -> missing (keep the row so the business-day grid stays intact)
replace yield = . if yield <= -3 | yield >= 8

* --- Shocks ---
merge m:1 date using "$datasets/surprises", keepusing(count_10y z1) keep(1 3) nogen
replace z1 = 0 if count_10y != 1 | missing(z1)
qui sum z1 if count_10y == 1
replace z1 = z1 / r(sd)

* --- Business-day panel setup ---
encode isin, gen(id)
bysort id (date): gen t = _n
xtset id t

* one-day jumps > 40bp are bad quotes (same convention as old paper)
gen d1 = abs((yield - L.yield)*100)
replace yield = . if d1 > 40
drop d1

* --- Outcomes: cumulative yield change t-1 -> t+h, in bp ---
forvalues h = 0/`H' {
	gen dy`h' = (F`h'.yield - L.yield)*100
}

* --- LP ---
tempname res
postfile `res' h b se lo hi using "$results/lp_dollar_z1", replace
forvalues h = 0/`H' {
	reghdfe dy`h' c.z1##c.dollar_measure, absorb(id) vce(cluster date)
	local b  = _b[c.z1#c.dollar_measure]
	local se = _se[c.z1#c.dollar_measure]
	post `res' (`h') (`b') (`se') (`b' - 1.96*`se') (`b' + 1.96*`se')
}
postclose `res'

* --- Plot ---
use "$results/lp_dollar_z1", clear
twoway (rarea lo hi h, color(gs13)) (line b h, lwidth(medthick)), ///
	yline(0, lpattern(dash)) legend(off) ///
	xtitle("Horizon (business days)") ///
	ytitle("bp per 1sd shock per 1pp dollar exposure") ///
	title("Yield response: z1 x dollar_measure")
graph export "$graphs/lp_dollar_z1.pdf", replace
