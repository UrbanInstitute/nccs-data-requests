# Reproducible computation for the Milwaukee MSA request.
# Produces the deliverable CSVs (full subsector names, plain headers).
# v2 (2026-06-23): adds a Milwaukee-County breakout (a `geography` column in
#   every metric file: "Milwaukee MSA (4-county)" vs "Milwaukee County") and a
#   named 2023 filer roster (filers_2023_named.csv). No new S3 datasets — the
#   county split and roster are re-aggregations of the same reads.
# Run with AWS_PROFILE=thiya. ~15 min (reads CORE 990 1989-2023 from S3).
suppressMessages({library(arrow); library(dplyr)})
options(arrow.unsafe_metadata = TRUE)
ROOT <- "/root/NCCS/nccs-data-requests/requests/2026-06-milwaukee-msa"
OUT  <- file.path(ROOT, "data")
PINS <- file.path(ROOT, "_pins.csv")
num <- function(x) suppressWarnings(as.numeric(x))
w <- function(df,f){ write.csv(df, file.path(OUT,f), row.names=FALSE); cat("\n== ",f," ==\n"); print(utils::head(as.data.frame(df),12)) }
# append a provenance row to _pins.csv (same schema as the header)
pin <- function(dataset, vintage, source, n_rows, note=""){
  cat(sprintf('"%s","%s","%s","%s",%d,"%s"\n',
      format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"), dataset, vintage, source, as.integer(n_rows), note),
      file=PINS, append=TRUE)
}
exists_s3 <- function(uri){ key<-sub("^s3://","",uri); fs<-S3FileSystem$create(anonymous=TRUE)
  info<-tryCatch(fs$GetFileInfo(key),error=function(e)NULL); if(is.null(info))return(FALSE)
  if(is.list(info)) info<-info[[1]]; isTRUE(tryCatch(as.integer(info$type)==2L,error=function(e)FALSE)) }

# NTEEv2 subsector code -> full label (nccs_catalog("ntee_subsector"))
LAB <- c(ART="Arts, Culture, and Humanities", EDU="Education", ENV="Environment and Animals",
  HEL="Health", HMS="Human Services", IFA="International, Foreign Affairs",
  PSB="Public, Societal Benefit", REL="Religion Related", MMB="Mutual/Membership Benefit",
  UNU="Unknown, Unclassified", UNI="Universities", HOS="Hospitals")
lab <- function(code) ifelse(code %in% names(LAB), LAB[code], "Unknown, Unclassified")

# ---- master -> MSA universe (focus = nteev2_subsector, spelled out) ----
# org_name_display is pulled for the named-filer roster (#2).
master <- "s3://nccsdata/geocoding/bmf-master/merged/bmf_master_geocoded.parquet"
wi <- open_dataset(master) %>% filter(org_addr_state=="WI") %>%
  select(ein, org_name_display, geo_state_abbr, geo_county, nteev2_subsector,
         first_year_in_bmf, last_year_in_bmf) %>% collect()
pin("bmf-master-geocoded", "rolling@2026-06-23",
    "s3://nccsdata/geocoding/bmf-master/merged/bmf_master_geocoded.parquet", nrow(wi),
    "WI universe re-read (adds org_name_display for roster)")
cdir <- "/root/NCCS/nccs-data-bmf/data/crosswalks"
cf  <- read_parquet(file.path(cdir,"county_fips_crosswalk.parquet"))
cbsa<- read_parquet(file.path(cdir,"cbsa_crosswalk.parquet"))
msa <- wi %>% left_join(cf,by=c("geo_state_abbr","geo_county"="geo_county_raw")) %>%
              left_join(cbsa,by=c("geo_county_fips"="county_fips")) %>%
              filter(cbsa_code=="33340") %>%
              mutate(focus_area = lab(ifelse(is.na(nteev2_subsector)|nteev2_subsector=="","UNU",nteev2_subsector)))
active <- function(df,y) filter(df, first_year_in_bmf<=y, last_year_in_bmf>=y)

# ---- geography grain: stack MSA (4-county) + Milwaukee County via a `geography` column ----
GEOS <- c("Milwaukee MSA (4-county)", "Milwaukee County")
geo_filter <- function(d, g) if (g=="Milwaukee County") filter(d, geo_county_canonical=="Milwaukee County") else d
stack_geo <- function(df, fn) bind_rows(lapply(GEOS, function(g){
  out <- fn(geo_filter(df, g)); out$geography <- g; dplyr::relocate(out, geography)
}))

# per-EIN lookup carrying county + focus, for joining onto CORE reads
eins_geo <- distinct(msa, ein, focus_area, geo_county_canonical)
eins <- unique(msa$ein)

# Q1 counts by year (MSA + Milwaukee County)
w(stack_geo(msa, function(d) bind_rows(lapply(1989:2026,\(y) active(d,y) %>% summarise(year=y, n_nonprofits=n())))),
  "nonprofits_by_year_1989-2026.csv")
# current (2026) by county — inherently county-level, left as-is
w(active(msa,2026) %>% count(county=geo_county_canonical, name="n_nonprofits", sort=TRUE),
  "nonprofits_by_county_2026.csv")
# Q2 by focus area (MSA + Milwaukee County)
w(stack_geo(msa, function(d) active(d,2026) %>% count(focus_area, name="n_nonprofits", sort=TRUE)),
  "nonprofits_by_focus_area_2026.csv")
# Data-coverage diagnostic: share of then-active *Wisconsin* orgs with a resolvable
# county. Denominator is statewide BY DESIGN (it explains the early-year undercount),
# so this file is intentionally NOT split by metro/county.
w(bind_rows(lapply(1989:2026,\(y){a<-active(wi,y)
   data.frame(year=y, active_wi=nrow(a), pct_geocoded=round(100*mean(!is.na(a$geo_county)&a$geo_county!=""),1))})),
  "data_coverage_by_year.csv")

# ---- CPI-U annual avg (1982-84=100); real base = 2024 ----
cpi <- c("1989"=124.0,"1990"=130.7,"1991"=136.2,"1992"=140.3,"1993"=144.5,"1994"=148.2,
  "1995"=152.4,"1996"=156.9,"1997"=160.5,"1998"=163.0,"1999"=166.6,"2000"=172.2,"2001"=177.1,
  "2002"=179.9,"2003"=184.0,"2004"=188.9,"2005"=195.3,"2006"=201.6,"2007"=207.342,"2008"=215.303,
  "2009"=214.537,"2010"=218.056,"2011"=224.939,"2012"=229.594,"2013"=232.957,"2014"=236.736,
  "2015"=237.017,"2016"=240.007,"2017"=245.120,"2018"=251.107,"2019"=255.657,"2020"=258.811,
  "2021"=270.970,"2022"=292.655,"2023"=304.702,"2024"=313.689)
base <- cpi["2024"]; yrs <- 1989:2023

read_core <- function(form, cols){
  bind_rows(lapply(yrs, function(y){
    uri <- sprintf("s3://nccsdata/processed_merged/core/%d/%s/core_%d_%s.parquet",y,form,y,form)
    if(!exists_s3(uri)) return(NULL)
    ds <- tryCatch(open_dataset(uri), error=function(e) NULL); if(is.null(ds)) return(NULL)
    if(!"ein" %in% ds$schema$names) return(NULL)
    have <- intersect(cols, ds$schema$names)
    out <- tryCatch(ds %>% select(all_of(c("ein",have))) %>% filter(ein %in% eins) %>% collect(),
                    error=function(e) NULL)
    if(is.null(out) || nrow(out)==0) return(NULL)
    out <- out %>% mutate(across(any_of(cols), num))
    for(cc in setdiff(cols,have)) out[[cc]] <- NA_real_
    out$tax_year <- y
    out %>% select(ein, tax_year, all_of(cols))
  }))
}

# ---- Form 990 + 990-EZ (public charities) ----
pccols <- c("total_revenue","total_contributions","program_service_revenue",
            "net_income_fundraising_events","investment_income","other_revenue_total_11e","total_expenses")
pc <- read_core("990combined", pccols) %>% left_join(eins_geo,by="ein")
pin("core-990combined", "merged@1989-2023", "s3://nccsdata/processed_merged/core/{year}/990combined/", nrow(pc),
    "Public-charity 990/990-EZ filings, MSA EINs, 1989-2023")

w(stack_geo(pc, function(d) d %>% group_by(year=tax_year) %>% summarise(n_filers=n(),
    revenue_nominal_usd_millions=round(sum(total_revenue,na.rm=TRUE)/1e6),
    revenue_real2024_usd_millions=round(sum(total_revenue,na.rm=TRUE)*base/cpi[as.character(first(tax_year))]/1e6),
    .groups="drop")),
  "total_revenue_public_charities_by_year_1989-2023.csv")
w(stack_geo(pc, function(d) d %>% group_by(year=tax_year) %>% summarise(
    contributions=round(sum(total_contributions,na.rm=TRUE)/1e6),
    program=round(sum(program_service_revenue,na.rm=TRUE)/1e6),
    events_net=round(sum(net_income_fundraising_events,na.rm=TRUE)/1e6),
    investment=round(sum(investment_income,na.rm=TRUE)/1e6),
    other=round(sum(other_revenue_total_11e,na.rm=TRUE)/1e6),
    total=round(sum(total_revenue,na.rm=TRUE)/1e6), .groups="drop")),
  "revenue_by_source_by_year_1989-2023.csv")
w(stack_geo(pc, function(d) d %>% filter(tax_year==2023) %>% group_by(focus_area) %>%
    summarise(n_filers=n(), total_revenue_usd_millions=round(sum(total_revenue,na.rm=TRUE)/1e6),
              .groups="drop") %>% arrange(desc(total_revenue_usd_millions))),
  "revenue_by_focus_area_2023.csv")
w(stack_geo(pc, function(d) d %>% filter(tax_year==2023) %>% group_by(focus_area) %>% summarise(n_filers=n(),
    contributions=round(sum(total_contributions,na.rm=TRUE)/1e6),
    program=round(sum(program_service_revenue,na.rm=TRUE)/1e6),
    events=round(sum(net_income_fundraising_events,na.rm=TRUE)/1e6),
    investment=round(sum(investment_income,na.rm=TRUE)/1e6),
    other=round(sum(other_revenue_total_11e,na.rm=TRUE)/1e6),
    total=round(sum(total_revenue,na.rm=TRUE)/1e6), .groups="drop") %>% arrange(desc(total))),
  "revenue_by_focus_and_source_2023.csv")

# ---- Form 990-PF (private foundations), separate ----
pfcols <- c("total_revenue_col_a","contributions_received","gross_investment_income_curr_yr",
            "other_income","total_expenses_col_a")
pf <- read_core("990pf", pfcols) %>% left_join(eins_geo,by="ein")
pin("core-990pf", "merged@1989-2023", "s3://nccsdata/processed_merged/core/{year}/990pf/", nrow(pf),
    "Private-foundation 990-PF filings, MSA EINs, 1989-2023 (2016-2018 sparse upstream)")
w(stack_geo(pf, function(d) d %>% group_by(year=tax_year) %>% summarise(n_filers=n(),
    revenue_nominal_usd_millions=round(sum(total_revenue_col_a,na.rm=TRUE)/1e6),
    revenue_real2024_usd_millions=round(sum(total_revenue_col_a,na.rm=TRUE)*base/cpi[as.character(first(tax_year))]/1e6),
    .groups="drop")),
  "total_revenue_private_foundations_by_year_1989-2023.csv")

# ---- #2 Named 2023 filer roster (org-level; raw dollars, NOT millions) ----
name_lk <- distinct(msa, ein, org_name=org_name_display, county=geo_county_canonical, focus_area)
roster_pc <- pc %>% filter(tax_year==2023) %>% transmute(ein, form_type="990/990-EZ",
   total_revenue, contributions=total_contributions, program_service_revenue,
   fundraising_events_net=net_income_fundraising_events, investment_income,
   other_revenue=other_revenue_total_11e, total_expenses)
roster_pf <- pf %>% filter(tax_year==2023) %>% transmute(ein, form_type="990-PF",
   total_revenue=total_revenue_col_a, contributions=contributions_received,
   program_service_revenue=NA_real_, fundraising_events_net=NA_real_,
   investment_income=gross_investment_income_curr_yr, other_revenue=other_income,
   total_expenses=total_expenses_col_a)
roster <- bind_rows(roster_pc, roster_pf) %>% left_join(name_lk, by="ein") %>%
  relocate(ein, org_name, county, focus_area, form_type) %>%
  arrange(desc(total_revenue))
w(roster, "filers_2023_named.csv")

# ---- QA: positive completeness / reconciliation checks ----
cat("\n==== QA ====\n")
c26 <- active(msa,2026)
cat(sprintf("2026 count: MSA=%d  sum-of-4-counties=%d  (must match)\n",
            nrow(c26), sum(c26$geo_county_canonical %in%
              c("Milwaukee County","Waukesha County","Ozaukee County","Washington County"))))
cat(sprintf("2026 count: Milwaukee County=%d\n", sum(c26$geo_county_canonical=="Milwaukee County")))
r23 <- pc %>% filter(tax_year==2023)
cat(sprintf("2023 PC filers: MSA=%d  MilwCounty=%d   rev $M: MSA=%d MilwCounty=%d\n",
    nrow(r23), sum(r23$geo_county_canonical=="Milwaukee County"),
    round(sum(r23$total_revenue,na.rm=TRUE)/1e6),
    round(sum(r23$total_revenue[r23$geo_county_canonical=="Milwaukee County"],na.rm=TRUE)/1e6)))
cat(sprintf("Roster: rows=%d  PC=%d (==2023 PC filers above)  PF=%d  missing-name=%d\n",
    nrow(roster), sum(roster$form_type=="990/990-EZ"), sum(roster$form_type=="990-PF"),
    sum(is.na(roster$org_name) | roster$org_name=="")))
cat("\nDONE\n")
