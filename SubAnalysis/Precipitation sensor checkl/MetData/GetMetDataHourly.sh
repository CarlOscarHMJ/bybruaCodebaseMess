#!/usr/bin/env bash
########################################
# SETTINGS (edit these)
CLIENT_ID="80650a9b-e79f-4fcd-b7fe-d23b68b14632"
API_KEY="2d34de58-f08b-475e-9f09-5063da7758ab"

# Station: SN44640 (Stavanger - Våland)
STATION_ID="SN44640"

# Time period (UTC)
TIME_START="2020-07-26T00:00:00Z"
TIME_END="2020-07-27T00:00:00Z"

# Element: hourly precipitation sum
ELEMENT="sum(precipitation_amount%20PT1H)"

# Output file
OUT_FILE="precipitationHourly_${STATION_ID}_${TIME_START}_to_${TIME_END}.json"

########################################
# Fetch the data
########################################
echo "Fetching precipitation data from ${STATION_ID}..."
curl -sS -u "$CLIENT_ID:$API_KEY" \
"https://frost.met.no/observations/v0.jsonld?sources=${STATION_ID}&elements=${ELEMENT}&referencetime=${TIME_START}/${TIME_END}" \
> "$OUT_FILE"

# Check if successful
if grep -q '"@type" : "ObservationResponse"' "$OUT_FILE"; then
    echo "✓ Success! Data saved to: $OUT_FILE"
    echo ""
    echo "Summary:"
    echo "- Total records: $(grep -c '"referenceTime"' "$OUT_FILE")"
else
    echo "✗ Error occurred. Check $OUT_FILE for details"
fi