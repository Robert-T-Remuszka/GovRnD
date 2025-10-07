clear all
do globals

* Going to loop through each RePORT excel file (each is a particular year), do some light cleaning and append together into one big file
foreach yyyy of numlist 1992(1)2024 {

    frame create appendthis
    frame appendthis {

        if `yyyy' < 2023 {
            import excel "${data}/NIH/RePORT/Worldwide`yyyy'.xls", clear first case(lower) allstring
        }
        if `yyyy' > 2022 {
            import excel "${data}/NIH/RePORT/Worldwide`yyyy'.xlsx", clear first case(lower) allstring
        }
        
        ren fundingmechanism mech
        ren projectnumber pnum
        ren stateorcountryname state
        gen year = `yyyy'
        la var year "YEAR"
        order pnum state city year zipcode

        /* 
        Drop funding mechanisms which are not research related - RPG are "reasearch project grants" and the SBIR bit stands for 
        awards to small businesses
        */
        drop if inlist(mech, "Construction", "NULL", "Other", "Training - Individual", "Training - Institutional")

        /*
        Focus on awards going to US territories
        */
        drop if mi(state)
        drop if inlist(state, "VIRGIN ISLANDS", "PUERTO RICO", "GUAM")

    }

    * Append into the default frame - requires Baum's xframeappend --> ssc install xframeappend
    xframeappend appendthis, drop

}

/*
One would think the pnum is a unique identifier but not so. (pnum, year) is close so let's go with that
*/
duplicates drop pnum year, force
destring funding, force replace

* Save this for a merge with the ExPORTER data
save "${data}/RePORTER92to24.dta", replace

