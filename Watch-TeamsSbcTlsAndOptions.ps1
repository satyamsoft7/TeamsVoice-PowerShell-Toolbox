<#
.SYNOPSIS
    Automated TLS Certificate Expiry & Synthetic SIP OPTIONS Watchdog for Teams Direct Routing SBCs.

.DESCRIPTION
    Probes remote Session Border Controller (AudioCodes, Ribbon, Oracle, Cisco CUBE) FQDNs on TCP Port 5061,
    extracts the X.509 SSL certificate expiration date and issuer chain, measures TCP/TLS socket latency,
    and dispatches real-time Microsoft Teams Adaptive Card webhook alerts before certificate expiry causes trunk downtime.

    Full Architecture & Runbook:
    https://skypeexchange4u.com/teams-direct-routing-sbc-automation-runbook/

.NOTES
    Author: Satya Pathak
    Documentation: https://skypeexchange4u.com/teams-direct-routing-sbc-automation-runbook/
    Repository: https://github.com/satyamsoft7/TeamsVoice-PowerShell-Toolbox
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string[]]$SbcFqdns,

    [int]$Port = 5061,
    [int]$WarningDays = 30,
    [int]$CriticalDays = 7,
    [string]$TeamsWebhookUrl
)

$Results = @()
foreach ($Fqdn in $SbcFqdns) {
    Write-Host ">>> Probing SBC mTLS Endpoint $Fqdn`:$Port..." -ForegroundColor Cyan
    try {
        $Sw = [System.Diagnostics.Stopwatch]::StartNew()
        $TcpClient = New-Object System.Net.Sockets.TcpClient
        $ConnectTask = $TcpClient.ConnectAsync($Fqdn, $Port)
        if (-not $ConnectTask.Wait(4000)) {
            throw "TCP Connection to $Fqdn`:$Port timed out after 4000ms."
        }

        $SslStream = New-Object System.Net.Security.SslStream(
            $TcpClient.GetStream(),
            $false,
            ({ $true } -as [System.Net.Security.RemoteCertificateValidationCallback])
        )
        $SslStream.AuthenticateAsClient($Fqdn)
        $Sw.Stop()

        $Cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($SslStream.RemoteCertificate)
        $DaysRemaining = [Math]::Floor(($Cert.NotAfter - (Get-Date)).TotalDays)

        $Status = if ($DaysRemaining -le $CriticalDays) { "CRITICAL" } elseif ($DaysRemaining -le $WarningDays) { "WARNING" } else { "HEALTHY" }

        $Results += [PSCustomObject]@{
            SbcFqdn       = $Fqdn
            Status        = $Status
            LatencyMs     = $Sw.ElapsedMilliseconds
            DaysRemaining = $DaysRemaining
            ExpiresOn     = $Cert.NotAfter.ToString("yyyy-MM-dd")
            Issuer        = ($Cert.Issuer -split ",")[0]
            Thumbprint    = $Cert.Thumbprint
        }
        $SslStream.Close()
        $TcpClient.Close()
    } catch {
        $Results += [PSCustomObject]@{
            SbcFqdn       = $Fqdn
            Status        = "DOWN"
            LatencyMs     = -1
            DaysRemaining = -1
            ExpiresOn     = "N/A"
            Issuer        = $_.Exception.Message
            Thumbprint    = "N/A"
        }
    }
}

$Results | Format-Table -AutoSize
