# LEVEL51-TUNE :: Tweak catalog
# ---------------------------------------------------------------------------
# Declarative data only. No logic here. The engine (Level51Tune.psm1) reads
# these records and performs backup -> apply -> verify -> restore.
#
# Record schema
#   Id          unique dotted id, e.g. 'power.cpu.min100'
#   Category    CPU | GPU | Power | Memory | Storage | Network | Windows
#   Title       English one-liner
#   TitleTh     Thai one-liner (docs / list output)
#   Risk        Low | Medium | High   (High must be opted in with -Include high)
#   Admin       $true when administrator is required
#   Reboot      $true when a restart is required to take effect
#   Profiles    array of profile ids this tweak belongs to
#   Type        Power | Registry | Service | Script
#   Notes       why it works / caveats (Thai)
#   Power:      Subgroup, Setting, AC, DC        (aliases or GUIDs)
#   Registry:   Path, Name, Value, ValueType     (DWord|QWord|String|ExpandString|MultiString|Binary)
#   Service:    ServiceName, StartupType         (Disabled|Manual|Automatic|AutomaticDelayedStart)
#   Script:     ApplyScript, RevertScript, DetectScript   (param($ctx))
# ---------------------------------------------------------------------------

$script:L51ProfileCatalog = @(
    @{
        Id = 'balanced'
        Name = 'Balanced'
        TitleTh = 'สมดุล (ปลอดภัยที่สุด)'
        Summary = 'เปิดของที่ได้ผลชัดและเสี่ยงต่ำสุด: HAGS, TRIM, last access, MMCSS เบา ๆ, ปิด GameDVR บางส่วน'
        UseWhen = 'ใช้งานทั่วไป / ทำงานออฟฟิศ / อยากได้ baseline ที่ย้อนกลับง่าย'
    },
    @{
        Id = 'performance'
        Name = 'Performance'
        TitleTh = 'ประสิทธิภาพ (ใช้งานประจำวัน)'
        Summary = 'ยกระดับ CPU state, ปิด core parking บางส่วน, PCIe ASPM off, disk timeout off, จูน TCP'
        UseWhen = 'ทำงานหนัก เร็วตอบสนองดี ยังคุมความร้อนได้'
    },
    @{
        Id = 'gaming'
        Name = 'Gaming'
        TitleTh = 'เกมมิ่ง (latency ต่ำ)'
        Summary = 'performance + MMCSS Games priority, Nagle off, NVIDIA telemetry off, GPU preference, ปิด fullscreen optimization'
        UseWhen = 'เล่นเกม / VR / งานที่ต้องการ input latency ต่ำ'
    },
    @{
        Id = 'max'
        Name = 'Max'
        TitleTh = 'สูงสุด (ระวังความร้อน)'
        Summary = 'ทุกอย่างของ gaming + CPU 100%, boost aggressive, SysMain/ค้นหาดัชนีปิด, services debloat, NTFS tuning'
        UseWhen = 'benchmark / เรนเดอร์ / งาน burst สั้น ๆ — เครื่องจะร้อนและกินไฟชัด'
    },
    @{
        Id = 'battery'
        Name = 'Battery'
        TitleTh = 'ประหยัดแบตเตอรี่'
        Summary = 'จำกัด state ตอนใช้แบต, boost แบบ efficient, ASPM ประหยัดสุด, พัดลมเงียบ, timeout สั้นลง'
        UseWhen = 'พาออกนอกบ้าน ใช้แบตเป็นหลัก'
    }
)

$script:L51TweakCatalog = @(

    # =======================================================================
    # POWER :: CPU state / boost / cooling
    # =======================================================================
    @{
        Id = 'power.cpu.min100'
        Category = 'Power'
        Title = 'Minimum processor state 100% (AC)'
        TitleTh = 'ล็อกสถานะซีพียูขั้นต่ำ 100% ตอนต่อไฟ'
        Risk = 'Low'
        Admin = $true
        Reboot = $false
        Profiles = @('max')
        Type = 'Power'
        Subgroup = 'SUB_PROCESSOR'
        Setting = 'PROCTHROTTLEMIN'
        AC = 100
        DC = 25
        Notes = 'ทำให้ Core ไม่ถูก park/downclock — latency ต่ำสุด แต่กินไฟและร้อนขึ้นชัดเจนบน N95TP6 (CPU desktop ในตัวเครื่อง laptop)'
    },
    @{
        Id = 'power.cpu.min50'
        Category = 'Power'
        Title = 'Minimum processor state 50% (AC)'
        TitleTh = 'สถานะซีพียูขั้นต่ำ 50% ตอนต่อไฟ'
        Risk = 'Low'
        Admin = $true
        Reboot = $false
        Profiles = @('performance', 'gaming')
        Type = 'Power'
        Subgroup = 'SUB_PROCESSOR'
        Setting = 'PROCTHROTTLEMIN'
        AC = 50
        DC = 5
        Notes = 'จุดสมดุล: ลดการสลับ P-state ถี่ ๆ ที่ทำให้เกิด jitter แต่ยังปล่อยให้ downclock ตอน idle'
    },
    @{
        Id = 'power.cpu.max100'
        Category = 'Power'
        Title = 'Maximum processor state 100% (AC/DC)'
        TitleTh = 'ปลดล็อกสถานะซีพียูสูงสุด 100% ทั้ง AC และ DC'
        Risk = 'Low'
        Admin = $true
        Reboot = $false
        Profiles = @('performance', 'gaming', 'max')
        Type = 'Power'
        Subgroup = 'SUB_PROCESSOR'
        Setting = 'PROCTHROTTLEMAX'
        AC = 100
        DC = 100
        Notes = 'ค่า default ฝั่ง DC มักถูกจำกัด (~85%) ทำให้เกมบนแบตกระตุก; ตั้ง 100 ทั้งสองฝั่งแต่ระวังอุณหภูมิ'
    },
    @{
        Id = 'power.cpu.boost-enabled'
        Category = 'Power'
        Title = 'Processor performance boost mode = Enabled'
        TitleTh = 'เปิด Turbo Boost (โหมดปกติ)'
        Risk = 'Low'
        Admin = $true
        Reboot = $false
        Profiles = @('performance', 'gaming')
        Type = 'Power'
        Subgroup = 'SUB_PROCESSOR'
        Setting = 'PERFBOOSTMODE'
        AC = 1
        DC = 1
        Notes = 'i9-9900K ต้องมี boost จึงจะไปถึง 5.0 GHz; ค่า 0 = ปิด boost ทั้งหมด (เครื่องเย็นแต่ช้า)'
    },
    @{
        Id = 'power.cpu.boost-aggressive'
        Category = 'Power'
        Title = 'Processor performance boost mode = Aggressive'
        TitleTh = 'Turbo Boost แบบ Aggressive'
        Risk = 'Medium'
        Admin = $true
        Reboot = $false
        Profiles = @('max')
        Type = 'Power'
        Subgroup = 'SUB_PROCESSOR'
        Setting = 'PERFBOOSTMODE'
        AC = 2
        DC = 4
        Notes = 'กระโดดขึ้น boost clock ทันทีแทนการไล่ทีละขั้น — ดีกับ burst workload แต่ร้อนและ noisy มาก'
    },
    @{
        Id = 'power.cpu.cooling-active'
        Category = 'Power'
        Title = 'System cooling policy = Active (AC)'
        TitleTh = 'นโยบายระบายความร้อนแบบ Active (พัดลมนำ)'
        Risk = 'Low'
        Admin = $true
        Reboot = $false
        Profiles = @('performance', 'gaming', 'max')
        Type = 'Power'
        Subgroup = 'SUB_PROCESSOR'
        Setting = 'SYSCOOLPOL'
        AC = 1
        DC = 0
        Notes = 'Active = เร่งพัดลมก่อนลด clock (ประสิทธิภาพดีกว่า), Passive = ลด clock ก่อน (เงียบกว่า) ใช้ Passive ตอนใช้แบต'
    },
    @{
        Id = 'power.cpu.coreparking-off'
        Category = 'Power'
        Title = 'Disable core parking (AC 100% / DC 50%)'
        TitleTh = 'ปิดการ park คอร์ (ไม่ให้คอร์หลับ)'
        Risk = 'Medium'
        Admin = $true
        Reboot = $false
        Profiles = @('gaming', 'max')
        Type = 'Power'
        Subgroup = 'SUB_PROCESSOR'
        Setting = 'CPMINCORES'
        AC = 100
        DC = 50
        Notes = 'ลดอาการสะดุดจากการปลุกคอร์ (wake latency ~ms) เหมาะกับเกมที่ใช้หลาย thread; เปลืองไฟขึ้นเล็กน้อย'
    },
    @{
        Id = 'power.cpu.epp-performance'
        Category = 'Power'
        Title = 'Energy Performance Preference = 25 (favour performance)'
        TitleTh = 'EPP เอนไปทางประสิทธิภาพ (Speed Shift)'
        Risk = 'Medium'
        Admin = $true
        Reboot = $false
        Profiles = @('performance', 'gaming')
        Type = 'Power'
        Subgroup = 'SUB_PROCESSOR'
        Setting = 'PERFEPP'
        AC = 25
        DC = 50
        Notes = 'EPP (0 = ประสิทธิภาพสุด, 100 = ประหยัดสุด) บอก CPU ว่าควรเลือกความถี่ไหนผ่าน Speed Shift; 25 คือสมดุลที่ latency ดี'
    },
    @{
        Id = 'power.cpu.epp-max'
        Category = 'Power'
        Title = 'Energy Performance Preference = 0 (max performance)'
        TitleTh = 'EPP = 0 (ประสิทธิภาพสูงสุด)'
        Risk = 'Medium'
        Admin = $true
        Reboot = $false
        Profiles = @('max')
        Type = 'Power'
        Subgroup = 'SUB_PROCESSOR'
        Setting = 'PERFEPP'
        AC = 0
        DC = 0
        Notes = 'บังคับ CPU เลือกความถี่สูงสุดเท่าที่ thermal budget อนุญาต — อาจทำให้ throttling เร็วขึ้นถ้าระบายความร้อนไม่พอ'
    },
    @{
        Id = 'power.cpu.idle-disable'
        Category = 'Power'
        Title = 'Disable processor idle states (C-states off)'
        TitleTh = 'ปิด C-state (ไม่ให้ซีพียูเข้าสถานะประหยัดไฟ)'
        Risk = 'High'
        Admin = $true
        Reboot = $true
        Profiles = @('max')
        Type = 'Power'
        Subgroup = 'SUB_PROCESSOR'
        Setting = 'IDLEDISABLE'
        AC = 1
        DC = 0
        Notes = 'latency ต่ำสุดสำหรับงาน real-time/DAC audio แต่กินไฟเพิ่ม 20-40W ตอน idle และร้อนขึ้นมาก — ไม่แนะนำให้เปิดค้าง'
    },
    @{
        Id = 'power.cpu.thresholds'
        Category = 'Power'
        Title = 'Faster frequency ramp (increase 30 / decrease 10)'
        TitleTh = 'ปรับเกณฑ์เพิ่ม/ลดความถี่ให้ตอบสนองไว'
        Risk = 'Low'
        Admin = $true
        Reboot = $false
        Profiles = @('performance', 'gaming', 'max')
        Type = 'Power'
        Subgroup = 'SUB_PROCESSOR'
        Setting = 'PERFINCTHRESHOLD'
        AC = 30
        DC = 30
        Notes = 'ค่าเริ่มต้น 30/10; ลด threshold การเพิ่มความถี่ทำให้ CPU ขึ้น clock เร็วขึ้นเมื่อมีงานเข้า (ตั้งคู่กับ PERFDECTHRESHOLD ในสคริปต์ถ้าต้องการละเอียด)'
    },

    # =======================================================================
    # POWER :: PCIe / disk / USB / display / sleep
    # =======================================================================
    @{
        Id = 'power.pcie.aspm-off'
        Category = 'Power'
        Title = 'PCI Express Link State Power Management = Off (AC)'
        TitleTh = 'ปิด ASPM ของ PCIe ตอนต่อไฟ'
        Risk = 'Medium'
        Admin = $true
        Reboot = $false
        Profiles = @('performance', 'gaming', 'max')
        Type = 'Power'
        Subgroup = 'SUB_PCIEXPRESS'
        Setting = 'ASPM'
        AC = 0
        DC = 1
        Notes = 'ASPM ทำให้ NVMe/GPU ต้องตื่นจาก L1 ทุกครั้งที่เข้าถึง — ปิดแล้ว latency ของดิสก์และเฟรมไทม์นิ่งขึ้น แต่กินไฟเพิ่มเล็กน้อย'
    },
    @{
        Id = 'power.disk.timeout-never'
        Category = 'Power'
        Title = 'Turn off hard disk after = Never (AC)'
        TitleTh = 'ไม่ให้ดิสก์หยุดหมุน/สลีปตอนต่อไฟ'
        Risk = 'Low'
        Admin = $true
        Reboot = $false
        Profiles = @('performance', 'gaming', 'max')
        Type = 'Power'
        Subgroup = 'SUB_DISK'
        Setting = 'DISKIDLE'
        AC = 0
        DC = 600
        Notes = 'ค่า 0 = ไม่ปิด; ลดอาการค้าง 1-2 วินาทีเมื่อเปิดโปรแกรมที่ยังไม่ถูก cache'
    },
    @{
        Id = 'power.usb.suspend-off'
        Category = 'Power'
        Title = 'USB selective suspend = Disabled (AC)'
        TitleTh = 'ปิด USB selective suspend ตอนต่อไฟ'
        Risk = 'Low'
        Admin = $true
        Reboot = $false
        Profiles = @('gaming', 'max')
        Type = 'Power'
        Subgroup = 'SUB_USB'
        Setting = 'USBSELECTIVESUSPEND'
        AC = 0
        DC = 1
        Notes = 'ช่วยเรื่อง latency ของเมาส์/คีย์บอร์ด/capture card แต่ทำให้อุปกรณ์กินไฟตลอดเวลา'
    },
    @{
        Id = 'power.video.timeout-20m'
        Category = 'Power'
        Title = 'Turn off display after = 20 minutes (AC)'
        TitleTh = 'ปิดจอหลัง 20 นาที (ตอนต่อไฟ)'
        Risk = 'Low'
        Admin = $true
        Reboot = $false
        Profiles = @('performance', 'gaming')
        Type = 'Power'
        Subgroup = 'SUB_VIDEO'
        Setting = 'VIDEOIDLE'
        AC = 1200
        DC = 300
        Notes = 'กันจอดับระหว่าง benchmark/เรนเดอร์ยาว แต่ยังประหยัดไฟเมื่อไม่มีคนใช้'
    },
    @{
        Id = 'power.sleep.never-ac'
        Category = 'Power'
        Title = 'Sleep after = Never (AC)'
        TitleTh = 'ไม่ให้เครื่อง sleep ตอนต่อไฟ'
        Risk = 'Low'
        Admin = $true
        Reboot = $false
        Profiles = @('performance', 'gaming', 'max')
        Type = 'Power'
        Subgroup = 'SUB_SLEEP'
        Setting = 'STANDBYIDLE'
        AC = 0
        DC = 900
        Notes = 'งาน render/ดาวน์โหลดไม่ถูกตัดกลางคัน; ตอนใช้แบตยัง sleep ที่ 15 นาที'
    },
    @{
        Id = 'power.hibernate-off'
        Category = 'Power'
        Title = 'Disable hibernation and Fast Startup'
        TitleTh = 'ปิด Hibernate และ Fast Startup'
        Risk = 'Medium'
        Admin = $true
        Reboot = $true
        Profiles = @('max')
        Type = 'Script'
        Notes = 'คืนพื้นที่ C: เท่ากับขนาด RAM (~32 GB) และทำให้การปิดเครื่องเป็น cold boot จริง (ไดรเวอร์/สถานะสะอาดขึ้น) แต่ boot ช้าลงและเสีย Fast Startup'
        ApplyScript = {
            param($ctx)
            $prev = @{ HibernateOn = $false }
            $q = Invoke-L51External 'powercfg' @('-a')
            if ($q.Output -match 'Hibernation|Hibernate') { $prev.HibernateOn = $true }
            if (-not $ctx.DryRun) {
                Invoke-L51External 'powercfg' @('-hibernate', 'off') | Out-Null
            }
            return $prev
        }
        RevertScript = {
            param($ctx)
            Invoke-L51External 'powercfg' @('-hibernate', 'on') | Out-Null
        }
        DetectScript = {
            param($ctx)
            $q = Invoke-L51External 'powercfg' @('-a')
            return -not ($q.Output -match 'Hibernate')
        }
    },
    @{
        Id = 'power.throttling-off'
        Category = 'Power'
        Title = 'Disable Windows Power Throttling (EcoQoS)'
        TitleTh = 'ปิด Power Throttling (EcoQoS)'
        Risk = 'Medium'
        Admin = $true
        Reboot = $true
        Profiles = @('max')
        Type = 'Registry'
        Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling'
        Name = 'PowerThrottlingOff'
        Value = 1
        ValueType = 'DWord'
        Notes = 'Windows ลด clock ให้โปรเซสพื้นหลังอัตโนมัติ (เห็นเป็น "Efficiency mode" ใน Task Manager) — ปิดแล้วงานเบื้องหลังไม่โดนหน่วง แต่กินไฟขึ้น'
    },

    # =======================================================================
    # BATTERY :: DC-only savings
    # =======================================================================
    @{
        Id = 'battery.cpu.min5'
        Category = 'Power'
        Title = 'Minimum processor state 5% (DC)'
        TitleTh = 'สถานะซีพียูขั้นต่ำ 5% ตอนใช้แบต'
        Risk = 'Low'
        Admin = $true
        Reboot = $false
        Profiles = @('battery')
        Type = 'Power'
        Subgroup = 'SUB_PROCESSOR'
        Setting = 'PROCTHROTTLEMIN'
        AC = $null
        DC = 5
        Notes = 'ปล่อยให้ downclock ลึกที่สุดเมื่อไม่มีงาน — เพิ่มอายุแบตชัดเจน'
    },
    @{
        Id = 'battery.cpu.max70'
        Category = 'Power'
        Title = 'Maximum processor state 70% (DC)'
        TitleTh = 'จำกัดซีพียูสูงสุด 70% ตอนใช้แบต'
        Risk = 'Low'
        Admin = $true
        Reboot = $false
        Profiles = @('battery')
        Type = 'Power'
        Subgroup = 'SUB_PROCESSOR'
        Setting = 'PROCTHROTTLEMAX'
        AC = $null
        DC = 70
        Notes = 'ตัด boost ทิ้งเมื่อใช้แบต; ประสิทธิภาพต่อวัตต์ดีขึ้นมากบน i9-9900K'
    },
    @{
        Id = 'battery.cpu.boost-efficient'
        Category = 'Power'
        Title = 'Processor performance boost mode = Efficient Enabled (DC)'
        TitleTh = 'Boost แบบประหยัดตอนใช้แบต'
        Risk = 'Low'
        Admin = $true
        Reboot = $false
        Profiles = @('battery')
        Type = 'Power'
        Subgroup = 'SUB_PROCESSOR'
        Setting = 'PERFBOOSTMODE'
        AC = $null
        DC = 3
        Notes = 'ค่า 3 = Efficient Enabled, 4 = Efficient Aggressive — ให้ boost เฉพาะเมื่อคุ้มจริง'
    },
    @{
        Id = 'battery.cooling-passive'
        Category = 'Power'
        Title = 'System cooling policy = Passive (DC)'
        TitleTh = 'นโยบายระบายความร้อนแบบ Passive ตอนใช้แบต'
        Risk = 'Low'
        Admin = $true
        Reboot = $false
        Profiles = @('battery')
        Type = 'Power'
        Subgroup = 'SUB_PROCESSOR'
        Setting = 'SYSCOOLPOL'
        AC = $null
        DC = 0
        Notes = 'ลด clock ก่อนเร่งพัดลม — เงียบและประหยัดกว่า'
    },
    @{
        Id = 'battery.pcie-aspm-max'
        Category = 'Power'
        Title = 'PCIe ASPM = Maximum power savings (DC)'
        TitleTh = 'ASPM ประหยัดสุดตอนใช้แบต'
        Risk = 'Low'
        Admin = $true
        Reboot = $false
        Profiles = @('battery')
        Type = 'Power'
        Subgroup = 'SUB_PCIEXPRESS'
        Setting = 'ASPM'
        AC = $null
        DC = 2
        Notes = 'ค่า 2 = Maximum power savings; NVMe จะตื่นช้าขึ้นเล็กน้อยแต่ประหยัดไฟกว่า'
    },
    @{
        Id = 'battery.video-timeout-5m'
        Category = 'Power'
        Title = 'Turn off display after 5 minutes (DC)'
        TitleTh = 'ปิดจอหลัง 5 นาที ตอนใช้แบต'
        Risk = 'Low'
        Admin = $true
        Reboot = $false
        Profiles = @('battery')
        Type = 'Power'
        Subgroup = 'SUB_VIDEO'
        Setting = 'VIDEOIDLE'
        AC = $null
        DC = 300
        Notes = 'จอ LCD กินไฟมากที่สุดเป็นอันดับหนึ่งตอน idle'
    },
    @{
        Id = 'battery.lid-sleep'
        Category = 'Power'
        Title = 'Lid close action = Sleep (DC)'
        TitleTh = 'ปิดฝาแล้ว sleep ตอนใช้แบต'
        Risk = 'Low'
        Admin = $true
        Reboot = $false
        Profiles = @('battery')
        Type = 'Power'
        Subgroup = 'SUB_BUTTONS'
        Setting = 'LIDACTION'
        AC = $null
        DC = 1
        Notes = 'ค่า 1 = Sleep, 0 = Do nothing, 2 = Hibernate, 3 = Shut down'
    },

    # =======================================================================
    # GPU
    # =======================================================================
    @{
        Id = 'gpu.hags'
        Category = 'GPU'
        Title = 'Hardware-accelerated GPU scheduling = On'
        TitleTh = 'เปิด Hardware-Accelerated GPU Scheduling (HAGS)'
        Risk = 'Low'
        Admin = $true
        Reboot = $true
        Profiles = @('balanced', 'performance', 'gaming', 'max')
        Type = 'Registry'
        Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers'
        Name = 'HwSchMode'
        Value = 2
        ValueType = 'DWord'
        Notes = 'ย้ายงานจัดคิว GPU ไปทำในฮาร์ดแวร์ ลด overhead ของ CPU driver; ต้อง reboot และต้องมีไดรเวอร์ WDDM 2.7+ (GTX 1060 รองรับ)'
    },
    @{
        Id = 'gpu.gamedvr-off'
        Category = 'GPU'
        Title = 'Disable GameDVR background recording'
        TitleTh = 'ปิด GameDVR (อัดหน้าจอเบื้องหลัง)'
        Risk = 'Low'
        Admin = $false
        Reboot = $false
        Profiles = @('balanced', 'performance', 'gaming', 'max')
        Type = 'Registry'
        Path = 'HKCU:\System\GameConfigStore'
        Name = 'GameDVR_Enabled'
        Value = 0
        ValueType = 'DWord'
        Notes = 'GameDVR ใช้ GPU encoder ตลอดเวลาแม้ไม่ได้อัด — ปิดแล้วได้ fps คืน 2-8% ในเกมบางตัว'
    },
    @{
        Id = 'gpu.gamedvr-policy'
        Category = 'GPU'
        Title = 'Disable GameDVR policy (machine-wide)'
        TitleTh = 'ปิดนโยบาย GameDVR ทั้งเครื่อง'
        Risk = 'Low'
        Admin = $true
        Reboot = $false
        Profiles = @('gaming', 'max')
        Type = 'Registry'
        Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR'
        Name = 'AllowGameDVR'
        Value = 0
        ValueType = 'DWord'
        Notes = 'ปิดทั้งเครื่องผ่าน policy — เก็บบัญชีอื่นไม่ให้เปิดค้างไว้'
    },
    @{
        Id = 'gpu.fullscreen-opt-off'
        Category = 'GPU'
        Title = 'Disable fullscreen optimizations (flip model)'
        TitleTh = 'ปิด Fullscreen Optimizations'
        Risk = 'Low'
        Admin = $false
        Reboot = $false
        Profiles = @('gaming', 'max')
        Type = 'Registry'
        Path = 'HKCU:\System\GameConfigStore'
        Name = 'GameDVR_FSEBehaviorMode'
        Value = 2
        ValueType = 'DWord'
        Notes = 'บังคับ exclusive fullscreen แบบเดิม ลด input lag ในบางเกม; เกม DX12 บางตัวอาจมีปัญหา alt-tab'
    },
    @{
        Id = 'gpu.fullscreen-opt-honor'
        Category = 'GPU'
        Title = 'Honor per-app fullscreen behaviour'
        TitleTh = 'เคารพการตั้ง fullscreen ของแต่ละโปรแกรม'
        Risk = 'Low'
        Admin = $false
        Reboot = $false
        Profiles = @('gaming', 'max')
        Type = 'Registry'
        Path = 'HKCU:\System\GameConfigStore'
        Name = 'GameDVR_HonorUserFSEBehaviorMode'
        Value = 1
        ValueType = 'DWord'
        Notes = 'ทำงานคู่กับ GameDVR_FSEBehaviorMode'
    },
    @{
        Id = 'gpu.prefer-dgpu-global'
        Category = 'GPU'
        Title = 'Default GPU preference = High performance (GTX 1060)'
        TitleTh = 'ตั้ง GPU หลักเป็นตัวแรง (GTX 1060)'
        Risk = 'Medium'
        Admin = $false
        Reboot = $false
        Profiles = @('gaming', 'max')
        Type = 'Registry'
        Path = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'
        Name = 'DirectXUserGlobalSettings'
        Value = 'SwapEffectUpgradeEnable=1;GpuPreference=2;'
        ValueType = 'String'
        Notes = 'บนเครื่อง Optimus ถ้าไม่ตั้งค่า ระบบอาจเลือก UHD 630 ให้โปรแกรมที่ไม่ได้ลงทะเบียน; ค่า 2 = high performance'
    },
    @{
        Id = 'gpu.nvidia-telemetry-off'
        Category = 'GPU'
        Title = 'Disable NVIDIA Telemetry Container service'
        TitleTh = 'ปิดบริการ NVIDIA Telemetry'
        Risk = 'Medium'
        Admin = $true
        Reboot = $false
        Profiles = @('gaming', 'max')
        Type = 'Service'
        ServiceName = 'NvTelemetryContainer'
        StartupType = 'Disabled'
        Notes = 'บริการส่งข้อมูลการใช้งานของไดรเวอร์ — ปิดได้ไม่กระทบการเล่นเกม (GeForce Experience จะเตือนถ้าใช้ฟีเจอร์ของมัน)'
    },
    @{
        Id = 'gpu.nvlddmkm-pstate'
        Category = 'GPU'
        Title = 'Disable dynamic P-State switching (nvlddmkm)'
        TitleTh = 'ปิดการสลับ P-State ไดนามิกของไดรเวอร์ NVIDIA'
        Risk = 'High'
        Admin = $true
        Reboot = $true
        Profiles = @('max')
        Type = 'Registry'
        Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm'
        Name = 'DisableDynamicPstate'
        Value = 1
        ValueType = 'DWord'
        Notes = 'ลดอาการ clock แกว่ง/สะดุด แต่ GPU จะไม่ downclock ตอน idle (ร้อนและกินไฟตลอด) — ใช้ชั่วคราวเพื่อวินิจฉัยเท่านั้น'
    },

    # =======================================================================
    # MEMORY
    # =======================================================================
    @{
        Id = 'mem.priority-separation'
        Category = 'Memory'
        Title = 'Win32PrioritySeparation = 38 (short, variable, 3:1)'
        TitleTh = 'ปรับ quantum ของตัวจัดตาราง ( foreground 3:1 )'
        Risk = 'Medium'
        Admin = $true
        Reboot = $true
        Profiles = @('performance', 'gaming', 'max')
        Type = 'Registry'
        Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl'
        Name = 'Win32PrioritySeparation'
        Value = 38
        ValueType = 'DWord'
        Notes = '38 (0x26) = quantum สั้น แบบ variable และให้ foreground ได้ CPU มากกว่า 3 เท่า — เหมาะกับเกม/อินเทอแรกทีฟ; ถ้าอยากได้ quantum ยาวใช้ 26 (0x1A)'
    },
    @{
        Id = 'mem.large-system-cache'
        Category = 'Memory'
        Title = 'LargeSystemCache = 1'
        TitleTh = 'เปิด LargeSystemCache'
        Risk = 'Medium'
        Admin = $true
        Reboot = $true
        Profiles = @('max')
        Type = 'Registry'
        Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'
        Name = 'LargeSystemCache'
        Value = 1
        ValueType = 'DWord'
        Notes = 'ให้ Windows ใช้ RAM ทำ file cache มากขึ้น — ช่วยงาน I/O หนัก ๆ แต่แย่ลงถ้าเปิดหลาย VM/แรมไม่พอ'
    },
    @{
        Id = 'mem.ntfs-memory-usage'
        Category = 'Memory'
        Title = 'NtfsMemoryUsage = 2'
        TitleTh = 'เพิ่มหน่วยความจำให้ NTFS'
        Risk = 'Medium'
        Admin = $true
        Reboot = $true
        Profiles = @('max')
        Type = 'Registry'
        Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'
        Name = 'NtfsMemoryUsage'
        Value = 2
        ValueType = 'DWord'
        Notes = 'เพิ่ม cache ของ metadata NTFS เหมาะกับเครื่องที่มีแรม 32 GB และทำงานกับไฟล์จำนวนมาก'
    },
    @{
        Id = 'mem.sysmain-off'
        Category = 'Memory'
        Title = 'Disable SysMain (Superfetch)'
        TitleTh = 'ปิด SysMain / Superfetch'
        Risk = 'Medium'
        Admin = $true
        Reboot = $true
        Profiles = @('max')
        Type = 'Service'
        ServiceName = 'SysMain'
        StartupType = 'Disabled'
        Notes = 'บน NVMe ยุคใหม่ SysMain ให้ประโยชน์น้อยแต่กิน CPU/IO พื้นหลัง; บางคนรู้สึกโปรแกรมเปิดช้าลง — ย้อนกลับได้ทันที'
    },
    @{
        Id = 'mem.prefetch-off'
        Category = 'Memory'
        Title = 'Disable Prefetcher (EnablePrefetcher = 0)'
        TitleTh = 'ปิด Prefetcher'
        Risk = 'Medium'
        Admin = $true
        Reboot = $true
        Profiles = @('max')
        Type = 'Registry'
        Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters'
        Name = 'EnablePrefetcher'
        Value = 0
        ValueType = 'DWord'
        Notes = 'ลด IO ตอนบูต/เปิดโปรแกรมครั้งแรกบน SSD แต่โปรแกรมที่เปิดบ่อยจะช้าลงเล็กน้อย — เป็นการแลกที่ถกเถียงกันมาก'
    },

    # =======================================================================
    # STORAGE
    # =======================================================================
    @{
        Id = 'disk.last-access-off'
        Category = 'Storage'
        Title = 'Disable NTFS last access timestamp'
        TitleTh = 'ปิดการอัปเดตเวลาเข้าถึงไฟล์ (last access)'
        Risk = 'Low'
        Admin = $true
        Reboot = $false
        Profiles = @('balanced', 'performance', 'gaming', 'max')
        Type = 'Script'
        Notes = 'Windows 11 ตั้ง 1 (ปิด) ไว้อยู่แล้ว — tweak นี้ยืนยันค่าและบันทึกสถานะเดิมไว้ เป็นตัวอย่าง tweak แบบ Script'
        ApplyScript = {
            param($ctx)
            $q = Invoke-L51External 'fsutil' @('behavior', 'query', 'disablelastaccess')
            $prev = @{ Raw = $q.Output.Trim() }
            if (-not $ctx.DryRun) {
                Invoke-L51External 'fsutil' @('behavior', 'set', 'disablelastaccess', '1') | Out-Null
            }
            return $prev
        }
        RevertScript = {
            param($ctx)
            Invoke-L51External 'fsutil' @('behavior', 'set', 'disablelastaccess', '2') | Out-Null
        }
        DetectScript = {
            param($ctx)
            $q = Invoke-L51External 'fsutil' @('behavior', 'query', 'disablelastaccess')
            return ($q.Output -match '=\s*1')
        }
    },
    @{
        Id = 'disk.defrag-task-off'
        Category = 'Storage'
        Title = 'Disable scheduled defragmentation task'
        TitleTh = 'ปิดงาน Defrag ตามกำหนดการ'
        Risk = 'Medium'
        Admin = $true
        Reboot = $false
        Profiles = @('performance', 'gaming', 'max')
        Type = 'Script'
        Notes = 'บน SSD ไม่จำเป็นต้อง defrag (Windows ทำ TRIM ให้) — การรันตาม schedule ทำให้เกิด IO พื้นหลังตอนเล่นเกม'
        ApplyScript = {
            param($ctx)
            $taskPath = '\Microsoft\Windows\Defrag\'
            $t = Get-ScheduledTask -TaskName 'ScheduledDefrag' -TaskPath $taskPath -ErrorAction SilentlyContinue
            if (-not $t) { return @{ Found = $false } }
            $prev = @{ Found = $true; State = [string]$t.State }
            if (-not $ctx.DryRun) {
                Disable-ScheduledTask -TaskName 'ScheduledDefrag' -TaskPath $taskPath -ErrorAction Stop | Out-Null
                $after = Get-ScheduledTask -TaskName 'ScheduledDefrag' -TaskPath $taskPath -ErrorAction Stop
                if ([string]$after.State -ne 'Disabled') { throw "ปิด ScheduledDefrag ไม่สำเร็จ (สถานะยังเป็น $($after.State))" }
            }
            return $prev
        }
        RevertScript = {
            param($ctx)
            if ($ctx.Previous.Found) { Enable-ScheduledTask -TaskName 'ScheduledDefrag' -TaskPath '\Microsoft\Windows\Defrag\' -ErrorAction SilentlyContinue | Out-Null }
        }
        DetectScript = {
            param($ctx)
            $t = Get-ScheduledTask -TaskName 'ScheduledDefrag' -TaskPath '\Microsoft\Windows\Defrag\' -ErrorAction SilentlyContinue
            if (-not $t) { return $false }
            return ([string]$t.State -eq 'Disabled')
        }
    },
    @{
        Id = 'disk.indexing-off'
        Category = 'Storage'
        Title = 'Disable Windows Search indexing service'
        TitleTh = 'ปิดบริการค้นหาดัชนี (Windows Search)'
        Risk = 'Medium'
        Admin = $true
        Reboot = $true
        Profiles = @('max')
        Type = 'Service'
        ServiceName = 'WSearch'
        StartupType = 'Disabled'
        Notes = 'ลด IO/CPU พื้นหลังได้ชัดบนเครื่องนี้ แต่ช่องค้นหา Start/Explorer จะช้าลงมาก (ค้นหาไฟล์จะไม่เจอเนื้อหาในไฟล์)'
    },
    @{
        Id = 'disk.8dot3-off'
        Category = 'Storage'
        Title = 'Disable 8.3 short name creation'
        TitleTh = 'ปิดการสร้างชื่อไฟล์แบบ 8.3'
        Risk = 'Medium'
        Admin = $true
        Reboot = $false
        Profiles = @('max')
        Type = 'Script'
        Notes = 'ลด metadata ที่ NTFS ต้องเขียนต่อไฟล์ใหม่; โปรแกรมเก่ามากที่อ้างชื่อ 8.3 อาจติดตั้งไม่ผ่าน (พบน้อยมากในปี 2026)'
        ApplyScript = {
            param($ctx)
            $q = Invoke-L51External 'fsutil' @('behavior', 'query', 'disable8dot3')
            $prev = @{ Raw = $q.Output.Trim() }
            if (-not $ctx.DryRun) { Invoke-L51External 'fsutil' @('behavior', 'set', 'disable8dot3', '1') | Out-Null }
            return $prev
        }
        RevertScript = {
            param($ctx)
            Invoke-L51External 'fsutil' @('behavior', 'set', 'disable8dot3', '2') | Out-Null
        }
        DetectScript = {
            param($ctx)
            $q = Invoke-L51External 'fsutil' @('behavior', 'query', 'disable8dot3')
            return ($q.Output -match '=\s*1')
        }
    },

    # =======================================================================
    # NETWORK
    # =======================================================================
    @{
        Id = 'net.throttling-off'
        Category = 'Network'
        Title = 'Disable network throttling index'
        TitleTh = 'ปิด NetworkThrottlingIndex (ตัวจำกัดแพ็กเก็ต multimedia)'
        Risk = 'Low'
        Admin = $true
        Reboot = $true
        Profiles = @('balanced', 'gaming', 'max')
        Type = 'Registry'
        Path = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
        Name = 'NetworkThrottlingIndex'
        Value = 4294967295
        ValueType = 'DWord'
        Notes = 'ค่า default 10 (จำกัด ~10 แพ็กเก็ต/ms ให้งานมัลติมีเดีย) — ตั้ง 0xFFFFFFFF เพื่อปิดการจำกัด ลด ping spike ในเกมออนไลน์'
    },
    @{
        Id = 'net.mmcss-responsiveness'
        Category = 'Network'
        Title = 'SystemResponsiveness = 10'
        TitleTh = 'SystemResponsiveness = 10 (สำรอง CPU ให้ multimedia)'
        Risk = 'Low'
        Admin = $true
        Reboot = $true
        Profiles = @('gaming', 'max')
        Type = 'Registry'
        Path = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
        Name = 'SystemResponsiveness'
        Value = 10
        ValueType = 'DWord'
        Notes = 'ค่า default 20 (สำรอง CPU ให้งานพื้นหลัง 20%); 10 = ให้ multimedia/เกมได้ CPU มากขึ้น'
    },
    @{
        Id = 'net.mmcss-games'
        Category = 'Network'
        Title = 'MMCSS Games task profile: high GPU/CPU/SFIO priority'
        TitleTh = 'ตั้ง priority ของ MMCSS Games task ให้สูง'
        Risk = 'Medium'
        Admin = $true
        Reboot = $true
        Profiles = @('gaming', 'max')
        Type = 'Script'
        Notes = 'ปรับ GPU Priority=8, Priority=6, Scheduling Category=High, SFIO Priority=High — เป็นค่าที่เกม/ไดรเวอร์อ่านจาก registry ตอนลงทะเบียน thread'
        ApplyScript = {
            param($ctx)
            $base = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games'
            if (-not (Test-Path $base)) { if (-not $ctx.DryRun) { New-Item -Path $base -Force | Out-Null } }
            $targets = @(
                @{ Name = 'GPU Priority'; Value = 8; Kind = 'DWord' },
                @{ Name = 'Priority'; Value = 6; Kind = 'DWord' },
                @{ Name = 'Scheduling Category'; Value = 'High'; Kind = 'String' },
                @{ Name = 'SFIO Priority'; Value = 'High'; Kind = 'String' },
                @{ Name = 'Background Only'; Value = 'False'; Kind = 'String' }
            )
            $prev = @()
            foreach ($t in $targets) {
                $s = Get-L51RegState -Path $base -Name $t.Name
                $prev += @{ Path = $base; Name = $t.Name; Exists = $s.Exists; Value = $s.Value; Kind = $s.Kind }
                if (-not $ctx.DryRun) { Set-L51RegValue -Path $base -Name $t.Name -Value $t.Value -ValueType $t.Kind }
            }
            return $prev
        }
        RevertScript = {
            param($ctx)
            foreach ($r in $ctx.Previous) {
                Restore-L51RegState -Path $r.Path -Name $r.Name -State @{ Exists = $r.Exists; Value = $r.Value; Kind = $r.Kind }
            }
        }
        DetectScript = {
            param($ctx)
            $base = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games'
            if (-not (Test-Path $base)) { return $false }
            $gp = Get-L51RegState -Path $base -Name 'GPU Priority'
            $sc = Get-L51RegState -Path $base -Name 'Scheduling Category'
            return ($gp.Value -eq 8 -and $sc.Value -eq 'High')
        }
    },
    @{
        Id = 'net.nagle-off'
        Category = 'Network'
        Title = 'Disable Nagle algorithm (TcpAckFrequency=1, TCPNoDelay=1)'
        TitleTh = 'ปิด Nagle (ลดดีเลย์ของเกม/remote desktop)'
        Risk = 'Medium'
        Admin = $true
        Reboot = $true
        Profiles = @('gaming', 'max')
        Type = 'Script'
        Notes = 'Nagle รวมแพ็กเก็ตเล็กเพื่อประหยัดแบนด์วิดท์ แต่เพิ่มดีเลย์ได้ถึง 200 ms; ปิดแล้วเกมตอบสนองไวขึ้น (แบนด์วิดท์ใช้มากขึ้นเล็กน้อย)'
        ApplyScript = {
            param($ctx)
            $base = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces'
            $prev = @()
            foreach ($if in Get-ChildItem $base -ErrorAction SilentlyContinue) {
                foreach ($n in @('TcpAckFrequency', 'TCPNoDelay')) {
                    $s = Get-L51RegState -Path $if.PSPath -Name $n
                    $prev += @{ Path = $if.PSPath; Name = $n; Exists = $s.Exists; Value = $s.Value; Kind = $s.Kind }
                    if (-not $ctx.DryRun) { Set-L51RegValue -Path $if.PSPath -Name $n -Value 1 -ValueType 'DWord' }
                }
            }
            return $prev
        }
        RevertScript = {
            param($ctx)
            foreach ($r in $ctx.Previous) {
                Restore-L51RegState -Path $r.Path -Name $r.Name -State @{ Exists = $r.Exists; Value = $r.Value; Kind = $r.Kind }
            }
        }
        DetectScript = {
            param($ctx)
            $base = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces'
            $ifs = @(Get-ChildItem $base -ErrorAction SilentlyContinue)
            if ($ifs.Count -eq 0) { return $false }
            foreach ($if in $ifs) {
                if ((Get-L51RegState -Path $if.PSPath -Name 'TcpAckFrequency').Value -ne 1) { return $false }
            }
            return $true
        }
    },
    @{
        Id = 'net.tcp-global'
        Category = 'Network'
        Title = 'TCP global tuning (autotuning normal, RSS on, timestamps off)'
        TitleTh = 'จูน TCP stack (autotuning, RSS)'
        Risk = 'Low'
        Admin = $true
        Reboot = $true
        Profiles = @('performance', 'gaming', 'max')
        Type = 'Script'
        Notes = 'ค่ามาตรฐานที่ควรเป็นบน Gigabit/2.5G: receive window autotuning = normal, RSS = enabled, timestamps = disabled, ECN = disabled (เลี่ยงปัญหา router บางรุ่น)'
        ApplyScript = {
            param($ctx)
            $q = Invoke-L51External 'netsh' @('int', 'tcp', 'show', 'global')
            $prev = @{ Raw = $q.Output.Trim() }
            if (-not $ctx.DryRun) {
                Invoke-L51External 'netsh' @('int', 'tcp', 'set', 'global', 'autotuninglevel=normal') | Out-Null
                Invoke-L51External 'netsh' @('int', 'tcp', 'set', 'global', 'rss=enabled') | Out-Null
                Invoke-L51External 'netsh' @('int', 'tcp', 'set', 'global', 'timestamps=disabled') | Out-Null
                Invoke-L51External 'netsh' @('int', 'tcp', 'set', 'global', 'ecn=disabled') | Out-Null
            }
            return $prev
        }
        RevertScript = {
            param($ctx)
            Invoke-L51External 'netsh' @('int', 'tcp', 'set', 'global', 'autotuninglevel=normal') | Out-Null
            Invoke-L51External 'netsh' @('int', 'tcp', 'set', 'global', 'rss=enabled') | Out-Null
            Invoke-L51External 'netsh' @('int', 'tcp', 'set', 'global', 'timestamps=disabled') | Out-Null
            Invoke-L51External 'netsh' @('int', 'tcp', 'set', 'global', 'ecn=default') | Out-Null
        }
        DetectScript = {
            param($ctx)
            $q = Invoke-L51External 'netsh' @('int', 'tcp', 'show', 'global')
            return ($q.Output -match 'Receive Window Auto-Tuning Level\s*:\s*normal' -and $q.Output -match 'Receive-Side Scaling State\s*:\s*enabled')
        }
    },

    # =======================================================================
    # WINDOWS :: latency, services, shell
    # =======================================================================
    @{
        Id = 'win.gamemode-on'
        Category = 'Windows'
        Title = 'Enable Windows Game Mode'
        TitleTh = 'เปิด Game Mode'
        Risk = 'Low'
        Admin = $false
        Reboot = $false
        Profiles = @('balanced', 'performance', 'gaming', 'max')
        Type = 'Registry'
        Path = 'HKCU:\Software\Microsoft\GameBar'
        Name = 'AutoGameModeEnabled'
        Value = 1
        ValueType = 'DWord'
        Notes = 'Game Mode ให้เกมได้ CPU/GPU priority และหยุดงานพื้นหลังบางส่วนระหว่างเล่น'
    },
    @{
        Id = 'win.mouse-accel-off'
        Category = 'Windows'
        Title = 'Disable mouse acceleration (Enhance pointer precision)'
        TitleTh = 'ปิด mouse acceleration'
        Risk = 'Low'
        Admin = $false
        Reboot = $false
        Profiles = @('gaming', 'max')
        Type = 'Registry'
        Path = 'HKCU:\Control Panel\Mouse'
        Name = 'MouseSpeed'
        Value = '0'
        ValueType = 'String'
        Notes = 'ปิดการเร่งความเร็วเมาส์ — การเคลื่อนไหวตรงกับที่มือขยับ (ต้องตั้ง MouseThreshold1/2 = 0 ด้วย ซึ่งทำในสคริปต์แยก)'
    },
    @{
        Id = 'win.mouse-thresholds'
        Category = 'Windows'
        Title = 'Mouse thresholds = 0 / 0'
        TitleTh = 'ตั้ง threshold ของเมาส์เป็น 0'
        Risk = 'Low'
        Admin = $false
        Reboot = $false
        Profiles = @('gaming', 'max')
        Type = 'Script'
        Notes = 'ทำงานคู่กับ MouseSpeed = 0; ต้อง sign out/sign in จึงมีผลเต็มที่'
        ApplyScript = {
            param($ctx)
            $p = 'HKCU:\Control Panel\Mouse'
            $prev = @()
            foreach ($n in @('MouseThreshold1', 'MouseThreshold2')) {
                $s = Get-L51RegState -Path $p -Name $n
                $prev += @{ Path = $p; Name = $n; Exists = $s.Exists; Value = $s.Value; Kind = $s.Kind }
                if (-not $ctx.DryRun) { Set-L51RegValue -Path $p -Name $n -Value '0' -ValueType 'String' }
            }
            return $prev
        }
        RevertScript = {
            param($ctx)
            foreach ($r in $ctx.Previous) {
                Restore-L51RegState -Path $r.Path -Name $r.Name -State @{ Exists = $r.Exists; Value = $r.Value; Kind = $r.Kind }
            }
        }
        DetectScript = {
            param($ctx)
            $p = 'HKCU:\Control Panel\Mouse'
            return ((Get-L51RegState -Path $p -Name 'MouseThreshold1').Value -eq '0')
        }
    },
    @{
        Id = 'win.keyboard-delay'
        Category = 'Windows'
        Title = 'Keyboard repeat delay = shortest'
        TitleTh = 'ตั้งดีเลย์คีย์บอร์ดสั้นสุด'
        Risk = 'Low'
        Admin = $false
        Reboot = $false
        Profiles = @('gaming', 'max')
        Type = 'Registry'
        Path = 'HKCU:\Control Panel\Keyboard'
        Name = 'KeyboardDelay'
        Value = '0'
        ValueType = 'String'
        Notes = 'ค่า 0 = 250 ms (สั้นสุด) เหมาะกับการกดคีย์รัว ๆ'
    },
    @{
        Id = 'win.unhide-power-settings'
        Category = 'Windows'
        Title = 'Unhide advanced power settings in Control Panel'
        TitleTh = 'แสดงค่า power settings ขั้นสูงใน Control Panel'
        Risk = 'Low'
        Admin = $true
        Reboot = $false
        Profiles = @('performance', 'gaming', 'max')
        Type = 'Script'
        Notes = 'ค่า boost mode / core parking / EPP ถูกซ่อนไว้โดย default — ปลดซ่อนเพื่อให้ปรับเองใน Power Options ได้'
        ApplyScript = {
            param($ctx)
            $pairs = @(
                @('SUB_PROCESSOR', 'PERFBOOSTMODE'), @('SUB_PROCESSOR', 'CPMINCORES'),
                @('SUB_PROCESSOR', 'CPMAXCORES'), @('SUB_PROCESSOR', 'PERFEPP'),
                @('SUB_PROCESSOR', 'IDLEDISABLE'), @('SUB_PROCESSOR', 'PERFINCTHRESHOLD'),
                @('SUB_PROCESSOR', 'PERFDECTHRESHOLD'), @('SUB_PCIEXPRESS', 'ASPM'),
                @('SUB_SLEEP', 'HIBERNATEIDLE'), @('SUB_SLEEP', 'STANDBYIDLE'),
                @('SUB_DISK', 'DISKIDLE'), @('SUB_BUTTONS', 'LIDACTION'),
                @('SUB_VIDEO', 'VIDEOIDLE'), @('SUB_USB', 'USBSELECTIVESUSPEND')
            )
            foreach ($p in $pairs) {
                if (-not $ctx.DryRun) {
                    Invoke-L51External 'powercfg' @('-attributes', $p[0], $p[1], '-ATTRIB_HIDE') | Out-Null
                }
            }
            return @{ Done = $true }
        }
        RevertScript = {
            param($ctx)
            $pairs = @(
                @('SUB_PROCESSOR', 'PERFBOOSTMODE'), @('SUB_PROCESSOR', 'CPMINCORES'),
                @('SUB_PROCESSOR', 'CPMAXCORES'), @('SUB_PROCESSOR', 'PERFEPP'),
                @('SUB_PROCESSOR', 'IDLEDISABLE'), @('SUB_PROCESSOR', 'PERFINCTHRESHOLD'),
                @('SUB_PROCESSOR', 'PERFDECTHRESHOLD'), @('SUB_PCIEXPRESS', 'ASPM'),
                @('SUB_SLEEP', 'HIBERNATEIDLE'), @('SUB_SLEEP', 'STANDBYIDLE'),
                @('SUB_DISK', 'DISKIDLE'), @('SUB_BUTTONS', 'LIDACTION'),
                @('SUB_VIDEO', 'VIDEOIDLE'), @('SUB_USB', 'USBSELECTIVESUSPEND')
            )
            foreach ($p in $pairs) {
                Invoke-L51External 'powercfg' @('-attributes', $p[0], $p[1], '+ATTRIB_HIDE') | Out-Null
            }
        }
        DetectScript = {
            param($ctx)
            $q = Invoke-L51External 'powercfg' @('-query', 'SCHEME_CURRENT', 'SUB_PROCESSOR', 'PERFBOOSTMODE')
            return ($q.ExitCode -eq 0)
        }
    },
    @{
        Id = 'win.visualfx-performance'
        Category = 'Windows'
        Title = 'Visual effects = Adjust for best performance'
        TitleTh = 'ตั้ง visual effects เป็น "performance สูงสุด"'
        Risk = 'Low'
        Admin = $false
        Reboot = $false
        Profiles = @('max')
        Type = 'Registry'
        Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'
        Name = 'VisualFXSetting'
        Value = 2
        ValueType = 'DWord'
        Notes = 'ปิด animation/เงา/thumbnail ที่กิน GPU — หน้าตา Windows จะเปลี่ยน (ไม่มี fade) ใช้เฉพาะตอนต้องการ fps สูงสุด'
    },
    @{
        Id = 'win.transparency-off'
        Category = 'Windows'
        Title = 'Disable transparency effects'
        TitleTh = 'ปิดเอฟเฟกต์โปร่งใส'
        Risk = 'Low'
        Admin = $false
        Reboot = $false
        Profiles = @('max')
        Type = 'Registry'
        Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
        Name = 'EnableTransparency'
        Value = 0
        ValueType = 'DWord'
        Notes = 'ลดงาน compositor เล็กน้อย (acrylic/blur)'
    },
    @{
        Id = 'win.background-apps-off'
        Category = 'Windows'
        Title = 'Disable background apps globally'
        TitleTh = 'ปิดแอปพื้นหลังทั้งหมด'
        Risk = 'Medium'
        Admin = $true
        Reboot = $false
        Profiles = @('max')
        Type = 'Registry'
        Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications'
        Name = 'GlobalUserDisabled'
        Value = 1
        ValueType = 'DWord'
        Notes = 'แอป Store จะไม่ทำงานเบื้องหลัง (ไม่มีการแจ้งเตือน/ซิงก์) — ช่วยลด RAM/CPU ตอนเล่นเกม'
    },
    @{
        Id = 'win.services-diagtrack'
        Category = 'Windows'
        Title = 'Disable DiagTrack (telemetry)'
        TitleTh = 'ปิดบริการ DiagTrack (Telemetry)'
        Risk = 'Medium'
        Admin = $true
        Reboot = $false
        Profiles = @('max')
        Type = 'Service'
        ServiceName = 'DiagTrack'
        StartupType = 'Disabled'
        Notes = 'บริการเก็บข้อมูลการใช้งานและการวินิจฉัย — ปิดแล้วลด IO/network พื้นหลัง (ไม่กระทบ Windows Update)'
    },
    @{
        Id = 'win.services-dmwappush'
        Category = 'Windows'
        Title = 'Disable dmwappushservice'
        TitleTh = 'ปิด dmwappushservice'
        Risk = 'Low'
        Admin = $true
        Reboot = $false
        Profiles = @('max')
        Type = 'Service'
        ServiceName = 'dmwappushservice'
        StartupType = 'Disabled'
        Notes = 'บริการ WAP push สำหรับ telemetry — ไม่จำเป็นสำหรับผู้ใช้ทั่วไป'
    },
    @{
        Id = 'win.services-mapsbroker'
        Category = 'Windows'
        Title = 'Disable MapsBroker'
        TitleTh = 'ปิด MapsBroker'
        Risk = 'Low'
        Admin = $true
        Reboot = $false
        Profiles = @('max')
        Type = 'Service'
        ServiceName = 'MapsBroker'
        StartupType = 'Disabled'
        Notes = 'ดาวน์โหลดแผนที่ออฟไลน์ — ถ้าไม่ใช้แอป Maps ปิดได้'
    },
    @{
        Id = 'win.bcd-dynamictick'
        Category = 'Windows'
        Title = 'bcdedit /set disabledynamictick yes'
        TitleTh = 'ปิด dynamic tick ของ kernel'
        Risk = 'High'
        Admin = $true
        Reboot = $true
        Profiles = @('max')
        Type = 'Script'
        Notes = 'ลด jitter ของ timer (มีประโยชน์กับงาน audio/DAC real-time) แต่กินไฟเพิ่มและอาจทำให้ไดรเวอร์บางตัวมีปัญหา — ต้อง reboot และแก้คืนด้วย bcdedit /deletevalue'
        ApplyScript = {
            param($ctx)
            $q = Invoke-L51External 'bcdedit' @('/enum', '{current}')
            $prev = @{ Raw = $q.Output.Trim() }
            if (-not $ctx.DryRun) { Invoke-L51External 'bcdedit' @('/set', 'disabledynamictick', 'yes') | Out-Null }
            return $prev
        }
        RevertScript = {
            param($ctx)
            Invoke-L51External 'bcdedit' @('/deletevalue', 'disabledynamictick') | Out-Null
        }
        DetectScript = {
            param($ctx)
            $q = Invoke-L51External 'bcdedit' @('/enum', '{current}')
            return ($q.Output -match 'disabledynamictick\s+Yes')
        }
    },
    @{
        Id = 'win.bcd-platformclock'
        Category = 'Windows'
        Title = 'bcdedit /set useplatformclock false'
        TitleTh = 'บังคับใช้ TSC แทน platform clock'
        Risk = 'High'
        Admin = $true
        Reboot = $true
        Profiles = @('max')
        Type = 'Script'
        Notes = 'ค่าเริ่มต้น Windows 11 ใช้ TSC อยู่แล้ว (useplatformclock ถูกปิด) — tweak นี้เขียนค่าชัดเจนเพื่อกัน HPET fallback; ห้ามใช้ร่วมกับ useplatformtick'
        ApplyScript = {
            param($ctx)
            $q = Invoke-L51External 'bcdedit' @('/enum', '{current}')
            $prev = @{ Raw = $q.Output.Trim() }
            if (-not $ctx.DryRun) { Invoke-L51External 'bcdedit' @('/set', 'useplatformclock', 'false') | Out-Null }
            return $prev
        }
        RevertScript = {
            param($ctx)
            Invoke-L51External 'bcdedit' @('/deletevalue', 'useplatformclock') | Out-Null
        }
        DetectScript = {
            param($ctx)
            $q = Invoke-L51External 'bcdedit' @('/enum', '{current}')
            return ($q.Output -match 'useplatformclock\s+No')
        }
    }
)
