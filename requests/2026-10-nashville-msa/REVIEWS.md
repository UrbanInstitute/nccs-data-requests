# Reviews and responses, in date order

Review texts and prompts are in `reviews/`. This file holds every response,
in the wording of the day. Script names changed in the 2026-10-29
consolidation; read the old names as follows.

| Old name | Now |
|---|---|
| `build-panel.R`, `build-external.R`, `build-peers.R`, `build-funders.R` | `build.R`, one section each |
| `explore-1` to `explore-12` (except 4, dropped) | `analysis-round1.R`, one pass each |
| `explore-13-charts.R` | `profile-charts.R` |
| `explore-14-profile.R` | `profile-list.R` |
| `explore-15-funders-listed.R` | `profile-funders.R` |
| `output/explore-N-*.txt` | `output/analysis-round1.txt` |
| `review-*.R`, `REVIEW*.md`, `REVIEWER-BRIEF.md` | `reviews/` |


<!-- formerly RESPONSE-TO-REVIEW.md -->

## Response to REVIEW.md (2026-10-12)

Every finding was accepted. What changed, finding by finding, and what the
rebuilt numbers show. All outputs in `output/` were regenerated from the
new build; the Nashville endpoint figures are unchanged except TY2022
employees (68,518 to 68,522).

| # | Finding | Action | Where |
|---|---|---|---|
| 1 | Nondeterministic filing selection; parts could mix | Filing chosen once on Part I (timestamp desc, OBJECTID desc); Part IX joined on OBJECTID; build asserts filings = unique keys = unique filing ids and zero identity mismatches (3,174,130 each, 0 mismatches). `review-validation.R` still exits non-zero because it re-implements the old two-stage algorithm to count ties; its panel-level checks (uniqueness, zero unmatched grants rows) pass. Filing-selection semantics noted as a candidate to route upstream in `checklist.md`. | `build.R` (section build-panel), `output/build-panel.txt`, `output/review-validation.txt` |
| 2 | Davidson 1st-place pay ranking not robust | Memo table now carries 2019-2022 beside 2019-2023 for every growth figure and states Davidson is 6th through 2022 (Cincinnati leads). Employee declines described as observed in this release, flat through 2022. The 2022-2023 count declines are given as declines, not completeness rates. | `analysis-round1.R` (pass 9) (sensitivity block), `request.qmd` finding 5, caveat 2 |
| 3 | Line 1e overstated as government funding; wrong county subsector figures; rank | All language changed to "reported line 1e government grants"; definition states line 2 exclusion. Human services county shares now computed and used (Williamson 1.4%, Rutherford 3.1%; all-charity 3.6% and 4.9% given separately). Rank corrected to 13th of 20, computed excluding the Rest of US row. Peer-metro and national comparators both shown. "84 to 96% government funded" rewritten as share of revenue reported on line 1e. | `analysis-round1.R` (pass 7), `analysis-round1.R` (pass 9), `request.qmd` finding 4 |
| 4 | "Months of reserves" is net assets | Renamed "net assets in months of expenses" with the restricted/fixed-asset caveat and a statement that it is not comparable with the survey's cash-on-hand figures. "Deficit" renamed "expenses exceed revenue". Column names in scripts changed to `exp_gt_rev` and `med_na_months`. | `request.qmd` definitions, findings 5 and 6; scripts 2, 3, 6, 9 |
| 5 | ZIP ranking contradicted the formation story | Headline "formation away from large institutions" deleted. Table re-ranked on recognitions since 2020, with Midtown (37203) shown third, human services among recent recognitions counted separately from all active human services, and a count of organizations with assets over $10M. Text now says "recently recognized organizations currently located in these ZIPs". | `analysis-round1.R` (pass 8), `request.qmd` finding 2, caveats 5 and 7 |
| 6 | National comparator changed across scripts | One definition: Nashville / Rest of TN / Peer metros / Rest of US (outside the 20 metros and outside TN), set in `explore-6` and carried in `panel_charities.parquet` so scripts 7, 9, 10 inherit it. Memo tables now show Peer metros and Rest of US as separate rows with the regenerated values. | `analysis-round1.R` (pass 6), `analysis-round1.R` (pass 7) |
| 7 | Exit-cohort evidence weaker for Davidson | Exit table moved into `explore-6` with valid-pay counts and a 2,000-resample bootstrap interval on the median gap for metro, Davidson, peer metros and Rest of US. Memo reports the intervals, says the Davidson gap is not distinguishable from zero, and drops the closure/decomposition interpretation. Caveat 4 cross-reference fixed. | `analysis-round1.R` (pass 6), `request.qmd` finding 5 |
| 8 | Volunteer labels mixed denominators | Every volunteer column now names its denominator (positive count; any value incl. zero; positive reporters with staff). The "11th of 20" rank is dropped in favor of the range. Balanced panel labeled as positive-in-both-years. The two organizations behind half the decline are named with their contribution. | `analysis-round1.R` (pass 10), `request.qmd` finding 6, caveat 9 |
| 9 | QCEW nominal vs real; measures not comparable | QCEW converted to 2023 dollars in `explore-9` (NAICS 624: $36,945 to $41,547, +12.5%); "kept pace for the same work" deleted; caveat 10 added on the per-job vs per-head basis. | `analysis-round1.R` (pass 9), `request.qmd` finding 5 |
| 10 | Reproducibility overstated | `build.R` (section build-external) now downloads Census, QCEW and the Phase 0 parquet (sha256 checked against its manifest) and derives `county_pop.csv`. Every pin carries a sha256; the BMF pin carries the manifest vintage, git sha and parquet sha256. Crosswalk sha256 pinned on every run. `run-all.R` is the entry point and starts a fresh `_pins.csv`. The memo now says "reproducible from its inputs as identified, not from the folder alone" and names the rolling BMF as the remaining non-immutable input. | `build.R` (section build-external), `build.R` (section build-panel), `run-all.R`, `INPUTS.md` |
| 11 | Broken coverage check; blank-as-zero unverified | Join indicator added from the right-hand table; build stops if any row is unmatched (none are). Blank share reported by group and year (Davidson 63% in 2023; Rest of US 63%). Blank-as-zero stated as an assumption in the script header and caveat 8. Individual share cap removed; rows with share over 1 are counted and reported instead (Nashville 1 in 2023). | `analysis-round1.R` (pass 7), `request.qmd` caveat 8 |
| 12 | Top-five employer diagnostic selected three | Pivot by EIN with names attached afterwards; selection on 2019 employment. The corrected diagnostic (five largest 2019 employers fell 11,009 to 7,759; all others rose 10,873 to 12,226) is in the output and not used in the memo. | `analysis-round1.R` (pass 6) |

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
| 2 | Hash provenance incomplete; cached national BMF; raw CSVs not byte-verified | Peer-state and national BMF pins now carry the manifest vintage, git sha and parquet sha256. The national slim read is no longer cached; it is re-read and pinned every run. `build.R` (section build-panel) hashes all 24 raw CSVs and stops on any mismatch with `_efile_inputs.csv` (verified: 24 files). |
| 3 | ZIP sentence contradicted its table | Rewritten: Antioch and North Nashville two large organizations each, South Nashville eight, Midtown 32. |
| 4 | Causal language stronger than the checks | "partly a TY2023 coverage effect" is now "may partly reflect incomplete TY2023 coverage; how much is not established". "Part of the rise is composition" is now "the cross-sectional rise exceeds the within-organization change; composition is one possible explanation". Caveat 8 no longer claims equal blank rates make comparisons less exposed. |
| 5 | Validation script tests the old algorithm | Renamed `review-validation-original-defect.R` with a header saying it is a historical reproducer expected to fail. New `validate-build.R` (run last by `run-all.R`) asserts panel uniqueness by key and filing id, re-derives the selection from raw Part I and checks the filing-id sets match exactly (3,174,130 both ways, 0 differences), and checks every filing has a Part IX row with the same EIN and year. Passed. |

Full chain rerun via `run-all.R` on 2026-10-12 (log in `output/run-all.log`).

## Exit cohort traced (same day)

The deferred item is done (`analysis-round1.R` (pass 11), `analysis-round1.R` (pass 12)).
Of the 128 metro leavers, 58 filed a full 990 for TY2023 that is in the SOI
extract (CORE) but not in the e-file release, 17 filed a 990-EZ, and 53 have
no TY2023 or TY2024 return. The pay gap for the 53 (42 with a valid value)
is $17,200 (bootstrap -$22,900 to -$7,800) against $5,200 for the same
construct in the peer metros. Caveat 2 is restated with the measured
mismatch between the e-file release and CORE for TY2023 (6% of CORE
filings absent from e-file, 5% the other way; net counts within 2%).

## Foundation-count review (2026-10-19)

A second review checked the Davidson County private foundation counts
prepared for a requester follow-up question. Findings and fixes:

- Counts reproduced exactly (405 active; 73 ruled 2023+; 53 ruled 2015-19;
  by year 18, 10, 8, 20, 26, 21, 18, 8). Foundation code set (2, 3, 4,
  stored unpadded) confirmed correct.
- "Active today" was overstated: `last_year_in_bmf >= 2026` admits
  organizations absent from the latest month (July 2026). Requiring the
  latest month gives 397 active, 72 ruled 2023+, 51 ruled 2015-19. The reply
  uses "about 400" and the tighter period counts.
- The 2026 rulings run through April in this build, not eight months.
- The peer-comparison table in `analysis-round1.R` (pass 8) computed period shares
  after filtering to rulings from 2010 on, while its label said "share of
  each metro's PF stock". Fixed: the denominator is now the full active
  stock, with pre-2010 as its own row. Corrected shares for 2023-26 are
  22.5% (Nashville) and 23.1% (pooled peers); the "same as peers" statement
  survives, the magnitude in the old output did not.
- Annual rulings peak in 2023 in both Nashville and the peers and fall in
  2024 and 2025. Whether that fall is real or registry lag cannot be told
  from this data. The reply describes a 2023 peak shared with the peer
  metros, not a "national" or "sustained" rise. The round 1 memo sentence
  "more Davidson foundations recognized since 2023 than in the whole of
  2015 to 2019" is numerically true but will be reworded in round 2 to
  carry the peer comparison and the lag caveat.
- A mailing-address county check was requested but the universe carries
  no separate mailing county; dropped.


<!-- formerly RESPONSE-REVIEW.md -->

## Verification of RESPONSE-TO-REVIEW.md

Reviewed 2026-10-12 against the revised scripts, saved outputs, pins, and local parquet. Most substantive revisions are implemented. I would not mark findings 6 and 10 closed yet. No analysis files or outputs were changed in this verification.

1. **The shared comparator is still inconsistent.** `explore-6-national.R:34-37` assigns Tennessee before peer membership. Its 2023 peer group excludes 832 Memphis organizations and all 576 Knoxville organizations, retaining only 69 non-Tennessee Memphis organizations. The group has **28,179 filers**, whereas all 19 peer metros have **29,587**. Recomputing from the rebuilt panel gives 2019-2023 employment growth **17.9% for all 19 peers**, versus **19.3% for the implemented group** (reported as +19% in `request.qmd:277`). More importantly, `explore-10-volunteers.R:8-10` overwrites `grp` using metro alone: its national comparator includes Tennessee organizations outside the metros, contrary to the revised definition, while its peer comparator includes all 19 peers. Thus RESPONSE-TO-REVIEW.md row 6's statement that scripts 7, 9, and 10 inherit one definition is incorrect. Decide whether these are overlapping named comparison populations or a mutually exclusive partition, then compute and label each consistently. **Confidence: confirmed by reading and rerunning.**

2. **Hash provenance and cache handling remain incomplete.** RESPONSE-TO-REVIEW.md row 10 says every pin carries a sha256, but the peer-state and national BMF rows in `_pins.csv` contain neither hashes nor manifest identities. `explore-6-national.R:14-18` skips logging the national input when its cache exists. On a future run, `run-all.R` starts a fresh log while this script can silently mix an older cached national BMF with freshly read Tennessee/peer geography. The raw e-file check in `build.R` (section build-panel) compares only the manifest's filenames with the 24 expected filenames; it does not compare the actual CSV bytes with the recorded hashes. Phase 0's actual hash verification is implemented, which is a useful improvement, but cannot stand in for the other inputs. Validate and record each actual cached input on every run, and verify the raw CSV hashes rather than only manifest coverage. **Confidence: confirmed by reading.**

3. **The ZIP narrative contains a direct numerical contradiction.** `request.qmd:216-217` says the two leading ZIPs and North Nashville have two large organizations each. The table immediately above gives South Nashville **eight**, not two (`request.qmd:206`). Rewrite as: “Antioch and North Nashville have two each; South Nashville has eight, compared with Midtown's 32.” **Confidence: confirmed by reading the revised table and saved output.**

4. **Some interpretations remain stronger than the checks establish.** `request.qmd:281-282` says the employment fall is “partly a TY2023 coverage effect”; the alternate endpoint establishes sensitivity, not the fraction explained by coverage. Use “may partly reflect incomplete TY2023 coverage.” `request.qmd:296` still opens with “Part of the rise is composition,” despite the response saying the decomposition interpretation was dropped. Use “The cross-sectional rise exceeds the median within-organization change; composition is one possible explanation.” Caveat 8's claim that similar blank shares make comparisons less exposed also needs qualification: equal missingness rates do not establish equal missing dollar amounts or equal reporting mechanisms. **Confidence: confirmed by reading; causal explanations remain unverified.**

5. **The validation script is now a historical reproducer, not a passing check of the fixed build.** The response correctly explains why `review-validation.R` still fails: it runs the old selection algorithm. Keep it as a clearly named reproduction of the original defect, but provide an active check that validates the revised shared-filing selection. A nonzero old-algorithm result should not be presented as a current build failure. **Confidence: confirmed by reading.**

Verified improvements: the revised build selects Part I once with an OBJECTID tie-breaker, joins Part IX by OBJECTID, and checks identity. Independently inspecting the rebuilt panel confirms **3,174,130 rows, EIN-year keys, and filing IDs**; its build output reports zero identity mismatches and zero missing Part IX rows. The revised rank sensitivity, narrower line 1e language, county subsector figures, government-share rank, net-assets labels, exit uncertainty, volunteer denominators, QCEW deflation, and top-five employer diagnostic address the original findings. I did not repeat the full network rebuild or certify every regenerated table.

Before sharing: resolve the comparator and cached-input provenance issues, fix the ZIP sentence, and soften the remaining causal language. The explicitly deferred EZ tracing, alternative pay bounds, and city/county comparison can remain listed limitations for an exploratory memo.


<!-- formerly RESPONSE-REVIEWER-ROUND2.md -->

## Response to the senior researcher's review (received 2026-10-29)

Teresa reviewed the round 1 memo (`docs/Initial Memo_tterese_review.docx`,
ten comments) and returned the round 2 reviewer brief without comments or
edits. Her covering email gave five summary points. Every comment is
accepted. This table says what changes in the round 2 write-up and build.
Her three method questions in the brief were not answered directly; the
comments imply answers, noted at the end.

| # | Comment (memo location) | Action | Where |
|---|---|---|---|
| 4 | The 5,100 / 4,500 / 400 registry counts need context: how many file a full 990, a 990-EZ, a postcard. The registry overstates active organizations. | Add a coverage table at the top of the round 2 section: Davidson registry count, then the number observed filing a full 990, a 990-EZ, or a 990-N for TY2023 (CORE merged tier plus e-file), and the remainder with no filing seen. Every later table names its filing population in the column header. | `profile-charts.R` (coverage block), `request.qmd` round 2 opening |
| 5 | Hospitals and universities excluded without justification; are they identifiable reliably? | They are identified by the NTEE-V2 subsector code (HOS, UNI) on the registry, not by name, so identification is exact to the coding. Justification to state: they are few, very large, and dominate spending and employee totals, so including them turns every Davidson aggregate into a statement about a handful of institutions. Round 2 shows the main tables both ways (all 501(c)(3), and excluding HOS/UNI) so the reader can see the effect, and names the count excluded. | `profile-charts.R`, `request.qmd` definitions |
| 11 | "Recognized" must be tied to one source (registry or filing). | "Recognized" is used only for the registry ruling date. Filing-based statements say "filed". A definitions line states this. | `request.qmd` definitions |
| 12, 23 | "One in five active in 2019 no longer on the registry" must be reconciled with the finding that half of apparent full-990 leavers are a release artifact. | Exit definition rewritten: an organization "exits the registry" when it is absent from the current registry after being present in a 2019 vintage; an organization "stops filing" when no return of any type appears in CORE for two consecutive years after its last return. The two series are reported separately and never summed. The release-artifact finding applies only to the e-file series and is said so. | PLAN.md method question 1 (answered as proposed, with the two-year rule), `profile-charts.R` exits block |
| 15 | "Grown 39 percent": metric unstated. | Say "population, Census county estimates 2010 to 2023". | `request.qmd` finding 2 |
| 16, 17 | Employment counts on the 990 are noisy, possibly more so for new organizations; location is the postal address, so a Davidson organization may operate in Williamson. Prefer metro-level comparisons. | Metro-level figures lead every workforce and location finding; county figures follow as secondary with the postal-address caveat in the same sentence. The Rutherford vs Davidson employees-per-resident comparison is kept only as a metro-wide pattern statement. Employee-count noise added to the caveats, with the age split shown as a check (employees per $1M expenses for organizations recognized before vs after 2015). | `request.qmd` findings 2 and 5, caveats |
| 24 | "Paying well" undefined. | Replace with "spending per reported employee on salaries, benefits and payroll taxes (Part IX lines 5 to 10)". | `request.qmd` finding 5 |
| 25 | "Spending more than they took in" must say revenue minus expenses is negative. | Say "total expenses exceeded total revenue (Part I line 18 greater than line 12)". | `request.qmd` finding 5 |

Comments 0, 2, 6, 7, 9, 13, 18, 20 and 22 are the requester team's
comments already answered or scheduled (PLAN.md items A to D); comment 22
(how much is COVID response and ARPA) is answered by chart C and the
caveat that the 990 cannot separate federal relief from other grants.

## Implied answers to the three method questions

1. Exits: comments 12 and 23 call for one clean definition and a
   reconciliation. Proceed as proposed in the plan (filing-based primary
   series through 2022, registry-vintage series as a check), with the
   separation above.
2. Profile comparator: no comment. Proceed with both comparators, headline
   on all Davidson charities, and show the HOS/UNI effect.
3. 990-EZ filers in the profile: comment 4 supports reporting coverage by
   form type for every measure. Proceed with inclusion and a coverage
   column. The spreadsheet fill stays full 990 only, as the requester asked.

## Design rule for round 2

Every table and chart carries its filing population in the title or first
column: registry, full 990, 990-EZ, 990-N, or a named combination.


<!-- formerly RESPONSE-REVIEW-CODEX-ROUND2.md -->

## Response to the second-analyst review of round 2 (2026-10-29)

A second analyst (Codex) reviewed the approach, code, findings and next
steps against REVIEW-PROMPT terms set the same day. Eighteen findings. Each
was reproduced from the data before acting. Accepted and fixed, accepted as
wording, or not confirmed, with the evidence.

| # | Finding | Checked | Disposition |
|---|---|---|---|
| 1 | Reviewer comments acknowledged but changes unimplemented; an uncommented brief is not approval | True: the changes are for the round 2 write-up, not yet drafted | Accepted. The write-up will carry each change; the three method questions go back to the reviewer explicitly with the draft rather than treated as approved. |
| 2 | HOS/UNI by code misses a university with $243.7M expenses | Confirmed: Lipscomb University carries an undefined NTEE code; a second institution (Richmond, The American International University in London, Nashville office) likewise | Fixed in `profile-charts.R`: the flag is the code plus two EINs found by listing full-990 filers with undefined codes and expenses over $20M. Stated in the script and to be stated in the write-up: identification is by code with a hand-checked supplement, not exact. |
| 3 | Coverage table should lead but cannot separate postcards from other unobserved returns | True: nothing on disk carries 990-N filings | Accepted as wording: the category is "no return seen (990-N postcard, late, or not filing; the releases do not say which)". |
| 4 | Rows 14, 75, 110 need entity confirmation; row 21 differs between workbook and match file | Rows 14, 75, 110 were already marked medium or low and are in the note to the requester (14) or flagged in the sheet. Row 21 is identical in both files (UTF-8 accented characters; the difference is a reader encoding issue) | Accepted for 14, 75, 110 (no change). Not confirmed for 21. |
| 5 | All 89 filled values are e-file; CORE adds no rows | True | No change. CORE stays as the cross-check. |
| 6 | The period-month rule fails for short periods | Confirmed at a small rate: 25 of 6,997 CORE full-990 rows matched to an e-file row on EIN and expenses disagree, nearly all short periods | Mitigated: e-file (which carries the IRS form year) now takes precedence over CORE wherever both hold a filing in `explore-13` as it already did in `explore-14`; the rule applies only to CORE-only rows, and the caveat is recorded in the script header. |
| 7 | Later recognition does not establish no 2023 return | True in principle | Fixed wording: "Recognized in 2024 or later; no tax year 2023 return seen". |
| 8 | Full-990-only sheet is consistent with the ask | Agreed | No change. |
| 9 | Coverage counts reproduce | Agreed | No change. |
| 10 | Remove the provisional 12.3% bar; two-year gaps are filing interruptions, not exits | Agreed | Fixed: chart shows judged years only; title and subtitle now say "two-year filing gap" and "not a confirmed closure". The provisional row stays in the CSV, labelled. |
| 11 | Median $340,177 (all) / $332,850 (excl. HOS/UNI); under-$1M share rounds to 71, not 72 | Confirmed; the 72 was from a run before zero-expense rows were dropped | Table regenerated; medians now $339k and $332k with the wider HOS/UNI flag. |
| 12 | Grant share percentages reproduce; series rebounds in 2023; median organization-level share is zero 2021-2023 | Agreed | Write-up will say the aggregate share is dollar-weighted and that most filers report nothing on line 1e (the share-reporting column is already in the table). |
| 13 | Employees fall 0.8% among consistent filers vs 5.9% in the changing population | Confirmed: 627 organizations present in both 2019 and 2023, employees -0.8%, real spending +7.7%; through 2022, 693 organizations, employees -2.8%, spending +4.0% | Fixed: sensitivity table added (`chart_f_balanced_sensitivity.csv`); the write-up will lead with the balanced figures. |
| 14 | 85 Schedule I rows use provisional name matching, 11 overriding supplied EINs | Confirmed: 127 rows in the extract where the provisional match differs from a supplied nine-digit EIN | Fixed: the EIN as filed takes precedence; the provisional match applies only where no nine-digit EIN was supplied, and the route is labelled per row (74 provisional rows remain over five years). |
| 15 | Individual flag and deduplication work; PF amounts are assigned wholesale to cash | Confirmed: 990-PF grants paid carry a single amount | Fixed: `amount_total` is the comparable column; cash and noncash are reported for Schedule I rows only; PF reported as a single amount. |
| 16 | All 3,678 Schedule I hit rows lost the recipient identifier; recipients reached were undercounted; recipient geography exceeds Davidson | Confirmed: the join consumed the EIN column, so Schedule I recipients were NA and "reached" counted PF matches only | Fixed: identifier preserved with an assertion that none is missing. Scope applied: recipients are the 114 listed organizations registered in Davidson; the 12 registered elsewhere are reported as out of scope. Reached rises from 94 to 102 of 114; funders 233; top ten funders 70% of matched dollars. |
| 17 | Corrected coverage: 883 e-file vs 652 CORE, all overlapping; 231 e-file-only; the symmetric 5-6% claim is wrong | Confirmed (883 / 649 / 0 CORE-only / 234 e-file-only in this reproduction; 197 of the e-file-only have their June-year return in CORE's period-end-2023 file, i.e. form 2022, and their form-2023 return is in the partial 2024 release) | Accepted: checklist.md corrected; explore-12's claim is to be restated as "the CORE 2024 release is partial for fiscal-year filers" when the write-up is drafted. |
| 18 | Fix identifiers, scope, year handling, denominators and wording before the draft; reserve method choices for the reviewer | Agreed | Done above except the write-up itself. |

Not changed on the second analyst's advice alone: the hand match decisions
(finding 4) stay as recorded, with their confidence levels going to the
requester for confirmation.


<!-- second-analyst review, round 2 fixes, 2026-10-29 (second pass) -->

## Response to the second-analyst re-review (2026-10-29, second pass)

Five findings after the first set of fixes. Each reproduced before acting.

| # | Finding | Checked | Disposition |
|---|---|---|---|
| 1 | The round 1 exit-artifact explanation is wrong: the 58 CORE returns read as "2023 full 990 missing from the e-file release" are June-year returns for form year 2022 | Confirmed: the exit trace (pass 11) used CORE's period-end year. Relabeled to form year, the category empties. Of 128 metro leavers, 76 last filed for 2022, 17 for 2021, 13 switched to the 990-EZ, 22 have no return since 2020. The genuine-leaver pay gap becomes about $9,600 per head (102 organizations; interval about $3,800 to $14,000), not $17,200 | Fixed in `analysis-round1.R` pass 11 (and pass 12, which now also reads the 2024 file). The round 1 memo sentence "nearly half of them did file for 2023 and are simply missing from the IRS release" is withdrawn and the correction goes to the reviewer and the requester with the round 2 draft. |
| 2 | The two universities added by EIN stayed in the grant-share and workforce populations | Confirmed: $274.6M expenses and 2,826 employees in 2023; all-charity grant share 14.78% with them, 15.50% without | Fixed: `profile-charts.R` removes the supplement EINs from the charity panel before sections E and F. Balanced-panel employee change is now -0.6% (2019 to 2023). |
| 3 | Short-period misdating survives source precedence when the two labels put one filing in different years | Confirmed at a small scale: 3 Davidson full-990 filings | Fixed: a CORE copy of any filing the e-file panel holds (same EIN, total expenses and total revenue) is dropped whatever year it was assigned. |
| 4 | PLAN.md still describes the full-990-only sheet with 89 figures | True | Fixed: deliverable 1 now states the three forms and lines, the source column, and 106 figures. |
| 5 | A moved review helper has stale run instructions and pins to reviews/_pins.csv | Confirmed | Fixed: instructions say run from `reviews/`; the pin goes to the request's `_pins.csv` one level up. |


<!-- second-analyst review of the round 2 draft text, 2026-10-29 -->

## Response to the second-analyst review of the round 2 draft (2026-10-29)

Seven findings on the round 2 section of `request.qmd`. All accepted.

| # | Finding | Checked | Disposition |
|---|---|---|---|
| 1 | The public qmd identifies members of the confidential list through affiliation descriptions and named funders | True | Funder names, the description of how the list was assembled, and the unmatched-organization detail removed from the qmd; they stay in the private deliverable (the filled sheet and the funder table). |
| 2 | Earlier sections keep the withdrawn coverage figures, institution-inclusive results and the obsolete 42-organization next step | True | Caveat 2 restated; finding 4's table and sentence carry the 15.5% figure beside the old one with the reason; the employee paragraph now gives the balanced-panel share; the next-step bullet names 102 organizations. |
| 3 | "Every SOI filing" holds only for Davidson (227 CORE-only cases elsewhere); "genuine leavers" and "no return anywhere" overstate; four short-period records still misdated | True | Wording narrowed to Davidson and to "no return in either release"; the short-period limit is stated in the corrections because the SOI extract carries no period start. |
| 4 | Expense table's full-990 row included institutions | Confirmed: 888 and $655k with them, 875 and $632k without | Fixed in `profile-charts.R` and the table. |
| 5 | Institution count is 13, not 11; PF dollars $18.9M (2021) and $19.1M (2022) | Confirmed from the outputs | Fixed. |
| 6 | Grant-share series cannot establish when the gap began; changing membership explains about 91%, not all, of the employee decrease | True | Reworded both. |
| 7 | Chart paths displayed as filenames | True | Five charts embedded as images; the Word render carries them. |
