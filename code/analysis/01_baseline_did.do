/*===========================================================================
  Female Editors-in-Chief and the Leading-Author Gender Gap
  STEP 1 — Baseline analysis

  Input:  data/1-{first|last}-0.7CI-withnovelty.dta   (paper level)
  Output: output/tables/{first|last}/                 (regression tables, figures)
          output/figure_data/                         (data exported for figures)

  Required packages: reghdfe, ftools, estout, did_multiplegt_dyn

  Sections:
    0.  Setup
    1.  Load paper-level data and collapse to journal × year
    2.  Descriptive statistics and figure data
    3.  Difference-in-differences (TWFE)
          3.1 Main DiD
          3.2 DiD by discipline (5 categories)
          3.3 DiD by field (21 fields)
          3.4 Event study (parallel trends) + figure
          3.5 Event study by discipline
    4.  Heterogeneity-robust DiD (did_multiplegt_dyn)
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

/*===========================================================================
  1.  LOAD PAPER-LEVEL DATA AND COLLAPSE TO JOURNAL × YEAR
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

* ── Collapse to journal × year ──────────────────────────────────────────────
collapse ///
    (mean)  prop_female_author  = female_author          ///
            jrn_female_edirto                            ///
            jrn_female_edihas                            ///
            jrn_hindex jrn_sjr jrn_avgcited              ///
            jrn_totref jrn_refperdoc                     ///
            avg_num_authors     = pap_author_num         ///
            avg_novelty_std     = novelty_std            ///
            avg_novel           = novel                  ///
            avg_top_inst        = ins_top                ///
    (sum)   n_papers            = one                    ///
    (first) field category                               ///
    , by(journal_id Publication_Year)

* ── Post-collapse variable generation ───────────────────────────────────────
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

global ctrl_jl "n_papers avg_num_authors log_jrn_avgcited log_jrn_totref log_jrn_refperdoc"

/*===========================================================================
  2.  DESCRIPTIVE STATISTICS AND FIGURE DATA
===========================================================================*/

* ── Summary statistics — journal-year level ─────────────────────────────────
estpost summarize gender_gap_y jrn_female_edihas jrn_female_edirto ///
    n_papers avg_num_authors log_jrn_avgcited log_jrn_totref log_jrn_refperdoc jrn_sjr ///
    avg_novelty_std avg_novel

esttab using "$out/T0_summary_jy.csv", replace ///
    cells("count(fmt(%12.0f)) mean(fmt(%9.3f)) sd(fmt(%9.3f)) min(fmt(%9.3f)) max(fmt(%9.3f))") ///
    label noobs nomtitle nonumber ///
    collabels("N" "Mean" "SD" "Min" "Max")

* ── Declare panel ───────────────────────────────────────────────────────────
sort journal_id Publication_Year
xtset journal_id Publication_Year

* ── Save journal-year tempfile ──────────────────────────────────────────────
tempfile jy
save `jy'

* ── Mean values reported in the text ────────────────────────────────────────
mean gender_gap_y
mean gender_gap_y, over(category)

preserve
    collapse (mean) prop_female_author (first) category, by(journal_id)
    export excel using "$figdata/1-scatter-${author}.xls", firstrow(variables) replace
restore

* ── Time trend: gender gap ──────────────────────────────────────────────────
preserve
    gen n_journals = 1
    collapse (mean) gender_gap_y (semean) se_gap = gender_gap_y (sum) n_journals, by(Publication_Year)
    export excel "$figdata/1a-timetrend-${author}.xlsx", replace firstrow(variables)
restore

* ── Time trend: share of journals with a female EIC ────────────────────────
preserve
    gen n_journals = 1
    collapse (mean) jrn_female_edihas (semean) se_eic = jrn_female_edihas (sum) n_journals, by(Publication_Year)
    export excel "$figdata/1a-timetrend-eic.xlsx", replace firstrow(variables)
restore

* ── Time trend by discipline: gender gap ────────────────────────────────────
preserve
    gen n_journals = 1
    collapse (mean) gender_gap_y (semean) se_gap = gender_gap_y (sum) n_journals, by(Publication_Year category)
    export excel "$figdata/1a-timetrend-discipline-${author}.xlsx", replace firstrow(variables)
restore

* ── Time trend by discipline: female EIC ────────────────────────────────────
preserve
    gen n_journals = 1
    collapse (mean) jrn_female_edihas (semean) se_eic = jrn_female_edihas (sum) n_journals, by(Publication_Year category)
    export excel "$figdata/1a-timetrend-discipline-eic.xlsx", replace firstrow(variables)
restore

* ── Gender gap by female-EIC status, journal level ──────────────────────────
preserve
    collapse (mean) gender_gap_y (first) category, by(jrn_female_edihas journal_id)
    export excel using "$figdata/1g-binary-scatter-bydiscipline-${author}.xls", firstrow(variables) replace
restore

* ── Share of journals that ever had a female EIC: overall ──────────────────
preserve
    keep journal_id category jrn_female_edihas Publication_Year
    duplicates drop
    collapse (max) jrn_female_edihas, by(journal_id)
    mean jrn_female_edihas
restore

* ── Share of journals that ever had a female EIC: by discipline ────────────
preserve
    keep journal_id category jrn_female_edihas Publication_Year
    duplicates drop
    collapse (max) jrn_female_edihas, by(journal_id category)
    forvalues i = 1/5 {
        mean jrn_female_edihas if category == `i'
    }
restore

/*===========================================================================
  3.  DIFFERENCE-IN-DIFFERENCES
      Treatment: first year a journal has jrn_female_edihas == 1
      Assumption: once a female EIC appears, treatment is permanent
===========================================================================*/

use `jy', clear
di as txt "=== Section 3: DiD ==="

* ── Construct treatment variables ──────────────────────────────────────────
bysort journal_id: ///
    egen first_treat_yr = min(cond(jrn_female_edihas == 1, Publication_Year, .))

gen ever_treated = !missing(first_treat_yr)
gen post         = (Publication_Year >= first_treat_yr) if ever_treated == 1
replace post     = 0 if missing(post)
gen did_treat    = ever_treated * post

label var ever_treated  "Ever had female EIC"
label var post          "Post first female EIC year"
label var did_treat     "DiD: ever-treated × post"

* ── 3.1  TWFE DiD models ───────────────────────────────────────────────────

* (i) Baseline
reghdfe gender_gap_y did_treat, ///
    absorb(journal_id Publication_Year) vce(cluster journal_id)
quietly summarize `e(depvar)' if e(sample)
quietly estadd scalar Mean   = r(mean)
quietly estadd scalar SD     = r(sd)
quietly estadd local  fe_disc ""
est store cdid1

* (ii) With controls
reghdfe gender_gap_y did_treat $ctrl_jl, ///
    absorb(journal_id Publication_Year) vce(cluster journal_id)
quietly summarize `e(depvar)' if e(sample)
quietly estadd scalar Mean   = r(mean)
quietly estadd scalar SD     = r(sd)
quietly estadd local  fe_disc ""
est store cdid2

* (iii) With controls + discipline-by-year FE
reghdfe gender_gap_y did_treat $ctrl_jl, ///
    absorb(journal_id i.category#i.Publication_Year) vce(cluster journal_id)
quietly summarize `e(depvar)' if e(sample)
quietly estadd scalar Mean   = r(mean)
quietly estadd scalar SD     = r(sd)
quietly estadd local  fe_disc "Category × Year"
est store cdid3

* (iv) With controls + field-by-year FE
reghdfe gender_gap_y did_treat $ctrl_jl, ///
    absorb(journal_id i.field#i.Publication_Year) vce(cluster journal_id)
quietly summarize `e(depvar)' if e(sample)
quietly estadd scalar Mean   = r(mean)
quietly estadd scalar SD     = r(sd)
quietly estadd local  fe_disc "Field × Year"
est store cdid4

esttab cdid1 cdid2 cdid3 cdid4 using "$out/TC1_DiD_main.csv", replace ///
    mtitle("Baseline" "Controls" "Cat.×Yr" "Fld.×Yr") ///
    keep(did_treat $ctrl_jl) order(did_treat $ctrl_jl) ///
    label b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) ///
    stats(N r2_a Mean SD fe_disc, fmt(%12.0f %9.3f %9.3f %9.3f) ///
        labels("Obs." "Adj. R²" "Mean DV" "SD DV" "Discipline trend FE")) ///
    compress nogap varwidth(22)

estimates clear

* ── 3.2  DiD by discipline (5 categories) ──────────────────────────────────
di as txt "--- 3.2 DiD by discipline ---"

forvalues cat = 1/5 {
    capture noisily reghdfe gender_gap_y did_treat $ctrl_jl ///
        if category == `cat', ///
        absorb(journal_id Publication_Year) vce(cluster journal_id)
    if _rc == 0 {
        quietly summarize `e(depvar)' if e(sample)
        quietly estadd scalar Mean = r(mean)
        quietly estadd scalar SD   = r(sd)
        est store did_cat`cat'
    }
    else di as error "Skipping category `cat' (code = " _rc ")"
}

esttab did_cat1 did_cat2 did_cat3 did_cat4 did_cat5 ///
    using "$out/TC1b_DiD_cat.csv", replace ///
    mtitle("`cname1'" "`cname2'" "`cname3'" "`cname4'" "`cname5'") ///
    keep(did_treat $ctrl_jl) order(did_treat $ctrl_jl) ///
    label b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) ///
    stats(N r2_a Mean SD, fmt(%12.0f %9.3f %9.3f %9.3f) ///
        labels("Obs." "Adj. R²" "Mean DV" "SD DV")) ///
    compress nogap varwidth(22)

estimates clear

* ── 3.3  DiD by field (21 fields) ──────────────────────────────────────────
di as txt "--- 3.3 DiD by field ---"

forvalues f = 1/21 {
    capture noisily reghdfe gender_gap_y did_treat $ctrl_jl if field == `f', ///
        absorb(journal_id Publication_Year) vce(cluster journal_id)
    if _rc == 0 {
        quietly summarize `e(depvar)' if e(sample)
        quietly estadd scalar Mean  = r(mean)
        quietly estadd scalar SD    = r(sd)
        quietly estadd local  field "`f'"
        est store did_fld`f'
    }
    else di as error "Skipping field `f' (code = " _rc ")"
}

esttab did_fld* using "$out/TC1c_DiD_fld.csv", replace ///
    mtitle(`field_mtitles') ///
    keep(did_treat) ///
    label b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) ///
    stats(N r2_a Mean SD field, fmt(%12.0f %9.3f %9.3f %9.3f) ///
        labels("Obs." "Adj. R²" "Mean DV" "SD DV" "Field")) ///
    compress nogap

estimates clear

* ── 3.4  Event study (parallel trends) ─────────────────────────────────────
di as txt "--- 3.4 Event study ---"

* Event time for eventually treated journals
gen evt_time = Publication_Year - first_treat_yr if ever_treated == 1

* Keep (1) all never-treated observations and
*      (2) treated observations with -4 <= event time <= 7
gen evt_sample = ever_treated == 0 | ///
    (ever_treated == 1 & inrange(evt_time, -4, 7))

* Pre-treatment indicators (t = -1 is the omitted reference period)
forvalues k = 4(-1)2 {
    gen pre`k' = ever_treated == 1 & evt_time == -`k'
    label var pre`k' "t = -`k'"
}

* Treatment and post-treatment indicators
forvalues k = 0/7 {
    gen post`k' = ever_treated == 1 & evt_time == `k'
    label var post`k' "t = +`k'"
}

eststo evtstudy: reghdfe gender_gap_y ///
    pre4 pre3 pre2 ///
    post0 post1 post2 post3 post4 post5 post6 post7 ///
    $ctrl_jl ///
    if evt_sample == 1, ///
    absorb(journal_id Publication_Year) ///
    vce(cluster journal_id)

esttab evtstudy using "$out/TC2_eventstudy_coef.csv", replace ///
    keep(pre4 pre3 pre2 ///
         post0 post1 post2 post3 post4 post5 post6 post7) ///
    b(6) ci(6) nostar noobs

* ── Event-study plot ────────────────────────────────────────────────────────
matrix B = e(b)
matrix V = e(V)
local evtvars "pre4 pre3 pre2 post0 post1 post2 post3 post4 post5 post6 post7"
local n_evt : word count `evtvars'

preserve
    clear
    set obs `= `n_evt' + 1'

    gen t    = .
    gen coef = .
    gen lo   = .
    gen hi   = .

    * Baseline: t = -1, coef = 0
    replace t    = -1 in 1
    replace coef = 0  in 1
    replace lo   = 0  in 1
    replace hi   = 0  in 1

    local tvals -4 -3 -2 0 1 2 3 4 5 6 7
    local row = 2
    foreach tv of local tvals {
        local vname = cond(`tv' < 0, "pre`=abs(`tv')'", "post`tv'")
        local col   = colnumb(B, "`vname'")
        replace t    = `tv'                                       in `row'
        replace coef = B[1, `col']                                in `row'
        replace lo   = B[1, `col'] - 1.96 * sqrt(V[`col', `col']) in `row'
        replace hi   = B[1, `col'] + 1.96 * sqrt(V[`col', `col']) in `row'
        local ++row
    }
    sort t

    twoway ///
        (rcap    lo hi t, lcolor(gs8) lwidth(thin)) ///
        (scatter coef t,  mcolor(navy) msymbol(circle) msize(medsmall)) ///
        (line    coef t,  lcolor(navy) lwidth(thin) lpattern(solid)) ///
        , ///
        yline(0, lcolor(red) lpattern(dash)) ///
        xline(-0.5, lcolor(gs10) lpattern(dash)) ///
        xlabel(-4(1)7) ///
        xtitle("Years relative to first female EIC appointment") ///
        ytitle("Coefficient (gender gap, ×100)") ///
        title("Event Study: Effect of Female EIC ($author author)", size(medlarge)) ///
        subtitle("Baseline: t = {&minus}1 | 95% CI shown", size(small)) ///
        legend(off) scheme(s2color)
    graph export "$out/FC1_eventstudy.png", replace width(1800)
restore

eststo clear

* ── 3.5  Event study by discipline (coefficients only) ─────────────────────
di as txt "--- 3.5 Event study by discipline ---"

est clear
forvalues c = 1/5 {
    capture noisily reghdfe gender_gap_y ///
        pre4 pre3 pre2 ///
        post0 post1 post2 post3 post4 post5 post6 post7 ///
        $ctrl_jl ///
        if evt_sample == 1 & category == `c', ///
        absorb(journal_id Publication_Year) ///
        vce(cluster journal_id)
    if _rc == 0 est store evt_cat`c'
    else di as error "Skipping event study for category `c' (code = " _rc ")"
}

esttab evt_cat1 evt_cat2 evt_cat3 evt_cat4 evt_cat5 ///
    using "$out/TC3_eventstudy_discipline_coef.csv", replace ///
    mtitle("`cname1'" "`cname2'" "`cname3'" "`cname4'" "`cname5'") ///
    keep(pre4 pre3 pre2 ///
         post0 post1 post2 post3 post4 post5 post6 post7) ///
    order(pre4 pre3 pre2 ///
          post0 post1 post2 post3 post4 post5 post6 post7) ///
    b(6) ci(6) nostar noobs

est clear
drop pre* post* evt_time evt_sample

/*===========================================================================
  4.  HETEROGENEITY-ROBUST DiD (did_multiplegt_dyn)
      Dynamic effects for switchers-in and switchers-out
===========================================================================*/

di as txt "=== Section 4: did_multiplegt_dyn ==="

* ── 4.1  Switchers in (journals that appoint a female EIC) ──────────────────
did_multiplegt_dyn gender_gap_y journal_id Publication_Year jrn_female_edihas, ///
    effects(10) placebo(6) cluster(journal_id) ///
    switchers(in) date_first_switch(first_treat_yr) controls($ctrl_jl)

graph save "Graph" "$out/FD1_multiplegt_in.gph", replace

* ── 4.2  Switchers out (journals that move away from a female EIC) ─────────
did_multiplegt_dyn gender_gap_y journal_id Publication_Year jrn_female_edihas, ///
    effects(5) placebo(3) cluster(journal_id) ///
    switchers(out) date_first_switch(first_treat_yr) controls($ctrl_jl)

graph save "Graph" "$out/FD2_multiplegt_out.gph", replace

di as result "=== Step 1 done. Output saved to: $out ==="
