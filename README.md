# LEVEL51-TUNE

ชุดเครื่องมือบรรทัดคำสั่ง (PowerShell) สำหรับ**ปรับแต่งประสิทธิภาพเชิงลึก**ของเครื่อง LEVEL51 — โน้ตบุ๊ก Clevo N95TP6 ที่ใส่ Intel Core i9-9900K, NVIDIA GTX 1060 6 GB, แรม 32 GB และ SSD NVMe 1 TB ภายใต้ Windows 11 Pro

ออกแบบบนหลักการ: **วัดก่อน–วัดหลัง, สำรองก่อนทุกครั้ง, ย้อนกลับได้ด้วยคำสั่งเดียว, ไม่แตะ power plan เดิมของคุณ**

> ดาวน์โหลดไฟล์สำเร็จรูปได้ที่ [Releases](https://github.com/NarDecH/LEVEL51-TUNE/releases) (`LEVEL51-TUNE-<version>.zip` — แตกแล้วดับเบิลคลิก `Start-LEVEL51.cmd`)

## ทำอะไรได้บ้าง

| หมวด | สิ่งที่ปรับ |
|---|---|
| **CPU / Power** | processor min/max state, Turbo boost mode, EPP (Speed Shift), core parking, cooling policy, C-state, PCIe ASPM, disk/USB/display timeouts |
| **GPU** | Hardware-Accelerated GPU Scheduling, GameDVR, fullscreen optimization, per-app GPU preference (Optimus), NVIDIA telemetry, dynamic P-State |
| **RAM** | Win32PrioritySeparation, LargeSystemCache, NTFS memory usage, SysMain, Prefetcher |
| **Storage** | NTFS last-access, TRIM/8.3, defrag schedule, Windows Search indexing |
| **Network** | NetworkThrottlingIndex, MMCSS Games priority, Nagle/delayed-ACK, TCP global tuning |
| **Windows** | Game Mode, mouse acceleration, keyboard delay, visual effects, background apps, telemetry services, boot configuration |

รวม **60 tweaks** ใน 5 โปรไฟล์ (`balanced`, `performance`, `gaming`, `max`, `battery`) พร้อมระบบสำรอง/ย้อนกลับอัตโนมัติ — ใช้ได้ทั้งจาก **CLI** และ **Web GUI** ในเบราว์เซอร์

## เริ่มใช้งาน 60 วินาที

```powershell
git clone https://github.com/NarDecH/LEVEL51-TUNE.git
cd LEVEL51-TUNE

# 1) ดูสถานะ + คำแนะนำสำหรับเครื่องนี้ (ไม่ต้อง admin)
.\Level51Tune.ps1 status
.\Level51Tune.ps1 recommend

# 2) วัดผลก่อน
.\Level51Tune.ps1 bench -Label before

# 3) ทดลองก่อน ไม่แก้อะไร
.\Level51Tune.ps1 apply -Profile gaming -DryRun

# 4) apply จริง
.\Level51Tune.ps1 apply -Profile gaming -Elevate

# 5) วัดผลหลัง + เทียบ
.\Level51Tune.ps1 bench -Label after
.\Level51Tune.ps1 compare

# ถ้าไม่ชอบอะไร
.\Level51Tune.ps1 restore
```

## Web GUI (ใช้ผ่านเบราว์เซอร์)

ดับเบิลคลิก **`Start-LEVEL51.cmd`** — ขอ UAC เองแล้วเปิด dashboard ให้ (หรือรันเองด้วย `Level51Tune.Web.ps1`)

```powershell
.\Start-LEVEL51.cmd              # 1 คลิก: UAC → http://localhost:8730/
.\Level51Tune.Web.ps1            # เปิดแบบไม่ elevate
.\Level51Tune.Web.ps1 -Port 8899 -NoBrowser
```

dashboard มี 5 แท็บ: **ภาพรวม** (ฮาร์ดแวร์, 5 โปรไฟล์, audit/bench/latency/restore, log), **ตั้งค่า tweak** (เลือกทีละตัว/ตามโปรไฟล์, ตรวจสถานะที่เลือก, บันทึกแล้ว `apply -Custom` ได้), **กราฟสด** (CPU/GPU/RAM อัปเดตทุก 2 วินาที), **ประวัติ/ย้อนกลับ** (restore backup ทีละครั้ง) และ **GPU ต่อแอป** (dgpu/igpu/auto ต่อ .exe) — ไม่ต้องติดตั้งอะไรเพิ่ม ไม่มี node_modules ฟังเฉพาะ loopback และบังคับ token ทุก request

ปุ่ม Apply/Restore ต้องเปิดโปรแกรมแบบ Administrator (ไม่งั้นได้ 403 พร้อมคำอธิบาย) — ดูการวิเคราะห์/roadmap ที่ [docs/15](docs/15-GUI-และ-roadmap.md)

## Tray และการแจกจ่าย

```powershell
.\Level51Tune.Tray.ps1            # ไอคอนใน system tray: สลับโปรไฟล์ / ตรวจสถานะ / เปิด Dashboard
.\tools\Build-Package.ps1        # สร้าง dist/LEVEL51-TUNE-<version>.zip สำหรับแจกจ่าย
.\tools\Build-Package.ps1 -CertificateThumbprint <thumb>   # ลงนามทุก .ps1 ด้วย Authenticode
.\tools\Build-Msix.ps1           # สร้าง dist/LEVEL51-TUNE-<version>.msix (ต้องมี Windows SDK)
.\Level51Tune.ps1 update         # ตรวจเวอร์ชันใหม่บน GitHub (คำสั่งเดียวที่ใช้เน็ต)
```

ใน tray: คลิกขวาเพื่อสลับโปรไฟล์ (ขอ UAC เองทุกครั้ง), ตรวจสถานะเป็น balloon, เปิดโฟลเดอร์ log/เอกสาร — ไม่รันค้างแบบ Administrator

MSIX (`Build-Msix.ps1`) ห่อแอปเป็นแพ็กเกจติดตั้งได้ โดยมี launcher เล็ก ๆ ที่เปิด dashboard — แต่ MSIX รันใน container จึงขอ UAC ไม่ได้ ปุ่ม Apply/Restore ในโหมดนั้นจะได้ 403 (ใช้ `Start-LEVEL51.cmd` เมื่อต้อง apply)

## โปรไฟล์

| โปรไฟล์ | เหมาะกับ | แลกกับ |
|---|---|---|
| `balanced` | ใช้งานทั่วไป | แทบไม่มี |
| `performance` | งานประจำวัน, เรนเดอร์สั้น | กินไฟขึ้นเล็กน้อย |
| `gaming` | เกม, latency ต่ำ | ความร้อน, ปิดฟีเจอร์ Windows บางอย่าง |
| `max` | benchmark, burst สั้น ๆ | ร้อนมาก — ไม่ควรใช้ค้าง |
| `battery` | ใช้แบต | ประสิทธิภาพลดลง |

## ความปลอดภัย

- ทุก `apply` สร้าง backup JSON ที่บรรจุค่าก่อนหน้าทุกตัว ไว้ใน `backups/`
- `restore` คืนค่า power/registry/services ได้ 100% และลบ power scheme ที่สร้าง
- โปรไฟล์ `max` มี tweaks ความเสี่ยงสูง 4 รายการที่ต้องเปิดด้วย `-Include high` เอง
- ไม่แตะ BIOS, ไม่ติดตั้งไดรเวอร์, ไม่ปิด Windows Update/Defender, ไม่ดาวน์โหลดอะไรจากอินเทอร์เน็ต

## เอกสาร

เอกสารภาษาไทยฉบับเต็ม 15 บท อยู่ใน [`docs/`](docs/index.html) — เปิดด้วย

```powershell
.\Level51Tune.ps1 docs -Open
```

| บท | เนื้อหา |
|---|---|
| [01](docs/01-ภาพรวม.md) | ภาพรวมและปรัชญาการจูน |
| [02](docs/02-เริ่มต้นใช้งาน.md) | ติดตั้งและเริ่มต้นใช้งาน |
| [03](docs/03-คำสั่ง-CLI.md) | คู่มือคำสั่ง CLI |
| [04](docs/04-โปรไฟล์.md) | โปรไฟล์และสิ่งที่แต่ละโปรไฟล์เปลี่ยน |
| [05](docs/05-CPU.md) | จูน CPU เชิงลึก |
| [06](docs/06-GPU.md) | จูน GPU (Optimus) |
| [07](docs/07-POWER.md) | พลังงาน แบต และความร้อน |
| [08](docs/08-RAM-STORAGE.md) | RAM และ Storage |
| [09](docs/09-NETWORK.md) | เครือข่ายและ latency |
| [10](docs/10-WINDOWS-และ-SERVICES.md) | Windows, services, debloat |
| [11](docs/11-เชิงลึก-BIOS-และฮาร์ดแวร์.md) | BIOS, ฮาร์ดแวร์, การวัดผล |
| [12](docs/12-ความปลอดภัย-ย้อนกลับ.md) | ความปลอดภัยและการย้อนกลับ |
| [13](docs/13-ผลตรวจเครื่องนี้.md) | ผลตรวจเครื่อง LEVEL51 (ค่าจริง) |
| [14](docs/14-แก้ปัญหา-FAQ.md) | แก้ปัญหาและ FAQ |
| [15](docs/15-GUI-และ-roadmap.md) | GUI ที่ทำจริง, tray, roadmap |

## โครงสร้างโปรเจกต์

```
Level51Tune.ps1              CLI entry point
Level51Tune.Web.ps1          Web GUI server (HttpListener + token, loopback only)
Start-LEVEL51.cmd            ตัวเรียก 1 คลิก (ขอ UAC แล้วเปิด GUI)
Level51Tune.Tray.ps1         tray icon (สลับโปรไฟล์/ตรวจสถานะ/เปิด Dashboard)
src/Level51Tune.psm1         engine (detect, backup, apply, restore, audit, status, docs)
src/Catalog.ps1              นิยาม tweaks 60 รายการ (declarative)
src/Markdown.ps1             markdown → HTML renderer
src/Bench.ps1                micro-benchmark + history + compare + latency
src/WebUI.ps1                HTML dashboard แบบ single-page (ไม่มี asset ภายนอก)
docs/                        เอกสาร .md (ต้นฉบับ) และ .html (สร้างอัตโนมัติ)
tools/Build-Docs.ps1         สร้าง docs/*.html
tools/AB-Bench.ps1           วัด A/B throughput ระหว่างสอง power scheme (A-B-B-A)
tools/AB-Latency.ps1         วัด A/B DPC/interrupt (ต้อง admin)
tools/Build-Package.ps1      สร้าง zip แจกจ่าย (dist/)
tools/Build-Msix.ps1         สร้าง MSIX (launcher .exe + manifest) สำหรับติดตั้งเป็นแอป
tests/Test-Level51Tune.ps1   ชุดทดสอบ (ไม่ต้อง admin, ไม่แก้ระบบ)
```

## ทดสอบ

```powershell
.\tests\Test-Level51Tune.ps1
```

ตรวจ schema ของแค็ตตาล็อก, markdown renderer, docs build, dashboard HTML, latency counter และ dry-run apply ทุกโปรไฟล์ (ไม่ต้องใช้สิทธิ์ admin และไม่เปลี่ยนแปลงระบบ)

## ความต้องการของระบบ

- Windows 10 21H2+ หรือ Windows 11
- PowerShell 5.1 (built-in) หรือ PowerShell 7+
- Administrator สำหรับ `apply` / `restore` / `backup`
- ไม่ต้องติดตั้งโมดูลเพิ่มเติม

## ข้อจำกัดที่ควรรู้

- เครื่องมือนี้ปรับ **ซอฟต์แวร์** เท่านั้น — ไม่ undervolt/overclock และไม่แฟลช BIOS
- บน N95TP6 ความร้อนเป็นคอขวดจริง การตั้งค่าที่ดีที่สุดคือ `performance`/`gaming` ไม่ใช่ `max`
- micro-benchmark มี noise ±3-5% — ตัวเลขที่ต่างน้อยกว่านั้นไม่มีความหมาย
- tweaks ประเภท Script (fsutil/netsh/bcdedit) ต้องคืนค่าด้วยมือ (มีคำสั่งใน docs/12)

## License

MIT © 2026 NarDecH
