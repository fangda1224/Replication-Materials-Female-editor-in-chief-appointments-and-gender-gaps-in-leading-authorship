/*===========================================================================
  Female Editors-in-Chief and the Leading-Author Gender Gap
  STEP 4a — Prepare the journal × year dataset for the novelty analysis

  Input:  data/1-{first|last}-0.7CI-withnovelty.dta               (paper level)
  Output: output/derived/2-{first|last}-journal-year-novelty.dta
          (input to 04b_novelty_gbdt_3step.ipynb)

  Novelty is measured with the atypical-combination score (Atyp_10pct_Z):
  a paper is "novel" if Atyp_10pct_Z < 0. Papers with a missing novelty
  score are excluded.
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

cap mkdir "$root/output"
cap mkdir "$derived"

/*===========================================================================
  1. LOAD PAPER-LEVEL DATA
===========================================================================*/

use "$data/1-${author}-0.7CI-withnovelty.dta", clear

drop if Publication_Year > 2022
drop if Atyp_10pct_Z == .

foreach v of varlist female_author jrn_female_edirto jrn_female_edihas ///
    pap_author_num jrn_hindex jrn_sjr jrn_avgcited jrn_totref jrn_refperdoc {
    cap confirm numeric var `v'
    if _rc cap destring `v', replace
}

cap confirm numeric var Publication_Year
if _rc destring Publication_Year, replace

cap rename journal journal_id

/*===========================================================================
  2. PAPER-LEVEL VARIABLES
===========================================================================*/

gen one = 1

gen novelty_inv = -Atyp_10pct_Z
egen novelty_std = std(novelty_inv)

* ── Male-led indicator ──────────────────────────────────────────────────────
gen male_author = (female_author == 0) if inlist(female_author, 0, 1)
label var male_author "Male leading author"

* ── Binary novelty indicator ────────────────────────────────────────────────
gen novel = (Atyp_10pct_Z < 0)

* ── Novel papers by leading-author gender (share of all papers) ─────────────
gen novel_fem = 1 if female_author == 1 & novel == 1
replace novel_fem = 0 if novel_fem == .

gen novel_male = 1 if male_author == 1 & novel == 1
replace novel_male = 0 if novel_male == .

/*===========================================================================
  3. COLLAPSE TO JOURNAL × YEAR
===========================================================================*/

collapse ///
    (mean)  prop_female_author  = female_author          ///
            jrn_female_edirto                            ///
            jrn_female_edihas                            ///
            jrn_hindex jrn_sjr jrn_avgcited              ///
            jrn_totref jrn_refperdoc                     ///
            avg_num_authors     = pap_author_num         ///
            avg_top_inst        = ins_top                ///
            avg_novelty_std     = novelty_std            ///
            avg_novel           = novel                  ///
            avg_novel_female    = novel_fem              ///
            avg_novel_male      = novel_male             ///
    (sum)   n_papers            = one                    ///
            n_novel             = novel                  ///
    (first) field category                               ///
    , by(journal_id Publication_Year)

* ── Post-collapse variables ─────────────────────────────────────────────────
gen gender_gap   = (1 - prop_female_author) - prop_female_author
gen gender_gap_y = gender_gap * 100

replace avg_novel        = avg_novel * 100
replace avg_novel_female = avg_novel_female * 100
replace avg_novel_male   = avg_novel_male * 100

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
label var avg_novel            "Share of novel papers, pp"
label var avg_novel_female     "Share of papers that are novel and female-led, pp"
label var avg_novel_male       "Share of papers that are novel and male-led, pp"
label var jrn_hindex           "Journal h-index"

/*===========================================================================
  4. TREATMENT VARIABLES
===========================================================================*/

sort journal_id Publication_Year
xtset journal_id Publication_Year

bysort journal_id: ///
    egen first_treat_yr = min(cond(jrn_female_edihas == 1, Publication_Year, .))

gen ever_treated = !missing(first_treat_yr)
gen post         = (Publication_Year >= first_treat_yr) if ever_treated == 1
replace post     = 0 if missing(post)
gen did_treat    = ever_treated * post

label var ever_treated  "Ever had female EIC"
label var post          "Post first female EIC year"
label var did_treat     "DiD: ever-treated × post"

/*===========================================================================
  5. SAVE
===========================================================================*/

compress
save "$derived/2-${author}-journal-year-novelty.dta", replace

di as result "=== Step 4a done. Saved: $derived/2-${author}-journal-year-novelty.dta ==="
