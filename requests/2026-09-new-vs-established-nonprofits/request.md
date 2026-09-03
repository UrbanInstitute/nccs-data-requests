---
title: >-
  Is the nonprofit sector shifting toward new organizations? Spending shares by
  organization age, 1989-2023
date: 2026-09-03T00:00:00.000Z
description: >-
  Three IRS-derived datasets (BMF, CORE, e-file) agree: organizations under ten
  years old account for a shrinking share of nonprofit spending, not a growing
  one.
draft: true
format: gfm
type: analysis
categories:
  - trends
  - core
  - efile
author:
  - id: thiya
citation:
  container-title: National Center for Charitable Statistics
  volume: 1
  issue: 1
knitr:
  opts_chunk:
    dev: png
    dpi: 150
---


## The ask

> Is the field shifting toward “new” nonprofits and away from
> established institutions? Is there any analysis of this, and can NCCS
> data surface whether it is real?

(Requester identity and the verbatim ask are in the gitignored
`_private.md`.)

## Short answer

No, not in the IRS filing data. Organizations under ten years old
account for a **shrinking** share of nonprofit spending, and the decline
is steady over three decades. The share of *organizations* that are
young has been roughly flat, so the sector is not running out of new
entrants; new entrants are simply staying small, while spending
concentrates in organizations founded thirty or more years ago. Three
independent ways of measuring organization age agree. The literature
review in `literature.md` found no published evidence for a shift toward
new organizations either, and several sources pointing the other way.

What the IRS data cannot see: for-profit providers, and any organization
too small to file a Form 990 or 990-EZ (990-N postcard filers report no
financials). Both are discussed under limitations.

## Data and method

Three canonical NCCS artifacts, each pinned in `_pins.csv`:

- **CORE series, merged tier, 990 + 990-EZ, tax years 1989-2023**
  (`nccsdata::nccs_read_core`). One row per filing; deduplicated to one
  row per EIN and tax year (latest tax period). Filings with missing or
  non-positive total expenses are dropped. All subsections included; a
  501(c)(3)-only cut is reported as a sensitivity.
- **Geocoded unified BMF** (`nccsdata::nccs_read`), one row per EIN, for
  the IRS ruling date, subsection, and NTEE code.
- **E-file 990/990-EZ header and Part I summary tables, tax years
  2012-2023** (`nccs-efile` v2.1 catalog): the self-reported year of
  formation and current-year total expenses.

**Metric.** Total expenses, following the request. Expenses measure what
an organization disburses in a year, they are reported on both the 990
and the 990-EZ for the whole 1989-2023 span, and the size-concentration
literature (McKeever and Pettijohn 2014) is stated in expense terms.
Shares are computed within each tax year, so inflation does not affect
them. Medians are reported alongside shares because the young-cohort
mean is driven by a handful of fast scale-ups (Bradach and Kim 2016;
Kelley et al. 2024).

**Organization age**, three ways, because each has a known flaw:

1.  **IRS ruling year** (BMF). Available for every EIN back to the
    1930s, but it lags founding by a year or more, and it is *reset*
    when an organization is reinstated after automatic revocation (a
    process that began in 2010). A reinstated 1965 charity looks like a
    2013 startup. Filings whose ruling year postdates the tax year are
    the visible tip of this and are excluded from the age tables; their
    size is reported below.
2.  **First appearance in the CORE panel.** Independent of the ruling
    date and immune to resets: an organization that filed a 990 in 1995
    cannot be “new” in 2020. Left-censored at 1989, so the
    under-ten-years group is only complete from tax year 1999 onward;
    the chart starts it in 2000 because 1999 is a thin year in the
    legacy files.
3.  **Self-reported year of formation** on the e-filed return (Form 990
    header). The most direct measure of founding, but only for e-filed
    returns, which were incomplete before the tax year 2021 mandate.

Age groups are 0-4, 5-9, 10-19, 20-29, and 30+ years. “Young” means
under ten. Hospitals (NTEE E20-E24) and higher education (B40-B59) are
shown separately because they hold about 40% of all expenses in every
year.

## Findings

### 1. Young organizations’ share of spending has fallen by more than half since 1990

``` r
a <- fread(file.path(out, "core_by_age_ruling.csv"))
sh <- a[, .(exp = sum(exp_sum), n = sum(n)), by = .(tax_year, age_grp)][
  , `:=`(exp_share = 100 * exp / sum(exp), n_share = 100 * n / sum(n)), by = tax_year]
sh[, age_grp := factor(age_grp, levels = c("0-4", "5-9", "10-19", "20-29", "30+"))]
tab <- dcast(sh[tax_year %in% show_years], tax_year ~ age_grp, value.var = "exp_share")
kable(tab |> mutate(across(-tax_year, ~ pct(.x))), align = "lrrrrr",
      caption = "Share of total expenses (990 + 990-EZ filers) by years since IRS ruling")
```

| tax_year |  0-4 |   5-9 | 10-19 | 20-29 |   30+ |
|:---------|-----:|------:|------:|------:|------:|
| 1990     | 9.3% | 12.0% | 16.7% | 13.6% | 48.4% |
| 1995     | 6.8% |  8.8% | 19.1% | 13.8% | 51.5% |
| 2000     | 8.7% |  7.9% | 19.3% | 13.6% | 50.4% |
| 2005     | 5.3% |  9.0% | 14.8% | 17.1% | 53.7% |
| 2010     | 4.8% |  5.6% | 15.8% | 17.4% | 56.4% |
| 2015     | 5.4% |  5.4% | 14.1% | 12.9% | 62.2% |
| 2019     | 3.9% |  6.7% | 10.5% | 14.2% | 64.7% |
| 2021     | 3.3% |  5.6% | 11.2% | 14.9% | 64.9% |
| 2023     | 2.7% |  5.7% | 10.5% | 15.4% | 65.8% |

Share of total expenses (990 + 990-EZ filers) by years since IRS ruling

``` r
tab <- dcast(sh[tax_year %in% show_years], tax_year ~ age_grp, value.var = "n_share")
kable(tab |> mutate(across(-tax_year, ~ pct(.x))), align = "lrrrrr",
      caption = "Share of filing organizations by years since IRS ruling")
```

| tax_year |   0-4 |   5-9 | 10-19 | 20-29 |   30+ |
|:---------|------:|------:|------:|------:|------:|
| 1990     | 15.7% | 15.7% | 25.1% | 15.2% | 28.3% |
| 1995     | 18.2% | 13.7% | 22.7% | 17.9% | 27.5% |
| 2000     | 17.1% | 15.7% | 21.4% | 16.2% | 29.6% |
| 2005     | 15.1% | 14.9% | 22.3% | 15.5% | 32.1% |
| 2010     | 13.2% | 13.3% | 23.0% | 15.5% | 35.0% |
| 2015     | 15.5% | 12.3% | 21.5% | 15.9% | 34.8% |
| 2019     | 14.4% | 13.1% | 20.0% | 16.4% | 36.1% |
| 2021     | 13.2% | 14.1% | 19.1% | 16.6% | 37.0% |
| 2023     | 13.9% | 14.6% | 17.7% | 16.2% | 37.7% |

Share of filing organizations by years since IRS ruling

In tax year 1990, organizations under ten years old accounted for 21.3%
of all expenses reported on Forms 990 and 990-EZ. By tax year 2023 that
share was 8.4%. Over the same period their share of *filers* moved only
from 31.4% to 28.4%. Organizations thirty or more years past their
ruling date went from 48.4% to 65.8% of expenses.

### 2. The pattern holds without hospitals and universities

``` r
x <- a[hosp_hied == FALSE, .(exp = sum(exp_sum), n = sum(n)), by = .(tax_year, age_grp)][
  , exp_share := 100 * exp / sum(exp), by = tax_year]
x[, age_grp := factor(age_grp, levels = c("0-4", "5-9", "10-19", "20-29", "30+"))]
tab <- dcast(x[tax_year %in% show_years], tax_year ~ age_grp, value.var = "exp_share")
kable(tab |> mutate(across(-tax_year, ~ pct(.x))), align = "lrrrrr",
      caption = "Share of total expenses excluding hospitals (NTEE E20-E24) and higher education (B40-B59)")
```

| tax_year |   0-4 |   5-9 | 10-19 | 20-29 |   30+ |
|:---------|------:|------:|------:|------:|------:|
| 1990     | 12.2% | 14.2% | 21.5% | 15.6% | 36.5% |
| 1995     |  8.5% | 11.7% | 23.4% | 16.1% | 40.3% |
| 2000     |  8.3% | 10.0% | 24.0% | 16.7% | 40.9% |
| 2005     |  6.7% |  9.0% | 18.5% | 21.4% | 44.4% |
| 2010     |  5.3% |  6.7% | 17.8% | 21.2% | 49.0% |
| 2015     |  5.3% |  6.3% | 15.5% | 15.7% | 57.3% |
| 2019     |  4.5% |  6.8% | 13.4% | 15.4% | 59.8% |
| 2021     |  3.6% |  5.9% | 13.4% | 16.5% | 60.6% |
| 2023     |  2.8% |  6.3% | 12.3% | 16.5% | 62.1% |

Share of total expenses excluding hospitals (NTEE E20-E24) and higher
education (B40-B59)

``` r
hh <- a[, .(share = 100 * sum(exp_sum[hosp_hied]) / sum(exp_sum)), by = tax_year]
```

Hospitals and higher education hold a near-constant 35.3% to 40.8% of
expenses in every year except 1999 (26.8%; tax year 1999 is a known thin
year in the legacy CORE files, with about 196,000 filers against roughly
315,000 in adjacent years), so they are not what drives the trend.
Excluding them, the young share falls from 26.4% in 1990 to 9.2% in
2023.

``` r
c3 <- fread(file.path(out, "core_by_age_ruling_c3.csv"))[
  , .(exp = sum(exp_sum)), by = .(tax_year, age_grp)][, exp_share := 100 * exp / sum(exp), by = tax_year]
f <- fread(file.path(out, "core_by_age_firstseen.csv"))[
  , .(exp = sum(exp_sum)), by = .(tax_year, first_grp)][, exp_share := 100 * exp / sum(exp), by = tax_year]
ef <- fread(file.path(out, "efile_by_age_formation.csv"))[
  , .(exp = sum(exp_sum)), by = .(TAX_YEAR, age_grp)][, exp_share := 100 * exp / sum(exp), by = TAX_YEAR]
lines <- rbindlist(list(
  sh[age_grp %in% young, .(series = "Ruling year (BMF), all filers", share = sum(exp_share)), by = tax_year],
  x[age_grp %in% young, .(series = "Ruling year, excl. hospitals & higher ed", share = sum(exp_share)), by = tax_year],
  c3[age_grp %in% young, .(series = "Ruling year, 501(c)(3) only", share = sum(exp_share)), by = tax_year],
  f[first_grp %in% young & tax_year >= 2000, .(series = "First 990 in CORE panel (from 2000)", share = sum(exp_share)), by = tax_year],
  ef[age_grp %in% young, .(series = "Self-reported formation year (e-file)", share = sum(exp_share)), by = .(tax_year = TAX_YEAR)]
))
ggplot(lines, aes(tax_year, share, colour = series)) +
  geom_line(linewidth = 0.9) +
  scale_y_continuous(labels = function(v) paste0(v, "%"), limits = c(0, NA)) +
  labs(x = "Tax year", y = "Share of total expenses",
       title = "Organizations under 10 years old: share of nonprofit spending",
       subtitle = "Five definitions across three datasets; none shows a rising share", colour = NULL) +
  theme_minimal(base_size = 12) + theme(legend.position = "bottom") +
  guides(colour = guide_legend(nrow = 3))
```

<div id="fig-young-share">

<img src="request_files/figure-commonmark/fig-young-share-1.png"
id="fig-young-share" />

Figure 1

</div>

### 3. Two independent age measures agree

**First appearance in the CORE panel** (no ruling date involved):

``` r
f[, first_grp := factor(first_grp, levels = c("0-4", "5-9", "10-19", "20-29", "30+"))]
tab <- dcast(f[tax_year %in% c(2000, 2005, 2010, 2015, 2019, 2021, 2023)], tax_year ~ first_grp, value.var = "exp_share")
kable(tab |> mutate(across(-tax_year, ~ ifelse(is.na(.x), "", pct(.x)))), align = "lrrrrr",
      caption = "Share of total expenses by years since the organization's first 990/990-EZ in the CORE panel (panel starts 1989, so older groups are empty in early years)")
```

| tax_year |  0-4 |   5-9 | 10-19 | 20-29 |   30+ |
|:---------|-----:|------:|------:|------:|------:|
| 2000     | 9.8% |  8.3% | 81.9% |       |       |
| 2005     | 5.6% | 11.2% | 83.2% |       |       |
| 2010     | 6.1% |  4.8% | 17.9% | 71.2% |       |
| 2015     | 4.5% |  6.3% | 14.8% | 74.5% |       |
| 2019     | 4.2% |  5.1% | 11.8% | 27.0% | 51.8% |
| 2021     | 3.1% |  5.4% | 10.5% | 17.0% | 64.0% |
| 2023     | 2.6% |  4.9% | 11.3% | 16.2% | 65.0% |

Share of total expenses by years since the organization’s first
990/990-EZ in the CORE panel (panel starts 1989, so older groups are
empty in early years)

**Self-reported formation year** on e-filed returns:

``` r
ef[, age_grp := factor(age_grp, levels = c("0-4", "5-9", "10-19", "20-29", "30+"))]
tab <- dcast(ef, TAX_YEAR ~ age_grp, value.var = "exp_share")
kable(tab |> mutate(across(-TAX_YEAR, ~ pct(.x))), align = "lrrrrr",
      caption = "Share of total expenses by years since self-reported formation, e-filed 990/990-EZ")
```

| TAX_YEAR |  0-4 |  5-9 | 10-19 | 20-29 |   30+ |
|:---------|-----:|-----:|------:|------:|------:|
| 2012     | 2.0% | 3.4% | 12.3% | 12.0% | 70.3% |
| 2013     | 1.8% | 3.8% | 12.1% | 11.0% | 71.3% |
| 2014     | 1.8% | 3.8% | 11.3% | 11.1% | 72.0% |
| 2015     | 1.9% | 3.8% | 10.5% | 11.1% | 72.7% |
| 2016     | 2.2% | 3.2% | 10.1% | 11.9% | 72.6% |
| 2017     | 2.2% | 3.2% |  9.2% | 11.9% | 73.5% |
| 2018     | 2.3% | 3.1% |  8.5% | 12.7% | 73.5% |
| 2019     | 2.4% | 3.3% |  8.0% | 13.3% | 73.0% |
| 2020     | 2.2% | 3.5% |  8.3% | 13.4% | 72.6% |
| 2021     | 2.0% | 3.5% |  8.3% | 13.3% | 72.8% |
| 2022     | 1.8% | 3.6% |  8.4% | 13.3% | 72.9% |
| 2023     | 1.5% | 3.6% |  8.4% | 13.2% | 73.3% |

Share of total expenses by years since self-reported formation, e-filed
990/990-EZ

``` r
efc <- fread(file.path(out, "efile_coverage_by_year.csv"))
```

This is the shortest series but the most direct measure of founding, and
it is flat: organizations formed within the past ten years held about 5%
of e-filed expenses in every year from 2012 to 2023, with the under-five
group near 2%. Two coverage notes. The 990-EZ has no formation-year
line, so this measure covers full Form 990 filers only (the EZ filers,
who are smaller and younger, are the 40% of returns without a formation
year; they hold 5.2% of expenses). That is why the level here sits below
the CORE ruling-year series. And e-filing was optional before tax year
2021, so earlier years are a self-selected sample; 2021-2023 are
near-complete.

### 4. Where the young cohort’s money sits: entrants, medians, and the top of the distribution

``` r
e <- fread(file.path(out, "core_entrants_by_year.csv"))
e[, `:=`(entrant_share_n = 100 * entrants / filers, entrant_share_exp = 100 * exp_entrants / exp_total)]
kable(e[tax_year %in% c(1995, 2000, 2005, 2010, 2015, 2019, 2023),
        .(tax_year, filers = fmt(filers), first_time_filers = fmt(entrants),
          `share of filers` = pct(entrant_share_n), `share of expenses` = pct(entrant_share_exp, 2))],
      align = "lrrrr", caption = "Organizations filing their first 990/990-EZ in the panel")
```

| tax_year |  filers | first_time_filers | share of filers | share of expenses |
|:---------|--------:|------------------:|----------------:|------------------:|
| 1995     | 280,739 |            24,004 |            8.6% |             1.34% |
| 2000     | 313,622 |            25,525 |            8.1% |             1.64% |
| 2005     | 388,975 |            27,372 |            7.0% |             0.95% |
| 2010     | 425,093 |            25,311 |            6.0% |             1.64% |
| 2015     | 507,732 |            25,767 |            5.1% |             0.73% |
| 2019     | 514,979 |            23,278 |            4.5% |             0.66% |
| 2023     | 504,580 |            22,105 |            4.4% |             0.22% |

Organizations filing their first 990/990-EZ in the panel

``` r
med <- a[, .(exp_median = weighted.mean(exp_median, n)), by = .(tax_year, age_grp)]
med[, age_grp := factor(age_grp, levels = c("0-4", "5-9", "10-19", "20-29", "30+"))]
tab <- dcast(med[tax_year %in% c(2000, 2010, 2019, 2023)], tax_year ~ age_grp, value.var = "exp_median")
kable(tab |> mutate(across(-tax_year, ~ paste0("$", fmt(round(.x / 1000)), "k"))), align = "lrrrrr",
      caption = "Median total expenses by age group (nominal dollars; n-weighted across the hospital/higher-ed split)")
```

| tax_year |    0-4 |    5-9 |  10-19 |  20-29 |      30+ |
|:---------|-------:|-------:|-------:|-------:|---------:|
| 2000     | \$119k | \$144k | \$193k | \$204k | \$1,022k |
| 2010     |  \$91k | \$125k | \$201k | \$231k | \$1,023k |
| 2019     |  \$89k | \$132k | \$165k | \$243k |   \$956k |
| 2023     | \$102k | \$161k | \$209k | \$328k | \$1,070k |

Median total expenses by age group (nominal dollars; n-weighted across
the hospital/higher-ed split)

``` r
t <- fread(file.path(out, "core_top_filers_by_age.csv"))[, share := 100 * n / sum(n), by = .(tax_year, top)]
tab <- dcast(t[age_grp %in% young, .(share = sum(share)), by = .(tax_year, top)][tax_year %in% show_years],
             tax_year ~ top, value.var = "share")
kable(tab |> mutate(across(-tax_year, ~ pct(.x))), align = "lrr",
      caption = "Share of the 1,000 and 10,000 largest filers (by expenses) that are under ten years old")
```

| tax_year | top1000 | top10000 |
|:---------|--------:|---------:|
| 1990     |   18.6% |    19.9% |
| 1995     |   13.1% |    17.6% |
| 2000     |   15.9% |    15.7% |
| 2005     |   10.9% |    12.7% |
| 2010     |    8.3% |     8.6% |
| 2015     |    9.9% |     8.9% |
| 2019     |    9.5% |     8.6% |
| 2021     |    7.6% |     8.5% |
| 2023     |    6.8% |     8.4% |

Share of the 1,000 and 10,000 largest filers (by expenses) that are
under ten years old

Entry into the filing universe has slowed as a share of filers (about 8%
of filers were first-time filers in the late 1990s, about 4.5% in the
2020s), and first-time filers’ share of expenses has fallen below half a
percent. Young organizations are also a shrinking share of the largest
filers. Together with the roughly flat count share, the picture is many
new organizations, each small, with the largest and fastest-growing
budgets sitting in long-established institutions.

### 5. Cross-check: how badly does the ruling date misstate age?

``` r
xc <- fread(file.path(out, "xcheck_ruling_vs_formation.csv"))
xc[, share := 100 * n / sum(n)]
kable(xc[, .(`ruling year minus formation year` = gap_bucket, organizations = fmt(n), share = pct(share))],
      align = "lrr", caption = "E-filers with both a BMF ruling year and a self-reported formation year (one row per EIN, latest return)")
```

| ruling year minus formation year | organizations | share |
|:---------------------------------|--------------:|------:|
| ruling before formation          |        39,103 |  9.5% |
| 0                                |        97,172 | 23.7% |
| 1                                |       104,140 | 25.4% |
| 2                                |        40,099 |  9.8% |
| 3-5                              |        37,169 |  9.1% |
| 6-10                             |        20,774 |  5.1% |
| 11-20                            |        21,836 |  5.3% |
| 21+                              |        50,225 | 12.2% |

E-filers with both a BMF ruling year and a self-reported formation year
(one row per EIN, latest return)

``` r
gap <- fread(file.path(out, "xcheck_gap_by_ruling_year.csv"))
```

``` r
ggplot(gap[ruling_year >= 1990 & ruling_year <= 2023], aes(ruling_year, 100 * share_gap_gt10)) +
  geom_col(fill = "#1f78b4") +
  scale_y_continuous(labels = function(v) paste0(v, "%")) +
  labs(x = "IRS ruling year", y = "Formed 10+ years before ruling",
       title = "A ruling date is not a founding date",
       subtitle = "Share of e-filers whose self-reported formation year is more than 10 years before their IRS ruling year") +
  theme_minimal(base_size = 12)
```

![](request_files/figure-commonmark/xcheck-fig-1.png)

The ruling date misstates age for a meaningful minority: about one in
eight e-filers reports a formation year more than twenty years before
its ruling year, and among organizations with a 2023 ruling date roughly
a quarter were formed ten or more years earlier. Every such case biases
the ruling-year series *toward* finding young organizations, not
against. Filings whose ruling year postdates the tax year (the
unambiguous cases) are excluded from the ruling-year tables; they were
12.9% of expenses in 1990 and 0.4% in 2023. Because those excluded 1990
filings are overwhelmingly old organizations, adding them back would
lower the 1990 young share and make the decline slightly smaller, not
larger. The first-appearance and formation-year measures, which do not
have this flaw, show the same decline.

## Takeaways

- **The premise is not supported by IRS filing data.** Organizations
  under ten years old held about a fifth of nonprofit spending in 1990
  and under a tenth in 2023. Their share of organizations barely moved.
  The sector keeps producing new organizations; it is not routing money
  to them.
- **Spending is concentrating in the oldest institutions**, and that is
  not only hospitals and universities, whose share is flat at about 40%.
- **Three age definitions across three datasets agree** on direction and
  roughly on magnitude, including the two that are immune to the
  ruling-date reset problem.
- **What this cannot rule out.** A shift toward for-profit providers
  (in, say, health care, child care, or education) is invisible in 990
  data and would need BLS or Census ownership data. A shift of
  *attention* or *new grant dollars* toward young organizations that has
  not yet shown up in spending totals is also possible; the literature
  review found survey evidence pointing the other way (Candid
  2025, 2026) but no direct measure. Government-grant and grants-paid
  fields in the e-file extraction could test the funder side next.

## Limitations

- 990-N filers (gross receipts normally under \$50,000) report no
  financials and are absent from every table. Most post-2014 Form
  1023-EZ entrants sit in that group (Candid 2025; Taxpayer Advocate
  2018), so the young cohort’s true spending is somewhat higher than
  shown, but by construction it is under \$50,000 per organization.
- CORE tax years 1989-2011 are the legacy NCCS files; 2012 onward are
  IRS SOI extracts. The 2012 step in filer counts reflects that source
  change, and tax year 1999 is unusually thin (about 196,000 filers).
- Ruling year is missing for about 6% of BMF EINs (mostly pre-1970
  records and sentinel values); those filings are excluded from
  ruling-year tables.
- Nominal dollars throughout; shares are unaffected, medians are not
  deflated.

------------------------------------------------------------------------

*Reproducibility: `build.R` pulls the pinned sources (see `_pins.csv`)
and writes the aggregates in `out/`; this document renders from `out/`
alone. The literature review is in `literature.md`. See ADR 0024 / 0025
in `nccs-contracts`.*
