# Response to the plan review (2026-10-20)

Each finding: accepted, amended, or rejected, with what I checked.
Labels: verified (I read the contract or code), reviewer-verified
(the reviewer's live data check, not rerun here; the build scripts
now print the same number so it is reproduced), inferred.

| # | Decision | Evidence and change |
|---|---|---|
| 1 | Amended | The processed CORE tier is partitioned 990, 990combined, 990ez, 990pf (verified, `nccs-contracts/contracts/core-990.yml`). PZ and PC do exist as partitions of the frozen legacy harmonized tier, whose base files stop at 2022 (verified, `core-harmonized-frozen.yml`), so the requester's source line uses the old product name. Plan now names the reads: 990combined for the five financial sheets with `source_form` separating 990 from EZ; the 990 partition for employees. Methods note will map "Core PZ/PC file" to these. |
| 2 | Accepted | Employees from Part V line 2a, which the 990 defines Part I line 5 to equal. Blanks stored as zero (reviewer-verified: 47 percent zeros, 299 with wages). The 0 band is labelled "zero or not reported" and step 3 prints the zero-with-wages count. |
| 3 | Accepted | Missing ruling dates stored as 1900-01-01 (reviewer-verified: 38 rows). Step 1 flags them; age sheet reports them as a "not reported" column or excludes them from the denominator, stated in the methods note. |
| 4 | Accepted | The master holds every EIN ever seen (reviewer-verified: 34,096 of 80,755 Michigan rows stale). Step 1 filters to the latest `last_vintage_ym` and prints the vintage and the rows dropped. |
| 5 | Accepted | Subsection 3 and foundation code not in 2, 3, 4, compared as integers. Codes 2, 3, 4 as private foundations match `sector-in-brief-data/R/derive_dimensions.R` (verified). Step 2 prints the count per county; reviewer-verified range 505 Monroe to 8,067 Wayne is the reproduction target. |
| 6 | Accepted | Step 2 maps NTEE v2 subsectors to the template's ten groups: HOS folds into Health, UNI into Education. Unclassified (reviewer-verified about 20 percent) is kept as its own row and explained in the methods note. |
| 7 | Accepted | Exclude negative-revenue rows from the operating surplus sheet (reviewer-verified: 18 rows) and report them in the methods note; the 0 band carries a footnote for assigned zeros (190). Ratios beyond 1000 percent stay in the outer bands since the bands are open-ended. |
| 8 | Accepted | Step 3 keeps the latest tax period per EIN and prints how many duplicates were resolved (reviewer-verified: 11). |
| 9 | Accepted | No cell suppression. Every row carries its denominator n in the output and the methods note. Monroe's 47 full-990 filers (reviewer-verified) is reported as a caveat. |
| 10 | Accepted | Lower bound inclusive on every dollar sheet. Liabilities of zero (reviewer-verified: half of filers) fall in the lowest band and are noted. |
| 11 | Accepted | Financial sheets cover organizations filing tax year 2023 that are currently registered; step 3 prints how many 2023 filers are not in the current registry (reviewer-verified: 81). |
| 12 | Accepted | Steps 1 and 2 merged into one universe script. Step 5 folder fixed to `template/`. Timeline rewritten. |
| 13 | Accepted | QA adds denominator reconciliation by county and sheet, a form-type by county cross-tab, and an external check of the Wayne County count against a published IRS or NCCS figure. |
| 14 | Accepted | Step 1 prints unresolved Michigan rows and drops them, even if the count is zero. |
| 15 | Accepted | Plan and README refer to "the analyst" and "the reviewer". The GitHub issues are addressed to no one by name. |

Not rerun here: every count the reviewer reports from live data. The
scripts print each one, so the first run reproduces or contradicts
them.
