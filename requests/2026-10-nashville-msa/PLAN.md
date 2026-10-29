# Plan: Nashville round 2 (follow-up charts and Ecosystem Map profile)

Status: reviewer (Teresa) comments received 2026-10-29, logged in
`REVIEWS.md`. Requester's list of 141 organizations
received 2026-10-23 and matched 2026-10-29 (`profile-list.R`).
Deadline from the requester is 2026-11-13; internal delivery target
2026-11-09. Written 2026-10-19; scope reset 2026-10-23.

## Scope as reset by the requester (2026-10-23)

Two deliverables replace items A to F below as the frame; the items
survive as the pieces of deliverable 2.

1. **The requester's spreadsheet, filled.** Tax year 2023 total expenses
   (full Form 990 Part I line 18) for each listed organization that filed a
   full 990; for the rest, a status saying why there is no figure (not
   matched, private foundation, 990-EZ, church, no 2023 return yet with the
   latest year seen). Full 990 only, as asked; 990-EZ totals are held in the
   detail file and offered, not written in. Done 2026-10-29: 89 of 141 have a
   figure, 15 are unmatched and go back to the requester.
2. **A sector health profile** of the Nashville (Davidson County) nonprofit
   and philanthropic sector: narrative, tables and charts covering age,
   starts and apparent exits (limits stated), median operating expenses,
   government grant share of revenue (2020 to 2023; line 1e excludes
   contracts), inflation-adjusted spending, reported employees, and who
   funded whom in tax years 2019 to 2023 matched to the listed organizations,
   with a narrative on overlap and gaps that states the evidentiary limits.
   The funder piece is narrowed to Nashville-based funders giving to
   Nashville-based listed organizations; the full `build.R` (section build-funders) extract
   (recipients anywhere) stays as the source and is not itself delivered.

Reviewer's design rule for every table and chart: name the filing
population (registry, full 990, 990-EZ, 990-N, or a combination).

## What is being asked

Round 1 (`request.qmd`, sent early October) was a first look at IRS data on
Nashville nonprofits: Davidson County and the 14-county metro against 19
peer metros and the rest of the country, using the Business Master File
(BMF) for counts and locations and full Form 990 e-filings for finances and
workforce, tax years 2019 to 2023.

The requester's team returned nine comments. Three are clarifications
answered in the document. The rest are new work, plus one new ask:

| # | Ask | Source |
|---|---|---|
| A | Starts by year for Davidson County, as a chart; an exits chart if possible | Comment 2 |
| B | Distribution of operating expenses by percentile, all Davidson charities and human services, to show how small most organizations are | Comments 3 and 4 |
| C | Government grant share of revenue, year by year 2019 to 2023, Davidson against peers and the US, with the pandemic-era peak visible | Comments 7 and 8 |
| D | Optional: filers, inflation-adjusted spending, and employees 2019 to 2023 as one chart | Comment 9 |
| E | Profile of the roughly 100 organizations in the team's Ecosystem Map: age, starts and exits, median operating expenses, government grant share, inflation-adjusted spending, reported employees | New ask; list of names and addresses (no EINs) not yet received |
| F | Who funds whom: grants reported by Davidson-based funders on their own returns, 2019 to 2023, matched to the Ecosystem Map list | Third ask, approved 2026-10-21 |

## Measures and sources

Definitions match round 1 (`request.qmd`, Definitions and Limitations).
New or changed items are marked.

| Measure | Source | Line | Who it covers |
|---|---|---|---|
| Age | BMF ruling date (date of exemption, not founding) | ruling_date | All registered organizations |
| Starts by year | BMF ruling year, organizations still active | ruling_date | All registered |
| Exits by year (new) | See method question 1 | | Depends on method |
| Operating expenses (new) | Full 990 Part I line 18 and 990-EZ line 17, total expenses; PF Part I line 26 if any foundations are on the list | | Full 990 and EZ filers; not 990-N |
| Government grant share | Full 990 Part VIII line 1e over total revenue; blank treated as zero (caveat 8) | 1e | Full 990 only |
| Inflation-adjusted spending | Total expenses, CPI-U to 2023 dollars | | Full 990 (and EZ for the profile) |
| Reported employees | Full 990 Part I line 5 | 5 | Full 990 only |
| Grants paid by public charities (new, F) | Schedule I Part II, e-file v2.1; recipients receiving more than $5,000 in aggregate in the year; cash and noncash kept separate; recipient EIN on most rows | Sch I | Full 990 filers that make grants |
| Grants paid by private foundations (new, F) | 990-PF grants paid (Part XIV on the 2023 form, Part XV earlier; table keeps the PF-P15 name), e-file release `efilepf_v2_3`; recipient name and address, no EIN; grants to individuals flagged and excluded | PF Part XIV/XV | 990-PF filers |

Expenses rather than revenue is used for size throughout; revenue swings
with one-time gifts and capital campaigns.

## Comparison groups

- Davidson County charities (501(c)(3) public charities, excluding
  hospitals and universities as in round 1).
- Nashville metro (14 counties).
- 19 peer metros and rest of US, from the round 1 build.
- For the profile (E): the Ecosystem Map organizations against Davidson
  County charities as a whole, and against Davidson human services if most
  of the list is human services.

## Method choices for the reviewer

1. **Exits.** The BMF does not record when an organization is removed.
   Two ways to build an exit series, and I would like the reviewer's view:
   (a) BMF vintage snapshots: an organization "exits" in the first vintage
   year it is absent. Covers every registered organization but the series
   steps at vintage years (caveat 6) and revocation lists lag.
   (b) Last 990 filed: an organization "exits" the year after its last
   return of any type, from the CORE merged tier. Covers only filers, but
   the timing is cleaner. Round 1 showed that about half of apparent
   full-990 leavers were filing lag or coverage gaps, so (b) needs the
   same CORE cross-check and a one-year lag cut.
   Proposal: build (b) as the primary series through 2022, show (a) as a
   check, and say plainly that 2023 and later exits cannot be read yet.
2. **Profile comparator.** Compare the roughly 100 organizations with all
   Davidson charities, or only with full-990 filers of similar size and
   field? Proposal: both, with the first as the headline, since the point
   of the profile is where the mapped organizations sit in the sector.
3. **990-EZ filers in the profile.** Include them with blanks on employees
   and grants, or drop them for consistency? Proposal: include, and report
   coverage by form type for every measure, since the mapped list will be
   small enough to show which organizations are missing what.

4. **Funder table (F).** Built as outgoing giving by funders whose
   registry address is in Davidson County, wherever the recipient is.
   Funders based elsewhere are absent by construction. Recipients are
   matched to the registry by EIN where the row carries one (Schedule I)
   and by name plus city otherwise (provisional, hand-checked against the
   Ecosystem Map list when it arrives). Shared funders will be reported
   as shared funders, not as duplication; organizations with no matched
   grant will be reported as "no matched grant observed in the selected
   records", not as a gap. Donor-advised fund grants appear under the
   sponsoring organization. One filing per funder and tax year, chosen as
   in round 1. Build: `build.R` (section build-funders). First build (2026-10-21):
   73,020 records, 300 Schedule I funders and 330 foundations over the
   five years. The Community Foundation of Middle Tennessee itemized
   about 10,000 COVID-19 relief grants in 2020 (median $4,000, below the
   itemization threshold), and its record count falls each year after,
   so year-to-year record counts are not comparable for that funder.

## Caveats carried from round 1

Filing lag to tax year 2023; full 990 only for employees and line 1e;
line 1e is grants, not contracts or reimbursements, so it is not total
government funding; blank 1e treated as zero; ruling date is recognition,
not founding; current address applied to history; e-file and CORE each
miss a few percent of the other's TY2023 filings, so 2019-2023 changes are
shown alongside 2019-2022. A new caveat for the profile: a hand-picked
list of about 100 local organizations will include some that file the
990-EZ or 990-N, and those will show blanks on the workforce and grant
measures; the profile reports how many.

## Outputs

- `request.qmd` round 2 section: one short paragraph per chart, the
  profile table, and the coverage table for the profile.
- Charts as PNG in `output/`, built in a new `profile-charts.R`.
- Profile built in `profile-list.R` from the requester's name and
  address list kept in the gitignored `data/` folder (not public).
- Funder table built in `build.R` (section build-funders); grant-level parquet stays in
  `data/`, funder-year aggregates in `output/`, the matched
  funder-by-recipient table for the mapped organizations delivered with
  the profile.
- Everything reproducible from the folder with `run-all.R`.

## Schedule

| Date | Step |
|---|---|
| 2026-10-22 | Individual asks sent to candidate reviewers, supervisor and project manager copied, answer requested by 2026-10-26 |
| 2026-10-22 | Reviewer confirmed (senior researcher, Teresa); plan and schedule sent to her the same day |
| 2026-10-23 to 10-29 | Reviewer reads the plan (about half an hour) and answers method questions 1 to 3; funder table built 10-21; charts A to D built from existing panel |
| 2026-10-23 | Requester's list received (names and addresses, no EINs) |
| 2026-10-29 | Reviewer comments received and logged; list matched and spreadsheet filled; unmatched names back to the requester |
| 2026-10-30 | Draft findings to reviewer |
| 2026-11-06 | Reviewer comments addressed; second-analyst code review |
| 2026-11-09 | Delivered to requester |
| 2026-11-13 | Requester's deadline |

Estimated effort: 8 to 10 hours of analyst time for A to E, plus a
provisional 3 to 4 hours for F (depends on the name-matching step for E), about 2 hours of
reviewer time across the plan and the findings.
