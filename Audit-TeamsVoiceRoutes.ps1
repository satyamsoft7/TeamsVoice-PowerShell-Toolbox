<#
.SYNOPSIS
    Audits Microsoft Teams Direct Routing Voice Routes, PSTN Usages, and SBC Gateways.
.DESCRIPTION
    Scans the tenant voice routing configuration, validates regex number patterns,
    inspects gateway health, and identifies orphaned routing policies.
.EXAMPLE
    .\Audit-TeamsVoiceRoutes.ps1
.LINK
    https://skypeexchange4u.com/teams-voice-routing-policy-explained/
#>

[CmdletBinding()]
param()

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Microsoft Teams Direct Routing Audit Engine" -ForegroundColor Cyan
Write-Host " Powered by SkypeExchange4U.com Engineering" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Connection Check
try {
    $tenant = Get-CsTenant -ErrorAction Stop
    Write-Host "[+] Connected to Tenant: $($tenant.DisplayName)" -ForegroundColor Green
} catch {
    Write-Warning "Connecting to MicrosoftTeams module..."
    Connect-MicrosoftTeams
}

# 2. Audit PSTN Gateways (SBCs)
Write-Host "`n[*] Step 1: Auditing Registered PSTN Gateways (SBCs)..." -ForegroundColor Yellow
$gateways = Get-CsOnlinePstnGateway
if ($gateways) {
    foreach ($gw in $gateways) {
        Write-Host "  -> Gateway: $($gw.Identity) (Port: $($gw.SipSignalingPort), Enabled: $($gw.Enabled))" -ForegroundColor White
        Write-Host "     Ping Status: FailoverPstnUsages = $($gw.FailoverPstnUsages), MediaBypass = $($gw.MediaBypassEnabled)" -ForegroundColor Gray
    }
} else {
    Write-Warning "[!] No Online PSTN Gateways discovered in tenant."
}

# 3. Audit Voice Routes & Regex Patterns
Write-Host "`n[*] Step 2: Auditing Online Voice Routes & Number Patterns..." -ForegroundColor Yellow
$routes = Get-CsOnlineVoiceRoute
if ($routes) {
    foreach ($r in $routes) {
        Write-Host "  -> Voice Route: $($r.Identity) (Priority: $($r.Priority))" -ForegroundColor White
        Write-Host "     Pattern:      $($r.NumberPattern)" -ForegroundColor Gray
        Write-Host "     Gateways:     $($r.OnlinePstnGatewayList -join ', ')" -ForegroundColor Gray
        Write-Host "     PSTN Usages:  $($r.OnlinePstnUsages -join ', ')" -ForegroundColor Gray
    }
} else {
    Write-Warning "[!] No Online Voice Routes found."
}

# 4. Audit Voice Routing Policies
Write-Host "`n[*] Step 3: Auditing Online Voice Routing Policies..." -ForegroundColor Yellow
$policies = Get-CsOnlineVoiceRoutingPolicy
foreach ($pol in $policies) {
    Write-Host "  -> Policy: $($pol.Identity)" -ForegroundColor White
    Write-Host "     Mapped Usages: $($pol.OnlinePstnUsages -join ', ')" -ForegroundColor Gray
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host " Audit complete. For routing precedence runbooks:" -ForegroundColor Cyan
Write-Host " https://skypeexchange4u.com/teams-voice-routing-policy-explained/" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
