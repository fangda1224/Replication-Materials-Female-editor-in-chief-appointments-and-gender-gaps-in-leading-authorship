/*===========================================================================
  Female Editors-in-Chief and the Leading-Author Gender Gap
  STEP 2 — Heterogeneity analysis

  Input:  data/1-{first|last}-0.7CI-withnovelty.dta     (paper level)
          data/wgidataset_with_sourcedata-2025.xlsx     (World Bank WGI)
          data/OGHIST_2026_07_01.xlsx                   (World Bank income groups)
  Output: output/tables/{first|last}/                   (regression tables)
          output/figure_data/                           (data exported for figures)

  Required packages: reghdfe, ftools, estout

  Classification standards:
    1. Institution : leading author affiliated with a top-200 university
                     (ins_top).
    2. Journal     : "High H-index" = journal's average h-index is at or
                     above the median h-index within its own discipline
                     (category). A within-category median avoids
                     high-h-index disciplines (e.g. Life Sci.) dominating
                     the High H-index group. A scatter plot of journal
                     average gender gap against average h-index (with a
                     lowess smoother) is drawn first to check for a clear
                     slope-change point; absent one, the median is used.
    3. Country:
       3.1 HDI                     : UN standard fixed cutoffs
                                     Low <0.550 | Medium [0.550,0.700) |
                                     High [0.700,0.800) | Very High >=0.800
       3.2 Governance Effectiveness: World Bank Worldwide Governance
                                     Indicators (WGI), "ge" sheet, merged on
                                     economy code and year (country_code,
                                     Publication_Year). The governance score
                                     (0-100) is averaged within country
                                     across its sample years, then split into
                                     "Higher"/"Lower" effectiveness at the
                                     median across countries.
       3.3 GNI / income group      : World Bank historical income
                                     classification, merged on ISO3 country
                                     code (country_code).

  Sections:
    0.  Setup
    1.  Institution  (top-200 university)
    2.  Journal      (h-index, within-category median split)
    3.  Country      3.1 HDI | 3.2 Governance Effectiveness | 3.3 Income group
===========================================================================*/

clear all
set more off
set linesize 200

/*===========================================================================
  0.  SETUP
===========================================================================*/

* ── Paths and leading-author definition (normally set in 00_master.do) ─────
if "$root"   == "" global root "/path/to/20261118-Materials"
if "$author" == "" global author first      // "first" or "last"

global data    "$root/data"
global out     "$root/output/tables/$author"
global figdata "$root/output/figure_data"

cap mkdir "$root/output"
cap mkdir "$root/output/tables"
cap mkdir "$out"
cap mkdir "$figdata"

* ── Discipline names ────────────────────────────────────────────────────────
local cname1 "Arts & Hum."
local cname2 "Life Sci."
local cname3 "Physical Sci."
local cname4 "Social Sci."
local cname5 "Technology"

local field_mtitles `""Agri." "Arts/Hum." "Bio." "Chem." "Clin.Med." "CompSci" "Econ" "Eng." "Environ." "Geo." "History" "Lit." "Materials" "Math" "Multi." "Phil." "Physics" "Plant/Ani." "Psych." "SocSci" "Visual""'

global ctrl_jl "n_papers avg_num_authors log_jrn_avgcited log_jrn_totref log_jrn_refperdoc"


/*===========================================================================
  1.  INSTITUTION
  - subgroup: whether the leading author is from a top-200 university (ins_top)
===========================================================================*/

use "$data/1-${author}-0.7CI-withnovelty.dta", clear

drop if Publication_Year > 2022

foreach v of varlist female_author jrn_female_edirto jrn_female_edihas ///
    pap_author_num jrn_hindex jrn_sjr jrn_avgcited jrn_totref jrn_refperdoc {
    cap confirm numeric var `v'
    if _rc cap destring `v', replace
}
cap confirm numeric var Publication_Year
if _rc destring Publication_Year, replace

cap rename journal journal_id

gen novelty_inv = -Atyp_10pct_Z
egen novelty_std = std(novelty_inv)

gen log_jrn_avgcited  = log(1 + jrn_avgcited)
gen log_jrn_totref    = log(1 + jrn_totref)
gen log_jrn_refperdoc = log(1 + jrn_refperdoc)

gen one = 1
gen novel = (Atyp_10pct_Z < 0)

* ── Collapse to journal × year × ins_top ─────────────────────────────────────
collapse ///
    (mean)  prop_female_author  = female_author          ///
            jrn_female_edirto                            ///
            jrn_female_edihas                            ///
            jrn_hindex jrn_sjr jrn_avgcited              ///
            jrn_totref jrn_refperdoc                     ///
            avg_num_authors     = pap_author_num         ///
            avg_novelty_std     = novelty_std             ///
            avg_novel           = novel                   ///
    (sum)   n_papers            = one                    ///
    (first) field category                               ///
    , by(journal_id Publication_Year ins_top)

gen gender_gap   = (1 - prop_female_author) - prop_female_author
gen gender_gap_y = gender_gap * 100

replace avg_novel = avg_novel * 100

gen log_n_papers       = log(1 + n_papers)
gen log_jrn_avgcited   = log(1 + jrn_avgcited)
gen log_jrn_refperdoc  = log(1 + jrn_refperdoc)
gen log_jrn_totref     = log(1 + jrn_totref)

label var gender_gap_y         "Gender gap: M−F leading author (×100)"
label var prop_female_author   "Prop. female leading author"
label var jrn_female_edirto    "Female EIC ratio"
label var jrn_female_edihas    "Has female EIC (=1)"
label var n_papers             "Total papers"
label var log_n_papers         "ln(1+total papers)"
label var avg_num_authors      "Avg. authors per paper"
label var log_jrn_avgcited     "ln(1+journal avg. citations)"
label var log_jrn_totref       "ln(1+journal total refs)"
label var log_jrn_refperdoc    "ln(1+journal refs per paper)"
label var avg_novelty_std      "Avg. novelty index (std.)"
label var jrn_hindex           "Journal h-index"

preserve
	collapse (mean)gender_gap_y  (count)n = gender_gap_y  ,by(journal_id jrn_female_edihas ins_top)
	export excel using "$figdata/2b-gap-byinsrank-${author}.xls", replace firstrow(variables)
restore


* ── Treatment variables ──────────────────────────────────────────────────────
bysort journal_id: ///
    egen first_treat_yr = min(cond(jrn_female_edihas == 1, Publication_Year, .))

gen ever_treated = !missing(first_treat_yr)
gen post         = (Publication_Year >= first_treat_yr) if ever_treated == 1
replace post     = 0 if missing(post)
gen did_treat    = ever_treated * post

label var ever_treated  "Ever had female EIC"
label var post          "Post first female EIC year"
label var did_treat     "DiD: ever-treated × post"

* ── 1.1  By ins_top, controls + journal + year FE ────────────────────────────
est clear
forvalues i = 0/1 {
    capture noisily reghdfe gender_gap_y did_treat $ctrl_jl   ///
        if ins_top == `i',   ///
        absorb(journal_id Publication_Year) vce(cluster journal_id)
    if _rc == 0 {
        quietly summarize `e(depvar)' if e(sample)
        quietly estadd scalar Mean = r(mean)
        quietly estadd scalar SD   = r(sd)
        est store ins`i'
    }
    else di as error "Skipping ins_top = `i' (code = " _rc ")"
}

esttab ins*   ///
    using "$out/TM1_DiD_byins.csv", replace   ///
    label b(4) se(4) star(* 0.10 ** 0.05 *** 0.01)   ///
    stats(N r2_a Mean SD, fmt(%12.0f %9.3f %9.3f %9.3f)   ///
        labels("Obs." "Adj. R²" "Mean DV" "SD DV"))   ///
    compress nogap varwidth(22)

* ── 1.2  By discipline (5 categories) × ins_top, DiD, controls + journal + year FE ──
est clear
local allmodels ""
local alltitles ""

forvalues c = 1/5 {
    forvalues i = 0/1 {
        capture noisily reghdfe gender_gap_y did_treat $ctrl_jl   ///
            if ins_top == `i' & category == `c',   ///
            absorb(journal_id Publication_Year) vce(cluster journal_id)

        if _rc == 0 {
            quietly summarize `e(depvar)' if e(sample)
            quietly estadd scalar Mean = r(mean)
            quietly estadd scalar SD   = r(sd)

            est store cat`c'_g`i'
            local allmodels `"`allmodels' cat`c'_g`i'"'
            local alltitles `"`alltitles' "Cat`c' Ins`i'""'
        }
        else di as error "Skipping category `c', ins_top `i' (code = " _rc ")"
    }
}

esttab `allmodels'                                   ///
    using "$out/TM1_DiD_byins_cat5.csv", replace      ///
    mtitle(`alltitles')                               ///
    keep(did_treat $ctrl_jl) order(did_treat $ctrl_jl)     ///
    label b(4) se(4) star(* 0.10 ** 0.05 *** 0.01)   ///
    stats(N r2_a Mean SD, fmt(%12.0f %9.3f %9.3f %9.3f) ///
        labels("Obs." "Adj. R²" "Mean DV" "SD DV"))   ///
    compress nogap varwidth(22)

* ── 1.3  Event study by ins_top (parallel trends) ────────────────────────────
gen evt_time = Publication_Year - first_treat_yr if ever_treated == 1

gen evt_sample = ever_treated == 0 | ///
    (ever_treated == 1 & inrange(evt_time, -4, 7))

forvalues k = 4(-1)2 {
    gen pre`k' = ever_treated == 1 & evt_time == -`k'
    label var pre`k' "t = -`k'"
}
forvalues k = 0/7 {
    gen post`k' = ever_treated == 1 & evt_time == `k'
    label var post`k' "t = +`k'"
}

est clear
forvalues i = 0/1 {
    capture noisily reghdfe gender_gap_y                       ///
        pre4 pre3 pre2                                          ///
        post0 post1 post2 post3 post4 post5 post6 post7        ///
        $ctrl_jl                                                 ///
        if evt_sample == 1 & ins_top == `i',                    ///
        absorb(journal_id Publication_Year) vce(cluster journal_id)
    if _rc == 0 est store evt_ins`i'
    else di as error "Skipping event study for ins_top = `i' (code = " _rc ")"
}

esttab evt_ins*   ///
    using "$out/TM1_eventstudy_byins.csv", replace   ///
    keep(pre4 pre3 pre2 post0 post1 post2 post3 post4 post5 post6 post7)   ///
    order(pre4 pre3 pre2 post0 post1 post2 post3 post4 post5 post6 post7)   ///
    label b(6) ci(6) nostar noobs

drop evt_time evt_sample pre4 pre3 pre2 post0 post1 post2 post3 post4 post5 post6 post7


/*===========================================================================
  2.  JOURNAL — H-INDEX (within-category median split)
  - Step 1: average h-index per journal, across all its journal-years
  - Step 2: draw a scatter plot of journal avg. gender gap vs. avg. h-index
            (with a lowess smoother) to visually check for a clear point
            where the fit line's slope changes
  - Step 3: since no such clear cut point is visible, classify journals
            as "High H-index" if avg h-index is at or above the median
            avg h-index *within its own category*
            (discipline-specific median), else "Others"
  - Note: using a within-category median (rather than the pooled sample
          median) avoids over-representing high-h-index disciplines (e.g.
          Life Sci.) in the High H-index group relative to low-h-index
          disciplines (e.g. Arts & Hum., Social Sci.), so category is no
          longer confounded with h-index group here.
===========================================================================*/

use "$data/1-${author}-0.7CI-withnovelty.dta", clear

drop if Publication_Year > 2022

foreach v of varlist female_author jrn_female_edirto jrn_female_edihas ///
    pap_author_num jrn_hindex jrn_sjr jrn_avgcited jrn_totref jrn_refperdoc {
    cap confirm numeric var `v'
    if _rc cap destring `v', replace
}
cap confirm numeric var Publication_Year
if _rc destring Publication_Year, replace

cap rename journal journal_id

gen novelty_inv = -Atyp_10pct_Z
egen novelty_std = std(novelty_inv)

gen one = 1
gen novel = (Atyp_10pct_Z < 0)

* ── Collapse to journal × year ──────────────────────────────────────────────
collapse ///
    (mean)  prop_female_author  = female_author          ///
            jrn_female_edirto                            ///
            jrn_female_edihas                            ///
            jrn_hindex jrn_sjr jrn_avgcited              ///
            jrn_totref jrn_refperdoc                     ///
            avg_num_authors     = pap_author_num         ///
            avg_novelty_std     = novelty_std             ///
            avg_novel           = novel                   ///
    (sum)   n_papers            = one                    ///
    (first) field category                               ///
    , by(journal_id Publication_Year)

gen gender_gap   = (1 - prop_female_author) - prop_female_author
gen gender_gap_y = gender_gap * 100

replace avg_novel = avg_novel * 100

gen log_n_papers       = log(1 + n_papers)
gen log_jrn_avgcited   = log(1 + jrn_avgcited)
gen log_jrn_refperdoc  = log(1 + jrn_refperdoc)
gen log_jrn_totref     = log(1 + jrn_totref)

label var gender_gap_y         "Gender gap: M−F leading author (×100)"
label var prop_female_author   "Prop. female leading author"
label var jrn_female_edirto    "Female EIC ratio"
label var jrn_female_edihas    "Has female EIC (=1)"
label var n_papers             "Total papers"
label var log_n_papers         "ln(1+total papers)"
label var avg_num_authors      "Avg. authors per paper"
label var log_jrn_avgcited     "ln(1+journal avg. citations)"
label var log_jrn_totref       "ln(1+journal total refs)"
label var log_jrn_refperdoc    "ln(1+journal refs per paper)"
label var avg_novelty_std      "Avg. novelty index (std.)"
label var jrn_hindex           "Journal h-index"

* ── Journal-level avg h-index & avg gender gap, scatter + within-category median classification ──
preserve
    collapse (mean) avg_hindex = jrn_hindex avg_gender_gap_y = gender_gap_y ///
        (first) category, by(journal_id)

    * Scatter of journal-level gender gap vs. h-index with a lowess smoother
    twoway ///
        (scatter avg_gender_gap_y avg_hindex, mcolor(%30) msize(small)) ///
        (lowess avg_gender_gap_y avg_hindex, lcolor(red) lwidth(medthick)), ///
        xtitle("Journal avg. h-index") ///
        ytitle("Journal avg. gender gap (×100)") ///
        title("Gender Gap vs. Journal H-index") ///
        legend(off) name(hindex_scatter_${author}, replace)

    graph export "$figdata/1e-scatter-hindex-gap-${author}.png", replace width(1600)

    * classify by the median of avg h-index *within each category*, so
    * high-h-index disciplines (e.g. Life Sci.) no longer dominate the
    * High H-index group relative to low-h-index disciplines
    bysort category: egen hindex_median_cat = median(avg_hindex)

    gen jrn_hgroup = .
    replace jrn_hgroup = 1 if avg_hindex >= hindex_median_cat & !missing(avg_hindex)
    replace jrn_hgroup = 0 if avg_hindex <  hindex_median_cat & !missing(avg_hindex)

    label define hgroup_lab 0 "Others" 1 "High H-index (within category)", replace
    label values jrn_hgroup hgroup_lab

    * Report the within-category median cutoffs and group sizes
    di as text "Within-category median h-index cutoffs and journal counts:"
    tabstat avg_hindex, by(category) statistics(median n) columns(statistics) format(%9.2f)
    quietly count if jrn_hgroup == 1
    di as text "High H-index group (>= within-category median): N = " r(N) " of " _N " journals"

    keep journal_id jrn_hgroup
    tempfile hgroup
    save `hgroup'
restore

merge m:1 journal_id using `hgroup', nogen

* ─── Export data for graphing (before regression) ──────────────────────────
preserve
	collapse (mean) gender_gap_y (first) jrn_hgroup, by(journal_id jrn_female_edihas)
    export excel "$figdata/1e-gap-byhindex-${author}.xlsx", ///
        replace firstrow(variables)
restore

* ── Treatment variables ──────────────────────────────────────────────────────
bysort journal_id: ///
    egen first_treat_yr = min(cond(jrn_female_edihas == 1, Publication_Year, .))

gen ever_treated = !missing(first_treat_yr)
gen post         = (Publication_Year >= first_treat_yr) if ever_treated == 1
replace post     = 0 if missing(post)
gen did_treat    = ever_treated * post

label var ever_treated  "Ever had female EIC"
label var post          "Post first female EIC year"
label var did_treat     "DiD: ever-treated × post"

* ── 2.1  By jrn_hgroup, controls + journal + year FE ─────────────────────────
est clear
forvalues i = 0/1 {
    capture noisily reghdfe gender_gap_y did_treat $ctrl_jl   ///
        if jrn_hgroup == `i',   ///
        absorb(journal_id Publication_Year) vce(cluster journal_id)
    if _rc == 0 {
        quietly summarize `e(depvar)' if e(sample)
        quietly estadd scalar Mean = r(mean)
        quietly estadd scalar SD   = r(sd)
        est store hg`i'
    }
    else di as error "Skipping jrn_hgroup = `i' (code = " _rc ")"
}

esttab hg*   ///
    using "$out/TM2_DiD_byhindex.csv", replace   ///
    label b(4) se(4) star(* 0.10 ** 0.05 *** 0.01)   ///
    stats(N r2_a Mean SD, fmt(%12.0f %9.3f %9.3f %9.3f)   ///
        labels("Obs." "Adj. R²" "Mean DV" "SD DV"))   ///
    compress nogap varwidth(22)

* ── 2.2  By discipline (5 categories) × jrn_hgroup, DiD ──────────────────────
est clear
local allmodels ""
local alltitles ""

forvalues c = 1/5 {
    forvalues i = 0/1 {
        capture noisily reghdfe gender_gap_y did_treat $ctrl_jl   ///
            if jrn_hgroup == `i' & category == `c',   ///
            absorb(journal_id Publication_Year) vce(cluster journal_id)

        if _rc == 0 {
            quietly summarize `e(depvar)' if e(sample)
            quietly estadd scalar Mean = r(mean)
            quietly estadd scalar SD   = r(sd)

            est store cat`c'_g`i'
            local allmodels `"`allmodels' cat`c'_g`i'"'
            local alltitles `"`alltitles' "Cat`c' HG`i'""'
        }
        else di as error "Skipping category `c', jrn_hgroup `i' (code = " _rc ")"
    }
}

esttab `allmodels'                                   ///
    using "$out/TM2_DiD_byhindex_cat5.csv", replace   ///
    mtitle(`alltitles')                               ///
    keep(did_treat $ctrl_jl) order(did_treat $ctrl_jl)     ///
    label b(4) se(4) star(* 0.10 ** 0.05 *** 0.01)   ///
    stats(N r2_a Mean SD, fmt(%12.0f %9.3f %9.3f %9.3f) ///
        labels("Obs." "Adj. R²" "Mean DV" "SD DV"))   ///
    compress nogap varwidth(22)

* ── 2.3  Event study by jrn_hgroup (parallel trends) ─────────────────────────
gen evt_time = Publication_Year - first_treat_yr if ever_treated == 1

gen evt_sample = ever_treated == 0 | ///
    (ever_treated == 1 & inrange(evt_time, -4, 7))

forvalues k = 4(-1)2 {
    gen pre`k' = ever_treated == 1 & evt_time == -`k'
    label var pre`k' "t = -`k'"
}
forvalues k = 0/7 {
    gen post`k' = ever_treated == 1 & evt_time == `k'
    label var post`k' "t = +`k'"
}

est clear
forvalues i = 0/1 {
    capture noisily reghdfe gender_gap_y                       ///
        pre4 pre3 pre2                                          ///
        post0 post1 post2 post3 post4 post5 post6 post7        ///
        $ctrl_jl                                                 ///
        if evt_sample == 1 & jrn_hgroup == `i',                 ///
        absorb(journal_id Publication_Year) vce(cluster journal_id)
    if _rc == 0 est store evt_hg`i'
    else di as error "Skipping event study for jrn_hgroup = `i' (code = " _rc ")"
}

esttab evt_hg*   ///
    using "$out/TM2_eventstudy_byhindex.csv", replace   ///
    keep(pre4 pre3 pre2 post0 post1 post2 post3 post4 post5 post6 post7)   ///
    order(pre4 pre3 pre2 post0 post1 post2 post3 post4 post5 post6 post7)   ///
    label b(6) ci(6) nostar noobs

drop evt_time evt_sample pre4 pre3 pre2 post0 post1 post2 post3 post4 post5 post6 post7


/*===========================================================================
  3.  COUNTRY
  3.1 HDI (UN fixed cutoffs)
  3.2 Governance Effectiveness (World Bank WGI, median split)
  3.3 GNI / World Bank income group (merged by ISO3 country_code)
===========================================================================*/

use "$data/1-${author}-0.7CI-withnovelty.dta", clear

drop if Publication_Year > 2022

foreach v of varlist female_author jrn_female_edirto jrn_female_edihas ///
    pap_author_num jrn_hindex jrn_sjr jrn_avgcited jrn_totref jrn_refperdoc {
    cap confirm numeric var `v'
    if _rc cap destring `v', replace
}
cap confirm numeric var Publication_Year
if _rc destring Publication_Year, replace

cap rename journal journal_id

gen novelty_inv = -Atyp_10pct_Z
egen novelty_std = std(novelty_inv)

gen one = 1
gen novel = (Atyp_10pct_Z < 0)


* ── Figure data: country-level gender gap ───────────────────────────────────

preserve

collapse (mean) fem_y = female_author   ///
		(sum)  n_papers = one   ///
		,by(country_code)

gen gap = ((1-fem_y)-fem_y)*100

 export excel using "$figdata/2e-overall-gap-bycny-${author}.xlsx", ///
        replace firstrow(variables)

restore


preserve

collapse (mean) fem_y = female_author   ///
		(sum)  n_papers = one   ///
		,by(country_code jrn_female_edihas)

gen gap = ((1-fem_y)-fem_y)*100

 export excel using "$figdata/2e-byeic-gap-bycny-${author}.xlsx", ///
        replace firstrow(variables)

restore


* ── 3.1  HDI: fixed standard cutoffs on existing var ─────────────────────────

* HDI — UN standard
gen hdi_group = .
replace hdi_group = 1 if cny_hdi <  0.550                     & !missing(cny_hdi)
replace hdi_group = 2 if cny_hdi >= 0.550 & cny_hdi < 0.700    & !missing(cny_hdi)
replace hdi_group = 3 if cny_hdi >= 0.700 & cny_hdi < 0.800    & !missing(cny_hdi)
replace hdi_group = 4 if cny_hdi >= 0.800                      & !missing(cny_hdi)

label define hdi_group_lab 1 "Low HDI" 2 "Medium HDI" 3 "High HDI" 4 "Very High HDI", replace
label values hdi_group hdi_group_lab

* ── 3.2  Governance Effectiveness (World Bank WGI) — merge by economy code & year ──
* Source: data/wgidataset_with_sourcedata-2025.xlsx, sheet "ge"
*   col C = Economy (code), col F = Year, col M = Governance score (0-100)
preserve
    import excel "$data/wgidataset_with_sourcedata-2025.xlsx", sheet("ge") clear
    drop in 1
    keep if G == "ge"
    keep C F M
    rename C country_code
    rename F Publication_Year
    rename M ge_score
    destring Publication_Year ge_score, replace
    duplicates drop country_code Publication_Year, force
    tempfile wgi_ge
    save `wgi_ge'
restore

merge m:1 country_code Publication_Year using `wgi_ge', keep(master match) nogen

* Country-fixed classification: average each country's matched governance
* score across its sample years, then split countries into "Higher"/"Lower"
* effectiveness using the overall median across countries (mirrors the
* journal h-index approach: one value per unit, then median split of units).
preserve
    collapse (first) ge_score, by(country_code Publication_Year)
    collapse (mean) avg_ge_score = ge_score, by(country_code)

    quietly summarize avg_ge_score, detail
    local ge_median = r(p50)

    gen ge_group = .
    replace ge_group = 1 if avg_ge_score >= `ge_median' & !missing(avg_ge_score)
    replace ge_group = 0 if avg_ge_score <  `ge_median' & !missing(avg_ge_score)

    label define ge_group_lab 0 "Lower effectiveness" 1 "Higher effectiveness", replace
    label values ge_group ge_group_lab

    * Report the median cutoff and group size
    quietly count if ge_group == 1
    di as text "Higher effectiveness group (>= median): N countries = " r(N) ///
        " of " _N ", median avg_ge_score = " `ge_median'

    keep country_code ge_group
    tempfile gegroup
    save `gegroup'
restore

merge m:1 country_code using `gegroup', keep(master match) nogen


* ── 3.3  GNI / World Bank income group — merge by ISO3 country_code ─────────
preserve
    import excel "$data/OGHIST_2026_07_01.xlsx", firstrow clear
    rename ISOcode country_code
    rename income  wb_income
    keep country_code wb_income
    duplicates drop country_code, force
    tempfile wbincome
    save `wbincome'
restore

merge m:1 country_code using `wbincome', keep(master match) nogen

gen gni_group = .
replace gni_group = 1 if wb_income == "L"
replace gni_group = 2 if wb_income == "LM"
replace gni_group = 3 if wb_income == "UM"
replace gni_group = 4 if wb_income == "H"

label define gni_group_lab 1 "Low income" 2 "Lower-middle income" 3 "Upper-middle income" 4 "High income", replace
label values gni_group gni_group_lab

* ── Save paper-level tempfile (with all three groups attached) ──────────────
tempfile cny
save `cny'

* ── Summary statistics — paper level ─────────────────────────────────────────
estpost summarize Publication_Year pap_author_num female_author jrn_female_edihas cny_hdi ge_score gni_group

esttab using "$out/T2_summary_paper.csv", replace ///
    cells("count(fmt(%12.0f)) mean(fmt(%9.3f)) sd(fmt(%9.3f)) min(fmt(%9.3f)) max(fmt(%9.3f))") ///
    label noobs nomtitle nonumber ///
    collabels("N" "Mean" "SD" "Min" "Max")


/* ---------------------------------------------------------------------------
   3.1  HDI
--------------------------------------------------------------------------- */

* ─── Export country-level data for graphing (before regression) ────────────
use `cny', clear
preserve
    collapse (mean) prop_female_author = female_author   ///
             (sum)  n_papers = one                       ///
             (first) category                            ///
             , by(journal_id country_code jrn_female_edihas hdi_group)

    gen gender_gap   = (1 - prop_female_author) - prop_female_author
    gen gender_gap_y = gender_gap * 100

    drop if country_code == ""

    export excel country_code journal_id jrn_female_edihas gender_gap_y ///
        hdi_group category using "$figdata/1e-gap-bycnyhdi-${author}.xlsx", ///
        replace firstrow(variables)
restore

* ── Collapse to journal × year × hdi_group for regression ───────────────────
use `cny', clear
collapse ///
    (mean)  prop_female_author  = female_author          ///
            jrn_female_edirto                            ///
            jrn_female_edihas                            ///
            jrn_hindex jrn_sjr jrn_avgcited              ///
            jrn_totref jrn_refperdoc                     ///
            avg_num_authors     = pap_author_num         ///
            avg_novelty_std     = novelty_std             ///
            avg_novel           = novel                   ///
    (sum)   n_papers            = one                    ///
    (first) field category                               ///
    , by(journal_id Publication_Year hdi_group)

gen gender_gap   = (1 - prop_female_author) - prop_female_author
gen gender_gap_y = gender_gap * 100

replace avg_novel = avg_novel * 100

gen log_n_papers       = log(1 + n_papers)
gen log_jrn_avgcited   = log(1 + jrn_avgcited)
gen log_jrn_refperdoc  = log(1 + jrn_refperdoc)
gen log_jrn_totref     = log(1 + jrn_totref)

label var gender_gap_y         "Gender gap: M−F leading author (×100)"
label var jrn_female_edihas    "Has female EIC (=1)"
label var n_papers             "Total papers"

bysort journal_id: ///
    egen first_treat_yr = min(cond(jrn_female_edihas == 1, Publication_Year, .))

gen ever_treated = !missing(first_treat_yr)
gen post         = (Publication_Year >= first_treat_yr) if ever_treated == 1
replace post     = 0 if missing(post)
gen did_treat    = ever_treated * post

* ── 3.1.1  By hdi_group, controls + journal + year FE ────────────────────────
est clear
forvalues i = 1/4 {
    capture noisily reghdfe gender_gap_y did_treat $ctrl_jl   ///
        if hdi_group == `i',   ///
        absorb(journal_id Publication_Year) vce(cluster journal_id)
    if _rc == 0 {
        quietly summarize `e(depvar)' if e(sample)
        quietly estadd scalar Mean = r(mean)
        quietly estadd scalar SD   = r(sd)
        est store hdi`i'
    }
    else di as error "Skipping hdi_group = `i' (code = " _rc ")"
}

esttab hdi*   ///
    using "$out/TM3_DiD_byhdi.csv", replace     ///
    label b(4) se(4) star(* 0.10 ** 0.05 *** 0.01)   ///
    stats(N r2_a Mean SD, fmt(%12.0f %9.3f %9.3f %9.3f)   ///
        labels("Obs." "Adj. R²" "Mean DV" "SD DV"))   ///
    compress nogap varwidth(22)

* ── 3.1.2  By discipline (5 categories) × hdi_group, DiD ─────────────────────
est clear
local allmodels ""
local alltitles ""

forvalues c = 1/5 {
    forvalues i = 1/4 {
        capture noisily reghdfe gender_gap_y did_treat $ctrl_jl   ///
            if hdi_group == `i' & category == `c',   ///
            absorb(journal_id Publication_Year) vce(cluster journal_id)

        if _rc == 0 {
            quietly summarize `e(depvar)' if e(sample)
            quietly estadd scalar Mean = r(mean)
            quietly estadd scalar SD   = r(sd)

            est store cat`c'_g`i'
            local allmodels `"`allmodels' cat`c'_g`i'"'
            local alltitles `"`alltitles' "Cat`c' HDI`i'""'
        }
        else di as error "Skipping category `c', hdi_group `i' (code = " _rc ")"
    }
}

esttab `allmodels'                                   ///
    using "$out/TM3_DiD_byhdi_cat5.csv", replace      ///
    mtitle(`alltitles')                               ///
    keep(did_treat $ctrl_jl) order(did_treat $ctrl_jl)     ///
    label b(4) se(4) star(* 0.10 ** 0.05 *** 0.01)   ///
    stats(N r2_a Mean SD, fmt(%12.0f %9.3f %9.3f %9.3f) ///
        labels("Obs." "Adj. R²" "Mean DV" "SD DV"))   ///
    compress nogap varwidth(22)

* ── 3.1.3  Event study by hdi_group (parallel trends) ────────────────────────
gen evt_time = Publication_Year - first_treat_yr if ever_treated == 1

gen evt_sample = ever_treated == 0 | ///
    (ever_treated == 1 & inrange(evt_time, -4, 7))

forvalues k = 4(-1)2 {
    gen pre`k' = ever_treated == 1 & evt_time == -`k'
    label var pre`k' "t = -`k'"
}
forvalues k = 0/7 {
    gen post`k' = ever_treated == 1 & evt_time == `k'
    label var post`k' "t = +`k'"
}

est clear
forvalues i = 1/4 {
    capture noisily reghdfe gender_gap_y                       ///
        pre4 pre3 pre2                                          ///
        post0 post1 post2 post3 post4 post5 post6 post7        ///
        $ctrl_jl                                                 ///
        if evt_sample == 1 & hdi_group == `i',                  ///
        absorb(journal_id Publication_Year) vce(cluster journal_id)
    if _rc == 0 est store evt_hdi`i'
    else di as error "Skipping event study for hdi_group = `i' (code = " _rc ")"
}

esttab evt_hdi*   ///
    using "$out/TM3_eventstudy_byhdi.csv", replace   ///
    keep(pre4 pre3 pre2 post0 post1 post2 post3 post4 post5 post6 post7)   ///
    order(pre4 pre3 pre2 post0 post1 post2 post3 post4 post5 post6 post7)   ///
    label b(6) ci(6) nostar noobs

drop evt_time evt_sample pre4 pre3 pre2 post0 post1 post2 post3 post4 post5 post6 post7


/* ---------------------------------------------------------------------------
   3.2  GOVERNANCE EFFECTIVENESS (World Bank WGI)
--------------------------------------------------------------------------- */

* ─── Export country-level data for graphing (before regression) ────────────
use `cny', clear
preserve
    collapse (mean) prop_female_author = female_author   ///
             (sum)  n_papers = one                       ///
             (first) category                            ///
             , by(journal_id country_code jrn_female_edihas ge_group)

    gen gender_gap   = (1 - prop_female_author) - prop_female_author
    gen gender_gap_y = gender_gap * 100

    drop if country_code == ""

    export excel country_code journal_id jrn_female_edihas gender_gap_y ///
        ge_group category using "$figdata/1e-gap-bycnyge-${author}.xlsx", ///
        replace firstrow(variables)
restore

* ── Collapse to journal × year × ge_group for regression ────────────────────
use `cny', clear


collapse ///
    (mean)  prop_female_author  = female_author          ///
            jrn_female_edirto                            ///
            jrn_female_edihas                            ///
            jrn_hindex jrn_sjr jrn_avgcited              ///
            jrn_totref jrn_refperdoc                     ///
            avg_num_authors     = pap_author_num         ///
            avg_novelty_std     = novelty_std             ///
            avg_novel           = novel                   ///
    (sum)   n_papers            = one                    ///
    (first) field category                               ///
    , by(journal_id Publication_Year ge_group)

gen gender_gap   = (1 - prop_female_author) - prop_female_author
gen gender_gap_y = gender_gap * 100

replace avg_novel = avg_novel * 100

gen log_n_papers       = log(1 + n_papers)
gen log_jrn_avgcited   = log(1 + jrn_avgcited)
gen log_jrn_refperdoc  = log(1 + jrn_refperdoc)
gen log_jrn_totref     = log(1 + jrn_totref)

label var gender_gap_y         "Gender gap: M−F leading author (×100)"
label var jrn_female_edihas    "Has female EIC (=1)"
label var n_papers             "Total papers"

bysort journal_id: ///
    egen first_treat_yr = min(cond(jrn_female_edihas == 1, Publication_Year, .))

gen ever_treated = !missing(first_treat_yr)
gen post         = (Publication_Year >= first_treat_yr) if ever_treated == 1
replace post     = 0 if missing(post)
gen did_treat    = ever_treated * post

* ── 3.2.1  By ge_group, controls + journal + year FE ─────────────────────────
est clear
forvalues i = 0/1 {
    capture noisily reghdfe gender_gap_y did_treat $ctrl_jl   ///
        if ge_group == `i',   ///
        absorb(journal_id Publication_Year) vce(cluster journal_id)
    if _rc == 0 {
        quietly summarize `e(depvar)' if e(sample)
        quietly estadd scalar Mean = r(mean)
        quietly estadd scalar SD   = r(sd)
        est store ge`i'
    }
    else di as error "Skipping ge_group = `i' (code = " _rc ")"
}

esttab ge*   ///
    using "$out/TM3_DiD_byge.csv", replace   ///
    label b(4) se(4) star(* 0.10 ** 0.05 *** 0.01)   ///
    stats(N r2_a Mean SD, fmt(%12.0f %9.3f %9.3f %9.3f)   ///
        labels("Obs." "Adj. R²" "Mean DV" "SD DV"))   ///
    compress nogap varwidth(22)

* ── 3.2.2  By discipline (5 categories) × ge_group, DiD ───────────────────────
est clear
local allmodels ""
local alltitles ""

forvalues c = 1/5 {
    forvalues i = 0/1 {
        capture noisily reghdfe gender_gap_y did_treat $ctrl_jl   ///
            if ge_group == `i' & category == `c',   ///
            absorb(journal_id Publication_Year) vce(cluster journal_id)

        if _rc == 0 {
            quietly summarize `e(depvar)' if e(sample)
            quietly estadd scalar Mean = r(mean)
            quietly estadd scalar SD   = r(sd)

            est store cat`c'_g`i'
            local allmodels `"`allmodels' cat`c'_g`i'"'
            local alltitles `"`alltitles' "Cat`c' GE`i'""'
        }
        else di as error "Skipping category `c', ge_group `i' (code = " _rc ")"
    }
}

esttab `allmodels'                                   ///
    using "$out/TM3_DiD_byge_cat5.csv", replace       ///
    mtitle(`alltitles')                               ///
    keep(did_treat $ctrl_jl) order(did_treat $ctrl_jl)     ///
    label b(4) se(4) star(* 0.10 ** 0.05 *** 0.01)   ///
    stats(N r2_a Mean SD, fmt(%12.0f %9.3f %9.3f %9.3f) ///
        labels("Obs." "Adj. R²" "Mean DV" "SD DV"))   ///
    compress nogap varwidth(22)

* ── 3.2.3  Event study by ge_group (parallel trends) ──────────────────────────
gen evt_time = Publication_Year - first_treat_yr if ever_treated == 1

gen evt_sample = ever_treated == 0 | ///
    (ever_treated == 1 & inrange(evt_time, -4, 7))

forvalues k = 4(-1)2 {
    gen pre`k' = ever_treated == 1 & evt_time == -`k'
    label var pre`k' "t = -`k'"
}
forvalues k = 0/7 {
    gen post`k' = ever_treated == 1 & evt_time == `k'
    label var post`k' "t = +`k'"
}

est clear
forvalues i = 0/1 {
    capture noisily reghdfe gender_gap_y                       ///
        pre4 pre3 pre2                                          ///
        post0 post1 post2 post3 post4 post5 post6 post7        ///
        $ctrl_jl                                                 ///
        if evt_sample == 1 & ge_group == `i',                   ///
        absorb(journal_id Publication_Year) vce(cluster journal_id)
    if _rc == 0 est store evt_ge`i'
    else di as error "Skipping event study for ge_group = `i' (code = " _rc ")"
}

esttab evt_ge*   ///
    using "$out/TM3_eventstudy_byge.csv", replace   ///
    keep(pre4 pre3 pre2 post0 post1 post2 post3 post4 post5 post6 post7)   ///
    order(pre4 pre3 pre2 post0 post1 post2 post3 post4 post5 post6 post7)   ///
    label b(6) ci(6) nostar noobs

drop evt_time evt_sample pre4 pre3 pre2 post0 post1 post2 post3 post4 post5 post6 post7


/* ---------------------------------------------------------------------------
   3.3  GNI / WORLD BANK INCOME GROUP
--------------------------------------------------------------------------- */

* ─── Export country-level data for graphing (before regression) ────────────
use `cny', clear
preserve
    collapse (mean) prop_female_author = female_author   ///
             (sum)  n_papers = one                       ///
             (first) category                            ///
             , by(journal_id country_code jrn_female_edihas gni_group)

    gen gender_gap   = (1 - prop_female_author) - prop_female_author
    gen gender_gap_y = gender_gap * 100

    drop if country_code == ""

    export excel country_code journal_id jrn_female_edihas gender_gap_y ///
        gni_group category using "$figdata/1e-gap-bycnygni-${author}.xlsx", ///
        replace firstrow(variables)
restore

* ── Collapse to journal × year × gni_group for regression ───────────────────
use `cny', clear
collapse ///
    (mean)  prop_female_author  = female_author          ///
            jrn_female_edirto                            ///
            jrn_female_edihas                            ///
            jrn_hindex jrn_sjr jrn_avgcited              ///
            jrn_totref jrn_refperdoc                     ///
            avg_num_authors     = pap_author_num         ///
            avg_novelty_std     = novelty_std             ///
            avg_novel           = novel                   ///
    (sum)   n_papers            = one                    ///
    (first) field category                               ///
    , by(journal_id Publication_Year gni_group)

gen gender_gap   = (1 - prop_female_author) - prop_female_author
gen gender_gap_y = gender_gap * 100

replace avg_novel = avg_novel * 100

gen log_n_papers       = log(1 + n_papers)
gen log_jrn_avgcited   = log(1 + jrn_avgcited)
gen log_jrn_refperdoc  = log(1 + jrn_refperdoc)
gen log_jrn_totref     = log(1 + jrn_totref)

label var gender_gap_y         "Gender gap: M−F leading author (×100)"
label var jrn_female_edihas    "Has female EIC (=1)"
label var n_papers             "Total papers"

bysort journal_id: ///
    egen first_treat_yr = min(cond(jrn_female_edihas == 1, Publication_Year, .))

gen ever_treated = !missing(first_treat_yr)
gen post         = (Publication_Year >= first_treat_yr) if ever_treated == 1
replace post     = 0 if missing(post)
gen did_treat    = ever_treated * post

* ── 3.3.1  By gni_group, controls + journal + year FE ────────────────────────
est clear
forvalues i = 1/4 {
    capture noisily reghdfe gender_gap_y did_treat $ctrl_jl   ///
        if gni_group == `i',   ///
        absorb(journal_id Publication_Year) vce(cluster journal_id)
    if _rc == 0 {
        quietly summarize `e(depvar)' if e(sample)
        quietly estadd scalar Mean = r(mean)
        quietly estadd scalar SD   = r(sd)
        est store gni`i'
    }
    else di as error "Skipping gni_group = `i' (code = " _rc ")"
}

esttab gni*   ///
    using "$out/TM3_DiD_bygni.csv", replace   ///
    label b(4) se(4) star(* 0.10 ** 0.05 *** 0.01)   ///
    stats(N r2_a Mean SD, fmt(%12.0f %9.3f %9.3f %9.3f)   ///
        labels("Obs." "Adj. R²" "Mean DV" "SD DV"))   ///
    compress nogap varwidth(22)

* ── 3.3.2  By discipline (5 categories) × gni_group, DiD ──────────────────────
est clear
local allmodels ""
local alltitles ""

forvalues c = 1/5 {
    forvalues i = 1/4 {
        capture noisily reghdfe gender_gap_y did_treat $ctrl_jl   ///
            if gni_group == `i' & category == `c',   ///
            absorb(journal_id Publication_Year) vce(cluster journal_id)

        if _rc == 0 {
            quietly summarize `e(depvar)' if e(sample)
            quietly estadd scalar Mean = r(mean)
            quietly estadd scalar SD   = r(sd)

            est store cat`c'_g`i'
            local allmodels `"`allmodels' cat`c'_g`i'"'
            local alltitles `"`alltitles' "Cat`c' GNI`i'""'
        }
        else di as error "Skipping category `c', gni_group `i' (code = " _rc ")"
    }
}

esttab `allmodels'                                   ///
    using "$out/TM3_DiD_bygni_cat5.csv", replace      ///
    mtitle(`alltitles')                               ///
    keep(did_treat $ctrl_jl) order(did_treat $ctrl_jl)     ///
    label b(4) se(4) star(* 0.10 ** 0.05 *** 0.01)   ///
    stats(N r2_a Mean SD, fmt(%12.0f %9.3f %9.3f %9.3f) ///
        labels("Obs." "Adj. R²" "Mean DV" "SD DV"))   ///
    compress nogap varwidth(22)

* ── 3.3.3  Event study by gni_group (parallel trends) ────────────────────────
gen evt_time = Publication_Year - first_treat_yr if ever_treated == 1

gen evt_sample = ever_treated == 0 | ///
    (ever_treated == 1 & inrange(evt_time, -4, 7))

forvalues k = 4(-1)2 {
    gen pre`k' = ever_treated == 1 & evt_time == -`k'
    label var pre`k' "t = -`k'"
}
forvalues k = 0/7 {
    gen post`k' = ever_treated == 1 & evt_time == `k'
    label var post`k' "t = +`k'"
}

est clear
forvalues i = 1/4 {
    capture noisily reghdfe gender_gap_y                       ///
        pre4 pre3 pre2                                          ///
        post0 post1 post2 post3 post4 post5 post6 post7        ///
        $ctrl_jl                                                 ///
        if evt_sample == 1 & gni_group == `i',                  ///
        absorb(journal_id Publication_Year) vce(cluster journal_id)
    if _rc == 0 est store evt_gni`i'
    else di as error "Skipping event study for gni_group = `i' (code = " _rc ")"
}

esttab evt_gni*   ///
    using "$out/TM3_eventstudy_bygni.csv", replace   ///
    keep(pre4 pre3 pre2 post0 post1 post2 post3 post4 post5 post6 post7)   ///
    order(pre4 pre3 pre2 post0 post1 post2 post3 post4 post5 post6 post7)   ///
    label b(6) ci(6) nostar noobs

drop evt_time evt_sample pre4 pre3 pre2 post0 post1 post2 post3 post4 post5 post6 post7

di as result "=== Step 2 done. Output saved to: $out ==="
