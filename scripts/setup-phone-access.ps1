# ================================================================
# setup-phone-access.ps1 — One-time setup for phone WiFi sync
# ================================================================
# Run this script once (as Administrator) to enable your phone
# to connect to the KJV Strong's Bible app via WiFi QR code.
#
# What it does:
#   1. Detects your PC's local network IP address
#   2. Registers an HTTP listener reservation for that IP (netsh)
#   3. Adds a Windows Firewall rule to allow inbound on port 8080
#
# This only needs to be run once. Settings persist across reboots.
# If your IP changes (DHCP), run this script again.
# ================================================================

#Requires -RunAsAdministrator

$Port = 8080

# Detect LAN IP
function Get-LanIp {
    try {
        $ip = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
              Where-Object { $_.IPAddress -notmatch "^127\." -and $_.IPAddress -notmatch "^169\.254\." } |
              Sort-Object { if ($_.PrefixOrigin -eq "Dhcp") { 0 } else { 1 } } |
              Select-Object -First 1 -ExpandProperty IPAddress
        return $ip
    } catch {
        return $null
    }
}

$lanIp = Get-LanIp
if (-not $lanIp) {
    Write-Host "ERROR: Could not detect local IP address. Make sure you are connected to WiFi or Ethernet." -ForegroundColor Red
    exit 1
}

$lanPrefix = "http://${lanIp}:${Port}/"
Write-Host ""
Write-Host "  Detected LAN IP: $lanIp" -ForegroundColor Cyan
Write-Host ""

# Step 1: Register netsh urlacl
Write-Host "  Step 1: Registering HTTP listener for $lanPrefix..." -ForegroundColor Yellow
$existing = & netsh http show urlacl url=$lanPrefix 2>&1 | Out-String
if ($existing -match [regex]::Escape($lanPrefix)) {
    Write-Host "          Already registered. Skipping." -ForegroundColor Green
} else {
    $result = & netsh http add urlacl url=$lanPrefix user=Everyone 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "          Registered successfully." -ForegroundColor Green
    } else {
        Write-Host "          WARNING: $result" -ForegroundColor Yellow
    }
}

# Step 2: Add Windows Firewall rule
$ruleName = "KJV Strong's Bible - Phone WiFi Sync (port $Port)"
Write-Host "  Step 2: Adding Windows Firewall rule for port $Port..." -ForegroundColor Yellow
$existingRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
if ($existingRule) {
    Write-Host "          Rule already exists. Skipping." -ForegroundColor Green
} else {
    New-NetFirewallRule -DisplayName $ruleName `
        -Direction Inbound `
        -Protocol TCP `
        -LocalPort $Port `
        -Action Allow `
        -Profile Private `
        -Description "Allows phones on the local WiFi network to connect to KJV Strong's Bible for note syncing." `
        | Out-Null
    Write-Host "          Firewall rule added successfully." -ForegroundColor Green
}

Write-Host ""
Write-Host "  ============================================" -ForegroundColor Green
Write-Host "  Phone access setup complete!" -ForegroundColor Green
Write-Host "  ============================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Your phone can now connect to:" -ForegroundColor Cyan
Write-Host "  $lanPrefix" -ForegroundColor White
Write-Host ""
Write-Host "  Open the KJV Strong's Bible app, click the" -ForegroundColor Gray
Write-Host "  hamburger menu, and choose 'Sync Phone via" -ForegroundColor Gray
Write-Host "  QR Code' to get started." -ForegroundColor Gray
Write-Host ""
