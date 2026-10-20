# Review prompt: Southeast Michigan fact sheet plan

You are reviewing a plan, not code. The plan says how a junior analyst
will fill a requester's Excel template with nine distributions
describing 501(c)(3) public charities in seven Michigan counties, from
the NCCS Business Master File (BMF) and the NCCS CORE series. The
analyst will write the scripts after this review; the author of the plan
will review their code. Your job is to find what in the plan is wrong,
underspecified, or likely to produce a number the requester will
misread. Report each finding with the plan line it concerns, what you
checked, and how confident you are. Agreement is not the goal.

Label each finding: verified (you read the artifact or contract),
inferred, or unverified. State your verification level at the top:
plan-only, or plan plus the contracts and data documentation.

## Where everything is

Branch `request/2026-10-southeast-michigan` in the `nccs-data-requests`
repo (public). Folder `requests/2026-10-southeast-michigan/`.

| Path | What it is |
|---|---|
| `PLAN.md` | The plan under review: ask, template description, settled definitions, open decisions, measure-to-source map, seven build steps, timeline. |
| `checklist.md`, `request.qmd` | Repo template stubs, not yet filled. |
| `template/` | Gitignored. The requester's Excel template (nine sheets) and a draft of the fact sheet it feeds. Not available to you; the plan's template section transcribes the sheet layout and the definitions the draft settles. Treat that transcription as the requester's specification. |
| `../../CLAUDE.md` | Repo house rules: read canonical artifacts, never re-derive geography, pin every read through `R/request_read.R`. |
| `../../R/request_read.R` | The read helpers the scripts must use. |
| `../2026-10-nashville-msa/` | The closest prior request (county-level profile from BMF and 990 data). Its `PLAN.md` and `build-*.R` show the house pattern. |
| `../../../nccs-contracts/contracts/*.yml` | Authoritative schemas and S3 paths for the BMF, crosswalks, and CORE tiers. |
| `../../../nccs-contracts/conventions/ein-format.md` | EIN conventions for joins. |

## What to check

### 1. Source to measure mapping

- The plan maps the first three sheets (count, subsector, age) to the
  geocoded BMF master and the county-fips crosswalk, and the six
  financial sheets to the CORE series. Check against the contracts that
  each named field exists: county resolution via the crosswalk, NTEE
  major group, ruling date, total revenue, total expenses, end-of-year
  assets and liabilities, and Form 990 Part I line 5 employees. Name any
  field the plan assumes that the contract does not carry.
- The requester's source lines say "Core PZ file" for the financial
  sheets and "Core PC file" for employees. Check what the CORE tiers in
  this system actually distinguish (form type, organization type) and
  whether "PZ" (public charities, 990 and 990-EZ) and "PC" (public
  charities, full 990) can be reproduced from them. If the CORE series
  does not separate 990-EZ from full 990 rows, say so; the employees
  sheet depends on it.
- Age is 2026 minus ruling year. Ruling year is the year of the IRS
  determination letter, not founding. Is that caveat in the plan's
  methods note item? Should it be?

### 2. Sample and denominators

- "Registered 501(c)(3) public charities" for the BMF sheets: the plan
  does not say how public charity is identified (subsection code 3 plus
  foundation code, or another rule) or whether organizations with a
  Michigan address but no resolvable county are dropped or counted. Both
  need a rule. Propose one if the plan lacks it.
- Each sheet has a different denominator (all registered; 990 and EZ
  filers; full-990 filers). Check that the plan's QA step would catch a
  share computed over the wrong denominator.
- The subsector sheet keeps hospitals and universities. The plan notes
  the Nonprofit Trends Core Sample excludes them and treats the sample
  question as probably closed. Is that a safe reading, or should the
  plan hold both samples until the requester confirms?

### 3. Definitions that will be misread

- Operating surplus is net income over total revenue, zero when revenue
  or net income is zero. With negative or near-zero revenue the ratio
  explodes. Does the plan say what happens to those rows? Should it trim,
  cap, or exclude them, and does the "0%" band in the template absorb
  the assigned zeros in a way that distorts that band?
- Dollar bands: "Less than $100K" and "$100K to $499K" leave the
  boundary ambiguous. Does the plan fix the convention (lower bound
  inclusive) and is it the same across the four dollar sheets?
- Employees: Part I line 5 counts W-2 employees. Blank versus zero: does
  the plan say how blanks are treated, and does the "0" band then mix
  true zeros with blanks?
- Tax year 2023 for financials against a 2026 BMF vintage for counts.
  Say whether mixing vintages creates an inconsistency the requester
  will notice (an organization counted in 2026 but filing nothing in
  2023, or the reverse).

### 4. Suppression and small counties

- The plan proposes suppressing cells under 10 organizations. For
  Monroe and St. Clair, the full-990 denominator may be a few hundred and
  some bands a handful. Would suppression leave those rows unusable, and
  would combining bands be a better rule? Does complementary suppression
  matter when the row sums to 100?

### 5. The build steps

- Seven steps, one script each, reviewed in sequence. Is the order
  right, is anything missing (for example a step that records the BMF and
  CORE vintages into `_pins.csv` and the methods note), and is any step
  too large for a 6-hour junior budget with the author doing review?
- Step 6 QA: shares sum to 100, counts reconcile across steps, region
  equals the sum of counties, three EINs checked by hand. What check is
  missing that would catch the most likely error?

## What to report

A numbered list of findings, most serious first. For each: the plan
section, the problem, the evidence, the fix you suggest, and your
confidence. End with anything you could not check and why.
