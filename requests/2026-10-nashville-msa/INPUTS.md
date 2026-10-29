# Inputs for 2026-10-nashville-msa

All reads are pinned in `_pins.csv` with a vintage and a sha256 (the BMF pin
carries its manifest vintage, git sha and parquet sha256). `run-all.R` is
the entry point; `build.R` (section build-external) fetches everything in the external table
below and verifies the Phase 0 parquet against its manifest.

## NCCS artifacts (anonymous HTTPS, no credentials needed)

| Artifact | URL | Used by |
|---|---|---|
| Geocoded Unified BMF (rolling; read 2026-10-12 was vintage 2026_09, git 1b1f8a9, sha256 c296860c...) | `nccsdata::nccs_read()` (https://nccsdata.s3.amazonaws.com/geocoding/unified-bmf/latest/bmf_unified_geocoded.parquet; manifest at `.../latest/_manifest.json`) | build.R (section panel) (TN), build.R (section peers) (19 states), analysis-round1.R (pass 6) (all states, 5 columns). Rolling: cannot be re-fetched at this vintage once it rolls. |
| County FIPS crosswalk | https://nccsdata.s3.amazonaws.com/crosswalks/county-fips/county_fips_crosswalk.parquet | build.R (section panel) |
| CBSA crosswalk (2023 OMB) | https://nccsdata.s3.amazonaws.com/crosswalks/cbsa/cbsa_crosswalk.parquet | build.R (section panel) |
| E-file v2.1 Form 990 Part I, TY2012-2023 | s3://nccs-efile/public/efile_v2_1/F9-P01-T00-SUMMARY-{year}.CSV, synced to `../2026-06-milwaukee-msa/data/efile-v2_1-p01/` (sha256 in that folder's `_efile_inputs.csv`) | build.R (section panel) |
| E-file v2.1 Schedule I Part II, release files 2019-2024, rows TY2019-2023 | https://nccs-efile.s3.us-east-1.amazonaws.com/public/efile_v2_1/SI-P02-T01-GRANTS-US-ORGS-GOVTS-{year}.CSV; downloaded, sha256 pinned, filtered to Davidson funders, raw file deleted | build.R (section funders) |
| E-file 990-PF grants paid (efilepf_v2_3, a SEPARATE release prefix from the 990 tables), release files 2019-2024, rows TY2019-2023 | https://nccs-efile.s3.us-east-1.amazonaws.com/public/efilepf_v2_3/PF-P15-T01-SUPPLEMENTARY-INFO-GRANT-PAID-{year}.parquet; same handling | build.R (section funders) |
| E-file v2.1 Form 990 Part IX, TY2012-2023 | s3://nccs-efile/public/efile_v2_1/F9-P09-T00-EXPENSES-{year}.CSV, same folder `efile-v2_1-p09/` | build.R (section panel) |
| E-file Phase 0 government grants (v2026.06, git 22b131b, sha256 verified against `_manifest.json`) | https://nccsdata.s3.amazonaws.com/processed/efile/phase0/latest/government_grants.parquet | build.R (section external) (download + verify); analysis-round1.R (pass 7), analysis-round1.R (pass 9) |
| CORE merged tier, 990combined, TY2019-2024 | `nccsdata::nccs_read_core(tier = "merged", form = "990combined")` (https://nccsdata.s3.amazonaws.com/processed_merged/core/{year}/990combined/) | analysis-round1.R (pass 11), analysis-round1.R (pass 12) |
| CPI-U annual averages | `nccsdata::cpi_u` (FRED CPIAUCNS) | build.R (section panel) |

## External inputs (`data/external/`, gitignored; fetched by build.R (section external), sha256 in `_pins.csv`)

| File | Source | Used by |
|---|---|---|
| co-est2019.csv (= co-est2019-alldata.csv) | https://www2.census.gov/programs-surveys/popest/datasets/2010-2019/counties/totals/ (vintage 2019; POPESTIMATE2010, 2015, 2019) | county_pop.csv |
| co-est2023.csv (= co-est2023-alldata.csv) | https://www2.census.gov/programs-surveys/popest/datasets/2020-2023/counties/totals/ (vintage 2023; POPESTIMATE2020, 2023) | county_pop.csv |
| qcew_{47037,47187,47149}_{2019,2023}.csv | https://data.bls.gov/cew/data/api/{year}/a/area/{fips}.csv (BLS QCEW annual, county) | output/qcew_private_pay_benchmarks.csv |

The 14-county population table is `output/county_population_2010_2023.csv`
(copied from `data/county_pop.csv`). The QCEW rows used are private
ownership (own_code 5), all industries (industry 10, agglvl 71) and NAICS
62 and 624 (agglvl 74/75), in `output/qcew_private_pay_benchmarks.csv`.

## Derived files in `data/` (gitignored, rebuilt by the scripts)

- `universe_tn.parquet`: every TN organization in the BMF with county and CBSA joins (build.R (section panel))
- `universe_peers.parquet`: EIN to metro/county/subsector for the 20 metros (build.R (section peers))
- `bmf_national_slim.parquet`: EIN, subsection, subsector, state for every organization (analysis-round1.R (pass 6))
- `panel_990_national.parquet`: one row per EIN2 x tax year, full Form 990 filers, TY2012-2023 (build.R (section panel))
- `panel_with_geo.parquet`: the panel joined to peer-metro geography (analysis-round1.R (pass 2))
- `panel_charities.parquet`: the panel restricted to 501(c)(3), excluding HOS/UNI, with pay per employee and the comparison-group label `grp` (analysis-round1.R (pass 6))
- `balanced_2019_2023.parquet`: all-organization balanced panel (analysis-round1.R (pass 3))
- `balanced_charities_2019_2023.parquet`: charities balanced panel with group labels (analysis-round1.R (pass 6))
- `_pins-*.csv`: pins logs from earlier runs, moved aside by run-all.R
- `government_grants.parquet`: Phase 0 download
- `cpi.csv`, `county_pop.csv`
- `list_match_candidates.csv`: top three registry name matches per listed organization (profile-list.R first pass)
- `list_match_decisions.csv`: hand-checked decision per listed organization: accept the top candidate, a named EIN, or none, with confidence and note (written by the analyst 2026-10-29)
- `list_matched.csv`, `list_filled.xlsx`: the requester's list with EIN, registry name, tax year 2023 full-990 total expenses, and status (profile-list.R)
- `funders_to_listed_grants.csv`, `funders_to_listed_pf_name_pairs.csv`: grants from Davidson-based funders to the listed organizations, TY2019-2023, and the 990-PF name pairs used (profile-funders.R)

Round 2 chart tables are in `output/chart_*.csv` with PNGs alongside
(profile-charts.R); they hold counts and aggregates only.

## Requester-supplied list (gitignored under `docs/`)

`List of Nonprofits and Philanthropies for Thiya.xlsx`, received 2026-10-23:
141 organizations, columns Name, Organization Type, Address, Operating
Expenses (blank). No EINs. Matched to the registry by name with the
address ZIP as a check; every match hand-checked. The CORE merged tier is
read for tax years 2023 and 2024 and relabeled to the IRS form year
(period beginning in 2023) so that fiscal-year filers line up with the
e-file panel.
