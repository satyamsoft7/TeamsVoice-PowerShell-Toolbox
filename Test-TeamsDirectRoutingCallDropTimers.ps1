<#
.SYNOPSIS
    Audits Microsoft Teams Direct Routing PSTN Gateways for Timed Call Drop Vectors
    (30-Second SIP ACK Timeouts, Contact Header Private IP NAT Leaks, and 15-Minute RFC 4028 Session Timers).

.DESCRIPTION
    Production diagnostic utility to isolate why Microsoft Teams Direct Routing calls
    connect with two-way SRTP audio (SIP 200 OK) and then drop at deterministic intervals:
    - 20 to 32 Seconds: Missing SIP ACK due to RFC 1918 IP in Contact/Record-Route header or blocked secondary proxy IPs.
    - 15 or 30 Minutes: RFC 4028 Session-Expires mid-dialog re-INVITE timeout on TCP Port 5061.

    Full Architecture & Troubleshooting Runbook:
    https://skypeexchange4u.com/teams-direct-routing-calls-dropping-30-seconds-sip-ack-fix/

.PARAMETER SbcFqdn
    Optional specific SBC FQDN (e.g., sbc1.contoso.com). If omitted, audits all tenant PSTN gateways.

.NOTES
    Author: Satya Pathak
    Documentation: https://skypeexchange4u.com/teams-direct-routing-calls-dropping-30-seconds-sip-ack-fix/
    Repository: https://github.com/satyamsoft7/TeamsVoice-PowerShell-Toolbox
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$SbcFqdn
)

Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host " Teams Direct Routing Timed Call Drop Diagnostic (30s ACK / 15m Timer)  " -ForegroundColor Cyan
Write-Host " Runbook: https://skypeexchange4u.com/teams-direct-routing-calls-dropping-30-seconds-sip-ack-fix/" -ForegroundColor DarkCyan
Write-Host "========================================================================" -ForegroundColor Cyan

try {
    $Gateways = if ($SbcFqdn) {
        @(Get-CsOnlinePSTNGateway -Identity $SbcFqdn -ErrorAction Stop)
    } else {
        Get-CsOnlinePSTNGateway -ErrorAction Stop
    }

    foreach ($Gw in $Gateways) {
        Write-Host "`n[*] Auditing Online PSTN Gateway: $($Gw.Identity)" -ForegroundColor Yellow
        Write-Host "    Enabled              : $($Gw.Enabled)"
        Write-Host "    SipSignalingPort     : $($Gw.SipSignalingPort)"
        Write-Host "    MediaBypass          : $($Gw.MediaBypass)"
        Write-Host "    BypassMode           : $($Gw.BypassMode)"
        Write-Host "    SendSipOptions       : $($Gw.SendSipOptions)"
        Write-Host "    ForwardPai           : $($Gw.ForwardPai)"

        if (-not $Gw.SendSipOptions) {
            Write-Warning "    [!] SendSipOptions is FALSE on $($Gw.Identity). Firewall TCP 5061 idle timeouts (5-10m) may drop active calls at the 15-minute RFC 4028 Session Timer re-INVITE!"
        }
        if ($Gw.MediaBypass -and $Gw.BypassMode -eq "Always") {
            Write-Warning "    [!] BypassMode is 'Always' instead of 'OnlyForLocalUsers'. Remote workers may experience 30-second RTP/ACK timeouts."
        }

        $DnsRecords = Resolve-DnsName -Name $Gw.Identity -Type A -ErrorAction SilentlyContinue
        foreach ($Rec in $DnsRecords) {
            if ($Rec.IPAddress -match "^(10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|192\.168\.)") {
                Write-Error "    [CRITICAL] $($Gw.Identity) resolves to private RFC 1918 IP ($($Rec.IPAddress))! Microsoft SIP proxies cannot deliver SIP ACK after 200 OK, causing 30-second call drops (Q.850 Cause=102)."
            } else {
                Write-Host "    [+] Public DNS A-Record Verified: $($Rec.IPAddress)" -ForegroundColor Green
            }
        }
    }
} catch {
    Write-Warning "Could not query Get-CsOnlinePSTNGateway. Connect via Connect-MicrosoftTeams first."
}

$MsProxies = @(
    "sip.pstnhub.microsoft.com",
    "sip2.pstnhub.microsoft.com",
    "sip3.pstnhub.microsoft.com"
)

Write-Host "`n[*] Validating Asymmetric SIP ACK Reachability to All 3 Microsoft Signaling Hubs (TCP 5061)..." -ForegroundColor Cyan
foreach ($Proxy in $MsProxies) {
    $Test = Test-NetConnection -ComputerName $Proxy -Port 5061 -WarningAction SilentlyContinue
    if ($Test.TcpTestSucceeded) {
        Write-Host "    [+] $Proxy ($($Test.RemoteAddress)) : TCP 5061 OPEN" -ForegroundColor Green
    } else {
        Write-Error "    [!] $Proxy : TCP 5061 BLOCKED! Asymmetric SIP ACK packets from this datacenter will fail and drop calls at 30 seconds."
    }
}
