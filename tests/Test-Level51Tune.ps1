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
    foreach ($needle in @('/api/status', '/api/apply', '/api/audit', '/api/latency', '/api/log')) {
        if ($html -notmatch [regex]::Escape($needle)) { throw "ไม่พบ $needle ใน dashboard" }
    }
    ($html -match '<!DOCTYPE html>') -and ($html.Length -gt 5000)
}

Test-Case 'web: log path อยู่ใน logs/ และสร้าง log ได้' {
    $p = Get-L51LogPath
    if (-not $p) { throw 'Get-L51LogPath คืนค่าว่าง' }
    $p -like '*\logs\l51-*.log'
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
