clear all
do globals


frame create mergethis

loc CleanBea 1
loc CleanContracts 1

/********************************
                BEA
*********************************/
if `CleanBea' {

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
    
    * Still have regions in there
    drop if inlist(statename, "Far West", "Great Lakes", "Mideast", "New England", "Plains", ///
    "Rocky Mountain", "Southeast", "Southwest")
    

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

    * Merge in the US postal abbreviations
    frame create stateabb
    frame stateabb {
       import delimited "${data}/stateabb_statename_cross.csv", clear varn(1)
       ren abbreviation stateabb
       tempfile crosswalk
       save `crosswalk', replace
    }
    
    * Merge in the crosswalk, all observations matched
    merge m:1 statename using "`crosswalk'", nogen
    frame drop stateabb
}



/********************************
    USA Spending Contracts
*********************************/
if `CleanContracts' {
    
    frame mergethis {

        import delimited "${contracts}/state_panel.csv", clear

        * These were cleaned in python, so just get rid of the index column
        drop v1

        * Prepare dates for aggregateion at the quarterly level
        gen dated = date(date, "YMD")
        format dated %td
        gen dateq = qofd(dated)
        format dateq %tq
        order state date*

        qui ds state date*, not
        collapse (sum) `r(varlist)', by(state dateq)

        * Generate tidy labels
        qui ds state dateq, not
        foreach v in `r(varlist)' {

            loc varlab: var lab `v'
            loc tidylab = strproper(subinstr(subinstr("`varlab'", "(sum) ", "", 1), "_", " ", 1))
            la var `v' "`tidylab' Spending (Current dollars)"
        }

        ren state stateabb
        la var stateabb "State (US Postal Abb)"
        la var dateq     "Year-Quarter"

        * Save for merge
        tempfile mergethis
        save `mergethis', replace   
    }
}

* Bring it all together - 3,800 state-quarter observations from 2005q1 to 2023q4
merge 1:1 stateabb dateq using `mergethis', nogen keep(3)
