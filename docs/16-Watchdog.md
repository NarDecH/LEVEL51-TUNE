# Watchdog: กันเครื่องพังหลัง apply

บทนี้พูดถึงกลไกกันตายที่ทำให้การลอง tweaks (รวมถึงของเสี่ยงสูง) ย้อนกลับได้เอง แม้เครื่องจะบูตไม่ขึ้นหรือ BSOD หลัง apply

## ปัญหาที่แก้

ก่อนมี watchdog ความปลอดภัยทั้งหมดพึ่งความจำของผู้ใช้: apply แล้วถ้าเครื่องมีปัญหา ต้องเปิด PowerShell ให้ได้ จำได้ว่า backup ไฟล์ล่าสุดชื่ออะไร แล้วรัน `restore` ให้ทัน — ซึ่งเป็นตอนที่เครื่องอาจใช้งานไม่ได้อยู่แล้ว ถ้าอาการหนักถึงขั้นบูตไม่ขึ้น ก็แทบไม่มีทางย้อนกลับได้เลย

## หลักการ

watchdog คือ **sentinel file + ตัวตัดสินใจ + Scheduled Task** อย่างละหนึ่ง

| องค์ประกอบ | ไฟล์/คำสั่ง | หน้าที่ |
|---|---|---|
| sentinel | `state/watchdog.json` | บันทึกว่า "apply เมื่อไร, backup ไฟล์ไหน, ต้องยืนยันภายในกี่นาที" |
| ตัวตัดสินใจ | `Get-L51WatchdogDecision` | ตรรกะล้วน รับ sentinel + เวลา boot + เหตุการณ์ crash แล้วตอบว่าจะทำอะไร |
| ตัวทำงาน | `Invoke-L51Watchdog -Auto` | ทำตามคำตอบ (ปิด sentinel / ย้อนกลับ / เฉย ๆ) |
| ตัวเรียกอัตโนมัติ | Scheduled Task `LEVEL51-TUNE Watchdog` | รัน `watchdog -Auto` ทุกครั้งที่ logon (SYSTEM) |

## ลำดับการทำงาน

1. `apply` เขียน backup ตามปกติ แล้วเขียน sentinel ทันทีในบล็อก `if (-not $DryRun)` — เก็บ `AppliedAt`, `ExpiresAt` (ค่าเริ่มต้น 30 นาที), `GraceMinutes` (10 นาที) และ path ของ backup
2. ผู้ใช้ restart เครื่องตามที่ระบบแจ้ง (หรือใช้งานต่อถ้าไม่ต้อง restart)
3. ที่ logon ครั้งถัดไป Scheduled Task เรียก `.\Level51Tune.ps1 watchdog -Auto`
4. ตัวตัดสินใจเลือกอย่างใดอย่างหนึ่งตามตารางด้านล่าง

| สถานะ | เงื่อนไข | สิ่งที่ทำ |
|---|---|---|
| `None` | ไม่มี sentinel / ยืนยันไปแล้ว / ย้อนกลับไปแล้ว | ไม่ทำอะไร |
| `Revert` | พบ Event ID 41, 1001 หรือ 6008 ใน System log หลังจาก `AppliedAt` | `restore` จาก backup ของ sentinel แล้วบันทึก `RevertedAt` |
| `Healthy` | boot ใหม่หลัง `AppliedAt` และ uptime ≥ `GraceMinutes` | ปิด sentinel อัตโนมัติ |
| `Wait` | boot ใหม่แล้วแต่ยังไม่ครบ grace / ยังไม่ถึงกำหนด | รอรอบถัดไป |
| `Expired` | ไม่มีการ restart ภายใน `ExpiresAt` (เช่น apply แล้วไม่รีบูต) | ลบ sentinel ถือว่าปกติ |

`Healthy` คือกรณีที่พบบ่อยที่สุด: apply → restart → ใช้งานได้ 10 นาที → watchdog ปิดตัวเองโดยไม่ต้องทำอะไร

## คำสั่ง

```powershell
# ดูสถานะ sentinel (ไม่ต้อง admin)
.\Level51Tune.ps1 watchdog

# บอกว่าเครื่องทำงานปกติ → ปิด sentinel (ไม่ต้อง admin)
.\Level51Tune.ps1 watchdog -Confirm

# ให้ตัวตัดสินใจทำงานหนึ่งรอบ (ใช้โดย Scheduled Task)
.\Level51Tune.ps1 watchdog -Auto
.\Level51Tune.ps1 watchdog -Auto -DryRun   # ดูว่าจะทำอะไร ไม่แก้อะไร

# ติดตั้ง/ถอน Scheduled Task (ต้อง admin)
.\Level51Tune.ps1 watchdog -Install
.\Level51Tune.ps1 watchdog -Uninstall
```

บน GUI: แบนเนอร์ "watchdog" ที่ด้านบนของ dashboard แสดงสถานะและมีปุ่ม **ยืนยันว่าระบบปกติ**
บน tray: เมนู **ยืนยันว่าระบบปกติ (watchdog)** และ tooltip จะต่อท้ายด้วย `· watchdog รอตรวจ` เมื่อยังไม่ปิด sentinel

## สิ่งที่ watchdog ไม่ได้ทำ

- **ไม่แทน backup** — ถ้าไม่มี backup (apply ล้มเหลวก่อนเขียนไฟล์) จะไม่มีการย้อนกลับ
- **ไม่ตรวจว่า tweak ได้ผล** — ตรวจเฉพาะ "เครื่องยังไม่พัง" เท่านั้น การตรวจค่าจริงเป็นงานของ `audit`
- **ไม่ครอบคลุม crash ที่ไม่มี event** — เช่นแอปค้างอย่างเดียว ระบบจะไม่รู้ว่าผิดปกติ (ใช้ `watchdog -Confirm` เมื่อพอใจแล้ว)
- **ไม่ทำงานถ้าไม่ได้ติดตั้ง Scheduled Task** — sentinel จะยังถูกเขียนและ `watchdog` แสดงสถานะได้ แต่จะไม่มีการตรวจอัตโนมัติ
- **ไม่ดาวน์โหลดอะไร** — ทั้งหมดทำงานในเครื่อง เป็นไปตาม invariant 13

## ความปลอดภัย

- sentinel มีเฉพาะ path ของ backup กับเวลา ไม่มี token/รหัสผ่าน
- `watchdog -Confirm` เขียนเฉพาะ `state/watchdog.json` ไม่แตะ registry หรือ power scheme จึงไม่ต้อง admin
- การย้อนกลับเรียก `Invoke-L51Restore` ตัวเดียวกับที่ผู้ใช้เรียกเอง (มี `Assert-L51Admin` ภายใน) — ถ้า Scheduled Task ไม่ได้รันด้วยสิทธิ์ที่พอ จะบันทึก `ย้อนกลับล้มเหลว` ลง log แทนการเงียบ
- Scheduled Task รันเป็น `SYSTEM` เฉพาะสคริปต์ในโฟลเดอร์โปรเจกต์ ไม่ได้เปิดพอร์ตหรือรับคำสั่งจากภายนอก

## ตรวจสอบด้วยตัวเอง

```powershell
# หลัง apply ควรมี sentinel
Get-Content .\state\watchdog.json

# ดูการตัดสินใจโดยไม่ต้องรีบูตจริง
.\Level51Tune.ps1 watchdog -Auto -DryRun

# ดู log ของ watchdog
Get-Content .\logs\l51-$(Get-Date -Format yyyyMMdd).log | Select-String watchdog
```

## ข้อจำกัดที่ควรรู้

- ถ้าเครื่อง crash **ก่อน** logon (เช่น boot loop) Scheduled Task แบบ AtLogOn จะไม่ทำงาน — ต้องใช้ Safe Mode หรือ `restore` จาก install media ในกรณีนั้น
- `GraceMinutes` 10 นาทีเป็นค่าคงที่ในโค้ด (`$script:L51WatchdogGraceMinutes`) ถ้าต้องการปรับ ต้องแก้ที่ `src/Level51Tune.psm1`
- การตรวจจับ crash อาศัย System event log ซึ่งอาจถูกเขียนทับหรือล้างได้ในเครื่องที่ log หมุนเร็ว
