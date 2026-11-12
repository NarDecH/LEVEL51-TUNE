# พลังงาน แบตเตอรี่ และความร้อน

## Windows จัดการพลังงานอย่างไร

Windows เก็บการตั้งค่าพลังงานไว้ใน **power scheme** (power plan) แต่ละ scheme คือชุดค่า index ของ "power setting" หลายร้อยตัว ซึ่งถูกจัดกลุ่มเป็น **subgroup** และอ้างด้วย GUID

```
Power Scheme (GUID)
└── Subgroup: Processor power management (54533251-82be-4824-96c1-47b60b740d00)
    ├── Minimum processor state (893dee8e-2bef-41e0-89c6-b55d0929964c)
    ├── Maximum processor state (bc5038f7-23e0-4960-96da-33abaf5935ec)
    ├── Processor performance boost mode (be337238-0d82-4146-a960-4f3749d470c7)
    └── ...
```

ทุกค่าเก็บ **สองชุด**: AC (ต่อไฟ) และ DC (ใช้แบต) นี่คือเหตุผลที่โปรไฟล์ `battery` แตะเฉพาะ DC

### ทำไมโปรแกรมนี้สร้าง scheme ใหม่

`apply` เรียก `powercfg -duplicate` จาก scheme ที่ใช้อยู่ แล้วตั้งชื่อ `LEVEL51-TUNE <โปรไฟล์>`

ข้อดี:

- แผนเดิม (Balanced / GameTurbo / LEVEL51 Ultimate Performance ของคุณ) ไม่ถูกแตะเลย
- เปรียบเทียบได้ด้วยการสลับ scheme ใน Control Panel
- `restore` ลบ scheme ที่สร้างและสลับกลับได้สะอาด

ข้อควรรู้: scheme ที่ duplicate มาจะมีค่าเหมือนต้นฉบับทุกอย่าง **รวมถึงค่าที่ซ่อนอยู่** ซึ่งเป็นสิ่งที่ต้องการ

## ค่าที่โปรแกรมปรับ และความหมายจริง

| Setting (alias) | GUID | ค่า | ความหมาย |
|---|---|---|---|
| `PROCTHROTTLEMIN` | 893dee8e… | 0-100 | เพดานล่างของ state (%) |
| `PROCTHROTTLEMAX` | bc5038f7… | 0-100 | เพดานบน (%) — ค่า 99 มักปิด Turbo โดยไม่ตั้งใจ |
| `PERFBOOSTMODE` | be337238… | 0-6 | 0=ปิด, 1=เปิด, 2=Aggressive, 3=Efficient Enabled, 4=Efficient Aggressive |
| `PERFEPP` | 36687f9e… | 0-100 | Energy Performance Preference (0=แรง, 100=ประหยัด) |
| `CPMINCORES` | 0cc5b647… | 0-100 | จำนวนคอร์ขั้นต่ำที่ไม่ถูก park (%) |
| `SYSCOOLPOL` | 94d3a615… | 0/1 | 0=Passive (ลด clock ก่อน), 1=Active (เร่งพัดลมก่อน) |
| `IDLEDISABLE` | 5d76a2ca… | 0/1 | 1=ปิด C-state |
| `PERFINCTHRESHOLD` | 06cadf0e… | 0-100 | เกณฑ์การเพิ่มความถี่ |
| `ASPM` (SUB_PCIEXPRESS) | ee12f906… | 0/1/2 | 0=Off, 1=Moderate, 2=Maximum savings |
| `DISKIDLE` (SUB_DISK) | 6738e2c4… | วินาที | 0=ไม่ปิดดิสก์ |
| `USBSELECTIVESUSPEND` | 48e6b7a6… | 0/1 | ปิด/เปิด selective suspend |
| `VIDEOIDLE` (SUB_VIDEO) | 3c0bc021… | วินาที | ปิดจอหลัง |
| `STANDBYIDLE` (SUB_SLEEP) | 29f6c1db… | วินาที | sleep หลัง |
| `LIDACTION` (SUB_BUTTONS) | 5ca83367… | 0-3 | 0=ไม่ทำอะไร, 1=sleep, 2=hibernate, 3=shutdown |

### ค่าที่ถูกซ่อน

Windows ซ่อนค่าหลายตัวจาก UI (เช่น PERFBOOSTMODE, CPMINCORES, PERFEPP) การ `-setacvalueindex` ยังทำได้ แต่บางไดรเวอร์/บิลด์จะปฏิเสธถ้าไม่ปลดซ่อน — tweak `win.unhide-power-settings` จึงมีอยู่:

```powershell
powercfg -attributes SUB_PROCESSOR PERFBOOSTMODE -ATTRIB_HIDE
```

`-ATTRIB_HIDE` = **ปลด**การซ่อน (ชื่ออ่านกลับกันได้ง่ายจนสับสน) ส่วน `+ATTRIB_HIDE` = ซ่อนกลับ

## คำสั่ง `powercfg` ที่มีประโยชน์

```powershell
# ดู scheme ทั้งหมด และอันที่ใช้อยู่
powercfg /list
powercfg /getactivescheme

# ดูค่าของ subgroup หนึ่งทั้งหมด
powercfg /query SCHEME_CURRENT SUB_PROCESSOR

# ดูค่ารายตัว
powercfg /query SCHEME_CURRENT SUB_PROCESSOR PERFBOOSTMODE

# ตั้งค่าเอง (AC)
powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX 90
powercfg /setactive SCHEME_CURRENT

# ตั้งค่าเอง (DC)
powercfg /setdcvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX 70

# รายงานการใช้พลังงาน 60 วินาที (ต้อง admin) — หาตัวที่ทำให้กินไฟ
powercfg /energy /duration 60 /output $env:TEMP\energy.html

# รายงานแบตเตอรี่ละเอียด
powercfg /batteryreport /output $env:TEMP\battery.html

# วิเคราะห์ sleep/Modern Standby
powercfg /sleepstudy /output $env:TEMP\sleep.html

# ดูว่าอะไรกันไม่ให้เครื่อง sleep
powercfg /requests
```

`powercfg /energy` เป็นเครื่องมือที่ดีที่สุดในการหาสาเหตุที่เครื่องไม่ sleep หรือใช้ไฟสูง: มันจะบอกชื่อ device/driver/program ที่มีปัญหาเป็นรายชื่อพร้อม count

## แบตเตอรี่บนเครื่องนี้

จาก `status`:

```
แบตเตอรี่ : BAT · 100% · design voltage 12.529 V
```

เครื่อง N95TP6 ใช้แบต 6-cell (ราว 62 Wh ตามสเปกเครื่อง Clevo รุ่นนี้) — ตรวจค่าจริงได้:

```powershell
Get-CimInstance -Namespace root\wmi -ClassName BatteryFullChargedCapacity |
  Select-Object InstanceName, FullChargedCapacity
Get-CimInstance -Namespace root\wmi -ClassName BatteryStatus |
  Select-Object RemainingCapacity, Voltage, ChargeRate, DischargeRate
```

`FullChargedCapacity` ที่ต่ำกว่าค่า design มาก (>20%) = แบตเริ่มเสื่อม

### การดูแลแบต

| เคล็ดลับ | เหตุผล |
|---|---|
| ตั้ง charge limit 80% ถ้าซอฟต์แวร์เครื่องรองรับ | แบต Li-ion เสื่อมช้าลงเมื่อไม่ค้างที่ 100% |
| อย่าทิ้งไว้ที่ 0% เป็นเวลานาน | แรงดันต่ำทำให้ cell เสียหายถาวร |
| ใช้โปรไฟล์ `battery` เมื่อไม่ได้ต่อไฟ | ลดทั้งความร้อนและการกินไฟ |
| อย่าใช้ `power.cpu.min100` บนแบต | กินไฟสูงสุดตลอดเวลา — ขัดกับวัตถุประสงค์ |

### อายุการใช้งานจริงที่คาดหวัง

i9-9900K กินไฟ 15-45 W ในงานเบา การใช้งานออฟฟิศ (เขียนเอกสาร, เว็บ) จะได้ราว 2.5-4 ชั่วโมงจากแบต 62 Wh ถ้าเล่นเกม <= 45-60 นาที นี่คือข้อจำกัดทางฟิสิกส์ ไม่ใช่การตั้งค่า

## ความร้อน — ปัญหาหลักของเครื่องนี้

### ทำไมร้อน

- ซีพียูเดสก์ท็อป 95W TDP (burst ถึง 210W) ในตัวเครื่องที่ออกแบบมาสำหรับชิ้นส่วนมือถือ
- GTX 1060 ปล่อยความร้อนเพิ่ม 88 W ในห้องเดียวกัน
- ฮีตไปป์และพัดลมมีพื้นที่จำกัด

ความร้อนรวมตอนเล่นเกมอาจถึง 150-190 W ซึ่งต้องระบายออกจากเครื่องขนาด ~2.5-3.5 ซม.

### มาตรวัดอุณหภูมิที่ควรรู้

| ค่า | ปกติ | ควรกังวล |
|---|---|---|
| CPU package (idle) | 38-50 °C | > 60 °C ตอน idle |
| CPU package (โหลด) | 70-90 °C | > 95 °C ค้าง + throttle |
| GPU (idle) | 40-52 °C | > 60 °C |
| GPU (โหลด) | 70-82 °C | > 86 °C (จะ throttle ที่ ~87) |
| SSD NVMe | 35-55 °C | > 70 °C (จะ throttle) |

### วิธีลดความร้อนที่ได้ผลจริง (เรียงตามความคุ้มค่า)

1. **ทำความสะอาดพัดลมและซี่ฮีตซิงก์** — ฝุ่นสะสม 1-2 ปีทำให้อุณหภูมิขึ้น 8-15 °C
2. **เปลี่ยน thermal paste** (ของเดิมจากโรงงานมักแห้งแล้วถ้าเครื่องอายุ 3+ ปี) — ลดได้ 5-12 °C
3. **Undervolt CPU** (-100 mV) — ลด 5-10 °C ที่ performance เท่าเดิม
4. **Undervolt GPU** — ลด 5-8 °C
5. **ยกเครื่องให้สูงขึ้น 2-3 ซม.** หรือใช้ cooling pad แบบblower — ลด 3-6 °C
6. **ตั้ง fan curve ให้ aggressive ขึ้น** (BIOS หรือ Control Center)
7. **จำกัด max frame rate** ในเกมเป็น 60/72 fps — ลด GPU load มาก
8. **ลด PL1 ใน BIOS** (ถ้าปรับได้) เป็น 65-75 W — เสีย performance 5-10% แต่เย็นลงชัด

### Thermal throttling ทำงานอย่างไร

เมื่ออุณหภูมิถึง Tjmax (100 °C สำหรับ 9900K) ซีพียูจะลด clock ทีละขั้น (Intel Dynamic Tuning) จนกว่าอุณหภูมิจะลง — ผลคือ fps ตกเป็นขั้นบันได ไม่ใช่ค่อย ๆ ลด

สังเกตได้จาก HWiNFO: `Thermal Throttling = Yes`, `Core Effective Clocks` ตกลง, `PROCHOT` ขึ้น

ถ้าเกิดถี่ ให้หยุดใช้โปรไฟล์ `max` และแก้ที่ระบบระบายความร้อนก่อน

## Sleep / Hibernate / Fast Startup

| กลไก | ทำงานอย่างไร | ข้อดี | ข้อเสีย |
|---|---|---|---|
| Sleep (S3) | RAM ยังมีไฟ, สถานะอยู่ใน RAM | ตื่นเร็ว < 2 วินาที | กินไฟเล็กน้อย, แบตหมด = ข้อมูลหาย |
| Modern Standby (S0ix) | เครื่อง "ตื่นบางส่วน" ตลอด | แจ้งเตือนได้ขณะพัก | กินไฟมากกว่า S3 มาก, มักมีปัญหาเครื่องร้อนในกระเป๋า |
| Hibernate (S4) | เขียน RAM ลงดิสก์แล้วปิดเครื่อง | ไม่กินไฟเลย | ใช้พื้นที่ = ขนาด RAM (~32 GB), boot ช้า |
| Fast Startup | ผสม hibernate เฉพาะ kernel session | boot เร็วขึ้น | ไดรเวอร์/สถานะไมตรีเซ็ตจริง — ต้นเหตุบั๊กแปลก ๆ |

tweak `power.hibernate-off` ในโปรไฟล์ `max` ปิด Hibernate + Fast Startup และคืนพื้นที่ ~32 GB บน C:

```powershell
powercfg -h off     # ปิด
powercfg -h on      # เปิดกลับ
```

ตรวจว่าเครื่องนี้ใช้ Modern Standby หรือ S3:

```powershell
powercfg /a
```

ถ้าขึ้น "Standby (S0 Low Power Idle)" = Modern Standby ถ้าเป็น S3 จะขึ้น "Standby (S3)"

> บน Modern Standby เครื่องที่ใส่ SSD NVMe มักร้อนในกระเป๋าเพราะระบบตื่นมาทำงานเบื้องหลังตลอด ถ้าเจอปัญหานี้ ให้ปิด network ใน sleep หรือใช้ Hibernate แทน

## AC vs DC — ต่างกันอย่างไรในทางปฏิบัติ

| สถานการณ์ | โปรไฟล์ | ค่าที่ต่าง |
|---|---|---|
| ต่อไฟ เล่นเกม | gaming | min 50%, ASPM off, ไม่ sleep |
| ใช้แบต ทำงานเอกสาร | battery | min 5%, max 70%, ASPM max savings, จอดับ 5 นาที |
| ต่อไฟ เรนเดอร์ | performance | min 50%, ไม่ sleep, จอดับ 20 นาที |
| benchmark | max | min 100%, boost aggressive |

Windows สลับ AC/DC อัตโนมัติเมื่อถอด/เสียบสาย **โดยไม่ต้อง apply ใหม่** ถ้าใช้โปรไฟล์ `battery` (ซึ่งตั้งเฉพาะ DC) — แต่ถ้าใช้ `gaming` (ตั้งเฉพาะ AC บางตัว + DC บางตัว) จะมีผลทั้งสองโหมด

## ตรวจสอบว่าการตั้งค่ามีผลจริง

```powershell
# ค่าที่ใช้อยู่จริง (ไม่ใช่ค่าที่บันทึกใน scheme)
powercfg /getactivescheme
powercfg /query SCHEME_CURRENT SUB_PROCESSOR

# ตรวจว่า scheme ที่โปรแกรมสร้างยังอยู่
.\Level51Tune.ps1 status
```

ถ้า apply แล้ว `audit` ยังขึ้น `no` ให้ตรวจ:

1. มีโปรแกรม OEM (Control Center / Armoury Crate / ThrottleStop) เขียนทับค่าหรือไม่
2. Windows Update / ไดรเวอร์ chipset รีเซ็ต scheme หรือไม่
3. ค่านั้นถูกซ่อนและถูกปฏิเสธ (ดู `WARN` ตอน apply)

## สรุป

1. โปรแกรมนี้ไม่แตะ scheme เดิมของคุณ — สร้างใหม่และสลับให้
2. AC/DC แยกกัน โปรไฟล์ `battery` จึงมีผลเฉพาะตอนใช้แบต
3. ความร้อนคือคอขวดจริงของเครื่องนี้ — ซอฟต์แวร์ช่วยได้ถึงจุดหนึ่ง
4. `powercfg /energy` และ `/batteryreport` คือเครื่องมือวินิจฉัยที่ดีที่สุดและฟรี
5. หลีกเลี่ยง Modern Standby ที่ทำให้เครื่องร้อนในกระเป๋า ถ้าเจอปัญหา
