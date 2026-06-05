# nccs-data-requests — context for Claude Code sessions

You're in `nccs-data-requests`, a **thin consumer** in the NCCS multi-repo
data system. It fulfils ad-hoc requests combining `bmf` / `core` / `efile`
data for specific geographies, one folder per request under `requests/`.

The contract surface and the load-bearing decisions live in the sibling
repo `../nccs-contracts` — read **ADR 0024** (this repo's role) and **ADR
0025** (data stories) there before non-trivial work. Sibling repos are one
level up under `../` (notably `../nccsdata`, the read package, and `../nccs`,
the website with the `_stories/` collection).

## House rules (from ADR 0024 / 0025)

0. **This repo is PUBLIC.** Never commit confidential requester specifics
   (name, verbatim ask, any non-public data). They go in a gitignored
   per-request `_private.md`. The `.qmd`, `checklist.md`, and `_pins.csv` are
   all world-readable — keep them about the analysis, not the requester.
1. **Read canonical artifacts; never re-derive.** Use `nccsdata`
   (`nccs_read` for the rolling geocoded BMF master, `nccs_vintage_url` to
   pin a dated BMF snapshot, `nccs_read_core` for core). Geography is a
   **join onto the published crosswalks** (`county-fips` / `cbsa` by label;
   `ct-planning-region` by coordinate for Connecticut) — do not write county
   or CBSA resolution logic here.
2. **No private upstream ETL.** If a request needs a producer output
   re-cleaned, that's a missing artifact → route it upstream (open an issue
   in the producer repo), don't absorb it here.
3. **Pin everything you read.** Use the helpers in `R/request_read.R`; every
   read appends to the request's `_pins.csv`. A deliverable must be
   reproducible from its folder alone.
4. **Publish no S3 data artifact.** This repo is not a producer: no
   `contracts/*.yml`, no `_manifest.json`, out of the drift loop. The only
   thing it "publishes" is a human-facing **data story**, and only by PR into
   `../nccs/_stories/`.

## The three graduation paths (this repo is a detector)

- A cross-dataset **join/geography** wanted a 2nd time → promote to a
  crosswalk or the API (ADR in `../nccs-contracts`).
- A **read helper** reused → promote into `../nccsdata` (a new export).
- A **generalizable, public-safe, interesting** request → promote to a data
  story in `../nccs/_stories/` (ADR 0025; clear the three gates in the
  request's `checklist.md` first).

Don't let logic that's been needed twice stay private here — promote it.

## Anatomy of a request

```
requests/<YYYY-MM-slug>/
  request.qmd     # Quarto data story (front-matter + analysis); the deliverable
  checklist.md    # public-safe gate + (if promoting) the 3 gates + pinned-vintage citation
  _pins.csv       # auto-written provenance: every artifact/vintage read
  data/           # local data pulls — gitignored (provenance is _pins.csv, not the bulk data)
```

Start a request by copying `requests/_template`. Reads flow through
`R/request_read.R`.
