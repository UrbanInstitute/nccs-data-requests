# Inputs for 2026-10-nashville-msa

All NCCS reads are pinned in `_pins.csv`. This file lists what each script
reads and where the non-NCCS inputs came from.

## NCCS artifacts (anonymous HTTPS, no credentials needed)

| Artifact | URL | Used by |
|---|---|---|
| Geocoded Unified BMF (rolling) | `nccsdata::nccs_read()` (https://nccsdata.s3.amazonaws.com/geocoding/unified-bmf/latest/bmf_unified_geocoded.parquet) | build-panel.R (TN), build-peers.R (19 states), explore-6-national.R (all states, 4 columns) |
| County FIPS crosswalk | https://nccsdata.s3.amazonaws.com/crosswalks/county-fips/county_fips_crosswalk.parquet | build-panel.R |
| CBSA crosswalk (2023 OMB) | https://nccsdata.s3.amazonaws.com/crosswalks/cbsa/cbsa_crosswalk.parquet | build-panel.R |
| E-file v2.1 Form 990 Part I, TY2012-2023 | s3://nccs-efile/public/efile_v2_1/F9-P01-T00-SUMMARY-{year}.CSV, synced to `../2026-06-milwaukee-msa/data/efile-v2_1-p01/` (sha256 in that folder's `_efile_inputs.csv`) | build-panel.R |
| E-file v2.1 Form 990 Part IX, TY2012-2023 | s3://nccs-efile/public/efile_v2_1/F9-P09-T00-EXPENSES-{year}.CSV, same folder `efile-v2_1-p09/` | build-panel.R |
| E-file Phase 0 government grants (v2026.06) | https://nccsdata.s3.amazonaws.com/processed/efile/phase0/latest/government_grants.parquet | explore-7-govgrants.R, explore-9-davidson.R |
| CPI-U annual averages | `nccsdata::cpi_u` (FRED CPIAUCNS) | build-panel.R |

## External inputs (`data/external/`, gitignored; fetched 2026-10-12)

| File | Source | Used by |
|---|---|---|
| co-est2019-alldata.csv | https://www2.census.gov/programs-surveys/popest/datasets/2010-2019/counties/totals/ (vintage 2019; POPESTIMATE2010, 2015, 2019) | county_pop.csv |
| co-est2023-alldata.csv | https://www2.census.gov/programs-surveys/popest/datasets/2020-2023/counties/totals/ (vintage 2023; POPESTIMATE2020, 2023) | county_pop.csv |
| qcew_{47037,47187,47149}_{2019,2023}.csv | https://data.bls.gov/cew/data/api/{year}/a/area/{fips}.csv (BLS QCEW annual, county) | output/qcew_private_pay_benchmarks.csv |

The 14-county population table is `output/county_population_2010_2023.csv`
(copied from `data/county_pop.csv`). The QCEW rows used are private
ownership (own_code 5), all industries (industry 10, agglvl 71) and NAICS
62 and 624 (agglvl 74/75), in `output/qcew_private_pay_benchmarks.csv`.

## Derived files in `data/` (gitignored, rebuilt by the scripts)

- `universe_tn.parquet`: every TN organization in the BMF with county and CBSA joins (build-panel.R)
- `universe_peers.parquet`: EIN to metro/county/subsector for the 20 metros (build-peers.R)
- `bmf_national_slim.parquet`: EIN, subsection, subsector, state for every organization (explore-6-national.R)
- `panel_990_national.parquet`: one row per EIN2 x tax year, full Form 990 filers, TY2012-2023 (build-panel.R)
- `panel_with_geo.parquet`: the panel joined to peer-metro geography (explore-2-finance.R)
- `panel_charities.parquet`: the panel restricted to 501(c)(3), excluding HOS/UNI, with pay per employee (explore-6-national.R)
- `balanced_2019_2023.parquet`: organizations filing in both 2019 and 2023 (explore-3-clean.R)
- `government_grants.parquet`: Phase 0 download
- `cpi.csv`, `county_pop.csv`
