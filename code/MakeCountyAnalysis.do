clear all
do globals

loc CleanBea       1
loc CleanPatents   1
loc CleanDeflator  1
loc CleanContracts 1

/********************************
                BEA
*********************************/
if `CleanBea' {

    import delimited "${bea}/CAGDP2_gdp_county_year/CAGDP2__ALL_AREAS_2001_2023.csv", clear

    * Clean up county fips codes
    replace geofip   = strtrim(geofip)
    gen fipscounty   = subinstr(geofip, `"""', "", .)
    order fipscounty
    drop geofip

    * drop the national aggregate and state aggregate
    drop if substr(fipscounty, -3, .) == "000"

    * Keep only the all industry total
    replace description = strtrim(description)
    keep if description == "All industry total"

    * Destring and convert to levels (thousands of dollars currently)
    qui ds v*
    loc yyyy = 2001
    foreach v in `r(varlist)' {
        
        destring `v', gen(gdp_`yyyy') force
        drop `v'
        replace gdp_`yyyy' = gdp_`yyyy' * 1e+3
        loc ++yyyy
    }

    drop unit description linecode tablename industryclassification region

    reshape long gdp_, i(fipscounty geoname) j(year) s
    destring year, replace
    ren gdp_ gdp
    la var gdp "GDP, Nominal"
    egen check = total(mi(gdp)), by(fipscounty)
    keep if check == 0
    drop check
    split geoname, parse(", ")
    replace geoname2 = subinstr(geoname2, "*", "", 1)
    drop if strpos(geoname2,"+") != 0
    ren geoname2 stateabb
    ren geoname1 countyname
    drop geoname
    order fipscounty countyname stateabb year
    drop geoname3
    
}

/********************************
                PATENTS
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
        gen year = yofd(dated)

        tostring state_fips,  gen(fipsstate)
        tostring county_fips, gen(countyfip)
        replace countyfip = "00" + countyfip if strlen(countyfip) == 1
        replace countyfip = "0"  + countyfip if strlen(countyfip) == 2
        replace fipsstate = "0"  + fipsstate if strlen(fipsstate) == 1
        gen fipscounty = fipsstate + countyfip

        gen counter = 1
        collapse (sum) counter, by(fipscounty year)

        ren counter patent_count
        la var patent_count "Patents granted"

        tempfile patents
        save "`patents'", replace

        frame drop inventors
        frame drop locations

    }

    
    merge 1:1 year fipscounty using "`patents'", keep(1 3) nogen
    frame drop patents
    replace patent_count = 0 if mi(patent_count)
}

/****************************************
    Merge in GDP Deflator (2017 == 100)
****************************************/
if `CleanDeflator' {

    frame create Deflator
    frame Deflator {

        import delimited "${data}/GDP_Deflator_Fred.csv", clear
        la var gdp "GDP Defaltor (2017 = 100)"

        gen dated = date(observation, "YMD")
        format dated %td
        gen year = yofd(dated)
        keep year gdp
        collapse (mean) gdp, by(year)

        tempfile Deflator
        save `Deflator', replace

    }

    * Merge it in
    merge m:1 year using `Deflator', nogen keep(1 3)
    frame drop Deflator
}

/****************************************
                Contracts
****************************************/
if `CleanContracts' {
    
    frame create contracts
    frame contracts {

        import delimited "${contracts}/county_panel.csv", clear
        gen dated = date(year_month, "YMD")
        format dated %td
        drop year_month
        gen year = yofd(dated)
        order dated year

        tostring fipscounty, replace
        replace fipscounty = "0"  + fipscounty if strlen(fipscounty) == 4

        drop *_raw
        keep year fipscounty *_tall *_wide
        collapse (sum) *_tall *_wide, by(year fipscounty)

        * Tidy labels
        foreach v of varlist *_tall {

            loc rtype = proper(subinstr("`v'", "_tall", "", 1))
            la var `v' "Realized obligated amount, `rtype'"
            replace `v' = 0 if mi(`v')
        }

        foreach v of varlist *_wide {

            loc rtype = proper(subinstr("`v'", "_wide", "", 1))
            la var `v' "Average ex-post payment, `rtype'"
            replace `v' = 0 if mi(`v')

        }

        * Save for merge
        tempfile contracts
        save `contracts', replace   
    }

    * Bring it all together - 3,800 state-quarter observations from 2005q1 to 2023q4
    merge 1:1 fipscounty year using `contracts', nogen keep(1 3)
    save "${data}/CountyAnalysisFile.dta", replace
    frame drop contracts

}