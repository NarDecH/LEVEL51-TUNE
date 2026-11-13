# AGENTS.md

คู่มือสำหรับ AI agent / ผู้พัฒนาที่เข้ามาทำงานใน repository นี้ อ่านก่อนแก้โค้ดทุกครั้ง

## 1. โปรเจกต์นี้คืออะไร

`LEVEL51-TUNE` คือชุดเครื่องมือ PowerShell สำหรับปรับแต่งประสิทธิภาพเครื่อง LEVEL51 (Clevo N95TP6 · i9-9900K · GTX 1060 · 32 GB · NVMe 1 TB · Windows 11 Pro)

เป้าหมาย: ปรับค่า power/registry/service ที่วัดผลได้ พร้อมสำรองและย้อนกลับได้ **ไม่ใช่** เครื่องมือ overclock หรือ debloat แบบทำลายระบบ

## 2. โครงสร้างและหน้าที่ของแต่ละไฟล์

| ไฟล์ | หน้าที่ | แก้เมื่อไหร่ |
|---|---|---|
| `Level51Tune.ps1` | CLI entry: parse คำสั่ง, help, exit code, จัดการ encoding | เพิ่ม/แก้คำสั่ง CLI |
| `src/Level51Tune.psm1` | engine: detect hardware, backup, apply, restore, audit, status, report, docs build | แก้กลไก ไม่ใช่ค่า tweak |
| `src/Catalog.ps1` | **ข้อมูล** tweaks 60 รายการ + นิยามโปรไฟล์ | เพิ่ม/แก้ tweak |
| `src/Markdown.ps1` | markdown → HTML (ไม่มี dependency) | แก้ renderer เท่านั้น |
| `src/Bench.ps1` | micro-benchmark, history, compare, `Measure-L51Latency` | แก้วิธีวัด |
| `Level51Tune.Web.ps1` | Web GUI server: HttpListener, token, routing, เสิร์ฟ `/docs/*` | เพิ่ม/แก้ endpoint GUI |
| `Start-LEVEL51.cmd` | ตัวเรียก GUI 1 คลิก (UAC → `Level51Tune.Web.ps1 -Elevate`) | แทบไม่ต้องแตะ |
| `Start-LEVEL51-Tray.cmd` | ตัวเรียก tray 1 คลิก (ไม่ต้อง admin — tray ขอ UAC เอง) | แทบไม่ต้องแตะ |
| `Level51Tune.Tray.ps1` | tray icon (WinForms): สลับโปรไฟล์/สถานะ/เปิด Dashboard (เรียก `/api/open-dashboard` ให้เซิร์ฟเวอร์เปิดเบราว์เซอร์พร้อม token) | เพิ่มเมนู tray |
| `tools/Build-Package.ps1` | สร้าง `dist/LEVEL51-TUNE-<version>.zip` | แก้รายการไฟล์ที่แจกจ่าย |
| `tools/Build-Msix.ps1` | สร้าง MSIX (launcher C# + AppxManifest + makeappx) | แก้ manifest/launcher |
| `src/WebUI.ps1` | HTML dashboard แบบ single-page 3 แท็บ (placeholder `__TOKEN__`) | แก้หน้าตา/JS ของ GUI |
| `tools/Build-Docs.ps1` | wrapper สำหรับสร้าง docs | แทบไม่ต้องแตะ |
| `tools/AB-Bench.ps1` | A/B throughput ระหว่าง 2 power scheme (A-B-B-A) | แก้วิธีทดลอง |
| `tools/AB-Latency.ps1` | A/B DPC/interrupt (ต้อง admin เพราะสลับ scheme) | แก้วิธีทดลอง |
| `tests/Test-Level51Tune.ps1` | test suite (ไม่ต้อง admin) | เพิ่ม test เมื่อเพิ่มความสามารถ |
| `docs/*.md` | เอกสารต้นฉบับ (ภาษาไทย) | แก้เอกสาร |
| `docs/*.html` | **ไฟล์ที่สร้างอัตโนมัติ** — ห้ามแก้ด้วยมือ | ถูกเขียนทับโดย `docs` command |

## 3. คำสั่งที่ใช้บ่อย

```powershell
# รัน CLI
pwsh -NoProfile -File .\Level51Tune.ps1 status
pwsh -NoProfile -File .\Level51Tune.ps1 apply -Profile gaming -DryRun
pwsh -NoProfile -File .\Level51Tune.Web.ps1 -NoBrowser   # GUI (เปิดค้างไว้ แล้วเปิด URL จาก console)

# test (ต้องผ่านก่อน commit ทุกครั้ง)
pwsh -NoProfile -File .\tests\Test-Level51Tune.ps1

# สร้าง docs หลังแก้ md
pwsh -NoProfile -File .\tools\Build-Docs.ps1
```

บนเครื่องนี้ใช้ `pwsh` (PowerShell 7) เป็นหลัก แต่โค้ด **ต้องรองรับ Windows PowerShell 5.1** ด้วย

## 4. กติกาการเขียนโค้ด

### ความเข้ากันได้

- ห้ามใช้ syntax ของ PowerShell 7 เท่านั้น: ไม่มี ternary (`? :`), ไม่มี `??`, ไม่มี `-Parallel`, ไม่มี `&&`
- **ห้ามใช้ `if` เป็น expression** ในที่ที่ต้องการค่า เช่น ใน hashtable literal หรือเป็น argument:
  ```powershell
  # ผิด (parse error)
  @{ Value = if ($x) { 1 } else { 0 } }
  Invoke-X -Arg (if ($x) { 1 } else { 0 })

  # ถูก
  $v = 0
  if ($x) { $v = 1 }
  @{ Value = $v }
  ```
- ตัวแปรที่แก้ไขภายใน helper function ต้องอยู่ใน hashtable หรือส่งเข้า-ออกผ่านพารามิเตอร์ (PowerShell scope ไม่ใช่ closure)
- ใช้ ASCII ในชื่อฟังก์ชัน/ตัวแปร/Id; ข้อความผู้ใช้และเอกสารเป็นภาษาไทย

### Encoding

ไฟล์ `.ps1` / `.psm1` **ต้องเป็น UTF-8 with BOM** เพราะ Windows PowerShell 5.1 อ่านไฟล์ที่ไม่มี BOM ด้วย codepage ของระบบ แล้วภาษาไทยจะเพี้ยน หลังสร้าง/แก้ไฟล์ด้วย editor ที่ไม่มี BOM ให้เติม BOM:

```powershell
$p = 'src\Catalog.ps1'
$t = Get-Content $p -Raw -Encoding UTF8
[IO.File]::WriteAllText($p, $t, (New-Object Text.UTF8Encoding($true)))
```

ไฟล์ `.md` / `.html` / `.css` เป็น UTF-8 ไม่ต้องมี BOM

### การบันทึก log

ใช้ `Write-L51Log -Message ... -Level INFO|OK|WARN|ERR|STEP|DEBUG` เท่านั้น (ไม่ใช้ `Write-Host` ใน engine — `Write-Host` ใช้ได้ใน CLI layer และใน status/bench ที่ต้องการจัดรูปแบบ)

## 5. การเพิ่ม tweak ใหม่

1. เพิ่ม record ใน `src/Catalog.ps1` ตาม schema ด้านบนไฟล์ (`Id`, `Category`, `Title`, `TitleTh`, `Risk`, `Admin`, `Reboot`, `Profiles`, `Type`, `Notes`)
2. ใส่ field ตาม `Type`:
   - `Power` → `Subgroup`, `Setting`, `AC`, `DC` (ใช้ alias เช่น `SUB_PROCESSOR`, `PROCTHROTTLEMIN`)
   - `Registry` → `Path` (`HKLM:\` / `HKCU:\`), `Name`, `Value`, `ValueType`
   - `Service` → `ServiceName`, `StartupType`
   - `Script` → `ApplyScript`, `RevertScript`, `DetectScript` (รับ `param($ctx)` โดย `$ctx.DryRun` คือ boolean)
3. `Script` tweak **ต้องตรวจ `$ctx.DryRun`** ก่อนสั่งเปลี่ยนแปลงใด ๆ เสมอ
4. `Script` tweak ต้องคืนค่า previous state ที่ JSON-serializable (hashtable/array) ถ้าต้องการให้ restore ใช้ได้
5. เพิ่ม tweak เข้าโปรไฟล์ที่เหมาะสมใน `Profiles`
6. อัปเดตเอกสาร: `docs/04-โปรไฟล์.md` (ตารางของโปรไฟล์นั้น) และเอกสารหมวดที่เกี่ยวข้อง
7. รัน `tests/Test-Level51Tune.ps1` — test จะตรวจ schema ให้อัตโนมัติ

### เกณฑ์การให้ Risk

| ระดับ | ใช้เมื่อ |
|---|---|
| `Low` | คืนค่าได้ทันที ไม่กระทบความเสถียร และไม่ทำให้เครื่องร้อนขึ้นชัด |
| `Medium` | เปลี่ยนพฤติกรรมที่ผู้ใช้รู้สึกได้ หรือกินไฟ/ร้อนขึ้น |
| `High` | อาจทำให้ไม่เสถียร ต้อง reboot และแก้คืนยาก (ต้องถูกข้ามเว้นแต่ผู้ใช้ใส่ `-Include high`) |

## 6. Safety invariants (ห้ามละเมิด)

1. **backup ก่อนแก้เสมอ** — `Invoke-L51Apply` ต้องเขียน backup ไฟล์ก่อนคำสั่งเปลี่ยนแปลงแรก
2. **ห้ามแตะ power scheme เดิม** — ต้อง `powercfg -duplicate` แล้วทำงานบน scheme ใหม่เท่านั้น
3. **`-DryRun` ต้องไม่เปลี่ยนระบบ** — ไม่สร้างไฟล์ใน `backups/`, `state/`, ไม่สร้าง scheme, ไม่เรียกคำสั่งที่ mutate
4. **ห้ามปิด Windows Update / Defender / audio / print spooler** โดยไม่ได้รับการร้องขอชัดเจน
5. **ห้ามรันคำสั่งที่ต้อง admin เองในระหว่างพัฒนา** — ใช้ `-DryRun` ในการตรวจสอบ
6. **ห้าม commit** `backups/`, `logs/`, `state/`, `benchmarks/`, `reports/` (อยู่ใน `.gitignore` แล้ว)
7. **ห้ามอ้างว่าเร็วขึ้นโดยไม่มีตัวเลข** — ถ้าจะกล่าวถึง performance ต้องมีผลจาก `bench` หรือระบุว่า "ยังไม่ได้วัด"
8. **GUI ต้องเป็น thin adapter** — `Level51Tune.Web.ps1` และ `src/WebUI.ps1` ห้ามมี logic ปรับแต่งระบบเอง ต้องเรียกฟังก์ชันใน `Level51Tune.psm1` เท่านั้น
9. **GUI ต้องฟังเฉพาะ loopback และบังคับ token** — ห้าม bind `0.0.0.0`, ห้ามเพิ่ม CORS, ห้ามให้ endpoint ที่ mutate ทำงานได้โดยไม่ผ่าน `Assert-L51Admin`
10. **token ห้ามลงดิสก์/ไฟล์** — สร้างใหม่ทุกครั้งที่เริ่มโปรเซส และส่งให้ผู้ใช้ทาง console เท่านั้น
11. **tray ต้องไม่รันแบบ elevated ค้างไว้** — ทุก action ที่แก้ระบบต้อง `Start-Process -Verb RunAs` แล้วจบ
12. **GPU preference เขียนเฉพาะ `HKCU`** — ห้ามเขียน `HKLM`/ค่าทั้งระบบแทนผู้ใช้โดยไม่ได้รับการร้องขอ
13. **เน็ตได้เฉพาะ `update`** — `Get-L51UpdateInfo` เป็นคำสั่งเดียวที่เรียกเน็ต (อ่าน metadata release) ต้องไม่ดาวน์โหลด/ติดตั้งอะไร และคำสั่งอื่นต้องทำงานแบบ offline ได้เสมอ
    - ข้อยกเว้นเดียว: `tools/Build-Msix.ps1 -TimestampServer <url>` ต่อเน็ตเพื่อประทับเวลาลายเซ็น **เฉพาะเมื่อผู้ใช้ระบุ flag นี้** (ไม่ระบุ = ไม่ต่อเน็ต) และต้องไม่ดาวน์โหลดอะไรลงโปรเจกต์
14. **ห้ามผูก logic เข้ากับฮาร์ดแวร์ตัวเดียว** — `Get-L51Recommendation` ต้องคิดจากข้อมูลจริงของเครื่อง (RAM channel / CPU class / dGPU) ไม่ hard-code `LEVEL51`
15. **MSIX ต้องไม่แอบขอสิทธิ์** — launcher ใน MSIX ต้องไม่พยายามยกระดับสิทธิ์/หลบ UAC; ถ้า MSIX ถูกจำกัดให้ document ข้อจำกัดนั้น ไม่ใช่หาทางเลี่ยง

## 7. กติกาเอกสาร

- เอกสารทั้งหมดเป็น **ภาษาไทย** ศัพท์เทคนิคคงภาษาอังกฤษ (เช่น `powercfg`, P-state, frametime)
- `docs/*.md` คือต้นฉบับ — `docs/*.html` ถูกสร้างจาก `Build-L51Docs` ห้ามแก้ html ด้วยมือ
- ชื่อไฟล์ขึ้นต้นด้วยเลขสองหลักเพื่อกำหนดลำดับใน sidebar (`01-`, `02-`, ...)
- H1 หนึ่งอันต่อไฟล์ (ใช้เป็นชื่อใน sidebar), H2 สำหรับหัวข้อหลัก (จะถูกทำ TOC อัตโนมัติ)
- ตารางและ code block รองรับ: ใช้ `|...|` และ ` ```powershell `
- **ห้ามใช้ nested list** — renderer รองรับ list ระดับเดียว (indented item จะได้ class `nested` แต่ไม่ซ้อนจริง) ให้ใช้ตารางหรือหัวข้อย่อยแทน
- อ้างอิงข้ามไฟล์ใช้ลิงก์แบบ `[ชื่อ](05-CPU.md)` (md) — builder จะคงลิงก์ไว้เป็น `.md` ใน html ด้วย ให้ใช้ชื่อไฟล์ `.md` เสมอเพื่อความสอดคล้อง
- หลังแก้ md ต้องรัน `Build-L51Docs` และตรวจว่าไม่มี placeholder `__TITLE__` ค้าง

## 8. Definition of done สำหรับการเปลี่ยนแปลง

```
[ ] tests ผ่านทั้งหมด (pwsh -NoProfile -File .\tests\Test-Level51Tune.ps1)
[ ] dry-run apply ของทุกโปรไฟล์ไม่มี FAIL
[ ] docs สร้างใหม่ได้และ html ไม่มี placeholder ค้าง
[ ] ไฟล์ .ps1/.psm1 เป็น UTF-8 with BOM
[ ] ไม่มีข้อมูลลับ (token, path ที่มีชื่อผู้ใช้แบบเจาะจง, key) ในไฟล์
[ ] ถ้าแตะ tweak ใหม่: มีเอกสารอธิบายและอยู่ในโปรไฟล์ที่สมเหตุสมผล
```

## 9. การ commit

ข้อความ commit ภาษาไทยหรืออังกฤษก็ได้ ให้Up short และบอก "ทำไม" ไม่ใช่แค่ "ทำอะไร" ตัวอย่าง:

```
เพิ่ม tweak ปิด NVIDIA dynamic P-State สำหรับโปรไฟล์ max

clock ของ GTX 1060 แกว่งระหว่างเล่นเกม lightweight ทำให้ frametime ไม่นิ่ง
tweak นี้เป็น High risk และถูกข้ามเว้นแต่ผู้ใช้ใส่ -Include high
```

ไม่ต้องใส่ AI attribution หากไม่ได้รับอนุญาตให้ใส่

## 10. ข้อจำกัดที่ต้องสื่อสารกับผู้ใช้เสมอ

- เครื่องมือนี้แตะได้เฉพาะชั้นซอฟต์แวร์ ไม่ใช่ BIOS/EC/firmware
- บน N95TP6 ความร้อนเป็นคอขวดจริง — `max` ไม่ควรใช้ค้างไว้
- micro-benchmark มี noise ±3-5%
- tweaks ประเภท `Script` (fsutil/netsh/bcdedit) ไม่ถูกย้อนอัตโนมัติโดย `restore`
