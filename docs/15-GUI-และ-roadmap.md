# GUI และ roadmap: ทำให้ใช้ง่ายขึ้นได้แค่ไหน

## คำตอบสั้น

**ได้ และทำเสร็จแล้วในรอบนี้** — โปรเจกต์มี Web GUI ที่ทำงานจริงอยู่ที่ `Level51Tune.Web.ps1` (dashboard บน `http://localhost:8730/`) ซึ่งเรียก engine ตัวเดียวกับ CLI ทุกฟังก์ชัน: ดูสถานะ, audit, apply, dry-run, bench, latency, restore และ log

เหตุผลที่เลือก Web GUI เป็น GUI ตัวแรก ไม่ใช่ WPF/WinForms:

| เหตุผล | รายละเอียด |
|---|---|
| ไม่ต้องติดตั้งอะไร | ใช้ `System.Net.HttpListener` ที่มีใน .NET/Windows อยู่แล้ว ไม่มี node_modules, ไม่มี Electron 200 MB |
| หน้าตาควบคุมได้เต็มที่ | HTML/CSS ทำ responsive, dark theme, ฟอนต์ไทย ได้ในไฟล์เดียว |
| ทดสอบได้จริง | เปิดในเบราว์เซอร์ ตรวจ DOM/network/console ได้ (WPF ตรวจยากกว่าและต้องมีจอ) |
| ใช้จากมือถือใน LAN ได้ถ้าต้องการ | เปลี่ยน bind address ได้ในอนาคต (ปัจจุบันล็อก loopback เพื่อความปลอดภัย) |
| ต่อยอดเป็น desktop app ได้ | ถ้าอยากได้ tray icon + auto-elevate ให้ห่อด้วย WPF ทีหลัง โดยไม่ต้องเขียน UI ใหม่ |

## สถาปัตยกรรมที่ใช้ (และการแยกชั้น)

```
Level51Tune.psm1  ← engine (detect / backup / apply / restore / audit / bench / latency)
   ├── Level51Tune.ps1        CLI  (thin adapter: parse args → เรียก engine)
   ├── Level51Tune.Web.ps1    GUI  (thin adapter: HTTP → เรียก engine)
   │      └── src/WebUI.ps1   HTML dashboard (string เดียว, ไม่มี asset ภายนอก)
   └── tools/*.ps1            benchmark / A-B tester
```

หลักสำคัญ: **GUI ไม่มี logic ของตัวเอง** ทุกอย่างเรียกฟังก์ชันเดียวกับ CLI (`Invoke-L51Apply`, `Invoke-L51Restore`, `Invoke-L51Audit`, `Invoke-L51Bench`, `Measure-L51Latency`) ทำให้:

- ไม่มีโอกาสที่ CLI กับ GUI ให้ผลไม่ตรงกัน
- การเพิ่ม tweak ใหม่ปรากฏใน GUI ทันทีโดยไม่ต้องแก้ UI
- test ที่มีอยู่ (23 เคส) ครอบคลุมทั้งสองทาง

## API ของ GUI

| Endpoint | Method | ทำอะไร | ต้อง admin |
|---|---|---|---|
| `/api/status` | GET | ฮาร์ดแวร์, scheme, โปรไฟล์, สถานะล่าสุด | ไม่ |
| `/api/audit` | POST `{profile}` | ตรวจว่าอะไรถูกปรับแล้ว | ไม่ |
| `/api/apply` | POST `{profile, dryRun, includeHigh}` | apply หรือ dry-run | ใช่ (ถ้าไม่ dry) |
| `/api/restore` | POST | ย้อนกลับจาก backup ล่าสุด | ใช่ |
| `/api/bench` | POST `{seconds, label}` | วัด CPU/RAM/Disk | ไม่ |
| `/api/latency` | POST `{seconds}` | วัด DPC/interrupt | ไม่ |
| `/api/log` | GET | log ล่าสุด (กรอง DEBUG ออก) | ไม่ |
| `/docs/*` | GET | เอกสาร HTML ใน `docs/` | ไม่ |

## ความปลอดภัยของ Web GUI

ออกแบบให้ปลอดภัยพอสำหรับเครื่องส่วนตัว และไม่เป็นช่องโหว่ใหม่:

| มาตรการ | รายละเอียด |
|---|---|
| bind เฉพาะ loopback | `http://localhost:8730/` เท่านั้น ไม่รับจากเครือข่าย |
| token สุ่มต่อ session | สร้างตอนเริ่ม ออกใน URL ที่พิมพ์ใน console; ทุก API ต้องมี `X-L51-Token` |
| ไม่มี CORS | ไม่มี header `Access-Control-Allow-Origin` → หน้าจากเว็บอื่นเรียก API ไม่ได้ |
| path traversal guard | `/docs/..` ถูก normalize และปฏิเสธ (ทดสอบแล้วได้ 404) |
| ไม่เก็บ credential | ไม่มี password/token ลงดิสก์ |
| admin เป็นของผู้ใช้ | ถ้าไม่ได้เปิดแบบ Administrator ปุ่ม apply จะได้ 403 พร้อมข้อความบอก |

**ข้อจำกัดที่ต้องรู้**: token อยู่ใน URL (history/log ของเบราว์เซอร์อาจเก็บไว้) และไม่มี TLS เพราะเป็น loopback — ห้ามเปลี่ยนให้ bind `0.0.0.0` โดยไม่มี auth ที่แข็งแรงกว่านี้

## ทางเลือกอื่นและเหตุผลที่ไม่เลือก (ตอนนี้)

| ทางเลือก | ข้อดี | ข้อเสีย | เหมาะเมื่อ |
|---|---|---|---|
| **WPF/WinForms ใน PowerShell** | native, มี tray icon, เปิดได้ทันทีไม่ต้องมีเบราว์เซอร์ | XAML ยาว, ฟอนต์ไทยต้องตั้งเอง, ทดสอบอัตโนมัติยาก, ต้องมีจอ | ต้องการ tray + auto-start + หน้าตาแบบแอปWindows |
| **Web GUI (ที่ทำแล้ว)** | ไม่มี dependency, ทดสอบได้, ปรับ UI เร็ว | ต้องเปิดเบราว์เซอร์, ไม่มี tray | ใช้เป็น GUI หลักระยะแรก |
| **Electron/Tauri** | UI สวย, ecosystem ใหญ่ | ต้องติดตั้ง build toolchain, ขนาดใหญ่, ซ้ำซ้อนกับ PowerShell engine | เมื่อมีทีม frontend และต้องการแจกจ่ายเป็นแอป |
| **.NET MAUI / WinUI 3** | native สมัยใหม่, cross-device | ต้องเขียน engine ใหม่เป็น C#, งานใหญ่ | เมื่อจะทำเป็นผลิตภัณฑ์จริงจัง |
| **PowerShell + Terminal GUI (Spectre.Console)** | เร็ว, สวยใน terminal | ไม่ใช่ GUI จริง, ใช้เมาส์จำกัด | ผู้ใช้สาย CLI |

## สิ่งที่ยังขาดถ้าจะเรียกว่า "GUI ใช้งานง่ายจริง"

| # | งาน | ผลลัพธ์ | แรงโดยประมาณ |
|---|---|---|---|
| 1 | ตัวเรียก 1 คลิก (`Start-LEVEL51.cmd` + shortcut) ที่ขอ UAC เองและเปิด GUI | ผู้ใช้ไม่ต้องพิมพ์ PowerShell | 30 นาที |
| 2 | tray icon + เมนูสลับโปรไฟล์ (WPF ห่อรอบ engine) | สลับ performance/gaming ได้จาก tray | 1-2 วัน |
| 3 | หน้าตั้งค่าละเอียด (toggle ราย tweak + คำอธิบายไทย) | ไม่ต้องจำโปรไฟล์ | 2-3 วัน |
| 4 | กราฟ realtime (clock/temp/power จาก nvidia-smi + performance counter) | เห็นผลทันที ไม่ต้องเปิด HWiNFO | 1-2 วัน |
| 5 | ตาราง per-app GPU preference (อ่าน/เขียน `UserGpuPreferences`) | แก้ปัญหา Optimus ได้ในคลิกเดียว | 1 วัน |
| 6 | ประวัติการเปลี่ยนแปลง + ปุ่ม rollback ทีละครั้ง | ปลอดภัยขึ้นมาก | 1 วัน |
| 7 | แพ็กเป็น .exe (ps2exe) หรือ MSIX พร้อม code signing | แจกจ่ายง่าย | 1 วัน + ค่า certificate |

## Roadmap ที่แนะนำ

### ระยะ 1 (เสร็จแล้วในรอบนี้)

- engine + CLI + 60 tweaks + backup/restore + bench + latency
- Web GUI: สถานะ, โปรไฟล์, dry-run, apply, audit, bench, latency, restore, log, ลิงก์เอกสาร
- เอกสารไทย 15 บท + test 23 เคส

### ระยะ 2 (คุ้มที่สุดเป็นอันดับต่อไป)

1. `Start-LEVEL51.cmd` ที่ auto-elevate แล้วเปิด GUI (ปิดช่องว่าง "ต้องพิมพ์ command" ทั้งหมด)
2. หน้า Settings ราย tweak (เปิด/ปิดทีละตัว, แสดง Risk + คำอธิบาย)
3. กราฟ realtime ของ CPU/GPU clock, temp, power
4. ปุ่ม "เปรียบเทียบก่อน/หลัง" ที่เรียก `bench` + `compare` ในคลิกเดียว

### ระยะ 3

5. Tray app (WPF) ห่อ GUI + สลับโปรไฟล์ + เตือนเมื่ออุณหภูมิสูงเกินไป
6. per-app GPU editor
7. ประวัติ + rollback ทีละครั้ง

### ระยะ 4

8. แพ็กเป็น executable เดียว, code signing, หน้าอัปเดตเวอร์ชัน
9. (ถ้าต้องการ) รองรับเครื่องอื่นที่ไม่ใช่ LEVEL51 ด้วย profile detection

## ข้อควรระวังในการทำ GUI ต่อ

1. **อย่าลอกจาก engine** — GUI ต้องเรียกฟังก์ชันใน `Level51Tune.psm1` เท่านั้น
2. **อย่าให้ UI ตัดสินใจเรื่องสิทธิ์** — ตรวจ admin ที่ engine เสมอ (`Assert-L51Admin`)
3. **ทุก action ที่แก้ระบบต้องมี confirm** — ตอนนี้ apply/restore มี `confirm()` แล้ว
4. **อย่าเก็บ state ใน UI** — อ่านจาก engine ทุกครั้ง (single source of truth)
5. **ทดสอบด้วย dry-run ก่อนเสมอ** เมื่อเพิ่ม endpoint ใหม่

## สรุป

- ทำ GUI ได้ และทำแล้ว: Web GUI ทำงานจริง ตรวจด้วยเบราว์เซอร์แล้ว (สถานะ, dry-run 17 OK/1 SKIP, log)
- จุดที่ควรลงทุนต่อไม่ใช่ "หน้าตา" แต่คือ **ทางเข้า** (one-click + UAC) และ **การเห็นผล** (กราฟ/ประวัติ) เพราะ engine ทำงานครบแล้ว
- ถ้าต้องการแอป Windows แท้ ๆ ให้ห่อ Web GUI ด้วย WPF + WebView2 หรือทำ tray shell — ไม่ต้องเขียน engine ใหม่
