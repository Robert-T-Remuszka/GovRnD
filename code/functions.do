/***********
Prepare the left hand side and right hand side variables for our regressions.
***********/
program PreProcessState

    loc agencies "dod doe nih nasa nsf"
    encode statefip, gen(statefip_num)
    xtset statefip_num dateq

    * Aggregate defense nondefense
    gen DOE = DOE_Defense + DOE_Nondefense

    * NIH is under department of health and human services
    ren hhs_applied nih_applied
    ren hhs_basic nih_basic
    ren hhs_other nih_other

    * Wildcard friendly names - don't want the totals included when calculating totals
    ren tot_basic basic_tot
    ren tot_applied applied_tot
    ren tot_other other_tot

    * Spending vars
    egen basic_total = rowtotal(*_basic)
    egen applied_total = rowtotal(*_applied)
    egen other_total = rowtotal(*_other)
    gen total_exp = (basic_tot + applied_tot + other_tot) * 100 / gdpdef

    * Some outcome variables
    gen rgdp = gdp * 100 / gdpdef

    * Our independent variables
    gen total_exp_real = total_exp * 100 / gdpdef
    gen total_exp_asinh = asinh(total_exp_real)

    * Generate agency shares
    foreach agency in `agencies' {
        
        * Agency shares in all research spending
        gen `agency'_total_real = (`agency'_basic + `agency'_applied + `agency'_other) * 100 / gdpdef
        gen `agency'_total_share = `agency'_total_real / total_exp_real
        bys statefip (dateq): gen `agency'_total_share_2005q1 = `agency'_total_share[1]
        bys statefip (dateq): gen `agency'_total_share_2005q2 = `agency'_total_share[2]
        bys statefip (dateq): gen `agency'_total_share_2005q3 = `agency'_total_share[3]
        bys statefip (dateq): gen `agency'_total_share_2005q4 = `agency'_total_share[4]
        egen `agency'_total_share_init = rowmean(`agency'_total_share_2005*)

    }

    * Convert shocks to real
    sort statefip_num dateq
    foreach agency in `agencies' {

        loc fm_var = strupper("`agency'")

        * Deflate shock
        gen `fm_var'_real = `fm_var' * 100 / gdpdef

    }

    * Create the instrument
    loc bartik_sum_all_research "dod_total_share_2005q1 * DOD_real"
    foreach agency in `agencies' {

        loc fm_var = strupper("`agency'")

        * append each term in the sum iteratively (except the DOD part which is already there)
        if "`agency'" != "dod" loc bartik_sum_all_research "`bartik_sum_all_research' + `agency'_total_share_2005q1 * `fm_var'_real"
    }

    * Normalize the instrument by state gdp
    gen bartik_all_research = (`bartik_sum_all_research')
    
    * Create outcome vars
    forvalues h = -10/20 {

        sort statefip_num dateq
        loc hzn = abs(`h')
        if `h' < 0 {
            gen rgdp_L`hzn'    = log(L`hzn'.rgdp / L1.rgdp)
            gen patents_L`hzn' = log(L`hzn'.patent_count / L1.patent_count)
        }
        else {
            gen rgdp_F`hzn'    = log(F`hzn'.rgdp / L1.rgdp)
            gen patents_F`hzn' = log(F`hzn'.patent_count / L1.patent_count)
        }
    }
end

program PreProcessCounty

    * Fill in miisings
    foreach v of varlist *_tall *_wide {

        replace `v' = 0 if mi(`v')

    }

    * Designate as panel
    encode fipscounty, gen(county_num)
    xtset county_num year
    sort county_num year

    * Deflate
    foreach v of varlist *_tall *_wide {
        gen `v'_real = `v' * 100 / gdpdef
    }

    gen rgdp = gdp * 100 / gdpdef

    * Create right hand side vars
    egen total_expost_pmt = rowtotal(*_wide_real)
    replace total_expost_pmt = total_expost_pmt - other_wide_real
    gen  total_expost_pmt_norm = total_expost_pmt / l.rgdp
    gen  basic_expost_pmt_norm = basic_wide_real  / l.rgdp
    gen  applied_expost_pmt_norm = applied_wide_real / l.rgdp
    gen  other_expost_pmt_norm = other_wide_real / l.rgdp
    gen  total_expost_pmt_diff_norm = (total_expost_pmt - l.total_expost_pmt)/l.rgdp
    gen  basic_expost_pmt_diff_norm = (basic_wide_real -  l.basic_wide_real)/l.rgdp
    gen  applied_expost_pmt_diff_norm = (applied_wide_real - l.applied_wide_real)/l.rgdp

    * Changes for left hand side
    forvalues h = -5/16 {

        loc hzn = abs(`h')
        if `h' < 0 {
            
            gen rgdp_L`hzn' = log(l`hzn'.rgdp / l.rgdp)
            gen patents_L`hzn' = asinh(l`hzn'.patent_count) - asinh(l.patent_count)

        }
        else {

            gen rgdp_H`hzn' = log(f`hzn'.rgdp / l.rgdp)
            gen patents_H`hzn' = asinh(f`hzn'.patent_count) - asinh(l.patent_count)
        }
    }

end