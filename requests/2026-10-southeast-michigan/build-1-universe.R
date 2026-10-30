library(nccsdata)
library(arrow)
library(dplyr)
source(here::here("R", "request_read.R"))

# This request's folder (used to write _pins.csv).
req <- here::here("requests", "2026-10-southeast-michigan")
out_dir <- file.path(req, "data", "output")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

#### Read the BMF master for Michigan ####
bmf <- read_bmf_master(
  req, state = "MI",
  columns = c("ein", "org_name_display","org_addr_state","geo_state_abbr", 
              "geo_county","subsection_code",
              "ntee_code_clean", "nteev2_subsector",
              "foundation_code", "ruling_date",
              "last_vintage_ym", "last_year_in_bmf"))

message("BMF rows: ", nrow(bmf))

latest_month <- max(bmf$last_vintage_ym)

message("Latest vintage month:", latest_month)

bmf_latest <- bmf |> 
  dplyr::filter(last_vintage_ym == latest_month)

message("Rows dropped (not in latest vintage):", nrow(bmf) - nrow(bmf_latest))
message("Rows kept(latest vintage):", nrow(bmf_latest))

#### Join the county crosswalk and keep the seven counties ####
xwalk_county <- read_crosswalk(req, "county-fips")
xwalk_cbsa   <- read_crosswalk(req, "cbsa")

#####Join geography onto the raw labels / coordinates #####
#Join the county-fips crosswalk; 
#keep Livingston, Macomb, Monroe, Oakland, St. Clair, Washtenaw, and Wayne; 
#print and drop Michigan rows whose county does not resolve.

#Define the michigan counties
counties <- c("Livingston County",
              "Macomb County","Monroe County", 
              "Oakland County", 
              "St. Clair County", "Washtenaw County",
              "Wayne County")

xwalk_mi <- bmf_latest |>
  dplyr::left_join(xwalk_county, by = c("geo_state_abbr", "geo_county" = "geo_county_raw")) |>
  dplyr::left_join(xwalk_cbsa,   by = c("geo_county_fips" = "county_fips"))

unresolved_mi <- xwalk_mi |>
  dplyr::filter(is.na(county_name))
message("Michigan rows whose county did not resolve (dropped): ", nrow(unresolved_mi))

merged_mi <- xwalk_mi |>
  dplyr::filter(county_name %in% counties)

message("Rows in other Michigan counties (dropped): ", nrow(xwalk_mi) - nrow(unresolved_mi) - nrow(merged_mi))
message("Rows kept in the seven counties: ", nrow(merged_mi))

#apply public charity rule  subsection code 3 and foundation code not in 2, 3, 4, 
#compared as integers; print what each condition removes per county. 
#We first create the rule
bmf_mi_pc <- merged_mi |>
  dplyr::mutate(subsection_rule = as.integer(subsection_code) %in% 3L) |>
  dplyr::mutate(foundation_rule = !as.integer(foundation_code) %in% c(2L,3L,4L))

#Then we count what's removed per county by the rule 
bmf_mi_subsection <- bmf_mi_pc |>
  dplyr::filter(!subsection_rule) |>
  dplyr::count(county_name) 

message("Rows removed by the subsection rule, per county:")
print(bmf_mi_subsection)


bmf_mi_foundation <- bmf_mi_pc |>
  dplyr::filter(!foundation_rule) |>
  dplyr::count(county_name) 


message("Rows removed by Foundation Rule (Per County):", (bmf_mi_foundation))

bmf_mi_rule <- bmf_mi_pc |>
  dplyr::filter(foundation_rule & subsection_rule) 
  
  #####Map the NTEE v2 subsector to the template's ten groups####
bmf_mi_ntee <- bmf_mi_rule |>
  dplyr::mutate(
    subsector =
      dplyr::recode_values(nteev2_subsector,
        "ART" ~ "Arts, Culture & Humanities",
        "EDU" ~ "Education", "UNI" ~ "Education",
        "ENV" ~ "Environment and Animals",
        "HEL" ~ "Health", "HOS" ~ "Health",
        "HMS" ~ "Human Services",
        "IFA" ~ "International Foreign Affairs",
        "PSB" ~ "Public, Societal Benefit",
        "REL" ~ "Religion Related", "MMB" ~ "Mutual/Membership Benefit",
        "UNU" ~ "Unknown",
        default = nteev2_subsector
      )
  )

#### Flag ruling dates stored as 1900-01-01 as missing#####
bmf_cfsem_universe <- bmf_mi_ntee |>
  dplyr::mutate(ruling_date = na_if(ruling_date, as.Date("1900-01-01")))

universe_count <- bmf_cfsem_universe|>
  dplyr::count(county_name)

message("Rows Per County):", (universe_count))

#county_name           n
#<chr>             <int>
#1 Livingston County   642
#2 Macomb County      2160
#3 Monroe County       505
#4 Oakland County     5840
#5 St. Clair County    566
#6 Washtenaw County   2098
#7 Wayne County       8066

#Write output/universe.csv and print the count per county
write.csv(bmf_cfsem_universe, file.path(out_dir,"universe.csv"), row.names = FALSE)
