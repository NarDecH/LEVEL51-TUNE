<#
.SYNOPSIS
    วัด A/B ด้าน latency (DPC / interrupt / context switch) ระหว่างสอง power scheme
.DESCRIPTION
    throughput ของเครื่องแทบไม่เปลี่ยนจากการจูน power plan แต่สิ่งที่เปลี่ยนคือ
    jitter/latency ของ interrupt และ DPC สคริปต์นี้สลับ A-B-B-A แล้วเทียบค่าเฉลี่ย
    (ลำดับสลับช่วยลด order bias จากความร้อนที่สะสม)
.EXAMPLE
    .\tools\AB-Latency.ps1              # A = scheme เดิม, B = scheme ที่ apply ไว้
.EXAMPLE
    .\tools\AB-Latency.ps1 -Seconds 20
#>
[CmdletBinding()]
param(
    [string]$A,
    [string]$B,
    [int]$Seconds = 12
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'src\Level51Tune.psm1') -Force -DisableNameChecking

try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }

$paths = Get-L51Paths
$transcript = Join-Path $paths.Root (Join-Path 'logs' ('ab-latency-{0}.txt' -f (Get-Date).ToString('yyyyMMdd-HHmmss')))
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

    Write-L51Log ("A/B latency: A = $nameA  ·  B = $nameB  ·  $Seconds วินาที/รอบ · ลำดับ A-B-B-A") 'STEP'

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
        $runs[$arm] += (Measure-L51Latency -Seconds $Seconds)
    }

    Invoke-L51External 'powercfg' @('-setactive', $B) | Out-Null

    Write-Host ''
    Write-L51Log 'สรุป A/B ด้าน latency (ค่าเฉลี่ย 2 รอบ/ฝั่ง)' 'STEP'
    $dpcA = ($runs.A | ForEach-Object { $_.DpcAvg } | Measure-Object -Average).Average
    $dpcB = ($runs.B | ForEach-Object { $_.DpcAvg } | Measure-Object -Average).Average
    $isrA = ($runs.A | ForEach-Object { $_.IsrAvg } | Measure-Object -Average).Average
    $isrB = ($runs.B | ForEach-Object { $_.IsrAvg } | Measure-Object -Average).Average

    $rows = @(
        @{ Name = 'DPC Time (%)'; A = $dpcA; B = $dpcB; Lower = $true },
        @{ Name = 'Interrupt Time (%)'; A = $isrA; B = $isrB; Lower = $true }
    )
    $out = @()
    foreach ($r in $rows) {
        $delta = 0
        if ($r.A -gt 0) { $delta = [math]::Round(($r.B - $r.A) / $r.A * 100, 1) }
        $color = 'Gray'
        if ($delta -lt -3) { $color = 'Green' }
        if ($delta -gt 3) { $color = 'Red' }
        Write-Host ('  {0,-18} {1,8:N2} -> {2,8:N2}   {3,6}%' -f $r.Name, $r.A, $r.B, $delta) -ForegroundColor $color
        $out += [pscustomobject]@{ Metric = $r.Name; A = [math]::Round($r.A, 2); B = [math]::Round($r.B, 2); DeltaPct = $delta }
    }
    Write-Host ''
    Write-Host '  ตัวเลขต่ำลง = ดีขึ้น · |delta| ต่ำกว่า 3% ถือว่าไม่ต่าง (noise)' -ForegroundColor DarkGray
    Write-Host ("  scheme B ยังคง active: {0}" -f $nameB) -ForegroundColor DarkGray

    $summaryPath = Join-Path $paths.Bench ('ab-latency-{0}.json' -f (Get-Date).ToString('yyyyMMdd-HHmmss'))
    [pscustomobject]@{ Timestamp = (Get-Date).ToString('o'); SchemeA = $nameA; SchemeB = $nameB; Metrics = $out } |
        ConvertTo-Json -Depth 5 | Set-Content -Path $summaryPath -Encoding UTF8
    Write-Host ("  summary: {0}" -f $summaryPath) -ForegroundColor DarkGray
} finally {
    try { Stop-Transcript | Out-Null } catch { }
    Write-Host ("  log: {0}" -f $transcript) -ForegroundColor DarkGray
}
