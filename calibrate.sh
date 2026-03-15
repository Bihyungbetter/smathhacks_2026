#!/bin/ash

Mac="$1"
Duration="${2:-30}"

if [ -z "$Mac" ]; then
    echo "Usage: calibrate.sh <MAC_ADDRESS> [duration_seconds]"
    exit 1
fi

echo "Calibrating for device: $Mac"
echo "Duration: ${Duration}s"

Readings=""
Count=0
Elapsed=0
Interval=3

while [ "$Elapsed" -lt "$Duration" ]; do
    for iface in ra0 ra1; do
        Rssi=$(iwinfo "$iface" assoclist 2>/dev/null | grep -i "$Mac" | grep -oE '\-[0-9]+' | head -1)
        if [ -n "$Rssi" ]; then
            Count=$((Count + 1))
            Readings="$Readings $Rssi"
            echo "  Reading $Count: $Rssi dBm"
        fi
    done
    sleep "$Interval"
    Elapsed=$((Elapsed + Interval))
done

if [ "$Count" -eq 0 ]; then
    echo "No readings for $Mac"
    exit 1
fi

Sorted=$(echo "$Readings" | tr ' ' '\n' | grep -v '^$' | sort -n)
Sum=0
Min=0
Max=-100
for r in $Readings; do
    [ -z "$r" ] && continue
    Sum=$((Sum + r))
    if [ "$r" -lt "$Min" ]; then Min=$r; fi
    if [ "$r" -gt "$Max" ]; then Max=$r; fi
done
Avg=$((Sum / Count))

Mid=$(( (Count + 1) / 2 ))
Median=$(echo "$Sorted" | sed -n "${Mid}p")

echo "Results for $Mac:"
echo "  Samples:  $Count"
echo "  Average:  $Avg dBm"
echo "  Median:   $Median dBm"
echo "  Min:      $Min dBm"
echo "  Max:      $Max dBm"
