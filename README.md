# TeamsVoice-PowerShell-Toolbox
> Production-tested PowerShell automation scripts and diagnostic utilities for Microsoft Teams Phone, Direct Routing SBCs, and Entra ID Hybrid Voice infrastructure.

Maintained by **Satya Pathak** & the engineering team at [SkypeExchange4U.com](https://skypeexchange4u.com/).

---

## 🛠 Included Utilities

### 1. `Deploy-TeamsSharedCalling.ps1`
Automates the end-to-end provisioning of **Microsoft Teams Shared Calling**, enabling outbound PSTN calling for front-line and shift workers without assigning dedicated DIDs or individual calling plan licenses.
* Automatically creates cloud Resource Account endpoints.
* Provisions dedicated E911 Emergency Resource Accounts for **Kari's Law & Ray Baum's Act** compliance.
* Links primary outbound DIDs and assigns group-based `TeamsSharedCallingPolicy`.
* **Full Runbook:** [Microsoft Teams Shared Calling Setup Runbook](https://skypeexchange4u.com/microsoft-teams-shared-calling-setup-runbook/)

### 2. `Test-AudioCodesTlsHandshake.ps1`
A diagnostic utility to troubleshoot TLS certificate handshake failures (`TLS Alert 48: Unknown CA`, `TLS Alert 40: Handshake Failure`) between customer Session Border Controllers (AudioCodes Mediant) and Microsoft Teams Direct Routing SIP Proxies (`sip.pstnhub.microsoft.com:5061`).
* Validates TCP socket connectivity on port 5061.
* Inspects remote certificate SANs and Common Names against Microsoft FQDN standards.
* Verifies DigiCert Global Root G2 and intermediate CA chain presentation.
* Checks for NTP hardware clock drift (>5 min threshold).
* **Full Runbook:** [AudioCodes Mediant SBC TLS Handshake Failure Fix](https://skypeexchange4u.com/audiocodes-sbc-tls-handshake-failure-microsoft-teams/)

### 3. `Audit-TeamsVoiceRoutes.ps1`
Audits tenant voice routing policies, PSTN usage records, SBC gateway registration health, and Local Media Optimization (LMO) settings.
* Evaluates active SBC OPTIONS ping latency and status across `sip.pstnhub.microsoft.com`, `sip2`, and `sip3`.
* Maps Voice Routing Policies to Online PSTN Gateways and validates regex dial strings.
* Identifies orphaned voice routes and unlicensed users.
* **Full Runbook:** [Teams Voice Routing Policy Explained](https://skypeexchange4u.com/teams-voice-routing-policy-explained/)

### 4. `Test-TeamsSharedCallingReadiness.ps1`
A rapid pre-flight diagnostic script to troubleshoot **Teams Shared Calling outbound call drops, silent drops, and SIP 403 Forbidden errors**.
* Audits `EnterpriseVoiceEnabled` status on shared users without DIDs.
* Flags `OnlineVoiceRoutingPolicy` conflicts (detects active PSTN Usages that break Shared Calling delegation).
* Verifies `TeamsSharedCallingPolicy` and backing Resource Account bindings.
* **Full Troubleshooting Guide:** [Teams Shared Calling Outbound Calls Dropping Fix](https://skypeexchange4u.com/teams-shared-calling-outbound-calls-dropping-fix/)

---

## 🚀 Quick Start

### Prerequisites
* Windows PowerShell 5.1 or PowerShell 7+
* `MicrosoftTeams` PowerShell module (version 5.5.0 or newer)
* Teams Administrator or Global Administrator privileges

```powershell
# Install required module
Install-Module -Name MicrosoftTeams -Force -AllowClobber

# Connect to tenant
Connect-MicrosoftTeams
```

### Running Shared Calling Deployment
```powershell
.\Deploy-TeamsSharedCalling.ps1 `
  -ResourceUPN "ra-sharedcalling-chicago@contoso.com" `
  -ResourceDisplayName "Chicago Branch Shared Calling Trunk" `
  -PrimaryPhoneNumber "+13125550150" `
  -EmergencyUPN "ra-e911-chicago@contoso.com" `
  -EmergencyPhoneNumber "+13125550159" `
  -PolicyName "Chicago_Branch_SharedCalling"
```

### Running SBC TLS Diagnostic
```powershell
.\Test-AudioCodesTlsHandshake.ps1 `
  -SbcFqdn "sbc.contoso.com" `
  -Port 5061
```

---

## 📚 Technical Documentation & Runbooks
For complete architecture diagrams, SIP ladder call flows, Wireshark traces, and troubleshooting guides, visit:
* [SkypeExchange4U.com](https://skypeexchange4u.com/)
* [Teams Direct Routing Local Media Optimization (LMO) Guide](https://skypeexchange4u.com/teams-direct-routing-local-media-optimization-lmo-guide/)
* [AudioCodes Mediant CE in Azure Direct Routing Setup](https://skypeexchange4u.com/audiocodes-mediant-ce-azure-teams-direct-routing-setup-guide/)
* [Entra ID CBA for Teams Phones & SIP Gateway](https://skypeexchange4u.com/microsoft-entra-id-cba-teams-phones-sip-gateway-guide/)

---

## 📄 License
MIT License. Free for enterprise deployment and community adaptation.
