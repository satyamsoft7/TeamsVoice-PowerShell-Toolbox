<#
.SYNOPSIS
    Remediates stale on-premises Skype for Business / Lync Server attributes in Active Directory.

.DESCRIPTION
    Clear-HybridTeamsVoiceAttributes audits and clears legacy msRTCSIP-* attributes on synchronized
    Active Directory user accounts to resolve the Microsoft Teams error:
    "Cannot modify LineURI because the user is synchronized from on-premises Active Directory."
    
    It safely clears:
    1. msRTCSIP-Line (breaks the OnPremLineURI lock in Microsoft Teams).
    2. msRTCSIP-DeploymentLocator (prevents incorrect hybrid SIP routing).
    3. Exports a CSV pre-change rollback log before any modifications are committed.
    4. Optionally triggers an Entra Connect Delta Synchronization cycle.

.PARAMETER UserPrincipalName
    The UserPrincipalName or sAMAccountName of the target user.

.PARAMETER OrganizationalUnit
    DistinguishedName of an OU to process users in bulk.

.PARAMETER TriggerEntraSync
    Switch parameter to immediately invoke Start-ADSyncSyncCycle -PolicyType Delta.

.EXAMPLE
    Clear-HybridTeamsVoiceAttributes -UserPrincipalName "john.doe@yourdomain.com" -TriggerEntraSync

.EXAMPLE
    Clear-HybridTeamsVoiceAttributes -OrganizationalUnit "OU=Sales,OU=Users,DC=corp,DC=domain,DC=com"

.NOTES
    Author: Satya Pathak (SkypeExchange4U.com)
    Repository: https://github.com/satyamsoft7/TeamsVoice-PowerShell-Toolbox
    Reference: https://skypeexchange4u.com/fixing-teams-onpremlineuri-sync-clearing-msrtcsip-attributes/
#>

function Clear-HybridTeamsVoiceAttributes {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $false, ParameterSetName = "SingleUser")]
        [string]$UserPrincipalName,

        [Parameter(Mandatory = $false, ParameterSetName = "BulkOU")]
        [string]$OrganizationalUnit,

        [Parameter(Mandatory = $false)]
        [switch]$TriggerEntraSync
    )

    Import-Module ActiveDirectory -ErrorAction Stop

    $LogPath = "C:\IT_Logs\TeamsVoice_Attribute_Remediation_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    $RemediationRecords = [System.Collections.Generic.List[PSCustomObject]]::new()

    Write-Host "`n===================================================================" -ForegroundColor Cyan
    Write-Host " Teams Hybrid msRTCSIP Attribute Remediation Utility" -ForegroundColor Cyan
    Write-Host "===================================================================" -ForegroundColor Cyan

    $TargetUsers = @()
    if ($UserPrincipalName) {
        $User = Get-ADUser -Identity $UserPrincipalName -Properties msRTCSIP-Line, msRTCSIP-DeploymentLocator, msRTCSIP-UserEnabled, UserPrincipalName
        if ($User) { $TargetUsers += $User }
    } elseif ($OrganizationalUnit) {
        $TargetUsers = Get-ADUser -Filter * -SearchBase $OrganizationalUnit -Properties msRTCSIP-Line, msRTCSIP-DeploymentLocator, msRTCSIP-UserEnabled, UserPrincipalName
    } else {
        Write-Error "Please specify either -UserPrincipalName or -OrganizationalUnit."
        return
    }

    Write-Host "[*] Evaluating $($TargetUsers.Count) user object(s)..." -ForegroundColor Yellow

    foreach ($Target in $TargetUsers) {
        $HasStaleLine = -not [string]::IsNullOrEmpty($Target."msRTCSIP-Line")
        $HasStaleLocator = -not [string]::IsNullOrEmpty($Target."msRTCSIP-DeploymentLocator")

        if ($HasStaleLine -or $HasStaleLocator) {
            Write-Host "  [-] Found stale hybrid locks for: $($Target.UserPrincipalName)" -ForegroundColor Magenta
            Write-Host "      msRTCSIP-Line               : $($Target.'msRTCSIP-Line')" -ForegroundColor Gray
            Write-Host "      msRTCSIP-DeploymentLocator  : $($Target.'msRTCSIP-DeploymentLocator')" -ForegroundColor Gray

            # Log pre-change state
            $RemediationRecords.Add([PSCustomObject]@{
                Timestamp                 = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                DistinguishedName         = $Target.DistinguishedName
                UserPrincipalName         = $Target.UserPrincipalName
                OriginalLineURI           = $Target."msRTCSIP-Line"
                OriginalDeploymentLocator = $Target."msRTCSIP-DeploymentLocator"
                Remediated                = $true
            })

            if ($PSCmdlet.ShouldProcess($Target.UserPrincipalName, "Clear msRTCSIP-Line and msRTCSIP-DeploymentLocator")) {
                Set-ADUser -Identity $Target.DistinguishedName -Clear "msRTCSIP-Line", "msRTCSIP-DeploymentLocator"
                Write-Host "      [PASS] Successfully cleared on-prem attributes." -ForegroundColor Green
            }
        } else {
            Write-Host "  [✓] $($Target.UserPrincipalName) is clean (no msRTCSIP locks)." -ForegroundColor DarkGray
        }
    }

    # Export Rollback / Audit Log
    if ($RemediationRecords.Count -gt 0) {
        $LogDir = Split-Path $LogPath -Parent
        if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
        $RemediationRecords | Export-Csv -Path $LogPath -NoTypeInformation
        Write-Host "`n[+] Audit log saved to: $LogPath" -ForegroundColor Green
    }

    # Optional Entra Sync
    if ($TriggerEntraSync) {
        Write-Host "`n[*] Triggering Entra Connect Delta Sync..." -ForegroundColor Yellow
        try {
            Invoke-Command -ScriptBlock { Start-ADSyncSyncCycle -PolicyType Delta } -ErrorAction Stop
            Write-Host "  [PASS] Entra Connect Delta Synchronization successfully initiated." -ForegroundColor Green
        } catch {
            Write-Host "  [WARN] Could not trigger Start-ADSyncSyncCycle locally: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }

    Write-Host "===================================================================`n" -ForegroundColor Cyan
}
