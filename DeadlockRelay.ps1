#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('Preview','On','Off')][string]$Mode = 'Preview',
    [string]$GamePath = "${env:ProgramFiles(x86)}\Steam\steamapps\common\Deadlock\game\bin\win64\deadlock.exe"
)
$ErrorActionPreference = 'Stop'
$group = 'DeadlockRelay-SA-1422450-v1'
$plan = @{}
if ($Mode -ne 'Off') {
    $exe = Get-Item -LiteralPath $GamePath
    if ($exe.PSIsContainer -or $exe.Name -ne 'deadlock.exe') { throw 'Expected the installed deadlock.exe (-GamePath).' }
    $url = 'https://api.steampowered.com/ISteamApps/GetSDRConfig/v1/?appid=1422450'
    $config = Invoke-RestMethod -Uri $url -TimeoutSec 20
    if (!$config.revision -or !$config.pops) { throw 'Unrecognized Valve config; no changes made.' }
    foreach ($city in 'gru','eze','scl','lim') {
        $pop = $config.pops.$city
        if (!$pop.relays) { Write-Warning "No advertised relays for $city"; continue }
        foreach ($r in $pop.relays) {
            $ports = @($r.port_range)
            if ($ports.Count -ne 2 -or $ports[0] -notmatch '^\d{1,5}$' -or $ports[1] -notmatch '^\d{1,5}$' -or [int]$ports[0] -lt 1 -or [int]$ports[1] -gt 65535 -or [int]$ports[1] -lt [int]$ports[0]) { throw "Invalid UDP range for $city" }
            $range = if ($ports[0] -eq $ports[1]) { "$($ports[0])" } else { $ports -join '-' }
            $addresses = @($r.ipv4,$r.ipv6 | Where-Object { $_ })
            if (!$addresses.Count) { throw "Missing address for $city" }
            foreach ($addr in $addresses) {
                $ip = [ipaddress]::Parse($addr)
                if ($ip.ToString() -in '::','0.0.0.0' -or [ipaddress]::IsLoopback($ip)) { throw "Invalid relay for $city" }
                $key = "$($exe.FullName.ToLowerInvariant())|$city|$ip|$range"
                $sha = [Security.Cryptography.SHA256]::Create()
                try { $id = [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($key))).Replace('-','') } finally { $sha.Dispose() }
                $plan["$group-$id"] = @{ DisplayName="Deadlock SA: $city $ip UDP $range"; Program=$exe.FullName; RemoteAddress=$ip.ToString(); RemotePort=$range }
            }
        }
    }
    if (!$plan.Count) { throw 'No identified SA relays; no changes made.' }
    Write-Output "Program: $($exe.FullName)"
    $plan.Values | ForEach-Object { $_.DisplayName } | Sort-Object
    if ($Mode -eq 'Preview') { return }
}
$principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
if (!$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Run On or Off from an administrator PowerShell.' }
$old = @(Get-NetFirewallRule -PolicyStore PersistentStore | Where-Object { $_.Group -eq $group -and $_.Name -match "^$group-[0-9A-F]{64}$" })
$created = @()
try {
    foreach ($name in $plan.Keys) {
        if ($old.Name -contains $name) { continue }
        $argsForRule = $plan[$name]
        New-NetFirewallRule @argsForRule -Name $name -Group $group -PolicyStore PersistentStore -Direction Outbound -Protocol UDP -Action Block -Profile Any -Enabled True | Out-Null
        $created += $name
    }
} catch {
    foreach ($name in $created) { Remove-NetFirewallRule -PolicyStore PersistentStore -Name $name -ErrorAction Continue }
    throw
}
# Only prune obsolete endpoints after every new rule has been staged successfully.
foreach ($rule in $old) {
    if (!$plan.ContainsKey($rule.Name)) { Remove-NetFirewallRule -PolicyStore PersistentStore -Name $rule.Name }
}
Write-Output "Done: $($plan.Count) managed relay rules."
