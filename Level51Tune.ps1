<#
.SYNOPSIS
    LEVEL51-TUNE :: ชุดเครื่องมือปรับแต่งประสิทธิภาพเครื่อง LEVEL51
.DESCRIPTION
    ตรวจฮาร์ดแวร์, apply โปรไฟล์ tweaks (CPU/GPU/Power/RAM/Storage/Network/Windows),
    สำรองสถานะก่อนทุกครั้ง และย้อนกลับได้ด้วย restore
.EXAMPLE
    .\Level51Tune.ps1 status
.EXAMPLE
    .\Level51Tune.ps1 audit -Profile gaming
.EXAMPLE
    .\Level51Tune.ps1 apply -Profile performance -DryRun
.EXAMPLE
    .\Level51Tune.ps1 apply -Profile gaming -Elevate
.EXAMPLE
    .\Level51Tune.ps1 restore
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)][string]$Command = 'help',
    [string]$Profile,
    [string]$Category,
    [string]$Path,
    [string]$BackupPath,
    [string]$Label = 'run',
    [string[]]$Include = @(),
    [int]$Seconds = 3,
    [int]$Last = 10,
    [switch]$DryRun,
    [switch]$Elevate,
    [switch]$IncludeHigh,
    [switch]$Open,
    [switch]$Custom,
    [string]$AppPath,
    [string]$Mode = 'dgpu',
    [switch]$Remove
)

$ErrorActionPreference = 'Stop'
$modulePath = Join-Path $PSScriptRoot 'src\Level51Tune.psm1'
if (-not (Test-Path $modulePath)) {
    Write-Host "[x] ไม่พบ $modulePath" -ForegroundColor Red
    exit 1
}
Import-Module $modulePath -Force -DisableNameChecking

# ให้ภาษาไทยแสดงผลถูกต้องเมื่อ output ถูก pipe หรือ redirect
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }
try { $OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }

function Show-L51Help {
    $v = Get-L51Version
    Write-Host ''
    Write-Host '  LEVEL51-TUNE' -ForegroundColor Cyan
    Write-Host "  performance toolkit v$v  ·  Windows 10/11  ·  PowerShell 5.1+" -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '  การใช้งาน: .\Level51Tune.ps1 <คำสั่ง> [options]' -ForegroundColor White
    Write-Host ''
    Write-Host '  คำสั่ง' -ForegroundColor Yellow
    @(
        @('status', 'แสดงฮาร์ดแวร์, power scheme, สถานะปัจจุบัน (ไม่ต้อง admin)'),
        @('profiles', 'แสดงโปรไฟล์ทั้งหมดและสิ่งที่แต่ละโปรไฟล์ทำ'),
        @('list [-Category X]', 'แสดง tweaks ในแค็ตตาล็อก (CPU/GPU/Power/Memory/Storage/Network/Windows)'),
        @('audit [-Profile X] [-Category Y]', 'ตรวจว่าอะไรถูกปรับแล้ว/ยังไม่ถูกปรับ'),
        @('apply -Profile X', 'ปรับตามโปรไฟล์ (สำรองสถานะก่อนทุกครั้ง)'),
        @('apply -Custom', 'ปรับเฉพาะ tweak ที่เลือกไว้ (state/custom.json จาก GUI/CLI)'),
        @('restore [-BackupPath FILE]', 'ย้อนกลับจาก backup (ค่าเริ่มต้น: ไฟล์ล่าสุด)'),
        @('backup', 'สำรองสถานะปัจจุบันอย่างเดียว ไม่แก้อะไร'),
        @('report [-Path FILE]', 'สร้างรายงานสถานะเป็น markdown'),
        @('bench [-Label before]', 'วัด CPU/RAM/Disk เพื่อเทียบก่อน-หลัง'),
        @('compare', 'เทียบผล benchmark 2 ครั้งล่าสุด'),
        @('latency [-Seconds 20]', 'วัด DPC / interrupt / context switch (ตัวชี้วัด jitter จริง)'),
        @('history', 'รายการ backup ทั้งหมด (ระบุไฟล์เพื่อ restore ทีละครั้ง)'),
        @('gpuprefs [-AppPath FILE -Mode dgpu|igpu|auto] [-Remove]', 'ตั้ง GPU ต่อแอป (Optimus)'),
        @('gpu', 'สรุปสถานะ GPU จาก nvidia-smi'),
        @('docs [-Open]', 'สร้าง docs/*.html จาก docs/*.md'),
        @('version', 'แสดงเวอร์ชัน')
    ) | ForEach-Object { Write-Host ("   {0,-34} {1}" -f $_[0], $_[1]) }
    Write-Host ''
    Write-Host '  options' -ForegroundColor Yellow
    @(
        @('-DryRun', 'แสดงว่าจะทำอะไรโดยไม่แก้อะไรจริง (ปลอดภัย ใช้ทดสอบได้)'),
        @('-Elevate', 'เปิด PowerShell ใหม่แบบ Administrator อัตโนมัติ (มี UAC)'),
        @('-Include high', 'อนุญาตให้รวม tweaks ความเสี่ยงสูง (IDLEDISABLE, bcdedit, P-State)'),
        @('-IncludeHigh', 'เหมือน -Include high'),
        @('-Custom', 'ใช้รายการ tweak ที่บันทึกไว้ (หน้า Settings ของ GUI เป็นตัวเลือก)'),
        @('-AppPath / -Mode / -Remove', 'ใช้กับ gpuprefs: ไฟล์ .exe, โหมด GPU, ลบรายการ'),
        @('-Category', 'กรองตามหมวด (ใช้กับ list/audit)'),
        @('-Seconds', 'ระยะเวลา benchmark ต่อรอบ (วินาที, ค่าเริ่มต้น 3)')
    ) | ForEach-Object { Write-Host ("   {0,-34} {1}" -f $_[0], $_[1]) }
    Write-Host ''
    Write-Host '  ตัวอย่าง' -ForegroundColor Yellow
    Write-Host '   .\Level51Tune.ps1 status'
    Write-Host '   .\Level51Tune.ps1 bench -Label before'
    Write-Host '   .\Level51Tune.ps1 apply -Profile gaming -DryRun'
    Write-Host '   .\Level51Tune.ps1 apply -Profile gaming -Elevate'
    Write-Host '   .\Level51Tune.ps1 bench -Label after ; .\Level51Tune.ps1 compare'
    Write-Host '   .\Level51Tune.ps1 restore'
    Write-Host '   .\Start-LEVEL51.cmd            (GUI + UAC)'
    Write-Host '   .\Level51Tune.Web.ps1          (GUI เฉพาะ loopback)'
    Write-Host ''
    Write-Host '  เอกสาร: docs/index.html   ·   คำเตือน: เครื่องจะร้อน/กินไฟขึ้นเมื่อใช้โปรไฟล์ max' -ForegroundColor DarkGray
    Write-Host ''
}

try {
    switch ($Command.ToLower()) {
        'help' { Show-L51Help; break }
        '-h' { Show-L51Help; break }
        '--help' { Show-L51Help; break }

        'version' { Write-Host ("LEVEL51-TUNE v{0}" -f (Get-L51Version)); break }

        'status' { $null = Get-L51Status; break }

        'profiles' {
            Write-Host ''
            foreach ($p in Get-L51Profiles) {
                $tweaks = @(Get-L51ProfileTweaks -Profile $p.Id)
                $high = @($tweaks | Where-Object { $_.Risk -eq 'High' }).Count
                Write-Host ("  {0,-13} {1}" -f $p.Id, $p.TitleTh) -ForegroundColor Cyan
                Write-Host ("                {0}" -f $p.Summary)
                Write-Host ("                ใช้เมื่อ: {0}" -f $p.UseWhen) -ForegroundColor DarkGray
                Write-Host ("                tweaks: {0} (high risk {1})" -f $tweaks.Count, $high) -ForegroundColor DarkGray
                Write-Host ''
            }
            break
        }

        'list' {
            $items = Get-L51Catalog -Category $Category
            $items | Select-Object @{n = 'Id'; e = { $_.Id } }, Category, Risk,
            @{n = 'Profiles'; e = { ($_.Profiles -join ',') } },
            @{n = 'Admin'; e = { $_.Admin } }, Title |
                Format-Table -AutoSize | Out-String -Width 200 | Write-Host
            Write-Host ("  รวม {0} tweaks" -f @($items).Count) -ForegroundColor DarkGray
            break
        }

        'audit' {
            $rows = Invoke-L51Audit -Profile $Profile -Category $Category -IncludeHigh:$IncludeHigh
            $rows | Format-Table -AutoSize | Out-String -Width 200 | Write-Host
            $done = @($rows | Where-Object { $_.Applied -eq 'YES' }).Count
            Write-Host ("  ปรับแล้ว {0} / {1}" -f $done, @($rows).Count) -ForegroundColor Yellow
            break
        }

        'apply' {
            if ($Custom) {
                $ids = @(Get-L51CustomSelection)
                if ($ids.Count -eq 0) { throw 'ยังไม่มีรายการที่เลือกไว้ — เลือกได้ที่หน้า Settings ของ Web GUI หรือใช้ -Profile แทน' }
                Write-Host ("  ใช้รายการที่เลือกไว้: {0} tweaks" -f $ids.Count) -ForegroundColor Cyan
                $r = Invoke-L51Apply -TweakIds $ids -DryRun:$DryRun -Include $Include -Elevate:$Elevate
                if ($r -and $r.PSObject.Properties['Elevated']) { break }
                break
            }
            if (-not $Profile) { throw 'ต้องระบุ -Profile (ดูรายการได้ด้วย: .\Level51Tune.ps1 profiles)' }
            $r = Invoke-L51Apply -Profile $Profile -DryRun:$DryRun -Include $Include -Elevate:$Elevate
            if ($r -and $r.PSObject.Properties['Elevated']) { break }
            break
        }

        'restore' {
            $r = Invoke-L51Restore -BackupPath $BackupPath -Elevate:$Elevate
            break
        }

        'backup' {
            if (-not (Test-L51Admin)) { throw 'การ backup สถานะ power ต้องใช้สิทธิ์ Administrator' }
            $null = Invoke-L51Backup
            break
        }

        'report' {
            $p = New-L51Report -Path $Path
            Write-Host "  $p" -ForegroundColor Green
            break
        }

        'bench' {
            $r = Invoke-L51Bench -Seconds $Seconds -Label $Label
            Write-Host ''
            Write-Host ("  ผลรวม: CPU1 {0} MB/s · CPU{1} {2} MB/s · RAM {3} MB/s · Disk W {4} / R {5} MB/s" -f `
                    $r.CpuSingleMBps, $r.CpuThreads, $r.CpuMultiMBps, $r.MemMBps, $r.DiskWriteMB, $r.DiskReadMB) -ForegroundColor Cyan
            break
        }

        'compare' { Compare-L51Bench -Count $Last; break }

        'latency' {
            $secs = 20
            if ($Seconds -gt 0) { $secs = $Seconds }
            $null = Measure-L51Latency -Seconds $secs
            break
        }

        'gpu' {
            $gpus = @(Get-L51GpuState)
            if ($gpus.Count -eq 0) { Write-Host '  ไม่พบ GPU' -ForegroundColor Yellow; break }
            $gpus | Format-List | Out-String -Width 200 | Write-Host
            Write-Host '  คำสั่งที่มีประโยชน์: nvidia-smi -q -d CLOCK,POWER,TEMPERATURE' -ForegroundColor DarkGray
            break
        }

        'history' {
            $rows = @(Get-L51BackupHistory -Limit 20)
            if ($rows.Count -eq 0) { Write-Host '  ยังไม่มี backup ใน backups/' -ForegroundColor Yellow; break }
            $rows | Select-Object @{n = 'เวลา'; e = { ([datetime]$_.Created).ToString('yyyy-MM-dd HH:mm:ss') } },
            Profile, Tweaks, @{n = 'ย้อนกลับได้'; e = { if ($_.Restorable) { 'yes' } else { '-' } } }, File |
                Format-Table -AutoSize | Out-String -Width 200 | Write-Host
            Write-Host '  ย้อนกลับเฉพาะไฟล์: .\Level51Tune.ps1 restore -BackupPath <ไฟล์>' -ForegroundColor DarkGray
            break
        }

        'gpuprefs' {
            if ($AppPath) {
                if ($Remove) {
                    $ok = Remove-L51GpuPreference -AppPath $AppPath
                    Write-Host ("  ลบรายการ: {0}" -f $(if ($ok) { 'สำเร็จ' } else { 'ไม่พบรายการ' })) -ForegroundColor $(if ($ok) { 'Green' } else { 'Yellow' })
                } else {
                    $r = Set-L51GpuPreference -AppPath $AppPath -Mode $Mode
                    Write-Host ("  ตั้งค่า: {0} -> {1} ({2})" -f $r.Path, $r.Mode, $r.Value) -ForegroundColor Green
                }
                break
            }
            $rows = @(Get-L51GpuPreferences)
            if ($rows.Count -eq 0) { Write-Host '  ยังไม่มี per-app GPU preference' -ForegroundColor Yellow }
            else { $rows | Format-Table -AutoSize | Out-String -Width 200 | Write-Host }
            Write-Host '  เพิ่ม/แก้: .\Level51Tune.ps1 gpuprefs -AppPath "C:\path\game.exe" -Mode dgpu' -ForegroundColor DarkGray
            break
        }

        'docs' {
            $r = Build-L51Docs
            Write-Host ("  {0}" -f $r.Index) -ForegroundColor Green
            if ($Open) { Start-Process $r.Index }
            break
        }

        default {
            Write-Host "[x] ไม่รู้จักคำสั่ง '$Command' — ใช้ 'help' เพื่อดูรายการ" -ForegroundColor Red
            exit 2
        }
    }
} catch {
    Write-Host ''
    Write-Host ("[x] {0}" -f $_.Exception.Message) -ForegroundColor Red
    Write-Host ''
    Write-Host '  คำแนะนำ: ถ้าเป็นเรื่องสิทธิ์ ให้รันใน PowerShell แบบ Administrator หรือเพิ่ม -Elevate' -ForegroundColor DarkGray
    exit 1
}
