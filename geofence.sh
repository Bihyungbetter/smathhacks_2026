#!/bin/ash

Mac0AB72A0C668B="phone"
Mac502E91CCBBCE="pc"

log() {
    echo "$(date '+%H:%M:%S') $1" >> "/tmp/reefguard.log"
}

getName() {
    local safe=$(echo "$1" | tr -d ':')
    eval "local name=\$Mac${safe}"
    echo "${name:-$1}"
}

store() {
    local safe=$(echo "$1" | tr -d ':')
    local file="/tmp/reefguard_rssi/$safe"

    echo "$2" >> "$file"

    local count=$(wc -l < "$file")
    if [ "$count" -gt 5 ]; then
        sed -i "1,$((count - 5))d" "$file"
    fi
}

smooth() {
    local safe=$(echo "$1" | tr -d ':')
    local sorted=$(sort -n "/tmp/reefguard_rssi/$safe")
    local count=$(echo "$sorted" | wc -l)
    echo "$sorted" | sed -n "$(( (count + 1) / 2 ))p"
}

distance() {
    echo "$1" | awk -v cal="-46:1 -51:5 -56:10 -63:15 -68:20 -71:25 -78:30" '{
        r = $1 + 0
        n = split(cal, pts, " ")
        for (i=1; i<=n; i++) {
            split(pts[i], kv, ":")
            rssi[i] = kv[1] + 0
            dist[i] = kv[2] + 0
        }
        if (r >= rssi[1]) { printf "%.1f", dist[1]; exit }
        if (r <= rssi[n]) {
            slope = (dist[n] - dist[n-1]) / (rssi[n] - rssi[n-1])
            printf "%.1f", dist[n] + slope * (r - rssi[n])
            exit
        }
        for (i=1; i<n; i++) {
            if (r <= rssi[i] && r >= rssi[i+1]) {
                frac = (r - rssi[i]) / (rssi[i+1] - rssi[i])
                printf "%.1f", dist[i] + frac * (dist[i+1] - dist[i])
                exit
            }
        }
    }'
}

classify() {
    echo $(distance "$1") | awk -v cz="$2" '{
        d = $1 + 0
        if (cz == "close") {
            if (d > 7) {
                if (d <= 15) print "medium"
                else print "far"
            } else print "close"
        } else if (cz == "medium") {
            if (d <= 5) print "close"
            else if (d > 18) print "far"
            else print "medium"
        } else {
            if (d <= 5) print "close"
            else if (d <= 15) print "medium"
            else print "far"
        }
    }'
}

current() {
    jsonfilter -i "/tmp/reefguard_zones.json" -e "$.devices[@.mac='$1'].zone" 2>/dev/null || echo "unknown"
}

serve_cgi() {
    echo "Content-Type: application/json"
    echo "Access-Control-Allow-Origin: *"
    echo ""
    cat "/tmp/reefguard_zones.json"
}

mkdir -p "/tmp/reefguard_rssi"
log "ReefGuard geofence monitor starting"

while true; do
    timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    : > "/tmp/reefguard_devices.tmp"

    for iface in ra0 ra1; do
        iwinfo "$iface" assoclist 2>/dev/null | awk '
            /([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}/ {
                mac = $1
                for (i=2; i<=NF; i++) {
                    if ($i ~ /^-[0-9]+$/) { rssi = $i; break }
                }
                if (mac != "" && rssi != "") print mac " " rssi
                rssi = ""
            }
        ' > /tmp/reefguard_clients.tmp

        while read mac rssi; do
            store "$mac" "$rssi"
            smoothed=$(smooth "$mac")
            zone=$(current "$mac")
            newzone=$(classify "$smoothed" "$zone")
            name=$(getName "$mac")
            dist=$(distance "$smoothed")

            if [ "$zone" != "$newzone" ] && [ "$zone" != "unknown" ]; then
                log "ZONE_CHANGE: $name ($mac) $zone -> $newzone (dist: ${dist}m, RSSI: $smoothed dBm)"
            fi

            echo "{\"mac\":\"$mac\",\"name\":\"$name\",\"rssi\":$smoothed,\"distance\":$dist,\"zone\":\"$newzone\",\"iface\":\"$iface\"}" >> "/tmp/reefguard_devices.tmp"
        done < /tmp/reefguard_clients.tmp
    done

    devices=""
    while IFS= read -r line; do
        if [ -n "$devices" ]; then
            devices="$devices,$line"
        else
            devices="$line"
        fi
    done < "/tmp/reefguard_devices.tmp"

    close=$(grep -c '"zone":"close"' "/tmp/reefguard_devices.tmp")
    medium=$(grep -c '"zone":"medium"' "/tmp/reefguard_devices.tmp")
    far=$(grep -c '"zone":"far"' "/tmp/reefguard_devices.tmp")

    cat > "/tmp/reefguard_zones.json" << ENDJSON
{
  "timestamp": "$timestamp",
  "zones": {
    "close": {"count": $close, "enter": 5, "leave": 7},
    "medium": {"count": $medium, "enter": 15, "leave": 18},
    "far": {"count": $far}
  },
  "devices": [$devices],
  "config": {
    "reception": 5,
    "history": 5,
    "calibration": "-46:1 -51:5 -56:10 -63:15 -68:20 -71:25 -78:30"
  }
}
ENDJSON

    sleep 5
done
