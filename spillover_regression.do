clear all
set more off

global path "C:\Users\hermesf\Projects\BanksFC"

* Euro area bond yields
import delimited "$path\bond_timeseries_v2.csv", clear case(lower)
gen date = date(word(dates, 1), "YMD")
format date %td
gen yield = (yld_ytm_bid + yld_ytm_ask) / 2

* US treasury auction surprises
merge m:1 date using "$path\surprises.dta", keep(match) nogen

* Daily yield change in bps
egen bond_id = group(isin)
sort bond_id date
by bond_id: gen d_yield = 100 * (yield - yield[_n-1])

* Auction results (~19:00 CET) land after the EA close -> use previous-day shock
by bond_id: gen z1_lag = z1[_n-1]

reghdfe d_yield z1_lag, absorb(bond_id) vce(cluster date)
