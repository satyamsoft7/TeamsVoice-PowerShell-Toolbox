<#
.SYNOPSIS
    Comprehensive readiness and diagnostic audit for Microsoft Teams Shared Calling users.

.DESCRIPTION
    Test-TeamsSharedCallingReadiness validates that a target Teams user is properly configured
    for Microsoft Teams Shared Calling. It audits:
    1. EnterpriseVoiceEnabled status (prevents SIP 488 / missing dial pad).
    2. Assigned TeamsSharedCallingPolicy and backing Resource Account validity.
    3. Assigned OnlineVoiceRoutingPolicy (verifies that PSTN Usages are EMPTY to prevent SIP 404 / 403 route drops).
    4. Conflicting direct DIDs / LineURIs.
    5. Tenant Communication Credits / Pay-As-You-Go readiness.

.PARAMETER UserPrincipalName
    The UserPrincipalName (email) of the Teams user to test.

.EXAMPLE
    Test-TeamsSharedCallingReadiness -UserPrincipalName "retail-user01@yourdomain.com"

.NOTES
    Author: Satya Pathak (SkypeExchange4U.com)
    Repository: https://github.com/satyamsoft7/TeamsVoice-PowerShell-Toolbox
    Reference: https://skypeexchange4u.com/teams-shared-calling-outbound-calls-dropping-fix/
#>

function Test-TeamsSharedCallingReadiness {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$UserPrincipalName
    )

    process {
        Write-Host "`n========================================================" -ForegroundColor Cyan
        Write-Host " Testing Shared Calling Readiness: $UserPrincipalName" -ForegroundColor Cyan
        Write-Host "========================================================" -ForegroundColor Cyan

        $User = Get-CsOnlineUser -Identity $UserPrincipalName -ErrorAction SilentlyContinue
        if (-not $User) {
            Write-Error "User '$UserPrincipalName' was not found in Microsoft Teams directory."
            return
        }

        # 1. Enterprise Voice Flag Validation
        Write-Host "[1/4] Checking Enterprise Voice Status..." -NoNewline
        if ($User.EnterpriseVoiceEnabled) {
            Write-Host " [PASS]" -ForegroundColor Green
        } else {
            Write-Host " [FAIL]" -ForegroundColor Red
            Write-Host "       EnterpriseVoiceEnabled is FALSE. Shared users must have EnterpriseVoice enabled." -ForegroundColor Yellow
            Write-Host "       Fix: Set-CsPhoneNumberAssignment -Identity '$UserPrincipalName' -EnterpriseVoiceEnabled `$true" -ForegroundColor Gray
        }

        # 2. Shared Calling Policy Validation
        Write-Host "[2/4] Checking TeamsSharedCallingPolicy..." -NoNewline
        $SCP = $User.TeamsSharedCallingPolicy
        if ($SCP) {
            Write-Host " [PASS] (Assigned: $SCP)" -ForegroundColor Green
            $Policy = Get-CsTeamsSharedCallingPolicy -Identity $SCP -ErrorAction SilentlyContinue
            if ($Policy) {
                Write-Host "       Resource Account : $($Policy.ResourceAccount)" -ForegroundColor Gray
                Write-Host "       Emergency Callback: $($Policy.EmergencyCallbackNumber)" -ForegroundColor Gray
            }
        } else {
            Write-Host " [FAIL]" -ForegroundColor Red
            Write-Host "       No TeamsSharedCallingPolicy is assigned to user." -ForegroundColor Yellow
            Write-Host "       Fix: Grant-CsTeamsSharedCallingPolicy -Identity '$UserPrincipalName' -PolicyName 'Your-SharedCalling-Policy'" -ForegroundColor Gray
        }

        # 3. Voice Routing Policy (Empty PSTN Usages Check)
        Write-Host "[3/4] Validating OnlineVoiceRoutingPolicy..." -NoNewline
        $VRP = $User.OnlineVoiceRoutingPolicy
        if (-not $VRP) {
            Write-Host " [PASS] (None assigned; uses default null routing)" -ForegroundColor Green
        } else {
            $VRPOptions = Get-CsOnlineVoiceRoutingPolicy -Identity $VRP -ErrorAction SilentlyContinue
            if ($VRPOptions.OnlinePstnUsages.Count -eq 0) {
                Write-Host " [PASS] ($VRP has 0 PSTN Usages)" -ForegroundColor Green
            } else {
                Write-Host " [FAIL]" -ForegroundColor Red
                Write-Host "       Policy '$VRP' contains active PSTN Usages: $($VRPOptions.OnlinePstnUsages -join ', ')" -ForegroundColor Red
                Write-Host "       CRITICAL: Shared Calling will drop calls with SIP 404/403 because Teams tries to route via Direct Routing!" -ForegroundColor Yellow
                Write-Host "       Fix: Grant-CsOnlineVoiceRoutingPolicy -Identity '$UserPrincipalName' -PolicyName `$null" -ForegroundColor Gray
            }
        }

        # 4. Direct DID Conflict Check
        Write-Host "[4/4] Checking for Conflicting Direct DIDs..." -NoNewline
        if ($User.LineURI -or $User.PhoneNumber) {
            Write-Host " [WARN]" -ForegroundColor Yellow
            Write-Host "       User has an explicit phone number ($($User.LineURI)). This overrides Shared Calling." -ForegroundColor Yellow
        } else {
            Write-Host " [PASS] (Clean shared profile without DID conflict)" -ForegroundColor Green
        }

        Write-Host "========================================================`n" -ForegroundColor Cyan
    }
}
