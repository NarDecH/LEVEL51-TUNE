# แก้ปัญหาและคำถามที่พบบ่อย

## ปัญหาการใช้งานโปรแกรม

### "cannot be loaded because running scripts is disabled on this system"

```powershell
Get-ChildItem -Recurse -Include *.ps1,*.psm1 | Unblock-File
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

### "ต้องใช้สิทธิ์ Administrator"

เปิด PowerShell ด้วยคลิกขวา → **Run as administrator** หรือเพิ่ม `-Elevate`:

```powershell
.\Level51Tune.ps1 apply -Profile gaming -Elevate
```

### apply แล้วขึ้น WARN "powercfg ปฏิเสธค่า"

ค่านั้นถูกซ่อนอยู่ วิธีแก้:

```powershell
.\Level51Tune.ps1 apply -Profile performance     # มี win.unhide-power-settings
# หรือสั่งเองรายตัว:
powercfg -attributes SUB_PROCESSOR PERFBOOSTMODE -ATTRIB_HIDE
```

### ตัวอักษรไทยใน console เพี้ยน (PowerShell 5.1)

```powershell
chcp 65001
```

หรือใช้ Windows Terminal / PowerShell 7 (`pwsh`) ซึ่งรองรับ UTF-8 โดย default

### `Import-Module` ฟ้องว่าไม่มีไฟล์

ต้องรันจากโฟลเดอร์รากของโปรเจกต์ หรือใช้ absolute path:

```powershell
Import-Module C:\_Project\LEVEL51-TUNE\src\Level51Tune.psm1 -Force
```

### ไฟล์ `.psm1` อ่านภาษาไทยไม่ออก

ไฟล์ทั้งหมดถูกบันทึกเป็น UTF-8 **with BOM** เพื่อให้ Windows PowerShell 5.1 อ่านได้ถูกต้อง ถ้าแก้ไฟล์ด้วย editor ที่บันทึกเป็น UTF-8 without BOM แล้วภาษาไทยเพี้ยน ให้บันทึกใหม่เป็น "UTF-8 with BOM"

## ปัญหาหลัง apply

### audit ขึ้น `no` ทั้งที่ apply ไปแล้ว

| สาเหตุ | วิธีตรวจ | วิธีแก้ |
|---|---|---|
| ค่า power ถูกซ่อน/ถูกปฏิเสธ | ดู WARN ตอน apply | unhide ก่อน |
| โปรแกรม OEM เขียนทับ | ปิด Control Center/ThrottleStop | ปิดแล้ว apply ใหม่ |
| Windows Update รีเซ็ต registry | ดู `audit` หลังอัปเดต | apply ซ้ำ |
| ยังไม่ reboot | ดูคอลัมน์ `reboot` | restart เครื่อง |
| Fast Startup ยังเปิด | `powercfg /a` | `powercfg -h off` แล้ว shutdown จริง |

### หลัง apply แล้วเครื่องร้อนขึ้น/พัดลมดังขึ้น

นี่คือ **ผลที่คาดหวัง** ของโปรไฟล์ `performance`/`gaming`/`max` (min state สูงขึ้น, boost aggressive, C-state off)

ถ้าไม่ต้องการ:

```powershell
.\Level51Tune.ps1 restore      # กลับทั้งหมด
# หรือใช้โปรไฟล์ที่เบากว่า
.\Level51Tune.ps1 apply -Profile balanced
```

### เกมได้ fps ต่ำลงหลัง apply

สาเหตุที่เป็นไปได้:

1. **HAGS** — เกมเก่าบางตัวแย่ลงเมื่อเปิด HAGS → ปิด `HwSchMode=0` และ reboot
2. **Fullscreen optimization ปิด** — เกม DX12 บางตัวมีปัญหา → คืนค่า `GameDVR_FSEBehaviorMode=0`
3. **ความร้อน** — โปรไฟล์ max ทำให้ throttle → เปลี่ยนเป็น gaming/performance
4. **Power Throttling ปิด** — ความร้อนเพิ่ม → ตรวจอุณหภูมิ

### ปิด GameDVR แล้วอัดคลิปไม่ได้

GameDVR background recording คือการอัดย้อนหลังอัตโนมัติ ถ้าต้องการอัดจริงจัง ให้ใช้ OBS (และใช้ QuickSync ของ iGPU เป็น encoder)

### ปิด Windows Search แล้วหาไฟล์ไม่เจอ

```powershell
Set-Service -Name WSearch -StartupType Automatic
Start-Service -Name WSearch
```

แล้วรอ indexing ทำงาน (อาจใช้เวลาหลายชั่วโมงในเครื่องที่มีไฟล์เยอะ)

### ปิด SysMain แล้วเครื่องบูตช้าลง

```powershell
Set-Service -Name SysMain -StartupType Automatic
Start-Service -Name SysMain
```

## ปัญหาฮาร์ดแวร์/ประสิทธิภาพ

### เครื่องร้อนจัด (95 °C+) ตอนเล่นเกม

1. ตรวจด้วย `.\Level51Tune.ps1 status` และ HWiNFO
2. ทำความสะอาดพัดลม/ฮีตซิงก์
3. เปลี่ยน thermal paste (ถ้าเครื่องอายุ 3+ ปี)
4. undervolt CPU (-100 mV) และ GPU
5. จำกัด fps ในเกมเป็น 60
6. ถ้าใช้โปรไฟล์ max → เปลี่ยนเป็น gaming

### เกมกระตุกเป็นช่วง ๆ (stutter) แต่ avg fps ดี

ตรวจ 1% low ด้วย CapFrameX/PresentMon แล้วดู:

| อาการ | สาเหตุ |
|---|---|
| กระตุกทุก ~2 วินาที | P-State แกว่ง / power limit |
| กระตุกเมื่อโหลด texture ใหม่ | RAM/VRAM ไม่พอ หรือดิสก์ช้า |
| กระตุกเมื่อมีเสียง | DPC latency ของไดรเวอร์เสียง (ดู LatencyMon) |
| กระตุกตอนศัตรูโผล่ | CPU limit (ตรวจ utilization ต่อคอร์) |

### `nvidia-smi` ขึ้น "has failed because it couldn't communicate with the NVIDIA driver"

1. Device Manager → Display adapters → มี GTX 1060 และไม่มีเครื่องหมายเตือนไหม
2. ถ้ามีเตือน → DDU + ติดตั้งไดรเวอร์ใหม่
3. ถ้าไม่มี GTX 1060 เลย → ตรวจใน BIOS ว่า dGPU ถูกปิดไหม

### ใช้ GTX 1060 ไม่ได้ เกมวิ่งช้า

```powershell
# ตรวจว่าตั้ง per-app preference ไว้หรือยัง
Get-ItemProperty 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'
```

ตั้งเพิ่มสำหรับเกมนั้น:

```powershell
$k = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'
Set-ItemProperty -Path $k -Name 'C:\Games\Game\game.exe' -Value 'GpuPreference=2;' -Type String
```

หรือ Settings → Display → Graphics → เพิ่มแอป → High performance

### SSD ช้ากว่าสเปกมาก

- ตรวจว่า SSD อยู่ในสล็อต PCIe 3.0 x4 (แพลตฟอร์มนี้ไม่รองรับ 4.0)
- ตรวจ TRIM: `fsutil behavior query DisableDeleteNotify` (ต้องเป็น 0)
- ตรวจพื้นที่ว่าง > 20%
- ตรวจอุณหภูมิ: `Get-StorageReliabilityCounter`
- ตรวจว่าไม่ได้ใช้ SATA M.2 แทน NVMe

### Wi-Fi ping แกว่ง

- ใช้ 5 GHz
- ปิด "Allow the computer to turn off this device to save power" ใน Device Manager
- อัปเดตไดรเวอร์ Intel 9260
- ตรวจ interference ด้วย `netsh wlan show interfaces`

## คำถามที่พบบ่อย

### โปรแกรมนี้ปลอดภัยไหม

มันแก้เฉพาะค่าที่ Windows เปิดให้แก้ผ่าน API (powercfg, registry, service) และ backup ก่อนทุกครั้ง ไม่แตะ BIOS, ไม่ติดตั้งไดรเวอร์, ไม่ปิด Windows Update/Defender และไม่ดาวน์โหลดอะไรจากอินเทอร์เน็ต

### ใช้กับเครื่องอื่นได้ไหม

ได้ แต่:

- ชื่อโปรไฟล์และคำอธิบายเขียนขึ้นสำหรับเครื่องนี้
- tweaks บางตัว (เช่น `gpu.prefer-dgpu-global`) ไม่มีความหมายบนเครื่องที่ไม่มี Optimus
- `win.unhide-power-settings` และ tweaks แบบ power ทำงานได้ทุกเครื่อง Windows
- โปรไฟล์ `max` บนเครื่องที่ระบายความร้อนไม่ดีอาจเป็นอันตราย

### ต้อง admin ตลอดไหม

ไม่ — `status`, `audit`, `bench`, `list`, `profiles`, `report`, `docs`, `gpu` ทำงานได้โดยไม่ต้อง admin

### apply ซ้ำได้ไหม

ได้ และปลอดภัย แต่ควรรู้ว่า:

- ถ้า apply โปรไฟล์เดิมซ้ำ โปรแกรมจะใช้ scheme ที่มีอยู่ (ไม่สร้างใหม่)
- ถ้า apply โปรไฟล์อื่น จะสร้าง scheme ใหม่จาก scheme ปัจจุบัน (ซึ่งเป็น tune scheme เดิม) แล้วลบ scheme เก่า
- backup ใหม่จะถูกสร้างทุกครั้ง

ถ้าอยากกลับไปจุดเริ่มต้นจริง ๆ ให้ `restore` ไฟล์ backup แรกสุด

### ทำไมตัวเลข bench ไม่ต่างกันเลย

เพราะโปรไฟล์ส่วนใหญ่ปรับ **latency/jitter** ไม่ใช่ throughput ดิบ `bench` วัด throughput ซึ่งได้ผลเฉพาะกับ:

- การปลดล็อก power limit (ซึ่งเครื่องนี้ทำไม่ได้)
- การปิด core parking ในงาน multi-thread (เล็กน้อย)
- การลด IO พื้นหลัง (เห็นชัดตอนวัดพร้อมกับรันอย่างอื่น)

ถ้าอยากเห็นผลของ latency ให้ใช้ LatencyMon (DPC) หรือ frametime graph ในเกม

### ลบโปรแกรมนี้ต้องทำอะไร

1. `.\Level51Tune.ps1 restore` (ย้อนค่าทั้งหมด)
2. ลบโฟลเดอร์โปรเจกต์
3. ไม่มีอะไรค้างในระบบ (ไม่มี service, ไม่มี scheduled task, ไม่มี driver)

### ทำไมต้องสร้าง power scheme ใหม่แทนที่จะแก้ของเดิม

เพราะการแก้ scheme เดิมจะทำให้คุณไม่สามารถเปรียบเทียบ "ก่อน/หลัง" ได้ และถ้าอยากกลับต้องจำค่าดิบทั้งหมด การแยก scheme ทำให้สลับไปมาใน Control Panel ได้ทันที

### `-Include high` ทำอะไร

อนุญาตให้รวม tweaks ความเสี่ยงสูง 4 รายการ (ปิด C-state, ปิด GPU dynamic P-State, disabledynamictick, useplatformclock) ซึ่งปกติถูกข้าม เพราะอาจทำให้เครื่องร้อนมากหรือไม่เสถียร

### ใช้ร่วมกับ ThrottleStop / XTU / MSI Afterburner ได้ไหม

ได้ แต่ระวังการเขียนทับกัน:

- ThrottleStop ตั้ง power limit และ undervolt → ไม่ชนกับ powercfg แต่จะ overwrite ค่า power limit ที่คุณตั้ง
- XTU ตั้งค่า clock/voltage → คนละชั้น ไม่ชน
- Afterburner ตั้ง GPU clock/voltage → ไม่ชนกับ tweaks ของโปรแกรมนี้

**ข้อแนะนำ**: ใช้ Level51Tune จัดการ power scheme/registry/service และใช้ ThrottleStop/Afterburner สำหรับ voltage/clock

### ทำไม `restore` ไม่คืนค่า fsutil/netsh/bcdedit

เพราะ tweaks เหล่านั้นให้ผลลัพธ์เป็นข้อความ ไม่ใช่ค่าที่อ่านกลับมาเปรียบเทียบได้ การเดาค่าเดิมแล้วเขียนทับมีความเสี่ยงมากกว่าการบอกผู้ใช้ให้คืนเอง — เอกสาร [ความปลอดภัย การสำรอง และการย้อนกลับ](12-ความปลอดภัย-ย้อนกลับ.md) มีคำสั่งครบทุกตัว

### ตรวจสอบว่าเครื่องใช้ Modern Standby หรือ S3

```powershell
powercfg /a
```

ถ้าเห็น "Standby (S0 Low Power Idle)" = Modern Standby (กินไฟในกระเป๋า) ถ้าเป็น S3 = sleep แบบเดิม

### จะรู้ได้อย่างไรว่าไฟล์ docs เป็นเวอร์ชันล่าสุด

```powershell
.\Level51Tune.ps1 docs
```

สร้าง HTML ใหม่จาก md ทุกครั้ง (md คือต้นฉบับ ไม่ใช่ HTML)
