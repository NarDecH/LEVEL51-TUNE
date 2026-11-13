# LEVEL51-TUNE :: core engine
# ---------------------------------------------------------------------------
# PowerShell 5.1+ / 7.x compatible. No external dependencies.
# Every mutating action: validate -> snapshot -> apply -> verify -> report.
# All snapshots are JSON so `restore` can undo an apply exactly.
# ---------------------------------------------------------------------------

$script:L51Version = '1.0.4'
$script:L51Root = Split-Path -Parent $PSScriptRoot
$script:L51LogFile = $null
$script:L51Hardware = $null

. (Join-Path $PSScriptRoot 'Catalog.ps1')
. (Join-Path $PSScriptRoot 'Markdown.ps1')
. (Join-Path $PSScriptRoot 'Bench.ps1')
. (Join-Path $PSScriptRoot 'WebUI.ps1')

# ===========================================================================
# Infrastructure
# ===========================================================================

function Write-L51Log {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO', 'OK', 'WARN', 'ERR', 'STEP', 'DEBUG')][string]$Level = 'INFO'
    )
    $prefix = @{ INFO = '[i]'; OK = '[+]'; WARN = '[!]'; ERR = '[x]'; STEP = '[*]'; DEBUG = '[.]' }[$Level]
    $color = @{ INFO = 'Gray'; OK = 'Green'; WARN = 'Yellow'; ERR = 'Red'; STEP = 'Cyan'; DEBUG = 'DarkGray' }[$Level]
    if ($Level -ne 'DEBUG') { Write-Host ("{0} {1}" -f $prefix, $Message) -ForegroundColor $color }
    $logPath = Get-L51LogPath
    if ($logPath) {
        try {
            $line = '{0} {1,-5} {2}' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'), $Level, $Message
            Add-Content -Path $logPath -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
        } catch { }
    }
}

function Get-L51LogPath {
    $dir = Join-Path $script:L51Root 'logs'
    if (-not (Test-Path $dir)) {
        try { New-Item -ItemType Directory -Path $dir -Force | Out-Null } catch { return $null }
    }
    return (Join-Path $dir ('l51-{0}.log' -f (Get-Date).ToString('yyyyMMdd')))
}

function Get-L51Paths {
    $dirs = @{
        Root      = $script:L51Root
        Backups   = Join-Path $script:L51Root 'backups'
        Reports   = Join-Path $script:L51Root 'reports'
        Bench     = Join-Path $script:L51Root 'benchmarks'
        State     = Join-Path $script:L51Root 'state'
        Docs      = Join-Path $script:L51Root 'docs'
        DocsAsset = Join-Path $script:L51Root 'docs\assets'
    }
    foreach ($key in @('Backups', 'Reports', 'Bench', 'State')) {
        if (-not (Test-Path $dirs[$key])) { New-Item -ItemType Directory -Path $dirs[$key] -Force | Out-Null }
    }
    return $dirs
}

function Test-L51Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($id)
    return $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

function Assert-L51Admin {
    param([string]$Action = 'การกระทำนี้')
    if (-not (Test-L51Admin)) {
        throw "$Action ต้องใช้สิทธิ์ Administrator — เปิด PowerShell แบบ 'Run as administrator' หรือรันด้วย -Elevate"
    }
}

function Invoke-L51External {
    param(
        [Parameter(Mandatory)][string]$File,
        [string[]]$Arguments = @()
    )
    $cmd = $File
    if ($Arguments.Count -gt 0) { $cmd = "$File " + ($Arguments -join ' ') }
    Write-L51Log $cmd 'DEBUG'
    # คำสั่ง native ที่เขียน stderr จะกลายเป็น error record — ต้องไม่ให้ EAP=Stop
    # โยน exception ทิ้งก่อนที่เราจะได้อ่าน exit code
    $savedEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out = & $File @Arguments 2>&1 | Out-String
        $code = $LASTEXITCODE
        if ($null -eq $code) { $code = 0 }
    } catch {
        $out = $_.Exception.Message
        $code = 1
    } finally {
        $ErrorActionPreference = $savedEap
    }
    return [pscustomobject]@{ Output = $out; ExitCode = $code }
}

function ConvertTo-L51Dword {
    param($Value)
    try {
        $i = [int64]$Value
        if ($i -lt 0) { $i = $i + 4294967296 }
        return [uint32]$i
    } catch { return $null }
}

function Get-L51Version { return $script:L51Version }

# ===========================================================================
# Registry helpers (shared by Registry tweaks and Script tweaks)
# ===========================================================================

function Get-L51RegState {
    param([string]$Path, [string]$Name)
    try {
        $item = Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop
        return @{ Exists = $true; Value = $item.$Name; Kind = (Get-Item -Path $Path).GetValueKind($Name).ToString() }
    } catch {
        return @{ Exists = $false; Value = $null; Kind = $null }
    }
}

function Set-L51RegValue {
    param([string]$Path, [string]$Name, $Value, [string]$ValueType = 'DWord')
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    if ($ValueType -eq 'DWord') {
        $dw = ConvertTo-L51Dword $Value
        Set-ItemProperty -Path $Path -Name $Name -Value $dw -Type DWord -Force
        return
    }
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $ValueType -Force
}

function Restore-L51RegState {
    param([string]$Path, [string]$Name, $State)
    $exists = $false
    try { $exists = [bool]$State.Exists } catch { $exists = $false }
    if (-not $exists) {
        if (Test-Path $Path) { Remove-ItemProperty -Path $Path -Name $Name -Force -ErrorAction SilentlyContinue }
        return
    }
    $kind = 'DWord'
    try { if ($State.Kind) { $kind = [string]$State.Kind } } catch { }
    if ($kind -eq 'Unknown') { $kind = 'String' }
    Set-L51RegValue -Path $Path -Name $Name -Value $State.Value -ValueType $kind
}

function Compare-L51RegValue {
    param($Current, $Target, [string]$ValueType)
    if ($null -eq $Current) { return $false }
    if ($ValueType -eq 'DWord') {
        $a = ConvertTo-L51Dword $Current
        $b = ConvertTo-L51Dword $Target
        return ($a -ne $null -and $b -ne $null -and $a -eq $b)
    }
    return ([string]$Current -eq [string]$Target)
}

# ===========================================================================
# Power helpers
# ===========================================================================

function Get-L51PowerSchemes {
    $r = Invoke-L51External 'powercfg' @('-list')
    $list = @()
    foreach ($line in ($r.Output -split "`r?`n")) {
        if ($line -match '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})\s+\((.+?)\)') {
            $list += [pscustomobject]@{
                Guid    = $Matches[1].ToLower()
                Name    = $Matches[2].Trim()
                IsActive = ($line -match '\*')
            }
        }
    }
    return $list
}

function Get-L51ActiveScheme {
    $r = Invoke-L51External 'powercfg' @('-getactivescheme')
    if ($r.Output -match '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})\s+\((.+?)\)') {
        return [pscustomobject]@{ Guid = $Matches[1].ToLower(); Name = $Matches[2].Trim() }
    }
    return $null
}

function Get-L51PowerValue {
    param([string]$Subgroup, [string]$Setting, [string]$Scheme = 'SCHEME_CURRENT')
    $r = Invoke-L51External 'powercfg' @('-query', $Scheme, $Subgroup, $Setting)
    if ($r.ExitCode -ne 0) { return $null }
    $ac = $null; $dc = $null
    foreach ($line in ($r.Output -split "`r?`n")) {
        if ($line -match 'Current AC Power Setting Index:\s*0x([0-9a-fA-F]+)') { $ac = [Convert]::ToInt32($Matches[1], 16) }
        if ($line -match 'Current DC Power Setting Index:\s*0x([0-9a-fA-F]+)') { $dc = [Convert]::ToInt32($Matches[1], 16) }
    }
    if ($null -eq $ac -and $null -eq $dc) { return $null }
    return [pscustomobject]@{ AC = $ac; DC = $dc }
}

function Set-L51PowerValue {
    param([string]$Subgroup, [string]$Setting, $AC, $DC, [string]$Scheme = 'SCHEME_CURRENT', [switch]$Verify)
    $ok = $true
    if ($null -ne $AC) {
        $r = Invoke-L51External 'powercfg' @('-setacvalueindex', $Scheme, $Subgroup, $Setting, [string]$AC)
        if ($r.ExitCode -ne 0) { $ok = $false; Write-L51Log ("setacvalueindex failed: {0}/{1} = {2}" -f $Subgroup, $Setting, $AC) 'DEBUG' }
    }
    if ($null -ne $DC) {
        $r = Invoke-L51External 'powercfg' @('-setdcvalueindex', $Scheme, $Subgroup, $Setting, [string]$DC)
        if ($r.ExitCode -ne 0) { $ok = $false; Write-L51Log ("setdcvalueindex failed: {0}/{1} = {2}" -f $Subgroup, $Setting, $DC) 'DEBUG' }
    }
    # powercfg คืน exit 0 แม้ค่าไม่เปลี่ยน (เช่น setting ไม่มีใน scheme นี้) — ต้องอ่านกลับมายืนยัน
    if ($Verify -and $ok) {
        $cur = Get-L51PowerValue -Subgroup $Subgroup -Setting $Setting -Scheme $Scheme
        if ($null -eq $cur) {
            $ok = $false
        } else {
            if ($null -ne $AC -and $cur.AC -ne $AC) { $ok = $false }
            if ($null -ne $DC -and $cur.DC -ne $DC) { $ok = $false }
        }
    }
    return $ok
}

function New-L51TuneScheme {
    param([string]$BaseScheme, [string]$Profile)
    # switch ที่ถูกต้องของ powercfg คือ /DUPLICATESCHEME (-duplicatescheme)
    $r = Invoke-L51External 'powercfg' @('-duplicatescheme', $BaseScheme)
    if (-not ($r.Output -match '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})')) {
        throw "สร้าง power scheme ใหม่ไม่สำเร็จ (powercfg -duplicatescheme $BaseScheme, exit $($r.ExitCode)): $($r.Output.Trim())"
    }
    $guid = $Matches[1].ToLower()
    Invoke-L51External 'powercfg' @('-changename', $guid, "LEVEL51-TUNE $Profile") | Out-Null
    Invoke-L51External 'powercfg' @('-setactive', $guid) | Out-Null
    return $guid
}

function Remove-L51Scheme {
    param([string]$Guid)
    if (-not $Guid) { return }
    Invoke-L51External 'powercfg' @('-delete', $Guid) | Out-Null
}

# ===========================================================================
# Catalog access
# ===========================================================================

function Get-L51Catalog {
    param([string]$Category)
    $items = $script:L51TweakCatalog
    if ($Category) {
        $items = $items | Where-Object { $_.Category -eq $Category }
    }
    return $items
}

function Get-L51Profiles { return $script:L51ProfileCatalog }

function Get-L51Profile {
    param([string]$Id)
    return ($script:L51ProfileCatalog | Where-Object { $_.Id -eq $Id }) | Select-Object -First 1
}

function Get-L51ProfileTweaks {
    param([Parameter(Mandatory)][string]$Profile)
    return @($script:L51TweakCatalog | Where-Object { $_.Profiles -contains $Profile })
}

# ===========================================================================
# Hardware detection
# ===========================================================================

function Get-L51GpuState {
    $gpus = @()
    try {
        $raw = & nvidia-smi --query-gpu=name,driver_version,temperature.gpu,utilization.gpu,clocks.gr,clocks.mem,power.draw,power.default_limit,memory.total,memory.used --format=csv,noheader,nounits 2>$null
        foreach ($line in @($raw)) {
            if (-not $line) { continue }
            $p = @($line -split ',' | ForEach-Object { $_.Trim() })
            if ($p.Count -ge 9) {
                $used = ''
                if ($p.Count -gt 9) { $used = $p[9] }
                $gpus += [pscustomobject]@{
                    Name        = $p[0]
                    Driver      = $p[1]
                    TempC       = $p[2]
                    UtilPct     = $p[3]
                    ClockMHz    = $p[4]
                    MemClockMHz = $p[5]
                    PowerW      = $p[6]
                    PowerLimitW = $p[7]
                    MemTotalMB  = $p[8]
                    MemUsedMB   = $used
                    Source      = 'nvidia-smi'
                }
            }
        }
    } catch { }
    if ($gpus.Count -eq 0) {
        try {
            foreach ($v in (Get-CimInstance Win32_VideoController -ErrorAction Stop)) {
                $gpus += [pscustomobject]@{
                    Name = $v.Name; Driver = $v.DriverVersion; TempC = ''; UtilPct = ''
                    ClockMHz = ''; MemClockMHz = ''; PowerW = ''; PowerLimitW = ''
                    MemTotalMB = [string][math]::Round($v.AdapterRAM / 1MB, 0); MemUsedMB = ''
                    Source = 'wmi'
                }
            }
        } catch { }
    }
    return $gpus
}

function Get-L51ThermalZones {
    $zones = @()
    try {
        $raw = Get-CimInstance -Namespace 'root/wmi' -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction Stop
        foreach ($z in $raw) {
            $zones += [pscustomobject]@{
                Zone = $z.InstanceName
                TempC = [math]::Round(($z.CurrentTemperature / 10) - 273.15, 1)
            }
        }
    } catch { }
    return $zones
}

function Get-L51Hardware {
    param([switch]$Refresh)
    if ($script:L51Hardware -and -not $Refresh) { return $script:L51Hardware }

    $os = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $cs = Get-CimInstance Win32_ComputerSystem
    $memModules = @(Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue)
    $disks = @(Get-PhysicalDisk -ErrorAction SilentlyContinue)
    $battery = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue | Select-Object -First 1
    $battPct = $null
    if ($battery) { $battPct = $battery.EstimatedChargeRemaining }

    $hw = [pscustomobject]@{
        Computer       = $env:COMPUTERNAME
        Manufacturer   = $cs.Manufacturer
        Model          = $cs.Model
        OS             = $os.Caption
        Build          = $os.BuildNumber
        Arch           = $os.OSArchitecture
        InstallDate    = $os.InstallDate
        CpuName        = $cpu.Name
        CpuCores       = $cpu.NumberOfCores
        CpuThreads     = $cpu.NumberOfLogicalProcessors
        CpuMaxMHz      = $cpu.MaxClockSpeed
        CpuL3KB        = $cpu.L3CacheSize
        RamGB          = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
        RamFreeGB      = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
        RamModules     = @($memModules | ForEach-Object {
                [pscustomobject]@{ Slot = $_.DeviceLocator; GB = [math]::Round($_.Capacity / 1GB, 0); SpeedMHz = $_.Speed; Part = $_.PartNumber }
            })
        Gpus           = @(Get-L51GpuState)
        Disks          = @($disks | ForEach-Object {
                [pscustomobject]@{ Name = $_.FriendlyName; Media = $_.MediaType; GB = [math]::Round($_.Size / 1GB, 0); Bus = $_.BusType; Health = $_.HealthStatus }
            })
        BatteryPct     = $battPct
        PowerScheme    = Get-L51ActiveScheme
        IsAdmin        = Test-L51Admin
        Virtualization = [bool]$cpu.VirtualizationFirmwareEnabled
        HyperV         = (Get-CimInstance Win32_ComputerSystem).HypervisorPresent
        UptimeHours    = [math]::Round(((Get-Date) - $os.LastBootUpTime).TotalHours, 1)
    }
    $script:L51Hardware = $hw
    return $hw
}

# ===========================================================================
# Backup / state
# ===========================================================================

function Get-L51TweakSnapshot {
    param($Tweak, [string]$Scheme = 'SCHEME_CURRENT')
    $snap = [ordered]@{
        Id      = $Tweak.Id
        Title   = $Tweak.Title
        Type    = $Tweak.Type
        Risk    = $Tweak.Risk
        Category = $Tweak.Category
    }
    switch ($Tweak.Type) {
        'Power' {
            $cur = Get-L51PowerValue -Subgroup $Tweak.Subgroup -Setting $Tweak.Setting -Scheme $Scheme
            if ($null -eq $cur) {
                $snap.Supported = $false
                $snap.Previous = @{ AC = $null; DC = $null }
            } else {
                $snap.Supported = $true
                $snap.Previous = @{ AC = $cur.AC; DC = $cur.DC }
            }
            $snap.Target = @{ Subgroup = $Tweak.Subgroup; Setting = $Tweak.Setting; AC = $Tweak.AC; DC = $Tweak.DC }
        }
        'Registry' {
            $snap.Supported = $true
            $snap.Previous = Get-L51RegState -Path $Tweak.Path -Name $Tweak.Name
            $snap.Target = @{ Path = $Tweak.Path; Name = $Tweak.Name; Value = $Tweak.Value; ValueType = $Tweak.ValueType }
        }
        'Service' {
            $svc = Get-Service -Name $Tweak.ServiceName -ErrorAction SilentlyContinue
            if (-not $svc) {
                $snap.Supported = $false
                $snap.Previous = @{ Exists = $false }
            } else {
                $snap.Supported = $true
                $snap.Previous = @{ Exists = $true; StartMode = [string]$svc.StartMode; Status = [string]$svc.Status }
            }
            $snap.Target = @{ ServiceName = $Tweak.ServiceName; StartupType = $Tweak.StartupType }
        }
        'Script' {
            $snap.Supported = $true
            $ctx = @{ DryRun = $true; Profile = $null; Scheme = $Scheme; Previous = $null }
            $snap.Previous = @{ Note = 'script-detected at apply time' }
            $snap.Target = @{ Script = $true }
        }
    }
    return $snap
}

function Get-L51State {
    $paths = Get-L51Paths
    $file = Join-Path $paths.State 'last.json'
    if (-not (Test-Path $file)) { return $null }
    try { return (Get-Content -Path $file -Raw -Encoding UTF8 | ConvertFrom-Json) } catch { return $null }
}

function Save-L51State {
    param($State)
    $paths = Get-L51Paths
    $file = Join-Path $paths.State 'last.json'
    $State | ConvertTo-Json -Depth 8 | Set-Content -Path $file -Encoding UTF8
}

function New-L51BackupFile {
    param($Backup)
    $paths = Get-L51Paths
    $name = '{0}_apply-{1}.json' -f (Get-Date).ToString('yyyyMMdd-HHmmss'), $Backup.Profile
    $path = Join-Path $paths.Backups $name
    $Backup | ConvertTo-Json -Depth 10 | Set-Content -Path $path -Encoding UTF8
    return $path
}

function Invoke-L51Backup {
    param([string]$Profile = 'snapshot')
    $paths = Get-L51Paths
    $hw = Get-L51Hardware
    $scheme = $hw.PowerScheme
    $schemeGuid = $null
    if ($scheme) { $schemeGuid = $scheme.Guid }
    $backup = [ordered]@{
        Version          = 1
        Created          = (Get-Date).ToString('o')
        Computer         = $env:COMPUTERNAME
        Profile          = $Profile
        Hardware         = [ordered]@{ Cpu = $hw.CpuName; RamGB = $hw.RamGB; Model = $hw.Model; OS = $hw.OS }
        ActiveSchemeBefore = $schemeGuid
        BaseScheme       = $schemeGuid
        TuneScheme       = $null
        Tweaks           = @()
    }
    $name = '{0}_snapshot.json' -f (Get-Date).ToString('yyyyMMdd-HHmmss')
    $path = Join-Path $paths.Backups $name
    $backup | ConvertTo-Json -Depth 10 | Set-Content -Path $path -Encoding UTF8
    Write-L51Log "บันทึกสถานะเริ่มต้นไว้ที่ $path" 'OK'
    return $path
}

# ===========================================================================
# Apply
# ===========================================================================

function Invoke-L51Apply {
    param(
        [string]$Profile = 'custom',
        [switch]$DryRun,
        [string[]]$Include = @(),
        [switch]$Elevate,
        [string[]]$TweakIds = @()
    )

    $custom = (@($TweakIds).Count -gt 0)
    $prof = $null
    if (-not $custom) {
        $prof = Get-L51Profile -Id $Profile
        if (-not $prof) {
            $ids = ($script:L51ProfileCatalog | ForEach-Object { $_.Id }) -join ', '
            throw "ไม่รู้จักโปรไฟล์ '$Profile' (มี: $ids)"
        }
    } else {
        $Profile = 'custom'
        $prof = [pscustomobject]@{
            Id      = 'custom'
            TitleTh = 'ตั้งค่าเอง (custom)'
            Summary = ('{0} tweaks ที่เลือกจากหน้า Settings/CLI -Custom' -f @($TweakIds).Count)
        }
    }

    if ($Elevate -and -not (Test-L51Admin) -and -not $DryRun) {
        $exe = (Get-Process -Id $PID).Path
        $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $script:L51Root 'Level51Tune.ps1'), 'apply', '-Profile', $Profile)
        if ($custom) { $argList += @('-Custom') }
        if ($Include.Count -gt 0) { $argList += @('-Include', ($Include -join ',')) }
        Write-L51Log "กำลังเปิด PowerShell ใหม่แบบ Administrator..." 'STEP'
        Start-Process -FilePath $exe -ArgumentList $argList -Verb RunAs
        return [pscustomobject]@{ Profile = $Profile; Elevated = $true }
    }

    if (-not $DryRun) { Assert-L51Admin -Action 'การ apply tweaks' }

    $includeHigh = ($Include -contains 'high') -or ($Include -contains 'all')
    if ($custom) {
        $all = @(Get-L51Catalog | Where-Object { $TweakIds -contains $_.Id })
        if ($all.Count -eq 0) { throw 'ไม่มี tweak ที่ตรงกับรายการที่เลือก (ตรวจ Id ให้ถูกต้อง)' }
    } else {
        $all = Get-L51ProfileTweaks -Profile $Profile
    }
    $apply = @($all | Where-Object { $_.Risk -ne 'High' -or $includeHigh })
    $skipped = @($all | Where-Object { $_.Risk -eq 'High' -and -not $includeHigh })

    Write-L51Log ("โปรไฟล์: {0} ({1})" -f $prof.TitleTh, $prof.Id) 'STEP'
    Write-Host ("    {0}" -f $prof.Summary)
    Write-Host ("    tweaks: {0} จะปรับ, {1} ถูกข้าม (High risk)" -f $apply.Count, $skipped.Count)
    if ($DryRun) { Write-L51Log 'โหมด DryRun: ไม่มีการเปลี่ยนแปลงใด ๆ เกิดขึ้น' 'WARN' }

    # ---- resolve power scheme base
    $hw = Get-L51Hardware
    $activeBefore = $null
    if ($hw.PowerScheme) { $activeBefore = $hw.PowerScheme.Guid }
    $lastState = Get-L51State
    $baseScheme = $activeBefore
    if ($lastState -and $lastState.SchemeGuid -eq $activeBefore -and $lastState.BaseScheme) {
        $baseScheme = $lastState.BaseScheme
    }

    $hasPower = @($apply | Where-Object { $_.Type -eq 'Power' }).Count -gt 0
    $tuneGuid = $null
    if ($hasPower -and -not $DryRun) {
        $tuneGuid = New-L51TuneScheme -BaseScheme $baseScheme -Profile $Profile
        Write-L51Log "สร้าง power scheme ใหม่: LEVEL51-TUNE $Profile ($tuneGuid)" 'OK'
    } elseif ($hasPower) {
        $tuneGuid = 'SCHEME_CURRENT'
    }

    # ---- backup
    $backup = [ordered]@{
        Version            = 1
        Created            = (Get-Date).ToString('o')
        Computer           = $env:COMPUTERNAME
        Profile            = $Profile
        DryRun             = [bool]$DryRun
        Hardware           = [ordered]@{ Cpu = $hw.CpuName; RamGB = $hw.RamGB; Model = $hw.Model; OS = $hw.OS }
        ActiveSchemeBefore = $activeBefore
        BaseScheme         = $baseScheme
        TuneScheme         = $null
        Tweaks             = @()
    }
    if (-not $DryRun) { $backup.TuneScheme = $tuneGuid }

    foreach ($t in $all) {
        $snapScheme = 'SCHEME_CURRENT'
        if ($t.Type -eq 'Power' -and $baseScheme) { $snapScheme = $baseScheme }
        $backup.Tweaks += Get-L51TweakSnapshot -Tweak $t -Scheme $snapScheme
    }

    $backupPath = $null
    if (-not $DryRun) {
        $backupPath = New-L51BackupFile -Backup $backup
        Write-L51Log "snapshot: $backupPath" 'OK'
    }

    # ---- apply
    $results = @()
    $idx = 0
    foreach ($t in $apply) {
        $idx++
        $label = '{0,2}/{1} {2}' -f $idx, $apply.Count, $t.Id
        $res = [ordered]@{ Id = $t.Id; Title = $t.Title; Category = $t.Category; Risk = $t.Risk; Type = $t.Type; Status = 'OK'; Detail = '' }
        try {
            switch ($t.Type) {
                'Power' {
                    $supported = $null -ne (Get-L51PowerValue -Subgroup $t.Subgroup -Setting $t.Setting)
                    if (-not $supported) {
                        $res.Status = 'SKIP'
                        $res.Detail = "เครื่องนี้ไม่มี power setting $($t.Setting) (ไดรเวอร์/BIOS ไม่รองรับ)"
                    } elseif ($DryRun) {
                        $bits = @()
                        if ($null -ne $t.AC) { $bits += "setacvalueindex SCHEME_CURRENT $($t.Subgroup) $($t.Setting) $($t.AC)" }
                        if ($null -ne $t.DC) { $bits += "setdcvalueindex SCHEME_CURRENT $($t.Subgroup) $($t.Setting) $($t.DC)" }
                        $res.Detail = 'powercfg ' + ($bits -join ' + ')
                    } else {
                        $ok = Set-L51PowerValue -Subgroup $t.Subgroup -Setting $t.Setting -AC $t.AC -DC $t.DC -Scheme 'SCHEME_CURRENT' -Verify
                        if (-not $ok) {
                            $res.Status = 'WARN'
                            $res.Detail = 'ค่าไม่เปลี่ยนหลังสั่ง (อาจถูกซ่อนอยู่ — apply โปรไฟล์ที่มี win.unhide-power-settings ก่อน แล้วลองอีกครั้ง)'
                        }
                    }
                }
                'Registry' {
                    if ($DryRun) { $res.Detail = "set $($t.Path)\$($t.Name) = $($t.Value) ($($t.ValueType))" }
                    else { Set-L51RegValue -Path $t.Path -Name $t.Name -Value $t.Value -ValueType $t.ValueType }
                }
                'Service' {
                    $svc = Get-Service -Name $t.ServiceName -ErrorAction SilentlyContinue
                    if (-not $svc) { $res.Status = 'SKIP'; $res.Detail = "ไม่พบบริการ $($t.ServiceName)" }
                    elseif ($DryRun) { $res.Detail = "Set-Service $($t.ServiceName) -StartupType $($t.StartupType)" }
                    else {
                        Set-Service -Name $t.ServiceName -StartupType $t.StartupType -ErrorAction Stop
                        if ($t.StartupType -eq 'Disabled') { Stop-Service -Name $t.ServiceName -Force -ErrorAction SilentlyContinue }
                    }
                }
                'Script' {
                    $ctx = @{ DryRun = [bool]$DryRun; Profile = $Profile; Scheme = $tuneGuid; Previous = $null }
                    if ($DryRun) {
                        $res.Detail = 'script tweak (dry-run: ตรวจสถานะเท่านั้น)'
                    } else {
                        $ctx.Previous = & $t.ApplyScript $ctx
                    }
                }
            }
        } catch {
            $res.Status = 'FAIL'
            $res.Detail = $_.Exception.Message
        }
        $results += [pscustomobject]$res
        $color = @{ OK = 'Green'; WARN = 'Yellow'; SKIP = 'DarkGray'; FAIL = 'Red' }[$res.Status]
        Write-Host ("  {0,-48} {1}" -f $label, $res.Status) -ForegroundColor $color
        if ($res.Detail) { Write-Host ("      {0}" -f $res.Detail) -ForegroundColor DarkGray }
    }

    if ($hasPower -and -not $DryRun) {
        Invoke-L51External 'powercfg' @('-setactive', $tuneGuid) | Out-Null
        $state = [ordered]@{
            Profile    = $Profile
            AppliedAt  = (Get-Date).ToString('o')
            SchemeGuid = $tuneGuid
            BaseScheme = $baseScheme
            Backup     = $backupPath
        }
        Save-L51State -State $state
        if ($lastState -and $lastState.SchemeGuid -and $lastState.SchemeGuid -ne $tuneGuid) {
            Remove-L51Scheme -Guid $lastState.SchemeGuid
        }
    }

    # ---- summary
    $okCount = @($results | Where-Object { $_.Status -eq 'OK' }).Count
    $bad = @($results | Where-Object { $_.Status -in @('WARN', 'FAIL') })
    Write-Host ''
    Write-L51Log ("เสร็จสิ้น: {0} สำเร็จ, {1} มีปัญหา, {2} ข้าม" -f $okCount, $bad.Count, @($results | Where-Object { $_.Status -eq 'SKIP' }).Count) 'OK'
    if ($skipped.Count -gt 0) {
        Write-L51Log ("ข้าม tweaks เสี่ยงสูง {0} รายการ (ใช้ -Include high เพื่อเปิด): {1}" -f $skipped.Count, (($skipped | ForEach-Object { $_.Id }) -join ', ')) 'WARN'
    }
    if ($backupPath) { Write-L51Log "ย้อนกลับด้วย: .\Level51Tune.ps1 restore -BackupPath '$backupPath'" 'INFO' }
    if (@($apply | Where-Object { $_.Reboot }).Count -gt 0) {
        Write-L51Log 'มี tweaks ที่ต้อง restart จึงจะมีผลเต็มที่' 'WARN'
    }

    return [pscustomobject]@{
        Profile = $Profile
        DryRun  = [bool]$DryRun
        Backup  = $backupPath
        Scheme  = $tuneGuid
        Results = $results
        Skipped = $skipped
    }
}

# ===========================================================================
# Restore
# ===========================================================================

function Invoke-L51Restore {
    param([string]$BackupPath, [switch]$Elevate)
    $paths = Get-L51Paths

    if (-not $BackupPath) {
        $latest = Get-ChildItem -Path $paths.Backups -Filter '*_apply-*.json' -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if (-not $latest) { throw "ไม่พบไฟล์ backup ใน $($paths.Backups)" }
        $BackupPath = $latest.FullName
    }
    if (-not (Test-Path $BackupPath)) { throw "ไม่พบไฟล์: $BackupPath" }

    if ($Elevate -and -not (Test-L51Admin)) {
        $exe = (Get-Process -Id $PID).Path
        Start-Process -FilePath $exe -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $script:L51Root 'Level51Tune.ps1'), 'restore', '-BackupPath', "`"$BackupPath`"") -Verb RunAs
        return
    }
    Assert-L51Admin -Action 'การ restore'

    $data = Get-Content -Path $BackupPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Write-L51Log "กำลังย้อนกลับจาก $BackupPath (โปรไฟล์: $($data.Profile))" 'STEP'

    $results = @()
    foreach ($t in ($data.Tweaks | Sort-Object { $_.Id } -Descending)) {
        $res = [ordered]@{ Id = $t.Id; Status = 'OK'; Detail = '' }
        try {
            switch ($t.Type) {
                'Power' {
                    if ($null -eq $t.Previous.AC -and $null -eq $t.Previous.DC) {
                        $res.Status = 'SKIP'; $res.Detail = 'ไม่มีค่าที่บันทึกไว้'
                    } else {
                        Set-L51PowerValue -Subgroup $t.Target.Subgroup -Setting $t.Target.Setting -AC $t.Previous.AC -DC $t.Previous.DC -Scheme 'SCHEME_CURRENT' | Out-Null
                    }
                }
                'Registry' {
                    Restore-L51RegState -Path $t.Target.Path -Name $t.Target.Name -State $t.Previous
                }
                'Service' {
                    if ($t.Previous.Exists) {
                        Set-Service -Name $t.Target.ServiceName -StartupType $t.Previous.StartMode -ErrorAction Stop
                        if ($t.Previous.Status -eq 'Running') { Start-Service -Name $t.Target.ServiceName -ErrorAction SilentlyContinue }
                    } else { $res.Status = 'SKIP' }
                }
                default { $res.Status = 'SKIP'; $res.Detail = 'script tweak — ย้อนกลับอัตโนมัติไม่ได้ ใช้ค่าเริ่มต้นของ Windows' }
            }
        } catch {
            $res.Status = 'FAIL'; $res.Detail = $_.Exception.Message
        }
        $results += [pscustomobject]$res
        $color = @{ OK = 'Green'; SKIP = 'DarkGray'; FAIL = 'Red' }[$res.Status]
        Write-Host ("  {0,-48} {1}" -f $t.Id, $res.Status) -ForegroundColor $color
    }

    if ($data.ActiveSchemeBefore) {
        Invoke-L51External 'powercfg' @('-setactive', $data.ActiveSchemeBefore) | Out-Null
        Write-L51Log "เปลี่ยน power scheme กลับเป็น $($data.ActiveSchemeBefore)" 'OK'
    }
    if ($data.TuneScheme) { Remove-L51Scheme -Guid $data.TuneScheme }

    $failed = @($results | Where-Object { $_.Status -eq 'FAIL' }).Count
    Write-L51Log ("restore เสร็จ: {0} รายการ, ล้มเหลว {1}" -f $results.Count, $failed) $(if ($failed -gt 0) { 'WARN' } else { 'OK' })
    Write-L51Log 'หมายเหตุ: tweaks ประเภท Script (fsutil/netsh/bcdedit/MMCSS) ต้องคืนค่าเอง — ดู docs/12-ความปลอดภัย-สำรอง-ย้อนกลับ.md' 'INFO'
    return $results
}

# ===========================================================================
# Audit / status / report
# ===========================================================================

function Test-L51TweakApplied {
    param($Tweak)
    try {
        switch ($Tweak.Type) {
            'Power' {
                $cur = Get-L51PowerValue -Subgroup $Tweak.Subgroup -Setting $Tweak.Setting
                if ($null -eq $cur) { return $null }   # เครื่องนี้ไม่รองรับค่าดังกล่าว
                $acOk = ($null -eq $Tweak.AC) -or ($cur.AC -eq $Tweak.AC)
                $dcOk = ($null -eq $Tweak.DC) -or ($cur.DC -eq $Tweak.DC)
                return ($acOk -and $dcOk)
            }
            'Registry' {
                $s = Get-L51RegState -Path $Tweak.Path -Name $Tweak.Name
                if (-not $s.Exists) { return $false }
                return (Compare-L51RegValue -Current $s.Value -Target $Tweak.Value -ValueType $Tweak.ValueType)
            }
            'Service' {
                $svc = Get-Service -Name $Tweak.ServiceName -ErrorAction SilentlyContinue
                if (-not $svc) { return $false }
                return ([string]$svc.StartMode -eq $Tweak.StartupType)
            }
            'Script' {
                if (-not $Tweak.DetectScript) { return $null }
                $ctx = @{ DryRun = $true; Previous = $null }
                return [bool](& $Tweak.DetectScript $ctx)
            }
        }
    } catch { return $false }
    return $false
}

function Invoke-L51Audit {
    param([string]$Profile, [string]$Category, [switch]$IncludeHigh, [string[]]$TweakIds = @())

    $custom = (@($TweakIds).Count -gt 0)
    $tweaks = @()
    if ($custom) { $tweaks = @(Get-L51Catalog | Where-Object { $TweakIds -contains $_.Id }) }
    elseif ($Profile) { $tweaks = Get-L51ProfileTweaks -Profile $Profile }
    else { $tweaks = Get-L51Catalog -Category $Category }
    # tweak ที่ผู้ใช้เลือกเองให้ตรวจเสมอ (รวม High) เพราะเป็นการเลือกโดยเจตนา
    if (-not $IncludeHigh -and -not $custom) { $tweaks = @($tweaks | Where-Object { $_.Risk -ne 'High' }) }

    $rows = @()
    foreach ($t in $tweaks) {
        $state = Test-L51TweakApplied -Tweak $t
        $rows += [pscustomobject]@{
            Id       = $t.Id
            Category = $t.Category
            Risk     = $t.Risk
            Applied  = if ($null -eq $state) { '?' } elseif ($state) { 'YES' } else { 'no' }
            Reboot   = if ($t.Reboot) { 'reboot' } else { '' }
            Title    = $t.TitleTh
        }
    }
    return $rows
}

function Get-L51Status {
    $hw = Get-L51Hardware -Refresh
    $schemes = Get-L51PowerSchemes
    $active = $hw.PowerScheme
    $cpuState = Get-L51PowerValue -Subgroup 'SUB_PROCESSOR' -Setting 'PROCTHROTTLEMIN'
    $cpuMax = Get-L51PowerValue -Subgroup 'SUB_PROCESSOR' -Setting 'PROCTHROTTLEMAX'
    $boost = Get-L51PowerValue -Subgroup 'SUB_PROCESSOR' -Setting 'PERFBOOSTMODE'

    Write-Host ''
    Write-Host '  LEVEL51-TUNE :: สถานะระบบ' -ForegroundColor Cyan
    Write-Host ('  ' + ('-' * 72)) -ForegroundColor DarkGray
    Write-Host ("  เครื่อง      : {0}  ({1} {2})" -f $hw.Computer, $hw.Manufacturer, $hw.Model)
    Write-Host ("  ระบบปฏิบัติการ: {0} build {1}  [{2}]" -f $hw.OS, $hw.Build, $hw.Arch)
    Write-Host ("  CPU          : {0}" -f $hw.CpuName)
    Write-Host ("                 {0} cores / {1} threads · L3 {2} MB · base {3} MHz" -f $hw.CpuCores, $hw.CpuThreads, [math]::Round($hw.CpuL3KB / 1024, 0), $hw.CpuMaxMHz)
    Write-Host ("  RAM          : {0} GB (ว่าง {1} GB)" -f $hw.RamGB, $hw.RamFreeGB)
    foreach ($m in $hw.RamModules) {
        Write-Host ("                 {0}: {1} GB @ {2} MT/s  {3}" -f $m.Slot, $m.GB, $m.SpeedMHz, ($m.Part -replace '\s+', ''))
    }
    foreach ($g in $hw.Gpus) {
        Write-Host ("  GPU          : {0}  driver {1}" -f $g.Name, $g.Driver)
        if ($g.Source -eq 'nvidia-smi') {
            Write-Host ("                 {0} MHz core / {1} MHz mem · {2}°C · {3}% · {4} W · VRAM {5}/{6} MB" -f `
                    $g.ClockMHz, $g.MemClockMHz, $g.TempC, $g.UtilPct, $g.PowerW, $g.MemUsedMB, $g.MemTotalMB)
        }
    }
    foreach ($d in $hw.Disks) {
        Write-Host ("  Disk         : {0} · {1} GB · {2} · {3}" -f $d.Name, $d.GB, $d.Bus, $d.Health)
    }
    if ($null -ne $hw.BatteryPct) { Write-Host ("  แบตเตอรี่    : {0}%" -f $hw.BatteryPct) }
    Write-Host ("  Hypervisor   : {0}   ·  VT-x in firmware: {1}" -f $hw.HyperV, $hw.Virtualization)
    Write-Host ("  Admin        : {0}   ·  uptime {1} ชั่วโมง" -f $hw.IsAdmin, $hw.UptimeHours)
    Write-Host ''
    Write-Host '  Power scheme' -ForegroundColor Cyan
    foreach ($s in $schemes) {
        $mark = if ($s.IsActive) { '*' } else { ' ' }
        $name = $s.Name
        if ($s.IsActive) { Write-Host ("   {0} {1}  {2}" -f $mark, $s.Guid, $name) -ForegroundColor Green }
        else { Write-Host ("   {0} {1}  {2}" -f $mark, $s.Guid, $name) }
    }
    if ($cpuState) { Write-Host ("   processor min AC/DC : {0}% / {1}%" -f $cpuState.AC, $cpuState.DC) }
    if ($cpuMax) { Write-Host ("   processor max AC/DC : {0}% / {1}%" -f $cpuMax.AC, $cpuMax.DC) }
    if ($boost) { Write-Host ("   boost mode AC/DC    : {0} / {1}" -f $boost.AC, $boost.DC) }
    $zones = Get-L51ThermalZones
    foreach ($z in $zones) { Write-Host ("   thermal zone        : {0} = {1} C" -f $z.Zone, $z.TempC) }
    Write-Host ''
    $state = Get-L51State
    if ($state) {
        Write-Host ("  ใช้โปรไฟล์ล่าสุด: {0} เมื่อ {1}" -f $state.Profile, $state.AppliedAt) -ForegroundColor Yellow
        Write-Host ("  backup: {0}" -f $state.Backup) -ForegroundColor DarkGray
    } else {
        Write-Host '  ยังไม่เคย apply โปรไฟล์ใด (ดูโปรไฟล์ด้วย: .\Level51Tune.ps1 profiles)' -ForegroundColor DarkGray
    }
    Write-Host ''
    return $hw
}

function New-L51Report {
    param([string]$Path)
    $paths = Get-L51Paths
    if (-not $Path) {
        $Path = Join-Path $paths.Reports ('status-{0}.md' -f (Get-Date).ToString('yyyyMMdd-HHmmss'))
    }
    $hw = Get-L51Hardware -Refresh
    $schemes = Get-L51PowerSchemes
    $sb = New-Object System.Text.StringBuilder
    $null = $sb.AppendLine('# LEVEL51-TUNE :: รายงานสถานะเครื่อง')
    $null = $sb.AppendLine('')
    $null = $sb.AppendLine(('สร้างเมื่อ: {0}' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))
    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('## ฮาร์ดแวร์')
    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('| รายการ | ค่า |')
    $null = $sb.AppendLine('|---|---|')
    $null = $sb.AppendLine(("| เครื่อง | {0} ({1} {2}) |" -f $hw.Computer, $hw.Manufacturer, $hw.Model))
    $null = $sb.AppendLine(("| OS | {0} build {1} |" -f $hw.OS, $hw.Build))
    $null = $sb.AppendLine(("| CPU | {0} ({1}C/{2}T, L3 {3} MB) |" -f $hw.CpuName, $hw.CpuCores, $hw.CpuThreads, [math]::Round($hw.CpuL3KB / 1024, 0)))
    $null = $sb.AppendLine(("| RAM | {0} GB (ว่าง {1} GB) |" -f $hw.RamGB, $hw.RamFreeGB))
    foreach ($g in $hw.Gpus) { $null = $sb.AppendLine(("| GPU | {0} (driver {1}) |" -f $g.Name, $g.Driver)) }
    foreach ($d in $hw.Disks) { $null = $sb.AppendLine(("| Disk | {0} {1} GB {2} |" -f $d.Name, $d.GB, $d.Bus)) }
    $null = $sb.AppendLine(("| Battery | {0}% |" -f $hw.BatteryPct))
    $null = $sb.AppendLine(("| Admin | {0} |" -f $hw.IsAdmin))
    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('## Power scheme ที่มีอยู่')
    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('| Active | GUID | ชื่อ |')
    $null = $sb.AppendLine('|---|---|---|')
    foreach ($s in $schemes) {
        $mark = ''
        if ($s.IsActive) { $mark = '*' }
        $null = $sb.AppendLine(("| {0} | {1} | {2} |" -f $mark, $s.Guid, $s.Name))
    }
    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('## สถานะ tweaks (ทุกโปรไฟล์ ไม่รวม High risk)')
    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('| Tweak | Category | Risk | สถานะ | Title |')
    $null = $sb.AppendLine('|---|---|---|---|---|')
    foreach ($row in (Invoke-L51Audit)) {
        $null = $sb.AppendLine(("| {0} | {1} | {2} | {3} | {4} |" -f $row.Id, $row.Category, $row.Risk, $row.Applied, $row.Title))
    }
    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('## ประเมินเบื้องต้น')
    $null = $sb.AppendLine('')
    $pending = @(Invoke-L51Audit | Where-Object { $_.Applied -eq 'no' }).Count
    $null = $sb.AppendLine("- จำนวน tweaks ที่ยังไม่ถูกปรับ: $pending")
    $null = $sb.AppendLine('- โปรไฟล์ที่แนะนำ: performance (ถ้าเครื่องเย็นพอ) หรือ gaming (ถ้าเน้น latency)')
    $null = $sb.AppendLine('')
    $sb.ToString() | Set-Content -Path $Path -Encoding UTF8
    Write-L51Log "รายงานถูกเขียนที่ $Path" 'OK'
    return $Path
}

# ===========================================================================
# Documentation builder
# ===========================================================================

function Build-L51Docs {
    param([switch]$Quiet)
    $paths = Get-L51Paths
    if (-not (Test-Path $paths.Docs)) { throw "ไม่พบโฟลเดอร์ docs ที่ $($paths.Docs)" }

    $mdFiles = @(Get-ChildItem -Path $paths.Docs -Filter '*.md' | Sort-Object Name)
    if ($mdFiles.Count -eq 0) { throw 'ไม่มีไฟล์ .md ใน docs' }

    $nav = @()
    $rendered = @{}
    foreach ($f in $mdFiles) {
        if ($f.BaseName -ieq 'index') { continue }
        $text = Get-Content -Path $f.FullName -Raw -Encoding UTF8
        $title = $f.BaseName
        if ($text -match '(?m)^#\s+(.+)$') { $title = $Matches[1].Trim() }
        $html = Convert-L51Markdown -Markdown $text -DocTitle $title
        $rendered[$f.BaseName] = @{ Title = $title; Body = $html; File = $f.Name }
        $nav += [pscustomobject]@{ Id = $f.BaseName; Title = $title; Out = ($f.BaseName + '.html') }
    }

    $written = 0
    for ($i = 0; $i -lt $nav.Count; $i++) {
        $item = $nav[$i]
        $prev = if ($i -gt 0) { $nav[$i - 1] } else { $null }
        $next = if ($i -lt $nav.Count - 1) { $nav[$i + 1] } else { $null }
        $html = New-L51HtmlPage -Title $item.Title -Body $rendered[$item.Id].Body -Nav $nav -Current $item.Id -Prev $prev -Next $next
        Set-Content -Path (Join-Path $paths.Docs $item.Out) -Value $html -Encoding UTF8
        $written++
    }

    # hub page
    $hub = New-Object System.Text.StringBuilder
    $null = $hub.AppendLine('<h1>LEVEL51-TUNE · เอกสารประกอบ</h1>')
    $null = $hub.AppendLine('<p class="lead">ชุดเอกสารภาษาไทยสำหรับโปรแกรมปรับแต่งประสิทธิภาพเครื่อง LEVEL51 (i9-9900K + GTX 1060 + NVMe)</p>')
    $null = $hub.AppendLine('<div class="cards">')
    foreach ($item in $nav) {
        $null = $hub.AppendLine(('<a class="card" href="{0}"><span class="card-title">{1}</span></a>' -f $item.Out, $item.Title))
    }
    $null = $hub.AppendLine('</div>')
    $indexHtml = New-L51HtmlPage -Title 'สารบัญเอกสาร' -Body $hub.ToString() -Nav $nav -Current '' -Prev $null -Next $null
    Set-Content -Path (Join-Path $paths.Docs 'index.html') -Value $indexHtml -Encoding UTF8

    if (-not $Quiet) {
        Write-L51Log ("สร้างเอกสารแล้ว {0} หน้า + index.html ใน {1}" -f $written, $paths.Docs) 'OK'
    }
    return [pscustomobject]@{ Written = $written; Index = (Join-Path $paths.Docs 'index.html'); Nav = $nav }
}

function New-L51HtmlPage {
    param([string]$Title, [string]$Body, $Nav, [string]$Current, $Prev, $Next)
    $navHtml = New-Object System.Text.StringBuilder
    foreach ($n in $Nav) {
        $cls = 'nav-item'
        if ($n.Id -eq $Current) { $cls = 'nav-item active' }
        $null = $navHtml.AppendLine(('      <a class="{0}" href="{1}">{2}</a>' -f $cls, $n.Out, $n.Title))
    }
    $pagerHtml = ''
    if ($Prev -or $Next) {
        $p = if ($Prev) { '<a class="pager-prev" href="{0}">&larr; {1}</a>' -f $Prev.Out, $Prev.Title } else { '<span></span>' }
        $n = if ($Next) { '<a class="pager-next" href="{0}">{1} &rarr;</a>' -f $Next.Out, $Next.Title } else { '<span></span>' }
        $pagerHtml = "      <nav class=`"pager`">$p$n</nav>"
    }
    $template = @'
<!DOCTYPE html>
<html lang="th">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>__TITLE__ · LEVEL51-TUNE</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Noto+Sans+Thai:wght@400;600;700&family=JetBrains+Mono:wght@400;600&display=swap" rel="stylesheet">
<link rel="stylesheet" href="assets/style.css">
</head>
<body>
<div class="layout">
  <aside class="sidebar">
    <a class="brand" href="index.html"><span class="brand-mark">L51</span><span class="brand-text">LEVEL51-TUNE<small>performance toolkit</small></span></a>
    <nav class="nav">
__NAV__
    </nav>
    <div class="sidebar-foot">เอกสารภาษาไทย · v__VERSION__</div>
  </aside>
  <main class="content">
    <article class="doc">
__BODY__
    </article>
__PAGER__
    <footer class="doc-foot">LEVEL51-TUNE · จัดทำเพื่อเครื่อง LEVEL51 (N95TP6) · ใช้ด้วยความระมัดระวังและสำรองข้อมูลก่อนเสมอ</footer>
  </main>
</div>
</body>
</html>
'@
    return $template.Replace('__TITLE__', $Title).Replace('__NAV__', $navHtml.ToString().TrimEnd()).Replace('__BODY__', $Body).Replace('__PAGER__', $pagerHtml).Replace('__VERSION__', $script:L51Version)
}

# ===========================================================================
# Custom selection (tweak ที่ผู้ใช้เลือกเองจากหน้า Settings / CLI -Custom)
# ===========================================================================

function Get-L51CustomSelection {
    $file = Join-Path (Join-Path $script:L51Root 'state') 'custom.json'
    if (-not (Test-Path $file)) { return @() }
    try {
        $j = Get-Content $file -Raw -Encoding UTF8 | ConvertFrom-Json
        return @($j.Tweaks)
    } catch {
        Write-L51Log "อ่าน state/custom.json ไม่ได้: $($_.Exception.Message)" 'WARN'
        return @()
    }
}

function Save-L51CustomSelection {
    param([string[]]$TweakIds = @())

    $known = @(Get-L51Catalog | ForEach-Object { $_.Id })
    $valid = @($TweakIds | Where-Object { $known -contains $_ } | Select-Object -Unique)
    $unknown = @($TweakIds | Where-Object { $known -notcontains $_ })
    if ($unknown.Count -gt 0) { Write-L51Log ("ข้าม tweak ที่ไม่รู้จัก: {0}" -f ($unknown -join ', ')) 'WARN' }

    $dir = Join-Path $script:L51Root 'state'
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $obj = [ordered]@{ Saved = (Get-Date).ToString('o'); Count = $valid.Count; Tweaks = $valid }
    $file = Join-Path $dir 'custom.json'
    [IO.File]::WriteAllText($file, ($obj | ConvertTo-Json -Depth 4), (New-Object System.Text.UTF8Encoding($false)))
    Write-L51Log ("บันทึกการเลือก tweak {0} รายการ: {1}" -f $valid.Count, $file) 'OK'
    return $valid
}

# ===========================================================================
# Backup history (ใช้โดยหน้า "ประวัติ" ของ Web GUI และ CLI history)
# ===========================================================================

function Get-L51BackupHistory {
    param([int]$Limit = 25)

    $paths = Get-L51Paths
    $files = @(Get-ChildItem -Path $paths.Backups -Filter '*.json' -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First $Limit)

    $out = @()
    foreach ($f in $files) {
        $row = [ordered]@{
            File     = $f.Name
            Path     = $f.FullName
            SizeKB   = [math]::Round($f.Length / 1KB, 1)
            Modified = $f.LastWriteTime.ToString('o')
            Profile  = ''
            Created  = $f.LastWriteTime.ToString('o')
            Tweaks   = 0
            Restorable = ($f.Name -like '*_apply-*')
        }
        try {
            $j = Get-Content $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($j.Profile) { $row.Profile = [string]$j.Profile }
            if ($j.Created) { $row.Created = [string]$j.Created }
            $row.Tweaks = @($j.Tweaks).Count
        } catch {
            Write-L51Log "อ่าน backup $($f.Name) ไม่ได้: $($_.Exception.Message)" 'WARN'
        }
        $out += [pscustomobject]$row
    }
    return $out
}

# ===========================================================================
# Per-app GPU preference (HKCU\Software\Microsoft\DirectX\UserGpuPreferences)
# ===========================================================================

function Get-L51GpuPreferences {
    $key = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'
    $rows = @()
    if (-not (Test-Path $key)) { return $rows }
    $item = Get-ItemProperty -Path $key -ErrorAction SilentlyContinue
    if (-not $item) { return $rows }
    foreach ($p in $item.PSObject.Properties) {
        if ($p.Name -like 'PS*') { continue }
        $raw = [string]$p.Value
        $mode = 'auto'
        if ($raw -match 'GpuPreference=2') { $mode = 'dgpu' }
        elseif ($raw -match 'GpuPreference=1') { $mode = 'igpu' }
        $rows += [pscustomobject]@{ Path = $p.Name; Mode = $mode; Raw = $raw }
    }
    return $rows
}

function Set-L51GpuPreference {
    param(
        [Parameter(Mandatory)][string]$AppPath,
        [ValidateSet('dgpu', 'igpu', 'auto')][string]$Mode = 'dgpu'
    )

    if (-not (Test-Path $AppPath)) { throw "ไม่พบไฟล์: $AppPath" }
    $full = (Resolve-Path $AppPath).Path
    $key = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'
    if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }

    $val = 'GpuPreference=2;'
    if ($Mode -eq 'igpu') { $val = 'GpuPreference=1;' }
    if ($Mode -eq 'auto') { $val = 'GpuPreference=0;' }

    New-ItemProperty -Path $key -Name $full -Value $val -PropertyType String -Force | Out-Null
    Write-L51Log ("ตั้ง GPU preference: {0} -> {1}" -f $full, $Mode) 'OK'
    return [pscustomobject]@{ Path = $full; Mode = $Mode; Value = $val }
}

function Remove-L51GpuPreference {
    param([Parameter(Mandatory)][string]$AppPath)

    $key = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'
    if (-not (Test-Path $key)) { return $false }
    $item = Get-ItemProperty -Path $key -ErrorAction SilentlyContinue
    if (-not $item) { return $false }
    $match = @($item.PSObject.Properties | Where-Object { $_.Name -ne 'PSPath' -and $_.Name -ne 'PSParentPath' -and $_.Name -ne 'PSChildName' -and $_.Name -ne 'PSDrive' -and $_.Name -ne 'PSProvider' -and ($_.Name -eq $AppPath -or $_.Name -like ('*' + $AppPath)) })
    if ($match.Count -eq 0) { return $false }
    foreach ($m in $match) {
        Remove-ItemProperty -Path $key -Name $m.Name -Force -ErrorAction SilentlyContinue
        Write-L51Log ("ลบ GPU preference: {0}" -f $m.Name) 'OK'
    }
    return $true
}

function Get-L51ProcessList {
    $rows = @()
    try {
        $procs = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path } |
            Select-Object -Property Name, Path -Unique | Sort-Object Name
        foreach ($p in $procs) {
            $rows += [pscustomobject]@{ Name = $p.Name; Path = $p.Path }
        }
    } catch { }
    return $rows
}

# ===========================================================================
# คำแนะนำตามฮาร์ดแวร์จริง (ใช้โดย CLI recommend และหน้า GUI)
# ===========================================================================

function Get-L51Recommendation {
    param($Hardware)

    if (-not $Hardware) { $Hardware = Get-L51Hardware -Refresh }

    $notes = @()
    $warnings = @()
    $modules = @($Hardware.RamModules)
    $moduleCount = $modules.Count
    $channels = 1
    if ($moduleCount -ge 2) { $channels = 2 }

    # ---- RAM: ตัวคอขวดที่ tweak ซอฟต์แวร์แตะไม่ได้
    if ($moduleCount -eq 1) {
        $notes += ('แรมแท่งเดียว ({0} GB) = single channel · bandwidth ราวครึ่งของ dual channel — เพิ่มแท่งที่สองจะได้ผลมากกว่า tweak ซอฟต์แวร์ทั้งหมด' -f $modules[0].GB)
    } elseif ($moduleCount -ge 2) {
        $notes += ('แรม {0} แท่ง = dual channel' -f $moduleCount)
    } else {
        $notes += 'อ่านจำนวนแรมไม่ครบ (WMI ไม่ให้ข้อมูล module) — ตรวจด้วย CPU-Z'
    }

    # ---- CPU: คลาสเดสก์ท็อปในบอดี้โน้ตบุ๊ก = ความร้อนเป็นคอขวด
    $cpuClass = 'mobile'
    if ($Hardware.CpuCores -ge 8 -and $Hardware.CpuMaxMHz -ge 3500) {
        $cpuClass = 'desktop-class'
        $warnings += ('CPU {0} ({1}C/{2}T) เป็นคลาสเดสก์ท็อป — ระบายความร้อนจำกัด ไม่ควรใช้โปรไฟล์ max ค้างไว้' -f $Hardware.CpuName, $Hardware.CpuCores, $Hardware.CpuThreads)
    }

    # ---- GPU
    $dgpus = @($Hardware.Gpus | Where-Object { $_.Name -match 'NVIDIA|GeForce|Radeon|Arc' })
    $hasDgpu = $dgpus.Count -gt 0
    if ($hasDgpu) {
        $notes += ('มี dGPU: {0} — ถ้าเกมไปวิ่งบน iGPU ให้ตั้ง GPU ต่อแอปเป็น dgpu' -f $dgpus[0].Name)
    } else {
        $notes += 'ไม่พบ dGPU — โปรไฟล์ gaming/max ไม่มีประโยชน์บนเครื่องนี้'
    }

    # ---- ดิสก์
    $unhealthy = @($Hardware.Disks | Where-Object { $_.Health -and $_.Health -ne 'Healthy' })
    if ($unhealthy.Count -gt 0) {
        $warnings += ('ดิสก์มีสถานะไม่ปกติ: {0} — สำรองข้อมูลก่อนทำอะไรต่อ' -f (($unhealthy | ForEach-Object { "$($_.Name)=$($_.Health)" }) -join ', '))
    }
    $hdd = @($Hardware.Disks | Where-Object { $_.Media -eq 'HDD' })
    if ($hdd.Count -gt 0) { $notes += ('มี HDD {0} ลูก — เก็บเกม/โปรแกรมที่โหลดบ่อยไว้บน SSD' -f $hdd.Count) }

    # ---- แบตเตอรี่
    if ($null -ne $Hardware.BatteryPct -and $Hardware.BatteryPct -le 20) {
        $warnings += ('แบตเหลือ {0}% — โปรไฟล์ battery ลดการใช้ไฟ แต่ performance จะกินไฟมากกว่า' -f $Hardware.BatteryPct)
    }

    # ---- เลือกโปรไฟล์
    $profile = 'performance'
    if (-not $hasDgpu) { $profile = 'balanced' }
    $maxSafe = ($moduleCount -ge 2) -and ($cpuClass -ne 'desktop-class')
    if (-not $maxSafe -and $hasDgpu) { $notes += 'ยังไม่แนะนำโปรไฟล์ max บนเครื่องนี้ (ข้อจำกัดความร้อน/แรม) — ใช้ performance หรือ gaming' }

    $titleTh = $profile
    $prof = Get-L51Profile -Id $profile
    if ($prof) { $titleTh = $prof.TitleTh }

    return [pscustomobject]@{
        Machine      = (('{0} {1}' -f ([string]$Hardware.Manufacturer).Trim(), ([string]$Hardware.Model).Trim()).Trim())
        KnownMachine = ($Hardware.Model -match 'N95TP6')
        Profile      = $profile
        ProfileTitleTh = $titleTh
        CpuClass     = $cpuClass
        RamChannels  = $channels
        HasDedicatedGpu = $hasDgpu
        MaxProfileSafe  = $maxSafe
        Notes        = @($notes)
        Warnings     = @($warnings)
    }
}

# ===========================================================================
# ตรวจอัปเดตเวอร์ชัน (อ่านเฉพาะ metadata ของ release สาธารณะ ไม่ดาวน์โหลดอะไร)
# ===========================================================================

function Get-L51UpdateInfo {
    param([switch]$SkipNetwork, [string]$Repo = 'NarDecH/LEVEL51-TUNE')

    $local = Get-L51Version
    $info = [ordered]@{
        Local       = $local
        Latest      = $null
        Url         = $null
        PublishedAt = $null
        UpToDate    = $null
        Checked     = $false
        Error       = $null
    }
    if ($SkipNetwork) { return [pscustomobject]$info }

    $headers = @{ 'User-Agent' = 'LEVEL51-TUNE'; 'Accept' = 'application/vnd.github+json' }
    $latest = $null
    $url = $null
    $published = $null
    $errorText = $null

    try {
        $r = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -Headers $headers -TimeoutSec 10 -ErrorAction Stop
        $latest = [string]$r.tag_name
        $url = [string]$r.html_url
        $published = [string]$r.published_at
    } catch {
        $status = 0
        try { $status = [int]$_.Exception.Response.StatusCode } catch { }
        if ($status -eq 404) {
            # repo ยังไม่เคย publish release — ลองดู tag แทน
            try {
                $raw = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/tags" -Headers $headers -TimeoutSec 10 -ErrorAction Stop
                # JSON array ว่างจะถูกคืนเป็น $null — ต้องกรองทิ้งก่อนนับ
                $tags = @($raw | Where-Object { $_ -and $_.name })
                if ($tags.Count -gt 0) {
                    # API ไม่รับประกันลำดับ — เลือกเวอร์ชันสูงสุดเอง
                    $best = $null
                    $bestVer = $null
                    foreach ($t in $tags) {
                        $ver = $null
                        try { $ver = [version](([string]$t.name) -replace '^[vV]', '') } catch { }
                        if (-not $best) { $best = $t; $bestVer = $ver; continue }
                        if ($ver -and (-not $bestVer -or $ver -gt $bestVer)) { $best = $t; $bestVer = $ver }
                    }
                    $latest = [string]$best.name
                    $url = ('https://github.com/{0}/tree/{1}' -f $Repo, $latest)
                } else {
                    $errorText = 'ยังไม่มี release หรือ tag บน GitHub (repo ยังไม่เคย publish)'
                }
            } catch {
                $errorText = $_.Exception.Message
            }
        } else {
            $errorText = $_.Exception.Message
        }
    }

    if ($latest) {
        $info.Checked = $true
        $info.Latest = $latest
        $info.Url = $url
        $info.PublishedAt = $published
        $info.UpToDate = (($latest -replace '^[vV]', '') -eq $local)
    } elseif ($errorText) {
        $info.Error = $errorText
        Write-L51Log "ตรวจอัปเดตไม่สำเร็จ: $errorText" 'WARN'
    }

    return [pscustomobject]$info
}

# ===========================================================================
# Exports
# ===========================================================================

Export-ModuleMember -Function @(
    'Write-L51Log', 'Get-L51Paths', 'Get-L51LogPath', 'Test-L51Admin', 'Assert-L51Admin', 'Invoke-L51External',
    'Get-L51RegState', 'Set-L51RegValue', 'Restore-L51RegState', 'Compare-L51RegValue',
    'Get-L51PowerSchemes', 'Get-L51ActiveScheme', 'Get-L51PowerValue', 'Set-L51PowerValue',
    'New-L51TuneScheme', 'Remove-L51Scheme',
    'Get-L51Catalog', 'Get-L51Profiles', 'Get-L51Profile', 'Get-L51ProfileTweaks',
    'Get-L51Hardware', 'Get-L51GpuState', 'Get-L51ThermalZones',
    'Invoke-L51Apply', 'Invoke-L51Restore', 'Invoke-L51Audit', 'Invoke-L51Backup',
    'Get-L51State', 'Save-L51State', 'Get-L51Status', 'New-L51Report',
    'Test-L51TweakApplied', 'Build-L51Docs', 'Get-L51Version', 'Get-L51DashboardHtml',
    'Invoke-L51Bench', 'Get-L51BenchHistory', 'Compare-L51Bench', 'Measure-L51Latency', 'Get-L51LiveMetrics',
    'Get-L51CustomSelection', 'Save-L51CustomSelection',
    'Get-L51BackupHistory', 'Get-L51GpuPreferences', 'Set-L51GpuPreference', 'Remove-L51GpuPreference', 'Get-L51ProcessList',
    'Get-L51Recommendation', 'Get-L51UpdateInfo',
    'Convert-L51Markdown'
)
