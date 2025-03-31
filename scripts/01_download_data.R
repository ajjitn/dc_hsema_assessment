library(tidyverse)
library(sf)
library(geoarrow)
library(arrow)
library(mapview)
library(nngeo)
library(tidygeocoder)

### ---- Download data -----

dc_boundary = st_read("https://maps2.dcgis.dc.gov/dcgis/rest/services/DCGIS_DATA/Administrative_Other_Boundaries_WebMercator/MapServer/10/query?outFields=CITY_NAME&where=1%3D1&f=geojson") %>% 
  mutate(name = "DC Boundary") %>% 
  select(-CITY_NAME) %>% 
  st_cast("LINESTRING")

dc_zips = st_read("https://maps2.dcgis.dc.gov/dcgis/rest/services/DCGIS_DATA/Location_WebMercator/FeatureServer/4/query?outFields=NAME,ZIPCODE&where=1%3D1&f=geojson") %>% 
  st_make_valid()

dc_metro_lines = st_read("https://maps2.dcgis.dc.gov/dcgis/rest/services/DCGIS_DATA/Transportation_Rail_Bus_WebMercator/MapServer/58/query?outFields=NAME&where=1%3D1&f=geojson")

dc_bus_lines = st_read("https://maps2.dcgis.dc.gov/dcgis/rest/services/DCGIS_DATA/Transportation_Rail_Bus_WebMercator/MapServer/59/query?outFields=ROUTE,DIRECTION,DESCRIPTION,SERVICE_TYPE,EXPRESS&where=1%3D1&f=geojson")

dc_zips = dc_zips %>% 
  mutate(area_zip = st_area(.))

affected_zips = c("20001", "20002", "20011", "20017", "20018", "20036", "20064", "20422")

affected_areas = dc_zips %>% 
  filter(ZIPCODE %in% affected_zips) %>% 
  st_union() %>% 
  st_as_sf() %>% 
  st_make_valid()

affected_areas_filled = affected_areas %>% 
  nngeo::st_remove_holes() %>% 
  st_make_valid()

dc_svi = st_read(here("data", "raw-data","dc_svi.gdb"), layer = "SVI2022_DISTRICTOFCOLUMBIA_tract")
  

dc_svi_filtered = dc_svi %>% 
  select(LOCATION, E_TOTPOP, starts_with("RPL")) %>%
  select(census_tract = LOCATION,
         E_TOTPOP, socioeconomic_status_rank = RPL_THEME1,
         household_chrtrstcs_rank = RPL_THEME2,
         racial_ethnic_minority_rank = RPL_THEME3,
         housing_transpo_rank = RPL_THEME4,
         overall_rank = RPL_THEMES) %>% 
  st_transform("EPSG:4326")

# The four theme ranking variables, detailed in the Data Dictionary below, are:
#   • Socioeconomic Status - RPL_THEME1
# • Household Characteristics - RPL_THEME2
# • Racial & Ethnic Minority Status - RPL_THEME3
# • Housing Type & Transportation - RPL_THEME4

# ints_areas = dc_zips %>% 
#   st_intersection(affected_areas_filled) %>% 
#   mutate(int_area = st_area(.)) %>% 
#   left_join(dc_zips %>% 
#               select(ZIPCODE, area_zip) %>% 
#               st_drop_geometry()) %>% 
#   mutate(pct_zip_intersecting = as.numeric(units::set_units(int_area / area_zip, 1))) %>% 
#   arrange(desc(pct_zip_intersecting))

# Manually saw that these residential zipcodes were in "holes" filled by floodplain area
# 20059, 20060

## School data

# charter schools
charter_schools = st_read("https://maps2.dcgis.dc.gov/dcgis/rest/services/DCGIS_DATA/Education_WebMercator/MapServer/1/query?&where=1%3D1&outFields=NAME,ADDRESS,GRADES,WEB_URL,PHONE&outSR=4326&f=geojson&f=geojson") %>% 
  mutate(subtype = "Charter Schools",
         type = "Education")

public_schools = st_read("https://maps2.dcgis.dc.gov/dcgis/rest/services/DCGIS_DATA/Education_WebMercator/MapServer/5/query?&where=1%3D1&outFields=NAME,ADDRESS,GRADES,WEB_URL,PHONE&outSR=4326&f=geojson") %>% 
  mutate(subtype = "Public Schools",
         type = "Education") 

independent_schools = st_read("https://maps2.dcgis.dc.gov/dcgis/rest/services/DCGIS_DATA/Education_WebMercator/MapServer/3/query?&where=1%3D1&outFields=ADDRESS,NAME,WEB_URL,TELEPHONE&outSR=4326&f=geojson") %>% 
  mutate(subtype = "Independent Schools",
         type = "Education") %>% 
  rename(PHONE = TELEPHONE)

# school_data = bind_rows(charter_schools, public_schools, independent_schools)

## Transportation data

metro_stations = st_read("https://maps2.dcgis.dc.gov/dcgis/rest/services/DCGIS_DATA/Transportation_Rail_Bus_WebMercator/MapServer/52/query?outFields=NAME,LINE,ADDRESS&where=1%3D1&f=geojson") %>% 
  mutate(subtype = "Metro Stations",
         type = "Transportation")

# This is big, has 10k records
bus_stations = st_read("https://maps2.dcgis.dc.gov/dcgis/rest/services/DCGIS_DATA/Transportation_Rail_Bus_WebMercator/MapServer/53/query?outFields=AT_STR,ON_STR,BSTP_MSG_TEXT&where=1%3D1&f=geojson") %>% 
  mutate(subtype = "Bus Stations",
         type = "Transportation")

## Gov facilities
fire_stations = st_read("https://maps2.dcgis.dc.gov/dcgis/rest/services/DCGIS_DATA/Public_Safety_WebMercator/MapServer/6/query?outFields=NAME,ADDRESS,ZIP,PHONE,TYPE,NEAREST_METRO&where=1%3D1&f=geojson")  %>% 
  mutate(subtype = "Fire Stations",
         type = "Gov. Facilities")
  
police_stations = st_read("https://maps2.dcgis.dc.gov/dcgis/rest/services/DCGIS_DATA/Public_Safety_WebMercator/MapServer/11/query?outFields=NAME,ADDRESS,ZIPCODE,PHONE,TYPE&where=1%3D1&f=geojson") %>% 
  mutate(subtype = "Police Stations",
         type = "Gov. Facilities")

fed_buildings = st_read("https://maps2.dcgis.dc.gov/dcgis/rest/services/DCGIS_DATA/Facility_and_Structure/MapServer/12/query?outFields=REAL_PROPERTY_ASSET_NAME,STREET_ADDRESS,ZIP_CODE,REAL_PROPERTY_ASSET_TYPE,BUILDING_STATUS&where=1%3D1&f=geojson") %>% 
  filter(BUILDING_STATUS == "Active", REAL_PROPERTY_ASSET_TYPE == "BUILDING") %>% 
  mutate(subtype = "Federal Buildings",
         type = "Gov. Facilities")

## Healthcare
primary_care_centers = st_read("https://maps2.dcgis.dc.gov/dcgis/rest/services/DCGIS_DATA/Health_WebMercator/MapServer/7/query?outFields=DCGIS.PrimaryCarePt.NAME,DCGIS.PrimaryCarePt.ADDRESS,DCGIS.PrimaryCarePt.PHONE,DCGIS.PrimaryCarePt.MEDICAID,DCGIS.PrimaryCarePt.MEDICARE,DCGIS.PrimaryCarePt.FACILITY_TYPE,DCGIS.PrimaryCarePt.FACILITY_SETTING&where=1%3D1&f=geojson") %>% 
  rename(
    NAME = DCGIS.PrimaryCarePt.NAME,
         ADDRESS = DCGIS.PrimaryCarePt.ADDRESS,
         PHONE = DCGIS.PrimaryCarePt.PHONE,
         MEDICAID_ACCEPTED = DCGIS.PrimaryCarePt.MEDICAID,
         MEDICARE_ACCEPTED = DCGIS.PrimaryCarePt.MEDICARE,
         FACILILITY_TYPE = DCGIS.PrimaryCarePt.FACILITY_TYPE,
         FACILITY_SETTING = DCGIS.PrimaryCarePt.FACILITY_SETTING
  ) %>% 
  mutate(subtype = "Primary Care Centers",
         type = "Healthcare Facilities")

hospitals = st_read("https://maps2.dcgis.dc.gov/dcgis/rest/services/DCGIS_DATA/Health_WebMercator/MapServer/4/query?outFields=NAME,ADDRESS,TYPE,WEB_URL,ADULT_MAJOR_TRAUMA,ADULT_MINOR_TRAUMA&where=1%3D1&f=geojson")  %>% 
  mutate(subtype = "Hospitals",
         type = "Healthcare Facilities")

nursing_homes = st_read("https://maps2.dcgis.dc.gov/dcgis/rest/services/DCGIS_DATA/Health_WebMercator/MapServer/6/query?outFields=NAME,ADDRESS,BEDS,CONTACTNUMBER&where=1%3D1&f=geojson") %>% 
  rename(PHONE=CONTACTNUMBER) %>% 
  mutate(BEDS = as.double(BEDS)) %>% 
  mutate(subtype = "Nursing Homes",
         type = "Healthcare Facilities")

intermediate_care_centers = st_read("https://maps2.dcgis.dc.gov/dcgis/rest/services/DCGIS_DATA/Health_WebMercator/MapServer/5/query?outFields=NAME,ADDRESS,PHONE,BEDS&where=1%3D1&f=geojson")  %>% 
  mutate(subtype = "Intermediate Care",
         type = "Healthcare Facilities")

dialysis_clinics = st_read("https://maps2.dcgis.dc.gov/dcgis/rest/services/DCGIS_DATA/Health_WebMercator/MapServer/2/query?outFields=NAME,ADDRESS,PHONE,WEB_URL&where=1%3D1&f=geojson")  %>% 
  mutate(subtype = "Dialysis Clinics",
         type = "Healthcare Facilities")

## Recreation Centers

# community centers, senior wellness centers, fitness centers, pools, splash pools
rec_facilities = st_read("https://maps2.dcgis.dc.gov/dcgis/rest/services/DCGIS_DATA/Recreation_WebMercator/MapServer/3/query?outFields=NAME,ADDRESS,USE_TYPE,POOL,SCHOOL_SITE,POOL_NAME,WEB_URL,PHONE,STATUS,FITNESS_CENTER,&where=1%3D1&f=geojson")

# Manually scraped from https://dhs.dc.gov/service/senior-wellness-centers
senior_centers = tribble(~NAME, ~ADDRESS, ~PHONE,
                         "Bernice Fonteneau Senior Wellness Center", "3531 Georgia Avenue NW, Washington, DC 20011", "(202) 727-0338",
                         "Hattie Holmes Senior Wellness Center", "324 Kennedy Street NW,Washington, DC 20011", "(202) 291-6170",
                         "Model Cities Senior Wellness Center", "1901 Evarts Street NE, Washington, DC 20018", "(202) 635-1900",
                         "Hayes Senior Wellness Center", "500 K Street NE, Washington, DC 20002", "(202) 727-0357",
                         "Washington Seniors Wellness Center", "3001 Alabama Avenue SE, Washington, DC 200020", "(202) 581-9355",
                         "Congress Heights Senior Wellness Center", "3500 Martin Luther King Jr Ave SE, Washington DC, 20032", "(202) 563-7225") %>% 
  tidygeocoder::geocode(address = ADDRESS, method = "census") %>% 
  st_as_sf(coords = c("long", "lat"), crs = "EPSG:4326") %>% 
  mutate(type = "Recreation Facilities",
         subtype = "Senior Center")
  

spray_parks = rec_facilities %>% 
  filter(USE_TYPE == "SPRAY PARK") %>% 
  mutate(type = "Recreation Facilities",
         subtype = "Spray Park")

pools = rec_facilities %>% 
  filter(USE_TYPE == "POOL") %>% 
  mutate(type = "Recreation Facilities",
         subtype = "Pool")

rec_centers = rec_facilities %>% 
  filter(USE_TYPE == "RECREATION CENTER") %>% 
  mutate(type = "Recreation Facilities",
         subtype = "Rec. Center")

aquatic_centers = rec_facilities %>% 
  filter(USE_TYPE == "AQUATIC CENTER") %>% 
  mutate(type = "Recreation Facilities",
         subtype = "Aquatic Center")


### --- Combine point data ----

all_point_data = bind_rows(
  charter_schools, public_schools, independent_schools,
  metro_stations, bus_stations,
  fire_stations, police_stations,
  primary_care_centers, dialysis_clinics, intermediate_care_centers, nursing_homes, hospitals,
  senior_centers, rec_centers, aquatic_centers, pools, spray_parks
) %>% 
  # Only present in fire_stations data and not useful
  select(-TYPE)

all_point_data %>% 
  count(type, subtype) %>% 
  st_drop_geometry() %>% 
  head(18)

### ---- Write out ----
dir.create("data/raw-data/", showWarnings = FALSE, recursive = TRUE)

dc_boundary %>% 
  arrow::write_parquet("data/raw-data/dc_boundary.parquet")

dc_zips %>% 
  arrow::write_parquet("data/raw-data/dc_zips.parquet")

dc_svi_filtered %>% 
  arrow::write_parquet("data/raw-data/dc_svi.parquet")

dc_metro_lines %>% 
  arrow::write_parquet("data/raw-data/dc_metro_lines.parquet")

dc_bus_lines %>% 
  arrow::write_parquet("data/raw-data/dc_bus_lines.parquet")

affected_areas %>% 
  arrow::write_parquet("data/raw-data/affected_zips.parquet")

affected_areas_filled %>% 
  arrow::write_parquet("data/raw-data/affected_zips_filled.parquet")

all_point_data %>% 
  arrow::write_parquet("data/raw-data/all_point_data.parquet")

