clear all
set more off

global path "C:\Users\hermesf\Projects\BanksFC"

* Nelson-Siegel durations (DE)
import delimited "$path\NelsonSiegel_DE_prices.csv", clear case(lower)
keep bondcode refdate duration
gen date = date(word(refdate, 1), "YMD")
format date %td
rename bondcode isin
drop refdate
tempfile ns
save `ns'

* Euro area bond yields
import delimited "$path\bond_timeseries_v2.csv", clear case(lower)
gen date = date(word(dates, 1), "YMD")
format date %td
gen yield = (yld_ytm_bid + yld_ytm_ask) / 2

* US treasury auction surprises
merge m:1 date using "$path\surprises.dta", keep(match) nogen

* Controls: NS duration (residual maturity where missing), bid-ask spread
merge 1:1 isin date using `ns', keep(master match) nogen
gen res_mat = (date(word(bond_maturity, 1), "YMD") - date) / 365.25
replace duration = res_mat if missing(duration)
gen ba_spread = px_ask - px_bid

* Daily yield change in bps
egen bond_id = group(isin)
sort bond_id date
by bond_id: gen d_yield = 100 * (yield - yield[_n-1])

* Auction results (~19:00 CET) land after the EA close -> previous-day shock;
* controls also at t-1 so they are predetermined w.r.t. the shock
by bond_id: gen z1_lag = z1[_n-1]
by bond_id: gen dur_lag = duration[_n-1]
by bond_id: gen spread_lag = ba_spread[_n-1]

* (1) Average spillover
reghdfe d_yield z1_lag dur_lag spread_lag, absorb(bond_id) vce(cluster date)

* (2) Duration-scaled spillover; date FE absorb the aggregate shock
reghdfe d_yield c.z1_lag#c.dur_lag dur_lag spread_lag, absorb(bond_id date) vce(cluster date)
