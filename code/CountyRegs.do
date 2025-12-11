clear all
do globals
do functions

use "${data}/CountyAnalysisFile.dta", clear

* Prepare for regression
PreProcessCounty

/*************
    REGS
*************/
loc preperiod = -5
loc postperiod = 16
loc tot_period = `postperiod' - `preperiod' + 1
frame create Estimates
frame Estimates {
        
        insobs `tot_period'
        gen h = _n + `preperiod' - 1
        gen beta_ols = 0
        gen se_ols   = 0
        
}
forvalues h = `preperiod'/`postperiod' {
    
    loc hzn = abs(`h')
    loc x total_expost_pmt_norm
    
    if `h' >= 0 {
        loc y rgdp_H`hzn'
    }
    if `h' < 0 {
        loc y rgdp_L`hzn'
    }

    if `h' != -1 {
        qui reghdfe `y' `x', absorb(county_num year)
        frame Estimates {
            replace beta_ols = _b[`x']  if h == `h'
            replace se_ols   = _se[`x'] if h == `h'
        }
    }
}

frame Estimates {


    gen upper_ols = beta_ols + 1.645 * se_ols
    gen lower_ols = beta_ols - 1.645 * se_ols
    tw line beta_ols h, lcolor(ebblue) || rarea upper_ols lower_ols h, fcolor(ebblue%30) lwidth(none) ///
    xlab(`preperiod'(1)`postperiod', nogrid) ylab(, nogrid) legend(off)
}
