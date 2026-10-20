# Review prompt: Davidson County private foundation formation counts

You are independently verifying a small set of numbers before they go to a
colleague at the Urban Institute. Do not read my computation first. Compute
the numbers yourself from the pinned data, then compare. Report each number
you get, the code you ran, and where you disagree. Agreement is not the
goal; the goal is to catch a wrong filter, a wrong column, or a wrong
interpretation. Say how confident you are and why.

## The claim to check

"Davidson County has 405 private foundations on the registry today. Of
those, 73 were recognized from 2023 onward, compared with 53 across all of
2015 to 2019. Year by year: 18 in 2019, 10 in 2020, 8 in 2021, 20 in 2022,
26 in 2023, 21 in 2024, 18 in 2025, 8 so far in 2026. The 19 comparison
metros show the same rise since 2022, so this is a national pattern, not a
Nashville one."

## Where the data are

Folder: `requests/2026-10-nashville-msa/` in the `nccs-data-requests` repo
(branch `request/2026-10-nashville-msa`). House rules in the repo's
`CLAUDE.md`. The data folder is gitignored and local only; the pulls are
already on disk.

| Path | What it is |
|---|---|
| `data/universe_tn.parquet` | Every Tennessee organization in the geocoded Unified BMF, with county and CBSA crosswalk columns joined. Built by `build-panel.R`. Pinned in `_pins.csv`. |
| `data/universe_peers.parquet` | Same shape, for organizations in the 19 peer metros. Built by `build-peers.R`. |
| `_pins.csv` | Which BMF vintage and crosswalk vintage each pull came from. |
| `build-panel.R`, `build-peers.R` | How the universes were built. Read these for the column meanings. |
| `explore-8-bmf.R` | My computation. Read it only AFTER you have produced your own numbers. |
| `output/explore-8-bmf.txt` | My captured output, same rule. |

Relevant columns in the universe files: `subsection_code`,
`foundation_code`, `ruling_date`, `county_name`, `cbsa_code`,
`first_year_in_bmf`, `last_year_in_bmf`.

## Definitions I used, which you should test rather than assume

1. Private foundation: `subsection_code` is 3 and `foundation_code` is one
   of 02, 03, 04 (the IRS foundation status codes for private operating,
   private non-operating, and private foundation with 4942(j)(3) status).
   Check the IRS definition of foundation codes and whether 04 belongs.
   Check whether any codes are stored with or without the leading zero.
2. "On the registry today": `last_year_in_bmf` is 2026 or later. Check what
   vintages exist in the pull and whether 2026 is the latest.
3. "Recognized in year Y": first four characters of `ruling_date`. Check
   the format of that column and whether any values are missing or
   implausible (before 1900, after 2026).
4. Davidson County: `county_name` equals "Davidson County". Check whether
   the geocoded county and the mailing-address county disagree for many
   rows, and whether the count changes much if you use the other.
5. The 2023 to 2026 period is partial: 2026 has eight months of rulings.

## What to produce

- Your own counts for each number in the claim, with the code.
- The same period breakdown for the peer metros as a share of each metro's
  foundation stock, so the "national pattern" statement can be checked.
- Any definition under which the Davidson numbers move by more than about
  10 percent, and what the number becomes.
- One sentence on whether the claim as written is fair to send.
