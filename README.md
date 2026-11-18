# Replication-Materials-Female-editor-in-chief-appointments-and-gender-gaps-in-leading-authorship
The project examines gender gaps in scientific authorship following female editor-in-chief appointments using large-scale bibliometric data. The analysis focuses on first and last corresponding authorship and gender representation in novel research, with comparisons across disciplines, journals, institutions, and countries.


This package contains the code needed to reproduce the analyses in the paper. The processed data are archived separately on figshare: https://doi.org/10.6084/m9.figshare.35048644

Download the data files from figshare and place them in the `data/` folder before running the code. The package is organised as follows once the data are in place:

```
20261118-Materials/
├── README.md
├── data/
│   ├── 1-first-0.7CI-withnovelty.dta      # paper-level data, leading author = first author
│   ├── 1-last-0.7CI-withnovelty.dta       # paper-level data, leading author = last author
│   ├── wgidataset_with_sourcedata-2025.xlsx   # World Bank WGI (public; see "External data")
│   └── OGHIST_2026_07_01.xlsx                 # World Bank income groups (public; see "External data")
├── code/
│   ├── data_pipeline/                     # code used to build the data (for reference only)
│   │   ├── 1_Merge_AllPublications.ipynb
│   │   ├── 2_Extract_AuthorInfo.ipynb
│   │   ├── 3_Infer_AuthorGender.ipynb
│   │   ├── 4_Indentify_AuthorAffiliation.ipynb
│   │   ├── 5_Merge_JournalInfo.ipynb
│   │   ├── 6_Merge_InstitutionInfo.ipynb
│   │   ├── 7_Merge_CountryInfo.ipynb
│   │   └── 8_Merge_AllInfo.ipynb
│   └── analysis/                          # code that reproduces the results
│       ├── 00_master.do
│       ├── 01_baseline_did.do
│       ├── 02_heterogeneity.do
│       ├── 03_mechanism.do
│       ├── 04a_novelty_prepare_journal_year.do
│       └── 04b_novelty_gbdt_3step.ipynb
└── output/                                # created when the code is run
```

## Data

### Processed data (`data/`)

**Download:** (https://doi.org/10.6084/m9.figshare.35048644)

The two `.dta` files are the processed, analysis-ready datasets. Each row is one paper. The two files differ only in how the *leading author* is defined:

| File | Leading author |
|---|---|
| `1-first-0.7CI-withnovelty.dta` | First author |
| `1-last-0.7CI-withnovelty.dta`  | Last author |


The raw bibliographic data used to build these files are not redistributed. The notebooks in `code/data_pipeline/` show how the processed files were built. They are included for transparency only and cannot be run without the raw data.

#### Main variables used in the analysis

| Variable | Description |
|---|---|
| `journal` / `journal_id` | Journal identifier (renamed to `journal_id` by the code) |
| `Publication_Year` | Publication year |
| `female_author` | Leading author is female (1) or male (0) |
| `jrn_female_edihas` | Journal has at least one female editor-in-chief (EIC) in that year (treatment) |
| `jrn_female_edirto` | Share of the journal's EICs who are female |
| `pap_author_num` | Number of authors on the paper |
| `pap_cited` | Citations received by the paper |
| `Atyp_10pct_Z` | Novelty score: 10th-percentile z-score of the paper's reference-pair combinations (atypical combinations). Papers with `Atyp_10pct_Z < 0` are classified as novel |
| `jrn_hindex`, `jrn_sjr` | Journal h-index and SJR |
| `jrn_avgcited`, `jrn_totref`, `jrn_refperdoc` | Journal average citations, total references, references per paper |
| `ins_top` | Leading author's institution is a top-200 university |
| `country_code` | ISO3 code of the leading author's country |
| `cny_hdi` | Human Development Index of the leading author's country |
| `field` | Field (21 categories) |
| `category` | Discipline: 1 Arts & Humanities, 2 Life Sciences, 3 Physical Sciences, 4 Social Sciences, 5 Technology |
| `author`, `affiliation` | Author and affiliation identifiers, used only to identify returning versus newcomer authors (`03_mechanism.do`) |

### External data (public)

`02_heterogeneity.do` also uses two public World Bank files. Copies are included in the figshare record; place them in `data/` together with the `.dta` files:

| File | Source |
|---|---|
| `wgidataset_with_sourcedata-2025.xlsx` | World Bank, *Worldwide Governance Indicators* (2025 release), sheet `ge` (Government Effectiveness). https://www.worldbank.org/en/publication/worldwide-governance-indicators |
| `OGHIST_2026_07_01.xlsx` | World Bank, *Historical country income classifications* (release of 1 July 2026). https://datahelpdesk.worldbank.org/knowledgebase/articles/906519 |

## Software requirements

**Stata** (the analysis was run with Stata/MP 19). Install the following packages from SSC:

```stata
ssc install reghdfe
ssc install ftools
ssc install estout
ssc install did_multiplegt_dyn
```

**Python** 3.13 with `numpy`, `pandas`, `scikit-learn` (1.6.1 was used), `scipy`, `matplotlib`, and Jupyter to run the notebook.

## How to reproduce the results

1. Download the data from figshare ([FIGSHARE DOI LINK]) and put all files in the `data/` folder.
2. Open `code/analysis/00_master.do`. Set `global root` to the full path of this folder (`20261118-Materials`).
3. Run `00_master.do` in Stata. It runs steps 01–04a twice: once with `author = first` and once with `author = last`.
4. Open `code/analysis/04b_novelty_gbdt_3step.ipynb` in Jupyter. Its working directory must be `code/analysis/`. Run it with `AUTHOR = 'first'`, then change the value to `'last'` and run it again.

You can also run each Stata script on its own. Set `global root` and `global author` first; the scripts default to `first`.

## Analysis scripts

| Step | Script | What it does | Main output |
|---|---|---|---|
| 0 | `00_master.do` | Sets the root path and runs steps 1–4a for both leading-author definitions | — |
| 1 | `01_baseline_did.do` | Collapses the data to journal × year. Computes descriptive statistics and the main two-way fixed-effects difference-in-differences (DiD) estimates, including by discipline and by field. Also runs the event study and the heterogeneity-robust DiD (`did_multiplegt_dyn`) for switchers in and out | `output/tables/{author}/T0_*`, `TC*`, `FC1_eventstudy.png`, `FD*.gph`; `output/figure_data/1*` |
| 2 | `02_heterogeneity.do` | Heterogeneity by institution (top-200 university), by journal h-index (median split within each discipline), and by country: HDI (UN cutoffs), government effectiveness (World Bank WGI, median split), and World Bank income group | `output/tables/{author}/TM1_*`, `TM2_*`, `TM3_*`, `T2_summary_paper.csv`; `output/figure_data/1e-*`, `2*` |
| 3 | `03_mechanism.do` | Builds a journal × year mechanism dataset. Estimates DiD and event studies for three mechanisms: (1) access, measured by the number of male- and female-led papers; (2) author-pool diversity, measured by the share of leading authors who had not published in the journal in the previous five years; (3) double standards, measured by field-year normalised citations | `output/derived/2-{author}-journal-year-mechanism.dta`; `output/tables/{author}_mechanism/`; `output/figures/mechanism/` |
| 4a | `04a_novelty_prepare_journal_year.do` | Builds the journal × year dataset of gender gap and novelty used by step 4b | `output/derived/2-{author}-journal-year-novelty.dta` |
| 4b | `04b_novelty_gbdt_3step.ipynb` | Three-step gradient-boosted tree (GBDT) counterfactual model. It is trained on untreated journal-years and predicts the no-treatment paths of the gender gap (Model A) and of novelty (Models B and C). The post-treatment change in novelty is split into a part implied by the change in the gender gap and a residual part. ATTs are reported with 95% CIs clustered by journal | `output/novelty/{author}/` (CSV tables and PDF figures) |

### Treatment definition

A journal is treated from the first year in which it has a female editor-in-chief (`jrn_female_edihas == 1`). Treatment is then assumed to be permanent (`did_treat = ever_treated × post`). Standard errors are clustered by journal. Unless stated otherwise, models include journal and year fixed effects. They also control for the number of papers, the average number of authors, and the log of the journal's average citations, total references and references per paper.

## Notes

- The GBDT step uses a fixed `random_state = 42`. Results may still differ slightly across scikit-learn versions.
- Outputs from `did_multiplegt_dyn` are saved as Stata graph files (`.gph`). The point estimates are printed in the Stata log.

