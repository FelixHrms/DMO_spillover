


clear all
set more off
capture log close

global path "/Users/massisfreg/Library/CloudStorage/Dropbox/Projects/US_Spillover_Repo"
global data "$path/data"
global output "$data/output"
global graphs "$output/graphs"




* ------------------------------------------------------------------------------
* (Billnotebond) Window 10-20 
* ------------------------------------------------------------------------------
import delimited "$data/input/surp_raw_10y.csv", clear 

* Gen date
gen dated = date(date,"YMD")
format dated %td
drop date
ren dated date 
order date, first

keep if date < td(01may2025)

preserve 
* Principal components 
* v1: use only Treasury futures 2,5,10,30
* v2: use those in v1 + SP500
* v3: use those in v2 + ffc1 (front-month FFR future)

* v1
pca p_tuc1 p_fvc1 p_tyc1 p_usc1
predict pc1 pc2, score
ren pc1 z1
ren pc2 z2


* Keep PCs and Slope 
keep date count* z* 

* Save 
tempfile surp
save `surp'

* restore and merge 
restore 
merge 1:1 date using `surp', nogen
* Replace missing values with 0
foreach var of varlist z* {
	replace `var' = 0 if missing(`var')
}


save "$data/data_build/datasets/surprises", replace 
