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

Deadlock doesn’t currently have a server picker for public matchmaking, so I made this. Also known (more accurately) as **Deadlock Relay Filter**.

Block Steam relays by region for `deadlock.exe` only. When relay availability determines placement, this does not guarantee a *particular* match server, but lets you consistently match in remaining regions of your choice.

## How it works

1. **You choose which regions to block.** For example, if you pick South America, the script looks up the addresses Valve lists for Deadlock in that region.
2. **Windows applies the block.** The script adds firewall rules that stop Deadlock from sending game traffic to those addresses. Other games and apps can still use them.
3. **Deadlock can still connect through the remaining regions.** The filter changes which connections are available; Valve still chooses the match server. The script exits, and the rules stay in place until you change or remove them.

## Quick start

Open PowerShell in the folder containing the script. To see which South American relays would be blocked, run:

```powershell
.\DeadlockRelayFilter.ps1 preview -Region SA
```

The preview shows the game executable, relay addresses, and UDP ports without changing the firewall. To see all available region codes and cities:

```powershell
.\DeadlockRelayFilter.ps1 list
```

### Apply, change, or undo a block

For `on` and `off`, open PowerShell **as administrator** in the same folder.

**Block South America:**

```powershell
.\DeadlockRelayFilter.ps1 on -Region SA
```

**Block South America and Europe:** Each selection replaces the previous one. To unblock Europe later, run the South America example again.

```powershell
.\DeadlockRelayFilter.ps1 on -Region SA,EU
```

**Remove all of this tool’s blocks:** This works offline.

```powershell
.\DeadlockRelayFilter.ps1 off
```

The script exits after applying the rules. The block survives closing PowerShell and restarting Windows. Run `on` again with your regions to refresh the endpoints, or `off` to undo.

## Options

- **`-Region`** — The regions to **block**, not the regions you want to play in. Required for `preview` and `on`. Use one code (`SA`) or a comma-separated list (`SA,EU`).
- **`-GamePath`** — Use this option if you installed Deadlock in a different Steam library. For example:

  ```powershell
  .\DeadlockRelayFilter.ps1 preview -Region SA -GamePath 'D:\SteamLibrary\steamapps\common\Deadlock\game\bin\win64\deadlock.exe'
  ```

| Code | Relay region |
| --- | --- |
| `SA` | South America |
| `NA` | North America |
| `EU` | Europe |
| `AS` | Asia, excluding the Middle East |
| `ME` | Middle East |
| `AF` | Africa |
| `OC` | Oceania |

These are the tool’s geographic groupings, not matchmaking regions. Unmapped locations are reported and left unblocked. Filtering can increase latency or prevent a connection; avoid changing rules during a match.

## Verify for yourself

- **Inspect the implementation:** [DeadlockRelayFilter.ps1](DeadlockRelayFilter.ps1) reads [Valve’s relay list for Deadlock](https://api.steampowered.com/ISteamApps/GetSDRConfig/v1/?appid=1422450) and manages outbound UDP rules in Windows Firewall. It does not modify game files, read process memory, or install a background service.
- **Inspect the result:** `preview` shows the proposed rules. The read-only query below shows the rules actually configured in Windows. After `off`, it should return no rows.

```powershell
Get-NetFirewallRule -PolicyStore PersistentStore |
    Where-Object Group -in 'DeadlockRelay-1422450-v2','DeadlockRelay-SA-1422450-v1' |
    Select-Object DisplayName, Enabled, Direction, Action
```

## License

Deadlock Server Filter is licensed under the [GNU Affero General Public License v3.0 only](LICENSE) (`AGPL-3.0-only`).
