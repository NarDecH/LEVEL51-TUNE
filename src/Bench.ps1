# LEVEL51-TUNE :: micro benchmark
# ---------------------------------------------------------------------------
# Purpose: give the user a *measurement* so tuning claims can be checked.
# Not a synthetic 3D benchmark - CPU math, memory copy, sequential NVMe IO.
# Results append to benchmarks/history.jsonl so before/after can be compared.
# ---------------------------------------------------------------------------

function Get-L51BenchHistory {
    param([int]$Last = 10)
    $paths = Get-L51Paths
    $file = Join-Path $paths.Bench 'history.jsonl'
    if (-not (Test-Path $file)) { return @() }
    $all = @()
    foreach ($line in (Get-Content -Path $file -Encoding UTF8)) {
        if (-not $line.Trim()) { continue }
        try { $all += ($line | ConvertFrom-Json) } catch { }
    }
    return @($all | Select-Object -Last $Last)
}

function Invoke-L51Bench {
    param(
        [int]$Seconds = 3,
        [string]$Label = 'run',
        [int]$SizeMB = 256
    )

    $hw = Get-L51Hardware
    $threads = [Environment]::ProcessorCount
    Write-L51Log ("เริ่ม benchmark: CPU {0} threads x {1}s · memory 256 MB · disk {2} MB" -f $threads, $Seconds, $SizeMB) 'STEP'

    # ---- CPU throughput ---------------------------------------------------
    # ใช้ SHA-256 บนบัฟเฟอร์ 4 MB ต่อรอบ: งานหนักอยู่ใน native code ทำให้
    # ผลที่ได้สะท้อนความเร็ว CPU จริง ไม่ใช่ความเร็วของ PowerShell interpreter
    $chunkMB = 4
    $hashBuf = New-Object byte[] ($chunkMB * 1MB)
    [System.Random]::new(2024).NextBytes($hashBuf)
    $worker = {
        param($Buffer, $Seconds)
        $sha = [System.Security.Cryptography.SHA256]::Create()
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $rounds = 0
        while ($sw.Elapsed.TotalSeconds -lt $Seconds) { $null = $sha.ComputeHash($Buffer); $rounds++ }
        return $rounds
    }

    # warm-up สั้น ๆ เพื่อให้ clock ขึ้นถึง boost ก่อนวัดจริง
    $null = & $worker $hashBuf 1
    $swAll = [Diagnostics.Stopwatch]::StartNew()
    $roundsSingle = [int64](& $worker $hashBuf $Seconds)
    $secSingle = $swAll.Elapsed.TotalSeconds
    $cpu1 = [math]::Round($roundsSingle * $chunkMB / $secSingle, 0)
    Write-Host ("  CPU 1 thread   : {0,10:N0} MB/s" -f $cpu1) -ForegroundColor Gray

    # ---- CPU all threads --------------------------------------------------
    $pool = [runspacefactory]::CreateRunspacePool(1, $threads)
    $pool.Open()
    $handles = @()
    $swAll = [Diagnostics.Stopwatch]::StartNew()
    $workerText = $worker.ToString()
    for ($i = 0; $i -lt $threads; $i++) {
        $ps = [powershell]::Create()
        $ps.RunspacePool = $pool
        $null = $ps.AddScript($workerText).AddArgument($hashBuf).AddArgument($Seconds)
        $handles += [pscustomobject]@{ Shell = $ps; Handle = $ps.BeginInvoke() }
    }
    $total = 0
    foreach ($h in $handles) {
        try {
            $out = $h.Shell.EndInvoke($h.Handle)
            if ($out -and @($out).Count -gt 0) { $total += [int64]@($out)[0] }
        } catch {
            Write-L51Log ("worker ล้มเหลว: {0}" -f $_.Exception.Message) 'DEBUG'
        } finally {
            $h.Shell.Dispose()
        }
    }
    $secMulti = $swAll.Elapsed.TotalSeconds
    $pool.Close()
    $pool.Dispose()
    $cpuN = [math]::Round($total * $chunkMB / $secMulti, 0)
    # efficiency เทียบกับจำนวน *physical* cores (SMT ไม่เพิ่ม throughput เต็ม 100%)
    $physCores = [int]$hw.CpuCores
    if ($physCores -le 0) { $physCores = $threads }
    $scaling = 0
    if ($cpu1 -gt 0) { $scaling = [math]::Round(($cpuN / $cpu1) / $physCores * 100, 0) }
    Write-Host ("  CPU {0,2} threads : {1,10:N0} MB/s  (efficiency {2}% ของ {3} physical cores)" -f $threads, $cpuN, $scaling, $physCores) -ForegroundColor Gray
    $hashBuf = $null

    # ---- memory copy ------------------------------------------------------
    $mb = 256
    $bufA = New-Object byte[] ($mb * 1MB)
    $bufB = New-Object byte[] ($mb * 1MB)
    [System.Random]::new(1234).NextBytes($bufA)
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $rounds = 4
    for ($r = 0; $r -lt $rounds; $r++) { [System.Buffer]::BlockCopy($bufA, 0, $bufB, 0, $bufA.Length) }
    $sw.Stop()
    $memMBps = [math]::Round(($mb * $rounds) / $sw.Elapsed.TotalSeconds, 0)
    Write-Host ("  Memory copy    : {0,10:N0} MB/s" -f $memMBps) -ForegroundColor Gray
    $bufA = $null; $bufB = $null
    [GC]::Collect()

    # ---- disk sequential write / read ------------------------------------
    $sizeBytes = [int64]$SizeMB * 1MB
    $tmp = Join-Path $env:TEMP ('l51-bench-{0}.bin' -f (Get-Random))
    $chunk = New-Object byte[] (4MB)
    [System.Random]::new(42).NextBytes($chunk)
    $writeMBps = 0
    $readMBps = 0
    try {
        $fs = [System.IO.File]::Create($tmp, 4MB, [System.IO.FileOptions]::SequentialScan)
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $written = 0
        while ($written -lt $sizeBytes) { $fs.Write($chunk, 0, $chunk.Length); $written += $chunk.Length }
        $fs.Flush($true)
        $sw.Stop()
        $fs.Close()
        $writeMBps = [math]::Round($SizeMB / $sw.Elapsed.TotalSeconds, 0)

        $fsr = [System.IO.File]::OpenRead($tmp)
        $rbuf = New-Object byte[] (4MB)
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $read = 0
        while (($n = $fsr.Read($rbuf, 0, $rbuf.Length)) -gt 0) { $read += $n }
        $sw.Stop()
        $fsr.Close()
        $readMBps = [math]::Round(($read / 1MB) / $sw.Elapsed.TotalSeconds, 0)
    } catch {
        Write-L51Log "disk benchmark ล้มเหลว: $($_.Exception.Message)" 'WARN'
    } finally {
        if (Test-Path $tmp) { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
    }
    Write-Host ("  Disk write     : {0,10:N0} MB/s" -f $writeMBps) -ForegroundColor Gray
    Write-Host ("  Disk read      : {0,10:N0} MB/s  (อาจได้จาก cache)" -f $readMBps) -ForegroundColor Gray

    # ---- GPU snapshot -----------------------------------------------------
    $gpu = @(Get-L51GpuState) | Where-Object { $_.Source -eq 'nvidia-smi' } | Select-Object -First 1
    if ($gpu) { Write-Host ("  GPU            : {0} · {1} MHz · {2} C" -f $gpu.Name, $gpu.ClockMHz, $gpu.TempC) -ForegroundColor Gray }

    $gpuClock = ''
    $gpuTemp = ''
    $schemeName = ''
    if ($gpu) { $gpuClock = $gpu.ClockMHz; $gpuTemp = $gpu.TempC }
    if ($hw.PowerScheme) { $schemeName = $hw.PowerScheme.Name }
    $activeProfile = ''
    $state = Get-L51State
    if ($state) { $activeProfile = [string]$state.Profile }

    $result = [pscustomobject]@{
        Timestamp   = (Get-Date).ToString('o')
        Label       = $Label
        CpuThreads  = $threads
        CpuSingleMBps = $cpu1
        CpuMultiMBps  = $cpuN
        CoreEffPct  = $scaling
        MemMBps     = $memMBps
        DiskWriteMB = $writeMBps
        DiskReadMB  = $readMBps
        GpuClockMHz = $gpuClock
        GpuTempC    = $gpuTemp
        PowerScheme = $schemeName
        Profile     = $activeProfile
    }

    $paths = Get-L51Paths
    $file = Join-Path $paths.Bench 'history.jsonl'
    Add-Content -Path $file -Value ($result | ConvertTo-Json -Compress) -Encoding UTF8
    Write-L51Log "บันทึกผลไว้ใน $file (label: $Label)" 'OK'
    return $result
}

function Measure-L51Latency {
    param([int]$Seconds = 20)

    $counters = @(
        '\Processor Information(_Total)\% DPC Time',
        '\Processor Information(_Total)\% Interrupt Time',
        '\Processor Information(_Total)\% Idle Time',
        '\System\Context Switches/sec'
    )
    Write-L51Log ("เก็บตัวอย่าง latency {0} วินาที (DPC / interrupt / context switch)" -f $Seconds) 'STEP'

    $data = $null
    try {
        $data = Get-Counter -Counter $counters -SampleInterval 1 -MaxSamples $Seconds -ErrorAction Stop
    } catch {
        throw "อ่าน performance counter ไม่ได้: $($_.Exception.Message)"
    }

    $rows = foreach ($group in ($data.CounterSamples | Group-Object Path)) {
        $vals = @($group.Group | ForEach-Object { [double]$_.CookedValue })
        # ตัด prefix \\<host>\\ ออกจาก counter path เพื่อให้อ่านง่าย
        $name = $group.Name
        $name = [regex]::Replace($name, '^\\\\[^\\]+\\', '')
        [pscustomobject]@{
            Counter = $name
            Avg     = [math]::Round((($vals | Measure-Object -Average).Average), 2)
            Max     = [math]::Round((($vals | Measure-Object -Maximum).Maximum), 2)
        }
    }

    Write-Host ''
    $rows | Format-Table -AutoSize | Out-String -Width 120 | Write-Host

    $dpc = $rows | Where-Object { $_.Counter -match 'dpc' } | Select-Object -First 1
    $isr = $rows | Where-Object { $_.Counter -match 'interrupt' } | Select-Object -First 1
    $verdict = 'ปกติ'
    $color = 'Green'
    if ($dpc -and $dpc.Avg -gt 3) { $verdict = 'DPC สูง — มีไดรเวอร์กิน CPU ตอน interrupt'; $color = 'Yellow' }
    if ($dpc -and $dpc.Avg -gt 6) { $verdict = 'DPC สูงมาก — ต้องหาไดรเวอร์ต้นเหตุ'; $color = 'Red' }
    if ($isr -and $isr.Avg -gt 2) { $verdict = 'Interrupt time สูงผิดปกติ'; $color = 'Yellow' }
    Write-Host ("  สรุป: {0}" -f $verdict) -ForegroundColor $color
    Write-Host '  อ้างอิง: DPC < 3% และ interrupt < 1% ถือว่าดี · ค่าที่ดีขึ้นหลังจูน = jitter น้อยลง' -ForegroundColor DarkGray
    Write-Host ''

    $dpcAvg = $null
    $isrAvg = $null
    if ($dpc) { $dpcAvg = $dpc.Avg }
    if ($isr) { $isrAvg = $isr.Avg }
    $schemeName = ''
    $active = Get-L51ActiveScheme
    if ($active) { $schemeName = $active.Name }

    return [pscustomobject]@{
        Timestamp = (Get-Date).ToString('o')
        Seconds   = $Seconds
        Scheme    = $schemeName
        Counters  = $rows
        DpcAvg    = $dpcAvg
        IsrAvg    = $isrAvg
    }
}

function Compare-L51Bench {
    param([int]$Count = 2, [switch]$AsObject)
    $hist = @(Get-L51BenchHistory -Last $Count)
    if ($hist.Count -lt 2) {
        if (-not $AsObject) { Write-L51Log 'ต้องมีผลอย่างน้อย 2 ครั้งใน benchmarks/history.jsonl เพื่อเปรียบเทียบ' 'WARN' }
        return @()
    }
    $out = @()
    for ($i = 1; $i -lt $hist.Count; $i++) {
        $a = $hist[$i - 1]
        $b = $hist[$i]
        if (-not $AsObject) {
            Write-Host ''
            Write-Host ("  {0}  ->  {1}" -f $a.Label, $b.Label) -ForegroundColor Cyan
        }
        $rows = @(
            @{ Name = 'CPU 1 thread (MB/s)'; A = $a.CpuSingleMBps; B = $b.CpuSingleMBps },
            @{ Name = 'CPU all threads (MB/s)'; A = $a.CpuMultiMBps; B = $b.CpuMultiMBps },
            @{ Name = 'Memory (MB/s)'; A = $a.MemMBps; B = $b.MemMBps },
            @{ Name = 'Disk write (MB/s)'; A = $a.DiskWriteMB; B = $b.DiskWriteMB },
            @{ Name = 'Disk read (MB/s)'; A = $a.DiskReadMB; B = $b.DiskReadMB }
        )
        foreach ($r in $rows) {
            $delta = 0
            if ($r.A -gt 0) { $delta = [math]::Round(($r.B - $r.A) / $r.A * 100, 1) }
            $out += [pscustomobject]@{
                From = $a.Label; To = $b.Label; Metric = $r.Name
                A = $r.A; B = $r.B; DeltaPct = $delta
            }
            if ($AsObject) { continue }
            $color = 'Gray'
            if ($delta -gt 1) { $color = 'Green' }
            if ($delta -lt -1) { $color = 'Red' }
            Write-Host ("   {0,-22} {1,10:N1} -> {2,10:N1}   {3,6}%" -f $r.Name, $r.A, $r.B, $delta) -ForegroundColor $color
        }
    }
    if (-not $AsObject) {
        Write-Host ''
        Write-Host '  หมายเหตุ: micro-benchmark มี noise ±3-5% — ต่างน้อยกว่านั้นถือว่าไม่ต่าง' -ForegroundColor DarkGray
    }
    return $out
}

# ===========================================================================
# Live metrics (ใช้โดยหน้า "กราฟสด" ของ Web GUI)
# ===========================================================================

function Get-L51LiveMetrics {
    $cpuLoad = $null
    $cpuClock = $null
    $ramUsed = $null
    $gpu = $null

    try {
        $sample = Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'" -ErrorAction Stop
        if ($sample) { $cpuLoad = [int]$sample.PercentProcessorTime }
    } catch { }

    try {
        $cpu = Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -First 1
        if ($cpu) { $cpuClock = [int]$cpu.CurrentClockSpeed }
    } catch { }

    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $usedKB = [double]$os.TotalVisibleMemorySize - [double]$os.FreePhysicalMemory
        $ramUsed = [math]::Round(($usedKB / 1MB), 1)
    } catch { }

    try {
        $state = @(Get-L51GpuState | Where-Object { $_.Source -ne 'wmi' })
        if ($state.Count -eq 0) { $state = @(Get-L51GpuState) }
        if ($state.Count -gt 0) {
            $g = $state[0]
            # ค่าจาก nvidia-smi เป็น string และอาจเป็น '[N/A]' — แปลงเฉพาะค่าที่เป็นตัวเลขได้
            $clock = $null; $temp = $null; $util = $null; $power = $null
            $tmp = 0.0
            if ([double]::TryParse([string]$g.ClockMHz, [ref]$tmp)) { $clock = $tmp }
            $tmp = 0.0
            if ([double]::TryParse([string]$g.TempC, [ref]$tmp)) { $temp = $tmp }
            $tmp = 0.0
            if ([double]::TryParse([string]$g.UtilPct, [ref]$tmp)) { $util = $tmp }
            $tmp = 0.0
            if ([double]::TryParse([string]$g.PowerW, [ref]$tmp)) { $power = $tmp }
            $gpu = [pscustomobject]@{
                Name     = $g.Name
                ClockMHz = $clock
                TempC    = $temp
                UtilPct  = $util
                PowerW   = $power
            }
        }
    } catch { }

    return [pscustomobject]@{
        Timestamp  = (Get-Date).ToString('o')
        CpuLoadPct = $cpuLoad
        CpuClockMHz = $cpuClock
        RamUsedGB  = $ramUsed
        Gpu        = $gpu
    }
}
