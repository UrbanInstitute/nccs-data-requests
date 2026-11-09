# Nashville round 2 review

Reviewed 9 November 2026. Scope: the six files specified by the user, with local supporting code, cached CORE parquet, e-file headers, and analysis inputs used for verification. Source files were left unchanged.

The draft needs corrections before circulation. The three-year exit implementation reproduces its CSV, and the workforce decomposition is correct. The most consequential interpretation issue is the treatment of organizations recognized after 2023 in the coverage discussion. A remaining tax-year conversion defect also affects the exit denominator.

## Findings in priority order

### 1. P1: Explain the recognition-date mismatch in the coverage table

Locations: `reviewer-draft-round2.qmd:37` and `:46`; the corresponding coverage section in `request.qmd`; Word page 2. Code: `profile-charts.R:140` onward.

The table compares organizations on the 2026 registry with returns for 2023. Its explanatory text attributes the unseen group to postcard filers, late filers, and organizations that stopped. It omits organizations recognized after the filing year being measured.

An independent calculation from the local registry and replayed return selection found:

| Population | No 2023 return seen | Of those, ruling year after 2023 |
|---|---:|---:|
| All registered organizations | 3,306 | 806 |
| Public charities | 2,869 | 722 |

The 722 public charities are about 25 percent of that population's unseen group. Recognition date does not establish founding date, so these should not automatically be called organizations that did not yet exist. It does establish that the explanation needs a separate timing category.

Suggested correction: say this is coverage of the current registry by historical returns, explicitly identify later-recognized organizations, and avoid presenting 71 percent as a historical nonfiling or inactivity rate. If a historical coverage rate is desired, define a historically eligible denominator and disclose its limitations.

### 2. P2: CORE year conversion still misdates short-period returns

Locations: `profile-charts.R:68` through `:75`, and the complete-conversion claim at `reviewer-draft-round2.qmd:29`; Word page 2.

The conversion subtracts one year from every period ending outside December. That is an approximation for ordinary fiscal years, not an exact conversion for short periods. The financial-amount anti-join does not remove every misdated record.

Matching retained CORE records to local e-file headers by EIN, form, and period end identifies four retained Davidson records whose inferred year conflicts with the header's explicit `TAX_YEAR`:

| Form | Inferred year | Header tax year | Period begins | Period ends | Expenses |
|---|---:|---:|---|---|---:|
| 990-EZ | 2020 | 2021 | 2021-05-10 | 2021-06-30 | $0 |
| 990 | 2022 | 2023 | 2023-01-01 | 2023-06-30 | $33,953 |
| 990 | 2022 | 2023 | 2023-02-08 | 2023-09-30 | $84,441 |
| 990 | 2022 | 2023 | 2023-06-23 | 2023-09-30 | $135,686 |

Correcting header-verified years before selecting one record per EIN and year changes the last exit-table denominator from 1,615 to 1,614. The 86 exits and rounded 5.3 percent rate remain unchanged. The other five exit rows remain unchanged in this check.

Suggested correction: use explicit source tax years where a reliable filing match exists, describe the remaining period-end inference as approximate, and regenerate affected outputs. This verification establishes at least four exceptions; it does not establish that these are the only exceptions across all years or geographies. `request.qmd` already acknowledges the general short-period limitation, but the reviewer draft drops it.

### 3. P2: The blanket inflation statement mislabels historical grant totals

Location: `reviewer-draft-round2.qmd:31`, with grant tables at `:158` and `:176`; Word pages 2, 10, and 11.

The draft states that dollar figures are in 2023 dollars. The workforce spending series applies a CPI deflator. The historical funder totals do not: `profile-funders.R:139` sums `amount_total` directly, and `profile-boedecker.R:216` explicitly describes its amounts as filed, without inflation adjustment.

The $34.6 million to $63.4 million funding series and the Boedecker historical dollar totals are therefore nominal. A reader could incorrectly interpret their changes as real growth.

Suggested correction: replace the blanket statement with: "Workforce spending comparisons are in 2023 dollars. Grant amounts are nominal amounts reported on the returns." Preserve the individual table labels for any additional exceptions.

### 4. P2: The location description identifies the wrong data source

Location: `reviewer-draft-round2.qmd:79`; Word page 4.

The draft calls location the address on the organization's return. `build.R:95` joins county and CBSA crosswalks to the geocoded BMF, and `analysis-round1.R:67` onward joins those organization-level fields to the historical panel. `request.qmd:51` correctly identifies current BMF geography applied across history.

Suggested correction: "Location is the organization's address carried in the geocoded BMF, assigned through the published geography crosswalks and applied to every year of its history." Explain that these are neither historical locations nor service areas. Also remove or substantiate the absolute claim that all large regional organizations are based in Davidson, and remove the statement that metro figures lead this draft, whose main tables are county figures.

### 5. P2: Explain changes in population between tables

Locations: `reviewer-draft-round2.qmd:46`, `:89`, `:143`, and `:156`; `profile-charts.R:332`; Word pages 2, 5, 7, 9, and 10.

The coverage table shows 872 full-990 public charities excluding institutions, the expense table 875, and the workforce table 881. These are different populations, rather than a single count carried through the draft:

- Coverage restricts to organizations still on the 2026 registry.
- Expenses use the return union without that restriction and drop zero or missing expenses. Before correcting the short-period dates, 879 full-990 filers consist of 872 current and seven former registry organizations; dropping four current zero-expense filers gives 875. For EZ, 315 consist of 311 current and four former organizations; dropping six zero-expense filers gives 309.
- Workforce uses the e-file charity panel.

The listed-organization comparison similarly uses 123 current public charities excluding institutions, whereas the grant network uses 136 listed Davidson organizations with a broader registry population. The first column header does not explain that restriction.

Suggested correction: give each table its source, registry eligibility, form coverage, and exclusions. Explicitly bridge 123 to 136. Remove the blanket statement that full-990 filers are the population for every financial figure below, since the expense and foundation tables use other forms. Counts should be refreshed after correcting tax years.

### 6. P2: The assertion that the median government-grant share is zero in every year has an exception

Locations: `reviewer-draft-round2.qmd:104` and the corresponding paragraph in `request.qmd`; Word page 6.

For Davidson human services in 2020, 116 of 232 filers report positive grants, exactly half. Among records with positive revenue, the independently calculated median grant share is approximately 0.252 percent, not zero. Exactly half reporting positive grants also illustrates why rounded participation percentages do not establish an exact zero median.

Suggested correction: say "The median share is zero in most population-year groups" and, if needed, give the 2020 exception. Qualify "about two thirds" as a recent-year description: Davidson's all-charity reporting share is 47 percent in 2020 and 34 percent in 2023.

### 7. P2: The Word document breaks a table row across pages

Location: Word pages 9 and 10, listed-organization comparison.

The label "Reporting any government grants (full 990)" splits across the page boundary. Its percentages appear on page 9 while the end of its label appears on page 10 beneath the repeated header. This disconnects the measure from its values. The continuation contains only this fragment and the final table row.

Suggested correction: prevent table rows from splitting and keep the small comparison table together, adjusting preceding content or moving the table if necessary. The coverage and expense tables also devote excessive height to long labels in narrow first columns. Rebalance column widths. All 11 rendered pages were inspected; no additional clipping or overlap was observed.

### 8. P3: Repair the unfinished workforce sentence in the main request

Location: `request.qmd:560` through `:562`.

The sentence begins "The round 1 claim that part of the employee decline was a release artifact is" and runs directly into "the figure for the same organizations is the one to cite." It has no completed predicate or clear conclusion.

Suggested correction: state explicitly which earlier interpretation is withdrawn, then give the balanced-panel recommendation in a separate sentence. The current reviewer draft and Word version do not contain this fragment.

## Checks that passed

- Replayed the current chart script against local registry, e-file panels, and cached CORE inputs, with production writes and provenance appends suppressed. All six rows of `chart_c1c_exits_three_year.csv` reproduced exactly before the independent header-year correction.
- Exit counts are 85, 57, 61, 53, 56, and 86, summing to 398. The PNG's bars agree with the CSV and its final-year qualification is visible.
- The two-year-gap comparison totals 441 observations, with 43 filing again by 2023, or 9.75 percent. The reported 10 percent is correct.
- The three-year nonfiling condition plus no later observed return matches the substance of Harrison and Oxley's method. Their paper dates exit to the last filing year; this draft explicitly labels the first missing year instead. Keep that difference clear in external comparisons. The paper's national benchmarks describe a different population and period, so they are contextual evidence rather than a directly matched Nashville benchmark. Reference: [Harrison and Oxley 2025](https://doi.org/10.1002/nml.21650), sections 4.1.2 and 4.2.
- Workforce changes reconcile: the same 625 organizations report 42,496 employees in 2019 and 42,231 in 2023, a loss of 265. Organizations seen at only one endpoint account for 5,365 versus 2,717 employees, a net loss of 2,648. Together these sum to the total loss of 2,913; changing membership accounts for 90.9 percent. This is an arithmetic decomposition, not identification of why an organization leaves the observed population.
- The Word content agrees with the reviewer draft for the material passages checked, including the current exit table and figures. The Word file renders to 11 pages and includes the five charts.

## Verification limits

The review used local inputs and the existing CORE cache rather than downloading a new release or rebuilding the multi-gigabyte panel. It does not independently revalidate every matched organization, every grant recipient, the spreadsheet's current contents, or every claim in the earlier round 1 analysis. The year-error test used available local 2021 through 2023 headers. The absence of a filing in an observed release remains distinct from confirmed closure. No manuscript, chart, CSV, production script, or pins log was changed by this review.
