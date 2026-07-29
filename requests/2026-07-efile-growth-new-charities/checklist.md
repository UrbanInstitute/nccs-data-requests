# Request checklist — 2026-07-efile-growth-new-charities

> ⚠️ **This repo is PUBLIC.** Nothing committed here is private. Put the
> requester's identity and the verbatim ask in `_private.md` (gitignored) —
> never in this file, the `.qmd`, or `_pins.csv`. This checklist records only
> non-confidential gate decisions.

## Public-safe gate (required for *every* request)

- [x] **Public-safe:** uses only public IRS / published-derived data (e-file
      v2.1 header tables + geocoded unified BMF); the `.qmd` contains no
      confidential requester specifics. → **yes**

## Promotion gates (all three required to publish a data story — ADR 0025)

- [x] **Generalizable** — likely yes: the e-file mandate step (TY2020-2021)
      and the "new charities growing into the full 990" pipeline are of
      general sector interest, but not yet confirmed by the maintainer.
- [x] **Public-safe** — confirmed `yes` above.
- [x] **Worth reading** — pending maintainer read-through.

## Before opening the `_stories/` PR

- [ ] Front-matter `citation:` cites the pinned vintages (from `_pins.csv`).
- [ ] `draft: true` removed from the `.qmd`.
- [ ] `quarto render` is clean; figures present.
- [ ] Move `request.qmd` (+ `*_files/` assets) into `../nccs/_stories/<name>.qmd`
      and open a PR on the `nccs` repo.

## Graduation notes (the other two paths — ADR 0024)

- **New read helper added**: `read_efile_header()` in `R/request_read.R`
  (first use). Per ADR 0024, on a **second** use promote it into `nccsdata`;
  when the contracted `processed/efile/relational/` tier lands (ADR 0028),
  re-point it there instead of the legacy `nccs-efile` catalog.
- No repeated cross-dataset join/geography yet (first e-file × BMF request).
