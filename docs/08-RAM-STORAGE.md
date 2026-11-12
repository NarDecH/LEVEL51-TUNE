# RAM และ Storage

## หน่วยความจำในเครื่องนี้

```
RAM : 32.6 GB (ว่าง 30.1 GB)
```

ตรวจรายละเอียดระดับโมดูล:

```powershell
Get-CimInstance Win32_PhysicalMemory |
  Select-Object DeviceLocator, Capacity, Speed, ConfiguredClockSpeed, Manufacturer, PartNumber
```

| ค่า | ความหมาย |
|---|---|
| `Speed` | ความเร็วที่โมดูลรองรับ (SPD/XMP) |
| `ConfiguredClockSpeed` | ความเร็วที่ **ใช้งานจริง** — ถ้าต่ำกว่า Speed มาก แสดงว่า XMP ปิดอยู่ |
| `DeviceLocator` | ช่อง DIMM (DIMM0/DIMM1) |
| `PartNumber` | รุ่นโมดูล ใช้ค้นหาสเปก |

### Dual channel

i9-9900K มี memory controller แบบ dual-channel ถ้าใส่แรม 2 แท่งในช่องที่ถูกต้อง (มักเป็น DIMM0 + DIMM1 หรือ A2 + B2) จะได้ bandwidth สองเท่า **ตรวจให้แน่ใจว่าทำงาน dual channel**:

```powershell
Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum |
  Select-Object Count, Sum
```

ถ้าเห็น 2 แท่งแต่ bandwidth ต่ำผิดปกติ ให้ตรวจว่าใส่ถูกช่อง (ดูคู่มือ mainboard ของ barebone) — การใส่แรมผิดช่องเป็นสาเหตุที่พบบ่อยและแก้ฟรี

### XMP

i9-9900K รองรับ DDR4-2666 อย่างเป็นทางการ แรมที่เร็วและมี XMP ต้องเปิด profile ใน BIOS จึงจะทำงานที่ความเร็วนั้น ถ้าเปิด XMP แล้วไม่เสถียร (จอฟ้า/timeout) ให้ลดลงหนึ่งสเต็ป หรือเพิ่มไฟ DRAM เล็กน้อย — **ระวัง**: เครื่อง Clevo หลายรุ่นจำกัดการเข้าถึงค่าไฟแรม

### Pagefile (virtual memory)

ค่าเริ่มต้น "system managed" เหมาะกับเกือบทุกกรณี การตั้ง manual เป็นค่านิยมที่มักให้ผลตรงข้าม:

- ถ้าตั้งเล็กเกินไป → Photoshop/VM/เกมหนักจะ crash ด้วย "out of memory"
- ถ้าปิด pagefile ทั้งหมด → crash dump ไม่ทำงาน และบางโปรแกรมปฏิเสธที่จะรัน
- RAM 32 GB ไม่ได้หมายความว่าไม่ต้องมี pagefile — Windows ใช้มันเป็น commit charge เสมอ

ตรวจค่าปัจจุบัน:

```powershell
Get-CimInstance Win32_PageFileUsage | Select-Object Name, AllocatedBaseSize, CurrentUsage, PeakUsage
```

**คำแนะนำ**: ปล่อยเป็น system managed บน SSD NVMe ไม่ต้องย้ายไปดิสก์อื่น

### Memory Compression

Windows 10/11 บีบอัดหน้า memory ที่ไม่ค่อยได้ใช้แทนการเขียนลง pagefile ช่วยให้เครื่อง 32 GB รับงานได้มากกว่าที่คาด ถ้าอยากดูว่าทำงานอยู่:

```powershell
Get-Process -Name 'Memory Compression' -ErrorAction SilentlyContinue |
  Select-Object Name, WorkingSet64
```

อย่าปิด Memory Compression — มีคนแนะนำให้ปิดเพราะ "กิน CPU" แต่ผลสุทธิคือแย่ลงในงานส่วนใหญ่

## tweaks ของโปรเจกต์ที่เกี่ยวกับ RAM

| Tweak | ค่า | โปรไฟล์ | ผล / ข้อควรระวัง |
|---|---|---|---|
| `mem.priority-separation` | `Win32PrioritySeparation=38` | performance, gaming, max | foreground ได้ CPU 3:1 — ต้อง reboot |
| `mem.large-system-cache` | `LargeSystemCache=1` | max | file cache มากขึ้น; ถ้าเปิด VM หลายตัวอาจแย่ลง |
| `mem.ntfs-memory-usage` | `NtfsMemoryUsage=2` | max | metadata cache มากขึ้น เหมาะกับงานไฟล์จำนวนมาก |
| `mem.sysmain-off` | Service `SysMain=Disabled` | max | ลด IO พื้นหลัง; โปรแกรมเปิดช้าลงเล็กน้อย |
| `mem.prefetch-off` | `EnablePrefetcher=0` | max | ลด IO; ถกเถียงกันมากบน SSD |

### ควรปิด SysMain จริงไหม

| ฝ่าย | เหตุผล |
|---|---|
| ควรปิด | บน NVMe การ prefetch ให้ประโยชน์น้อย, service กิน RAM/CPU พื้นหลัง, บางเครื่องมีอาการ disk 100% |
| ไม่ควรปิด | Windows ออกแบบมาให้ทำงานร่วมกัน; การเปิดโปรแกรมเดิมซ้ำเร็วขึ้น measurable; ปิดแล้วบายพาสกลไกที่ Microsoft ปรับมาแล้ว |

**คำตอบที่ซื่อสัตย์**: ผลขึ้นกับเครื่อง วัดด้วย `bench` และความรู้สึกจริง (เวลาเปิด Photoshop/เกม) ถ้าไม่ต่าง ให้เปิดกลับ (default) เพราะได้ประโยชน์จาก prefetch ในระยะยาว

## Storage: Samsung 990 EVO Plus 1 TB NVMe

```
Samsung SSD 990 EVO Plus 1TB · 932 GB · NVMe · Healthy
```

| คุณสมบัติ | ค่า |
|---|---|
| Interface | PCIe 4.0 x4 (ทำงานได้ทั้ง 4.0/5.0 ตามสล็อต) |
| Sequential read | ~7,250 MB/s (สเปกผู้ผลิต) |
| Sequential write | ~6,300 MB/s |
| NAND | TLC V-NAND |
| DRAM cache | มี |
| Endurance | ~600 TBW |

หมายเหตุ: เครื่อง N95TP6 เป็นแพลตฟอร์ม Z390/CM246 ยุค 2019 ซึ่งรองรับ **PCIe 3.0** เท่านั้น ดังนั้น SSD นี้จะทำงานที่ ~3,500 MB/s ไม่ใช่ 7,250 — ไม่ใช่ปัญหา ไม่ใช่ของเสีย แค่เป็นเพดานของชิปเซ็ต

### ตรวจสุขภาพ SSD

```powershell
Get-PhysicalDisk | Select-Object FriendlyName, MediaType, HealthStatus, OperationalStatus
Get-Disk | Select-Object Number, FriendlyName, HealthStatus, BusType
Get-StorageReliabilityCounter -PhysicalDisk (Get-PhysicalDisk -FriendlyName 'Samsung SSD 990 EVO Plus 1TB') |
  Select-Object Temperature, Wear, ReadErrorsTotal, WriteErrorsTotal, PowerOnHours
```

| ค่า | ความหมาย |
|---|---|
| `Wear` | เปอร์เซ็นต์การสึก (0 = ใหม่, 100 = หมดอายุ) |
| `Temperature` | อุณหภูมิ NVMe — เกิน 70 °C จะ throttle |
| `PowerOnHours` | ชั่วโมงใช้งานจริง |

### TRIM

TRIM บอก SSD ว่า block ไหนไม่มีข้อมูลแล้ว จำเป็นมากสำหรับประสิทธิภาพและอายุ SSD

```powershell
fsutil behavior query DisableDeleteNotify
# DisableDeleteNotify = 0  → TRIM เปิด (ถูกต้อง)
# DisableDeleteNotify = 1  → TRIM ปิด (ต้องแก้)
```

ถ้าปิด: `fsutil behavior set DisableDeleteNotify 0` (ต้อง admin)

### Defrag vs Optimize

บน SSD Windows จะรัน "Retrim" ไม่ใช่ defrag จริง tweak `disk.defrag-task-off` ปิดงานตามกำหนดการ ซึ่งลด IO พื้นหลังได้ แต่ก็หยุด retrim เป็นระยะด้วย

**คำแนะนำที่สมดุล**: ปิดตามกำหนดการแล้วรัน `Optimize-Volume -DriveLetter C -ReTrim -Verbose` ด้วยมือเดือนละครั้ง หรือใช้โปรไฟล์ `performance` ซึ่งปิด task แต่ยัง trims เมื่อมีคำสั่ง

### ค่าที่ควรตรวจเกี่ยวกับ NTFS

| คำสั่ง | ค่าปกติ | คำอธิบาย |
|---|---|---|
| `fsutil behavior query disablelastaccess` | 1 | ปิด last access (Win11 default) |
| `fsutil behavior query disable8dot3` | 2 (per-volume) | สร้างชื่อ 8.3 |
| `fsutil behavior query memoryusage` | 1 | NTFS paged pool |
| `fsutil behavior query disabledeletenotify` | 0 | TRIM เปิด |

## ดิสก์ USB ภายนอก

จาก `status`:

```
Seagate One Touch w/PW · 4.5 TB · USB · Healthy
```

ข้อควรรู้:

- ดิสก์ USB จะถูกตั้งเป็น "quick removal" (write caching off) โดย default — ปลอดภัยกว่าแต่ช้ากว่า
- การเปิด write caching บนดิสก์ USB เพิ่มความเสี่ยงข้อมูลหายถ้าถอดสายผิดวิธี
- ถ้าใช้เป็น backup target ให้ตั้ง exclusion ใน Windows Defender เพื่อลด IO ที่ไม่จำเป็น (เฉพาะโฟลเดอร์ backup)

## Indexing (Windows Search)

tweak `disk.indexing-off` ปิด `WSearch` ซึ่งเป็นบริการที่สร้าง index สำหรับค้นหาใน Start/Explorer/Outlook

| ผล | รายละเอียด |
|---|---|
| ดีขึ้น | ลด IO/CPU พื้นหลังได้ชัดโดยเฉพาะหลัง boot |
| แย่ลง | ค้นหาไฟล์/เนื้อหาในไฟล์ช้าลงมาก, Outlook search ไม่ทำงาน, Start menu ค้นหาแอปยังใช้ได้แต่ช้ากว่า |

**ทางเลือกที่สมดุลกว่า**: ปิดเฉพาะโฟลเดอร์ที่ไม่ต้องการ (เช่น โฟลเดอร์ build, node_modules, Steam library) ผ่าน Indexing Options แทนการปิดทั้งบริการ

## พื้นที่ดิสก์

การมีพื้นที่ว่างน้อยทำให้ SSD ช้าลง (garbage collection ทำงานได้ไม่เต็มที่) และ Windows Update/pagefile มีปัญหา

| พื้นที่ว่าง | สถานะ |
|---|---|
| > 20% | ดี |
| 10-20% | พอใช้ |
| < 10% | ควรจัดเก็บ — SSD จะช้าลงและ wear leveling แย่ลง |

หาไฟล์ใหญ่:

```powershell
Get-ChildItem C:\ -Recurse -File -ErrorAction SilentlyContinue |
  Sort-Object Length -Descending | Select-Object -First 20 FullName,
  @{n='GB';e={[math]::Round($_.Length/1GB,2)}}
```

## tweaks ประเภท Script ที่เกี่ยวกับ Storage

tweaks เหล่านี้ใช้ `fsutil` / `ScheduledTasks` และ **restore จะไม่คืนค่าให้อัตโนมัติ** (รายงานเป็น `SKIP`):

| Tweak | คำสั่งที่รัน | วิธีคืนค่าเอง |
|---|---|---|
| `disk.last-access-off` | `fsutil behavior set disablelastaccess 1` | `fsutil behavior set disablelastaccess 2` |
| `disk.8dot3-off` | `fsutil behavior set disable8dot3 1` | `fsutil behavior set disable8dot3 2` |
| `disk.defrag-task-off` | `Disable-ScheduledTask ScheduledDefrag` | `Enable-ScheduledTask -TaskName ScheduledDefrag` |

## ตรวจสอบผลด้วย bench

`bench` วัด disk write/read 256 MB แบบ sequential — ตัวเลขที่ควรได้บนเครื่องนี้ (PCIe 3.0):

| รายการ | ช่วงที่คาดหวัง |
|---|---|
| Disk write | 1,200-2,500 MB/s |
| Disk read | 1,500-4,000 MB/s (อาจได้จาก cache) |
| Memory copy | 4,000-6,000 MB/s (single channel) / 8,000-14,000 MB/s (dual channel) |

> เครื่องนี้ตรวจพบแรม **1 แท่ง 32 GB** (ChannelA-DIMM0 @ 3200 MT/s) ซึ่งหมายถึง **single channel** — memory bandwidth จึงเหลือประมาณครึ่งเดียวของสิ่งที่ i9-9900K ทำได้ การเพิ่มแรมอีกแท่งที่ความเร็วเท่ากันคือการอัปเกรดที่คุ้มที่สุดสำหรับเครื่องนี้ (ดู [ผลตรวจเครื่องนี้](13-ผลตรวจเครื่องนี้.md))

ถ้าได้ต่ำกว่ามาก:

- disk < 600 MB/s → ตรวจว่า SSD ต่อที่ PCIe 3.0 x4 จริง (ไม่ใช่ x2/SATA), ตรวจอุณหภูมิ, ตรวจว่าไดรเวอร์ NVMe ถูกต้อง
- memory < 8,000 MB/s → อาจเป็น single channel หรือแรมวิ่งที่ 2133 MHz (XMP ปิด)

## สรุป

1. RAM 32 GB เพียงพอสำหรับเกมและงานทั่วไป — อย่าปิด pagefile
2. ตรวจว่าแรมวิ่ง dual channel และ XMP เปิด (ถ้ามี)
3. SSD ทำงานที่ PCIe 3.0 เพราะชิปเซ็ต — ยอมรับเพดานนี้
4. ตรวจ TRIM เปิด และเหลือพื้นที่ว่าง > 20%
5. SysMain/Prefetcher เป็นการแลกที่ต้องวัดผลเอง ไม่มีคำตอบเดียวที่ถูกสำหรับทุกคน
