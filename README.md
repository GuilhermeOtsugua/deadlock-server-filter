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

Also known (more accurately) as **Deadlock Relay Filter**.

Block Steam relays in the regions you choose, for `deadlock.exe` only. This changes the routes available to the game, not necessarily the match server. It can increase latency or prevent a connection; apply changes before queueing, not during a match.

## Usage

### Block South America

Open Windows PowerShell in the repo folder. `List` and `Preview` are read-only:

```powershell
.\DeadlockRelay.ps1 List
.\DeadlockRelay.ps1 Preview -Region SA
```

**Duration:** The script exits immediately after applying the rules. The rules survive closing PowerShell and restarting Windows. They do not refresh automatically: run `On` again to update them, or `Off` to remove them. From an **administrator PowerShell** in the same folder:

```powershell
.\DeadlockRelay.ps1 On -Region SA
.\DeadlockRelay.ps1 Off              # Undo, even offline
```

### Choose regions

`-Region` means **block**, not “play in.” `List` shows the currently advertised cities under each code: `SA` South America, `NA` North America, `EU` Europe, `AS` Asia excluding the Middle East, `ME` Middle East, `AF` Africa, `OC` Oceania. These are local groupings, not matchmaking regions. Unmapped locations are listed but never selected.

```powershell
.\DeadlockRelay.ps1 On -Region SA,EU  # Block both
.\DeadlockRelay.ps1 On -Region SA     # Replace the selection: EU is no longer blocked
```

For a non-default Steam library, add `-GamePath 'D:\SteamLibrary\steamapps\common\Deadlock\game\bin\win64\deadlock.exe'` to `Preview` or `On`.

### Optional shortcut

From the repo folder, define a shortcut in the shell you intend to use:

```powershell
Set-Alias drf (Resolve-Path .\DeadlockRelay.ps1).Path
drf preview -Region SA
```

`drf` accepts the same commands, does not elevate privileges, and disappears when the shell closes. **The rules do not.** Without the alias, use the full `Off` command above.

### Verify for yourself

Read [the PowerShell firewall configuration script](DeadlockRelay.ps1). It reads [Valve's advertised relays for Deadlock](https://api.steampowered.com/ISteamApps/GetSDRConfig/v1/?appid=1422450), selects endpoint addresses and UDP ports, and uses `New-NetFirewallRule` and `Remove-NetFirewallRule` to manage its own outbound rules. It does not modify game files, read process memory, or install a background service.

`Preview` shows the **proposed** rules. To check what Windows actually has configured, run this read-only query after `On`; after `Off` it should return no rows. It includes rules from the original South America-only version:

```powershell
Get-NetFirewallRule -PolicyStore PersistentStore |
    Where-Object Group -in 'DeadlockRelay-1422450-v2','DeadlockRelay-SA-1422450-v1' |
    Select-Object DisplayName, Enabled, Direction, Action
```

## Distribution

PowerShell is the current implementation. A future standalone version in Rust or another language could simplify distribution; it is not required for in-game performance.
