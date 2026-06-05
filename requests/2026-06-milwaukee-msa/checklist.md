# Request checklist — 2026-06-milwaukee-msa

> ⚠️ **This repo is PUBLIC.** Requester identity + verbatim ask live in
> `_private.md` (gitignored) — never here, in the `.qmd`, or `_pins.csv`.

## Public-safe gate (required for *every* request)

- [x] **Public-safe:** uses only public IRS / NCCS-published data (BMF master +
      CORE 990 + published crosswalks); the `.qmd` names no requester and carries
      no confidential specifics. → **yes**

## Promotion gates (all three required to publish a data story — ADR 0025)

- [x] **Generalizable** — "nonprofits in metro X, counts + focus + revenue over
      time" is a reusable metro-profile pattern, not one funder's narrow ask.
- [x] **Public-safe** — confirmed `yes` above.
- [x] **Worth reading** — a Milwaukee-metro nonprofit profile (growth, mix,
      revenue sources) is of clear public interest.

Candidate for promotion once revenue (Q3–Q5) is complete and rendered.

## Before opening the `_stories/` PR

- [ ] Front-matter `citation:` cites pinned vintages (from `_pins.csv`).
- [ ] `draft: true` removed from the `.qmd`.
- [x] `quarto render` clean (gfm → `request.md`); live helper reads ran and wrote
      `_pins.csv`. (No figures yet — tables only; add charts before promotion.)
- [x] Revenue (Q3–Q5) completed for **1989–2023** (Form 990/990-EZ + 990-PF,
      nominal + real). Pre-2012 directional (legacy completeness — see qmd).
- [ ] Move `request.qmd` (+ `*_files/`) into `../nccs/_stories/` and open the PR.

## Graduation notes (the other two paths — ADR 0024)

- **Join / geography:** uses the standard BMF → county-fips → cbsa join. First
  CBSA-grain request; if a 2nd metro request lands, consider promoting a
  CBSA-filter convenience (helper or API), not a new crosswalk.
- **Read helper reuse:** none new; existing `read_bmf_master` / `read_crosswalk`
  / `read_core` sufficed.
- **No upstream route needed for historical geography.** The cumulative master
  (one row/EIN, 1989–2026, defunct orgs retained) already supplies historical
  geography/NTEE via the EIN join — CORE's lack of geo/NTEE is by design (ADR
  0016), not a missing artifact. (Legacy-CORE raw files do carry STATE/FIPS/NTEECC
  that harmonization drops, but the master join makes harmonizing them
  unnecessary for this work.)
</content>
