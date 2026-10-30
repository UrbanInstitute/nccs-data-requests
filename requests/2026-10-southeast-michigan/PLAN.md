# Plan: Southeast Michigan nonprofit fact sheet (seven counties)

Status: set up 2026-10-20. Deadline for the populated data template is
end of day Friday 2026-10-30. The analyst executes the steps below; the
reviewer checks code and numbers; the requester owns the fact sheet.

## What is being asked

A fact sheet on nonprofits in seven Michigan counties: St. Clair,
Livingston, Oakland, Macomb, Washtenaw, Wayne, and Monroe. Every measure
is reported for the seven-county region in aggregate and for each county
on its own. The deliverable is the requester's Excel template, filled in
(in `template/`), with a short methods note so the
requester can write the source lines and caveats. Requester identity and
the full email thread are in `_private.md` (gitignored).

Budget: 40 reviewer hours, 6 analyst hours. The estimate covered
two sample-definition meetings, data assembly, all measures below, QA,
the methods note, and one round of revisions.

## The template (received 2026-10-20, in `template/`)

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

## What the fact sheet document settles (format draft in `template/`)

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
  registered 501(c)(3) public charity, private foundations excluded. The financial sheets use
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

1. **Sample: settled 2026-10-20.** All 501(c)(3) public charities,
   excluding private foundations. No Nonprofit Trends Core Sample
   filter, so hospitals and universities stay in. In the BMF this is
   subsection code 3 with a foundation code that marks a public charity
   (not a private foundation); write the exact code rule into step 1 and
   the methods note. The sample meetings are no longer needed for this.
2. **Tax year and vintages.** Financial sheets: tax year 2023 from the
   CORE series. BMF sheets: a 2026 BMF vintage, matching the age
   formula. Fill every "[Date]" and "Year" placeholder with the vintage
   or tax year used.
3. **Hosting.** COMM product on urban.org or funder site. Format only.

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

## Settled decisions (requester approved 2026-10-21)

- Reads: BMF geocoded master filtered to the latest `last_vintage_ym`;
  CORE processed tier, tax year 2023, `990combined` partition for the
  five financial sheets (`source_form` separates 990 from 990-EZ) and
  the `990` partition for employees (Part V line 2a, which equals Part I
  line 5). The requester's "Core PZ file" and "Core PC file" are the
  retired legacy names for these populations.
- Public charity: subsection code 3 and foundation code not in 2, 3, 4,
  compared as integers.
- Subsector: NTEE v2 subsector mapped to the ten template groups;
  hospitals fold into Health, universities into Education; Unclassified
  kept and explained.
- Age: ruling dates stored as 1900-01-01 are missing, reported in a
  "not reported" column, not in the 50+ band.
- Employees 0 band is labelled "zero or not reported".
- Operating surplus: negative-revenue rows excluded and counted;
  assigned zeros footnoted.
- Dollar bands: lower bound inclusive everywhere.
- No suppression. Every row carries its denominator n.
- Duplicate EIN within tax year 2023: keep the latest tax period.

## Steps for the analyst

Each step is one script in this folder, tracked as a GitHub issue.
Reads go through `R/request_read.R` so every artifact is pinned in
`_pins.csv`. Code is tidyverse style with full roxygen comments on any
function. The reviewer checks each script before the next starts.
Every count the plan relies on is printed by the script that produces
it.

1. `build-1-universe.R`: read the geocoded BMF master, filter to the
   latest `last_vintage_ym` (print it and the rows dropped), join the
   county-fips crosswalk, keep the seven counties (print and drop
   unresolved Michigan rows), apply the public-charity rule (print what
   each condition removes per county), map subsector to the ten groups,
   flag missing ruling dates. Write `output/universe.csv`. Print the
   count per county; these fill the Number sheet.
2. `build-2-financials.R`: for the universe EINs, read tax year 2023
   from the 990combined and 990 partitions. Verify tax year per row.
   Keep the latest tax period per EIN (print duplicates resolved). One
   row per EIN with `source_form`, revenue, expenses, assets,
   liabilities, employees. Print: EINs with a 990 row, an EZ row, no
   row; 2023 filers absent from the current registry; full-990 rows
   with zero employees but positive wages.
3. `build-3-measures.R`: every sheet's distribution for the region and
   each county, bands exactly as on the template, lower bound
   inclusive. Operating surplus excludes negative revenue (print the
   count) and footnotes assigned zeros (print the count). Write
   `output/measures-long.csv` (geography, sheet, band, share, n).
4. `build-4-template.R`: copy the Excel template from `template/` to
   `output/` and fill it from the long table. Never write over the
   original. Fill the [Date] and Year placeholders with the BMF vintage
   and the CORE tax year.
5. `check-5-qa.R`: shares sum to 100 per row; denominator n reconciles
   by county and sheet against steps 1 and 2; form-type by county
   cross-tab; region equals the sum of counties; Wayne County count
   checked against an external published figure; three EINs checked by
   hand against ProPublica Nonprofit Explorer. Print pass or fail per
   check.
6. `docs/methods-note.md`: sample rule, reads and vintages from
   `_pins.csv`, the PZ/PC name mapping, who each sheet covers with n,
   missing ruling dates, employee zeros, negative revenue, no
   suppression, data dictionary.

## Timeline

| Date | Milestone |
|---|---|
| By 2026-10-23 | Steps 1 and 2 built and reviewed |
| By 2026-10-27 | Steps 3 and 4 built and reviewed |
| By 2026-10-29 | QA passed, methods note drafted |
| 2026-10-30 | Deliver the filled template and methods note |
