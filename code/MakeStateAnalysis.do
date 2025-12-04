clear all
do globals

/**********
    BEA
***********/
import delimited "${bea}/gdp_state_quarter.csv", clear

* First three rows are filler from the BEA
drop if _n <= 3

* Give proper names to the date columns
qui ds v*
foreach v in `r(varlist)' {

    if !inlist("`v'", "v1", "v2") {

        loc datestub = subinstr(strlower(`v'[1]), ":", "", 1)
        ren `v' gdp_`datestub'
    }
}

* State fips are only two digits long
gen statefip = substr(v1, 1, 2)
drop v1

ren v2 statename
order statefip statename

* Don't need the united states total or the metadata in the first row
drop if _n <= 2

* Format as numerical
qui ds gdp_*
foreach v in `r(varlist)' {
    destring `v', replace force
}


* Reshape
reshape long gdp_, i(statefip statename) j(dateq) s
drop if mi(gdp_) // not sure what is up with this
ren dateq dateqstr
gen dateq = quarterly(dateqstr, "YQ")
format dateq %tq
drop dateqstr

* Tidy it up
ren gdp_ gdp
la var gdp       "Gross domestic product (Current dollars)"
la var statefip  "State fip code"
la var statename "Name of state"
la var dateq     "Year-Quarter"

order statefip statename dateq gdp

tempfile gdp
save "`gdp'", replace

