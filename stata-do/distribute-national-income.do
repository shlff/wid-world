// List countries where we already have pre-tax national income
use "$work_data/calculate-per-capita-series-output.dta", clear
keep if substr(widcode, 1, 6) == "sptinc"
keep iso
duplicates drop
tempfile iso_ptinc
save "`iso_ptinc'"

// Averages
use "$work_data/calculate-per-capita-series-output.dta", clear

drop currency

generate sixlet = substr(widcode, 1, 6)
generate pop = substr(widcode, 7, 3)
generate vartype = substr(widcode, 10, 1)

drop widcode

keep if p == "pall"
keep if inlist(sixlet, "anninc", "afiinc")

drop if pop != "992"
drop if inlist(vartype, "t", "f", "m")
drop if sixlet == "afiinc" & iso == "MY" & vartype == "i" & year>=1984
drop vartype

reshape wide value, i(iso year p pop) j(sixlet) string

generate double factor = valueanninc/valueafiinc

drop valueanninc valueafiinc

drop if missing(factor)

tempfile factor
save "`factor'"

use "$work_data/calculate-per-capita-series-output.dta", clear

drop currency

generate onelet = substr(widcode, 1, 1)
generate fivelet = substr(widcode, 2, 5)
generate pop = substr(widcode, 7, 3)
generate vartype = substr(widcode, 10, 1)

keep if fivelet == "fiinc" & inlist(onelet, "a", "t")

merge n:1 iso year using "`factor'", nogenerate keep(match)

replace value = value*factor
replace fivelet = "ptinc"
replace widcode = onelet + fivelet + pop + vartype

drop factor onelet fivelet pop vartype

merge n:1 iso using "`iso_ptinc'", keep(master) nogenerate

tempfile averages
save "`averages'"

// Shares
use "$work_data/calculate-per-capita-series-output.dta", clear

keep if substr(widcode, 1, 9) == "sfiinc992"
replace widcode = "sptinc992" + substr(widcode, 10, 1)

merge n:1 iso using "`iso_ptinc'", keep(master) nogenerate

tempfile shares
save "`shares'"

// Aggregates
use "$work_data/calculate-per-capita-series-output.dta", clear

drop currency

generate sixlet = substr(widcode, 1, 6)
generate pop = substr(widcode, 7, 3)
generate vartype = substr(widcode, 10, 1)

keep if sixlet == "mfiinc"

merge n:1 iso year using "`factor'", nogenerate keep(match)

replace value = value*factor

replace widcode = "mptinc" + pop + vartype

drop factor sixlet pop vartype

merge n:1 iso using "`iso_ptinc'", keep(master) nogenerate

tempfile aggregates
save "`aggregates'"

// Add to main file
use "$work_data/calculate-per-capita-series-output.dta", clear

merge 1:1 iso year p widcode using "`averages'", update nogenerate
merge 1:1 iso year p widcode using "`shares'", update nogenerate
merge 1:1 iso year p widcode using "`aggregates'", update nogenerate

// Drop rescaled fiscal income series when DINA are available
gen x=1 if widcode=="aptinc992j"
bys iso: egen has_j=total(x)
drop if has_j>0 ///
	& substr(widcode,2,5)=="ptinc" ///
	& strpos(widcode,"ptinc992j")==0 ///
	& !inlist(iso,"FR")
drop x has_j

compress
label data "Generated by distribute-national-income.do"
save "$work_data/distribute-national-income-output.dta", replace

// Create metadata
use "`averages'", clear
append using "`shares'"
append using "`aggregates'"

gen x=1 if widcode=="aptinc992j"
bys iso: egen has_j=total(x)
drop if has_j>0 ///
	& substr(widcode,2,5)=="ptinc" ///
	& strpos(widcode,"ptinc992j")==0 ///
	& !inlist(iso,"FR")
drop x has_j

keep iso widcode

generate sixlet = substr(widcode, 1, 6)
drop widcode
duplicates drop

generate method = "Fiscal income rescaled to match the macroeconomic aggregates."
generate source = "WID.world computations using fiscal and net national income."

tempfile meta
save "`meta'"

use "$work_data/calculate-wealth-income-ratio-metadata.dta", clear

merge 1:1 iso sixlet using "`meta'", nogenerate update
replace extrapolation = "[[2004, 2019]]" if iso == "ID" & strpos(sixlet, "ptinc")
replace extrapolation = "[[2014, 2019]]" if iso == "SG" & strpos(sixlet, "sptinc")
replace extrapolation = "[[2013, 2019]]" if iso == "TW" & strpos(sixlet, "ptinc")
replace extrapolation = "[[2018, 2019]]" if iso == "NZ" & strpos(sixlet, "ptinc")

label data "Generated by distribute-national-income.do"
save "$work_data/distribute-national-income-metadata.dta", replace
