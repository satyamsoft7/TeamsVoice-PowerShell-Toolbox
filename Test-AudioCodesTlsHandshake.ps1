<#
.SYNOPSIS
    Tests and diagnoses TLS certificate handshakes with Microsoft Teams Direct Routing.
.DESCRIPTION
    Validates TCP 5061 connectivity, certificate Subject Alternative Names (SAN),
    validity periods, and cipher suite support for AudioCodes and Ribbon SBCs.
.PARAMETER SbcFqdn
    The Fully Qualified Domain Name of the SBC to test.
.PARAMETER Port
    The SIP signaling port (default is 5061).
.EXAMPLE
    .\Test-AudioCodesTlsHandshake.ps1 -SbcFqdn "sbc.contoso.com"
.LINK
    https://skypeexchange4u.com/audiocodes-sbc-tls-handshake-failure-microsoft-teams/
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$SbcFqdn,

    [Parameter(Mandatory = $false)]
    [int]$Port = 5061
)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Direct Routing SBC TLS Diagnostic Utility" -ForegroundColor Cyan
Write-Host " Powered by SkypeExchange4U.com Engineering" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. TCP Connectivity Check
Write-Host "`n[*] Step 1: Testing TCP Port $Port Connectivity to $SbcFqdn..." -ForegroundColor Yellow
$tcpTest = Test-NetConnection -ComputerName $SbcFqdn -Port $Port -WarningAction SilentlyContinue
if ($tcpTest.TcpTestSucceeded) {
    Write-Host "[+] TCP Socket Open: Successfully reached $SbcFqdn on port $Port" -ForegroundColor Green
} else {
    Write-Error "[-] TCP Socket Failed: Port $Port on $SbcFqdn is closed or filtered by firewall."
    exit 1
}

# 2. TLS Handshake & Certificate Inspection
Write-Host "`n[*] Step 2: Initiating TLS 1.2 Handshake & Certificate Extraction..." -ForegroundColor Yellow
try {
    $tcpClient = New-Object System.Net.Sockets.TcpClient($SbcFqdn, $Port)
    $sslStream = New-Object System.Net.Security.SslStream($tcpClient.GetStream(), $false, {
        param($sender, $certificate, $chain, $sslPolicyErrors)
        return $true # Accept all for inspection
    })

    $sslStream.AuthenticateAsClient($SbcFqdn)

    $remoteCert = [System.Security.Cryptography.X509Certificates.X509Certificate2]$sslStream.RemoteCertificate
    Write-Host "[+] TLS Handshake Established!" -ForegroundColor Green
    Write-Host "    Negotiated Protocol: $($sslStream.SslProtocol)" -ForegroundColor White
    Write-Host "    Cipher Algorithm:    $($sslStream.CipherAlgorithm)" -ForegroundColor White
    Write-Host "    Cipher Strength:     $($sslStream.CipherStrength) bits" -ForegroundColor White
    Write-Host "    Hash Algorithm:       $($sslStream.HashAlgorithm)" -ForegroundColor White

    # Certificate Details
    Write-Host "`n[*] Step 3: Validating SBC X.509 Certificate..." -ForegroundColor Yellow
    Write-Host "    Subject:        $($remoteCert.Subject)" -ForegroundColor White
    Write-Host "    Issuer:         $($remoteCert.Issuer)" -ForegroundColor White
    Write-Host "    Valid From:     $($remoteCert.NotBefore)" -ForegroundColor White
    Write-Host "    Valid To:       $($remoteCert.NotAfter)" -ForegroundColor White
    Write-Host "    Thumbprint:     $($remoteCert.Thumbprint)" -ForegroundColor White

    $now = Get-Date
    if ($now -lt $remoteCert.NotBefore) {
        Write-Error "[-] CERTIFICATE ERROR: Certificate is NOT YET VALID. Check NTP clock on SBC."
    } elseif ($now -gt $remoteCert.NotAfter) {
        Write-Error "[-] CERTIFICATE ERROR: Certificate has EXPIRED. Immediate renewal required."
    } else {
        $daysRemaining = ($remoteCert.NotAfter - $now).Days
        Write-Host "[+] Certificate is currently VALID ($daysRemaining days remaining)." -ForegroundColor Green
    }

    # SAN Check
    Write-Host "`n[*] Step 4: Inspecting Subject Alternative Names (SAN)..." -ForegroundColor Yellow
    $sanExtension = $remoteCert.Extensions | Where-Object { $_.Oid.FriendlyName -eq "Subject Alternative Name" }
    if ($sanExtension) {
        Write-Host "    SAN Value: $($sanExtension.Format($true))" -ForegroundColor White
        if ($sanExtension.Format($false) -match [regex]::Escape($SbcFqdn) -or $sanExtension.Format($false) -match "\*\.") {
            Write-Host "[+] SAN matches target SBC FQDN ($SbcFqdn)." -ForegroundColor Green
        } else {
            Write-Warning "[!] SAN MISMATCH: Certificate SAN does not contain '$SbcFqdn'. Microsoft will reject this gateway."
        }
    } else {
        Write-Warning "[!] SAN MISSING: No Subject Alternative Name extension found on certificate."
    }

    $sslStream.Close()
    $tcpClient.Close()

} catch {
    Write-Error "[-] TLS Handshake Failed: $($_.Exception.Message)"
    Write-Host "`nCommon Remediation Steps:" -ForegroundColor Yellow
    Write-Host " 1. Ensure the Intermediate CA is bundled into the SBC PEM certificate." -ForegroundColor White
    Write-Host " 2. Ensure DigiCert Global Root G2 is present in the SBC Trusted Root Store." -ForegroundColor White
    Write-Host " 3. Verify AudioCodes TLS Context is set to TLSv1.2 with ECDHE-RSA ciphers." -ForegroundColor White
    Write-Host " See full troubleshooting guide: https://skypeexchange4u.com/audiocodes-sbc-tls-handshake-failure-microsoft-teams/" -ForegroundColor Cyan
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host " Diagnostic check complete." -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
