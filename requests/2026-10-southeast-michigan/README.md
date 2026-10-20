# Southeast Michigan public charities fact sheet

Nine distributions describing 501(c)(3) public charities (private
foundations excluded) in seven Michigan counties: Livingston, Macomb,
Monroe, Oakland, St. Clair, Washtenaw, and Wayne. Each is reported for
the region and for each county, as shares, into the requester's Excel
template. Due 2026-10-30.

| Sheet | Source | Who it covers |
|---|---|---|
| Number, Subsector, Age | NCCS Business Master File (2026 vintage) | All registered public charities |
| Revenue, Expenses, Operating Surplus, Assets, Liabilities | NCCS CORE series, tax year 2023, 990 and 990-EZ filers | Reporting organizations |
| Employees | NCCS CORE series, tax year 2023, full 990 filers | Full-990 filers |

## Files

| Path | What it is |
|---|---|
| `PLAN.md` | Scope, settled definitions, open decisions, measure-to-source map, the seven build steps, timeline. Read first. |
| `REVIEW-PROMPT.md` | Prompt for an independent review of the plan. |
| `template/` | The requester's Excel template and the draft fact sheet it feeds. The draft settles definitions (shares, operating surplus as net income over revenue, age as 2026 minus ruling year). |
| `build-*.R`, `check-*.R` | One script per plan step, written in order. Not yet started. |
| `REVIEW.md`, `RESPONSE-TO-REVIEW.md` | Independent review of the plan and the finding-by-finding response; the plan incorporates both. |
| `output/` | Script outputs. The filled template is written here, never over the original in `template/`. |
| `_pins.csv` | Provenance of every dataset read, written by the helpers in `R/request_read.R`. |
| `checklist.md`, `request.qmd` | Repo template stubs for the public-safety gate and a possible data story. |
| `data/` | Local data pulls, gitignored. |

## How the work runs

One person writes the scripts, one script per plan step, and pushes
each to this branch. A second person reviews each script before the
next starts. Code is tidyverse style with a roxygen comment block on
every function. Reads go through `R/request_read.R` so `_pins.csv`
records every vintage. No AWS credentials are needed.

Repo house rules are in the top-level `CLAUDE.md`. The closest prior
request is `../2026-10-nashville-msa/`.
