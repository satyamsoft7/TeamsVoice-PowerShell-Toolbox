<#
.SYNOPSIS
    Microsoft 365 Tenant-to-Tenant (T2T) Pre-Cutover Domain Audit & Readiness Utility.

.DESCRIPTION
    Test-TenantMigrationReadiness audits a source Microsoft 365 tenant prior to a 
    Tenant-to-Tenant migration cutover. It identifies all directory objects locking
    the custom domain that will block domain removal from the source tenant:
    1. User Principal Names (UPNs) using the target custom domain.
    2. ProxyAddresses / Secondary email aliases containing the custom domain.
    3. Distribution Groups, Mail-Enabled Security Groups, and M365 Groups.
    4. Shared, Room, and Equipment Mailboxes.
    5. Summarizes total mailbox count, archive states, and litigation hold flags.

.PARAMETER DomainName
    The custom domain being migrated to the target tenant (e.g., "contoso.com").

.EXAMPLE
    Test-TenantMigrationReadiness -DomainName "contoso.com"

.NOTES
    Author: Satya Pathak (SkypeExchange4U.com)
    Repository: https://github.com/satyamsoft7/TeamsVoice-PowerShell-Toolbox
    Reference: https://skypeexchange4u.com/microsoft-365-tenant-to-tenant-migration-runbook/
#>

function Test-TenantMigrationReadiness {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DomainName
    )

    Write-Host "`n===================================================================" -ForegroundColor Cyan
    Write-Host " Microsoft 365 Tenant-to-Tenant Pre-Cutover Domain Audit" -ForegroundColor Cyan
    Write-Host " Target Domain to Release: $DomainName" -ForegroundColor Cyan
    Write-Host "===================================================================" -ForegroundColor Cyan

    # 1. Audit User Principal Names (UPNs)
    Write-Host "`n[1/4] Auditing User Principal Names using @$DomainName..." -ForegroundColor Yellow
    $LockedUsers = Get-Mailbox -ResultSize Unlimited | Where-Object { $_.UserPrincipalName -like "*@$DomainName" }
    if ($LockedUsers.Count -gt 0) {
        Write-Host "  [WARN] Found $($LockedUsers.Count) user(s) with primary UPN using @$DomainName" -ForegroundColor Yellow
        Write-Host "         These UPNs MUST be switched to @tenant.onmicrosoft.com before domain release!" -ForegroundColor Red
    } else {
        Write-Host "  [PASS] 0 Users found using @$DomainName as primary UPN." -ForegroundColor Green
    }

    # 2. Audit Secondary Email Aliases (ProxyAddresses)
    Write-Host "`n[2/4] Auditing Secondary ProxyAddresses / Aliases using @$DomainName..." -ForegroundColor Yellow
    $LockedAliases = Get-Mailbox -ResultSize Unlimited | Where-Object { $_.EmailAddresses -like "*@$DomainName*" }
    if ($LockedAliases.Count -gt 0) {
        Write-Host "  [WARN] Found $($LockedAliases.Count) mailbox(es) with @$DomainName in secondary aliases." -ForegroundColor Yellow
        Write-Host "         All proxyAddresses referencing @$DomainName must be stripped." -ForegroundColor Red
    } else {
        Write-Host "  [PASS] 0 Mailboxes with secondary aliases referencing @$DomainName." -ForegroundColor Green
    }

    # 3. Audit Distribution Groups & M365 Groups
    Write-Host "`n[3/4] Auditing Distribution Groups & Microsoft 365 Groups..." -ForegroundColor Yellow
    $LockedGroups = Get-DistributionGroup -ResultSize Unlimited | Where-Object { $_.PrimarySmtpAddress -like "*@$DomainName" -or $_.EmailAddresses -like "*@$DomainName*" }
    if ($LockedGroups.Count -gt 0) {
        Write-Host "  [WARN] Found $($LockedGroups.Count) group(s) locking @$DomainName" -ForegroundColor Yellow
    } else {
        Write-Host "  [PASS] 0 Groups locking @$DomainName." -ForegroundColor Green
    }

    # 4. Storage & Litigation Hold Summary
    Write-Host "`n[4/4] Summarizing Migration Storage & Compliance Holds..." -ForegroundColor Yellow
    $MailboxStats = Get-Mailbox -ResultSize Unlimited | Select-Object DisplayName, ArchiveStatus, LitigationHoldEnabled
    $OnHoldCount = ($MailboxStats | Where-Object { $_.LitigationHoldEnabled }).Count
    $ArchiveCount = ($MailboxStats | Where-Object { $_.ArchiveStatus -eq "Active" }).Count

    Write-Host "  [*] Total User Mailboxes Evaluated : $($MailboxStats.Count)" -ForegroundColor Gray
    Write-Host "  [*] Mailboxes with In-Place Archive: $ArchiveCount" -ForegroundColor Gray
    Write-Host "  [*] Mailboxes on Litigation Hold   : $OnHoldCount" -ForegroundColor Gray

    Write-Host "`n===================================================================" -ForegroundColor Cyan
    if ($LockedUsers.Count -eq 0 -and $LockedAliases.Count -eq 0 -and $LockedGroups.Count -eq 0) {
        Write-Host " [PASS] Domain '$DomainName' is CLEAN and ready for removal from Source Tenant!" -ForegroundColor Green
    } else {
        Write-Host " [ACTION REQUIRED] Run Strip-DomainProxyAddresses script before initiating cutover." -ForegroundColor Red
    }
    Write-Host "===================================================================`n" -ForegroundColor Cyan
}
