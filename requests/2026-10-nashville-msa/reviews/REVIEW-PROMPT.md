# Review prompt: Nashville nonprofit exploration

You are reviewing an exploratory data analysis before it is shared with a
colleague at the Urban Institute. The analysis asks what IRS nonprofit data
show about nonprofit locations, finances, workforce, and volunteers in
Nashville (Davidson County) and its 14-county metro, benchmarked against
19 peer metros. It was built in about three hours of a five-hour budget.
Review it as a careful second analyst would: check that the code does what
the write-up says, that the numbers in the write-up match the outputs, that
the assumptions are stated and defensible, and that the limitations are
complete and honest. Report what you find with evidence (file, line, the
number you computed) and say how confident you are. Agreement is not the
goal; finding what is wrong or overstated is.

## Where everything is

Folder: `requests/2026-10-nashville-msa/` in the `nccs-data-requests` repo
(branch `request/2026-10-nashville-msa`). The repo's house rules are in its
`CLAUDE.md` (public repo; read canonical artifacts, never re-derive
geography; pin every read).

| Path | What it is |
|---|---|
| `request.qmd` | The write-up: geography, data, definitions, seven caveats, six findings. Tables are static values copied from the outputs. |
| `docs/` | The requester's prior work: the Tennessee nonprofit workforce brief (PDF and text) and the Urban Wire piece (text). The write-up should complement, not contradict, these. |
| `INPUTS.md` | Every input and where it came from. |
| `_pins.csv` | Provenance log written by the read helpers (dataset, vintage, URL, row count). |
| `build.R` (section build-panel) | Builds the Tennessee universe (BMF plus crosswalk joins) and the national full-990 org-year panel from the e-file v2.1 Part I and Part IX files (dedup logic lives here). |
| `build.R` (section build-peers) | Builds EIN to metro mapping for the 20 metros. |
| `analysis-round1.R` (pass 1) | BMF density, formation, subsector mix by county. |
| `analysis-round1.R` (pass 2) | First financial pass, all organizations (superseded by 5 and 6 but kept for the all-organization view). |
| `analysis-round1.R` (pass 3) | Org-level medians, trimming, balanced 2019-2023 panel. |
| `analysis-round1.R` (pass 4) | Checks on what drives collar-county growth and the human services pay rise. |
| `analysis-round1.R` (pass 5) | Restricts to 501(c)(3), per-capita by county. |
| `analysis-round1.R` (pass 6) | National 501(c)(3) benchmark, robustness (2019-2022), exit and entrant cohorts. Writes `panel_charities.parquet`, used by 7, 9, 10. |
| `analysis-round1.R` (pass 7) | Government grants dependence (Phase 0). |
| `analysis-round1.R` (pass 8) | BMF-only: formation, attrition, foundations, zip codes. |
| `analysis-round1.R` (pass 9) | Davidson alone against peer principal counties. |
| `analysis-round1.R` (pass 10) | Volunteer reliance. |
| `output/explore-*.txt` | Console output of each script, captured 2026-10-12. The write-up's numbers should trace to these. |
| `output/county_population_2010_2023.csv`, `output/qcew_private_pay_benchmarks.csv` | The Census and BLS benchmark rows used. |
| `data/` | Gitignored. Derived parquet files and the raw external downloads (`data/external/`). Rebuilt by the scripts; the e-file CSV inputs live in `../2026-06-milwaukee-msa/data/`. |
| `checklist.md` | Public-safety and promotion gates. |
| `_private.md` | Gitignored. Requester identity and a draft note to them. Not part of the review. |

Reads use the `nccsdata` R package and anonymous HTTPS; no AWS credentials
are needed to rerun. Rerunning `build.R` (section build-panel) scans about 6 GB of CSV and
takes a minute.

## What to check

### 1. Code does what the write-up says

- Dedup in `build.R` (section build-panel): one return per EIN2 x tax year, amended and
  group returns keep the latest timestamp, return type 990 only, tax year
  taken from the column. Confirm the SQL does this and that Part IX joins
  to Part I on EIN2 and tax year without duplicating rows.
- Geography: counties come only from the published crosswalks; CBSA 34980
  has 14 counties; Davidson is FIPS 47037. Peer "principal county" in
  `analysis-round1.R` (pass 9) is the county with the most registered
  organizations. Is that a fair stand-in for the city in every peer? (St.
  Louis County is not the city of St. Louis; Henrico is not Richmond city.)
- Population filters: `as.integer(subsection_code) == 3` and exclusion of
  NTEE v2 subsectors HOS and UNI. Check that private foundations are
  excluded from the financial tables (the panel is return type 990, so
  990-PF filers should be absent; confirm) and that the BMF density table in
  finding 1 includes them (it does; is that the right choice?).
- Pay per employee: Part IX lines 5-10 summed with `rowSums(..., na.rm =
  TRUE)`, set to NA when both officer compensation and other salaries are
  missing, divided by Part I line 5, kept in [5000, 400000]. Check the
  column names against the e-file v2.1 Part IX header and whether the
  trimming bounds are reasonable.
- Government grants: blank treated as zero; share capped at 1; one row per
  EIN x tax year kept by highest filing receipt id. Is "blank means zero"
  defensible, given 58% of panel rows are blank?
- Balanced panels: organizations present in both 2019 and 2023. Check the
  pivot and the change formulas.
- Deflation: `base_cpi / cpi[tax_year]` to 2023 dollars.

### 2. Outputs match the write-up

Trace every number in `request.qmd` to a line in `output/`. Flag any that
do not match or that were rounded in a way that changes the reading. In
particular: the per-capita county table (explore-5), the government share
table (explore-7 and explore-9), the 2019-2023 growth table (explore-6 and
explore-9), the exit-cohort pay figures (explore-6 and explore-9), and the
volunteer table (explore-10).

### 3. Assumptions and interpretation

- The write-up ranks Davidson "1st of 20" on real pay growth and the metro
  "1st of 20" on the same. Are those rankings robust to the TY2023
  undercount (caveat 2)? Check the 2019-2022 version in explore-6.
- The exit-cohort finding (leavers paid less than stayers) rests on 128
  metro and 81 Davidson organizations. Is the gap statistically meaningful?
  Could it be explained by organizations switching to the 990-EZ (smaller,
  more part-time) rather than closing?
- "Human services charities draw less from government" compares Davidson
  with the rest of the US. Is the national comparison the right one, or
  should it be peer central counties (where Davidson is 14th of 20)?
- The collar-county capacity gap is measured by filing address. State
  clearly whether anything in the data constrains how much Davidson
  organizations serve collar residents.
- Finding 2 (zip codes): is "new organizations form away from the large
  institutions" supported by the asset sums, given caveat 6? Would a count
  of organizations with assets above some threshold be a better measure?
- Finding 6 (volunteers): is a 23% decline in reported volunteers in
  Davidson meaningful when line 6 is an estimate, 2015 was 351,000, and one
  organization reports 25,000?
- Are any of the findings a restatement of national trends (for example
  the 2020 jump in contribution share, the 2020-2021 deficit dip) presented
  as Nashville-specific?

### 4. Documentation, limitations, and caveats

- Are the seven caveats complete? Candidates not yet listed: the e-file
  v2.1 catalog is the legacy NODC release slated for supersession; the BMF
  "first year" field steps at vintage years (sparse before 1995, no 2017 or
  2021 vintage), which makes formation-by-year lumpy; QCEW pay is per job
  (annual average employment) while 990 pay is per head, so the two are not
  on the same basis; peer metros were chosen by the analyst, not by a
  published peer list (the Tennessee Nonprofit Network peer states are in
  `docs/`).
- Does any sentence in `request.qmd` claim something about 2024 or later?
  It should not.
- Are named organizations used only for public 990 facts?
- Is anything in the tracked files requester-identifying? (The repo is
  public.)

## How to report

List findings most serious first. For each: file and line or table, what
you expected, what you found, the number you computed if any, and your
confidence (confirmed by rerunning, confirmed by reading, or plausible but
unverified). End with the three changes you would make before this is
shared, and anything you would delete.
