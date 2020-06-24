# TODO: Move all temporary process files to /tmp/ folder 
# TODO: Fix cleanup to focus on /tmp/ folder

# This Makefile does a few things:
# 1. Gets county shapefiles from tiger
# 2. Gets EAVS data from the Election Assistance Commission
# 3. Gets election data from MIT 
# 4. Binds them all together 
# 5. TODO: Push them to mapbox as layers using mapbox CLI 

# This Makefile assumes that csvkit is installed
# https://csvkit.readthedocs.io/en/0.9.1/install.html

MAPBOX_TARGET_TILESET_ID=eavs-data
MAPBOX_USER=

## Get the county level shapefiles for mapping purposes
counties.zip:
	#curl -o counties.zip 'https://www2.census.gov/geo/tiger/GENZ2018/shp/cb_2018_us_county_500k.zip'
	curl -o $@ 'https://www2.census.gov/geo/tiger/GENZ2018/shp/cb_2018_us_county_20m.zip'

# Unzip them
cb_2018_us_county_20m.shp: counties.zip
	unzip $<

# Convert them from shapefiles into geojson using mapshaper
counties.geojson:	cb_2018_us_county_20m.shp
	node_modules/mapshaper/bin/mapshaper $< -o $@ format=geojson precision=0.001 -simplify 20%

# Convert the geojson to newline delimited json
counties.ndjson: counties.geojson
	cat $< | jq -c ".features[]" > $@

# Rename the FIPS code to our shared fips ID 
counties-id.ndjson: counties.ndjson
	ndjson-map 'd.FIPS = d.properties.GEOID, d' < $< > $@

# Filter out any counties that have a FIPS of "00000"
# TODO: Should also filter out any that aren't 5 chars in length
counties-id-trimmed.ndjson: counties-id.ndjson
	cat $< | ndjson-filter 'd.FIPS !== "00000" && d.FIPS.length === 5' > $@ 

## Now all of our county shapefiles are cleaned up, simplified, and ready to be bound to the EAVS data with our new shared ID

# Time to process the EAVS data

# All available EAVS metric IDs and labels

# > csvcut -c 1,3 eavs_codebook.csv
# VariableName,Label
# FIPSCode,FIPS        
# Jurisdiction_Name,Jurisdiction Name       
# State_Full,State Name (full)
# State_Abbr,State Name (abbreviation)
# A1a,Total Registered Voters     
# A1b,Total Active Voters     
# A1c,Total Inactive Voters     
# A1Comments,A1 Comments       
# A2a,Total New Same Day Registrations   
# A2Comments,A2 Comments       
# A3a,Registration Forms: Total     
# A3b,Registration Forms: New Valid    
# A3c,Registration Forms: New Pre Registrations   
# A3d,Registration Forms: Duplicates     
# A3e,Registration Forms: Invalid or Rejected   
# A3f,"Registration Forms: Change to name, party or within-jurisdiction address"
# A3g,Registration Forms: Change Address cross jurisdiction  
# A3h_Other,Other Text 1     
# A3h,Other 1      
# A3i_Other,Other Text 2
# A3i,Other 2      
# A3j_Other,Other Text 3     
# A3j,Other 3      
# A3Comments,A3 Comments       
# A4a,Total forms: Mail     
# A4b,Total forms: In-person     
# A4c,Total forms: Online     
# A4d,Total forms: DMV     
# A4e,Total forms: NVRA Mandated    
# A4f,Total forms: Agencies Serving Persons with Disabilities 
# A4g,Total forms: Armed Forces Offices   
# A4h,Total forms: Non-NVRA Mandated    
# A4i,Total forms: Registration Drives    
# A4j_Other,Total forms: Other Text 1   
# A4j,Total forms: Other 1    
# A4k_Other,Other Text 2     
# A4k,Total forms: Other 2    
# A4l_Other,Other Text 3     
# A4l,Total forms: Other 3    
# A5a,New Registrations: Mail     
# A5b,New Registrations: In-person     
# A5c,New Registrations: Online     
# A5d,New Registrations: DMV     
# A5e,New Registrations: NVRA Mandated    
# A5f,New Registrations: Agencies Serving Persons with Disabilities 
# A5g,New Registrations: Armed Forces Offices   
# A5h,New Registrations: Non-NVRA Mandated    
# A5i,New Registrations: Registration Drives    
# A5j_Other,Total forms: Other Text 1   
# A5j,New Registrations: Other 1    
# A5k_Other,Other Text 2     
# A5k,New Registrations: Other 2    
# A5l_Other,Other Text 3     
# A5l,New Registrations: Other 3    
# A6a,Duplicate Registrations: Mail     
# A6b,Duplicate Registrations: In-person     
# A6c,Duplicate Registrations: Online     
# A6d,Duplicate Registrations: DMV     
# A6e,Duplicate Registrations: NVRA Mandated    
# A6f,Duplicate Registrations: Agencies Serving Persons with Disabilities 
# A6g,Duplicate Registrations: Armed Forces Offices   
# A6h,Duplicate Registrations: Non-NVRA Mandated    
# A6i,Duplicate Registrations: Registration Drives    
# A6j_Other,Total forms: Other Text 1   
# A6j,Duplicate Registrations: Other 1    
# A6k_Other,Other Text 2     
# A6k,Duplicate Registrations: Other 2    
# A6l_Other,Other Text 3     
# A6l,Duplicate Registrations: Other 3    
# A7a,Invalid Registrations: Mail     
# A7b,Invalid Registrations: In-person     
# A7c,Invalid Registrations: Online     
# A7d,Invalid Registrations: DMV     
# A7e,Invalid Registrations: NVRA Mandated    
# A7f,Invalid Registrations: Agencies Serving Persons with Disabilities 
# A7g,Invalid Registrations: Armed Forces Offices   
# A7h,Invalid Registrations: Non-NVRA Mandated    
# A7i,Invalid Registrations: Registration Drives    
# A7j_Other,Total forms: Other Text 1   
# A7j,Invalid Registrations: Other 1    
# A7k_Other,Other Text 2     
# A7k,Invalid Registrations: Other 2    
# A7l_Other,Other Text 3     
# A7l,Invalid Registrations: Other 3    
# A4_A7Comments,A4-A7 Comments       
# A8a,Notifications: Total      
# A8b,Notifications: Received Confirming     
# A8c,Notifications: Received Invalidating     
# A8d,Notifications: Returned Undeliverable     
# A8e,Notifications: Status Unknown     
# A8f_Other,Notifications: Other Text 1    
# A8f,Notifications: Other 1     
# A8g_Other,Notifications: Other Text 2    
# A8g,Notifications: Other 2     
# A8h_Other,Notifications: Other Text 3    
# A8h,Notifications: Other 3     
# A8Comments,A8 Comments       
# A9a,Voters Removed: Total     
# A9b,Voters Removed: Moved     
# A9c,Voters Removed: Death     
# A9d,Voters Removed: Felony     
# A9e,Voters Removed: Fail to Respond   
# A9f,Voters Removed: Declared Mentally Incompetent   
# A9g,Voters Removed: Voter Request    
# A9h_Other,Voters Removed: Other Text 1   
# A9h,Voters Removed: Other 1    
# A9i_Other,Voters Removed: Other Text 2   
# A9i,Voters Removed: Other 2    
# A9j_Other,Voters Removed: Other Text 3   
# A9j,Voters Removed: Other 3    
# A9Comments,A9 Comments       
# B1a,UOCAVA Registered: Total     
# B1b,Uniformed Service Registered: Total    
# B1c,Non-military Registered: Total     
# B1Comments,B1 Comments       
# B2a,UOCAVA FPCAs: Total     
# B2b,Uniformed Service FPCAs: Total    
# B2c,Non-military FPCAs: Total     
# B2Comments,B2 Comments       
# B3a,UOCAVA FPCAs Rejected: Total    
# B3b,Uniformed Service FPCAs Rejected: Total   
# B3c,Non-military FPCAs Rejected: Total    
# B3Comments,B3 Comments       
# B4a,UOCAVA FPCAs Rejected: Total Late   
# B4Comments,B4 Comments       
# B5a,UOCAVA Transmitted Ballots: Total    
# B5b,Uniformed Service Transmitted Ballots: Total   
# B5c,Non-Military Transmitted Ballots: Total    
# B6a,UOCAVA Transmitted Ballots: Mail    
# B6b,Uniformed Service Transmitted Ballots: Mail   
# B6c,Non-military Transmitted Ballots: Mail    
# B7a,UOCAVA Transmitted Ballots: Email    
# B7b,Uniformed Service Transmitted Ballots: Email   
# B7c,Uniformed Service Transmitted Ballots: Email   
# B8a,UOCAVA Transmitted Ballots: Other    
# B8b,Uniformed Service Transmitted: Other    
# B8c,Non-military Transmitted: Other     
# B5_B8Comments,B5-B8 Comments       
# B9a,UOCAVA Ballots Returned: Total    
# B9b,Uniformed Service Ballots Returned: Total   
# B9c,Non-military Ballots Returned: Total    
# B10a,UOCAVA Ballots Returned: Mail    
# B10b,Uniformed Service Ballots Returned: Mail   
# B10c,Non-military Ballots Returned: Mail    
# B11a,UOCAVA Ballots Returned: Email    
# B11b,Uniformed Service Ballots Returned: Email   
# B11c,Non-military Ballots Returned: Email    
# B12a,UOCAVA Ballots Returned: Other    
# B12b,Uniformed Service Ballots Returned: Other   
# B12c,Non-military Ballots Returned: Other    
# B9_B12Comments,B9-B12 Comments       
# B13a,UOCAVA Returned Undeliverable: Total    
# B13b,UOCAVA Returned Undeliverable: Mail    
# B13c,UOCAVA Returned Undeliverable: Email    
# B13d,UOCAVA Returned Undeliverable: Other    
# B13Comments,B13 Comments       
# B14a,UOCAVA Ballots Counted: Total    
# B14b,Uniformed Service Ballots Counted: Total   
# B14c,Non-military Ballots Counted: Total    
# B15a,UOCAVA Ballots Counted: Mail    
# B15b,Uniformed Service Ballots Counted: Mail   
# B15c,Non-military Ballots Counted: Mail    
# B16a,UOCAVA Ballots Counted: Email    
# B16b,Uniformed Service Ballots Counted: Email   
# B16c,Non-military Ballots Counted: Email    
# B17a,UOCAVA Ballots Counted: Other    
# B17b,Uniformed Service Ballots Counted: Other   
# B17c,Non-military Ballots Counted: Other    
# B14_B17Comments,B14-B17 Comments       
# B18a,UOCAVA Ballots Rejected: Total    
# B18b,Uniformed Service Ballots Rejected: Total   
# B18c,Non-military Ballots Rejected: Total    
# B19a,UOCAVA Ballots Rejected: Deadline    
# B19b,Uniformed Service Ballots Rejected: Deadline   
# B19c,Non-military Ballots Rejected: Deadline    
# B20a,UOCAVA Ballots Rejected: Signature    
# B20b,Uniformed Service Ballots Rejected: Signature   
# B20c,Non-military Ballots Rejected: Signature    
# B21a,UOCAVA Ballots Rejected: Postmark    
# B21b,Uniformed Service Ballots Rejected: Postmark   
# B21c,Non-military Ballots Rejected: Postmark    
# B22a,UOCAVA Ballots Rejected: Other Text   
# B22b,Uniformed Service Ballots Rejected: Other   
# B22c,Non-military Ballots Rejected: Other    
# B22_Other,Other
# B18_B22Comments,B18-B22 Comments       
# B23a,UOCAVA FWABs Returned: Total    
# B23b,Uniformed Service FWABs Returned: Total   
# B23c,Non-military FWABs Returned: Total    
# B24a,UOCAVA FWABs Counted: Total    
# B24b,Uniformed Service FWABs Counted: Total   
# B24c,Non-military FWABs Counted: Total    
# B25a,UOCAVA FWABs Rejected: Deadline    
# B25b,Uniformed Service FWABs Rejected: Deadline   
# B25c,Non-military FWABs Rejected: Deadline    
# B26a,UOCAVA FWABs Rejected: Absentee    
# B26b,Uniformed Service FWABs Rejected: Absentee   
# B26c,Non-military FWABs Rejected: Absentee    
# B23_B26Comments,B23-B26 Comments       
# C1a,By-mail Transmitted: Total     
# C1b,By-mail Transmitted: Returned for Counting   
# C1c,By-mail Transmitted: Returned Undeliverable    
# C1d,By-mail Transmitted: Voided     
# C1e,By-mail Transmitted: Voted In-person Provisional   
# C1f,By-mail Transmitted: Status Unknown    
# C1g_Other,By-mail Transmitted: Other Text 1   
# C1g,By-mail Transmitted: Other 1    
# C1h_Other,By-mail Transmitted: Other Text 2   
# C1h,By-mail Transmitted: Other 2    
# C1i_Other,By-mail Transmitted: Other Text 3   
# C1i,By-mail Transmitted: Other 3    
# C1Comments,C1 Comments       
# C2a,Permanent By-mail Registrants: Total Transmitted   
# C2Comments,C2 Comments       
# C3a,By-mail Ballots Counted: Total    
# C3Comments,C3 Comments       
# C4a,By-mail Ballots Rejected: Total    
# C4b,By-mail Rejected: Deadline     
# C4c,By-mail Rejected: Voter Signature    
# C4d,By-mail Rejected: Witness Signature    
# C4e,By-mail Rejected: Non-matching Signature    
# C4f,By-mail Rejected: No EO Signature   
# C4g,By-mail Rejected: Unofficial Envelope    
# C4h,By-mail Rejected: Ballot Missing    
# C4i,By-mail Rejected: Envelope Not Sealed   
# C4j,By-mail Rejected: No Address    
# C4k,By-mail Rejected: Multiple Ballots    
# C4l,By-mail Rejected: Deceased     
# C4m,By-mail Rejected: Already Voted    
# C4n,By-mail Rejected: No Voter ID   
# C4o,By-mail Rejected: No Ballot Application   
# C4p_Other,By-mail Rejected: Other Text 1   
# C4p,By-mail Rejected: Other 1    
# C4q_Other,By-mail Rejected: Other Text 2   
# C4q,By-mail Rejected: Other 2    
# C4r_Other,By-mail Rejected: Other Text 3   
# C4r,By-mail Rejected: Other 3    
# C4Comments,C4 Comments       
# D1a,Votes Cast: Total     
# D1Comments,D1 Comments       
# D2a,Voted at Poll Place on Election Day 
# D2b,Voted at Early Vote Location   
# D2Comments,D2 Comments       
# D3a,Number of Precincts: Total    
# D3Comments,D3 Comments       
# D4a,Election Day Polling Places: Total   
# D4b,Election Day Polling Places: Physical Place Not Election Office
# D4c,Election Day Polling Places: Election Office  
# D5a,Early Voting Polling Places: Total   
# D5b,Early Voting Polling Places: Physical Place Not Election Office
# D5c,Early Voting Polling Places: Election Office  
# D4_D5Comments,D4-D5 Comments       
# D6,Poll Workers Election Day: Total   
# D7,Poll Workers Early Voting: Total   
# D6_D7Comments,D6-D7 Comments       
# D8a,Poll Workers: Total     
# D8b,Poll Workers: Under 18    
# D8c,Poll Workers: 18 to 25   
# D8d,Poll Workers: 26 to 40   
# D8e,Poll Workers: 41 to 60   
# D8f,Poll Workers: 61 to 70   
# D8g,Poll Workers: 71 And Up   
# D8Comments,D8 Comments       
# D9,Poll Workers Recruiting Difficulty    
# D9Comments,D9 Comments       
# E1a,Provisional Ballots: Total     
# E1b,Provisional Ballots: Counted Full Ballot   
# E1c,Provisional Ballots: Counted Part of Ballot  
# E1d,Provisional Ballots: Rejected Ballot    
# E1e_Other,Other Text      
# E1e,Provisional Ballots: Other     
# E1Comments,E1 Comments       
# E2a,Provisional Ballots Rejected: Total    
# E2b,Provisional Ballots Rejected: Not Registered   
# E2c,Provisional Ballots Rejected: Wrong Jurisdiction   
# E2d,Provisional Ballots Rejected: Wrong Precinct   
# E2e,Provisional Ballots Rejected: No ID   
# E2f,Provisional Ballots Rejected: Incomplete    
# E2g,Provisional Ballots Rejected: Ballot Missing   
# E2h,Provisional Ballots Rejected: No Signature   
# E2i,Provisional Ballots Rejected: Non-matching Signature   
# E2j,Provisional Ballots Rejected: Already Voted   
# E2k_Other,Provisional Ballots Rejected: Other Text 1  
# E2k,Provisional Ballots Rejected: Other 1   
# E2l_Other,Provisional Ballots Rejected: Other Text 2  
# E2l,Provisional Ballots Rejected: Other 2   
# E2m_Other,Provisional Ballots Rejected: Other Text 3  
# E2m,Provisional Ballots Rejected: Other 3   
# E2Comments,E2 Comments       
# F1a,Participation: Total      
# F1b,Participation: Physical Polling Place on Election Day 
# F1c,Participation: UOCAVA      
# F1d,Participation: By Mail     
# F1e,Participation: Provisional Ballot     
# F1f,Participation: In Person Early Voting   
# F1g,Participation: Vote By Mail Jurisdiction   
# F1h_Other,Participation: Other Text     
# F1h,Participation: Other      
# F1Comments,F1 Comments       
# F2,Data Source for Total Participation   
# F2_Other,Data Source for Total Participation: Other Text 
# F2Comments,F2 Comments       
# F3a,Electronic Poll Book use: Sign Voters In 
# F3b,Electronic Poll Book use: Update Voter History 
# F3c,Electronic Poll Book use: Look Up Polling Places
# F3d_Other,Electronic Poll Book use: Other Text  
# F3d,Electronic Poll Book use: Other   
# F4a,Paper Poll Book use: Sign Voters In 
# F4b,Paper Poll Book use: Update Voter History 
# F4c,Paper Poll Book use: Look Up Polling Places
# F4d_Other,Paper Poll Book use: Other Text  
# F4d,Paper Poll Book use: Other   
# F3_F4Comments,F3-F4 Comments       
# F5a,Voting Technology used: DRE no VVPAT  
# F5b_1,DRE no VVPAT: Make and Model 1 
# F5b_1other,DRE no VVPAT: Other Make Model 1 
# F5c_1,DRE no VVPAT: Number Deployed 1  
# F5b_2,DRE no VVPAT: Make and Model 2 
# F5b_2other,DRE no VVPAT: Other Make Model 2 
# F5c_2,DRE no VVPAT: Number Deployed 2  
# F5b_3,DRE no VVPAT: Make and Model 3 
# F5b_3other,DRE no VVPAT: Other Make Model 3 
# F5c_3,DRE no VVPAT: Number Deployed 3  
# F5d_1,DRE no VVPAT: Regular Balloting   
# F5d_2,DRE no VVPAT: Special Device   
# F5d_3,DRE no VVPAT: Provisional Ballot   
# F5d_4,DRE no VVPAT: In Person Early  
# F6a,Voting Technology used: DRE with VVPAT     
# F6b_1,DRE with VVPAT: Make and Model 1 
# F6b_1other,DRE with VVPAT: Other Make Model 1 
# F6c_1,DRE with VVPAT: Number Deployed 1  
# F6b_2,DRE with VVPAT: Make Model 2  
# F6b_2other,DRE with VVPAT: Other Make Model 2 
# F6c_2,DRE with VVPAT: Number Deployed 2  
# F6b_3,DRE with VVPAT: Make Model 3  
# F6b_3other,DRE with VVPAT: Other Make Model 3 
# F6c_3,DRE with VVPAT: Number Deployed 3  
# F6d_1,DRE with VVPAT: Regular Balloting   
# F6d_2,DRE with VVPAT: Special Device   
# F6d_3,DRE with VVPAT: Provisional Ballot   
# F6d_4,DRE with VVPAT: In Person Early  
# F7a,Voting Technology used: Ballot Marking Device
# F7b_1,Ballot Marking Device: Make and Model 1 
# F7b_1other,Ballot Marking Device: Other Make Model 1 
# F7c_1,Ballot Marking Device: Number Deployed 1  
# F7b_2,Ballot Marking Device: Make Model 2  
# F7b_2other,Ballot Marking Device: Other Make Model 2 
# F7c_2,Ballot Marking Device: Number Deployed 2  
# F7b_3,Ballot Marking Device: Make Model 3  
# F7b_3other,Ballot Marking Device: Other Make Model 3 
# F7c_3,Ballot Marking Device: Number Deployed 3  
# F7d_1,Ballot Marking Device: Regular Balloting   
# F7d_2,Ballot Marking Device: Special Device   
# F7d_3,Ballot Marking Device: Provisional Ballot   
# F7d_4,Ballot Marking Device: In Person Early  
# F7d_5,Ballot Marking Device: By Mail Ballot  
# F8a,Voting Technology used: Scanner       
# F8b_1,Scanner: Make and Model 1   
# F8b_1other,Scanner: Other Make Model 1   
# F8c_1,Scanner: Number Deployed 1    
# F8b_2,Scanner: Make Model 2    
# F8b_2other,Scanner: Other Make Model 2   
# F8c_2,Scanner: Number Deployed 2    
# F8b_3,Scanner: Make Model 3    
# F8b_3other,Scanner: Other Make Model 3   
# F8c_3,Scanner: Number Deployed 3    
# F8d_1,Scanner: Regular Balloting     
# F8d_2,Scanner: Special Device     
# F8d_3,Scanner: Provisional Ballot     
# F8d_4,Scanner: In Person Early    
# F8d_5,Scanner: By Mail Ballot    
# F9a,Voting Technology used: Punch Card
# F9b_1other,Punch Card: Make Model 1   
# F9c_1,Punch Card: Number Deployed 1   
# F9b_2other,Punch Card: Make Model 2   
# F9c_2,Punch Card: Number Deployed 2   
# F9b_3other,Punch Card: Make Model 3   
# F9c_3,Punch Card: Number Deployed 3   
# F9d_1,Punch Card: Regular Balloting    
# F9d_2,Punch Card: Special Device    
# F9d_3,Punch Card: Provisional Ballot    
# F9d_4,Punch Card: In Person Early   
# F9d_5,Punch Card: By Mail Ballot   
# F10a,Voting Technology used: Lever
# F10b_1other,Lever: Make Model 1
# F10c_1,Lever: Number Deployed 1
# F10b_2other,Lever: Make Model 2
# F10c_2,Lever: Number Deployed 2
# F10b_3other,Lever: Make Model 3
# F10c_3,Lever: Number Deployed 3
# F10d_1,Lever: Regular Balloting     
# F10d_2,Lever: Special Device     
# F10d_4,Lever: In Person Earl    
# F11a,Voting Technology used: Hand Count
# F11d_1,Hand Count: Regular Balloting    
# F11d_2,Hand Count: Special Device    
# F11d_3,Hand Count: Provisional Ballot    
# F11d_4,Hand Count: In Person Early   
# F11d_5,Hand Count: By Mail Ballot   
# F5_F11Comments,F5-F11 Comments       
# F12a,Location of Vote Tally: Election Day Regular Ballot
# F12b,Location of Vote Tally: Special Devices  
# F12c,Location of Vote Tally: Provisional Ballot Voting 
# F12d,Location of Vote Tally: In Person Early Voting
# F12e,Location of Vote Tally: By Mail Balloting 
# F12Comments,F12 Comments       
# F13,General Comments      

################################################
# Of which, we only care about a few rows
# A1a,Total Registered Voters     
# A1b,Total Active Voters    
# A9a,Voters Removed: Total     
# A9b,Voters Removed: Moved     
# A9c,Voters Removed: Death     
# A9d,Voters Removed: Felony     
# A9e,Voters Removed: Fail to Respond   
# A9f,Voters Removed: Declared Mentally Incompetent   
# A9g,Voters Removed: Voter Request    

# Maybe use later for mail-in ballot rejections 
# C4a,By-mail Ballots Rejected: Total    
# C4b,By-mail Rejected: Deadline     
# C4c,By-mail Rejected: Voter Signature    
# C4d,By-mail Rejected: Witness Signature    
# C4e,By-mail Rejected: Non-matching Signature    
# C4f,By-mail Rejected: No EO Signature   
# C4g,By-mail Rejected: Unofficial Envelope    
# C4h,By-mail Rejected: Ballot Missing    
# C4i,By-mail Rejected: Envelope Not Sealed   
# C4j,By-mail Rejected: No Address    
# C4k,By-mail Rejected: Multiple Ballots    
# C4l,By-mail Rejected: Deceased     
# C4m,By-mail Rejected: Already Voted    
# C4n,By-mail Rejected: No Voter ID   
# C4o,By-mail Rejected: No Ballot Application  


# We will use those column names later to cut out only what we want
ROWS=FIPSCode,Jurisdiction_Name,State_Abbr,A1a,A1b,A9a,A9b,A9c,A9d,A9e,A9f,A9g

# Earlier version where we had already bound the proper label names (makes big files)
# ROWS=CleanFIPS,"Total_Registered_Voters","Voters_Removed_Total","Voters_Removed_Moved","Voters_Removed_Death","Voters_Removed_Fail_to_Respond","Voters_Removed_Declared_Mentally_Incompetent"

# Download the EAVS data for 2018
eavs.csv:
	curl -o $@ 'https://www.eac.gov/sites/default/files/Research/EAVS_2018_for_Public_Release_Updates.csv'

# Download the codebook for the EAVS data
eavs_codebook.xlsx:
	curl -o $@ 'https://www.eac.gov/sites/default/files/eac_assets/1/6/2018_EAVS_Codebook.xlsx'

# Convert the codebook from excel to CSV
eavs_codebook.csv: eavs_codebook.xlsx
	in2csv $< > $@

# Trim to just the columns that we want to us
# We defined this in the ROWS variable at the top of the script 
#
# Basically running the following: 
# > csvcut -c CleanFIPS,"Total Registered Voters" eavs.csv > eavs_trimmed.csv
eavs-trimmed.csv: eavs.csv
	csvcut -c ${ROWS} $< > $@

eavs-decoded-headers.csv: eavs-trimmed.csv eavs_codebook.csv
	node -r esm CSVHeadersFromCodebook.mjs $< eavs_codebook.csv VariableName=Label > $@

# Rewrite the header 
eavs-decoded.csv: eavs-decoded-headers.csv eavs-trimmed.csv
	cat eavs-decoded-headers.csv > $@;tail -n +2 eavs-trimmed.csv >> $@

# Convert the EAVS data (trimmed just to rows we care about) from CSV to JSON
# eavs-trimmed.json: eavs-trimmed.csv
# 	node node_modules/csv2json/cli.js $< > $@
eavs-decoded.json: eavs-decoded.csv
	#node node_modules/csv2json/cli.js $< > $@
	csvjson $< > $@

# Convert from normal json to newline delimited JSON
eavs.ndjson: eavs-decoded.json
	cat $< | jq -c '.[]' | ndjson-filter 'd.fips.toString()[6] == 0 ? true : false' | ndjson-map 'd.FIPS = d.fips.toString().padStart(5,0).substring(0, 5), delete d.fips, d' > $@

eavs.json: eavs.ndjson
	node node_modules/ndjson-to-json/index.js $< > $@

eavs-new.csv: eavs.json
	./node_modules/d3-dsv/bin/json2dsv < eavs.json > eavs-new.csv

# Remove any line in the JSON where the fips code is 00000
# TODO: Make this a better `isFIPS` check
eavs_filtered.ndjson: eavs.ndjson
	cat $< | ndjson-filter 'd.FIPS !== "00000"' > $@ 

# Ok, now our eavs data is cleaned up and ready to be bound

# Time to get a-bindin'

# EAVS calls the id `FIPSCode`
# Shapefile calls the id `GEOID`
# But we've modified them both so they both call them
# `FIPS`
# which we use to bind everything together

# This is where the magic happens
# We join the two ndjson files by their shared ID
counties_eavs.ndjson: eavs_filtered.ndjson counties-id-trimmed.ndjson
#	ndjson-join 'd.CleanFIPS' $^| ndjson-map 'Object.assign(d[0], d[1])' > $@
# ndjson-join 'd.FIPS' $^| ndjson-map 'd[1].properties=d[0],d' > $@
# ndjson-join 'd.FIPS' $^| ndjson-map 'd[0].properties=d[0],d[0]' > $@
	ndjson-join 'd.FIPS' eavs_filtered.ndjson counties-id-trimmed.ndjson > $@

counties_eavs_bound.ndjson: counties_eavs.ndjson
	ndjson-map 'd[1].properties = Object.assign(d[1].properties, d[0]),d[1]' < counties_eavs.ndjson > $@

#TODO: I THINK THE MAP SHOULD BE BEFORE THE JOIN
# Basically the issue is what Bostock points out here
# > It may be hard to see in the screenshot, but each line in the resulting NDJSON stream is a two-element array.
# We don't want that, we want a single element per line, not in an array
# So we can convert things back to geoJSON

# Turn our bound ndjson back into plain old geojson, if we want
counties_eavs.geojson: counties_eavs.ndjson
	# ndjson-reduce < counties_eavs.ndjson | ndjson-map '{type: "FeatureCollection", features: d}' > counties_eavs.geojson
	ndjson-reduce 'p.features.push(d), p' '{type: "FeatureCollection", features: []}' < counties_eavs.ndjson > counties_eavs.geojson
	# npx ndjson-to-json counties_eavs.ndjson > counties_eavs.geojson

# Election stuff

# Presidential county results come from https://dataverse.harvard.edu/dataset.xhtml?persistentId=doi:10.7910/DVN/VOQCHQ
# https://github.com/MEDSL/county-returns/blob/master/countypres_2000-2016.csv
# MIT Election Data and Science Lab
MIT_countypres_2000-2016.csv:
	curl -o $@ 'https://raw.githubusercontent.com/MEDSL/county-returns/master/countypres_2000-2016.csv'

county-elections.json: MIT_countypres_2000-2016.csv
	# node node_modules/csv2json/cli.js $< > $@
	csvjson $< > $@

county-elections-countyGrouped.json: county-elections.json
	node -r esm groupByCounty.mjs $< > $@

county-elections.csv: county-elections-countyGrouped.json
	./node_modules/d3-dsv/bin/json2dsv < $< > $@

county-elections-eavs.csv: county-elections.csv eavs-new.csv
	csvjoin -c 'FIPS' county-elections.csv eavs-new.csv > $@

county-elections-eavs.db: county-elections-eavs.csv
	csvs-to-sqlite $< $@
# county-elections.ndjson: county-elections-countyGrouped.json
# 	cat $< | jq -c '.[]' | ndjson-map 'd.FIPS = (d.FIPS).padStart(5,0), d' > $@

# counties_eavs_election.ndjson: counties_eavs.ndjson county-elections.ndjson
# 	ndjson-join 'd.CleanFIPS' counties_eavs.ndjson county-elections.ndjson > counties_eavs_election.ndjson


# Upload to MapBox as a tileset source
# Validate our geojson with mapbox CLI tool
# TODO: Make sure this actually works as expected
verify_generated_geojson: counties_eavs.geojson
	tilesets validate-source $< 

# Upload our complete and bound geojson to mapbox
upload_to_mapbox: counties_eavs.geojson verify_generated_geojson
	tilesets add-source {MAPBOX_USER} {MAPBOX_TARGET_TILESET_ID} $<


# Clean-up
clean:
	rm -rf ./*.zip
	rm -rf ./cb_*.*
	rm -f counties.geojson
	rm -f counties_eavs.geojson
	rm -f eavs_trimmed.csv
	rm -f eavs-trimmed.json
	rm -f county-elections.json
	rm -f counties_eavs.geojson
	rm -f county-elections-countyGrouped.json
	rm -f eavs-trimmed.csv
	rm -f *.ndjson
	rm -f *.csv
	rm -f *.xlsx
	rm -f *.db