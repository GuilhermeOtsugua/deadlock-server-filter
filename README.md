<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/logo-light.svg">
    <img src="assets/logo-dark.svg" width="480" alt="Deadlock Server Filter">
  </picture>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-Windows-0078D4" alt="Platform: Windows">
  <img src="https://img.shields.io/badge/PowerShell-5.1%2B-245780" alt="PowerShell 5.1+">
  <img src="https://img.shields.io/badge/filter-Windows_Firewall-0f766e" alt="Filter: Windows Firewall">
</p>

# Deadlock Server Filter

Block known South American Steam relays for Deadlock without running a background process. The script adds outbound UDP rules for `deadlock.exe` and exits. This changes the routes Deadlock can use; it does not guarantee a US match server.

## Usage

```powershell
.\DeadlockRelay.ps1 Preview  # List endpoints without making changes
.\DeadlockRelay.ps1 On       # Administrator: apply or refresh rules before queueing
.\DeadlockRelay.ps1 Off      # Administrator: remove managed rules, even offline
```

Preview and On fetch Valve's relay list for app 1422450 and select the advertised endpoints for São Paulo, Buenos Aires, Santiago, and Lima. For a non-default Steam library, pass `-GamePath` with the full path to `deadlock.exe`.

## Distribution

PowerShell is the current implementation. A future standalone version in Rust or another language could simplify distribution; it is not required for in-game performance.
