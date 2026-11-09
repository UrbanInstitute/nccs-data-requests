# Nashville exploration: second-analyst review

Reviewed 2026-10-12. Recommendation: revise before sharing. The county tables mostly transcribe correctly, but several interpretations and reproducibility claims need correction.

Scope: read all analysis scripts, INPUTS.md, pins, checklist, stored console outputs, and both supplied text references. Independently recomputed selected results from local parquet, scanned all 24 raw Part I/IX CSVs, and used a 2,000-resample bootstrap for the two local exit-cohort median gaps. Did not read `_private.md`, download replacement inputs, or modify the analysis. Raw audits reapply the dedup algorithm with OBJECTID retained. Their arbitrary selections under timestamp ties need not reproduce the already-written panel.

A read-only detector is included as `review-validation.R`. Run it from the repo root with `Rscript requests/2026-10-nashville-msa/review-validation.R`. It confirms panel uniqueness and complete grant join coverage, then intentionally fails on tied latest timestamps and mixed filing identities. Its verification execution selected 6,312 mixed filing IDs, another illustration of the nondeterminism. It does not overwrite data or pins.

## Findings, most serious first

### 1. Filing selection is nondeterministic and can combine different returns

**Evidence:** `build-panel.R:110-126,131-132,162`; latest selection is performed separately for Parts I and IX and ordered only by RETURN_TIME_STAMP. OBJECTID is discarded before the EIN2/tax-year join.

**Expected:** one deterministically selected filing, with all parts belonging to that filing.

**Found:** each raw part has 3,249,518 in-scope rows and 3,174,130 unique EIN2/tax-year keys. There are **36,611 keys tied at the latest timestamp** in each part. Two independent audit executions retaining OBJECTID produced **6,263 and 6,241 cross-part filing-ID mismatches**, despite identical timestamps and no missing Part IX keys. The changing result demonstrates the unstable selection. In the latter execution, 28 Nashville charity rows were mismatched, all outside the 2019/2023 endpoints; nine endpoint rows were mismatched in the outside-20-metros comparator.

This does not establish that compensation values differ between those filings or that the existing Nashville endpoint estimates are wrong. It does establish that the build can mix returns and cannot guarantee the same result on rerun. Choose a shared filing key once, use a deterministic tie-breaker, join parts on that key, and assert key uniqueness and filing identity. Route reusable filing-selection logic upstream rather than inventing producer semantics here.

**Confidence:** confirmed by rerunning the raw selection algorithm; financial impact unverified.

### 2. Davidson's first-place pay-growth ranking is not robust

**Evidence:** `request.qmd:94-96,212`; `explore-9-davidson.R:22-30`. The stated robustness output in explore-6 does not rank central counties.

**Expected:** a first-place headline supported by the alternate endpoint, or its sensitivity stated beside it.

**Found:** with the same trimmed pay definition, Davidson is **1st of 20 for 2019-2023 (+6.89%)**, but **6th for 2019-2022 (+3.31%)**. Cincinnati leads the latter comparison at +5.51%. The Nashville metro remains first under both endpoints: +9.91% through 2023 and +7.05% through 2022.

The endpoint matters for jobs too: Davidson employment changes -0.99% through 2022 versus -5.93% through 2023; metro employment is essentially flat through 2022 (-0.09%). Describe the observed release, not an established fall in sector employment. A 2022-to-2023 count decline is not an independently estimated completeness rate: the local declines are 3.29% in Davidson and 1.86% in the metro, and can include exits and switches as well as missing returns.

**Confidence:** confirmed by rerunning.

### 3. The funding interpretation overstates what line 1e measures, and uses the wrong county subsector figures

**Evidence:** `request.qmd:181-203`; `explore-7-govgrants.R:31-34`; `output/explore-7-govgrants.txt`, county and human-services tables.

**Expected:** claims limited to government grants reported on line 1e, with consistent human-services comparisons.

**Found:** Williamson **3.6%** and Rutherford **4.9%** are shares for all included charities, inserted into a paragraph about human services. The recomputed human-services shares are **1.42% and 3.10%**, respectively. The human-services collar share is **7.8%**, versus Davidson 15.7%.

Line 1e excludes government payments classified as program-service revenue, including some contracts and reimbursements. Consequently, neither “draw less from government” nor “84 to 96% government funded” is established as a statement about all government revenue. Use “reported line 1e government grants as a share of revenue.” The distinction is supported by the producer dictionary (`../nccs-data-efile/inst/concordance/nccs_dictionary.csv:2`) and [IRS Form 990 instructions, Part VIII lines 1e and 2](https://www.irs.gov/instructions/i990).

There is also a rank transcription error: Davidson is **13th of 20** on human-services government-grants share. It appears on row 14 of the printed table because “Rest of US” is an extra row. The national 23.8% comparison is useful but is not a comparison with equivalent central counties. Present both comparators and identify the county-selection limitation below.

**Confidence:** confirmed by reading and rerunning.

### 4. “Months of reserves” is not a measure of spendable reserves

**Evidence:** `request.qmd:82-83,233-236`; `explore-2-finance.R:29`.

**Expected:** a liquidity or operating-reserve measure if describing months of reserves.

**Found:** the numerator is **total net assets**, including restricted funds and assets such as buildings. Twelve times net assets over annual expenses is an accounting ratio, not months of cash or funds available to support operations. The 20% under-three-month figure and balanced-panel ratios match the calculation, but the label invites a false comparison with the supplied Urban Wire discussion of cash on hand.

Rename it “net assets expressed in months of annual expenses” and explicitly state that availability and liquidity are unknown. Also use “expenses exceed revenue” rather than implying an operating deficit net of nonoperating items.

**Confidence:** confirmed by reading.

### 5. ZIP-code ranking contradicts the proposed formation story

**Evidence:** `request.qmd:156-165`; `explore-8-bmf.R:62-65`; `output/analysis-round1.txt (pass 8):128-155`.

**Expected:** the claimed highest new-organization ZIPs should actually rank highest.

**Found:** recent-ruling counts are **37013:130, 37211:115, 37203:102, 37209:86, 37215:81, 37207:75**. Midtown 37203 is third, ahead of both ZIPs described as following the first two. Its 32 charities with reported assets above $10 million also make it an obvious counterexample to the broad headline. Corresponding counts are 2 in 37013, 8 in 37211, and 2 in 37207; the conclusion can be narrower, but does not follow from asset totals alone.

The 65 human-services organizations in 37207 are **all active charities there**, not necessarily 65 of the 75 recent rulings. Ruling dates measure exemption recognition, and addresses are current assigned addresses, not locations at founding. Write “recently recognized organizations currently located in these ZIPs.”

**Confidence:** confirmed by reading and rerunning.

### 6. National comparators change across scripts

**Evidence:** `request.qmd:52-53,191,215,226-234`; `explore-6-national.R:27`; `explore-7-govgrants.R:15`; `explore-9-davidson.R:20`.

**Expected:** “Rest of US” always excludes the 20 metros, as defined in the narrative.

**Found:** scripts 6 and 7 group **all non-Tennessee organizations**, including the 17 non-Tennessee peer metros, as Rest of US. Scripts 9 and 10 use the outside-20-metros group. The two 2023 populations have **238,304 versus 211,745 filers**. Script 6 reports employee growth **+1%** and pay growth **+0.7%**; the narrative's **-2% and +0.5%** are the outside-20-metros results. Script 7's broader comparator has government share **15.3%**, whereas the table's 14.8% comes from the narrower group.

The narrative numbers are often legitimate calculations, but the comparator provenance is inconsistent. Fortunately, rerunning the balanced outside-20-metros benchmark gives +3.49% median within-organization pay change and human-services deficit shares 40.3% to 44.2%, so those rounded claims survive. Use one explicit geography variable throughout and regenerate outputs and tables together.

**Confidence:** confirmed by reading and rerunning.

### 7. Exit-cohort evidence supports the metro gap better than the Davidson gap

**Evidence:** `request.qmd:225-231`; `explore-9-davidson.R:44-47`. Neither the metro exit calculation nor its figures occur in the supplied explore-6 script/output, despite the review prompt attributing them there.

**Expected:** traceable cohort calculations with uncertainty and a clear distinction between absence from this panel and closure.

**Found:** independent recomputation confirms metro medians **$31,629 versus $41,560** and Davidson **$39,786 versus $44,411**. Of the 128 metro and 81 Davidson staffed exits, only **113 and 70**, respectively, have retained pay values. Stayer valid counts are 734 and 429.

A percentile bootstrap for the exit-minus-stayer median gap gives approximate 95% intervals of **-$15,125 to -$5,030 for the metro**, but **-$15,619 to +$3,740 for Davidson**. The Davidson median gap is not clearly separated from zero by this check. These are exploratory resampling intervals within a selected filing population, not proof of a population causal effect. Smaller organizations switching to EZ, reporting changes, late returns, and merger remain plausible explanations. The outside-20-metros medians are $37,478 for exits and $37,218 for stayers, close rather than literally equal.

Retain the metro result only as descriptive evidence about retained full-990 records. Do not interpret it as lower-paid employers closing, or as a demonstrated decomposition of the pay rise. Fix caveat 4's reference from “section 4” to finding 5.

**Confidence:** confirmed by rerunning; exit mechanisms unverified.

### 8. Volunteer labels mix positive reporting, missingness, and denominators

**Evidence:** `request.qmd:114-116,238-256`; `explore-10-volunteers.R:12-21,40-45`.

**Expected:** “reporting volunteers” includes an explicit zero; a table described as reporting both uses that population consistently.

**Found:** `reports_vol` means **strictly positive volunteers**. Davidson has 583 positive, 135 zero, and 165 blank values in 2023. Thus **66%** is the positive share, **81.3%** report a nonmissing value, and **18.7%** are blank. The median 40 includes positive-volunteer organizations with no paid employees; among positive-volunteer organizations with positive employment it is **50**. Label each column's denominator.

The 4.0 volunteers-per-employee result matches the output, but its “11th” rank is a printed row position among tied displayed values, not a declared ranking rule. The balanced volunteer calculation also excludes organizations changing from positive counts to zero or blank, so “reporting in both years” actually means positive in both years.

The total decline is real within these records: **226,840 to 173,719**, or -23.4%. Hands On Nashville and Tennessee Environmental Council contribute **25,879 of the 53,121 decrease (48.7%)**. The 377 organizations positive in both years fall from 201,096 to 156,146 (-22.4%), yet the median organization has **zero change**. Human services has 90 positive-positive organizations and a median -6.9%. Report these as estimates from selected returns, not a demonstrated 23% fall in distinct volunteers or volunteer hours. The 2015 Davidson total was 350,740, reinforcing the series' instability.

**Confidence:** confirmed by reading and rerunning.

### 9. The QCEW comparison mixes dollar bases and incompatible measures

**Evidence:** `request.qmd:219-223`; `output/qcew_private_pay_benchmarks.csv`; `explore-2-finance.R:24-27`.

**Expected:** consistent 2023 dollars and an appropriately qualified comparator.

**Found:** the $36,400 to $41,700 nonprofit series is real, whereas QCEW's **$30,998 to $41,547** is nominal. The CPI factor is **1.191839**; QCEW's 2019 value in 2023 dollars is **$36,945**, giving **12.46% real growth**, versus approximately **14.72%** for the nonprofit human-services median. The all-private real growth of 6.26% does support the rounded 6% statement.

However, QCEW measures wages per annual-average job, whereas this nonprofit measure includes benefits and payroll taxes per calendar-year headcount. It also compares Davidson NAICS 624 with metro-wide NTEE HMS and a median across organizations. Similar growth does not establish keeping pace in wages “for the same work.” Replace that inference with a qualified comparison of distinct measures.

**Confidence:** confirmed by reading and rerunning.

### 10. Reproducibility is overstated

**Evidence:** `request.qmd:269-278`; `_pins.csv`; `build-panel.R:47-61`; `explore-5-charities.R:6`; `explore-7-govgrants.R:6`; `INPUTS.md`.

**Expected:** the prescribed script sequence reconstructs the deliverable from immutable identified inputs.

**Found:** BMF reads and government grants use rolling/latest paths. Pins record dates and labels, not immutable versions or hashes of those actual files. Crosswalk downloads reuse any existing local file. The script sequence does not download government_grants.parquet or construct county_pop.csv from the Census files, although downstream scripts require them. The request also depends on Milwaukee's gitignored raw files and its input manifest. Calling the existing analysis “reproducible from its folder alone” would be incorrect.

Record actual immutable sources and hashes, add the missing download/extraction steps, verify cached file identity, and provide a complete entry point. Do not simply add another dated label to a mutable URL.

**Confidence:** confirmed by reading.

### 11. Government-grants coverage check is broken, though coverage currently passes

**Evidence:** `explore-7-govgrants.R:19-20`.

**Expected:** a join-presence indicator separate from whether the extracted amount is missing.

**Found:** `!is.na(...) | TRUE` always reports 100%. Independently adding an indicator to the right-hand table confirms **zero unmatched rows** in all four tax years in the current charity panel. The 58% missing amounts therefore represent matched records with blank extracted values, not failed joins here. Davidson alone has **526/883 (59.6%)** blanks in 2023.

Treating an omitted XML amount as zero can be a working convention after checking extraction status and representative source filings, but the current consumer audit does not prove those omissions are all true zeros. State the assumption and check blank/nonblank distributions by year and geography. The individual share cap at one does not cap aggregate grants/revenue, because aggregation uses raw gg0; flag numerator/denominator inconsistencies instead of obscuring them.

**Confidence:** broken check and actual join coverage confirmed by rerunning; universal blank-as-zero interpretation unverified.

### 12. An exploratory employer diagnostic selects three organizations, not five

**Evidence:** `explore-6-national.R:48-54`; `output/explore-6-national.txt`, top-employer and excluding-top-five tables.

**Expected:** top five unique employers in 2019.

**Found:** including org_name in the pivot's identifier splits YMCA and Goodwill into separate rows when capitalization changes. `big$ein2[1:5]` contains only **three unique EINs**, selected on the maximum employment of either endpoint rather than 2019 employment. The stored diagnostic claims employment outside the top five fell from 14,195 to 11,618. Correctly selecting the five largest 2019 employers instead gives **10,873 to 12,226 (+12.4%)**, while the five themselves fall from 11,009 to 7,759 (-29.5%). The diagnostic's interpretation reverses.

This is not directly copied into the narrative, but it is unsafe supporting evidence. Pivot by EIN and attach display names afterward.

**Confidence:** confirmed by reading and rerunning.

## Additional limitations and numerical trace

- The selected “principal counties” are the counties with most current registered organizations, not a uniform definition of city or urban core. The output selects St. Louis County and Henrico County. Keep a county comparison if desired, but explain analyst selection and show a city/county alternative before claiming equivalent central-city rankings. The 19 peers are analyst-selected, not the Tennessee Nonprofit Network's peer states in the supplied brief.
- Geography uses published crosswalk joins, as required. Local checks confirm 14 distinct counties for CBSA 34980, Davidson FIPS 47037, and 71,133 unique Tennessee EINs without join multiplication. Historical records use the BMF's assigned geography and classification, not year-specific addresses or historical tax status. Historical movers and service reach cannot be recovered from this analysis.
- The financial panel has **2,350,612 unique EIN2/tax-year rows**. Raw filters correctly require RETURN_TYPE 990 and in-column tax year 2012-2023. Thus 990-PF returns are excluded. However, there is no foundation-code exclusion: two Nashville 2023 full-990 records have current BMF foundation code 4 (Gibson Foundation and Dr Lynn Hicks Foundation). This may reflect status changes or source inconsistency; “public charities” is not separately verified by the current filter. Investigate rather than silently reclassify.
- Density includes all subsection-3 organizations, including private foundations. That is defensible for registered-organization density, but not interchangeable with direct-service charity capacity. All six displayed density rows and all six spending/workforce rows match explore-5, including Rutherford's 37 human-services filers. Their 2023 endpoints are historical estimates from the current BMF, not current 2026 density. Finding 1's spending measures are also TY2023, so the proposed map is not wholly current.
- The first/last BMF observation interval is not continuous verified activity. Tennessee first-observed counts include **14,461 in 1989**, **9,810 in 1995**, and none in 2017 or 2021. These are observation/vintage artifacts, not annual formation rates. The main ZIP finding uses ruling dates rather than first observation, but its surviving-current-stock selection misses organizations that formed and disappeared.
- The 29% metro stock growth, sixth-place ranking, religion/arts/human-services mix, foundation densities and Williamson/Davidson foundation growth match explore-8. The printed attrition values have a **20% peer median**, rather than the narrative's 21%; it is fair to say close to peers. Latest assets round to $251 million for Dettwiller, slightly outside the stated $150-250 million range. “Seven to eight in ten in every county report under $50,000” is also too strong: several counties are at 83-86%, and the code counts missing revenue as zero (`explore-8-bmf.R:50`).
- The Davidson/metro growth rows, fifth-highest Davidson 2023 median pay, local exit medians, grant recipient amounts, and positive-volunteer ratios mostly match their supplied outputs. The metro exit figures are independently reproducible but absent from the saved output. National values need the comparator fixes above. Balanced HMS net-assets ratios are 9.6 to 10.8 months, so describe the actual change instead of simply “held near 11.”
- Compensation columns are present in the actual Part IX header and the sum includes lines 5-10, including compensation to disqualified persons omitted from the prose list. The missingness rule and CPI deflation implement the stated calculation. Across Nashville's combined 2019/2023 charity rows, 22 positive-employment records fall below the nominal $5,000 bound and four above $400,000; 1,875 pay values remain. Bounds are arbitrary, applied before deflation, and exclude potentially real part-time/seasonal organizations. Report valid sample sizes and check alternate bounds before emphasizing ranks.
- “Full-990 filers” are observed returns, not a census of organizations: national BMF matching drops **2,014 raw full-990 rows in 2019** and **3,397 in 2023** before the subsection filter. Voluntary e-filing in earlier years, current classifications, unclassified subsectors, group returns, partial tax periods, and missing amounts require explicit coverage qualifications. The legacy v2.1 release's planned supersession is documented in `R/request_read.R:87-91`; add it to the source limitations.
- The contribution-share jump and deficit dip in 2020-2021 also appear in explore-6's national series. The narrative does not currently headline these as uniquely Nashville effects; keep any pandemic comparison explicitly national and descriptive.
- No financial/workforce finding purports to measure post-TY2023 conditions. References to later survey periods and current BMF stock are appropriately differentiated, except the overbroad “both are current” proposal. A proposed TY2024 extension is not an existing TY2024 result. The supplied survey discussion is compatible with this earlier IRS analysis once cash-versus-net-assets and wage-versus-headcount measures are separated.
- No direct requester identity or verbatim private ask was found in the reviewed tracked text. `_private.md` is absent from the tracked-file list. Named organizations in the analytical findings are used for public IRS/BMF facts. This is a tracked-text check, not verification of publication permissions for the supplied reference PDF.

## Three changes before sharing, and deletions

1. **Make the build auditable:** shared deterministic filing selection with identity assertions; one national comparator; actual grant join checks; immutable input identification and the missing reconstruction steps. Regenerate the tables from those results.
2. **Correct the substantive claims:** disclose Davidson's sixth-place 2022 sensitivity; narrow government-grants language and fix its subsector figures/rank; rename the net-assets ratio; qualify QCEW comparisons, exits, and volunteer changes.
3. **Rewrite the geography story:** correct the ZIP ranking, distinguish recent rulings from founding, label historical versus current endpoints, and add current-address, service-area, coverage, and analyst-selected-peer limitations.

Delete the “formation away from large institutions” headline, the “same work” pay-market inference, unqualified “government funded” language, and the claim that Davidson is robustly first on pay growth. Delete or replace the incorrect top-five employer diagnostic. Do not delete the descriptive county tables or metro pay result, which remain useful with these qualifications.
