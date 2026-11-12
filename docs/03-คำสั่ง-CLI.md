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
| `-IncludeHigh` | switch | audit | แสดง/ตรวจ tweaks High ด้วย |
| `-BackupPath <file>` | string | restore | ระบุไฟล์ backup (ค่าเริ่มต้น: ล่าสุด) |
| `-Path <file>` | string | report | ที่เก็บรายงาน |
| `-Label <text>` | string | bench | ชื่อกำกับผล (เช่น `before`, `after`, `max-profile`) |
| `-Seconds <n>` | int | bench | เวลาต่อรอบ CPU (ค่าเริ่มต้น 3) |
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

คอลัมน์ `Applied`: `YES` = ตรงกับเป้าหมายแล้ว, `no` = ยังไม่ตรง, `?` = ตรวจไม่ได้ (เช่น tweak แบบ Script ที่ไม่มี detect)

ใช้ `audit` เพื่อตอบคำถามว่า "ตอนนี้เครื่องอยู่ในสภาพไหน" หลังจาก apply ไปแล้วหรือหลัง Windows Update รีเซ็ตค่าบางอย่าง

## apply

```powershell
# ดูของก่อน
.\Level51Tune.ps1 apply -Profile performance -DryRun

# apply จริง (ต้อง admin)
.\Level51Tune.ps1 apply -Profile performance

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

`FAIL` ไม่ทำให้ทั้ง proses หยุด (tweak อื่นยังทำงานต่อ) แต่ควรตรวจว่าเกิดจากอะไร

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

ฟังก์ชันที่ export: `Get-L51Hardware`, `Get-L51GpuState`, `Get-L51Catalog`, `Get-L51Profiles`, `Get-L51ProfileTweaks`, `Invoke-L51Apply`, `Invoke-L51Restore`, `Invoke-L51Audit`, `Invoke-L51Backup`, `Get-L51Status`, `New-L51Report`, `Invoke-L51Bench`, `Compare-L51Bench`, `Build-L51Docs`, `Get-L51PowerValue`, `Set-L51PowerValue`, `Test-L51TweakApplied`
