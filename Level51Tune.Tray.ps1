<#
.SYNOPSIS
    LEVEL51-TUNE :: tray icon (ควบคุมเร็วจาก notification area)
.DESCRIPTION
    วางไอคอนไว้ใน system tray พร้อมเมนู:
      - เปิด Dashboard (ขอ UAC แล้วเปิด Web GUI)
      - สลับโปรไฟล์ (balanced / performance / gaming / max / battery)
      - ตรวจสถานะ (แสดง tooltip + balloon: โปรไฟล์, GPU temp/power)
      - เปิดโฟลเดอร์ log / เอกสาร
      - ออก
    ทุก action ที่แก้ระบบจะขอ UAC เอง (ไม่รัน elevated ค้างไว้)
.EXAMPLE
    .\Level51Tune.Tray.ps1
.EXAMPLE
    .\Level51Tune.Tray.ps1 -Port 8899
#>
[CmdletBinding()]
param([int]$Port = 8730)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Import-Module (Join-Path $PSScriptRoot 'src\Level51Tune.psm1') -Force -DisableNameChecking
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }

$script:Root = $PSScriptRoot
$script:LastStatus = 'กำลังเริ่ม…'

function Invoke-L51Elevated {
    param([string[]]$Arguments)

    $exe = (Get-Process -Id $PID).Path
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $script:Root 'Level51Tune.ps1')) + $Arguments
    Start-Process -FilePath $exe -ArgumentList $argList -Verb RunAs
}

function Start-L51Dashboard {
    $exe = (Get-Process -Id $PID).Path
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $script:Root 'Level51Tune.Web.ps1'), '-Port', "$Port", '-Elevate')
    Start-Process -FilePath $exe -ArgumentList $argList -Verb RunAs
}

function Get-L51TraySummary {
    $state = Get-L51State
    $profileName = 'ยังไม่ apply'
    if ($state) { $profileName = [string]$state.Profile }
    $gpuText = ''
    try {
        $gpu = @(Get-L51GpuState | Where-Object { $_.Source -eq 'nvidia-smi' } | Select-Object -First 1)
        if ($gpu.Count -gt 0) { $gpuText = (' · GPU {0}°C {1}W' -f $gpu[0].TempC, $gpu[0].PowerW) }
    } catch { }
    return ('LEVEL51 · {0}{1}' -f $profileName, $gpuText)
}

$notify = New-Object System.Windows.Forms.NotifyIcon
try { $notify.Icon = [System.Drawing.SystemIcons]::Shield } catch { $notify.Icon = [System.Drawing.SystemIcons]::Application }
$notify.Text = 'LEVEL51-TUNE'
$notify.Visible = $true

$menu = New-Object System.Windows.Forms.ContextMenuStrip

$miDash = New-Object System.Windows.Forms.ToolStripMenuItem('เปิด Dashboard')
$miDash.Add_Click({ try { Start-L51Dashboard } catch { } })
[void]$menu.Items.Add($miDash)

$miProfiles = New-Object System.Windows.Forms.ToolStripMenuItem('สลับโปรไฟล์')
foreach ($p in (Get-L51Profiles)) {
    $item = New-Object System.Windows.Forms.ToolStripMenuItem(('{0}  ({1})' -f $p.TitleTh, $p.Id))
    $id = $p.Id
    $item.Tag = $id
    $item.Add_Click({ param($sender, $e) Invoke-L51Elevated @('apply', '-Profile', $sender.Tag) }.GetNewClosure())
    [void]$miProfiles.DropDownItems.Add($item)
}
[void]$menu.Items.Add($miProfiles)

$miStatus = New-Object System.Windows.Forms.ToolStripMenuItem('ตรวจสถานะ')
$miStatus.Add_Click({
        try {
            $script:LastStatus = Get-L51TraySummary
            $notify.BalloonTipTitle = 'LEVEL51-TUNE'
            $notify.BalloonTipText = $script:LastStatus
            $notify.ShowBalloonTip(4000)
        } catch { }
    })
[void]$menu.Items.Add($miStatus)

[void]$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))

$miLog = New-Object System.Windows.Forms.ToolStripMenuItem('เปิดโฟลเดอร์ log')
$miLog.Add_Click({ try { Invoke-Item (Join-Path $script:Root 'logs') } catch { } })
[void]$menu.Items.Add($miLog)

$miDocs = New-Object System.Windows.Forms.ToolStripMenuItem('เปิดเอกสาร')
$miDocs.Add_Click({ try { Invoke-Item (Join-Path $script:Root 'docs\index.html') } catch { } })
[void]$menu.Items.Add($miDocs)

$miQuit = New-Object System.Windows.Forms.ToolStripMenuItem('ออก')
$miQuit.Add_Click({
        $notify.Visible = $false
        $notify.Dispose()
        [System.Windows.Forms.Application]::ExitThread()
    })
[void]$menu.Items.Add($miQuit)

$notify.ContextMenuStrip = $menu
$notify.Add_MouseDoubleClick({ try { Start-L51Dashboard } catch { } })

# อัปเดต tooltip ทุก 30 วินาที (Text ของ NotifyIcon จำกัด 63 ตัวอักษร)
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 30000
$timer.Add_Tick({
        try {
            $text = Get-L51TraySummary
            $script:LastStatus = $text
            if ($text.Length -gt 63) { $text = $text.Substring(0, 63) }
            $notify.Text = $text
        } catch { }
    })
$timer.Start()

$script:LastStatus = Get-L51TraySummary
if ($script:LastStatus.Length -le 63) { $notify.Text = $script:LastStatus }
$notify.BalloonTipTitle = 'LEVEL51-TUNE ทำงานอยู่'
$notify.BalloonTipText = $script:LastStatus + ' — คลิกขวาที่ไอคอนเพื่อเลือกโปรไฟล์'
$notify.ShowBalloonTip(3000)

Write-Host ''
Write-Host '  LEVEL51-TUNE :: tray' -ForegroundColor Cyan
Write-Host ('  สถานะ: {0}' -f $script:LastStatus)
Write-Host '  ไอคอนอยู่ใน system tray — คลิกขวาเพื่อเปิดเมนู, ดับเบิลคลิกเพื่อเปิด Dashboard' -ForegroundColor DarkGray
Write-Host '  ปิดได้จากเมนู "ออก" หรือ Ctrl+C ในหน้าต่างนี้' -ForegroundColor DarkGray
Write-Host ''

try {
    $context = New-Object System.Windows.Forms.ApplicationContext
    [System.Windows.Forms.Application]::Run($context)
} finally {
    $timer.Stop()
    try { $notify.Visible = $false; $notify.Dispose() } catch { }
    Write-Host '  ปิด tray แล้ว' -ForegroundColor DarkGray
}
