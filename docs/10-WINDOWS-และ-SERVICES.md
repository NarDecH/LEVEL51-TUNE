# Windows, services และ debloat

## แนวคิด: debloat ≠ tuning

การปิดบริการและฟีเจอร์ "เพื่อให้เร็วขึ้น" เป็นคำแนะนำยอดนิยมที่มักให้ผลน้อยกว่าที่คิด และบางครั้งให้ผลตรงข้าม เอกสารนี้จึงแยกให้ชัดระหว่าง:

| ประเภท | ตัวอย่าง | ผลจริง |
|---|---|---|
| ลด overhead ที่วัดได้ | GameDVR, telemetry, background apps | 0.5-5% ในเกม/งานหนัก |
| ลด IO พื้นหลัง | Windows Search, defrag task, SysMain | รู้สึกได้ตอน idle/บูต |
| เปลี่ยนพฤติกรรม UI | visual effects, transparency | รู้สึกได้ แต่ไม่ใช่ performance |
| ความเชื่อที่ไม่มีหลักฐาน | ปิด Superfetch ทุกกรณี, ปิด pagefile, "Limit reservable bandwidth" | น้อยมากหรือไม่มีผล |

โปรไฟล์ `max` รวมของกลุ่มแรกและกลุ่มที่สองไว้ แต่ **ปิด Search และ SysMain เป็นการแลกที่คุณต้องเลือกเอง**

## Game Mode / Game Bar / GameDVR

| ฟีเจอร์ | ทำอะไร | คำแนะนำ |
|---|---|---|
| Game Mode | ให้ priority กับเกม, หยุด Windows Update บางงานระหว่างเล่น | เปิด (`win.gamemode-on`) |
| Game Bar (Win+G) | overlay, widget | เปิดไว้ได้ ไม่กิน resource เมื่อไม่เรียก |
| GameDVR background recording | อัดคลิปย้อนหลังตลอดเวลา | ปิด (`gpu.gamedvr-off`) — นี่คือของจริงที่กิน GPU encoder |
| Captures | อัดเมื่อสั่ง | เปิดได้ถ้าใช้ |

ตรวจสอบว่า GameDVR ปิดจริง:

```powershell
Get-ItemProperty 'HKCU:\System\GameConfigStore' -Name GameDVR_Enabled
Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' -Name AllowGameDVR
```

## Visual effects

`win.visualfx-performance` ตั้ง `VisualFXSetting=2` (Adjust for best performance) ซึ่งปิด:

- Animate windows when minimizing/maximizing
- Fade/Slide menus
- Show shadows under windows
- Smooth edges of screen fonts (ปิดอันนี้ทำให้ตัวอักษรดูแย่ลง — พิจารณา)
- Thumbnails แทน icons
- Peek, translucent selection rectangle

ผลต่อ fps: ~0-1% บน GPU แยก ผลต่อ **ความรู้สึกเร็ว** ของ UI: ชัดเจน แต่หลายคนไม่ชอบที่ไม่มี animation

ถ้าต้องการเลือกเอง: `SystemPropertiesPerformance.exe`

## MMCSS และการจัดลำดับความสำคัญ

ดูรายละเอียดใน [เครือข่ายและ latency](09-NETWORK.md#4-mmcss-multimedia-class-scheduler-service) — สรุปคือ tweak `net.mmcss-games` และ `net.mmcss-responsiveness` ปรับ priority ที่ Windows ใช้กับงาน multimedia/เกม

`mem.priority-separation` (Win32PrioritySeparation=38) ปรับ quantum ของ scheduler ให้ foreground ได้ 3 เท่า

## บริการ (services) ที่โปรแกรมแตะ

| บริการ | ชื่อ | โปรไฟล์ | ผลเมื่อปิด | คำแนะนำ |
|---|---|---|---|---|
| SysMain | `SysMain` | max | ไม่มี prefetch, ลด IO | ทดลองและวัดผล |
| Windows Search | `WSearch` | max | ค้นหาไฟล์ช้ามาก, Outlook search เสีย | ไม่แนะนำถ้าใช้ค้นหาไฟล์ |
| DiagTrack | `DiagTrack` | max | ไม่ส่ง telemetry | ปลอดภัย |
| dmwappushservice | `dmwappushservice` | max | ไม่มีผลข้างเคียงที่เห็นได้ | ปลอดภัย |
| MapsBroker | `MapsBroker` | max | แอป Maps โหลดแผนที่ไม่ได้ | ปลอดภัย |
| NVIDIA Telemetry | `NvTelemetryContainer` | gaming, max | ไม่มีผลกับการเล่นเกม | ปลอดภัย |

**บริการที่โปรแกรมไม่แตะโดยเจตนา**:

| บริการ | เหตุผล |
|---|---|
| Windows Update (wuauserv) | ความปลอดภัย — ไม่ใช่การจูน |
| Defender (WinDefend) | ความปลอดภัย |
| Audio (Audiosrv) | จำเป็น |
| Print Spooler | ปิดได้แต่บางโปรแกรม (PDF printer) จะเสีย — ให้ผู้ใช้เลือก |
| Xbox services | หลายเกม (รวม Game Pass) ต้องใช้ |
| Bluetooth | จำเป็นถ้าใช้หูฟัง/เมาส์ |

## Startup apps — ที่ได้ผลมากกว่าการปิด service

โปรแกรมที่รันตอน login กินทั้ง RAM และ CPU เป็นระยะ:

```powershell
Get-CimInstance Win32_StartupCommand | Select-Object Name, Command, Location, User
```

หรือดูผ่าน Task Manager → Startup apps (มีคอลัมน์ "Startup impact")

ปิดใน Task Manager หรือลบ shortcut ใน:

```
%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup
HKCU:\Software\Microsoft\Windows\CurrentVersion\Run
HKLM:\Software\Microsoft\Windows\CurrentVersion\Run
```

**ตัวอย่างที่มักปิดได้**: OneDrive (ถ้าไม่ใช้), Teams, Discord (ถ้าไม่ต้อง auto-start), GeForce Experience, các app ของ OEM

## Scheduled tasks ที่กิน IO

```powershell
Get-ScheduledTask | Where-Object State -eq 'Ready' |
  Get-ScheduledTaskInfo |
  Sort-Object LastRunTime -Descending |
  Select-Object -First 20 TaskName, LastRunTime, LastTaskResult
```

งานที่มักไม่มีประโยชน์ในเครื่องส่วนตัว: Customer Experience Improvement Program, Office telemetry, Adobe GC Invoker, Google Update (ถ้าไม่ใช้ Chrome)

## Windows Defender — exclusions ที่ปลอดภัย

การสแกนโฟลเดอร์ build ที่มีไฟล์หมื่นไฟล์ทำให้ช้าและกิน CPU:

```powershell
# ต้อง admin
Add-MpPreference -ExclusionPath 'C:\_Project'
Add-MpPreference -ExclusionPath "$env:USERPROFILE\.cargo"
Add-MpPreference -ExclusionProcess 'node.exe'
Get-MpPreference | Select-Object ExclusionPath, ExclusionProcess
```

⚠️ **อย่า** เพิ่ม exclusion ให้โฟลเดอร์ดาวน์โหลดหรือทั้งไดรฟ์ — นั่นคือการปิดการป้องกัน

## Power Throttling / Efficiency Mode

Windows 11 ติดป้ายโปรเซสพื้นหลังว่า "Efficiency mode" และจำกัด clock ให้

- ดูได้ใน Task Manager (แท็บ Processes, คอลัมน์ Status)
- tweak `power.throttling-off` ปิดกลไกนี้ (ต้อง reboot)
- ผล: งานพื้นหลังเร็วขึ้น แต่กินไฟและร้อนขึ้น

ถ้าเครื่องเย็นพอปิดได้ แต่ถ้าใช้ `max` + ปิด throttling + ปิด C-state พร้อมกัน จะร้อนมาก

## Notification / Focus / Widgets

ไม่ใช่ performance แต่เป็น "ความรู้สึกเร็ว" ของเครื่อง:

| ฟีเจอร์ | ผล |
|---|---|
| Widgets (Win+W) | โหลด process เพิ่ม ~40-80 MB |
| News and interests | รันเบื้องหลัง |
| Notification popups | ขัดจังหวะเกม (มีโหมด Game Mode ช่วย) |

ปิด Widgets: Taskbar settings → Widgets = Off

## Windows Update — อย่าปิด แต่จัดการเวลา

```powershell
# ตั้ง active hours เพื่อไม่ให้ reboot ระหว่างเล่นเกม
Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'
```

Settings → Windows Update → Advanced options → Active hours ตั้งช่วงที่ใช้งาน

## tweaks ของโปรเจกต์ในหมวด Windows

| Tweak | โปรไฟล์ | ผล |
|---|---|---|
| `win.gamemode-on` | balanced, performance, gaming, max | เปิด Game Mode |
| `win.mouse-accel-off` + `win.mouse-thresholds` | gaming, max | ปิด mouse acceleration |
| `win.keyboard-delay` | gaming, max | ดีเลย์คีย์สั้นสุด |
| `win.unhide-power-settings` | performance, gaming, max | แสดงค่า power ขั้นสูง |
| `win.visualfx-performance` | max | ปิด animation |
| `win.transparency-off` | max | ปิด acrylic/blur |
| `win.background-apps-off` | max | ปิดแอปพื้นหลัง |
| `win.services-diagtrack` | max | ปิด telemetry |
| `win.services-dmwappush` | max | ปิด WAP push |
| `win.services-mapsbroker` | max | ปิด MapsBroker |
| `win.bcd-dynamictick` (High) | max | ปิด dynamic tick |
| `win.bcd-platformclock` (High) | max | บังคับ TSC |

## เช็กลิสต์ debloat ที่ปลอดภัย

1. ปิด startup apps ที่ไม่ใช้ (ได้ผลที่สุด)
2. ปิด GameDVR
3. ตั้ง Defender exclusions สำหรับโฟลเดอร์ build
4. ปิด Widgets / News
5. ตั้ง Active hours ของ Windows Update
6. ลบแอป Store ที่ไม่ใช้ (Settings → Apps → Installed apps)
7. **อย่า** ปิด Windows Update, Defender, หรือ service ที่ไม่รู้จัก
8. **อย่า** ใช้สคริปต์ debloat จากอินเทอร์เน็ตที่ไม่ตรวจสอบ — หลายตัวปิดสิ่งที่จำเป็นต่อการบูต

## ตรวจสอบผลกระทบ

หลังปิดบริการ ให้ตรวจว่าไม่มีอะไรพัง:

```powershell
# ดู error ใน Event Log 24 ชั่วโมงล่าสุด
Get-WinEvent -FilterHashtable @{LogName='System'; Level=1,2; StartTime=(Get-Date).AddDays(-1)} |
  Group-Object ProviderName | Sort-Object Count -Descending |
  Select-Object -First 10 Count, Name
```

ถ้าเจอ error ใหม่ที่เกี่ยวกับบริการที่ปิด → `restore` หรือเปิดบริการกลับด้วย `Set-Service -StartupType Manual`
