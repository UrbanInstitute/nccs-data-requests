# Plan: Nashville round 2 (follow-up charts and Ecosystem Map profile)

Status: draft for senior researcher review. Deadline from the requester is
2026-11-13; internal delivery target 2026-11-09. Written 2026-10-19.

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
| E | Profile of the roughly 100 organizations in the team's Ecosystem Map: age, starts and exits, median operating expenses, government grant share, inflation-adjusted spending, reported employees | New ask; EIN list not yet received |

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
- Charts as PNG in `output/`, built in a new `explore-13-charts.R`.
- Profile built in `explore-14-profile.R` from an EIN list kept in the
  gitignored `data/` folder (requester-supplied, not public).
- Everything reproducible from the folder with `run-all.R`.

## Schedule

| Date | Step |
|---|---|
| 2026-10-21 | Plan agreed with reviewer; charts A to D built from existing panel |
| On receipt of EIN list | Profile built, coverage checked |
| 2026-10-30 | Draft findings to reviewer |
| 2026-11-06 | Reviewer comments addressed; second-analyst code review |
| 2026-11-09 | Delivered to requester |
| 2026-11-13 | Requester's deadline |

Estimated effort: 8 to 10 hours of analyst time, about 2 hours of
reviewer time across the plan and the findings.
