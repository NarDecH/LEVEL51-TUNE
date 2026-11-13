<#
.SYNOPSIS
    LEVEL51-TUNE :: Web GUI (dashboard ท้องถิ่น)
.DESCRIPTION
    เปิดหน้าเว็บ GUI บน http://127.0.0.1:<port>/ เพื่อดูสถานะ ตรวจ audit,
    apply โปรไฟล์, bench, วัด latency และ restore โดยเรียก engine ตัวเดียวกับ CLI

    - ฟังเฉพาะ loopback (127.0.0.1) ไม่เปิดออกเครือข่าย
    - ทุก API ต้องมี token สุ่มที่สร้างตอนเริ่ม (ฝังในหน้าเว็บให้อัตโนมัติ)
    - ถ้าต้องการ apply/restore ต้องเปิดโปรแกรมนี้แบบ Administrator
.EXAMPLE
    .\Level51Tune.Web.ps1
.EXAMPLE
    .\Level51Tune.Web.ps1 -Port 8899 -NoBrowser
#>
[CmdletBinding()]
param(
    [int]$Port = 8730,
    [switch]$NoBrowser,
    [switch]$Elevate
)

$ErrorActionPreference = 'Stop'
$modulePath = Join-Path $PSScriptRoot 'src\Level51Tune.psm1'
Import-Module $modulePath -Force -DisableNameChecking
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }

# -Elevate: เปิดตัวเองใหม่แบบ Administrator แล้วจบโปรเซสนี้ (ใช้โดย Start-LEVEL51.cmd)
if ($Elevate -and -not (Test-L51Admin)) {
    $exe = (Get-Process -Id $PID).Path
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath, '-Port', "$Port", '-Elevate')
    if ($NoBrowser) { $argList += '-NoBrowser' }
    Write-Host '  กำลังขอสิทธิ์ Administrator (UAC)…' -ForegroundColor Yellow
    Start-Process -FilePath $exe -ArgumentList $argList -Verb RunAs
    exit 0
}

$token = -join ((48..57) + (97..102) | Get-Random -Count 32 | ForEach-Object { [char]$_ })
$docsDir = Join-Path $PSScriptRoot 'docs'
# ใช้ localhost เพื่อให้ HttpListener ทำงานได้โดยไม่ต้องมี URL ACL (bind เฉพาะ loopback)
$prefix = "http://localhost:$Port/"
$listener = New-Object System.Net.HttpListener
$listener.IgnoreWriteExceptions = $true
$listener.Prefixes.Add($prefix)
try {
    $listener.Start()
} catch {
    Write-Host "[x] เปิด port $Port ไม่ได้: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "    ลองเปลี่ยน port:  .\Level51Tune.Web.ps1 -Port 8899" -ForegroundColor DarkGray
    exit 1
}

$url = "$prefix`?t=$token"
Write-Host ''
Write-Host '  LEVEL51-TUNE :: Web GUI' -ForegroundColor Cyan
Write-Host ("  เปิดที่: {0}" -f $url) -ForegroundColor Green
Write-Host ("  สิทธิ์ admin: {0}" -f (Test-L51Admin)) -ForegroundColor $(if (Test-L51Admin) { 'Green' } else { 'Yellow' })
if (-not (Test-L51Admin)) {
    Write-Host '  หมายเหตุ: apply/restore ต้องรันโปรแกรมนี้แบบ Administrator' -ForegroundColor Yellow
}
Write-Host '  กด Ctrl+C เพื่อหยุด' -ForegroundColor DarkGray
Write-Host ''

if (-not $NoBrowser) { try { Start-Process $url } catch { } }

function Send-L51Response {
    param($Context, [string]$Body, [string]$ContentType = 'application/json; charset=utf-8', [int]$Status = 200)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Body)
    $Context.Response.StatusCode = $Status
    $Context.Response.ContentType = $ContentType
    $Context.Response.ContentLength64 = $bytes.Length
    $Context.Response.Headers.Add('Cache-Control', 'no-store')
    $Context.Response.Headers.Add('X-Content-Type-Options', 'nosniff')
    try { $Context.Response.OutputStream.Write($bytes, 0, $bytes.Length) } catch { }
    try { $Context.Response.Close() } catch { }
}

function Get-L51JsonBody {
    param($Context)
    $reader = New-Object System.IO.StreamReader($Context.Request.InputStream, [System.Text.Encoding]::UTF8)
    $raw = $reader.ReadToEnd()
    $reader.Close()
    if (-not $raw) { return @{} }
    try { return ($raw | ConvertFrom-Json) } catch { return @{} }
}

function Get-L51StatusPayload {
    $hw = Get-L51Hardware -Refresh
    $state = Get-L51State
    $profiles = @(Get-L51Profiles | ForEach-Object {
            [pscustomobject]@{
                id      = $_.Id
                name    = $_.Name
                titleTh = $_.TitleTh
                summary = $_.Summary
                useWhen = $_.UseWhen
                tweaks  = @(Get-L51ProfileTweaks -Profile $_.Id).Count
                high    = @(Get-L51ProfileTweaks -Profile $_.Id | Where-Object { $_.Risk -eq 'High' }).Count
            }
        })
    $gpu = @($hw.Gpus | Where-Object { $_.Source -eq 'nvidia-smi' } | Select-Object -First 1)
    $gpuObj = $null
    if ($gpu.Count -gt 0) {
        $gpuObj = [pscustomobject]@{
            name = $gpu[0].Name; clock = $gpu[0].ClockMHz; temp = $gpu[0].TempC
            util = $gpu[0].UtilPct; power = $gpu[0].PowerW; driver = $gpu[0].Driver
        }
    }
    $stateObj = $null
    if ($state) {
        $stateObj = [pscustomobject]@{
            profile       = $state.Profile
            appliedAt     = $state.AppliedAt
            backup        = $state.Backup
            scheme        = $state.SchemeGuid
            rebootPending = [bool]$state.RebootPending
            rebootTweaks  = @($state.RebootTweaks)
        }
    }
    $schemeObj = $null
    if ($hw.PowerScheme) { $schemeObj = [pscustomobject]@{ guid = $hw.PowerScheme.Guid; name = $hw.PowerScheme.Name } }
    $advice = $null
    try {
        $rec = Get-L51Recommendation -Hardware $hw
        $advice = [pscustomobject]@{
            profile = $rec.Profile; profileTitle = $rec.ProfileTitleTh; cpuClass = $rec.CpuClass
            ramChannels = $rec.RamChannels; hasDedicatedGpu = $rec.HasDedicatedGpu
            knownMachine = $rec.KnownMachine; maxProfileSafe = $rec.MaxProfileSafe
            notes = @($rec.Notes); warnings = @($rec.Warnings)
        }
    } catch { }
    return [pscustomobject]@{
        computer = $hw.Computer
        model    = "$($hw.Manufacturer) $($hw.Model)".Trim()
        os       = "$($hw.OS) build $($hw.Build)"
        cpu      = $hw.CpuName
        cores    = $hw.CpuCores
        threads  = $hw.CpuThreads
        ram      = $hw.RamGB
        ramFree  = $hw.RamFreeGB
        admin    = $hw.IsAdmin
        scheme   = $schemeObj
        gpu      = $gpuObj
        profiles = $profiles
        state    = $stateObj
        advice   = $advice
        # เรียงให้ดิสก์ภายใน (NVMe/SSD) ขึ้นก่อน USB
        disks    = @($hw.Disks | Sort-Object @{ Expression = { if ($_.Bus -eq 'NVMe') { 0 } elseif ($_.Bus -eq 'USB') { 2 } else { 1 } } }, @{ Expression = { $_.GB }; Descending = $true } | ForEach-Object {
                [pscustomobject]@{ name = $_.Name; gb = $_.GB; bus = $_.Bus; health = $_.Health }
            })
    }
}

$cancelEvent = New-Object System.Threading.ManualResetEvent($false)
try {
    while ($listener.IsListening) {
        $ctx = $null
        try { $ctx = $listener.GetContext() } catch { break }
        $req = $ctx.Request
        $path = $req.Url.AbsolutePath

        try {
            # ---- static: docs ---------------------------------------------
            if ($path.StartsWith('/docs/')) {
                $rel = $path.Substring(6)
                $rel = [Uri]::UnescapeDataString($rel) -replace '/', '\'
                $full = Join-Path $docsDir $rel
                $resolved = [System.IO.Path]::GetFullPath($full)
                if (-not $resolved.StartsWith([System.IO.Path]::GetFullPath($docsDir))) {
                    Send-L51Response $ctx '{"error":"forbidden"}' 'application/json' 403
                } elseif (Test-Path $resolved -PathType Leaf) {
                    $mime = switch ([System.IO.Path]::GetExtension($resolved)) {
                        '.html' { 'text/html; charset=utf-8' }
                        '.css' { 'text/css; charset=utf-8' }
                        '.md' { 'text/plain; charset=utf-8' }
                        default { 'application/octet-stream' }
                    }
                    Send-L51Response $ctx (Get-Content $resolved -Raw -Encoding UTF8) $mime
                } else {
                    Send-L51Response $ctx '{"error":"not found"}' 'application/json' 404
                }
                continue
            }

            # ---- token check (ยกเว้นหน้าแรกที่ฝัง token มาให้) --------------
            $given = $req.QueryString['t']
            if (-not $given) { $given = $req.Headers['X-L51-Token'] }
            if ($given -ne $token) {
                Send-L51Response $ctx '{"error":"unauthorized - open the URL printed in the console"}' 'application/json' 401
                continue
            }

            # ---- dashboard -------------------------------------------------
            if ($path -eq '/' -or $path -eq '/index.html') {
                $html = (Get-L51DashboardHtml).Replace('__TOKEN__', $token)
                Send-L51Response $ctx $html 'text/html; charset=utf-8'
                continue
            }

            # ---- API -------------------------------------------------------
            if ($path -eq '/api/status') {
                Send-L51Response $ctx ((Get-L51StatusPayload) | ConvertTo-Json -Depth 6)
                continue
            }

            if ($path -eq '/api/audit') {
                $body = Get-L51JsonBody $ctx
                $profile = $body.profile
                $auditIds = @()
                if ($body.tweakIds) { $auditIds = @($body.tweakIds | ForEach-Object { [string]$_ }) }
                $rows = @(Invoke-L51Audit -Profile $profile -TweakIds $auditIds | ForEach-Object {
                        [pscustomobject]@{ id = $_.Id; category = $_.Category; risk = $_.Risk; applied = $_.Applied; title = $_.Title }
                    })
                Send-L51Response $ctx ([pscustomobject]@{
                        profile = $profile
                        rows    = $rows
                        done    = @($rows | Where-Object { $_.applied -eq 'YES' }).Count
                        total   = $rows.Count
                    } | ConvertTo-Json -Depth 5)
                continue
            }

            if ($path -eq '/api/apply') {
                $body = Get-L51JsonBody $ctx
                $dry = [bool]$body.dryRun
                $include = @()
                if ($body.includeHigh) { $include = @('high') }
                $ids = @()
                if ($body.tweakIds) { $ids = @($body.tweakIds | ForEach-Object { [string]$_ }) }
                $appliedTo = $body.profile
                if ($ids.Count -gt 0) {
                    $appliedTo = 'custom'
                    $r = Invoke-L51Apply -TweakIds $ids -DryRun:$dry -Include $include
                } else {
                    $r = Invoke-L51Apply -Profile $body.profile -DryRun:$dry -Include $include
                }
                Send-L51Response $ctx ([pscustomobject]@{
                        profile = $appliedTo
                        dryRun  = $dry
                        backup  = $r.Backup
                        scheme  = $r.Scheme
                        results = @($r.Results | ForEach-Object { [pscustomobject]@{ id = $_.Id; status = $_.Status; detail = $_.Detail } })
                        skipped = @($r.Skipped | ForEach-Object { $_.Id })
                        restartRequired = @($r.RebootTweaks)
                    } | ConvertTo-Json -Depth 6)
                continue
            }

            if ($path -eq '/api/restore') {
                if (-not (Test-L51Admin)) { Send-L51Response $ctx '{"error":"ต้องรัน Web GUI แบบ Administrator เพื่อ restore"}' 'application/json' 403; continue }
                $body = Get-L51JsonBody $ctx
                $bp = $null
                if ($body.backupPath) { $bp = [string]$body.backupPath }
                $rows = @(Invoke-L51Restore -BackupPath $bp | ForEach-Object { [pscustomobject]@{ id = $_.Id; status = $_.Status; detail = $_.Detail } })
                Send-L51Response $ctx ([pscustomobject]@{ results = $rows } | ConvertTo-Json -Depth 5)
                continue
            }

            if ($path -eq '/api/bench') {
                $body = Get-L51JsonBody $ctx
                $secs = 3
                if ($body.seconds) { $secs = [int]$body.seconds }
                $label = 'web'
                if ($body.label) { $label = [string]$body.label }
                $r = Invoke-L51Bench -Seconds $secs -Label $label
                Send-L51Response $ctx ([pscustomobject]@{
                        cpuSingle = $r.CpuSingleMBps; cpuMulti = $r.CpuMultiMBps; cores = $r.CpuThreads
                        mem       = $r.MemMBps; diskWrite = $r.DiskWriteMB; diskRead = $r.DiskReadMB
                        label     = $r.Label
                    } | ConvertTo-Json -Depth 4)
                continue
            }

            if ($path -eq '/api/latency') {
                $body = Get-L51JsonBody $ctx
                $secs = 10
                if ($body.seconds) { $secs = [int]$body.seconds }
                $r = Measure-L51Latency -Seconds $secs
                Send-L51Response $ctx ([pscustomobject]@{
                        dpc = $r.DpcAvg; isr = $r.IsrAvg; scheme = $r.Scheme
                        rows = @($r.Counters | ForEach-Object { [pscustomobject]@{ counter = $_.Counter; avg = $_.Avg; max = $_.Max } })
                    } | ConvertTo-Json -Depth 4)
                continue
            }

            if ($path -eq '/api/tweaks') {
                $rows = @(Get-L51Catalog | ForEach-Object {
                        [pscustomobject]@{
                            id       = $_.Id
                            category = $_.Category
                            title    = $_.Title
                            titleTh  = $_.TitleTh
                            risk     = $_.Risk
                            type     = $_.Type
                            admin    = [bool]$_.Admin
                            reboot   = [bool]$_.Reboot
                            profiles = @($_.Profiles)
                            notes    = $_.Notes
                        }
                    })
                $saved = @(Get-L51CustomSelection)
                Send-L51Response $ctx ([pscustomobject]@{ rows = $rows; saved = $saved } | ConvertTo-Json -Depth 5)
                continue
            }

            if ($path -eq '/api/settings') {
                if ($req.HttpMethod -eq 'POST') {
                    $body = Get-L51JsonBody $ctx
                    $ids = @()
                    if ($body.tweakIds) { $ids = @($body.tweakIds | ForEach-Object { [string]$_ }) }
                    $saved = @(Save-L51CustomSelection -TweakIds $ids)
                    Send-L51Response $ctx ([pscustomobject]@{ saved = $saved; count = $saved.Count } | ConvertTo-Json -Depth 4)
                } else {
                    $saved = @(Get-L51CustomSelection)
                    Send-L51Response $ctx ([pscustomobject]@{ saved = $saved; count = $saved.Count } | ConvertTo-Json -Depth 4)
                }
                continue
            }

            if ($path -eq '/api/live') {
                $m = Get-L51LiveMetrics
                $g = $null
                if ($m.Gpu) {
                    $g = [pscustomobject]@{
                        name = $m.Gpu.Name; clockMHz = $m.Gpu.ClockMHz; temp = $m.Gpu.TempC
                        util = $m.Gpu.UtilPct; power = $m.Gpu.PowerW
                    }
                }
                # ใช้ชื่อแบบ camelCase ให้ตรงกับฝั่ง JS
                Send-L51Response $ctx ([pscustomobject]@{
                        ts          = $m.Timestamp
                        cpuLoadPct  = $m.CpuLoadPct
                        cpuClockMHz = $m.CpuClockMHz
                        ramUsedGB   = $m.RamUsedGB
                        gpu         = $g
                    } | ConvertTo-Json -Depth 4)
                continue
            }

            if ($path -eq '/api/compare') {
                $body = Get-L51JsonBody $ctx
                $secs = 3
                if ($body.seconds) { $secs = [int]$body.seconds }
                $last = Invoke-L51Bench -Seconds $secs -Label ('web-' + (Get-Date).ToString('HHmmss'))
                $rows = @(Compare-L51Bench -Count 2 -AsObject)
                $pairs = @($rows | ForEach-Object {
                        [pscustomobject]@{
                            from = $_.From; to = $_.To; metric = $_.Metric
                            a = $_.A; b = $_.B; delta = $_.DeltaPct
                        }
                    })
                Send-L51Response $ctx ([pscustomobject]@{
                        label  = $last.Label
                        pairs  = $pairs
                        rounds = @($pairs | Select-Object -ExpandProperty from -Unique).Count
                    } | ConvertTo-Json -Depth 5)
                continue
            }

            if ($path -eq '/api/update') {
                $u = Get-L51UpdateInfo
                Send-L51Response $ctx ([pscustomobject]@{
                        local = $u.Local; latest = $u.Latest; url = $u.Url
                        publishedAt = $u.PublishedAt; upToDate = $u.UpToDate
                        checked = $u.Checked; error = $u.Error
                    } | ConvertTo-Json -Depth 4)
                continue
            }

            if ($path -eq '/api/backups') {
                $rows = @(Get-L51BackupHistory -Limit 25 | ForEach-Object {
                        [pscustomobject]@{
                            file = $_.File; path = $_.Path; profile = $_.Profile; created = $_.Created
                            tweaks = $_.Tweaks; sizeKB = $_.SizeKB; restorable = $_.Restorable
                        }
                    })
                Send-L51Response $ctx ([pscustomobject]@{ rows = $rows } | ConvertTo-Json -Depth 4)
                continue
            }

            if ($path -eq '/api/gpu-prefs') {
                if ($req.HttpMethod -eq 'POST') {
                    $body = Get-L51JsonBody $ctx
                    $action = 'set'
                    if ($body.action) { $action = [string]$body.action }
                    $appPath = [string]$body.path
                    if (-not $appPath) { Send-L51Response $ctx '{"error":"ต้องระบุ path ของไฟล์ .exe"}' 'application/json' 400; continue }
                    if ($action -eq 'remove') {
                        $ok = Remove-L51GpuPreference -AppPath $appPath
                        Send-L51Response $ctx ([pscustomobject]@{ removed = $ok } | ConvertTo-Json)
                    } else {
                        $mode = 'dgpu'
                        if ($body.mode) { $mode = [string]$body.mode }
                        $r = Set-L51GpuPreference -AppPath $appPath -Mode $mode
                        Send-L51Response $ctx ([pscustomobject]@{ path = $r.Path; mode = $r.Mode; value = $r.Value } | ConvertTo-Json)
                    }
                } else {
                    $rows = @(Get-L51GpuPreferences | ForEach-Object { [pscustomobject]@{ path = $_.Path; mode = $_.Mode } })
                    Send-L51Response $ctx ([pscustomobject]@{ rows = $rows } | ConvertTo-Json -Depth 4)
                }
                continue
            }

            if ($path -eq '/api/processes') {
                $rows = @(Get-L51ProcessList | ForEach-Object { [pscustomobject]@{ name = $_.Name; path = $_.Path } })
                Send-L51Response $ctx ([pscustomobject]@{ rows = $rows } | ConvertTo-Json -Depth 3)
                continue
            }

            if ($path -eq '/api/log') {
                $logPath = Get-L51LogPath
                $text = ''
                if ($logPath -and (Test-Path $logPath)) {
                    # ซ่อนบรรทัด DEBUG ของ powercfg/fsutil ไม่ให้ท่วมหน้าจอ
                    $lines = @(Get-Content $logPath -Tail 300 -Encoding UTF8)
                    $quiet = @($lines | Where-Object { $_ -notmatch '\sDEBUG\s' } | Select-Object -Last 60)
                    if ($quiet.Count -eq 0) { $quiet = @($lines | Select-Object -Last 60) }
                    $text = $quiet -join "`n"
                }
                Send-L51Response $ctx ([pscustomobject]@{ log = $text } | ConvertTo-Json -Depth 3)
                continue
            }

            Send-L51Response $ctx '{"error":"not found"}' 'application/json' 404
        } catch {
            Send-L51Response $ctx (@{ error = $_.Exception.Message } | ConvertTo-Json) 'application/json' 500
        }
    }
} finally {
    try { $listener.Stop(); $listener.Close() } catch { }
    Write-Host '  หยุด Web GUI แล้ว' -ForegroundColor DarkGray
}
