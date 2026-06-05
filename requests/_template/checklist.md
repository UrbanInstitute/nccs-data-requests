# Request checklist — <YYYY-MM-slug>

> ⚠️ **This repo is PUBLIC.** Nothing committed here is private. Put the
> requester's identity and the verbatim ask in `_private.md` (gitignored) —
> never in this file, the `.qmd`, or `_pins.csv`. This checklist records only
> non-confidential gate decisions.

## Public-safe gate (required for *every* request)

This determines whether the request *may* ever be promoted. Absence is not
"safe" — leave as `no` until positively confirmed.

- [ ] **Public-safe:** uses only public IRS / published-derived data; the
      `.qmd` contains no confidential requester specifics. → **yes / no**

A `no` here means the request stays a private deliverable. Stop.

## Promotion gates (all three required to publish a data story — ADR 0025)

- [ ] **Generalizable** — says something beyond this one requester's narrow ask.
- [ ] **Public-safe** — confirmed `yes` above.
- [ ] **Worth reading** — a non-specialist would get something from it.

## Before opening the `_stories/` PR

- [ ] Front-matter `citation:` cites the pinned vintages (from `_pins.csv`).
- [ ] `draft: true` removed from the `.qmd`.
- [ ] `quarto render` is clean; figures present.
- [ ] Move `request.qmd` (+ `*_files/` assets) into `../nccs/_stories/<name>.qmd`
      and open a PR on the `nccs` repo.

## Graduation notes (the other two paths — ADR 0024)

- Did a **join / geography** here repeat a prior request? → open an ADR in
  `nccs-contracts` to promote it (crosswalk or API).
- Did a **read helper** get reused? → promote it into `nccsdata`.
