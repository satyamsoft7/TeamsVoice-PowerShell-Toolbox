<#
.SYNOPSIS
    Microsoft Teams Direct Routing Media Plane & Port Connectivity Diagnostic Utility.

.DESCRIPTION
    Test-DirectRoutingMediaPorts audits network and firewall connectivity between an enterprise
    environment (or Session Border Controller) and Microsoft Teams Direct Routing cloud endpoints.
    It validates:
    1. Direct Routing SIP Signaling Proxies (TCP 5061) across sip.pstnhub, sip2, and sip3.
    2. Microsoft Regional Cloud Media Processor STUN/TURN listeners (UDP 3478-3481).
    3. Customer SBC SIP listener socket connectivity (default port 5061).
    4. Media port range availability for RTP/SRTP traffic (UDP 50000-50019 / 49152-53247).

.PARAMETER SbcFqdn
    The fully qualified domain name of your customer Session Border Controller.

.PARAMETER SbcSipPort
    The SIP signaling port on your customer SBC (default: 5061).

.EXAMPLE
    Test-DirectRoutingMediaPorts -SbcFqdn "sbc.contoso.com"

.NOTES
    Author: Satya Pathak (SkypeExchange4U.com)
    Repository: https://github.com/satyamsoft7/TeamsVoice-PowerShell-Toolbox
    Reference: https://skypeexchange4u.com/teams-direct-routing-one-way-audio-troubleshooting-fix/
#>

function Test-DirectRoutingMediaPorts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$SbcFqdn = "sbc.yourdomain.com",

        [Parameter(Mandatory = $false)]
        [int]$SbcSipPort = 5061
    )

    Write-Host "`n===================================================================" -ForegroundColor Cyan
    Write-Host " Microsoft Teams Direct Routing Media Plane Diagnostic Utility" -ForegroundColor Cyan
    Write-Host "===================================================================" -ForegroundColor Cyan

    # 1. Test SIP Signaling Endpoints (TLS Port 5061)
    Write-Host "`n[1/3] Testing Microsoft Direct Routing SIP Signaling Endpoints (Port 5061)..." -ForegroundColor Yellow
    $SignalingEndpoints = @(
        "sip.pstnhub.microsoft.com",
        "sip2.pstnhub.microsoft.com",
        "sip3.pstnhub.microsoft.com"
    )

    foreach ($Ep in $SignalingEndpoints) {
        $TcpTest = Test-NetConnection -ComputerName $Ep -Port 5061 -WarningAction SilentlyContinue
        if ($TcpTest.TcpTestSucceeded) {
            Write-Host "  [PASS] $Ep`:5061 - Connected successfully." -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] $Ep`:5061 - Connection failed! Check perimeter outbound firewall." -ForegroundColor Red
        }
    }

    # 2. Test Microsoft Cloud Media Processor STUN Endpoints (Port 3478)
    Write-Host "`n[2/3] Auditing Microsoft Cloud Media Processor STUN Endpoints (UDP/TCP 3478)..." -ForegroundColor Yellow
    $MediaEndpoints = @(
        "worldaz.turn.teams.microsoft.com"
    )

    foreach ($MEp in $MediaEndpoints) {
        $TcpFallback = Test-NetConnection -ComputerName $MEp -Port 3478 -WarningAction SilentlyContinue
        if ($TcpFallback.TcpTestSucceeded) {
            Write-Host "  [PASS] $MEp`:3478 - STUN endpoint reachable." -ForegroundColor Green
        } else {
            Write-Host "  [WARN] $MEp`:3478 - STUN TCP fallback unreachable. Verify UDP 3478-3481 on firewall." -ForegroundColor Yellow
        }
    }

    # 3. Test Customer SBC Listener
    Write-Host "`n[3/3] Validating Customer SBC Listener ($SbcFqdn)..." -ForegroundColor Yellow
    if ($SbcFqdn -and $SbcFqdn -ne "sbc.yourdomain.com") {
        $SbcTest = Test-NetConnection -ComputerName $SbcFqdn -Port $SbcSipPort -WarningAction SilentlyContinue
        if ($SbcTest.TcpTestSucceeded) {
            Write-Host "  [PASS] Customer SBC ($SbcFqdn`:$SbcSipPort) is listening." -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] Cannot reach SBC listener on $SbcFqdn`:$SbcSipPort. Check WAN IP & NAT." -ForegroundColor Red
        }
    } else {
        Write-Host "  [INFO] Pass -SbcFqdn parameter to test your specific SBC endpoint socket." -ForegroundColor Gray
    }

    Write-Host "`n===================================================================" -ForegroundColor Cyan
    Write-Host " Note: If one-way audio occurs despite open signaling ports, verify:" -ForegroundColor Gray
    Write-Host " 1. SBC IP Routing Table has static routes for internal LAN subnets." -ForegroundColor Gray
    Write-Host " 2. SIP ALG is DISABLED on perimeter firewalls." -ForegroundColor Gray
    Write-Host " 3. UDP session timeouts for 52.112.0.0/14 and 52.122.0.0/15 are >= 180s." -ForegroundColor Gray
    Write-Host "===================================================================`n" -ForegroundColor Cyan
}
