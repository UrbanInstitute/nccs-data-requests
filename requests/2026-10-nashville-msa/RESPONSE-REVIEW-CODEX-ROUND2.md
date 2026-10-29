# Response to the second-analyst review of round 2 (2026-10-29)

A second analyst (Codex) reviewed the approach, code, findings and next
steps against REVIEW-PROMPT terms set the same day. Eighteen findings. Each
was reproduced from the data before acting. Accepted and fixed, accepted as
wording, or not confirmed, with the evidence.

| # | Finding | Checked | Disposition |
|---|---|---|---|
| 1 | Reviewer comments acknowledged but changes unimplemented; an uncommented brief is not approval | True: the changes are for the round 2 write-up, not yet drafted | Accepted. The write-up will carry each change; the three method questions go back to the reviewer explicitly with the draft rather than treated as approved. |
| 2 | HOS/UNI by code misses a university with $243.7M expenses | Confirmed: Lipscomb University carries an undefined NTEE code; a second institution (Richmond, The American International University in London, Nashville office) likewise | Fixed in `explore-13-charts.R`: the flag is the code plus two EINs found by listing full-990 filers with undefined codes and expenses over $20M. Stated in the script and to be stated in the write-up: identification is by code with a hand-checked supplement, not exact. |
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
