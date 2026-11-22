# Offline smoke tests; mock every network/firewall operation. No elevation required.
$ErrorActionPreference = 'Stop'
$entry = Join-Path $PSScriptRoot '..\DeadlockRelayFilter.ps1'
$temp = New-Item -ItemType Directory -Path (Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid()))
$game = (New-Item (Join-Path $temp.FullName 'deadlock.exe')).FullName
$db = @{}; $offline = $false; $fail = ''; $failRemove = ''
function Invoke-RestMethod { param($Uri,$TimeoutSec)
    if ($offline) { throw 'offline' }
    $pops = [ordered]@{}; $i = 0
    foreach ($p in 'gru','fra','lax') { $i++; $pops[$p] = @{desc=$p;relays=@(@{ipv4="192.0.2.$i";port_range=27015,27060})} }
    @{revision=1;pops=[pscustomobject]$pops}
}
function Get-NetFirewallRule {param($PolicyStore) $db.Values}
function New-NetFirewallRule {param($Name,$Group,$DisplayName,$Program,$RemoteAddress,$RemotePort,$PolicyStore,$Direction,$Protocol,$Action,$Profile,$Enabled,$ErrorAction)
    if ($fail -and $DisplayName -like "*$fail*") { throw 'mock add failure' }
    if ($db.ContainsKey($Name)) { throw 'duplicate' }; $db[$Name] = [pscustomobject]@{}; foreach ($k in $PSBoundParameters.Keys) { $db[$Name] | Add-Member NoteProperty $k $PSBoundParameters[$k] }
}
function Remove-NetFirewallRule {param($PolicyStore,$Name,$ErrorAction) if ($Name -eq $failRemove) { throw 'mock prune failure' }; $db.Remove($Name)}
function Get-NetFirewallApplicationFilter {process { $_ }}
function Get-NetFirewallAddressFilter {process { $_ }}
function Get-NetFirewallPortFilter {process { $_ }}
function Check($condition,$msg) { if (!$condition) { throw $msg } }
function Rejected([scriptblock]$action) { try { & $action | Out-Null } catch { return }; throw 'expected rejection' }
try {
    $foreign = 'unrelated'; $db[$foreign] = [pscustomobject]@{Group='other';Name=$foreign}
    $legacy = 'DeadlockRelay-SA-1422450-v1'; $id = "$legacy-" + ('A'*64)
    New-NetFirewallRule -Name $id -Group $legacy -DisplayName old -Enabled True
    & $entry List | Out-Null; & $entry Preview -Region SA -GamePath $game | Out-Null
    Check ($db.Count -eq 2) 'preview changed state'
    Rejected { & $entry On }; Rejected { & $entry On -Region ZZ }; Rejected { & $entry On -Region SA,EU,NA -GamePath $game }; Rejected { & $entry On -Region SA,AF -GamePath $game }
    $fail = 'fra'; Rejected { & $entry On -Region SA,EU -GamePath $game }; $fail = ''
    Check ($db.Count -eq 2 -and $db.ContainsKey($id)) 'failed refresh changed state'
    & $entry On -Region SA,EU -GamePath $game | Out-Null; & $entry On -Region SA,EU -GamePath $game | Out-Null
    Check ($db.Count -eq 3 -and !$db.ContainsKey($id)) 'migration or repeat failed'
    & $entry On -Region SA -GamePath $game | Out-Null
    Check ($db.Values.DisplayName -like '*gru*') 'lost SA'; Check ($db.Count -eq 2) 'failed to prune EU'
    New-NetFirewallRule -Name $id -Group $legacy -DisplayName old -Enabled True
    $offline = $true; Rejected { & $entry On -Region EU -GamePath $game }
    $failRemove = @($db.Values | Where-Object Group -ne 'other')[-1].Name; Rejected { & $entry Off }; $failRemove = ''
    Check ($db.Count -eq 3) 'prune rollback failed'; & $entry Off | Out-Null
    Check ($db.Count -eq 1 -and $db.ContainsKey($foreign)) 'offline undo failed'
    'Offline relay filter tests passed.'
} finally { Remove-Item $temp.FullName -Recurse -Force }
