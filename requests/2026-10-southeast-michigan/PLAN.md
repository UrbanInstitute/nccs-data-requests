# Plan: Southeast Michigan nonprofit fact sheet (seven counties)

Status: set up 2026-10-20. Deadline for the populated data template is
end of day Friday 2026-10-30. Christina executes the steps below; Thiya
reviews code and numbers; the requester owns the fact sheet itself.

## What is being asked

A fact sheet on nonprofits in seven Michigan counties: St. Clair,
Livingston, Oakland, Macomb, Washtenaw, Wayne, and Monroe. Every measure
is reported for the seven-county region in aggregate and for each county
on its own. The deliverable is the requester's Excel template, filled in
(in `template/`, gitignored), with a short methods note so the
requester can write the source lines and caveats. Requester identity and
the full email thread are in `_private.md` (gitignored).

Budget: 40 hours of Thiya's time, 6 of Christina's. The estimate covered
two sample-definition meetings, data assembly, all measures below, QA,
the methods note, and one round of revisions.

## The template (received 2026-10-20, in `template/`, not committed)

Nine sheets. Each has one row per geography (region plus seven
counties, except Number which has counties only) and one column per
category. Cells are presumably shares; confirm with the requester (see
the fact sheet draft confirms shares). Sources cited on the sheets: Unified BMF for the first
three, "Core PZ file" (public charities, 990 and 990-EZ) for the
financial sheets, "Core PC file" (full 990 only) for employees.

| Sheet | Categories | Source on sheet |
|---|---|---|
| Number | count of 501(c)(3) public charities, per county | BMF |
| Subsector | 10 NTEE major groups plus Unclassified | BMF |
| Age | 0-5, 6-10, 11-25, 26-49, 50+ years (requester open to changing) | BMF |
| Revenue | <$100K, $100K-499K, $500K-999K, $1M-9.9M, $10M+ | Core PZ |
| Expenses | same five bands | Core PZ |
| Operating Surplus | -20% or lower, -19.99 to -5, -4.99 to -0.01, 0, 0.1 to 4.99, 5 to 19.99, 20%+ | Core PZ |
| Assets | same five dollar bands (requester open to changing) | Core PZ |
| Liabilities | same five dollar bands (requester open to changing) | Core PZ |
| Employees | 0, 1, 2-9, 10-19, 20-49, 50+ | Core PC |

Not in the template but in the earlier email or our suggestions:
revenue breakdown, contributed revenue breakdown, filing-type mix,
nonprofits per 10,000 residents, aggregate totals, government grants,
volunteers. Treat these as out of scope unless the requester adds
sheets. The measure map below is now limited to the template.

## What the fact sheet document settles (format draft in `template/`, not committed)

The requester's draft fact sheet shows how the Excel numbers will be
used. We produce the Excel sheet only; the charts, map, and text are
theirs. It settles several questions:

- **Cells are shares.** Every figure is a distribution across ranges, so
  each sheet is percent of the denominator for that sheet.
- **Operating surplus** is net income (total revenue minus total expenses)
  divided by total revenue, as a percent. Organizations with zero revenue
  or zero net income are assigned zero. Use this definition exactly.
- **Age** is 2026 minus the IRS ruling year.
- **Sample** for the counts, subsector, and age sheets is every
  registered 501(c)(3) public charity. The financial sheets use
  "reporting" organizations, those filing a 990 or 990-EZ in the tax
  year. Employees use full-990 filers. The draft does not apply the
  Nonprofit Trends Core Sample filter anywhere, and its subsector table
  keeps universities and hospitals.
- **Subsector** rows are the ten classic NTEE major groups plus
  Unclassified, exactly as the Excel sheet lists them. Fill those rows.

The deliverable is the filled Excel sheet and nothing else. Numbers the
draft text needs beyond the sheets, and the charts, map, and prose, are
the requester's to produce or ask for separately.

## Open decisions (block the build)

1. **Sample filter.** The earlier emails said the funder had not chosen
   between all public charities and the Core Sample. The draft fact
   sheet uses all registered public charities throughout. Confirm with
   the requester that the Core Sample question is closed; if so the two
   sample meetings shrink to one.
2. **Tax year and vintages.** Financial sheets: tax year 2023 from the
   CORE series. BMF sheets: a 2026 BMF vintage, matching the age
   formula. Fill every "[Date]" and "Year" placeholder with the vintage
   or tax year used.
3. **Suppression threshold.** St. Clair and Monroe have small full-990
   counts. Proposal: suppress cells with fewer than 10 organizations and
   state the rule in the methods note.
4. **Hosting.** COMM product on urban.org or funder site. Format only.

## Measures and sources

| Sheet | Measure | Source | Who it covers |
|---|---|---|---|
| Number | Count of registered 501(c)(3) public charities | Geocoded BMF master, county from the county-fips crosswalk | All registered, including 990-N filers |
| Subsector | Share by NTEE major group | BMF NTEE | All registered |
| Age | Share by years since IRS ruling date | BMF ruling date | All registered |
| Revenue | Share by total revenue band | CORE, 990 and 990-EZ total revenue | 990 and EZ filers |
| Expenses | Share by total expenses band | CORE, 990 and 990-EZ total expenses | 990 and EZ filers |
| Operating Surplus | Share by net income over total revenue, in bands; zero if revenue or net income is zero | CORE, 990 and 990-EZ | 990 and EZ filers |
| Assets | Share by end-of-year total assets band | CORE | 990 and EZ filers |
| Liabilities | Share by end-of-year total liabilities band | CORE | 990 and EZ filers |
| Employees | Share by Form 990 Part I line 5 band | CORE, full 990 | Full 990 only |

Coverage caveat for the methods note: the first three sheets cover every
registered organization; the financial sheets cover 990 and 990-EZ
filers for the tax year; employees cover full-990 filers only. Each
sheet's denominator differs and must be stated.

## Steps for Christina

Each step is one script in this folder. Reads go through
`R/request_read.R` so every artifact is pinned in `_pins.csv`. Code is
tidyverse style with full roxygen comments on any function. Thiya reviews
each script before the next starts.

1. `build-1-universe.R`: read the geocoded BMF master, join the
   county-fips crosswalk, keep the seven counties, keep 501(c)(3) public
   charities. Write `output/universe.csv` with EIN, county, NTEE major
   group, ruling year, filing type. Report the count per county and the
   number of unresolved county labels.
2. `build-2-sample.R`: apply the sample definition (decision 1). Report
   how many organizations each condition removes, per county.
3. `build-3-financials.R`: pull tax year 2023 Form 990 and 990-EZ
   financials for the sample EINs from the CORE series (PZ tier for
   revenue, expenses, assets, liabilities; PC rows for employees). One
   row per EIN, with a flag for form type. Verify tax year and return
   type per row; never trust the file-name year.
4. `build-4-measures.R`: compute every sheet's distribution for the
   region and each county, using the band cut points exactly as on the
   template. Apply suppression (decision 3). Write
   `output/measures-long.csv` (geography, measure, category, value,
   denominator n).
5. `build-5-template.R`: fill the requester's Excel template from the
   long table. Write to `output/`, never over the original in `docs/`.
6. `check-6-qa.R`: shares sum to 100 within each distribution; counts
   match between steps; region equals the sum of counties for counts;
   spot-check three EINs by hand against ProPublica Nonprofit Explorer.
7. Methods note: `docs/methods-note.md` with sample definition,
   sources, coverage by measure, suppression rule, data dictionary for
   the template columns.

## Timeline

| Date | Milestone |
|---|---|
| Week of 2026-10-20 | Sample meetings; receive Excel template and Core Sample criteria; steps 1 and 2 |
| By 2026-10-27 | Steps 3 and 4 built and reviewed |
| By 2026-10-29 | Template filled, QA done, methods note drafted |
| 2026-10-30 | Deliver populated template and methods note |
