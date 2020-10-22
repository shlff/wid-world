use "$work_data/ppp.dta", clear

// Add exchage rate with EUR and CNY
preserve
keep if iso == "EA"
drop iso
rename ppp ppp_ea
tempfile ppp_ea
save "`ppp_ea'" 
restore

preserve
keep if iso == "CN"
drop iso
rename ppp ppp_cn
tempfile ppp_cn
save "`ppp_cn'" 
restore

merge n:1 year using "`ppp_ea'", nogenerate
merge n:1 year using "`ppp_cn'", nogenerate

generate valuexlceup999i = ppp/ppp_ea
generate valuexlcyup999i = ppp/ppp_cn

rename ppp valuexlcusp999i
drop ppp_ea ppp_cn

reshape long value, i(iso year) j(widcode) string
replace widcode = widcode
generate p = "pall"
drop if missing(value)

drop if iso == "EA"

append using "$work_data/correct-widcodes-output.dta", gen(old)

// Get rid of PPP/MER from Piketty-Yang-Zucman paper
drop if substr(iso, 1, 2) == "CN" & substr(widcode, 1, 3) == "xlc" & old
drop old

label data "Generated by add-ppp.do"
save "$work_data/add-ppp-output.dta", replace
