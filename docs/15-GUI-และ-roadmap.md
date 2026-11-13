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
| `/api/tweaks` | GET | tweak ทั้ง 60 รายการ + รายการที่บันทึกไว้ | ไม่ |
| `/api/settings` | GET/POST | อ่าน/บันทึก tweak ที่เลือกเอง (`state/custom.json`) | ไม่ |
| `/api/live` | GET | ค่าสด: CPU load/clock, RAM, GPU clock/temp/power | ไม่ |
| `/api/compare` | POST | วัด benchmark ใหม่ + เทียบกับครั้งก่อน | ไม่ |
| `/api/open-dashboard` | POST + `X-L51-Open: 1` | คืน URL พร้อม token ของ session (ไม่ต้องมี token, ห้ามมี `Origin`) | ไม่ |
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
| 1 | ~~ตัวเรียก 1 คลิก~~ **เสร็จแล้ว**: `Start-LEVEL51.cmd` ขอ UAC เองแล้วเปิด GUI | ผู้ใช้ไม่ต้องพิมพ์ PowerShell | เสร็จ |
| 2 | ~~tray icon~~ **เสร็จแล้ว**: `Level51Tune.Tray.ps1` (WinForms NotifyIcon, เมนูสลับโปรไฟล์ + balloon สถานะ) | สลับ performance/gaming ได้จาก tray | เสร็จ |
| 3 | ~~หน้าตั้งค่าละเอียด~~ **เสร็จแล้ว**: tab “ตั้งค่า tweak” (ค้นหา/กรอง/เลือกตามโปรไฟล์/บันทึก) | ไม่ต้องจำโปรไฟล์ | เสร็จ |
| 4 | ~~กราฟ realtime~~ **เสร็จแล้ว**: tab “กราฟสด” 6 กราฟ + ปุ่ม “วัด + เทียบกับครั้งก่อน” | เห็นผลทันที ไม่ต้องเปิด HWiNFO | เสร็จ |
| 5 | ~~per-app GPU preference~~ **เสร็จแล้ว**: แท็บ “GPU ต่อแอป” + CLI `gpuprefs` | แก้ปัญหา Optimus ได้ในคลิกเดียว | เสร็จ |
| 6 | ~~ประวัติ + rollback~~ **เสร็จแล้ว**: แท็บ “ประวัติ/ย้อนกลับ” + CLI `history` | ปลอดภัยขึ้นมาก | เสร็จ |
| 7 | ~~แพ็กเกจ~~ **เสร็จบางส่วน**: `tools/Build-Package.ps1` สร้าง zip แจกจ่าย (ยังไม่ sign/MSIX) | แจกจ่ายง่าย | เหลือ certificate |
| 8 | ~~แจ้งเตือนเมื่อต้อง restart~~ **เสร็จแล้ว**: `RestartRequired`/`RebootTweaks` จาก `Invoke-L51Apply` + `RebootPending` ใน state + แบนเนอร์ GUI + balloon/tooltip ของ tray + กรอบเตือนใน CLI | ผู้ใช้ไม่พลาดว่าค่ายังไม่เต็มที่ | เสร็จ |

## Roadmap ที่แนะนำ

### ระยะ 1 (เสร็จแล้วในรอบนี้)

- engine + CLI + 60 tweaks + backup/restore + bench + latency
- Web GUI: สถานะ, โปรไฟล์, dry-run, apply, audit, bench, latency, restore, log, ลิงก์เอกสาร
- เอกสารไทย 15 บท + test 23 เคส

### ระยะ 2 (เสร็จแล้ว)

1. `Start-LEVEL51.cmd` — ดับเบิลคลิกเดียว ขอ UAC แล้วเปิด dashboard (ปิดช่องว่าง "ต้องพิมพ์ command")
2. หน้า Settings ราย tweak — ค้นหา/กรองหมวด/เลือกตามโปรไฟล์/บันทึกเป็น `state/custom.json` แล้ว apply ได้ทั้ง GUI และ CLI (`apply -Custom`)
3. กราฟ realtime 6 ตัว — CPU load, CPU clock, GPU temp, GPU power, RAM used, GPU clock (อัปเดตทุก 2 วินาที, เก็บ 60 จุด)
4. ปุ่ม "วัด + เทียบกับครั้งก่อน" — รัน `bench` แล้วแสดง delta เทียบผลครั้งก่อนในคลิกเดียว

### ระยะ 3

### ระยะ 3 (เสร็จแล้ว)

5. Tray app — `Level51Tune.Tray.ps1` (WinForms NotifyIcon): เปิด Dashboard, สลับโปรไฟล์, ตรวจสถานะเป็น balloon, เปิด log/docs, ออก
6. per-app GPU editor — แท็บ “GPU ต่อแอป” + CLI `gpuprefs` (เขียน `HKCU\...\UserGpuPreferences`)
7. ประวัติ + rollback ทีละครั้ง — แท็บ “ประวัติ/ย้อนกลับ” อ่าน `backups/` และ restore ไฟล์ที่เลือก + CLI `history`
8. audit ราย tweak ในหน้า Settings — ปุ่ม “ตรวจสถานะที่เลือก” ใช้ `Invoke-L51Audit -TweakIds`

### ระยะ 4

### ระยะ 4 (บางส่วน)

9. `tools/Build-Package.ps1` — สร้าง `dist/LEVEL51-TUNE-<version>.zip` พร้อมใช้ (เสร็จแล้ว)
10. ~~หน้าตรวจอัปเดตเวอร์ชัน~~ **เสร็จแล้ว**: CLI `update` + ปุ่ม “ตรวจอัปเดต” ใน GUI (อ่านเฉพาะ metadata ของ release/tag — repo มี release `v1.0.7` พร้อมไฟล์ zip/msix แนบให้เทียบแล้ว)
11. ~~profile detection~~ **เสร็จแล้ว**: `recommend` + การ์ด “คำแนะนำสำหรับเครื่องนี้” (เลือกโปรไฟล์ตาม RAM channel / CPU class / dGPU)
12. ~~code signing~~ **ทำไปป์ไลน์แล้ว**: `Build-Package.ps1 -CertificateThumbprint <thumb>` ลงนามทุก .ps1/.psm1 ด้วย Authenticode — เหลือแค่ certificate ของผู้พัฒนา
13. ~~MSIX~~ **เสร็จแล้ว**: `tools/Build-Msix.ps1` คอมไพล์ launcher (C# ผ่าน `csc.exe`) + `AppxManifest.xml` + assets แล้ว pack ด้วย `makeappx.exe` → `dist/LEVEL51-TUNE-<version>.msix`
14. MSIX — ผลตรวจครบวงจรบนเครื่องนี้: `Build-Msix.ps1 -Unsigned` → `Add-AppxPackage -AllowUnsigned` (Administrator) ได้ `Status: Ok` → เปิดจาก Start ด้วย AUMID `NarDecH.LEVEL51TUNE_f8fxc7vhmgvhy!App` แล้วเซิร์ฟเวอร์รันจาก `C:\Program Files\WindowsApps\...\Level51Tune.Web.ps1` และ dashboard ตอบ 401 เมื่อไม่มี token → ถอนด้วย `Remove-AppxPackage` เรียบร้อย
15. เงื่อนไขการติดตั้ง MSIX ที่ต้องรู้: แพ็กเกจ unsigned ต้องมี marker `OID.2.25.311729368913984317654407730594956997722=1` ต่อท้าย Publisher (สคริปต์ใส่ให้เมื่อใช้ `-Unsigned`) · ต้องเปิด Developer Mode · และเพราะมี `.exe` ต้องติดตั้งด้วย PowerShell แบบ Administrator
16. ข้อจำกัดที่คงอยู่ของ MSIX: รันใน container จึงขอ UAC ไม่ได้ (launcher เปิด dashboard แบบไม่ elevated; apply/restore ต้องใช้ `Start-LEVEL51.cmd`)
17. MSIX — การลงนาม: `Build-Msix.ps1 -PfxPath <file.pfx> -PfxPassword <...>` เรียก `signtool sign /fd SHA256` · ถ้าเพิ่ม `-TimestampServer <url>` จะต่อเน็ตเพื่อประทับเวลา (opt-in เท่านั้น — invariant 13) · ทดสอบบนเครื่องนี้ด้วย self-signed cert `CN=LEVEL51-TUNE` แล้วติดตั้งสำเร็จ — แต่สำหรับแจกจ่ายจริงยังต้องใช้ cert จาก CA ที่เชื่อถือได้
19. ~~แจ้งเตือนเมื่อต้อง restart~~ **เสร็จแล้ว**: engine คืน `RestartRequired` + `RebootTweaks`, เขียน `RebootPending` ลง `state/last.json` ทุก apply ที่สำเร็จ, GUI ขึ้นแบบเนอร์, tray ขึ้น balloon + tooltip “ต้องรีสตาร์ทเครื่อง”, CLI พิมพ์กรอบเตือน (8 รายการแรก + จำนวนที่เหลือ) และ `status` ก็แสดง
20. ~~เคลียร์ alert อัตโนมัติหลัง reboot~~ **เสร็จแล้ว**: `Get-L51RestartInfo` ใช้ `Test-L51RebootSinceApplied` เทียบ `LastBootUpTime` กับ `AppliedAt` — ถ้า reboot ไปแล้วจะเคลียร์ flag และเขียน state ใหม่ (ทดสอบด้วยการจำลองเวลา boot แล้ว ไม่ต้องรีบูตจริง)
21. ~~บันทึก state ทุก apply~~ **แก้บั๊กแล้ว**: เดิมการ save ถูกผูกกับ `$hasPower` ทำให้โปรไฟล์ที่ registry ล้วน (เช่น `balanced`) ไม่เขียน state → สถานะ/แบนเนอร์ล้าสมัย ตอนนี้ใช้ `New-L51ApplyState` และบันทึกทุกครั้งที่ apply สำเร็จ
22. ทดสอบเมนู tray แบบไม่ต้องกด UAC: `.\Level51Tune.Tray.ps1 -SelfTest [-Port 8899]` แสดง tooltip จริง, ผลตรวจพอร์ต, ผลเรียก `/api/open-dashboard`, และคำสั่งที่จะเปิด Dashboard
23. ~~เปิด Dashboard จาก tray แล้วได้หน้าเว็บจริง~~ **เสร็จแล้ว**: `Start-L51Dashboard` ขอ URL จาก `POST /api/open-dashboard` แล้ว tray เป็นคนเรียก `Start-Process <url>` เอง (tray ไม่ได้ elevated → ได้เบราว์เซอร์ของผู้ใช้ปกติ) ถ้ายังไม่มีเซิร์ฟเวอร์จะเปิดตัวใหม่แบบ Administrator พร้อม `-NoBrowser` แล้วรอ URL สูงสุด 60 วินาที — token ไม่ถูกเขียนลงดิสก์ และห้ามใช้ `explorer.exe` เปิด URL เพราะมันตีความเป็นพาธแล้วเปิด File Explorer
18. ทางเลือกที่ไม่ต้องซื้อ cert: (ก) `tools/New-SigningCert.ps1` สร้าง self-signed cert + PFX/CER ให้ฟรี แล้วเครื่องปลายทางนำ `.cer` เข้า `TrustedPeople` ก่อนติดตั้งแอป (เหมาะกับแจกให้ตัวเอง/ทีม; Windows ไม่ได้เชื่อถือโดยปริยายและไม่ช่วยเรื่อง SmartScreen) · (ข) โปรเจกต์นี้ใช้ MIT license จึงยื่นขอ **SignPath Foundation** (ฟรีสำหรับ OSS, cert ออกในนามมูลนิธิ, เซ็นผ่าน pipeline ของเขา) ได้ที่ signpath.org — ต้องรออนุมัติ

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
