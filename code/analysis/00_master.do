/*===========================================================================
  Female Editors-in-Chief and the Leading-Author Gender Gap
  MASTER SCRIPT — runs all Stata analyses in order

  Usage:
    1. Set the global `root` below to the folder that contains this
       replication package (the folder holding `code/` and `data/`).
    2. Install the required packages (once).
    3. Run this file. Each analysis script is run twice: once for the
       first-author definition and once for the last-author definition
       of the "leading author".

  Steps:
    01_baseline_did.do                 Main DiD, event study, did_multiplegt_dyn
    02_heterogeneity.do                Heterogeneity (institution, journal, country)
    03_mechanism.do                    Mechanisms (access, newcomers, citations)
    04a_novelty_prepare_journal_year.do  Builds the journal-year input for
                                       04b_novelty_gbdt_3step.ipynb (Python)

  After this file finishes, run 04b_novelty_gbdt_3step.ipynb in Python.
===========================================================================*/

clear all
set more off

* ── Root folder of the replication package (EDIT THIS) ─────────────────────
global root "/path/to/20261118-Materials"

* ── Required packages (uncomment to install once) ──────────────────────────
* ssc install reghdfe
* ssc install ftools
* ssc install estout
* ssc install did_multiplegt_dyn

* ── Run all steps for both leading-author definitions ──────────────────────
foreach a in first last {
    global author `a'
    do "$root/code/analysis/01_baseline_did.do"
    do "$root/code/analysis/02_heterogeneity.do"
    do "$root/code/analysis/03_mechanism.do"
    do "$root/code/analysis/04a_novelty_prepare_journal_year.do"
}

di as result "=== All Stata steps finished. Outputs are in $root/output ==="
