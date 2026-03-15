while ($true) {
    Clear-Host
    Write-Host "ReefGuard Live Monitor  $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Cyan
    Write-Host ""
    try {
        $data = Invoke-RestMethod http://192.168.8.1:8080/api/zones
        foreach ($dev in $data.devices) {
            $color = switch ($dev.zone) {
                "close"  { "Red" }
                "medium" { "Yellow" }
                "far"    { "Green" }
            }
            Write-Host "  $($dev.name)" -NoNewline -ForegroundColor $color
            Write-Host "  |  $($dev.distance_m)m  |  zone: $($dev.zone)  |  RSSI: $($dev.rssi) dBm"
        }
        Write-Host ""
        Write-Host "  Close: $($data.zones.close.count)  Medium: $($data.zones.medium.count)  Far: $($data.zones.far.count)"
    } catch {
        Write-Host "  API not responding" -ForegroundColor Red
    }
    Start-Sleep -Seconds 2
}
