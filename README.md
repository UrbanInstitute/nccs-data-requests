# nccs-data-requests

A **thin consumer** in the NCCS data system: it fulfils ad-hoc data requests
that combine `bmf` / `core` / `efile` data for specific geographies, one
folder per request. It reads canonical S3 artifacts (via the
[`nccsdata`](https://github.com/UrbanInstitute/nccsdata) R package) and the
published geography crosswalks, composes the join the request needs, and
records exactly what it read.

Contracts and the decisions that shape this repo live in
[`nccs-contracts`](https://github.com/UrbanInstitute/nccs-contracts) —
specifically **ADR 0024** (this repo's role) and **ADR 0025** (data stories).

## What this repo is — and is not

- ✅ Reads canonical artifacts (`nccs_read`, `nccs_read_core`,
  `nccs_vintage_url`) and **joins the published crosswalks** for geography.
- ✅ **Pins** the contract versions / vintages it reads, per request, so a
  deliverable is reproducible from its folder alone.
- ✅ Authors each request as a reproducible **Quarto `.qmd`** — the
  deliverable *is* a draft data story.
- ❌ Not a producer: publishes **no** S3 data artifact, has **no**
  `contracts/*.yml`, and is **out of the drift loop**.
- ❌ No private upstream ETL. If a request keeps re-cleaning a producer
  output, that's a missing artifact — route it upstream, don't bury it here.
- ❌ Not a merge layer. It re-derives no geography; it joins the crosswalks
  (`county-fips` / `cbsa` label joins; the `ct-planning-region` coordinate
  join for Connecticut).

## The three graduation paths

This repo is a **detector**. A routine request stays a private deliverable;
when a request generalises, it graduates — and stops being ad-hoc:

| When a request… | Graduates to | ADR |
|---|---|---|
| repeats a cross-dataset **join / geography** (2nd request) | a crosswalk or the API | 0024 |
| reuses a **read helper** (2nd use) | the `nccsdata` package | 0024 |
| is **generalizable + public-safe + worth reading** | a **data story** in `nccs/_stories/` | 0025 |

The rule: the *moment* a join/helper is needed a second time, promote it —
don't let private logic ossify here.

## Starting a request

```sh
cp -r requests/_template requests/2026-06-<slug>
```

Then, in `requests/2026-06-<slug>/`:

1. Edit `request.qmd` — fill the front-matter, read your pinned data through
   the helpers in `R/request_read.R` (they log every read to `_pins.csv`),
   compose the join, write the analysis.
2. Work `checklist.md` — record the **public-safe** determination and, if you
   intend to promote, the three gates and the pinned-vintage citation.
3. Render to preview: `quarto render requests/2026-06-<slug>/request.qmd`.

## Promoting to a data story

If the request clears all three gates in `checklist.md`, move the `.qmd`
(plus its `*_files/` assets) into `nccs/_stories/` and open a PR there. The
website renders it (gfm + `layout: story`) and hosts it at `/stories/<name>/`.
The story **must** cite its pinned vintages (front-matter `citation:` block).

## Setup

Reads use `nccsdata` (installs from GitHub) plus `arrow` + `dplyr`. With
[`pak`](https://pak.r-lib.org):

```r
pak::local_install_deps()   # reads DESCRIPTION
# or: pak::pkg_install("github::UrbanInstitute/nccsdata")
```

S3 reads use the `nccsdata` defaults; for the `nccs-data-*` buckets set your
AWS profile as usual.
