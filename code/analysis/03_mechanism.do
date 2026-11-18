/*===========================================================================
  Female Editors-in-Chief and the Leading-Author Gender Gap
  STEP 3 — Mechanism analysis (journal level)

  Input:  data/1-{first|last}-0.7CI-withnovelty.dta          (paper level)
  Output: output/derived/2-{first|last}-journal-year-mechanism.dta
          output/tables/{first|last}_mechanism/               (regression tables)
          output/figures/mechanism/                           (event-study plots)

  Required packages: reghdfe, ftools, estout

  Part A builds the journal × year mechanism dataset:
    - field-year normalized citation measures
    - five-year newcomer leading authors (author = name × affiliation)
  Part B estimates the mechanisms:
    1) Access                 : number of male- and female-led articles
    2) Author-pool diversity  : male and female newcomers
    3) Double standards       : field-year normalized citations
    4) Event studies for all 9 outcomes
    5) Heterogeneity by discipline for all 9 outcomes
===========================================================================*/

clear all
set more off
set linesize 200

/*===========================================================================
  0. SETUP
===========================================================================*/

* ── Paths and leading-author definition (normally set in 00_master.do) ─────
if "$root"   == "" global root "/path/to/20261118-Materials"
if "$author" == "" global author first      // "first" or "last"

global data    "$root/data"
global derived "$root/output/derived"
global out     "$root/output/tables/${author}_mechanism"
global fig     "$root/output/figures/mechanism"

cap mkdir "$root/output"
cap mkdir "$root/output/derived"
cap mkdir "$root/output/tables"
cap mkdir "$root/output/figures"
cap mkdir "$out"
cap mkdir "$fig"

* ── Discipline names ────────────────────────────────────────────────────────
local cname1 "Arts & Hum."
local cname2 "Life Sci."
local cname3 "Physical Sci."
local cname4 "Social Sci."
local cname5 "Technology"

* ── Earliest year for the five-year newcomer measure ────────────────────────
* E.g. in 2010, this checks whether the lead author appeared in 2005–2009.
* The data start in 2003, so 2008 is technically possible; 2009 is more
* conservative.
local start_newcomer5 2009


/*###########################################################################
  PART A — BUILD JOURNAL × YEAR MECHANISM DATASET
###########################################################################*/

/*===========================================================================
  PHASE 1 — Load paper-level data
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


/*===========================================================================
  PHASE 2 — Basic paper-level variables
===========================================================================*/

gen one = 1

gen novelty_inv = -Atyp_10pct_Z
egen novelty_std = std(novelty_inv)

gen novel = (Atyp_10pct_Z < 0)

* ── Male-led indicator ──────────────────────────────────────────────────────
gen male_author = (female_author == 0) if inlist(female_author, 0, 1)

label var male_author "Male leading author"


/*===========================================================================
  PHASE 3 — Field-year normalized citation measures
===========================================================================*/

destring pap_cited, replace force

* ── Field-year normalized citation: citation / field-year mean ──────────────
bysort field Publication_Year: egen mean_cite_fldyr = mean(pap_cited)

gen fn_cite = pap_cited / mean_cite_fldyr ///
    if mean_cite_fldyr > 0 & !missing(pap_cited)

label var fn_cite "Field-year normalized citation: citation / field-year mean"

* ── Log citation adjusted by field-year mean log citation ───────────────────
gen log_cite = ln(1 + pap_cited)

bysort field Publication_Year: egen mean_logcite_fldyr = mean(log_cite)

gen fn_logcite = log_cite - mean_logcite_fldyr

label var fn_logcite "Log citation minus field-year mean log citation"

* ── Top 10% cited papers within field × year ────────────────────────────────
bysort field Publication_Year: egen p90_fn_cite = pctile(fn_cite), p(90)

gen top10_fn_cite = fn_cite >= p90_fn_cite ///
    if !missing(fn_cite, p90_fn_cite)

label var top10_fn_cite "Top 10% field-year normalized citation paper"

drop p90_fn_cite

* ── Citation quality by leading-author gender ───────────────────────────────
gen fn_cite_female = fn_cite if female_author == 1
gen fn_cite_male   = fn_cite if male_author == 1

gen fn_logcite_female = fn_logcite if female_author == 1
gen fn_logcite_male   = fn_logcite if male_author == 1

gen top10_female = top10_fn_cite if female_author == 1
gen top10_male   = top10_fn_cite if male_author == 1

label var fn_cite_female "Field-normalized citation, female-led papers"
label var fn_cite_male   "Field-normalized citation, male-led papers"
label var top10_female   "Top 10% cited paper, female-led"
label var top10_male     "Top 10% cited paper, male-led"


/*===========================================================================
  PHASE 4 — Identify five-year newcomer leading authors

  Definition:
  author_id = author name × affiliation

  newcomer5_lead = 1 if the leading author did not publish as leading author
  in the same journal during the prior five calendar years.

  Example:
  In 2010, the author is a five-year newcomer if she/he did not appear in
  the same journal during 2005–2009.
===========================================================================*/

* ── Make sure affiliation remains numeric ───────────────────────────────────
cap confirm numeric variable affiliation
if _rc {
    destring affiliation, replace force
}

* ── Generate numeric ID for author name ─────────────────────────────────────
cap confirm numeric variable author
if _rc {
    egen long author_name_id = group(author), missing
}
else {
    gen long author_name_id = author
}

label var author_name_id "Numeric ID for author name"

* ── Generate author ID based on author name × affiliation ───────────────────
egen long author_id = group(author_name_id affiliation), missing

replace author_id = . if missing(author_name_id) | missing(affiliation)

label var author_id "Author ID based on author name ID × affiliation ID"

* ── First observed year of each journal ─────────────────────────────────────
bysort journal_id: egen first_journal_obs_year = min(Publication_Year)

* ── Valid five-year window ──────────────────────────────────────────────────
gen valid_newcomer5 = !missing(author_id) ///
    & inlist(female_author, 0, 1) ///
    & Publication_Year >= `start_newcomer5' ///
    & first_journal_obs_year <= Publication_Year - 5

label var valid_newcomer5 "Valid paper for five-year newcomer author measure"

* ── Build author-journal-year history to identify prior publication ─────────
preserve

    keep if !missing(author_id)

    * One record per journal × author × year
    egen tag_author_jyr = tag(journal_id author_id Publication_Year)
    keep if tag_author_jyr == 1

    keep journal_id author_id Publication_Year

    * Previous observed publication year of this author in this journal
    bysort journal_id author_id (Publication_Year): ///
        gen prev_author_jrn_year = Publication_Year[_n-1]

    * Had published in this journal during the prior five years
    gen had_pub_past5 = ///
        !missing(prev_author_jrn_year) ///
        & prev_author_jrn_year >= Publication_Year - 5 ///
        & prev_author_jrn_year <= Publication_Year - 1

    * Five-year newcomer: no publication in same journal during prior five years
    gen newcomer5_lead = (had_pub_past5 == 0)

    keep journal_id author_id Publication_Year ///
         prev_author_jrn_year had_pub_past5 newcomer5_lead

    tempfile newcomer5
    save `newcomer5', replace

restore

* ── Merge five-year newcomer status back to paper-level data ────────────────
merge m:1 journal_id author_id Publication_Year using `newcomer5', nogen

* Apply valid-window restriction
replace newcomer5_lead = . if valid_newcomer5 != 1

label var newcomer5_lead "Lead author absent from this journal in prior 5 years"

* ── Female and male five-year newcomer indicators ───────────────────────────
gen newcomer5_female = (newcomer5_lead == 1 & female_author == 1) ///
    if valid_newcomer5 == 1

gen newcomer5_male = (newcomer5_lead == 1 & male_author == 1) ///
    if valid_newcomer5 == 1

label var newcomer5_female "Female lead author absent from this journal in prior 5 years"
label var newcomer5_male   "Male lead author absent from this journal in prior 5 years"

* ── Denominators for among-female and among-male newcomer shares ────────────
gen female_led_valid5 = (female_author == 1) if valid_newcomer5 == 1
gen male_led_valid5   = (male_author == 1)   if valid_newcomer5 == 1

label var female_led_valid5 "Female-led paper with valid five-year newcomer window"
label var male_led_valid5   "Male-led paper with valid five-year newcomer window"


/*===========================================================================
  PHASE 5 — Collapse to journal × year
===========================================================================*/

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
            avg_fn_cite         = fn_cite                ///
            avg_fn_logcite      = fn_logcite             ///
            avg_fn_cite_female  = fn_cite_female         ///
            avg_fn_cite_male    = fn_cite_male           ///
            avg_fn_logcite_female = fn_logcite_female    ///
            avg_fn_logcite_male   = fn_logcite_male      ///
            share_top10_fn_cite = top10_fn_cite          ///
            share_top10_female  = top10_female           ///
            share_top10_male    = top10_male             ///
            prop_newcomer5_lead   = newcomer5_lead       ///
            prop_newcomer5_female = newcomer5_female     ///
            prop_newcomer5_male   = newcomer5_male       ///
    (sum)   n_papers            = one                    ///
            n_female_led        = female_author          ///
            n_male_led          = male_author            ///
            n_valid_newcomer5   = valid_newcomer5        ///
            n_newcomer5_lead    = newcomer5_lead         ///
            n_newcomer5_female  = newcomer5_female       ///
            n_newcomer5_male    = newcomer5_male         ///
            n_female_led_valid5 = female_led_valid5      ///
            n_male_led_valid5   = male_led_valid5        ///
    (first) field category                               ///
    , by(journal_id Publication_Year)


/*===========================================================================
  PHASE 6 — Post-collapse journal-year variables
===========================================================================*/

* ── Convert main shares to percentage points ────────────────────────────────
foreach v in prop_female_author share_top10_fn_cite share_top10_female share_top10_male {
    gen `v'_pp = 100 * `v'
}

* ── Gender gap in percentage points: male share − female share ──────────────
gen gender_gap   = (1 - prop_female_author) - prop_female_author
gen gender_gap_y = gender_gap * 100

label var gender_gap_y "Leading-author gender gap, male share - female share, pp"

* ── Novelty percentage ──────────────────────────────────────────────────────
replace avg_novel = avg_novel * 100

* ── Journal-level log controls ──────────────────────────────────────────────
gen log_n_papers       = log(1 + n_papers)
gen log_jrn_avgcited   = log(1 + jrn_avgcited)
gen log_jrn_refperdoc  = log(1 + jrn_refperdoc)
gen log_jrn_totref     = log(1 + jrn_totref)

* ── Count outcomes for female/male-led publications ─────────────────────────
gen log_n_female_led = log(1 + n_female_led)
gen log_n_male_led   = log(1 + n_male_led)

label var log_n_female_led "ln(1+female-led papers)"
label var log_n_male_led   "ln(1+male-led papers)"


/*===========================================================================
  PHASE 7 — Five-year newcomer journal-year measures
===========================================================================*/

* ── Share of all valid papers led by five-year newcomer authors ─────────────
gen prop_newcomer5_lead_pp = 100 * prop_newcomer5_lead

* ── Share of all valid papers led by five-year newcomer female/male authors ─
gen prop_newcomer5_female_pp = 100 * prop_newcomer5_female
gen prop_newcomer5_male_pp   = 100 * prop_newcomer5_male

* ── Among female-led papers, share led by five-year newcomer female authors ─
gen prop_newcomer5_among_fem = n_newcomer5_female / n_female_led_valid5 ///
    if n_female_led_valid5 > 0

* ── Among male-led papers, share led by five-year newcomer male authors ─────
gen prop_newcomer5_among_male = n_newcomer5_male / n_male_led_valid5 ///
    if n_male_led_valid5 > 0

gen prop_newcomer5_among_fem_pp  = 100 * prop_newcomer5_among_fem
gen prop_newcomer5_among_male_pp = 100 * prop_newcomer5_among_male

* ── Log count outcomes for five-year newcomer authors ──────────────────────
gen log_n_newcomer5_lead   = log(1 + n_newcomer5_lead)
gen log_n_newcomer5_female = log(1 + n_newcomer5_female)
gen log_n_newcomer5_male   = log(1 + n_newcomer5_male)

label var prop_newcomer5_lead_pp   "Share of papers led by 5-year newcomer authors, pp"
label var prop_newcomer5_female_pp "Share of papers led by 5-year newcomer female authors, pp"
label var prop_newcomer5_male_pp   "Share of papers led by 5-year newcomer male authors, pp"

label var prop_newcomer5_among_fem_pp  "Share of female-led papers by 5-year newcomer female authors, pp"
label var prop_newcomer5_among_male_pp "Share of male-led papers by 5-year newcomer male authors, pp"

label var log_n_newcomer5_lead   "ln(1+5-year newcomer-led papers)"
label var log_n_newcomer5_female "ln(1+5-year newcomer female-led papers)"
label var log_n_newcomer5_male   "ln(1+5-year newcomer male-led papers)"


/*===========================================================================
  PHASE 8 — Labels and controls
===========================================================================*/

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
label var avg_novel            "Share of novel papers, pp"
label var jrn_hindex           "Journal h-index"

label var avg_fn_cite "Average field-year normalized citation"
label var avg_fn_logcite "Average log citation adjusted by field-year mean"
label var avg_fn_cite_female "Average field-year normalized citation, female-led papers"
label var avg_fn_cite_male "Average field-year normalized citation, male-led papers"
label var avg_fn_logcite_female "Average log citation adjusted by field-year mean, female-led papers"
label var avg_fn_logcite_male "Average log citation adjusted by field-year mean, male-led papers"
label var share_top10_fn_cite_pp "Share of papers in top 10% field-year citations, pp"
label var share_top10_female_pp "Share of female-led papers in top 10% field-year citations, pp"
label var share_top10_male_pp "Share of male-led papers in top 10% field-year citations, pp"

global ctrl_jl "n_papers avg_num_authors log_jrn_avgcited log_jrn_totref log_jrn_refperdoc"


/*===========================================================================
  PHASE 9 — Save journal-year mechanism dataset
===========================================================================*/

compress

save "$derived/2-${author}-journal-year-mechanism.dta", replace


/*###########################################################################
  PART B — ANALYSIS (journal level)

  1) Access                : absolute number of male- and female-led articles
  2) Author-pool diversity : male and female newcomers
  3) Double standards      : field-year normalized citation
###########################################################################*/

use "$derived/2-${author}-journal-year-mechanism.dta", clear

global ctrl_jl "n_papers avg_num_authors log_jrn_avgcited log_jrn_totref log_jrn_refperdoc"


* ── Declare panel ────────────────────────────────────────────────────────────
sort journal_id Publication_Year
xtset journal_id Publication_Year


* ──  Construct treatment variables ──────────────────────────────────────
bysort journal_id: ///
    egen first_treat_yr = min(cond(jrn_female_edihas == 1, Publication_Year, .))

gen ever_treated = !missing(first_treat_yr)
gen post         = (Publication_Year >= first_treat_yr) if ever_treated == 1
replace post     = 0 if missing(post)
gen did_treat    = ever_treated * post

label var ever_treated  "Ever had female EIC"
label var post          "Post first female EIC year"
label var did_treat     "DiD: ever-treated × post"

* ── Summary statistics — journal-year level ──────────────────────────────────
estpost summarize gender_gap_y jrn_female_edihas jrn_female_edirto did_treat  ///
    n_papers avg_num_authors log_jrn_avgcited log_jrn_totref log_jrn_refperdoc ///
    avg_novelty_std avg_novel   ///
	log_n_papers prop_newcomer5_lead_pp prop_newcomer5_female_pp prop_newcomer5_male_pp  ///
	avg_fn_cite_female avg_fn_cite_male avg_fn_cite

esttab using "$out/T0_summary_jy.csv", replace ///
    cells("count(fmt(%12.0f)) mean(fmt(%9.3f)) sd(fmt(%9.3f)) min(fmt(%9.3f)) max(fmt(%9.3f))") ///
    label noobs nomtitle nonumber ///
    collabels("N" "Mean" "SD" "Min" "Max")


/*===========================================================================
*  --- Event-time dummies (shared across all 9 DVs' event studies below) ---
*  Relative time: years since first female EIC (for ever-treated journals)
*  Never-treated: no relative time -> event dummies set to 0 (serve as controls)
*  Baseline: t = -1 (year before first female EIC); window t in [-4,7]
===========================================================================*/
di as txt "--- Event study: building event-time dummies ---"

gen evt_time = Publication_Year - first_treat_yr if ever_treated == 1

gen evt_sample = ever_treated == 0 | ///
    (ever_treated == 1 & inrange(evt_time, -4, 7))

forvalues k = 4(-1)2 {
    gen pre`k' = ever_treated == 1 & evt_time == -`k'
    label var pre`k' "t = -`k'"
}
* t = -1 is the omitted baseline — do NOT generate pre1

forvalues k = 0/7 {
    gen post`k' = ever_treated == 1 & evt_time == `k'
    label var post`k' "t = +`k'"
}

local evt_dummies "pre4 pre3 pre2 post0 post1 post2 post3 post4 post5 post6 post7"


/*===========================================================================
*  --- 1. Access
===========================================================================*/
global ctrl_jl "avg_num_authors log_jrn_avgcited log_jrn_totref log_jrn_refperdoc"

gen log_n_paper = log(1+n_papers)


reghdfe log_n_paper did_treat $ctrl_jl, ///
        absorb(journal_id Publication_Year) vce(cluster journal_id)

		quietly summarize `e(depvar)' if e(sample)
        quietly estadd scalar Mean  = r(mean)
        quietly estadd scalar SD    = r(sd)
        quietly estadd local  y "n_papers"
		quietly estadd local  tfe "Yes"
		quietly estadd local  ife "Yes"
        est store n_papers

reghdfe log_n_male_led did_treat $ctrl_jl n_papers , ///
        absorb(journal_id Publication_Year) vce(cluster journal_id)

		quietly summarize `e(depvar)' if e(sample)
        quietly estadd scalar Mean  = r(mean)
        quietly estadd scalar SD    = r(sd)
        quietly estadd local  y "male_n_papers"
		quietly estadd local  tfe "Yes"
		quietly estadd local  ife "Yes"
        est store n_male


reghdfe log_n_female_led did_treat $ctrl_jl n_papers , ///
        absorb(journal_id Publication_Year) vce(cluster journal_id)

		quietly summarize `e(depvar)' if e(sample)
        quietly estadd scalar Mean  = r(mean)
        quietly estadd scalar SD    = r(sd)
        quietly estadd local  y "female_n_papers"
		quietly estadd local  tfe "Yes"
		quietly estadd local  ife "Yes"
        est store n_female

esttab n_* using "$out/T1_${author}_npapers.csv", replace ///
    label b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) ///
    stats(N r2_a Mean SD y ife tfe, fmt(%12.0f %9.3f %9.3f %9.3f) ///
        labels("Obs." "Adj. R²" "Mean DV" "SD DV" "DV" "Journal FE" "Year FE")) ///
    compress nogap

/*===========================================================================
*  --- 2. Diversify the journal's author pool
===========================================================================*/
global ctrl_jl "n_papers avg_num_authors log_jrn_avgcited log_jrn_totref log_jrn_refperdoc"


reghdfe prop_newcomer5_lead_pp did_treat $ctrl_jl, ///
        absorb(journal_id Publication_Year) vce(cluster journal_id)

		quietly summarize `e(depvar)' if e(sample)
        quietly estadd scalar Mean  = r(mean)
        quietly estadd scalar SD    = r(sd)
        quietly estadd local  y "n_newcomer"
		quietly estadd local  tfe "Yes"
		quietly estadd local  ife "Yes"
        est store new_all


reghdfe prop_newcomer5_female_pp did_treat $ctrl_jl, ///
        absorb(journal_id Publication_Year) vce(cluster journal_id)

		quietly summarize `e(depvar)' if e(sample)
        quietly estadd scalar Mean  = r(mean)
        quietly estadd scalar SD    = r(sd)
        quietly estadd local  y "n_newfemale"
		quietly estadd local  tfe "Yes"
		quietly estadd local  ife "Yes"
        est store new_fe


reghdfe prop_newcomer5_male_pp did_treat $ctrl_jl, ///
        absorb(journal_id Publication_Year) vce(cluster journal_id)

		quietly summarize `e(depvar)' if e(sample)
        quietly estadd scalar Mean  = r(mean)
        quietly estadd scalar SD    = r(sd)
        quietly estadd local  y "n_newmale"
		quietly estadd local  tfe "Yes"
		quietly estadd local  ife "Yes"
        est store new_ma

esttab new_* using "$out/T2_${author}_newcomers.csv", replace ///
    label b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) ///
    stats(N r2_a Mean SD y ife tfe, fmt(%12.0f %9.3f %9.3f %9.3f) ///
        labels("Obs." "Adj. R²" "Mean DV" "SD DV" "DV" "Journal FE" "Year FE")) ///
    compress nogap

/*===========================================================================
*  --- 3. Double standards
===========================================================================*/

global ctrl_jl "n_papers avg_num_authors log_jrn_totref  log_jrn_avgcited log_jrn_refperdoc"


gen female_male_fn_cite_gap = avg_fn_cite_female - avg_fn_cite_male
label var female_male_fn_cite_gap "Female-led minus male-led avg. field-normalized citation"


reghdfe avg_fn_cite_female did_treat $ctrl_jl, ///
        absorb(journal_id Publication_Year) vce(cluster journal_id)

		quietly summarize `e(depvar)' if e(sample)
        quietly estadd scalar Mean  = r(mean)
        quietly estadd scalar SD    = r(sd)
        quietly estadd local  y "cite_fe"
		quietly estadd local  tfe "Yes"
		quietly estadd local  ife "Yes"
        est store cite_fe

reghdfe avg_fn_cite_male did_treat $ctrl_jl, ///
        absorb(journal_id Publication_Year) vce(cluster journal_id)

		quietly summarize `e(depvar)' if e(sample)
        quietly estadd scalar Mean  = r(mean)
        quietly estadd scalar SD    = r(sd)
        quietly estadd local  y "cite_me"
		quietly estadd local  tfe "Yes"
		quietly estadd local  ife "Yes"
        est store cite_me

reghdfe avg_fn_cite did_treat $ctrl_jl, ///
    absorb(journal_id Publication_Year) vce(cluster journal_id)

		quietly summarize `e(depvar)' if e(sample)
        quietly estadd scalar Mean  = r(mean)
        quietly estadd scalar SD    = r(sd)
        quietly estadd local  y "cite"
		quietly estadd local  tfe "Yes"
		quietly estadd local  ife "Yes"
        est store cite_gap

esttab cite_* using "$out/T3_${author}_cite.csv", replace ///
    label b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) ///
    stats(N r2_a Mean SD y ife tfe, fmt(%12.0f %9.3f %9.3f %9.3f) ///
        labels("Obs." "Adj. R²" "Mean DV" "SD DV" "DV" "Journal FE" "Year FE")) ///
    compress nogap

estimates clear


/*===========================================================================
*  --- 4. Event studies for all 9 dependent variables (3 per section) ---
*  Same event-time dummies (pre4..pre2, post0..post7; baseline t=-1) built
*  once above. Each DV keeps the exact control set used in its baseline
*  DiD spec (Sections 1-3).
===========================================================================*/
di as txt "=== 4. Event studies: all 9 DVs ==="

local evt_dummies "pre4 pre3 pre2 post0 post1 post2 post3 post4 post5 post6 post7"

* ── Parallel index lists: DV / control set / y-axis-and-title label / file suffix ─
local evt_dv1    "log_n_paper"
local evt_ctrl1  "avg_num_authors log_jrn_avgcited log_jrn_totref log_jrn_refperdoc"
local evt_lbl1   "ln(1+Total Papers)"
local evt_sfx1   "npapers"

local evt_dv2    "log_n_male_led"
local evt_ctrl2  "avg_num_authors log_jrn_avgcited log_jrn_totref log_jrn_refperdoc n_papers"
local evt_lbl2   "ln(1+Male-led Papers)"
local evt_sfx2   "male_npapers"

local evt_dv3    "log_n_female_led"
local evt_ctrl3  "avg_num_authors log_jrn_avgcited log_jrn_totref log_jrn_refperdoc n_papers"
local evt_lbl3   "ln(1+Female-led Papers)"
local evt_sfx3   "female_npapers"

local evt_dv4    "prop_newcomer5_lead_pp"
local evt_ctrl4  "n_papers avg_num_authors log_jrn_avgcited log_jrn_totref log_jrn_refperdoc"
local evt_lbl4   "Share of Newcomer-led Papers (pp)"
local evt_sfx4   "newcomer_all"

local evt_dv5    "prop_newcomer5_female_pp"
local evt_ctrl5  "n_papers avg_num_authors log_jrn_avgcited log_jrn_totref log_jrn_refperdoc"
local evt_lbl5   "Share of Female-Newcomer-led Papers (pp)"
local evt_sfx5   "newcomer_female"

local evt_dv6    "prop_newcomer5_male_pp"
local evt_ctrl6  "n_papers avg_num_authors log_jrn_avgcited log_jrn_totref log_jrn_refperdoc"
local evt_lbl6   "Share of Male-Newcomer-led Papers (pp)"
local evt_sfx6   "newcomer_male"

local evt_dv7    "avg_fn_cite_female"
local evt_ctrl7  "n_papers avg_num_authors log_jrn_totref log_jrn_avgcited log_jrn_refperdoc"
local evt_lbl7   "Avg. Field-Normalized Citation, Female-led"
local evt_sfx7   "cite_female"

local evt_dv8    "avg_fn_cite_male"
local evt_ctrl8  "n_papers avg_num_authors log_jrn_totref log_jrn_avgcited log_jrn_refperdoc"
local evt_lbl8   "Avg. Field-Normalized Citation, Male-led"
local evt_sfx8   "cite_male"

local evt_dv9    "avg_fn_cite"
local evt_ctrl9  "n_papers avg_num_authors log_jrn_totref log_jrn_avgcited log_jrn_refperdoc"
local evt_lbl9   "Field-Normalized Citation"
local evt_sfx9   "cite"

forvalues i = 1/9 {
    local dv    "`evt_dv`i''"
    local ctrls "`evt_ctrl`i''"
    local lbl   "`evt_lbl`i''"
    local sfx   "`evt_sfx`i''"

    di as txt "--- Event study `i'/9: `dv' ---"

    eststo evt_`sfx': reghdfe `dv' `evt_dummies' `ctrls' if evt_sample == 1, ///
        absorb(journal_id Publication_Year) vce(cluster journal_id)

    esttab evt_`sfx' using "$out/T4_${author}_eventstudy_`sfx'.csv", replace ///
        keep(`evt_dummies') b(6) ci(6) nostar

    * ── Event-study plot: manual matrix extraction of B and V ──────────────
    matrix B = e(b)
    matrix V = e(V)

    preserve
        clear
        set obs 12   // 11 event dummies + baseline t=-1

        gen t    = .
        gen coef = .
        gen lo   = .
        gen hi   = .

        * Baseline (t = -1, omitted category → zero by construction)
        replace t    = -1 in 1
        replace coef = 0  in 1
        replace lo   = 0  in 1
        replace hi   = 0  in 1

        local tvals -4 -3 -2 0 1 2 3 4 5 6 7
        local row = 2
        foreach tv of local tvals {
            local vname = cond(`tv' < 0, "pre`=abs(`tv')'", "post`tv'")
            local col   = colnumb(B, "`vname'")
            replace t    = `tv'                                      in `row'
            replace coef = B[1, `col']                               in `row'
            replace lo   = B[1, `col'] - 1.96 * sqrt(V[`col', `col']) in `row'
            replace hi   = B[1, `col'] + 1.96 * sqrt(V[`col', `col']) in `row'
            local ++row
        }
        sort t

        twoway ///
            (rcap lo hi t, lcolor(gs8) lwidth(thin)) ///
            (scatter coef t, mcolor(navy) msymbol(circle) msize(medsmall)) ///
            (line coef t, lcolor(navy) lwidth(thin) lpattern(solid)) ///
            , ///
            yline(0, lcolor(red) lpattern(dash)) ///
            xline(-0.5, lcolor(gs10) lpattern(dash)) ///
            xlabel(-4(1)7) ///
            xtitle("Years Relative to First Female EIC Appointment") ///
            ytitle("`lbl'") ///
            title("Event Study: `lbl'", size(medlarge)) ///
            subtitle("Baseline: t = {&minus}1, 95% CI shown", size(small)) ///
            legend(off) ///
            scheme(s2color)
        graph export "$fig/${author}_F4_eventstudy_`sfx'.png", replace width(1800)
    restore

    eststo clear
}

drop pre* post* evt_time evt_sample
di as txt "=== 4. Event studies exported to $fig and $out ==="


/*===========================================================================
*  --- 5. Heterogeneity by discipline (category = 1..5) for all 9 DVs ───────
*  Re-estimates each baseline DiD spec (Sections 1-3) restricted to one
*  discipline (`category') at a time; same DV/control lists as Section 4.
===========================================================================*/
di as txt "=== 5. Heterogeneity by discipline (category): all 9 DVs ==="

forvalues i = 1/9 {
    local dv    "`evt_dv`i''"
    local ctrls "`evt_ctrl`i''"
    local sfx   "`evt_sfx`i''"

    di as txt "--- By category `i'/9: `dv' ---"

    forvalues cat = 1/5 {
        capture noisily reghdfe `dv' did_treat `ctrls' ///
            if category == `cat', ///
            absorb(journal_id Publication_Year) vce(cluster journal_id)
        if _rc == 0 {
            quietly summarize `e(depvar)' if e(sample)
            quietly estadd scalar Mean = r(mean)
            quietly estadd scalar SD   = r(sd)
            est store cat_`sfx'`cat'
        }
        else di as error "Skipping `dv', category `cat' (code = " _rc ")"
    }

    esttab cat_`sfx'* using "$out/T5_${author}_bycat_`sfx'.csv", replace ///
        mtitle("`cname1'" "`cname2'" "`cname3'" "`cname4'" "`cname5'") ///
        keep(did_treat `ctrls') order(did_treat `ctrls') ///
        label b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) ///
        stats(N r2_a Mean SD, fmt(%12.0f %9.3f %9.3f %9.3f) ///
            labels("Obs." "Adj. R²" "Mean DV" "SD DV")) ///
        compress nogap varwidth(22)

    estimates clear
}

di as txt "=== 5. Heterogeneity-by-category tables exported to $out ==="

di as result "=== Step 3 done. Output saved to: $out and $fig ==="
