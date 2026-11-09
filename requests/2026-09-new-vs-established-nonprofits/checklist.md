# Request checklist — 2026-09-new-vs-established-nonprofits

> ⚠️ **This repo is PUBLIC.** Nothing committed here is private. Put the
> requester's identity and the verbatim ask in `_private.md` (gitignored) —
> never in this file, the `.qmd`, or `_pins.csv`. This checklist records only
> non-confidential gate decisions.

## Public-safe gate (required for *every* request)

This determines whether the request *may* ever be promoted. Absence is not
"safe" — leave as `no` until positively confirmed.

- [x] **Public-safe:** uses only public IRS / published-derived data (CORE
      merged tier, geocoded unified BMF, e-file v2.1 header + Part I); the
      `.qmd` contains no confidential requester specifics. → **yes**

A `no` here means the request stays a private deliverable. Stop.

## Promotion gates (all three required to publish a data story — ADR 0025)

- [x] **Generalizable** — likely yes: a sector-wide trend question (share of
      spending by organization age, 1989-2023) with three-way triangulation;
      not yet confirmed by the maintainer.
- [x] **Public-safe** — confirmed `yes` above.
- [ ] **Worth reading** — pending maintainer read-through; the direction of
      the finding contradicts a common narrative, which argues for promotion.

## Before opening the `_stories/` PR

- [ ] Front-matter `citation:` cites the pinned vintages (from `_pins.csv`).
- [ ] `draft: true` removed from the `.qmd`.
- [ ] `quarto render` is clean; figures present.
- [ ] Move `request.qmd` (+ `*_files/` assets) into `../nccs/_stories/<name>.qmd`
      and open a PR on the `nccs` repo.

## Graduation notes (the other two paths — ADR 0024)

- Did a **join / geography** here repeat a prior request? → open an ADR in
  `nccs-contracts` to promote it (crosswalk or API).
- **Read helper reused (2nd use):** the e-file header read (first used in
  `2026-07-efile-growth-new-charities`) was generalized to `read_efile_table()`
  in `R/request_read.R` and used again here (header + Part I summary). Per
  ADR 0024 this is now due for promotion into `nccsdata`, re-pointed at the
  contracted `processed/efile/relational/` tier when ADR 0028 lands.
- **Join reused (2nd use):** e-file x BMF on `EIN2` (first: 2026-07). Ages by
  ruling date / formation year are a candidate derived field for `nccsdata`.

## Status: shelved (2026-09-03)

Per the requesting team, no further work is planned. The analysis is complete
and reproducible from this folder (`build.R` -> `out/` -> `request.qmd`), and
can be picked up later. The IRS filing data speaks to the arrival of new
organizations and their share of spending; it cannot speak to influence,
for-profit providers, or 990-N filers (see Limitations in `request.qmd`).
