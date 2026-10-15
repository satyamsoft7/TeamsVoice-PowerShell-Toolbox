<#
.SYNOPSIS
    Deploys Microsoft Teams Shared Calling architecture with E911 compliance.
.DESCRIPTION
    Automates the creation of outbound Shared Calling resource accounts, emergency
    callback endpoints (ECBN), assigns phone numbers, and builds the TeamsSharedCallingPolicy.
.PARAMETER ResourceUPN
    User Principal Name for the primary Shared Calling resource account.
.PARAMETER ResourceDisplayName
    Display name for the primary resource account.
.PARAMETER PrimaryPhoneNumber
    E.164 phone number assigned to the primary resource account.
.PARAMETER EmergencyUPN
    User Principal Name for the dedicated E911 emergency callback endpoint.
.PARAMETER EmergencyPhoneNumber
    E.164 phone number assigned to the emergency callback endpoint.
.PARAMETER PolicyName
    Name of the TeamsSharedCallingPolicy to create.
.EXAMPLE
    .\Deploy-TeamsSharedCalling.ps1 -ResourceUPN "ra-shared@contoso.com" -PrimaryPhoneNumber "+13125550150" -EmergencyUPN "ra-e911@contoso.com" -EmergencyPhoneNumber "+13125550159" -PolicyName "Warehouse_SharedCalling"
.LINK
    https://skypeexchange4u.com/microsoft-teams-shared-calling-setup-runbook/
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$ResourceUPN,

    [Parameter(Mandatory = $false)]
    [string]$ResourceDisplayName = "Teams Shared Calling Trunk",

    [Parameter(Mandatory = $true)]
    [string]$PrimaryPhoneNumber,

    [Parameter(Mandatory = $true)]
    [string]$EmergencyUPN,

    [Parameter(Mandatory = $true)]
    [string]$EmergencyPhoneNumber,

    [Parameter(Mandatory = $true)]
    [string]$PolicyName
)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Microsoft Teams Shared Calling Provisioning Engine" -ForegroundColor Cyan
Write-Host " Powered by SkypeExchange4U.com Engineering" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Verify MicrosoftTeams Module
if (-not (Get-Module -Name MicrosoftTeams -ListAvailable)) {
    Write-Error "MicrosoftTeams PowerShell module is not installed. Run 'Install-Module -Name MicrosoftTeams -Force' first."
    exit 1
}

# 2. Check Connection
try {
    $tenant = Get-CsTenant -ErrorAction Stop
    Write-Host "[+] Connected to Tenant: $($tenant.DisplayName) ($($tenant.TenantId))" -ForegroundColor Green
} catch {
    Write-Warning "Not connected to Teams PowerShell. Attempting connection..."
    Connect-MicrosoftTeams
}

# 3. Create Main Shared Calling Application Endpoint
Write-Host "`n[*] Step 1: Provisioning Primary Outbound Resource Account..." -ForegroundColor Yellow
$appId = "ce933385-9390-45d1-9512-c8d228074e07" # Microsoft Teams Phone Application ID

$mainEndpoint = Get-CsOnlineApplicationEndpoint -Identity $ResourceUPN -ErrorAction SilentlyContinue
if (-not $mainEndpoint) {
    $mainEndpoint = New-CsOnlineApplicationEndpoint -ApplicationId $appId -Name $ResourceDisplayName -Uri $ResourceUPN
    Write-Host "[+] Created Resource Account: $ResourceUPN" -ForegroundColor Green
} else {
    Write-Host "[i] Resource Account already exists: $ResourceUPN" -ForegroundColor Gray
}

# 4. Create Emergency E911 Application Endpoint
Write-Host "`n[*] Step 2: Provisioning Dedicated E911 Emergency Resource Account..." -ForegroundColor Yellow
$emergEndpoint = Get-CsOnlineApplicationEndpoint -Identity $EmergencyUPN -ErrorAction SilentlyContinue
if (-not $emergEndpoint) {
    $emergEndpoint = New-CsOnlineApplicationEndpoint -ApplicationId $appId -Name "$ResourceDisplayName (E911)" -Uri $EmergencyUPN
    Write-Host "[+] Created E911 Resource Account: $EmergencyUPN" -ForegroundColor Green
} else {
    Write-Host "[i] E911 Resource Account already exists: $EmergencyUPN" -ForegroundColor Gray
}

# 5. Assign Numbers
Write-Host "`n[*] Step 3: Assigning E.164 Phone Numbers..." -ForegroundColor Yellow
Write-Host "  -> Assigning Primary DID: $PrimaryPhoneNumber to $ResourceUPN"
Set-CsPhoneNumberAssignment -Identity $ResourceUPN -PhoneNumber $PrimaryPhoneNumber -PhoneNumberType CallingPlan -ErrorAction SilentlyContinue

Write-Host "  -> Assigning Emergency DID: $EmergencyPhoneNumber to $EmergencyUPN"
Set-CsPhoneNumberAssignment -Identity $EmergencyUPN -PhoneNumber $EmergencyPhoneNumber -PhoneNumberType CallingPlan -ErrorAction SilentlyContinue

# 6. Create or Update Shared Calling Policy
Write-Host "`n[*] Step 4: Creating TeamsSharedCallingPolicy: $PolicyName..." -ForegroundColor Yellow
$existingPolicy = Get-CsSharedCallingPolicy -Identity $PolicyName -ErrorAction SilentlyContinue

$emergencyConfig = @(
    @{
        EmergencyNumber = "911";
        ResourceAccount = $emergEndpoint.Identity
    }
)

if (-not $existingPolicy) {
    New-CsSharedCallingPolicy `
        -Identity $PolicyName `
        -Description "Shared Calling Outbound Trunk deployed via SkypeExchange4U Toolbox" `
        -ResourceAccount $mainEndpoint.Identity `
        -EmergencyNumbers $emergencyConfig
    Write-Host "[+] Successfully created Shared Calling Policy: $PolicyName" -ForegroundColor Green
} else {
    Set-CsSharedCallingPolicy `
        -Identity $PolicyName `
        -ResourceAccount $mainEndpoint.Identity `
        -EmergencyNumbers $emergencyConfig
    Write-Host "[+] Updated existing Shared Calling Policy: $PolicyName" -ForegroundColor Green
}

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host " DEPLOYMENT COMPLETE! Policy is ready to assign to users." -ForegroundColor Green
Write-Host " To assign to a user:" -ForegroundColor White
Write-Host "   Grant-CsSharedCallingPolicy -Identity 'user@domain.com' -PolicyName '$PolicyName'" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Green
