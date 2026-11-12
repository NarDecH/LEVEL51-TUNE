<#
.SYNOPSIS
    ชุดทดสอบเบา ๆ ที่ไม่ต้องใช้สิทธิ์ Administrator และไม่แก้ระบบ
.DESCRIPTION
    ตรวจ catalog (schema/ความสอดคล้อง), markdown renderer, docs build
    และ dry-run apply ทุกโปรไฟล์
.EXAMPLE
    .\tests\Test-Level51Tune.ps1
#>
[CmdletBinding()]

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'src\Level51Tune.psm1') -Force -DisableNameChecking

try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }

$script:Pass = 0
$script:Fail = 0

function Test-Case {
    param([string]$Name, [scriptblock]$Body)
    try {
        $r = & $Body
        if ($r -eq $false) { throw 'returned false' }
        $script:Pass++
        Write-Host ("  PASS  {0}" -f $Name) -ForegroundColor Green
    } catch {
        $script:Fail++
        Write-Host ("  FAIL  {0} :: {1}" -f $Name, $_.Exception.Message) -ForegroundColor Red
    }
}

Write-Host ''
Write-Host '  LEVEL51-TUNE :: test suite' -ForegroundColor Cyan
Write-Host '  ---------------------------------------------------------' -ForegroundColor DarkGray

# ---------------------------------------------------------------- catalog
Test-Case 'catalog: มี tweaks อย่างน้อย 40 รายการ' {
    @(Get-L51Catalog).Count -ge 40
}

Test-Case 'catalog: Id ไม่ซ้ำกัน' {
    $ids = @(Get-L51Catalog | ForEach-Object { $_.Id })
    ($ids | Select-Object -Unique).Count -eq $ids.Count
}

Test-Case 'catalog: ทุก record มี field บังคับครบ' {
    $required = @('Id', 'Category', 'Title', 'TitleTh', 'Risk', 'Admin', 'Profiles', 'Type')
    foreach ($t in Get-L51Catalog) {
        foreach ($f in $required) {
            if (-not $t.ContainsKey($f)) { throw "$($t.Id) ขาด field $f" }
        }
    }
    $true
}

Test-Case 'catalog: Risk อยู่ในชุดที่อนุญาต' {
    foreach ($t in Get-L51Catalog) {
        if ($t.Risk -notin @('Low', 'Medium', 'High')) { throw "$($t.Id) Risk=$($t.Risk)" }
    }
    $true
}

Test-Case 'catalog: Type อยู่ในชุดที่อนุญาต' {
    foreach ($t in Get-L51Catalog) {
        if ($t.Type -notin @('Power', 'Registry', 'Service', 'Script')) { throw "$($t.Id) Type=$($t.Type)" }
    }
    $true
}

Test-Case 'catalog: Power tweak มี Subgroup/Setting' {
    foreach ($t in (Get-L51Catalog | Where-Object { $_.Type -eq 'Power' })) {
        if (-not $t.Subgroup -or -not $t.Setting) { throw "$($t.Id) ขาด Subgroup/Setting" }
        if ($null -eq $t.AC -and $null -eq $t.DC) { throw "$($t.Id) ไม่ได้ตั้งค่า AC หรือ DC" }
    }
    $true
}

Test-Case 'catalog: Registry tweak มี Path/Name/ValueType' {
    foreach ($t in (Get-L51Catalog | Where-Object { $_.Type -eq 'Registry' })) {
        if (-not $t.Path -or -not $t.Name -or -not $t.ValueType) { throw "$($t.Id) ขาด field" }
        if ($t.Path -notmatch '^(HKCU|HKLM|HKCR|HKU):\\') { throw "$($t.Id) Path ผิดรูปแบบ: $($t.Path)" }
        if ($t.ValueType -notin @('DWord', 'QWord', 'String', 'ExpandString', 'MultiString', 'Binary')) {
            throw "$($t.Id) ValueType=$($t.ValueType)"
        }
    }
    $true
}

Test-Case 'catalog: Service tweak มี ServiceName/StartupType' {
    foreach ($t in (Get-L51Catalog | Where-Object { $_.Type -eq 'Service' })) {
        if (-not $t.ServiceName) { throw "$($t.Id) ขาด ServiceName" }
        if ($t.StartupType -notin @('Disabled', 'Manual', 'Automatic', 'AutomaticDelayedStart')) { throw "$($t.Id) StartupType=$($t.StartupType)" }
    }
    $true
}

Test-Case 'catalog: Script tweak มี ApplyScript + RevertScript' {
    foreach ($t in (Get-L51Catalog | Where-Object { $_.Type -eq 'Script' })) {
        if (-not ($t.ApplyScript -is [scriptblock])) { throw "$($t.Id) ขาด ApplyScript" }
        if (-not ($t.RevertScript -is [scriptblock])) { throw "$($t.Id) ขาด RevertScript" }
    }
    $true
}

Test-Case 'catalog: ทุก tweak อยู่ในโปรไฟล์ที่มีจริง' {
    $profileIds = @(Get-L51Profiles | ForEach-Object { $_.Id })
    foreach ($t in Get-L51Catalog) {
        if (@($t.Profiles).Count -eq 0) { throw "$($t.Id) ไม่ได้อยู่ในโปรไฟล์ใดเลย" }
        foreach ($p in $t.Profiles) {
            if ($p -notin $profileIds) { throw "$($t.Id) อ้างโปรไฟล์ที่ไม่มี: $p" }
        }
    }
    $true
}

Test-Case 'profiles: มี 5 โปรไฟล์ และแต่ละอันมี tweaks' {
    $p = @(Get-L51Profiles)
    if ($p.Count -ne 5) { throw "พบ $($p.Count) โปรไฟล์" }
    foreach ($x in $p) { if (@(Get-L51ProfileTweaks -Profile $x.Id).Count -lt 3) { throw "$($x.Id) มี tweaks น้อยเกินไป" } }
    $true
}

# ---------------------------------------------------------------- markdown
Test-Case 'markdown: heading + paragraph + bold' {
    $h = Convert-L51Markdown -Markdown "# Title`n`nสวัสดี **โลก**"
    ($h -match '<h1 id="sec-1">Title</h1>') -and ($h -match '<strong>โลก</strong>')
}

Test-Case 'markdown: fenced code ไม่ถูกตีความเป็น markdown' {
    $fence = ([string][char]96) * 3
    $md = $fence + "powershell`nWrite-Host '**x**'`n" + $fence + "`n"
    $h = Convert-L51Markdown -Markdown $md
    ($h -match '<pre><code class="lang-powershell">') -and ($h -notmatch '<strong>')
}

Test-Case 'markdown: table 2 คอลัมน์ 2 แถว' {
    $md = "| A | B |`n|---|---|`n| 1 | 2 |"
    $h = Convert-L51Markdown -Markdown $md
    ($h -match '<th>A</th>') -and ($h -match '<td>2</td>') -and ($h -match '<table>')
}

Test-Case 'markdown: list และ hr' {
    $h = Convert-L51Markdown -Markdown "- a`n- b`n`n---`n"
    ($h -match '<ul>') -and ($h -match '<li>a</li>') -and ($h -match '<hr>')
}

Test-Case 'markdown: HTML ถูก escape' {
    $h = Convert-L51Markdown -Markdown 'ใช้ <script>alert(1)</script>'
    ($h -match '&lt;script&gt;') -and ($h -notmatch '<script>')
}

# ---------------------------------------------------------------- docs
Test-Case 'docs: build สร้าง html ครบทุก md' {
    $r = Build-L51Docs -Quiet
    $mdCount = @(Get-ChildItem (Join-Path $root 'docs') -Filter '*.md').Count
    if ($r.Written -lt ($mdCount - 1)) { throw "เขียน $($r.Written) จาก $mdCount md" }
    if (-not (Test-Path $r.Index)) { throw 'ไม่พบ index.html' }
    $true
}

Test-Case 'docs: html ที่ได้มี template ครบและไม่มี placeholder ค้าง' {
    $bad = 0
    foreach ($f in Get-ChildItem (Join-Path $root 'docs') -Filter '*.html') {
        $t = Get-Content $f.FullName -Raw -Encoding UTF8
        if ($t -notmatch '<!DOCTYPE html>') { $bad++; continue }
        if ($t -match '__TITLE__|__NAV__|__BODY__') { $bad++ }
        if ($t -notmatch 'assets/style.css') { $bad++ }
    }
    if ($bad -gt 0) { throw "$bad ไฟล์มีปัญหา" }
    $true
}

Test-Case 'docs: style.css มีอยู่' {
    Test-Path (Join-Path $root 'docs\assets\style.css')
}

# ---------------------------------------------------------------- dry run
Test-Case 'apply -DryRun ทุกโปรไฟล์: ไม่มี FAIL และไม่แก้ระบบ' {
    foreach ($p in Get-L51Profiles) {
        $r = Invoke-L51Apply -Profile $p.Id -DryRun
        $fail = @($r.Results | Where-Object { $_.Status -eq 'FAIL' })
        if ($fail.Count -gt 0) {
            throw ("{0}: {1}" -f $p.Id, (($fail | ForEach-Object { "$($_.Id)=$($_.Detail)" }) -join ' | '))
        }
    }
    $true
}

Test-Case 'apply -DryRun: ไม่สร้างไฟล์ backup/state' {
    $paths = Get-L51Paths
    $before = @(Get-ChildItem $paths.Backups -Filter '*.json' -ErrorAction SilentlyContinue).Count
    $null = Invoke-L51Apply -Profile 'balanced' -DryRun
    $after = @(Get-ChildItem $paths.Backups -Filter '*.json' -ErrorAction SilentlyContinue).Count
    $before -eq $after
}

Test-Case 'audit: คืนผลครบทุก tweak ของโปรไฟล์ (ไม่รวม High risk)' {
    $rows = @(Invoke-L51Audit -Profile 'balanced')
    $expected = @(Get-L51ProfileTweaks -Profile 'balanced' | Where-Object { $_.Risk -ne 'High' })
    $rows.Count -eq $expected.Count
}

Test-Case 'web: dashboard HTML มี token placeholder และ element หลัก' {
    $html = Get-L51DashboardHtml
    if ($html -notmatch '__TOKEN__') { throw 'ไม่พบ placeholder __TOKEN__' }
    foreach ($needle in @('/api/status', '/api/apply', '/api/audit', '/api/latency', '/api/log', '/api/tweaks', '/api/settings', '/api/live', '/api/compare', '/api/backups', '/api/gpu-prefs', '/api/processes', '/api/update')) {
        if ($html -notmatch [regex]::Escape($needle)) { throw "ไม่พบ $needle ใน dashboard" }
    }
    ($html -match '<!DOCTYPE html>') -and ($html.Length -gt 5000)
}

Test-Case 'web: JS ใน dashboard ไม่มี string ที่ขาด quotation' {
    $html = Get-L51DashboardHtml
    $start = $html.IndexOf('<script>')
    $end = $html.LastIndexOf('</script>')
    if ($start -lt 0 -or $end -le $start) { throw 'ไม่พบ block <script>' }
    $script = $html.Substring($start, $end - $start)
    $bad = @()
    $n = 0
    foreach ($line in ($script -split "`n")) {
        $n++
        $clean = $line.Replace('\', '')
        $count = ([regex]::Matches($clean, "'")).Count
        if ($count % 2 -ne 0) { $bad += ("บรรทัด {0}: {1}" -f $n, $line.Trim()) }
    }
    if ($bad.Count -gt 0) { throw ($bad -join ' | ') }
    $true
}

Test-Case 'web: log path อยู่ใน logs/ และสร้าง log ได้' {
    $p = Get-L51LogPath
    if (-not $p) { throw 'Get-L51LogPath คืนค่าว่าง' }
    $p -like '*\logs\l51-*.log'
}

Test-Case 'settings: บันทึก/อ่านรายการ tweak ที่เลือกได้' {
    $dir = Join-Path $root 'state'
    $file = Join-Path $dir 'custom.json'
    $hadFile = Test-Path $file
    $backup = $null
    if ($hadFile) { $backup = Get-Content $file -Raw -Encoding UTF8 }
    try {
        $ids = @('gpu.hags', 'win.gamemode-on')
        $saved = @(Save-L51CustomSelection -TweakIds $ids)
        if ($saved.Count -ne 2) { throw "บันทึกได้ $($saved.Count) รายการ" }
        $back = @(Get-L51CustomSelection)
        if ($back.Count -ne 2) { throw "อ่านกลับได้ $($back.Count) รายการ" }
    } finally {
        if ($hadFile) { [IO.File]::WriteAllText($file, $backup, (New-Object Text.UTF8Encoding($false))) }
        elseif (Test-Path $file) { Remove-Item $file -Force }
    }
    $true
}

Test-Case 'apply -TweakIds: dry-run เฉพาะที่เลือกทำงานได้' {
    $ids = @(Get-L51Catalog | Select-Object -First 3 | ForEach-Object { $_.Id })
    $r = Invoke-L51Apply -TweakIds $ids -DryRun
    if (-not $r) { throw 'ไม่ได้ผลลัพธ์' }
    if (@($r.Results).Count -ne 3) { throw "ได้ $(@($r.Results).Count) ผล ลคาด 3" }
    $r.Profile -eq 'custom'
}

Test-Case 'audit -TweakIds: ตรวจสถานะเฉพาะรายการที่เลือกได้' {
    $ids = @('gpu.hags', 'power.cpu.min100')
    $rows = @(Invoke-L51Audit -TweakIds $ids)
    if ($rows.Count -ne 2) { throw "ได้ $($rows.Count) แถว" }
    foreach ($r in $rows) {
        if ($r.Applied -notin @('YES', 'no', '?')) { throw "สถานะไม่ถูกต้อง: $($r.Applied)" }
    }
    $true
}

Test-Case 'recommend: คืนโปรไฟล์และคำแนะนำครบถ้วน' {
    $r = Get-L51Recommendation
    if (-not $r) { throw 'ไม่ได้ผลลัพธ์' }
    if (-not $r.Profile) { throw 'ไม่มีโปรไฟล์ที่แนะนำ' }
    $prof = Get-L51Profile -Id $r.Profile
    if (-not $prof) { throw "โปรไฟล์ที่แนะนำไม่มีจริง: $($r.Profile)" }
    if ($r.RamChannels -notin @(1, 2)) { throw "RamChannels=$($r.RamChannels)" }
    if (-not $r.Notes -or @($r.Notes).Count -eq 0) { throw 'ไม่มีหมายเหตุ' }
    $true
}

Test-Case 'update: -SkipNetwork ไม่ยิงเน็ตและคืนโครงสร้างครบ' {
    $u = Get-L51UpdateInfo -SkipNetwork
    if (-not $u.Local) { throw 'ไม่มีเวอร์ชันในเครื่อง' }
    if ($u.Checked) { throw 'ควรเป็น Checked=false เมื่อ SkipNetwork' }
    $u.Local -eq (Get-L51Version)
}

Test-Case 'history: อ่านรายการ backup ได้ (ถ้ามี)' {
    $rows = @(Get-L51BackupHistory -Limit 5)
    if ($rows.Count -gt 0) {
        foreach ($r in $rows) {
            if (-not $r.File) { throw 'แถวที่ไม่มีชื่อไฟล์' }
            if ($r.Tweaks -lt 0) { throw 'จำนวน tweaks ติดลบ' }
        }
    }
    $true
}

Test-Case 'gpuprefs: เพิ่ม/อ่าน/ลบ preference ได้ (HKCU, ไฟล์ชั่วคราว)' {
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ('l51-test-' + [guid]::NewGuid().ToString('N') + '.exe')
    Set-Content -Path $tmp -Value 'stub' -Encoding ASCII
    try {
        $set = Set-L51GpuPreference -AppPath $tmp -Mode 'dgpu'
        if ($set.Mode -ne 'dgpu') { throw 'ตั้งค่าไม่สำเร็จ' }
        $found = @(Get-L51GpuPreferences | Where-Object { $_.Path -eq $set.Path })
        if ($found.Count -ne 1) { throw "อ่านกลับไม่พบ ($($found.Count))" }
        if ($found[0].Mode -ne 'dgpu') { throw "โหมดที่อ่านได้: $($found[0].Mode)" }
        $removed = Remove-L51GpuPreference -AppPath $set.Path
        if (-not $removed) { throw 'ลบไม่สำเร็จ' }
        $after = @(Get-L51GpuPreferences | Where-Object { $_.Path -eq $set.Path })
        if ($after.Count -ne 0) { throw 'ยังพบรายการหลังลบ' }
    } finally {
        if (Test-Path $tmp) { Remove-Item $tmp -Force }
        try { Remove-L51GpuPreference -AppPath $tmp | Out-Null } catch { }
    }
    $true
}

Test-Case 'scripts: tray / package parse ได้' {
    foreach ($rel in @('Level51Tune.Tray.ps1', 'tools\Build-Package.ps1')) {
        $p = Join-Path $root $rel
        if (-not (Test-Path $p)) { throw "ไม่พบ $rel" }
        $errors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile($p, [ref]$null, [ref]$errors)
        if ($errors -and $errors.Count -gt 0) { throw "${rel}: $($errors[0].Message)" }
    }
    $true
}

Test-Case 'live: อ่านค่าสด (CPU load / clock / RAM) ได้' {
    $m = Get-L51LiveMetrics
    if (-not $m) { throw 'ไม่ได้ผลลัพธ์' }
    if ($null -eq $m.CpuLoadPct) { throw 'CPU load เป็น null' }
    if ($null -eq $m.RamUsedGB) { throw 'RAM used เป็น null' }
    ($m.CpuLoadPct -ge 0) -and ($m.CpuLoadPct -le 100) -and ($m.RamUsedGB -gt 0)
}

Test-Case 'latency: วัด counter ได้และให้ค่าตัวเลข 4 รายการ' {
    $r = Measure-L51Latency -Seconds 3
    if (-not $r -or -not $r.Counters) { throw 'ไม่ได้ผลลัพธ์' }
    if (@($r.Counters).Count -lt 4) { throw "ได้ $(@($r.Counters).Count) แถว" }
    foreach ($row in @($r.Counters)) {
        if (-not $row.Counter) { throw 'แถวที่ไม่มีชื่อ counter' }
    }
    ($null -ne $r.DpcAvg) -and ($r.DpcAvg -ge 0)
}

Test-Case 'hardware: ตรวจ CPU/RAM ได้' {
    $hw = Get-L51Hardware -Refresh
    ($hw.CpuCores -gt 0) -and ($hw.RamGB -gt 0) -and $hw.CpuName
}

Write-Host '  ---------------------------------------------------------' -ForegroundColor DarkGray
Write-Host ("  ผลลัพธ์: {0} ผ่าน, {1} ไม่ผ่าน" -f $script:Pass, $script:Fail) -ForegroundColor $(if ($script:Fail -eq 0) { 'Green' } else { 'Red' })
Write-Host ''
if ($script:Fail -gt 0) { exit 1 }
exit 0
