# ================================================================
# setup-phone-access.ps1 — One-time firewall setup for phone WiFi sync
# ================================================================
# Run this script once (as Administrator) to allow your phone to
# connect to the KJV Strong's Bible app via WiFi QR code.
#
# What it does:
#   Adds a Windows Firewall rule to allow inbound TCP on port 8081
#   (the LAN proxy port — raw TcpListener, no HTTP.sys involved).
#
# No netsh urlacl registration needed! The LAN proxy uses raw TCP
# sockets, bypassing HTTP.sys entirely.
#
# This only needs to be run once. Settings persist across reboots.
# ================================================================

#Requires -RunAsAdministrator

$LanPort = 8081

Write-Host ""
Write-Host "  ============================================" -ForegroundColor Cyan
Write-Host "  Phone WiFi Sync Setup" -ForegroundColor Cyan
Write-Host "  ============================================" -ForegroundColor Cyan
Write-Host ""

# Detect LAN IP for display
function Get-LanIp {
    try {
        $ip = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
              Where-Object { $_.IPAddress -notmatch "^127\." -and $_.IPAddress -notmatch "^169\.254\." } |
              Sort-Object { if ($_.PrefixOrigin -eq "Dhcp") { 0 } else { 1 } } |
              Select-Object -First 1 -ExpandProperty IPAddress
        return $ip
    } catch { return $null }
}

$lanIp = Get-LanIp
if ($lanIp) {
    Write-Host "  Detected LAN IP: $lanIp" -ForegroundColor Green
} else {
    Write-Host "  WARNING: Could not detect LAN IP." -ForegroundColor Yellow
}

# Remove any old netsh urlacl registrations for port 8080 (cleanup from previous attempts)
Write-Host ""
Write-Host "  Cleaning up any old HTTP.sys registrations..." -ForegroundColor Yellow
$oldUrls = @(
    "http://+:8080/",
    "http://*:8080/"
)
if ($lanIp) {
    # Clean up a reservation for this PC's *current* LAN IP, detected
    # above -- not a hardcoded address from whenever this script was
    # first written, which could easily be stale (routers reassign
    # IPs). This is just cleanup of an old, now-unused approach (the
    # LAN proxy uses raw TCP sockets, not HTTP.sys), so it's harmless
    # either way if nothing matches.
    $oldUrls += "http://${lanIp}:8080/"
}
foreach ($url in $oldUrls) {
    $check = & netsh http show urlacl url=$url 2>&1 | Out-String
    if ($check -match [regex]::Escape($url)) {
        & netsh http delete urlacl url=$url 2>&1 | Out-Null
        Write-Host "  Removed old reservation: $url" -ForegroundColor Gray
    }
}

# Add Windows Firewall rule for the LAN proxy port (8081)
$ruleName = "KJV Strong's Bible - Phone WiFi Sync (port $LanPort)"
Write-Host ""
Write-Host "  Adding firewall rule for port $LanPort..." -ForegroundColor Yellow

$existingRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
if ($existingRule) {
    Write-Host "  Rule already exists. Skipping." -ForegroundColor Green
} else {
    New-NetFirewallRule -DisplayName $ruleName `
        -Direction Inbound `
        -Protocol TCP `
        -LocalPort $LanPort `
        -Action Allow `
        -Profile Private `
        -Description "Allows phones on the local WiFi to connect to KJV Strong's Bible for note syncing via LAN proxy on port $LanPort." `
        | Out-Null
    Write-Host "  Firewall rule added successfully." -ForegroundColor Green
}

Write-Host ""
Write-Host "  ============================================" -ForegroundColor Green
Write-Host "  Setup complete!" -ForegroundColor Green
Write-Host "  ============================================" -ForegroundColor Green
Write-Host ""
if ($lanIp) {
    Write-Host "  Your phone can connect to:" -ForegroundColor Cyan
    Write-Host "  http://${lanIp}:${LanPort}/" -ForegroundColor White
    Write-Host ""
}
Write-Host "  No netsh urlacl registration needed!" -ForegroundColor Gray
Write-Host "  The LAN proxy uses raw TCP sockets," -ForegroundColor Gray
Write-Host "  bypassing HTTP.sys entirely." -ForegroundColor Gray
Write-Host ""
