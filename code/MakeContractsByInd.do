clear all
do globals

frame create contracts_appended

* The recipient_duns field is missing for all obs in 2023, hence i stop in 2022
loc loop_start 2001
loc loop_stop  2022

foreach yyyy of numlist `loop_start'/`loop_stop' {

    di "*******************************************************" _n "    CLEANING `yyyy' FILE" _n "*******************************************************"

    import delimited "${data}/Unzipped Contracts/base_file_`yyyy'.csv", clear
    
    * Drop if don't have a unique recipient identifier
    drop if inlist(recipient_duns, "", "NA")

    * Specify shorter names
    ren recipient_duns recipient_id
    ren contract_award award_id
    ren contract_trans trans_id

    la var recipient_id "Recipient unique ID"
    la var award_id     "Award-level unique ID"
    la var trans_id     "Transaction-level unique ID"
    
    sort recipient_id award_id trans_id 
    order recipient_id award_id trans_id

    * Collapse all transactions on a contract into a total obligation
    collapse (sum) total_obligation = federal_action, by(recipient_id award_id year awarding_agency_code recipient_name naics_code)
    la var total_obligation "Total contract obligation"

    * Replace NA NAICS as missing
    gen naics_award = naics_code if naics_code != "NA"
    la var naics_award "NAICS assoiciated with award"
    drop naics_code

    * Append the awarded contracts into one data frame - you must ssc install xframeappend
    frame contracts_appended: xframeappend default
}

frame copy contracts_appended default, replace
frame drop contracts_appended

* Compute obligation-weighted modal NAICS - recipient's primary industry by total spending
preserve

    keep recipient_id naics_award total_obligation

    * Sum obligations per recipient-naics combination across all years
    collapse (sum) total_obligation, by(recipient_id naics_award)

    * Keep the naics with highest total obligations (breaks ties whereas a simple count would not)
    bysort recipient_id (total_obligation naics_award): keep if _n == _N

    keep recipient_id naics_award
    ren naics_award naics_pri
    la var naics_pri "Primary NAICS"

    tempfile naics_pri
    save `naics_pri'

restore

merge m:1 recipient_id using `naics_pri', nogen

* Some final touch-ups
la var year "year"
ren awarding_agency_code agcy_code
la var agcy_code "Awarding agency"
ren recipient_name recipient
la var recipient "Recipient name"

* Some awards could not be associated with any industry
drop if naics_pri == ""

compress
save "${data}/ContractsByIndustry.dta", replace