# Independent foundation review

The Davidson arithmetic reproduces, but the claim needs revision. The full-stock denominator in the peer table is wrong, the year-level registry filter includes organizations absent from the latest observed month, and the national conclusion exceeds the evidence.

## 1. Reproduction

Ran the supplied R expression first, before reading explore-8-bmf.R or its output. All numbers agree under the supplied filters:

- Stock 405.
- Periods: 2010-14 27; 2015-19 53; 2020-22 38; 2023-26 73.
- Annual counts: 2015 4; 2016 10; 2017 11; 2018 10; 2019 18; 2020 10; 2021 8; 2022 20; 2023 26; 2024 21; 2025 18; 2026 8.

The 405 are unique EINs. Both local universe files have zero duplicate EINs.

## 2. Private foundation definition

The IRS EO BMF documentation identifies 02 as a private operating foundation exempt from investment-income excise taxes, 03 as other private operating foundations, and 04 as private non-operating foundations. All three belong. The longer original prompt's descriptions of codes 03 and 04 were incorrect, but its filter was correct.

Source: [IRS EO BMF field documentation](https://www.irs.gov/pub/irs-soi/eo-info.pdf).

foundation_code is character, with unpadded values in the TN file. Davidson's 405 comprise 1 code 2, 21 code 3, and 383 code 4. The padded/unpadded membership set drops none of these and cannot duplicate rows: %in% is a Boolean membership test. No subsection restriction gives the same 405 here. Across the TN universe, the subsection-3 PF counts are 5 code 2, 203 code 3, and 3,472 code 4.

## 3. Registry presence and vintage

2026 is the maximum last_year_in_bmf in the local file. However, this field is the year extracted from last_vintage_ym, not an IRS status code or a current-month presence flag. Producer evidence: nccs-data-bmf/R/master_bmf_builder.R, final_ranked/final select.

Retrieved only EIN, last_vintage_ym and status_code from the permanent v2026_09 geocoded master. Its manifest matches the request pin's git 1b1f8a9 and SHA256 c296860c572822404dc55861af89ea13ce11b48f51030313d97d067f1766a3ad. This SHA256 is manifest-reported; the 641 MB source object was not independently downloaded and rehashed. TN EIN coverage and derived last-year values match the local universe exactly.

The September build's maximum observed month is **2026-07**, nationally as well as in TN. Build vintage and observation vintage differ. Davidson latest-observation counts:

| Last observed month | Count |
|---|---:|
| January 2026 | 1 |
| March 2026 | 5 |
| May 2026 | 1 |
| June 2026 | 1 |
| July 2026 | 397 |

Requiring presence in the latest observed month gives **397**, down 8 (2.0%). The period counts become 27, 51, 35, 72. Annual counts from 2019 become 17, 10, 8, 17, 25, 21, 18, 8. Among July's 397, 395 have IRS status code 1 and two have status 25, terminating private foundation status under section 507(b)(1)(B). These are registry entries, not independent proof of ongoing operations. Neither this pull nor this review establishes registry membership on October 19, 2026.

## 4. Ruling dates

The local column is an R Date, rendered YYYY-MM-DD. The supplied first-four-characters expression correctly extracts the year. The underlying IRS field records the month/year on an exemption recognition letter, not incorporation or necessarily original foundation formation. Current classification does not establish classification at the ruling date.

Among the 405 current-year Davidson PFs: no missing dates, none before 1900, none after 2026; range December 1942 to April 2026. Among all 640 Davidson PFs in the historical universe: also zero missing/before-1900/after-2026, range January 1900 to April 2026.

No Davidson records silently disappear because of missing or implausible ruling years. The 214 current-year foundations before 2010 are deliberately excluded from the period table, and cut() labels them NA if applied without the preliminary year filter. These are valid older dates, not missing data.

The eight 2026 Davidson rulings are January 2, February 1, March 3, April 2. The stated eight-month ruling coverage cannot be established. Latest recorded date does not itself establish complete coverage through that month. Broader TN data contain at least one future ruling date (maximum December 2068), but none is in the Davidson subset or the peer universe.

## 5. Geography

For all 405, county_name, geo_county and geo_county_canonical agree on Davidson County; geo_county_fips is 47037. This is **zero disagreements between geocoded/crosswalk labels**, not a mailing-versus-geocoded county check.

There is no separate mailing-address county in the local universe, build-column selection, or full pinned master schema. City, ZIP and state cannot provide an unambiguous county comparison. Therefore the requested mailing-county disagreement count and alternative count are **not identifiable from these inputs**. No county was inferred from ZIP or city.

## 6. Peer table and interpretation

The original period table reproduces exactly:

| Group | 2010-14 | 2015-19 | 2020-22 | 2023-26 |
|---|---:|---:|---:|---:|
| Nashville metro | 58 (14%) | 100 (24%) | 82 (20%) | 174 (42%) |
| Pooled 19 peers | 1,347 (14%) | 2,160 (22%) | 2,147 (22%) | 4,179 (42%) |

But ruling_year >= 2010 is applied before count() and sum(n). The percentage denominators are **414 and 9,833**, not stocks of **774 and 18,097**. Correct full-stock shares:

| Group | 2010-14 | 2015-19 | 2020-22 | 2023-26 |
|---|---:|---:|---:|---:|
| Nashville metro | 7.49% | 12.92% | 10.59% | 22.48% |
| Pooled 19 peers | 7.44% | 11.94% | 11.86% | 23.09% |

Davidson's corresponding full-stock shares are 6.67%, 13.09%, 9.38%, and 18.02%. Nashville metro is a larger geography than Davidson County.

Each metro below shows period count divided by its entire year-filtered PF stock. These retain the original last_year_in_bmf >= 2026 filter so the denominator correction can be isolated.

| Metro | Stock | 2010-14 | 2015-19 | 2020-22 | 2023-26 |
|---|---:|---:|---:|---:|---:|
| Atlanta | 2,232 | 158 (7.1%) | 274 (12.3%) | 330 (14.8%) | 712 (31.9%) |
| Austin | 874 | 67 (7.7%) | 125 (14.3%) | 129 (14.8%) | 257 (29.4%) |
| Birmingham | 699 | 58 (8.3%) | 84 (12.0%) | 56 (8.0%) | 107 (15.3%) |
| Charlotte | 711 | 41 (5.8%) | 87 (12.2%) | 93 (13.1%) | 229 (32.2%) |
| Cincinnati | 1,174 | 86 (7.3%) | 199 (17.0%) | 122 (10.4%) | 179 (15.2%) |
| Columbus | 812 | 60 (7.4%) | 94 (11.6%) | 88 (10.8%) | 174 (21.4%) |
| Denver | 1,355 | 115 (8.5%) | 157 (11.6%) | 165 (12.2%) | 302 (22.3%) |
| Indianapolis | 666 | 46 (6.9%) | 75 (11.3%) | 84 (12.6%) | 180 (27.0%) |
| Jacksonville | 669 | 47 (7.0%) | 79 (11.8%) | 93 (13.9%) | 227 (33.9%) |
| Kansas City | 894 | 45 (5.0%) | 99 (11.1%) | 91 (10.2%) | 212 (23.7%) |
| Knoxville | 231 | 20 (8.7%) | 25 (10.8%) | 37 (16.0%) | 63 (27.3%) |
| Louisville | 516 | 53 (10.3%) | 72 (14.0%) | 77 (14.9%) | 110 (21.3%) |
| Memphis | 297 | 21 (7.1%) | 36 (12.1%) | 36 (12.1%) | 93 (31.3%) |
| Nashville | 774 | 58 (7.5%) | 100 (12.9%) | 82 (10.6%) | 174 (22.5%) |
| Oklahoma City | 511 | 47 (9.2%) | 67 (13.1%) | 61 (11.9%) | 131 (25.6%) |
| Phoenix | 1,421 | 107 (7.5%) | 189 (13.3%) | 251 (17.7%) | 426 (30.0%) |
| Raleigh | 511 | 35 (6.8%) | 59 (11.5%) | 70 (13.7%) | 159 (31.1%) |
| Richmond | 489 | 35 (7.2%) | 52 (10.6%) | 72 (14.7%) | 123 (25.2%) |
| San Antonio | 719 | 54 (7.5%) | 105 (14.6%) | 106 (14.7%) | 173 (24.1%) |
| St. Louis | 3,316 | 252 (7.6%) | 282 (8.5%) | 186 (5.6%) | 322 (9.7%) |

The pooled annual recognition counts are 1,127 in 2022, 1,599 in 2023, 1,235 in 2024, 959 in 2025, and 386 in partial 2026. Nashville metro: 48, 71, 54, 36, 13. Eighteen peers increase from 2022 to 2023; Cincinnati is unchanged at 66. Every peer has fewer 2025 than 2023 rulings. Thus the evidence supports a broadly shared 2023 peak among current-stock survivors, not a sustained rise since 2022. All 19 peers have more surviving 2023-26 recognitions than 2015-19 recognitions, but those periods have different lengths and the recent period is incomplete.

Pooling hides metro variation. These metros are a selected comparison set, not a nationally representative sample. Current-stock conditioning also excludes organizations that have disappeared and attaches current geography to historical recognition dates. Similar recent shares do not by themselves establish national formation rates or a Nashville-specific causal conclusion.

## 7. Sensitivities above approximately 10 percent

- Remove the 2026-presence restriction: 640 rather than 405 (+58.0%). This counts historical entries, not current stock.
- Operating foundations only (codes 02/03): 22 rather than 405 (-94.6%). A legitimate narrower population, not a correction to the PF definition. Excluding code 04 from all-PF counts would be wrong.
- Nashville metro instead of Davidson County: 774 (+91.1%). A changed geography, not a county-definition alternative.
- First observed in BMF from 2023 onward: 82 rather than the 73 ruled from 2023 onward (+12.3%). Different concept; first observation is not formation.

Code 04 alone gives 383 (-5.4%), and latest-month presence gives 397 (-2.0%). Neither crosses 10%. The unobservable mailing-county alternative remains unresolved.

## Reproducibility and confidence

Run `Rscript review-foundations.R` from this folder. It writes metro count and period-share CSVs. The complete run is captured in output/review-foundations.txt with R/package versions and local-input SHA256 values. Optional network reconstruction of monthly evidence: `Rscript review-foundations-fetch-vintage.R` first. The additional read is recorded in _pins.csv. Original computation, original outputs and source data were not edited. No messages were sent and nothing was published.

High confidence in the reproduced arithmetic, code-set interpretation, denominator defect and latest-month count. Confidence is limited for true current legal/operating status and historical formation trends. Mailing-county sensitivity cannot be measured from the supplied fields. Validation includes unique EIN checks, an independent date-year expression, reconciliation of local years against the pinned master, and an automated assertion exposing the original table's truncated denominator.

**The claim is not fair to send as written: retain the reproducible Davidson counts with an explicit year-level registry definition and pinned date, or use the latest-month counts, correct the peer denominator, and replace the national-rise conclusion with a qualified statement about the selected metros.**
