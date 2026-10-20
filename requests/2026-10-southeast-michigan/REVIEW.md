# Review of PLAN.md (independent reviewer, 2026-10-20)

Verification level as reported by the reviewer: plan plus contracts
plus live reads of the BMF master and CORE tax year 2023 partitions.

1. "PZ" and "PC" tiers do not exist (verified). Financials are the merged 990combined partition, which has a source_form column separating 990 from EZ. Employees are the SOI 990 partition. Step 3 must name those two reads.
2. Employees field and blank-as-zero (verified). CORE carries Part V line 2a, which Form 990 Part I line 5 is defined to equal, so cite that. Blanks are stored as zero: 47 percent of seven-county full-990 filers show zero employees, and 299 of those report wages. The 0 band must be labelled "zero or not reported."
3. Ruling date placeholder (verified). Missing dates are stored as 1900-01-01. There are 38 such charities in the seven counties. They land in the 50+ band unless the missing flag is used.
4. Number sheet needs a current-vintage filter (verified). The master holds every EIN ever seen. 34,096 of 80,755 Michigan 501(c)(3) rows are stale. Filter on the latest last_vintage_ym, which is 2026-07.
5. Public-charity rule unwritten (verified). Subsection 3, foundation code not in 2, 3, 4, compared as integers because padding varies. Resulting counts range from 505 in Monroe to 8,067 in Wayne.
6. Subsector mapping (verified). Neither NTEE column is the template's ten groups. Fold hospitals into Health and universities into Education. Unclassified is 20 percent and must be explained.
7. Operating surplus (verified). 190 assigned zeros, 18 negative-revenue rows whose sign flips, 44 ratios beyond 1000 percent. Exclude negative revenue and footnote the 0 band.
8. Duplicate EINs in tax year 2023 (verified). 11 in the seven counties, two tax periods each. Keep the latest tax period.
9. Suppression at 10 guts Monroe and St. Clair (verified). Monroe has 47 full-990 filers. Rows sum to 100, so single-cell suppression is recoverable anyway. Publish shares with n per row instead.
10. Dollar band boundaries not fixed (inferred). State lower bound inclusive everywhere. Half of filers have zero liabilities.
11. Vintage mismatch (verified). 81 tax year 2023 filers are gone from the registry. Say the financial sheets cover currently registered organizations.
12. Steps 1 and 2 overlap, step 5 names the wrong folder, timeline is stale (inferred).
13. QA would not catch any of the above (inferred). Add denominator reconciliation by county, a form-type cross-tab, and an external count check for Wayne.
14. County resolution (verified). Every current Michigan 501(c)(3) resolves, but write the drop-and-report rule anyway.
15. Analyst's first name in a public repo (unverified, low). Judgment call.
