clear all
do globals
do functions

use "${data}/CountyAnalysisFile.dta", clear

* Prepare for regression
PreProcessCounty

* Controls for which responses to plot
loc rgdp_response    1
loc patents_response 1

/************************
    RGDP REGS
************************/

if `rgdp_response' {
    loc preperiod = -5
    loc postperiod = 16
    loc tot_period = `postperiod' - `preperiod' + 1

    ******** LHS = GDP long diff, rhs = overall payments
    frame create Estimates_total
    frame Estimates_total {

            * Observations correspond to horizons
            insobs `tot_period'
            gen h = _n + `preperiod' - 1
            gen beta_ols = 0
            gen se_ols   = 0
            
            forvalues h = `preperiod'/`postperiod' {
        
                loc hzn = abs(`h')
                loc x total_expost_pmt_norm patent_count
                loc y rgdp
                
                if `h' >= 0 {
                    loc suffix H`hzn'
                }
                if `h' < 0 {
                    loc suffix L`hzn'
                }

                if `h' != -1 {
                    frame default: qui reghdfe `y'_`suffix' `x' l(1/2).`y'_`suffix', absorb(county_num year) vce(cluster county_num)
                    replace beta_ols =  _b[total_expost_pmt_norm]  if h == `h'
                    replace se_ols   = _se[total_expost_pmt_norm]  if h == `h'
                }
            }

            * Plot results
            gen upper_ols = beta_ols + 1.645 * se_ols
            gen lower_ols = beta_ols - 1.645 * se_ols
            tw line beta_ols h, lcolor(ebblue) || rarea upper_ols lower_ols h, fcolor(ebblue%30) lwidth(none) yline(0, lcolor(black%30) lp(solid)) ///
            xlab(`preperiod'(2)`postperiod', nogrid labsize(small)) ylab(, nogrid) legend(off) name(`y'_v_total_pmt_ols) ytitle("GDP to Overall Spending")

            graph export "${graphs}/`y'_v_total_pmt_ols.pdf", name(`y'_v_total_pmt_ols) replace
            
    }


    ******** LHS = GDP log long diff, rhs = basic_pmt, applied_pmt
    frame create Estimate_split
    frame Estimate_split {

        insobs `tot_period'
        gen h = _n + `preperiod' - 1
        gen beta_applied_ols = 0
        gen beta_basic_ols   = 0
        gen se_applied_ols = 0
        gen se_basic_ols = 0

        forvalues h = `preperiod'/`postperiod' {
        
                loc hzn = abs(`h')
                loc x basic_expost_pmt_norm applied_expost_pmt_norm patent_count
                loc y rgdp

                if `h' >= 0 {
                    loc suffix H`hzn'
                }
                if `h' < 0 {
                    loc suffix L`hzn'
                }

                if `h' != -1 {
                    frame default: qui reghdfe `y'_`suffix' `x' l(1/2).`y'_`suffix', absorb(county_num year) vce(cluster county_num)
                    replace beta_basic_ols = _b[basic_expost_pmt_norm]  if h == `h'
                    replace se_basic_ols   = _se[basic_expost_pmt_norm] if h == `h'
                    replace beta_applied_ols = _b[applied_expost_pmt_norm] if h == `h'
                    replace se_applied_ols = _se[applied_expost_pmt_norm]  if h == `h'
                }
            }

            * Plot results - basic
            gen upper_basic_ols = beta_basic_ols + 1.645 * se_basic_ols
            gen lower_basic_ols = beta_basic_ols - 1.645 * se_basic_ols
            tw line beta_basic_ols h, lcolor(ebblue) || rarea upper_basic_ols lower_basic_ols h, fcolor(ebblue%30) lwidth(none) yline(0, lcolor(black%30) lp(solid)) ///
            xlab(`preperiod'(2)`postperiod', nogrid labsize(small)) ylab(, nogrid) legend(off) name(`y'_v_basic_pmt_ols) ytitle("GDP to Basic Spending")

            graph export "${graphs}/`y'_v_basic_pmt_ols.pdf", name(`y'_v_basic_pmt_ols) replace

            * Plot results - applied
            gen upper_applied_ols = beta_applied_ols + 1.645 * se_applied_ols
            gen lower_applied_ols = beta_applied_ols - 1.645 * se_applied_ols
            tw line beta_applied_ols h, lcolor(ebblue) || rarea upper_applied_ols lower_applied_ols h, fcolor(ebblue%30) lwidth(none) yline(0, lcolor(black%30) lp(solid)) ///
            xlab(`preperiod'(2)`postperiod', nogrid labsize(small)) ylab(, nogrid) legend(off) name(`y'_v_applied_pmt_ols) ytitle("GDP to Applied Spending")

            graph export "${graphs}/`y'_v_applied_pmt_ols.pdf", name(`y'_v_applied_pmt_ols) replace

    }

    ***** Combined graphs
    graph combine rgdp_v_applied_pmt_ols rgdp_v_basic_pmt_ols rgdp_v_total_pmt_ols, rows(2) cols(2) name(rgdp_responses_ols)
    graph export "${graphs}/rgdp_responses_ols.pdf", name(rgdp_responses_ols) replace

    frame drop Estimates_total Estimate_split
}
/************************
        PATENT REGS
************************/
if `patents_response' {

    loc preperiod = -5
    loc postperiod = 16
    loc tot_period = `postperiod' - `preperiod' + 1

    ******** LHS = GDP long diff, rhs = overall payments
    frame create Estimates_total
    frame Estimates_total {

            * Observations correspond to horizons
            insobs `tot_period'
            gen h = _n + `preperiod' - 1
            gen beta_ols = 0
            gen se_ols   = 0
            
            forvalues h = `preperiod'/`postperiod' {
        
                loc hzn = abs(`h')

                loc x total_expost_pmt_norm rgdp
                loc y patents
                
                if `h' >= 0 {
                    loc suffix H`hzn'
                }
                if `h' < 0 {
                    loc suffix L`hzn'
                }

                if `h' != -1 {
                    frame default: qui reghdfe `y'_`suffix' `x' l(1/2).`y'_`suffix', absorb(county_num year) vce(cluster county_num)
                    replace beta_ols =  _b[total_expost_pmt_norm]  if h == `h'
                    replace se_ols   = _se[total_expost_pmt_norm]  if h == `h'
                }
            }

            * Plot results
            gen upper_ols = beta_ols + 1.645 * se_ols
            gen lower_ols = beta_ols - 1.645 * se_ols
            tw line beta_ols h, lcolor(ebblue) || rarea upper_ols lower_ols h, fcolor(ebblue%30) lwidth(none) yline(0, lcolor(black%30) lp(solid)) ///
            xlab(`preperiod'(2)`postperiod', nogrid labsize(small)) ylab(, nogrid) legend(off) name(`y'_v_total_pmt_ols) ytitle("Patents to Overall Spending")

            graph export "${graphs}/`y'_v_total_pmt_ols.pdf", name(`y'_v_total_pmt_ols) replace
            
    }


    ******** LHS = GDP log long diff, rhs = basic_pmt, applied_pmt
    frame create Estimate_split
    frame Estimate_split {

        insobs `tot_period'
        gen h = _n + `preperiod' - 1
        gen beta_applied_ols = 0
        gen beta_basic_ols   = 0
        gen se_applied_ols = 0
        gen se_basic_ols = 0

        forvalues h = `preperiod'/`postperiod' {
        
                loc hzn = abs(`h')
                loc x basic_expost_pmt_norm applied_expost_pmt_norm rgdp
                loc y patents

                if `h' >= 0 {
                    loc suffix H`hzn'
                }
                if `h' < 0 {
                    loc suffix L`hzn'
                }

                if `h' != -1 {
                    frame default: qui reghdfe `y'_`suffix' `x' l(1/2).`y'_`suffix', absorb(county_num year) vce(cluster county_num)
                    replace beta_basic_ols = _b[basic_expost_pmt_norm]  if h == `h'
                    replace se_basic_ols   = _se[basic_expost_pmt_norm] if h == `h'
                    replace beta_applied_ols = _b[applied_expost_pmt_norm] if h == `h'
                    replace se_applied_ols = _se[applied_expost_pmt_norm]  if h == `h'
                }
            }

            * Plot results - basic
            gen upper_basic_ols = beta_basic_ols + 1.645 * se_basic_ols
            gen lower_basic_ols = beta_basic_ols - 1.645 * se_basic_ols
            tw line beta_basic_ols h, lcolor(ebblue) || rarea upper_basic_ols lower_basic_ols h, fcolor(ebblue%30) lwidth(none) yline(0, lcolor(black%30) lp(solid)) ///
            xlab(`preperiod'(2)`postperiod', nogrid labsize(small)) ylab(, nogrid) legend(off) name(`y'_v_basic_pmt_ols) ytitle("Patents to Basic Spending")

            graph export "${graphs}/`y'_v_basic_pmt_ols.pdf", name(`y'_v_basic_pmt_ols) replace

            * Plot results - applied
            gen upper_applied_ols = beta_applied_ols + 1.645 * se_applied_ols
            gen lower_applied_ols = beta_applied_ols - 1.645 * se_applied_ols
            tw line beta_applied_ols h, lcolor(ebblue) || rarea upper_applied_ols lower_applied_ols h, fcolor(ebblue%30) lwidth(none) yline(0, lcolor(black%30) lp(solid)) ///
            xlab(`preperiod'(2)`postperiod', nogrid labsize(small)) ylab(, nogrid) legend(off) name(`y'_v_applied_pmt_ols) ytitle("Patents to Applied Spending")

            graph export "${graphs}/`y'_v_applied_pmt_ols.pdf", name(`y'_v_applied_pmt_ols) replace

    }

    ***** Combined graphs
    graph combine patents_v_applied_pmt_ols patents_v_basic_pmt_ols patents_v_total_pmt_ols, rows(2) cols(2) name(patents_responses_ols)
    graph export "${graphs}/patents_responses_ols.pdf", name(patents_responses_ols) replace

}
