# คู่มือคำสั่ง CLI

ไฟล์ entry คือ `Level51Tune.ps1` รูปแบบทั่วไป:

```
.\Level51Tune.ps1 <คำสั่ง> [options]
```

ถ้าไม่ระบุคำสั่งจะเท่ากับ `help`

## สรุปคำสั่งทั้งหมด

| คำสั่ง | ต้องใช้ admin | แก้ระบบ | ใช้เวลา | หน้าที่ |
|---|---|---|---|---|
| `help` | ไม่ | ไม่ | ทันที | แสดงวิธีใช้ |
| `version` | ไม่ | ไม่ | ทันที | แสดงเวอร์ชัน |
| `status` | ไม่ | ไม่ | 1-3 วินาที | ฮาร์ดแวร์, power scheme, ค่าซีพียูปัจจุบัน |
| `profiles` | ไม่ | ไม่ | ทันที | รายละเอียดโปรไฟล์ |
| `list` | ไม่ | ไม่ | ทันที | tweaks ในแค็ตตาล็อก |
| `audit` | ไม่ | ไม่ | 2-5 วินาที | ตรวจว่าอะไรถูกปรับแล้ว |
| `apply` | ใช่ (ยกเว้น `-DryRun`) | ใช่ | 3-10 วินาที | ปรับตามโปรไฟล์ |
| `restore` | ใช่ | ใช่ | 2-5 วินาที | ย้อนกลับจาก backup |
| `backup` | ใช่ | ไม่ (แค่อ่าน) | 1 วินาที | snapshot สถานะ |
| `report` | ไม่ | ไม่ | 3-6 วินาที | รายงาน markdown |
| `bench` | ไม่ | ไม่ | 15-25 วินาที | วัดประสิทธิภาพ |
| `latency` | ไม่ | ไม่ | 15-25 วินาที | วัด DPC / interrupt / context switch |
| `recommend` | ไม่ | ไม่ | 1-2 วินาที | วิเคราะห์ฮาร์ดแวร์และแนะนำโปรไฟล์ |
| `update` | ไม่ | ไม่ | 1-3 วินาที | ตรวจเวอร์ชันใหม่บน GitHub (ต้องต่อเน็ต) |
| `history` | ไม่ | ไม่ | ทันที | รายการ backup ทั้งหมด (เลือก restore ทีละครั้ง) |
| `gpuprefs` | ไม่ | ใช่ (HKCU เท่านั้น) | ทันที | ตั้ง GPU ต่อแอป (Optimus) |
| `compare` | ไม่ | ไม่ | ทันที | เทียบผลวัด |
| `gpu` | ไม่ | ไม่ | 1 วินาที | สถานะ GPU |
| `docs` | ไม่ | ไม่ | 1 วินาที | สร้าง HTML |

## options ทั้งหมด

| option | ชนิด | ใช้กับ | ความหมาย |
|---|---|---|---|
| `-Profile <id>` | string | apply, audit | `balanced`, `performance`, `gaming`, `max`, `battery` |
| `-Category <name>` | string | list, audit | `CPU`, `GPU`, `Power`, `Memory`, `Storage`, `Network`, `Windows` |
| `-DryRun` | switch | apply | เดินทุกอย่างแต่ไม่เปลี่ยนแปลงระบบ |
| `-Elevate` | switch | apply, restore | เปิด PowerShell ใหม่แบบ admin (UAC) |
| `-Include high` | string[] | apply | อนุญาต tweaks ความเสี่ยงสูง |
| `-Custom` | switch | apply | ใช้รายการ tweak ที่บันทึกไว้ใน `state/custom.json` (จากหน้า Settings ของ GUI) |
| `-AppPath <exe>` | string | gpuprefs | ไฟล์ .exe ที่ต้องการตั้งค่า GPU |
| `-Mode <mode>` | string | gpuprefs | `dgpu` (GTX 1060), `igpu` (UHD 630), `auto` |
| `-Remove` | switch | gpuprefs | ลบรายการของแอปนั้น |
| `-IncludeHigh` | switch | audit | แสดง/ตรวจ tweaks High ด้วย |
| `-BackupPath <file>` | string | restore | ระบุไฟล์ backup (ค่าเริ่มต้น: ล่าสุด) |
| `-Path <file>` | string | report | ที่เก็บรายงาน |
| `-Label <text>` | string | bench | ชื่อกำกับผล (เช่น `before`, `after`, `max-profile`) |
| `-Seconds <n>` | int | bench, latency | เวลาต่อรอบ CPU / เวลาที่เฝ้าดู counter (ค่าเริ่มต้น 3 / 20) |
| `-Last <n>` | int | compare | จำนวนผลที่จะเทียบ (ค่าเริ่มต้น 2) |
| `-Open` | switch | docs | เปิด index.html หลังสร้าง |

## status

แสดงภาพรวมทั้งหมดโดยไม่แก้อะไร

```powershell
.\Level51Tune.ps1 status
```

เนื้อหาที่แสดง: ชื่อเครื่อง/รุ่น, OS build, CPU (cores/threads/L3/base clock), RAM (พร้อม slot, ความเร็ว, part number), GPU ทุกตัวพร้อม clock/temp/power จาก `nvidia-smi`, ดิสก์, แบตเตอรี่, สถานะ Hypervisor/VT-x, สิทธิ์ admin, uptime, power scheme ทั้งหมด (มี `*` หน้าอันที่ใช้อยู่), ค่า processor min/max/boost ปัจจุบัน, thermal zone และโปรไฟล์ที่ apply ล่าสุด

> ถ้า `nvidia-smi` ไม่ตอบ (ไดรเวอร์มีปัญหา) โปรแกรมจะ fallback ไปใช้ WMI ซึ่งให้ข้อมูลน้อยกว่า (ไม่มี clock/temp)

## profiles

```powershell
.\Level51Tune.ps1 profiles
```

แสดง 5 โปรไฟล์พร้อมคำอธิบายไทย, สถานการณ์ที่ควรใช้ และจำนวน tweaks (แยกจำนวน High risk ให้เห็น)

## list

```powershell
.\Level51Tune.ps1 list
.\Level51Tune.ps1 list -Category Power
.\Level51Tune.ps1 list -Category GPU
```

ตารางคอลัมน์: `Id`, `Category`, `Risk`, `Profiles`, `Admin`, `Title` — ใช้ดูว่ามี tweak อะไรบ้างก่อน apply

## audit

ตรวจสถานะจริงของแต่ละ tweak เทียบกับค่าเป้าหมาย โดยอ่านค่าจากระบบ (ไม่ใช้ข้อมูลที่จำไว้)

```powershell
.\Level51Tune.ps1 audit -Profile gaming
.\Level51Tune.ps1 audit -Category Network
.\Level51Tune.ps1 audit -Profile gaming -IncludeHigh
```

คอลัมน์ `Applied`: `YES` = ตรงกับเป้าหมายแล้ว, `no` = ยังไม่ตรง, `?` = ตรวจไม่ได้หรือเครื่องไม่รองรับ (เช่น tweak แบบ Script ที่ไม่มี detect หรือ power setting ที่ไดรเวอร์/BIOS ไม่ได้ expose บนเครื่องนี้)

ใช้ `audit` เพื่อตอบคำถามว่า "ตอนนี้เครื่องอยู่ในสภาพไหน" หลังจาก apply ไปแล้วหรือหลัง Windows Update รีเซ็ตค่าบางอย่าง

## apply

```powershell
# ดูของก่อน
.\Level51Tune.ps1 apply -Profile performance -DryRun

# apply จริง (ต้อง admin)
.\Level51Tune.ps1 apply -Profile performance

# apply เฉพาะ tweak ที่เลือกเองไว้ (บันทึกจากหน้า Settings ของ GUI)
.\Level51Tune.ps1 apply -Custom -DryRun

# ขอ UAC เอง
.\Level51Tune.ps1 apply -Profile gaming -Elevate

# รวม tweaks เสี่ยงสูงด้วย
.\Level51Tune.ps1 apply -Profile max -Include high
```

สถานะที่รายงานทีละ tweak:

| สถานะ | ความหมาย |
|---|---|
| `OK` | สำเร็จ |
| `WARN` | คำสั่งถูกปฏิเสธ (มักเพราะค่านั้นถูกซ่อน — unhide ก่อน) |
| `SKIP` | ไม่มีเป้าหมายให้ทำ (เช่น ไม่พบบริการนั้น) |
| `FAIL` | เกิด exception — ดู log ใน `logs/` |

`FAIL` ไม่ทำให้ทั้งโปรเซสหยุด (tweak อื่นยังทำงานต่อ) แต่ควรตรวจว่าเกิดจากอะไร

**apply ไม่ใช่การเลเยอร์**: ทุกครั้งจะ duplicate scheme จาก scheme ต้นฉบับแล้วใส่เฉพาะ tweaks ของโปรไฟล์นั้น การ apply โปรไฟล์ที่สองจะแทนที่ผลของโปรไฟล์แรก ไม่ใช่ต่อยอด (ดู [โปรไฟล์](04-โปรไฟล์.md))

## restore

```powershell
.\Level51Tune.ps1 restore                    # ไฟล์ apply ล่าสุด
.\Level51Tune.ps1 restore -BackupPath .\backups\20261112-153012_apply-gaming.json
.\Level51Tune.ps1 restore -Elevate
```

สิ่งที่ restore ทำ:

1. คืนค่า power index ทุกตัวที่เคยแก้ กลับเป็นค่าเดิม
2. คืนค่า registry (รวมถึงลบค่าที่เดิมไม่มี)
3. คืน startup type ของบริการและ start บริการที่เดิมทำงานอยู่
4. `powercfg -setactive <scheme เดิม>` และลบ scheme `LEVEL51-TUNE ...` ที่สร้างไว้

> tweaks ประเภท `Script` (fsutil, netsh, bcdedit, งาน ScheduledDefrag, MMCSS tasks) **ไม่สามารถย้อนอัตโนมัติได้** เพราะผลลัพธ์ไม่ใช่ค่าที่อ่านกลับมาเปรียบเทียบได้ง่าย — restore จะรายงานเป็น `SKIP` และบอกให้คืนค่าเอง (ดู [ความปลอดภัย การสำรอง และการย้อนกลับ](12-ความปลอดภัย-ย้อนกลับ.md))

## backup

```powershell
.\Level51Tune.ps1 backup
```

สร้าง `backups/<เวลา>_snapshot.json` ที่บรรจุฮาร์ดแวร์ + power scheme ปัจจุบัน ทำก่อนลองอะไรด้วยมือ (เช่น ก่อนแก้ใน BIOS-less tools)

## report

```powershell
.\Level51Tune.ps1 report
.\Level51Tune.ps1 report -Path .\reports\before-tuning.md
```

สร้าง markdown ที่มี: ตารางฮาร์ดแวร์, power scheme ทั้งหมด, สถานะทุก tweak (ทั้งโปรเจกต์), จำนวนที่ยังไม่ถูกปรับ เหมาะสำหรับแนบใน issue หรือเก็บไว้เทียบภายหลัง

## bench / compare

```powershell
.\Level51Tune.ps1 bench -Label before -Seconds 5
.\Level51Tune.ps1 bench -Label after
.\Level51Tune.ps1 compare -Last 4
```

`bench` วัด 4 อย่าง:

| ตัวชี้วัด | วิธีวัด | บอกอะไร |
|---|---|---|
| CPU 1 thread | ลูปคำนวณ sqrt ตามเวลาที่กำหนด | single-thread performance และ clock ที่ได้จริง |
| CPU N threads | runspace pool ตามจำนวน logical processor | multi-thread + scaling % (ถ้า scaling ต่ำผิดปกติ = throttling) |
| Memory copy | Buffer.BlockCopy 256 MB × 4 รอบ | memory bandwidth |
| Disk write/read | FileStream 1 MB buffer, 256 MB, Flush(true) | sequential IO ของ NVMe |

`compare` แสดง delta เป็น % พร้อมสี (เขียว = ดีขึ้น, แดง = แย่ลง) และย้ำว่า noise ±3-5%

## latency

```powershell
.\Level51Tune.ps1 latency
.\Level51Tune.ps1 latency -Seconds 30
```

อ่าน Windows performance counter ระหว่างเฝ้าดูตามเวลาที่กำหนด (ไม่ต้อง admin) แล้วสรุปว่า latency ผิดปกติหรือไม่

| counter | บอกอะไร | ค่าที่ดี |
|---|---|---|
| `% DPC Time` | เวลาที่ Kernel ใช้ใน deferred procedure call (ไดรเวอร์) | < 3% |
| `% Interrupt Time` | เวลาที่ใช้รับ interrupt จากฮาร์ดแวร์ | < 1% |
| `% Idle Time` | เครื่องว่างมากน้อยแค่ไหน (ใช้เทียบว่าตอนวัดมีงานอื่นวิ่งอยู่ไหม) | > 50% ตอน idle |
| `Context Switches/sec` | ความถี่ในการสลับ thread | ยิ่งต่ำยิ่งดีเมื่อ idle |

ใช้ `latency` เพื่อตรวจว่า "มีไดรเวอร์หรืออุปกรณ์ไหนทำให้เกิด jitter" ก่อนจูน — ถ้า DPC สูงผิดปกติ (> 3%) ให้ตามหาไดรเวอร์นั้นด้วย LatencyMon ก่อน เพราะ tweak พลังงานแก้ไม่ได้

ตัวอย่างผลจริงบนเครื่องนี้ (หลัง apply โปรไฟล์ performance, 15 วินาที):

```
  Counter                                          Avg      Max
  -------                                          ---      ---
  processor information(_total)\% dpc time         0.03     0.10
  processor_info(_total)\% idle time               84.76    88.37
  processor information(_total)\% interrupt time   0.17     0.39
  system\context switches/sec                   8426.16 10582.26

  สรุป: ปกติ
```

สำหรับการเทียบก่อน/หลังแบบเป็นระบบ (สลับ scheme A-B-B-A) ใช้ `tools\AB-Latency.ps1` — ต้องรันแบบ Administrator เพราะต้องสลับ power scheme

```powershell
# เปิด PowerShell แบบ Administrator
.\tools\AB-Latency.ps1 -Seconds 12
```

## history

```powershell
.\Level51Tune.ps1 history
.\Level51Tune.ps1 restore -BackupPath .\backups\20261112-120049_apply-performance.json
```

แสดงไฟล์ backup ทั้งหมดใน `backups/` เรียงใหม่สุดก่อน พร้อมโปรไฟล์ จำนวน tweak และบอกว่าไฟล์ไหนย้อนกลับได้ (เฉพาะ `*_apply-*.json`) — ใช้เมื่อต้องการย้อนกลับไปจุดใดจุดหนึ่ง ไม่ใช่แค่จุดล่าสุด

## gpuprefs

```powershell
.\Level51Tune.ps1 gpuprefs
.\Level51Tune.ps1 gpuprefs -AppPath "C:\Games\Game\game.exe" -Mode dgpu
.\Level51Tune.ps1 gpuprefs -AppPath "C:\Games\Game\game.exe" -Remove
```

จัดการ per-app GPU preference ใน `HKCU\Software\Microsoft\DirectX\UserGpuPreferences` (ไม่ต้อง admin, ไม่แตะเครื่องของผู้ใช้อื่น) — มีผลหลังปิด-เปิดแอปนั้น

| โหมด | ค่าที่เขียน | หมายเหตุ |
|---|---|---|
| `dgpu` | `GpuPreference=2;` | บังคับใช้ GTX 1060 (แก้ปัญหาเกมไปวิ่งบน UHD 630) |
| `igpu` | `GpuPreference=1;` | บังคับใช้ UHD 630 (ประหยัดแบต) |
| `auto` | `GpuPreference=0;` | ให้ Windows ตัดสินใจ |

## recommend

```powershell
.\Level51Tune.ps1 recommend
```

วิเคราะห์เครื่องจริงแล้วตอบ 3 อย่าง: โปรไฟล์ที่เหมาะ, จุดที่เป็นคอขวดที่ tweak ซอฟต์แวร์แก้ไม่ได้ (เช่น แรมแท่งเดียว), และข้อควรระวัง (ความร้อน, ดิสก์ผิดปกติ, แบตต่ำ)

ตัวอย่างผลบนเครื่องนี้:

```
  เครื่อง: Notebook N95TP6  (LEVEL51 / N95TP6)
  โปรไฟล์ที่แนะนำ: performance (ประสิทธิภาพ (ใช้งานประจำวัน))
  CPU class: desktop-class · RAM channels: 1 · dGPU: True

  ข้อควรระวัง
   ! CPU Intel Core i9-9900K (8C/16T) เป็นคลาสเดสก์ท็อป — ระบายความร้อนจำกัด ไม่ควรใช้โปรไฟล์ max ค้างไว้

  หมายเหตุ
   - แรมแท่งเดียว (32 GB) = single channel · bandwidth ราวครึ่งของ dual channel
   - มี dGPU: NVIDIA GeForce GTX 1060 — ถ้าเกมไปวิ่งบน iGPU ให้ตั้ง GPU ต่อแอปเป็น dgpu
```

ใช้ `recommend` เป็นจุดเริ่มต้นก่อนเลือกโปรไฟล์ โดยเฉพาะบนเครื่องที่ไม่ใช่ LEVEL51

## update

```powershell
.\Level51Tune.ps1 update
```

อ่าน metadata ของ release ล่าสุดจาก GitHub (`api.github.com/repos/NarDecH/LEVEL51-TUNE/releases/latest`) แล้วเทียบกับเวอร์ชันในเครื่อง — **คำสั่งเดียวในโปรแกรมที่ใช้เน็ต**, ไม่อัปเดตหรือดาวน์โหลดอะไรให้เอง ถ้าไม่มีเน็ตจะรายงานว่า "ตรวจไม่ได้" และคำสั่งอื่นทั้งหมดยังทำงานแบบ offline

## gpu

```powershell
.\Level51Tune.ps1 gpu
```

แสดงรายละเอียด GPU จาก `nvidia-smi` แบบ list และแนะนำคำสั่งตรวจเชิงลึก:

```powershell
nvidia-smi -q -d CLOCK,POWER,TEMPERATURE
nvidia-smi --query-gpu=clocks.gr,clocks.throttle --format=csv
```

## docs

```powershell
.\Level51Tune.ps1 docs
.\Level51Tune.ps1 docs -Open
```

แปลง `docs/*.md` ทั้งหมดเป็น HTML พร้อม sidebar, TOC, ตาราง, ปุ่มก่อนหน้า/ถัดไป และสร้าง `docs/index.html` เป็นสารบัญ ไม่ต้องติดตั้ง pandoc หรืออะไรเพิ่ม

## Exit codes

| code | ความหมาย |
|---|---|
| `0` | สำเร็จ |
| `1` | เกิดข้อผิดพลาด (สิทธิ์ไม่พอ, ไม่พบไฟล์, exception) |
| `2` | ไม่รู้จักคำสั่ง |

ใช้ในสคริปต์ได้:

```powershell
.\Level51Tune.ps1 apply -Profile gaming -DryRun
if ($LASTEXITCODE -ne 0) { Write-Error 'dry-run ล้มเหลว' }
```

## การใช้จาก PowerShell profile

ถ้าอยากเรียกสั้น ๆ ให้เพิ่ม function ใน `$PROFILE`:

```powershell
function l51 { & 'C:\_Project\LEVEL51-TUNE\Level51Tune.ps1' @args }
```

แล้วใช้ `l51 status`, `l51 apply -Profile gaming -DryRun` ได้เลย

## การเรียกใช้ engine ตรง ๆ (สำหรับ automation)

```powershell
Import-Module C:\_Project\LEVEL51-TUNE\src\Level51Tune.psm1 -Force

$hw = Get-L51Hardware
$rows = Invoke-L51Audit -Profile 'gaming'
$result = Invoke-L51Apply -Profile 'performance' -DryRun
$result.Results | Where-Object Status -ne 'OK'
```

ฟังก์ชันที่ export: `Get-L51Hardware`, `Get-L51GpuState`, `Get-L51Catalog`, `Get-L51Profiles`, `Get-L51ProfileTweaks`, `Invoke-L51Apply`, `Invoke-L51Restore`, `Invoke-L51Audit`, `Invoke-L51Backup`, `Get-L51Status`, `New-L51Report`, `Invoke-L51Bench`, `Compare-L51Bench`, `Measure-L51Latency`, `Build-L51Docs`, `Get-L51DashboardHtml`, `Get-L51LogPath`, `Get-L51PowerValue`, `Set-L51PowerValue`, `Test-L51TweakApplied`

## Web GUI

```powershell
.\Start-LEVEL51.cmd                     # 1 คลิก: ขอ UAC → เปิด dashboard
.\Level51Tune.Web.ps1                  # เปิดเอง (ไม่ elevate)
.\Level51Tune.Web.ps1 -Port 8899 -NoBrowser
.\Level51Tune.Web.ps1 -Elevate         # ขอ UAC แล้วเปิดตัวใหม่แบบ Administrator
```

dashboard มี 5 แท็บ: **ภาพรวม** (ฮาร์ดแวร์/โปรไฟล์/audit/bench/latency), **ตั้งค่า tweak** (เลือกทีละตัว ค้นหา/กรอง/บันทึก/ตรวจสถานะที่เลือก), **กราฟสด** (6 กราฟ อัปเดตทุก 2 วินาที), **ประวัติ/ย้อนกลับ** (restore backup ทีละครั้ง) และ **GPU ต่อแอป** (ตั้ง dgpu/igpu/auto ต่อไฟล์ .exe)

ถ้าต้องการไอคอนใน system tray ใช้ `Level51Tune.Tray.ps1` (เมนูสลับโปรไฟล์ + ตรวจสถานะ + เปิด Dashboard)

เป็น thin adapter อีกตัวที่เรียก engine เดียวกับ CLI ผ่าน HTTP (`System.Net.HttpListener`) — ไม่มี dependency ภายนอก ฟังเฉพาะ loopback และบังคับ token ทุก request

| endpoint | method | ทำอะไร |
|---|---|---|
| `/api/status` | GET | ฮาร์ดแวร์, scheme, โปรไฟล์ล่าสุด |
| `/api/audit` | POST | ตรวจสถานะ tweak ของโปรไฟล์ |
| `/api/apply` | POST | apply หรือ dry-run |
| `/api/restore` | POST | ย้อนกลับจาก backup ล่าสุด |
| `/api/bench` | POST | วัด CPU/RAM/Disk |
| `/api/latency` | POST | วัด DPC/interrupt |
| `/api/log` | GET | log ล่าสุด (กรอง DEBUG) |
| `/api/tweaks` | GET | tweaks ทั้งหมด + รายการที่บันทึกไว้ |
| `/api/settings` | GET/POST | อ่าน/บันทึก tweak ที่เลือกเอง |
| `/api/live` | GET | ค่าสด (CPU/GPU/RAM) สำหรับกราฟ |
| `/api/compare` | POST | วัด benchmark + เทียบกับครั้งก่อน |
| `/api/backups` | GET | รายการ backup (สำหรับหน้า “ประวัติ/ย้อนกลับ”) |
| `/api/gpu-prefs` | GET/POST | อ่าน/ตั้ง/ลบ GPU preference ต่อแอป |
| `/api/processes` | GET | รายชื่อโปรเซส (ตัวช่วยเลือก .exe) |
| `/api/update` | GET | ตรวจเวอร์ชันล่าสุดบน GitHub |
| `/docs/*` | GET | เอกสาร HTML |

header ที่ต้องส่ง: `X-L51-Token: <token>` (token พิมพ์อยู่ใน console ตอนเริ่ม และฝังใน URL ของ dashboard แล้ว)

ดูเหตุผลการออกแบบและ roadmap ที่ [GUI และ roadmap](15-GUI-และ-roadmap.md)
