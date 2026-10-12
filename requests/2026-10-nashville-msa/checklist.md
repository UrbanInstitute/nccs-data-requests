# Request checklist — 2026-10-nashville-msa

> This repo is PUBLIC. Requester identity and the verbatim ask live in
> `_private.md` (gitignored), never here, in the `.qmd`, or `_pins.csv`.

## Public-safe gate (required for every request)

- [x] Public-safe: public IRS / NCCS-published data only (Unified BMF, e-file
      v2.1, e-file Phase 0, published crosswalks) plus public Census and BLS
      series. Named organizations appear only as the largest government
      grant recipients and employers, which are public 990 facts.

## Promotion gates (ADR 0025)

- [ ] Generalizable: a "capacity vs population growth by county" and a
      "government vs private funding mix" metro profile is reusable, but
      this is an exploration, not yet a story.
- [x] Public-safe: yes.
- [ ] Worth reading: findings 1, 2 and 4 are candidates; finding 5 needs the
      exit cohort checked (closure vs 990-EZ switch) before it is cited.

## Review

- [x] Second-analyst review received 2026-10-12 (`REVIEW.md`, 12 findings), all
      accepted; response in `RESPONSE-TO-REVIEW.md`; build and outputs
      regenerated.
- [ ] Trace the exit cohort into the 990-EZ (CORE merged tier) before
      finding 5 is cited.

## Status

Exploratory deliverable only (five-hour engagement). Tables in `request.qmd`
are static values copied from `output/` after the post-review rebuild on
2026-10-12.
Before any promotion: re-express tables as computed chunks, add figures,
and cite pinned vintages in the front matter from `_pins.csv`.

## Graduation notes (ADR 0024)

- Geography: standard BMF -> county-fips -> cbsa join, second CBSA-grain
  request after Milwaukee. A CBSA-filter convenience is now wanted twice.
- Read helpers: `read_crosswalk` was bypassed with an HTTPS download because
  the S3 URI needs credentials; the helper should offer an anonymous HTTPS
  path. The e-file org-year panel build (Part I + Part IX, dedup) is now
  written a second time (Milwaukee, Nashville) and is a promotion candidate.
- Phase 0 `government_grants` read is a first use from this repo.
- Filing selection for e-file v2.1 part tables (one filing per EIN x year,
  shared OBJECTID across parts) is producer semantics written here twice;
  route upstream per ADR 0024 rather than keep re-deriving it.
