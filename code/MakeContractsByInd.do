clear all
do globals

* For a loop across contract years
frame create contracts_appended

* Import PSC code and county FIPS
import delimited "${contracts}/ticeraskin_remuszka.csv", clear

* Prepare these for a merge with rest of contract data
ren contract_transaction_unique_key trans_id
ren product_or_service_code         psc_code

ren prime_award county_fips
replace county_fips = subinstr(county_fips, ".0", "", 1)
replace county_fips = "" if county_fips == "."
la var county_fips ""
drop federal_action_obligation

* Clean up the fips codes - one observation with fips == "MACOMB"
replace county_fips = "0" + county_fips if strlen(county_fips) == 4
drop if strlen(county_fips) == 6

tempfile psc
save `psc'

********* Loop

* The recipient_duns field is missing for all obs in 2023, hence I stop in 2022
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

    * Attach PSC code and county FIPS
    merge 1:1 trans_id using `psc', keep(master match) nogen

    * Sort so non-missing PSC and county come first within each award. Useful for collapse (first); recall that missings are infinite in Stata
    gen byte _m_psc    = missing(psc_code)
    gen byte _m_county = missing(county_fips)
    sort recipient_id award_id _m_psc _m_county trans_id
    drop _m_psc _m_county
    order recipient_id award_id trans_id

    * Collapse all transactions on a contract into a total obligation
    collapse (sum) total_obligation = federal_action ///
             (first) psc_code county_fips, ///
             by(recipient_id award_id year awarding_agency_code recipient_name naics_code)
    
    la var total_obligation "Total contract obligation"
    la var psc_code    "Product/Service Code"
    la var county_fips "County FIPS (place of performance)"

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

* Collapse total obligations for an award across years
gen byte _m_psc    = missing(psc_code)
gen byte _m_county = missing(county_fips)
sort award_id _m_psc _m_county
drop _m_psc _m_county
collapse (sum) total_obligation (min) year (first) psc_code county_fips, ///
    by(award_id recipient_id recipient agcy_code naics_pri)

la var total_obligation "Total ex-post obligation"
la var year             "year"
la var psc_code         "Product/Service Code"
la var county_fips      "County FIPS (place of performance)"

compress
save "${data}/ContractsByIndustry.dta", replace