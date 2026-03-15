#!/bin/ash

Port=8080
State_file="/tmp/reefguard_zones.json"
Log_file="/tmp/reefguard.log"

serve_netcat() {
    echo "ReefGuard API listening on port $Port"
    while true; do
        {
            read -r request_line
            method=$(echo "$request_line" | awk '{print $1}')
            path=$(echo "$request_line" | awk '{print $2}')

            while read -r header; do
                [ "$header" = "$(printf '\r')" ] && break
                [ -z "$header" ] && break
            done

            case "$path" in
                /api/zones)
                    body=$(cat "$State_file")
                    ;;
                /api/alerts)
                    body="["
                    first=1
                    tail -20 "$Log_file" | grep "ZONE_CHANGE" | while read line; do
                        ts=$(echo "$line" | awk '{print $1}')
                        detail=$(echo "$line" | sed 's/^[^ ]* ZONE_CHANGE: //')
                        if [ "$first" = "1" ]; then
                            first=0
                        else
                            printf ","
                        fi
                        printf '{"time":"%s","event":"%s"}' "$ts" "$detail"
                    done
                    body="$body]"
                    ;;
                /api/device/*)
                    mac=$(echo "$path" | sed 's|/api/device/||')
                    body=$(jsonfilter -i "$State_file" -e "$.devices[@.mac='$mac']")
                    ;;
                /api/config)
                    body=$(jsonfilter -i "$State_file" -e '$.config')
                    ;;
                *)
                    body='{"endpoints":["/api/zones","/api/alerts","/api/device/<mac>","/api/config"]}'
                    ;;
            esac

            content_length=$(echo -n "$body" | wc -c)
            printf "HTTP/1.1 200 OK\r\n"
            printf "Content-Type: application/json\r\n"
            printf "Access-Control-Allow-Origin: *\r\n"
            printf "Access-Control-Allow-Methods: GET\r\n"
            printf "Connection: close\r\n"
            printf "Content-Length: %d\r\n" "$content_length"
            printf "\r\n"
            printf "%s" "$body"
        } | nc -l -p "$Port" -w 5 2>/dev/null
    done
}

serve_netcat
