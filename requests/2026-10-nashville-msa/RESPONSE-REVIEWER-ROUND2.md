# Response to the senior researcher's review (received 2026-10-29)

Teresa reviewed the round 1 memo (`docs/Initial Memo_tterese_review.docx`,
ten comments) and returned the round 2 reviewer brief without comments or
edits. Her covering email gave five summary points. Every comment is
accepted. This table says what changes in the round 2 write-up and build.
Her three method questions in the brief were not answered directly; the
comments imply answers, noted at the end.

| # | Comment (memo location) | Action | Where |
|---|---|---|---|
| 4 | The 5,100 / 4,500 / 400 registry counts need context: how many file a full 990, a 990-EZ, a postcard. The registry overstates active organizations. | Add a coverage table at the top of the round 2 section: Davidson registry count, then the number observed filing a full 990, a 990-EZ, or a 990-N for TY2023 (CORE merged tier plus e-file), and the remainder with no filing seen. Every later table names its filing population in the column header. | `explore-13-charts.R` (coverage block), `request.qmd` round 2 opening |
| 5 | Hospitals and universities excluded without justification; are they identifiable reliably? | They are identified by the NTEE-V2 subsector code (HOS, UNI) on the registry, not by name, so identification is exact to the coding. Justification to state: they are few, very large, and dominate spending and employee totals, so including them turns every Davidson aggregate into a statement about a handful of institutions. Round 2 shows the main tables both ways (all 501(c)(3), and excluding HOS/UNI) so the reader can see the effect, and names the count excluded. | `explore-13-charts.R`, `request.qmd` definitions |
| 11 | "Recognized" must be tied to one source (registry or filing). | "Recognized" is used only for the registry ruling date. Filing-based statements say "filed". A definitions line states this. | `request.qmd` definitions |
| 12, 23 | "One in five active in 2019 no longer on the registry" must be reconciled with the finding that half of apparent full-990 leavers are a release artifact. | Exit definition rewritten: an organization "exits the registry" when it is absent from the current registry after being present in a 2019 vintage; an organization "stops filing" when no return of any type appears in CORE for two consecutive years after its last return. The two series are reported separately and never summed. The release-artifact finding applies only to the e-file series and is said so. | PLAN.md method question 1 (answered as proposed, with the two-year rule), `explore-13-charts.R` exits block |
| 15 | "Grown 39 percent": metric unstated. | Say "population, Census county estimates 2010 to 2023". | `request.qmd` finding 2 |
| 16, 17 | Employment counts on the 990 are noisy, possibly more so for new organizations; location is the postal address, so a Davidson organization may operate in Williamson. Prefer metro-level comparisons. | Metro-level figures lead every workforce and location finding; county figures follow as secondary with the postal-address caveat in the same sentence. The Rutherford vs Davidson employees-per-resident comparison is kept only as a metro-wide pattern statement. Employee-count noise added to the caveats, with the age split shown as a check (employees per $1M expenses for organizations recognized before vs after 2015). | `request.qmd` findings 2 and 5, caveats |
| 24 | "Paying well" undefined. | Replace with "spending per reported employee on salaries, benefits and payroll taxes (Part IX lines 5 to 10)". | `request.qmd` finding 5 |
| 25 | "Spending more than they took in" must say revenue minus expenses is negative. | Say "total expenses exceeded total revenue (Part I line 18 greater than line 12)". | `request.qmd` finding 5 |

Comments 0, 2, 6, 7, 9, 13, 18, 20 and 22 are the requester team's
comments already answered or scheduled (PLAN.md items A to D); comment 22
(how much is COVID response and ARPA) is answered by chart C and the
caveat that the 990 cannot separate federal relief from other grants.

## Implied answers to the three method questions

1. Exits: comments 12 and 23 call for one clean definition and a
   reconciliation. Proceed as proposed in the plan (filing-based primary
   series through 2022, registry-vintage series as a check), with the
   separation above.
2. Profile comparator: no comment. Proceed with both comparators, headline
   on all Davidson charities, and show the HOS/UNI effect.
3. 990-EZ filers in the profile: comment 4 supports reporting coverage by
   form type for every measure. Proceed with inclusion and a coverage
   column. The spreadsheet fill stays full 990 only, as the requester asked.

## Design rule for round 2

Every table and chart carries its filing population in the title or first
column: registry, full 990, 990-EZ, 990-N, or a named combination.
