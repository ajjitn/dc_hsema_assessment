# Flooding GIS assignment

This repo contains the scripts and dashboards used to generate a prototype
dashbaord on Flooding Risk for a hypothetical flooding event in DC. The
dashbaord can be viewed publicly
[here](https://ajjitn.github.io/dc_hsema_assessment/dashboards/water_main_break_index.html)
and the data download/processing script can be found in
`scripts/01_download_data.R`. Most data comes directly from DC's Open Data
portal, and I also use Social Vulnerability Index data from the CDC.


## Data Cleaning Notes

- Unioned zip codes, then filled in "islands" which are likely also flooded
- This filling in process also mean a few administrative zip codes (like federal buidings, Howard Univ Hospital, etc) and one residential zipcode (20059) were included in flood zone.
- All input datasets were saved as geoparquet files for efficiency
- Manually compiled list of senior wellness centers from DC DHS website