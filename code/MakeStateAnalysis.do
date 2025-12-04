clear all
do globals


frame create mergethis

loc CleanBea       1
loc CleanContracts 1
loc CleanShocks    1
loc CleanPatents   1

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

    * Bring it all together - 3,800 state-quarter observations from 2005q1 to 2023q4
    merge 1:1 stateabb dateq using `mergethis', nogen keep(3)
    frame drop mergethis

}

/********************************
    Fieldhouse Mertens Shocks
*********************************/
if `CleanShocks' {
    
    frame create mergethis
    frame mergethis {
        import excel "${narrshocks}/rgrd_preliminary.xlsx", clear sheet("Quarterly Nominal R&D Shocks")
        ren A datestr
        drop N O P Q R S
        qui ds datestr, not
        foreach v in `r(varlist)' {
            loc part1 = subinstr(`v'[1], ": ", "_", 1)
            loc part2 = "_" + `v'[2]
            loc newname = "`part1'" + "`part2'"
            ren `v' `newname'
        }

        * Extra meta-data, just remember the shocks are in millions will rescale later
        drop if _n <= 3
        drop *_Endogenous

        * Make numerical
        qui ds datestr, not
        foreach v in `r(varlist)' {
            destring `v', replace force
            replace `v' = `v' * 1e+6
        }

        * Create quarterly dates
        replace datestr = substr(datestr, 1, 4) + "q1" if strlen(datestr) == 4
        replace datestr = substr(datestr, 1, 4) + "q2" if substr(datestr, 5, 3) == ".25"
        replace datestr = substr(datestr, 1, 4) + "q3" if substr(datestr, 5, 2) == ".5"
        replace datestr = substr(datestr, 1, 4) + "q4" if substr(datestr, 5, 3) == ".75"
        gen dateq = quarterly(datestr, "YQ")
        format dateq %tq
        drop datestr
        order dateq

        * Tidy labels
        qui ds dateq, not
        foreach v in `r(varlist)' {


            loc agency = subinstr("`v'", "_Exogenous", "", 1)
            ren `v' `agency'
            if substr("`v'", 1, 3) == "DOE" {
                loc category = subinstr("`agency'", "DOE_", "", 1)
                la var `agency' "DOE `category' Shock (Current dollars)"
            }
            else {
                la var `agency' "`agency' Shock (Current dollars)"
            }
        }

        tempfile shocks
        save `shocks', replace
    }

    * We now have 3000 state quarter observations from 2005q1 to 2019q4
    merge m:1 dateq using `shocks', nogen keep(3)
    frame drop mergethis
}


/********************************
    Patents
*********************************/
if `CleanPatents' {

    frame create patents 
    frame patents {
        import delimited "${patents}/g_patent.tsv", clear
        keep if patent_type == "utility" & !withdrawn

        keep patent_id patent_date patent_title num_claims
        tempfile patents
        save "`patents'", replace
    }

    frame create inventors
    frame inventors {

        import delimited "${patents}/g_inventor_disambiguated.tsv", clear

        * Keep the first named invetor on the patent
        keep if inventor_sequence == 0 
        
        tempfile inventors
        save "`inventors'", replace
    }

    frame create locations
    frame locations {
        import delimited "${patents}/g_location_disambiguated.tsv", clear
        tempfile locations
        save "`locations'", replace
    }

    * Merging it all
    frame patents {

        * Patents to their inventors - 8,342,330 patents paired to their inventors
        merge m:1 patent_id using "`inventors'", keep(3) nogen

        * Patents to the locations - 8,273,586 matched
        merge m:1 location_id using "`locations'", keep(3) nogen

        * Keep invetions which spawned in the US - 4,172,983
        keep if disambig_country == "US"

        * dropping a mere 10,126
        drop if mi(state_fips)

        * Create a quarterly date
        gen dated = date(patent_date, "YMD")
        format dated %td
        gen dateq = qofd(dated)
        format dateq %tq
        order dated dateq state_fips

        tostring state_fips, gen(statefip)
        replace statefip = "0" + statefip if strlen(statefip) == 1

        gen counter = 1
        collapse (sum) counter, by(statefip dateq)

        ren counter patent_count
        la var patent_count "Patents granted"

        tempfile patents
        save "`patents'", replace

        frame drop inventors
        frame drop locations

    }

    * All 3000 observations matched
    merge 1:1 dateq statefip using "`patents'", nogen keep(3)

    save "${data}/StateAnalysisFile.dta", replace
}

