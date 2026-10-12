# Response to REVIEW.md (2026-10-12)

Every finding was accepted. What changed, finding by finding, and what the
rebuilt numbers show. All outputs in `output/` were regenerated from the
new build; the Nashville endpoint figures are unchanged except TY2022
employees (68,518 to 68,522).

| # | Finding | Action | Where |
|---|---|---|---|
| 1 | Nondeterministic filing selection; parts could mix | Filing chosen once on Part I (timestamp desc, OBJECTID desc); Part IX joined on OBJECTID; build asserts filings = unique keys = unique filing ids and zero identity mismatches (3,174,130 each, 0 mismatches). `review-validation.R` still exits non-zero because it re-implements the old two-stage algorithm to count ties; its panel-level checks (uniqueness, zero unmatched grants rows) pass. Filing-selection semantics noted as a candidate to route upstream in `checklist.md`. | `build-panel.R`, `output/build-panel.txt`, `output/review-validation.txt` |
| 2 | Davidson 1st-place pay ranking not robust | Memo table now carries 2019-2022 beside 2019-2023 for every growth figure and states Davidson is 6th through 2022 (Cincinnati leads). Employee declines described as observed in this release, flat through 2022. The 2022-2023 count declines are given as declines, not completeness rates. | `explore-9-davidson.R` (sensitivity block), `request.qmd` finding 5, caveat 2 |
| 3 | Line 1e overstated as government funding; wrong county subsector figures; rank | All language changed to "reported line 1e government grants"; definition states line 2 exclusion. Human services county shares now computed and used (Williamson 1.4%, Rutherford 3.1%; all-charity 3.6% and 4.9% given separately). Rank corrected to 13th of 20, computed excluding the Rest of US row. Peer-metro and national comparators both shown. "84 to 96% government funded" rewritten as share of revenue reported on line 1e. | `explore-7-govgrants.R`, `explore-9-davidson.R`, `request.qmd` finding 4 |
| 4 | "Months of reserves" is net assets | Renamed "net assets in months of expenses" with the restricted/fixed-asset caveat and a statement that it is not comparable with the survey's cash-on-hand figures. "Deficit" renamed "expenses exceed revenue". Column names in scripts changed to `exp_gt_rev` and `med_na_months`. | `request.qmd` definitions, findings 5 and 6; scripts 2, 3, 6, 9 |
| 5 | ZIP ranking contradicted the formation story | Headline "formation away from large institutions" deleted. Table re-ranked on recognitions since 2020, with Midtown (37203) shown third, human services among recent recognitions counted separately from all active human services, and a count of organizations with assets over $10M. Text now says "recently recognized organizations currently located in these ZIPs". | `explore-8-bmf.R`, `request.qmd` finding 2, caveats 5 and 7 |
| 6 | National comparator changed across scripts | One definition: Nashville / Rest of TN / Peer metros / Rest of US (outside the 20 metros and outside TN), set in `explore-6` and carried in `panel_charities.parquet` so scripts 7, 9, 10 inherit it. Memo tables now show Peer metros and Rest of US as separate rows with the regenerated values. | `explore-6-national.R`, `explore-7-govgrants.R` |
| 7 | Exit-cohort evidence weaker for Davidson | Exit table moved into `explore-6` with valid-pay counts and a 2,000-resample bootstrap interval on the median gap for metro, Davidson, peer metros and Rest of US. Memo reports the intervals, says the Davidson gap is not distinguishable from zero, and drops the closure/decomposition interpretation. Caveat 4 cross-reference fixed. | `explore-6-national.R`, `request.qmd` finding 5 |
| 8 | Volunteer labels mixed denominators | Every volunteer column now names its denominator (positive count; any value incl. zero; positive reporters with staff). The "11th of 20" rank is dropped in favor of the range. Balanced panel labeled as positive-in-both-years. The two organizations behind half the decline are named with their contribution. | `explore-10-volunteers.R`, `request.qmd` finding 6, caveat 9 |
| 9 | QCEW nominal vs real; measures not comparable | QCEW converted to 2023 dollars in `explore-9` (NAICS 624: $36,945 to $41,547, +12.5%); "kept pace for the same work" deleted; caveat 10 added on the per-job vs per-head basis. | `explore-9-davidson.R`, `request.qmd` finding 5 |
| 10 | Reproducibility overstated | `build-external.R` now downloads Census, QCEW and the Phase 0 parquet (sha256 checked against its manifest) and derives `county_pop.csv`. Every pin carries a sha256; the BMF pin carries the manifest vintage, git sha and parquet sha256. Crosswalk sha256 pinned on every run. `run-all.R` is the entry point and starts a fresh `_pins.csv`. The memo now says "reproducible from its inputs as identified, not from the folder alone" and names the rolling BMF as the remaining non-immutable input. | `build-external.R`, `build-panel.R`, `run-all.R`, `INPUTS.md` |
| 11 | Broken coverage check; blank-as-zero unverified | Join indicator added from the right-hand table; build stops if any row is unmatched (none are). Blank share reported by group and year (Davidson 63% in 2023; Rest of US 63%). Blank-as-zero stated as an assumption in the script header and caveat 8. Individual share cap removed; rows with share over 1 are counted and reported instead (Nashville 1 in 2023). | `explore-7-govgrants.R`, `request.qmd` caveat 8 |
| 12 | Top-five employer diagnostic selected three | Pivot by EIN with names attached afterwards; selection on 2019 employment. The corrected diagnostic (five largest 2019 employers fell 11,009 to 7,759; all others rose 10,873 to 12,226) is in the output and not used in the memo. | `explore-6-national.R` |

Additional items from the review's limitations section:

- Peer counties described as analyst-selected with the St. Louis and
  Henrico examples; peer metros described as analyst-selected and
  distinguished from the survey brief's peer states (Geography section).
- Current-address-applied-to-history and ruling-date-not-founding added as
  caveat 5; BMF vintage stepping as caveat 6; legacy v2.1 supersession noted
  in the data table.
- Two Nashville full-990 filers with private-foundation code 4 reported in
  `output/explore-6-national.txt` and noted in the memo; not reclassified.
- Attrition "21% vs peer median 20%" now stated as close to peers.
  Dettwiller stated at $251M. "Seven to eight in ten under $50,000" replaced
  with the range among organizations reporting a revenue figure and the
  share with no figure, since missing revenue is no longer counted as zero.
- Balanced human services net-asset months stated as 9.6 to 10.8.
- "Both are current" replaced: the density layer is current, the spending
  layer is TY2023; the TY2024 extension is described as not yet done.
- The 2020-2021 contribution-share jump and expenses-exceed-revenue dip
  remain in the by-year outputs and are not presented as Nashville-specific.

Not done, and why:

- The exit cohort has not been traced into the 990-EZ (CORE merged tier).
  That is the next step before finding 5 is cited; it is outside this pass.
- Alternate pay trimming bounds were not tested. Valid sample sizes are now
  reported beside every median; bounds remain nominal and pre-deflation.
- Peer-county definition was not replaced with a city definition; the
  limitation is stated instead.

## Follow-up (`RESPONSE-REVIEW.md`, same day)

| # | Item | Action |
|---|---|---|
| 1 | Comparator still inconsistent (Tennessee assigned before peer membership; explore-10 redefined `grp`) | Partition fixed and documented in `explore-6`: Nashville / Peer metros (all 19, incl. Memphis and Knoxville, 29,587 filers in 2023) / Rest of TN (Tennessee outside the 20 metros, 1,620) / Rest of US. `explore-10` now only splits Nashville into Davidson and collar and otherwise keeps the panel's `grp`. Memo rows regenerated: peer-metro employee growth +17.9% (was +19.3%), rest of TN line 1e 19.2%, peer HMS line 1e 21.6%, exit-gap intervals re-drawn. |
| 2 | Hash provenance incomplete; cached national BMF; raw CSVs not byte-verified | Peer-state and national BMF pins now carry the manifest vintage, git sha and parquet sha256. The national slim read is no longer cached; it is re-read and pinned every run. `build-panel.R` hashes all 24 raw CSVs and stops on any mismatch with `_efile_inputs.csv` (verified: 24 files). |
| 3 | ZIP sentence contradicted its table | Rewritten: Antioch and North Nashville two large organizations each, South Nashville eight, Midtown 32. |
| 4 | Causal language stronger than the checks | "partly a TY2023 coverage effect" is now "may partly reflect incomplete TY2023 coverage; how much is not established". "Part of the rise is composition" is now "the cross-sectional rise exceeds the within-organization change; composition is one possible explanation". Caveat 8 no longer claims equal blank rates make comparisons less exposed. |
| 5 | Validation script tests the old algorithm | Renamed `review-validation-original-defect.R` with a header saying it is a historical reproducer expected to fail. New `validate-build.R` (run last by `run-all.R`) asserts panel uniqueness by key and filing id, re-derives the selection from raw Part I and checks the filing-id sets match exactly (3,174,130 both ways, 0 differences), and checks every filing has a Part IX row with the same EIN and year. Passed. |

Full chain rerun via `run-all.R` on 2026-10-12 (log in `output/run-all.log`).

## Exit cohort traced (same day)

The deferred item is done (`explore-11-exit-trace.R`, `explore-12-coverage.R`).
Of the 128 metro leavers, 58 filed a full 990 for TY2023 that is in the SOI
extract (CORE) but not in the e-file release, 17 filed a 990-EZ, and 53 have
no TY2023 or TY2024 return. The pay gap for the 53 (42 with a valid value)
is $17,200 (bootstrap -$22,900 to -$7,800) against $5,200 for the same
construct in the peer metros. Caveat 2 is restated with the measured
mismatch between the e-file release and CORE for TY2023 (6% of CORE
filings absent from e-file, 5% the other way; net counts within 2%).
