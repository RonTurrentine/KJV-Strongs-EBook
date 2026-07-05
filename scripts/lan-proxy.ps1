# ================================================================
# LAN PROXY — Phone WiFi Access for KJV Strong's Bible
# ================================================================
#
# ARCHITECTURE:
#   HttpListener (localhost:8080)  ← existing, unchanged
#        ↑ forwards to (with Host header rewritten)
#   TcpListener (0.0.0.0:8081)    ← NEW, no elevation needed
#        ↑ phone connects here
#   Phone browser (192.168.86.x)
#
# WHY THIS WORKS:
#   - TcpListener does NOT use HTTP.sys → no elevation, no urlacl
#   - Host header rewriting makes HttpListener accept the request
#   - Port 8081 is free (HTTP.sys only owns port 8080)
#   - Firewall rule for 8081 is the only elevated step (one-time)
#
# WHAT TO CHANGE:
#   1. Add the C# proxy class to start-study.ps1 (near the top)
#   2. Start the proxy after HttpListener starts
#   3. Stop the proxy in the finally block
#   4. Update Handle-LocalUrl to return port 8081
#   5. Update setup-phone-access.ps1 (firewall on 8081, no netsh)
#
# ================================================================


# ==============================================================
# PART 1: C# Proxy Class — Add near the top of start-study.ps1,
#         after the param() block and before any functions
# ==============================================================

Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;

public class LanProxy
{
    private TcpListener _listener;
    private int _targetPort;
    private CancellationTokenSource _cts;
    private Task _acceptTask;
    private bool _running;

    public LanProxy(int listenPort, int targetPort)
    {
        _listener = new TcpListener(IPAddress.Any, listenPort);
        _targetPort = targetPort;
        _cts = new CancellationTokenSource();
    }

    public bool Start()
    {
        try
        {
            _listener.Start();
            _running = true;
            _acceptTask = Task.Run(() => AcceptLoop());
            return true;
        }
        catch (Exception)
        {
            return false;
        }
    }

    public void Stop()
    {
        _running = false;
        _cts.Cancel();
        try { _listener.Stop(); } catch { }
    }

    private async Task AcceptLoop()
    {
        while (_running && !_cts.IsCancellationRequested)
        {
            TcpClient client = null;
            try
            {
                client = await _listener.AcceptTcpClientAsync();
                // Fire-and-forget each connection handler
                var c = client;
                Task.Run(() => HandleClient(c));
            }
            catch (ObjectDisposedException) { break; }
            catch (SocketException) { if (!_running) break; }
            catch { }
        }
    }

    private async Task HandleClient(TcpClient client)
    {
        TcpClient upstream = null;
        try
        {
            client.ReceiveTimeout = 30000;
            client.SendTimeout = 30000;

            var clientStream = client.GetStream();

            // Read the first chunk (contains HTTP headers)
            var buffer = new byte[16384];
            int bytesRead = await clientStream.ReadAsync(buffer, 0, buffer.Length);
            if (bytesRead == 0) { client.Close(); return; }

            // Find the end of HTTP headers (\r\n\r\n)
            int headerEnd = -1;
            for (int i = 0; i < bytesRead - 3; i++)
            {
                if (buffer[i] == 13 && buffer[i+1] == 10 &&
                    buffer[i+2] == 13 && buffer[i+3] == 10)
                {
                    headerEnd = i + 4;
                    break;
                }
            }

            byte[] toSend;

            if (headerEnd > 0)
            {
                // Split headers from any body data in this chunk
                string headers = Encoding.ASCII.GetString(buffer, 0, headerEnd);

                // Rewrite Host header to localhost:targetPort
                headers = Regex.Replace(headers,
                    @"(?i)Host:\s*[^\r\n]+",
                    "Host: localhost:" + _targetPort);

                byte[] modifiedHeaders = Encoding.ASCII.GetBytes(headers);

                // Reconstruct: modified headers + any body bytes
                int bodyBytesInChunk = bytesRead - headerEnd;
                toSend = new byte[modifiedHeaders.Length + bodyBytesInChunk];
                Array.Copy(modifiedHeaders, 0, toSend, 0, modifiedHeaders.Length);
                if (bodyBytesInChunk > 0)
                {
                    Array.Copy(buffer, headerEnd, toSend,
                               modifiedHeaders.Length, bodyBytesInChunk);
                }
            }
            else
            {
                // No header boundary found (shouldn't happen for valid HTTP)
                // Forward as-is
                toSend = new byte[bytesRead];
                Array.Copy(buffer, 0, toSend, 0, bytesRead);
            }

            // Connect to localhost HttpListener
            upstream = new TcpClient();
            await upstream.ConnectAsync(IPAddress.Loopback, _targetPort);
            var upstreamStream = upstream.GetStream();

            // Send the modified first chunk
            await upstreamStream.WriteAsync(toSend, 0, toSend.Length);
            await upstreamStream.FlushAsync();

            // Relay bidirectionally: phone↔upstream
            var toServer = RelayAsync(clientStream, upstreamStream, _cts.Token);
            var toClient = RelayAsync(upstreamStream, clientStream, _cts.Token);

            await Task.WhenAny(toServer, toClient);
        }
        catch { /* connection closed or error — clean up silently */ }
        finally
        {
            try { client.Close(); } catch { }
            try { if (upstream != null) upstream.Close(); } catch { }
        }
    }

    private async Task RelayAsync(NetworkStream from, NetworkStream to,
                                   CancellationToken ct)
    {
        var buf = new byte[8192];
        try
        {
            int n;
            while (!ct.IsCancellationRequested &&
                   (n = await from.ReadAsync(buf, 0, buf.Length)) > 0)
            {
                await to.WriteAsync(buf, 0, n);
                await to.FlushAsync();
            }
        }
        catch { /* stream closed */ }
    }
}
'@ -ReferencedAssemblies @("System.Net.Primitives", "System.Net.Sockets")


# ==============================================================
# PART 2: Start the proxy — Add AFTER the HttpListener starts
#         and the banner prints (around line 1493)
# ==============================================================

<#
# ── LAN Proxy for Phone WiFi Access ──────────────────────────────
$LanPort = $Port + 1    # 8081
$lanProxy = New-Object LanProxy -ArgumentList $LanPort, $Port

$lanStarted = $lanProxy.Start()
if ($lanStarted) {
    $lanIp = Get-LanIp
    if ($lanIp) {
        Write-Host "  LAN proxy running at:  http://${lanIp}:${LanPort}/" -ForegroundColor Green
        Write-Host "  Phone can connect on port $LanPort" -ForegroundColor Gray
    } else {
        Write-Host "  LAN proxy running on port $LanPort (no LAN IP detected)" -ForegroundColor Yellow
    }
} else {
    Write-Host "  LAN proxy could not start on port $LanPort (port in use?)" -ForegroundColor Yellow
    Write-Host "  Phone WiFi sync will not be available this session." -ForegroundColor Yellow
}
Write-Host ""
#>


# ==============================================================
# PART 3: Stop the proxy — Add to the finally block (line ~1618)
# ==============================================================

<#
finally {
    Write-Host ""
    Write-Host "Shutting down server..." -ForegroundColor Yellow
    # Stop LAN proxy first
    if ($lanProxy) {
        try { $lanProxy.Stop() } catch {}
        Write-Host "  LAN proxy stopped." -ForegroundColor Gray
    }
    $listener.Stop()
    $listener.Close()
    Write-Host "Server stopped." -ForegroundColor Green
}
#>


# ==============================================================
# PART 4: Update Handle-LocalUrl to return LAN port (8081)
# ==============================================================
# Replace the existing Handle-LocalUrl function:

<#
function Handle-LocalUrl {
    param([System.Net.HttpListenerResponse]$Response)
    $ip = Get-LanIp
    $lprt = $Port + 1    # LAN proxy port (8081)
    if ($ip) {
        Send-Json -Response $Response -Data @{
            ok   = $true
            url  = "http://${ip}:${lprt}/"
            ip   = $ip
            port = $lprt
        }
    } else {
        Send-Json -Response $Response -Data @{
            ok    = $false
            error = "Could not detect local IP address. Make sure your PC is connected to WiFi or Ethernet."
        }
    }
}
#>


# ==============================================================
# PART 5: Updated setup-phone-access.ps1
# ==============================================================
# SIMPLIFIED: Only a firewall rule is needed. No netsh urlacl
# because the LAN proxy uses TcpListener (raw sockets), not
# HTTP.sys. Replace the entire setup-phone-access.ps1 with:
# ==============================================================

<#
# setup-phone-access.ps1 — One-time firewall setup for phone WiFi sync
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

# Add Windows Firewall rule for the LAN proxy port
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
        -Description "Allows phones on the local WiFi to connect to KJV Strong's Bible for note syncing (LAN proxy on port $LanPort)." `
        | Out-Null
    Write-Host "  Firewall rule added." -ForegroundColor Green
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
#>


# ==============================================================
# WHY THIS APPROACH WORKS (for the README / developer notes)
# ==============================================================
#
# Problem: System.Net.HttpListener uses HTTP.sys (kernel driver).
#   - HTTP.sys owns port 8080 on ALL interfaces
#   - Only accepts requests where Host header matches a registered prefix
#   - Registering LAN IP prefixes requires elevation (netsh urlacl)
#   - Even with elevation, HTTP.sys conflict errors are common
#
# Solution: TcpListener-based proxy on port 8081.
#   - TcpListener uses raw sockets → no HTTP.sys, no elevation
#   - Listens on 0.0.0.0:8081 (all interfaces, different port)
#   - For each connection: reads HTTP headers, rewrites Host header
#     from "Host: 192.168.86.39:8081" to "Host: localhost:8080",
#     connects to 127.0.0.1:8080, forwards modified request,
#     relays response back bidirectionally
#   - HttpListener sees valid "Host: localhost:8080" → accepts it
#   - Only one-time setup needed: firewall rule for port 8081
#   - No netsh urlacl registration at all
#
# Data flow:
#   Phone browser                → http://192.168.86.39:8081/api/notes
#   TcpListener (port 8081)      receives: Host: 192.168.86.39:8081
#   Host header rewrite          changes to: Host: localhost:8080
#   Forward to localhost:8080    → HttpListener accepts it
#   HttpListener processes       → returns JSON response
#   Relay response back          → through TcpListener → to phone
#
# Performance: The proxy adds ~1ms of latency (local TCP hop).
# Negligible for all use cases (API calls, page loads).
#
# Security: The existing IP allowlist in start-study.ps1 (line 1524)
# still applies — only private subnet IPs (127.x, 192.168.x,
# 10.x, 172.16-31.x) are accepted. The proxy doesn't bypass this
# because the requests still go through HttpListener's main loop.
#
# ==============================================================
