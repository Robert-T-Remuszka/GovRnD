*======================================================
*MASTER DO-FILE: COUNTY LP-IV WITH SHIFT–SHARE
*NEWEY-WEST STANDARD ERRORS + FIRST-STAGE F-STATS
*======================================================
clear all
set more off

do globals
do functions_ticeraskin

use "${data}/CountyAnalysisFile.dta", clear

*======================================================
*RUN PREPROCESSING
*======================================================
PreProcessCounty

*======================================================
*LOCAL PROJECTIONS — GDP RESPONSES (IV)
*======================================================
local preperiod  = -3
local postperiod = 15
local tot_period = `postperiod' - `preperiod' + 1

* Set Newey-West lag length (rule of thumb: floor(4*(T/100)^(2/9)))
* Adjust based on your time series length
local nw_lags = 3

frame create GDP_IV
frame GDP_IV {

    insobs `tot_period'
    gen h = _n + `preperiod' - 1

    gen beta_basic   = .
    gen beta_applied = .
    gen se_basic     = .
    gen se_applied   = .
    gen fstat_basic  = .
    gen fstat_applied = .
    
    forvalues h = `preperiod'/`postperiod' {

        local hzn = abs(`h')
        local y rgdp

        if `h' >= 0 local suffix H`hzn'
        if `h' <  0 local suffix L`hzn'

        if `h' == -1 {
            * Set h=-1 to zero (normalization)
            replace beta_basic   = 0 if h == `h'
            replace se_basic     = 0 if h == `h'
            replace beta_applied = 0 if h == `h'
            replace se_applied   = 0 if h == `h'
            replace fstat_basic  = . if h == `h'
            replace fstat_applied = . if h == `h'
        }
        else {
            * Partial out fixed effects first
            frame default {
                qui reghdfe `y'_`suffix', absorb(county_num year) resid
                predict double y_resid, residuals
                
                qui reghdfe basic_expost_pmt_norm, absorb(county_num year) resid
                predict double basic_resid, residuals
                
                qui reghdfe applied_expost_pmt_norm, absorb(county_num year) resid
                predict double applied_resid, residuals
                
                qui reghdfe basic_ss, absorb(county_num year) resid
                predict double basic_iv_resid, residuals
                
                qui reghdfe applied_ss, absorb(county_num year) resid
                predict double applied_iv_resid, residuals
                
                qui reghdfe l.gdp_control, absorb(county_num year) resid
                predict double gdp_ctrl_resid, residuals
                
                qui reghdfe l.basic_expost_pmt_diff_norm, absorb(county_num year) resid
                predict double basic_diff_resid, residuals
                
                qui reghdfe l.applied_expost_pmt_diff_norm, absorb(county_num year) resid
                predict double applied_diff_resid, residuals
                
                * Run IV with Newey-West standard errors
                qui ivreg2 y_resid ///
                    (basic_resid applied_resid = basic_iv_resid applied_iv_resid) ///
                    gdp_ctrl_resid basic_diff_resid applied_diff_resid, ///
                    bw(`nw_lags') kernel(bartlett) robust
                
                * Store results in frame
                frame GDP_IV {
                    replace beta_basic   = _b[basic_resid]   if h == `h'
                    replace se_basic     = _se[basic_resid]  if h == `h'
                    replace beta_applied = _b[applied_resid] if h == `h'
                    replace se_applied   = _se[applied_resid] if h == `h'
                    
                    * Store first-stage F-statistics
                    replace fstat_basic   = e(widstat) if h == `h'
                    replace fstat_applied = e(widstat) if h == `h'
                }
                
                * Clean up residuals
                drop y_resid basic_resid applied_resid basic_iv_resid applied_iv_resid ///
                     gdp_ctrl_resid basic_diff_resid applied_diff_resid
            }
        }
    }

    * 90% CI
    gen ub_basic_90 = beta_basic + 1.645 * se_basic
    gen lb_basic_90 = beta_basic - 1.645 * se_basic

    gen ub_applied_90 = beta_applied + 1.645 * se_applied
    gen lb_applied_90 = beta_applied - 1.645 * se_applied

    * 68% CI
    gen ub_basic_68 = beta_basic + 1.0 * se_basic
    gen lb_basic_68 = beta_basic - 1.0 * se_basic

    gen ub_applied_68 = beta_applied + 1.0 * se_applied
    gen lb_applied_68 = beta_applied - 1.0 * se_applied

    * Display first-stage F-statistics
    di _n "==================================================="
    di "FIRST-STAGE F-STATISTICS: GDP RESPONSES"
    di "==================================================="
    list h fstat_basic fstat_applied if h != -1, sep(0)
    
    * Summary statistics
    sum fstat_basic if h != -1
    local min_f_basic = r(min)
    sum fstat_applied if h != -1
    local min_f_applied = r(min)
    
    di _n "Minimum F-stat (Basic): " %6.2f `min_f_basic'
    di "Minimum F-stat (Applied): " %6.2f `min_f_applied'
    di "==================================================="
    
    *--------------------------------------------------
    * PROFESSIONAL PLOT: GDP RESPONSES (IV)
    *--------------------------------------------------

    twoway ///
        (rarea ub_applied_90 lb_applied_90 h, ///
            fcolor("68 105 176%20") lwidth(none)) ///
        (rarea ub_applied_68 lb_applied_68 h, ///
            fcolor("68 105 176%40") lwidth(none)) ///
        (line beta_applied h, ///
            lcolor("68 105 176") lwidth(0.6) lpattern(solid)) ///
        (rarea ub_basic_90 lb_basic_90 h, ///
            fcolor("34 139 34%20") lwidth(none)) ///
        (rarea ub_basic_68 lb_basic_68 h, ///
            fcolor("34 139 34%40") lwidth(none)) ///
        (line beta_basic h, ///
            lcolor("34 139 34") lwidth(0.6) lpattern(solid)) ///
        , ///
        yline(0, lcolor(black) lwidth(0.3)) ///
        xline(-1, lcolor(gs10) lwidth(0.25) lpattern(dash)) ///
        xlabel(-3(3)15, labsize(small) tlength(2)) ///
        ylabel(, labsize(small) angle(horizontal) format(%9.2f) nogrid) ///
        xtitle("Years from Shock", size(small) margin(small)) ///
        ytitle("Dynamic Multiplier", size(small) margin(small)) ///
        title("", size(medium) color(black)) ///
        legend(order(3 "Applied Research" 6 "Basic Research") ///
            position(6) rows(1) size(small) ///
            region(lcolor(none) fcolor(none)) ///
            symxsize(5) keygap(1) ring(0)) ///
        graphregion(color(white) margin(small)) ///
        plotregion(color(white) margin(small) lcolor(black) lwidth(0.3)) ///
        name(lp_gdp_pro, replace)

    graph export "${graphs}/lp_gdp_iv_nw.pdf", replace
    graph export "${graphs}/lp_gdp_iv_nw.png", replace width(2400)
}

*======================================================
*LOCAL PROJECTIONS — PATENT RESPONSES (IV)
*======================================================
frame create PATENTS_IV
frame PATENTS_IV {

    insobs `tot_period'
    gen h = _n + `preperiod' - 1

    gen beta_basic   = .
    gen beta_applied = .
    gen se_basic     = .
    gen se_applied   = .
    gen fstat_basic  = .
    gen fstat_applied = .
    
    forvalues h = `preperiod'/`postperiod' {
    
        local hzn = abs(`h')
        local y patents

        if `h' >= 0 local suffix H`hzn'
        if `h' <  0 local suffix L`hzn'

        if `h' == -1 {
            * Set h=-1 to zero (normalization)
            replace beta_basic   = 0 if h == `h'
            replace se_basic     = 0 if h == `h'
            replace beta_applied = 0 if h == `h'
            replace se_applied   = 0 if h == `h'
            replace fstat_basic  = . if h == `h'
            replace fstat_applied = . if h == `h'
        }
        else {
            * Partial out fixed effects first
            frame default {
                qui reghdfe `y'_`suffix', absorb(county_num year) resid
                predict double y_resid, residuals
                
                qui reghdfe basic_expost_pmt_norm, absorb(county_num year) resid
                predict double basic_resid, residuals
                
                qui reghdfe applied_expost_pmt_norm, absorb(county_num year) resid
                predict double applied_resid, residuals
                
                qui reghdfe basic_ss, absorb(county_num year) resid
                predict double basic_iv_resid, residuals
                
                qui reghdfe applied_ss, absorb(county_num year) resid
                predict double applied_iv_resid, residuals
                
                qui reghdfe l.gdp_control, absorb(county_num year) resid
                predict double gdp_ctrl_resid, residuals
                
                qui reghdfe l.basic_expost_pmt_diff_norm, absorb(county_num year) resid
                predict double basic_diff_resid, residuals
                
                qui reghdfe l.applied_expost_pmt_diff_norm, absorb(county_num year) resid
                predict double applied_diff_resid, residuals
                
                * Run IV with Newey-West standard errors
                qui ivreg2 y_resid ///
                    (basic_resid applied_resid = basic_iv_resid applied_iv_resid) ///
                    gdp_ctrl_resid basic_diff_resid applied_diff_resid, ///
                    bw(`nw_lags') kernel(bartlett) robust
                
                * Store results in frame
                frame PATENTS_IV {
                    replace beta_basic   = _b[basic_resid]   if h == `h'
                    replace se_basic     = _se[basic_resid]  if h == `h'
                    replace beta_applied = _b[applied_resid] if h == `h'
                    replace se_applied   = _se[applied_resid] if h == `h'
                    
                    * Store first-stage F-statistics
                    replace fstat_basic   = e(widstat) if h == `h'
                    replace fstat_applied = e(widstat) if h == `h'
                }
                
                * Clean up residuals
                drop y_resid basic_resid applied_resid basic_iv_resid applied_iv_resid ///
                     gdp_ctrl_resid basic_diff_resid applied_diff_resid
            }
        }
    }

    * 90% CI
    gen ub_basic_90 = beta_basic + 1.645 * se_basic
    gen lb_basic_90 = beta_basic - 1.645 * se_basic

    gen ub_applied_90 = beta_applied + 1.645 * se_applied
    gen lb_applied_90 = beta_applied - 1.645 * se_applied

    * 68% CI
    gen ub_basic_68 = beta_basic + 1.0 * se_basic
    gen lb_basic_68 = beta_basic - 1.0 * se_basic

    gen ub_applied_68 = beta_applied + 1.0 * se_applied
    gen lb_applied_68 = beta_applied - 1.0 * se_applied

    * Display first-stage F-statistics
    di _n "==================================================="
    di "FIRST-STAGE F-STATISTICS: PATENT RESPONSES"
    di "==================================================="
    list h fstat_basic fstat_applied if h != -1, sep(0)
    
    * Summary statistics
    sum fstat_basic if h != -1
    local min_f_basic = r(min)
    sum fstat_applied if h != -1
    local min_f_applied = r(min)
    
    di _n "Minimum F-stat (Basic): " %6.2f `min_f_basic'
    di "Minimum F-stat (Applied): " %6.2f `min_f_applied'
    di "==================================================="
    
    *--------------------------------------------------
    * PROFESSIONAL PLOT: PATENT RESPONSES (IV)
    *--------------------------------------------------

    twoway ///
        (rarea ub_applied_90 lb_applied_90 h, ///
            fcolor("68 105 176%20") lwidth(none)) ///
        (rarea ub_applied_68 lb_applied_68 h, ///
            fcolor("68 105 176%40") lwidth(none)) ///
        (line beta_applied h, ///
            lcolor("68 105 176") lwidth(0.6) lpattern(solid)) ///
        (rarea ub_basic_90 lb_basic_90 h, ///
            fcolor("34 139 34%20") lwidth(none)) ///
        (rarea ub_basic_68 lb_basic_68 h, ///
            fcolor("34 139 34%40") lwidth(none)) ///
        (line beta_basic h, ///
            lcolor("34 139 34") lwidth(0.6) lpattern(solid)) ///
        , ///
        yline(0, lcolor(black) lwidth(0.3)) ///
        xline(-1, lcolor(gs10) lwidth(0.25) lpattern(dash)) ///
        xlabel(-3(3)15, labsize(small) tlength(2)) ///
        ylabel(, labsize(small) angle(horizontal) format(%9.2f) nogrid) ///
        xtitle("Years from Shock", size(small) margin(small)) ///
        ytitle("Percentage Points", size(small) margin(small)) ///
        title("", size(medium) color(black)) ///
        legend(order(3 "Applied Research" 6 "Basic Research") ///
            position(6) rows(1) size(small) ///
            region(lcolor(none) fcolor(none)) ///
            symxsize(5) keygap(1) ring(0)) ///
        graphregion(color(white) margin(small)) ///
        plotregion(color(white) margin(small) lcolor(black) lwidth(0.3)) ///
        name(lp_patents_pro, replace)

    graph export "${graphs}/lp_patents_iv_nw.pdf", replace
    graph export "${graphs}/p_patents_iv_nw.png", replace width(2400)
}
