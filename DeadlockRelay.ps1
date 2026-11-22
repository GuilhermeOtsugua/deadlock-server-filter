#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('List','Preview','On','Off')][string]$Mode = 'List',
    [string[]]$Region,
    [string]$GamePath = "${env:ProgramFiles(x86)}\Steam\steamapps\common\Deadlock\game\bin\win64\deadlock.exe"
)
$ErrorActionPreference = 'Stop'
$group = 'DeadlockRelay-1422450-v2'
$legacy = 'DeadlockRelay-SA-1422450-v1'
$regions = [ordered]@{
    SA = 'eze gru lim scl'; NA = 'atl dfw iad lax ord sea'; EU = 'ams fra lhr mad par sto sto2 vie waw dfra dvie dlhr'
    AS = 'bom2 maa2 hkg seo sgp tyo'; ME = 'dxb dfjr'; AF = 'jnb'; OC = 'gum syd'
}
$plan = @{}
if ($Mode -in 'On','Preview' -and !$Region) { throw "Usage: $Mode -Region SA (or SA,EU). Use List to see regions." }
if ($Mode -in 'Off','List' -and $Region) { throw "$Mode does not take -Region." }
foreach ($code in $Region) { if (!$regions.Contains($code)) { throw "Unknown region '$code'. Use List." } }
if ($Mode -ne 'Off') {
    $config = Invoke-RestMethod -Uri 'https://api.steampowered.com/ISteamApps/GetSDRConfig/v1/?appid=1422450' -TimeoutSec 20
    if (!$config.revision -or !$config.pops) { throw 'Unrecognized Valve config.' }
    $live = @($config.pops.psobject.Properties | Where-Object { $_.Value.relays })
    if (!$live.Count) { throw 'No advertised relays.' }
    $cities = @{}
    foreach ($code in $regions.Keys) {
        $cities[$code] = @($live | Where-Object { $_.Name -in ($regions[$code] -split ' ') })
        if ($Mode -eq 'List') {
            $labels = @($cities[$code] | ForEach-Object { "$($_.Value.desc) [$($_.Name)]" })
            if (!$labels) { $labels = '(none advertised)' }; Write-Output "${code}: $($labels -join ', ')"
        }
        if ($code -in $Region -and !$cities[$code].Count) { throw "No live endpoints for $code; selection unchanged." }
    }
    $unknown = @($live.Name | Where-Object { $_ -notin (($regions.Values -join ' ') -split ' ') })
    if ($unknown) { Write-Warning "Unmapped (not selected): $($unknown -join ', ')" }
    if ($Mode -eq 'List') { return }
    $exe = Get-Item -LiteralPath $GamePath
    if ($exe.PSIsContainer -or $exe.Name -ne 'deadlock.exe') { throw 'Expected the installed deadlock.exe (-GamePath).' }
    $selected = @($Region | ForEach-Object { $cities[$_] } | ForEach-Object { $_.Name })
    $spared = @{}
    foreach ($pop in $live) {
        foreach ($r in $pop.Value.relays) {
            $ports = @($r.port_range)
            if ($ports.Count -ne 2 -or $ports[0] -notmatch '^\d{1,5}$' -or $ports[1] -notmatch '^\d{1,5}$' -or [int]$ports[0] -lt 1 -or [int]$ports[1] -gt 65535 -or [int]$ports[1] -lt [int]$ports[0]) { throw "Invalid ports for $($pop.Name)" }
            $range = if ($ports[0] -eq $ports[1]) { "$($ports[0])" } else { $ports -join '-' }
            $addresses = @($r.ipv4,$r.ipv6 | Where-Object { $_ })
            if (!$addresses.Count) { throw "Missing address for $($pop.Name)" }
            foreach ($addr in $addresses) {
                $ip = [ipaddress]::Parse($addr)
                if ($ip.ToString() -in '::','0.0.0.0' -or [ipaddress]::IsLoopback($ip)) { throw "Invalid relay: $addr" }
                if ($pop.Name -notin $selected) { $spared[$ip.ToString()] = $true; continue }
                $key = "$($exe.FullName.ToLowerInvariant())|$ip|$range"
                $sha = [Security.Cryptography.SHA256]::Create()
                try { $id = [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($key))).Replace('-','') } finally { $sha.Dispose() }
                $plan["$group-$id"] = @{ DisplayName="Deadlock relay: $($pop.Name) $ip UDP $range"; Program=$exe.FullName; RemoteAddress=$ip.ToString(); RemotePort=$range }
            }
        }
    }
    if (!$spared.Count) { throw 'Refusing to block all advertised relays.' }
    foreach ($item in $plan.Values) { if ($spared.ContainsKey($item.RemoteAddress)) { throw 'Shared relay address across selected and unselected locations; refusing ambiguous filter.' } }
    Write-Output "Program: $($exe.FullName)"
    $plan.Values | ForEach-Object { $_.DisplayName } | Sort-Object
    if ($Mode -eq 'Preview') { return }
}
# Windows enforces elevation for the firewall writes. No automatic elevation.
$old = @(Get-NetFirewallRule -PolicyStore PersistentStore | Where-Object { $_.Group -in $group,$legacy -and $_.Name -match ('^' + [regex]::Escape($_.Group) + '-[0-9A-F]{64}$') })
$stale = @($old | Where-Object { !$plan.ContainsKey($_.Name) })
$backup = @{}
foreach ($rule in $stale) {
    $backup[$rule.Name] = @{ Group=$rule.Group; DisplayName=$rule.DisplayName; Program=($rule | Get-NetFirewallApplicationFilter).Program; RemoteAddress=($rule | Get-NetFirewallAddressFilter).RemoteAddress; RemotePort=($rule | Get-NetFirewallPortFilter).RemotePort; Enabled=$rule.Enabled }
}
$created = @()
$removed = @()
try {
    foreach ($name in $plan.Keys) {
        if ($old.Name -contains $name) { continue }
        $spec = $plan[$name]
        New-NetFirewallRule @spec -Name $name -Group $group -PolicyStore PersistentStore -Direction Outbound -Protocol UDP -Action Block -Profile Any -Enabled True | Out-Null
        $created += $name
    }
    foreach ($rule in $stale) {
        Remove-NetFirewallRule -PolicyStore PersistentStore -Name $rule.Name
        $removed += $rule.Name
    }
} catch {
    # Best-effort rollback if a Windows Firewall operation fails mid-change.
    foreach ($name in $removed) {
        $spec = $backup[$name]
        New-NetFirewallRule @spec -Name $name -PolicyStore PersistentStore -Direction Outbound -Protocol UDP -Action Block -Profile Any -ErrorAction Continue | Out-Null
    }
    foreach ($name in $created) { Remove-NetFirewallRule -PolicyStore PersistentStore -Name $name -ErrorAction Continue }
    throw
}
Write-Output "Done: $($plan.Count) managed relay rules."
