<#
.SYNOPSIS
    วัด A/B ระหว่าง power scheme สองตัวแบบสลับ A-B-B-A แล้วเทียบค่าเฉลี่ย
.DESCRIPTION
    การวัด A แล้ว B ต่อกันมี order bias (รอบหลังเครื่องร้อนกว่า) สคริปต์นี้จึงรัน
    A,B,B,A แล้วเฉลี่ยแต่ละฝั่ง เพื่อลดผลของ thermal drift
    ค่าเริ่มต้น: A = scheme ต้นฉบับใน state/last.json, B = scheme ที่โปรแกรมสร้าง
.EXAMPLE
    .\tools\AB-Bench.ps1
.EXAMPLE
    .\tools\AB-Bench.ps1 -A 381b4222-... -B e7ffd28e-... -Seconds 4
#>
[CmdletBinding()]
param(
    [string]$A,
    [string]$B,
    [int]$Seconds = 4
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'src\Level51Tune.psm1') -Force -DisableNameChecking

try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }

$paths = Get-L51Paths
$transcript = Join-Path $paths.Root (Join-Path 'logs' ('ab-bench-{0}.txt' -f (Get-Date).ToString('yyyyMMdd-HHmmss')))
try { Start-Transcript -Path $transcript -Force | Out-Null } catch { }

try {
    $state = Get-L51State
    if (-not $A) {
        if ($state -and $state.BaseScheme) { $A = $state.BaseScheme } else { throw 'ไม่พบ scheme A — ระบุด้วย -A' }
    }
    if (-not $B) {
        if ($state -and $state.SchemeGuid) { $B = $state.SchemeGuid } else { throw 'ไม่พบ scheme B — ระบุด้วย -B' }
    }
    if (-not (Test-L51Admin)) { throw 'ต้องรันแบบ Administrator เพราะต้องสลับ active power scheme' }

    $schemes = Get-L51PowerSchemes
    $nameA = ($schemes | Where-Object { $_.Guid -eq $A } | Select-Object -First 1).Name
    $nameB = ($schemes | Where-Object { $_.Guid -eq $B } | Select-Object -First 1).Name
    if (-not $nameA -or -not $nameB) { throw "ไม่พบ scheme ในเครื่อง: A=$A B=$B" }

    Write-L51Log ("A/B: A = $nameA  ·  B = $nameB  ·  $Seconds วินาที/รอบ · ลำดับ A-B-B-A") 'STEP'

    $order = @('A', 'B', 'B', 'A')
    $runs = @{ A = @(); B = @() }
    $i = 0
    foreach ($arm in $order) {
        $i++
        $guid = $A
        if ($arm -eq 'B') { $guid = $B }
        Invoke-L51External 'powercfg' @('-setactive', $guid) | Out-Null
        Start-Sleep -Seconds 2
        Write-L51Log ("รอบ {0}/4  ->  {1}" -f $i, $arm) 'STEP'
        $runs[$arm] += (Invoke-L51Bench -Seconds $Seconds -Label ("ab-{0}{1}" -f $arm, $i))
    }

    Invoke-L51External 'powercfg' @('-setactive', $B) | Out-Null

    Write-Host ''
    Write-L51Log ("สรุป A/B (ค่าเฉลี่ย 2 รอบ/ฝั่ง): A = $nameA  ·  B = $nameB") 'STEP'
    $metrics = @(
        @{ Key = 'CpuSingleMBps'; Name = 'CPU 1 thread (MB/s)' },
        @{ Key = 'CpuMultiMBps'; Name = 'CPU all threads (MB/s)' },
        @{ Key = 'MemMBps'; Name = 'Memory (MB/s)' },
        @{ Key = 'DiskWriteMB'; Name = 'Disk write (MB/s)' },
        @{ Key = 'DiskReadMB'; Name = 'Disk read (MB/s)' }
    )
    $out = @()
    foreach ($m in $metrics) {
        $va = ($runs.A | ForEach-Object { $_.($m.Key) } | Measure-Object -Average).Average
        $vb = ($runs.B | ForEach-Object { $_.($m.Key) } | Measure-Object -Average).Average
        $delta = 0
        if ($va -gt 0) { $delta = [math]::Round(($vb - $va) / $va * 100, 1) }
        $line = '  {0,-22} {1,10:N0} -> {2,10:N0}   {3,6}%' -f $m.Name, $va, $vb, $delta
        $color = 'Gray'
        if ($delta -gt 3) { $color = 'Green' }
        if ($delta -lt -3) { $color = 'Red' }
        Write-Host $line -ForegroundColor $color
        $out += [pscustomobject]@{ Metric = $m.Name; A = [math]::Round($va, 0); B = [math]::Round($vb, 0); DeltaPct = $delta }
    }
    Write-Host ''
    Write-Host '  |delta| ต่ำกว่า 3% ถือว่าไม่ต่าง (noise + thermal drift)' -ForegroundColor DarkGray
    Write-Host ("  scheme B ยังคง active: {0}" -f $nameB) -ForegroundColor DarkGray
    $summaryPath = Join-Path $paths.Bench ('ab-summary-{0}.json' -f (Get-Date).ToString('yyyyMMdd-HHmmss'))
    [pscustomobject]@{ Timestamp = (Get-Date).ToString('o'); SchemeA = $nameA; SchemeB = $nameB; Metrics = $out } |
        ConvertTo-Json -Depth 5 | Set-Content -Path $summaryPath -Encoding UTF8
    Write-Host ("  summary: {0}" -f $summaryPath) -ForegroundColor DarkGray
} finally {
    try { Stop-Transcript | Out-Null } catch { }
    Write-Host ("  log: {0}" -f $transcript) -ForegroundColor DarkGray
}
