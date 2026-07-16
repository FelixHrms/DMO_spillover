clear all
set more off

global path "C:\Users\hermesf\Projects\BanksFC"

* USD exposure (bond-day, built from t-1 positions in the notebook)
import delimited "$path\bond_usd_exposure.csv", clear case(lower)
gen d = date(word(date, 1), "YMD")
drop date
rename d date
format date %td
tempfile expo
save `expo'

* Euro area bond yields
import delimited "$path\bond_ts.csv", clear case(lower)
gen date = date(word(dates, 1), "YMD")
format date %td
drop if missing(isin)
duplicates drop isin date, force
gen yield = (yld_ytm_bid + yld_ytm_ask) / 2
gen ba_spread = px_ask - px_bid

* US treasury auction surprises
merge m:1 date using "$path\surprises.dta", keep(match) nogen

* USD exposure of the bond's intermediaries
merge 1:1 isin date using `expo', keep(master match) nogen

* Daily yield change in bps
egen bond_id = group(isin)
sort bond_id date
by bond_id: gen d_yield = 100 * (yield - yield[_n-1])

* Auction results (~19:00 CET) land after the EA close -> previous-day shock;
* controls also at t-1 so they are predetermined w.r.t. the shock
by bond_id: gen z1_lag = z1[_n-1]
by bond_id: gen z2_lag = z2[_n-1]
by bond_id: gen dur_lag = duration[_n-1]
by bond_id: gen spread_lag = ba_spread[_n-1]

* (1) Average spillover, level surprise
reghdfe d_yield z1_lag dur_lag spread_lag, absorb(bond_id) vce(cluster date)

* (2) Duration-scaled, level surprise; date FE absorb the aggregate shock
reghdfe d_yield c.z1_lag#c.dur_lag dur_lag spread_lag, absorb(bond_id date) vce(cluster date)

* (3) Average spillover, slope surprise
reghdfe d_yield z2_lag dur_lag spread_lag, absorb(bond_id) vce(cluster date)

* (4) Duration-scaled, slope surprise
reghdfe d_yield c.z2_lag#c.dur_lag dur_lag spread_lag, absorb(bond_id date) vce(cluster date)

* (5) Mechanism: USD-exposure-scaled spillover (usd_exposure already dated t
* from t-1 inputs -> do not lag again), duration gradient controlled
reghdfe d_yield c.z1_lag#c.usd_exposure c.z1_lag#c.dur_lag usd_exposure dur_lag spread_lag, absorb(bond_id date) vce(cluster date)

* (6) Local projections of the exposure interaction: cumulative yield change
* from the pre-shock close to t+h, h in trading days (h < 0: pre-trends;
* h = -1 is the reference point, zero by construction)
gen h = _n - 6 if _n <= 16
gen b = .
gen se = .
forvalues h = -5/10 {
    if `h' == -1 continue
    local j = `h' + 5
    bysort bond_id (date): gen y`j' = 100 * (yield[_n + `h'] - yield[_n - 1])
    reghdfe y`j' c.z1_lag#c.usd_exposure c.z1_lag#c.dur_lag usd_exposure dur_lag spread_lag, absorb(bond_id date) vce(cluster date)
    replace b = _b[c.z1_lag#c.usd_exposure] if h == `h'
    replace se = _se[c.z1_lag#c.usd_exposure] if h == `h'
    drop y`j'
}
replace b = 0 if h == -1
replace se = 0 if h == -1
gen lo = b - 1.96 * se
gen hi = b + 1.96 * se
twoway (rarea lo hi h, color(gs13)) (line b h, lcolor(navy)), yline(0, lpattern(dash)) ///
    xline(-0.5, lpattern(dot)) xtitle("Horizon (trading days)") ytitle("z1 x USD exposure") legend(off)
