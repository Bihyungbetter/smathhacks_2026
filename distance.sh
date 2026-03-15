#!/bin/ash

Interval="${1:-2}"
Cal="-46:1 -51:5 -56:10 -63:15 -68:20 -71:25 -78:30"

Mac_0A_B7_2A_0C_66_8B="phone"
Mac_50_2E_91_CC_BB_CE="pc"

get_name() {
    local safe=$(echo "$1" | tr ':' '_')
    eval "local n=\$Mac_${safe}"
    echo "${n:-$1}"
}

get_dist() {
    echo "$1" | awk -v cal="$Cal" '{
        r = $1 + 0
        n = split(cal, pts, " ")
        for (i=1; i<=n; i++) {
            split(pts[i], kv, ":")
            rs[i] = kv[1] + 0
            ds[i] = kv[2] + 0
        }
        if (r >= rs[1]) { printf "%.1f", ds[1]; exit }
        if (r <= rs[n]) {
            slope = (ds[n] - ds[n-1]) / (rs[n] - rs[n-1])
            d = ds[n] + slope * (r - rs[n])
            if (d < ds[n]) d = ds[n]
            printf "%.1f", d
            exit
        }
        for (i=1; i<n; i++) {
            if (r <= rs[i] && r >= rs[i+1]) {
                frac = (r - rs[i]) / (rs[i+1] - rs[i])
                d = ds[i] + frac * (ds[i+1] - ds[i])
                printf "%.1f", d
                exit
            }
        }
    }'
}

while true; do
    clear
    echo "ReefGuard Distance Monitor  $(date '+%H:%M:%S')"
    echo ""
    iwinfo ra0 assoclist 2>/dev/null | while read line; do
        mac=$(echo "$line" | grep -oE '([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}')
        [ -z "$mac" ] && continue
        rssi=$(echo "$line" | awk '{for(i=1;i<=NF;i++) if($i~/^-[0-9]+$/){print $i;exit}}')
        [ -z "$rssi" ] && continue
        name=$(get_name "$mac")
        dist=$(get_dist "$rssi")
        echo "  $name   RSSI: $rssi dBm   Distance: ${dist}m"
    done
    echo ""
    echo "Refreshing every ${Interval}s — Ctrl+C to stop"
    sleep "$Interval"
done
