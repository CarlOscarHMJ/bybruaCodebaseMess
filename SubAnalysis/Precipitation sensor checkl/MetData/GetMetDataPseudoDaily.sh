#!/usr/bin/env bash
########################################
# Get hourly data and sum to daily (00:00-23:59 UTC)
########################################

CLIENT_ID="80650a9b-e79f-4fcd-b7fe-d23b68b14632"
API_KEY="2d34de58-f08b-475e-9f09-5063da7758ab"

STATION_ID="SN44640"

# Get a period (hourly data available from 1999-08-17)
TIME_START="2020-01-01T00:00:00Z"
TIME_END="2020-12-31T23:59:59Z"

OUT_FILE="precipitation_hourly_for_daily_sum_${START_TIME}_${TIME_END}.json"

echo "Fetching hourly precipitation data..."
curl -sS -u "$CLIENT_ID:$API_KEY" \
"https://frost.met.no/observations/v0.jsonld?sources=${STATION_ID}&elements=sum(precipitation_amount%20PT1H)&referencetime=${TIME_START}/${TIME_END}" \
> "$OUT_FILE"

if grep -q '"@type" : "ObservationResponse"' "$OUT_FILE"; then
    echo "✓ Success! Data saved to: $OUT_FILE"
    echo "- Hourly records: $(grep -c '"referenceTime"' "$OUT_FILE")"
    echo ""
    echo "Now you can sum the hourly values per day (00:00-23:59 UTC)"
else
    echo "✗ Error occurred"
fi