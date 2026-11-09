# Request checklist — 2026-08-single-org-history

> ⚠️ **This repo is PUBLIC.** Nothing committed here is private. Put the
> requester's identity and the verbatim ask in `_private.md` (gitignored) —
> never in this file, the `.qmd`, or `_pins.csv`. This checklist records only
> non-confidential gate decisions.

## Public-safe gate (required for *every* request)

- [x] **Public-safe:** uses only public IRS / published-derived data (Form
      990-PF is a public return; the EIN and organization name are public in
      the IRS BMF). The `.qmd` contains no requester specifics. → **yes**

## Promotion gates (all three required to publish a data story — ADR 0025)

- [ ] **Generalizable** — partly. The "how to read a 990-PF history in plain
      language" framing generalizes; the specific organization does not.
      If promoted, swap the EIN for an anonymized or well-known example.
- [x] **Public-safe** — confirmed `yes` above.
- [ ] **Worth reading** — as a methods piece on single-org lookups, maybe.
      Not promoting on one request; leave `draft: true`.

## Before opening the `_stories/` PR

- [ ] Front-matter `citation:` cites the pinned vintages (from `_pins.csv`).
- [ ] `draft: true` removed from the `.qmd`.
- [ ] `quarto render` is clean; figures present.
- [ ] Move `request.qmd` (+ `*_files/` assets) into `../nccs/_stories/<name>.qmd`
      and open a PR on the `nccs` repo.

## Graduation notes (the other two paths — ADR 0024)

- **Read helper candidate:** "one EIN across all core years" =
  per-year `nccs_read_core(collect = FALSE) |> filter(ein == x)`. First use
  here. On a second single-organization request, promote an
  `nccs_read_core_ein()` (or `ein =` pushdown argument) into `nccsdata`.
- **Upstream issue to route (nccs-data-core / nccsdata):** stacking all
  `merged/990pf` partitions 1989-2024 into one Arrow dataset and filtering
  fails with `Integer value 3762359200 not in range: -2147483648 to
  2147483647`. Arrow unifies a numeric column to int32 across partitions
  while at least one partition holds values above 2^31. Per-year reads work.
  Producer should pin int64/double for all money columns across vintages.
- **Coverage caveat to surface in docs:** merged `990pf` has no rows for
  this EIN in 1992-1993 (legacy) and 2016-2018 (SOI 990-PF extracts are
  near-empty those years); not org-specific.
- **External cross-check:** ProPublica Nonprofit Explorer API queried
  2026-08-28; revenue/assets agree exactly for all 10 overlapping years.
  Standing rule: any claim about what ProPublica holds is verified via the
  API, never asserted.
