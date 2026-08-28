---
title: >-
  One private foundation, 35 years of filings: reading a 990-PF history in plain
  language
date: 2026-08-28T00:00:00.000Z
description: >-
  What NCCS holds on a single private foundation from 1989 to the present, and
  how to read it without a data dictionary.
draft: true
format: gfm
knitr:
  opts_chunk:
    dev: png
type: methods
categories:
  - core
  - private-foundations
author:
  - id: thiya
citation:
  container-title: National Center for Charitable Statistics
  volume: 1
  issue: 1
---


## The ask

> Everything NCCS holds on one organization (a single EIN) from 1989 to
> the present, delivered so that a reader with no data background can
> follow it.

The EIN resolves in the Unified BMF to a Virginia 501(c)(3) **private
non-operating foundation** (foundation code 4), so its annual return is
**Form 990-PF**, not Form 990. That decides which CORE partitions to
read: `990pf`, merged tier, 1989 through the latest published year
(2024).

## Data

``` r
cols <- c("ein", "tax_period", "tax_year", "subsection_cd",
          "contributions_received", "dividends_interest_excluded",
          "interest_savings_excluded", "capital_gain", "other_income",
          "total_revenue_col_a", "net_investment_income",
          "compensation_officers", "total_operating_admin_expenses_col_a",
          "contributions_paid", "total_expenses_col_a", "total_expenses_col_d",
          "excess_revenue_over_expenses", "excise_tax_net_investment_income",
          "total_assets_eoy", "fair_mkt_value_total_assets_eoy",
          "total_liabilities_eoy", "total_fund_net_worth_eoy",
          "total_investments_securities", "minimum_investment_return",
          "distributable_amount", "qualifying_distributions_curr_yr",
          "undistributed_income_current_yr", "source_pipeline")

# Read year-by-year. Stacking all 36 partitions into one Arrow dataset fails
# on this EIN with an int32 overflow (Arrow unifies a column to int32 across
# partitions where some years hold values > 2^31); see the upstream note in
# checklist.md. Per-year reads sidestep the unified schema.
pf <- bind_rows(lapply(1989:2024, function(y) {
  nccsdata::nccs_read_core(tier = "merged", tax_year = y, form = "990pf",
                           columns = cols, collect = FALSE, confirm = FALSE) |>
    filter(ein == EIN) |>
    collect() |>
    mutate(across(where(is.numeric), as.numeric))
})) |> arrange(tax_period)

record_pin(req, "core-merged", vintage = "merged",
           source = nccsdata::nccs_core_url(tier = "merged", tax_year = 2024,
                                            form = "990pf"),
           n_rows = nrow(pf),
           note = "990-PF partitions 1989-2024 read year-by-year, one EIN")

bmf <- read_bmf_master(req, collect = FALSE,
                       note = "identity check for one EIN") |>
  filter(ein == EIN) |> collect()
```

30 filings came back. Years with no filing on file: 1992, 1993, 2016,
2017, 2018, 2024.

## What each number means

A 990-PF has three stories on it. Restated for a reader who has never
seen one:

| Plain-language label | 990-PF line | CORE column |
|----|----|----|
| Money the foundation received as gifts | Part I, line 1 | `contributions_received` |
| Investment income (dividends and interest) | Part I, lines 3 + 4 | `dividends_interest_excluded` + `interest_savings_excluded` |
| Gain or loss from selling investments | Part I, line 6a | `capital_gain` |
| **Total income for the year** | Part I, line 12 | `total_revenue_col_a` |
| Grants and gifts the foundation gave out | Part I, line 25 | `contributions_paid` |
| Cost of running the foundation | Part I, line 24 | `total_operating_admin_expenses_col_a` |
| **Total spending for the year** | Part I, line 26 | `total_expenses_col_a` |
| **What the foundation was worth at year end** (book value) | Part II, line 16 | `total_assets_eoy` |
| Same, at market value | Part II, line 16 (FMV) | `fair_mkt_value_total_assets_eoy` |
| Minimum the IRS expects it to give each year (about 5% of assets) | Part X, line 6 | `minimum_investment_return` |
| Required giving not yet paid out | Part XIII, line 6f | `undistributed_income_current_yr` |

## The history, one row per year

``` r
tbl <- pf |>
  transmute(
    `Tax year`                     = as.character(tax_year),
    `Gifts received`               = contributions_received,
    `Investment income`            = coalesce(dividends_interest_excluded, 0) +
                                     coalesce(interest_savings_excluded, 0),
    `Gain/loss on sales`           = capital_gain,
    `Total income`                 = total_revenue_col_a,
    `Grants given out`             = contributions_paid,
    `Total spending`               = total_expenses_col_a,
    `Assets at year end (book)`    = total_assets_eoy,
    `Assets at year end (market)`  = fair_mkt_value_total_assets_eoy,
    `Required annual payout`       = minimum_investment_return,
    `Source`                       = if_else(source_pipeline == "legacy",
                                             "NCCS legacy core (1989-2011)",
                                             "IRS SOI extract (2012+)")
  )
kable(tbl, format.args = list(big.mark = ",", scientific = FALSE))
```

| Tax year | Gifts received | Investment income | Gain/loss on sales | Total income | Grants given out | Total spending | Assets at year end (book) | Assets at year end (market) | Required annual payout | Source |
|:---|---:|---:|---:|---:|---:|---:|---:|---:|---:|:---|
| 1989 | 33,887,522 | 128,679 | 71,857 | 34,088,058 | 163,200 | 207,857 | 35,591,381 | NA | NA | NCCS legacy core (1989-2011) |
| 1990 | 0 | 966,964 | 0 | 952,314 | 1,219,900 | 1,252,027 | 35,291,666 | NA | NA | NCCS legacy core (1989-2011) |
| 1991 | 0 | 938,714 | 116,126 | 1,054,840 | 828,250 | 865,677 | 35,508,345 | NA | NA | NCCS legacy core (1989-2011) |
| 1994 | 0 | 728,424 | 0 | 725,199 | 5,638,972 | 5,675,123 | 25,646,774 | 21,058,148 | 1,149,468 | NCCS legacy core (1989-2011) |
| 1995 | 0 | 700,609 | 76,282 | 776,891 | 3,973,838 | 4,033,460 | 22,390,205 | 20,198,070 | 1,057,521 | NCCS legacy core (1989-2011) |
| 1996 | 0 | 637,946 | 11,523 | 649,469 | 475,450 | 526,476 | 22,513,198 | 21,755,563 | 1,067,764 | NCCS legacy core (1989-2011) |
| 1997 | 0 | 588,214 | 187,517 | 775,731 | 1,358,206 | 1,425,232 | 21,863,697 | 20,213,948 | 951,002 | NCCS legacy core (1989-2011) |
| 1998 | 0 | 546,914 | 15,971 | 562,885 | 3,718,221 | 3,785,377 | 17,756,977 | 15,692,821 | 843,590 | NCCS legacy core (1989-2011) |
| 1999 | 0 | 598,004 | 87,847 | 685,851 | 2,509,697 | 2,563,494 | 15,879,967 | 16,426,220 | 769,048 | NCCS legacy core (1989-2011) |
| 2000 | 0 | 872,111 | 54,280 | 926,391 | 1,903,680 | 1,999,900 | 14,806,389 | 15,391,043 | 759,303 | NCCS legacy core (1989-2011) |
| 2001 | 0 | 859,270 | 1,123,177 | 2,028,665 | 3,013,625 | 3,127,881 | 13,707,173 | 13,059,666 | 658,342 | NCCS legacy core (1989-2011) |
| 2002 | 0 | 549,408 | -881,128 | -301,720 | 2,235,332 | 2,321,767 | 11,083,779 | 10,088,966 | 548,692 | NCCS legacy core (1989-2011) |
| 2003 | 0 | 437,086 | -263,001 | 204,085 | 1,159,255 | 1,219,784 | 10,068,050 | 10,163,719 | 496,145 | NCCS legacy core (1989-2011) |
| 2004 | 0 | 417,536 | 168,155 | 615,659 | 1,005,115 | 1,085,242 | 9,898,326 | 9,953,902 | 495,773 | NCCS legacy core (1989-2011) |
| 2005 | 0 | 337,270 | -83,711 | 281,983 | 1,446,521 | 1,527,742 | 8,652,560 | 8,624,419 | 456,678 | NCCS legacy core (1989-2011) |
| 2006 | 0 | 339,277 | 144,216 | 520,828 | 784,767 | 867,775 | 8,293,470 | 8,831,062 | 445,584 | NCCS legacy core (1989-2011) |
| 2007 | 0 | 339,890 | 100,590 | 465,202 | 964,453 | 1,038,193 | 7,697,853 | 8,129,102 | 424,209 | NCCS legacy core (1989-2011) |
| 2008 | 0 | 288,020 | -702,701 | -394,458 | 1,058,636 | 1,132,437 | 6,172,022 | 5,844,239 | 343,462 | NCCS legacy core (1989-2011) |
| 2009 | 0 | 201,604 | -21,646 | 210,640 | 827,853 | 905,200 | 5,460,876 | 5,900,908 | 286,342 | NCCS legacy core (1989-2011) |
| 2010 | 0 | 150,199 | 60,789 | 240,988 | 654,400 | 722,507 | 4,939,831 | 5,323,613 | 269,570 | NCCS legacy core (1989-2011) |
| 2011 | 0 | 82,202 | -131,786 | 10,416 | 606,920 | 681,969 | 4,268,479 | 4,397,409 | 236,081 | NCCS legacy core (1989-2011) |
| 2012 | 0 | 46,711 | 10,546 | 117,257 | 485,428 | 556,238 | 3,835,622 | 4,089,758 | 205,271 | IRS SOI extract (2012+) |
| 2013 | 0 | 15,455 | 69,865 | 150,320 | 156,500 | 222,612 | 3,758,223 | 4,114,629 | 208,362 | IRS SOI extract (2012+) |
| 2014 | 0 | 6,986 | 143,635 | 215,721 | 147,650 | 233,670 | 3,772,824 | 3,780,028 | 199,724 | IRS SOI extract (2012+) |
| 2015 | 0 | 902 | 6,656 | 62,458 | 43,200 | 128,046 | 3,707,438 | 3,708,783 | 184,184 | IRS SOI extract (2012+) |
| 2019 | 0 | 464 | 180 | 60,923 | 7,700 | 64,757 | 3,623,332 | 3,627,775 | 178,116 | IRS SOI extract (2012+) |
| 2020 | 0 | 215 | 0 | 60,215 | 24,000 | 60,352 | 3,623,195 | 3,628,903 | 179,474 | IRS SOI extract (2012+) |
| 2021 | 0 | 450,617 | 1,067 | 511,684 | 78,300 | 166,255 | 3,968,624 | 4,008,506 | 110,449 | IRS SOI extract (2012+) |
| 2022 | 0 | 50,563 | 0 | 72,980 | 123,950 | 187,830 | 3,853,774 | 3,645,823 | 200,412 | IRS SOI extract (2012+) |
| 2023 | 0 | 95,067 | 0 | 86,398 | 175,240 | 233,085 | 3,707,087 | 3,868,170 | 184,351 | IRS SOI extract (2012+) |

``` r
par(mar = c(4, 5, 2, 1))
plot(tbl$`Tax year`, tbl$`Assets at year end (book)` / 1e6, type = "b", pch = 16,
     xlab = "Tax year", ylab = "Millions of dollars", ylim = c(0, 40),
     main = "Assets at year end vs. grants given out, by year")
lines(tbl$`Tax year`, tbl$`Grants given out` / 1e6, type = "h", lwd = 4,
      col = "grey55")
legend("topright", bty = "n", pch = c(16, NA), lty = c(1, 1), lwd = c(1, 4),
       col = c("black", "grey55"),
       legend = c("Assets at year end (book)", "Grants given out"))
```

![](request_files/figure-commonmark/chart-1.png)

## Findings

- The record opens in tax year 1989 with a one-time gift of about \$33.9
  million, which is the foundation’s founding endowment as seen by NCCS.
  Assets stood at \$35.6 million at the end of that year.
- From 1990 on the foundation received essentially no new gifts. It
  lived on investment income and spent down principal: grants paid out
  exceeded income in almost every year, so assets fell steadily from
  \$35 million in 1991 to about \$3.7 million by 2015, and have held
  near \$3.6 to \$4.0 million since.
- Cumulative grants over the 30 filings on record total about 36.8
  million dollars.
- Grant-making peaked in the 1990s (over \$5.6 million in 1994, \$3.7
  million in 1998) and has been in the tens of thousands to low hundreds
  of thousands since 2013.
- Since 2021 the return shows a small “undistributed income” balance,
  meaning the required annual payout was not fully met in the year; that
  is a flag on the return, not a finding about wrongdoing.

## Takeaways

- **Coverage caveat.** Six years have no filing in NCCS: 1992, 1993,
  2016, 2017, 2018, and 2024. The 2016 to 2018 gap is an IRS source
  problem: the SOI 990-PF extracts for those years are nearly empty
  across all foundations, not just this one. 2024 is not yet released.
  1992 and 1993 are missing from the legacy NCCS files. None of these
  gaps implies the foundation did not file. Verified against the
  ProPublica Nonprofit Explorer API
  (`/api/v2/organizations/{ein}.json`): it holds scanned PDFs for
  2016-2018 (paper filings, no extracted data, hence their absence from
  SOI) but nothing for 1992, 1993, or 2024. For the ten overlapping
  years (2011-2015, 2019-2023) ProPublica’s total revenue and
  end-of-year assets match the CORE values exactly.
- **Two eras, one table.** 1989 to 2011 comes from NCCS’s legacy core
  files; 2012 onward from the IRS SOI extracts. The harmonized column
  names line up, so a single per-year table is honest, but the 1989 to
  1991 rows lack the market-value and payout fields (they were not
  captured then).
- **Method note for future single-EIN requests.** Reading one EIN across
  36 partitions is a filter, not an ETL: the whole thing is
  `nccs_read_core(..., collect = FALSE) |> filter(ein == x)` per year.
  If a second single-organization request arrives, this is a candidate
  for an `nccs_read_core_ein()` helper in `nccsdata`.

------------------------------------------------------------------------

*Reproducibility: this story reads the vintages pinned in `_pins.csv`;
rerun from those pins to reproduce. See ADR 0024 / 0025 in
`nccs-contracts`.*
