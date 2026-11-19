# deadlock-relay-filter

A Windows PowerShell script that blocks Deadlock's outbound UDP traffic to known South American Steam relays. It uses Windows Firewall and exits; there is no background service. Blocking relays changes the available routes, not necessarily the match server.

```powershell
.\DeadlockRelay.ps1 Preview  # List endpoints without making changes
.\DeadlockRelay.ps1 On       # Administrator: apply or refresh rules before queueing
.\DeadlockRelay.ps1 Off      # Administrator: remove managed rules, even offline
```

Preview and On fetch Valve's relay list for app 1422450 and select the advertised endpoints for São Paulo, Buenos Aires, Santiago, and Lima. For a non-default Steam library, pass `-GamePath` with the full path to `deadlock.exe`.

## Distribution

PowerShell is the current implementation. A future standalone version in Rust or another language could simplify distribution; it is not required for in-game performance.
