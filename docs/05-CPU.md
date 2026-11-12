# จูน CPU เชิงลึก (Core i9-9900K)

## ซีพียูในเครื่องนี้คืออะไร

| คุณสมบัติ | ค่า |
|---|---|
| รุ่น | Intel Core i9-9900K (Coffee Lake Refresh) |
| Cores / Threads | 8 / 16 (Hyper-Threading เปิด) |
| Base clock | 3.6 GHz |
| Max Turbo | 5.0 GHz (single core, TVB) |
| All-core Turbo | ~4.7 GHz (ขึ้นกับ power/thermal budget) |
| L3 cache | 16 MB |
| TDP | 95 W (PL1), PL2 สูงถึง ~210 W ที่ค่าสต็อก |
| Tjmax | 100 °C |
| Socket | LGA1151 v2 — เป็นซีพียู **เดสก์ท็อป** ที่ใส่ในบอดี้โน้ตบุ๊ก |
| หน่วยความจำ | DDR4-2666 (บัสที่รองรับอย่างเป็นทางการ) |

การที่เครื่อง N95TP6 ใส่ซีพียูเดสก์ท็อป 95W ในบอดี้โน้ตบุ๊กคือหัวใจของทุกอย่างในเอกสารนี้: **ศักยภาพสูง แต่ขีดจำกัดความร้อนต่ำ** ซอฟต์แวร์จึงไม่ใช่คอขวดหลัก — ระบบระบายความร้อนและการจ่ายไฟคือคอขวด

## โมเดลการจัดการพลังงานที่ต้องเข้าใจก่อน

Windows และซีพียูคุยกันผ่านกลไกหลายชั้น ถ้าไม่เข้าใจชั้นเหล่านี้ การตั้งค่าจะขัดกันเอง

### P-State (Performance State)

สถานะความถี่/ไฟของคอร์ ตั้งแต่ P0 (เร็วสุด) ลงไปถึง Pn (ช้าสุด) Windows ไม่ได้สั่ง P-state ตรง ๆ อีกต่อไป แต่บอก "ความต้องการ" ผ่าน:

- **PROCTHROTTLEMIN / PROCTHROTTLEMAX** — เพดานล่าง/บนของ state เป็นเปอร์เซ็นต์ ตัวควบคุมจะแปลงเป็นความถี่
- **PERFEPP (Energy Performance Preference)** — ค่า 0-100 ที่ใช้กับ Intel Speed Shift (HWP) 0 = เน้นประสิทธิภาพ, 100 = เน้นประหยัด
- **PERFBOOSTMODE** — อนุญาตให้เกิน base clock (Turbo) หรือไม่ และ aggressive แค่ไหน

### C-State (Core/package idle state)

C0 = ทำงาน, C1 = halt, C3/C6 = deeper sleep, C7+ = package deep sleep ยิ่งลึกยิ่งประหยัดแต่ **wake latency สูงขึ้น** (C6 ~ 100 µs, C7 ~ 200-400 µs)

`power.cpu.idle-disable` (IDLEDISABLE=1) ปิดการเข้า C-state นอก C0/C1 → latency ต่ำสุด แต่ idle power พุ่ง 20-40 W บนซีพียูนี้ (เทียบเท่าเปิดหลอดไฟ 24 ชั่วโมง)

### Core Parking

Windows อาจ "จอด" คอร์ที่ไม่ได้ใช้ (unpark latency หลักมิลลิวินาที) `CPMINCORES=100` บังคับให้ทุกคอร์ตื่นตลอด

บน i9-9900K ที่มี 8 คอร์ การปิด parking ให้ผลชัดกับเกมที่ scale ได้ถึง 8 thread แต่เพิ่มความร้อนเพราะทุกคอร์มีไฟเลี้ยง

### Timer resolution และ coalescing

Windows รวม timer interrupt เพื่อประหยัดไฟ (timer coalescing) ทำให้ความละเอียดของ timer ลดจาก 1 ms เหลือ 15.6 ms ในบางสถานการณ์ `bcdedit /set disabledynamictick yes` ปิด dynamic tick ที่ทำให้เกิดการรวมนี้ — เป็น tweak ระดับ High ที่มีทั้งประโยชน์ (จูน audio/real-time) และโทษ (กินไฟ, ไดรเวอร์บางตัวเพี้ยน)

## ตาราง tweaks ของโปรเจกต์ที่เกี่ยวกับ CPU

| Tweak | กลไก | โปรไฟล์ | ผลที่วัดได้โดยประมาณ |
|---|---|---|---|
| `power.cpu.min50` | PROCTHROTTLEMIN AC=50 | performance, gaming | ลด P-state switching, jitter นิ่งขึ้น |
| `power.cpu.min100` | PROCTHROTTLEMIN AC=100 | max | ไม่มี downclock, latency ต่ำสุด, +15-30 W idle |
| `power.cpu.max100` | PROCTHROTTLEMAX AC/DC=100 | performance, gaming, max | ปลดล็อกเพดานบน (สำคัญตอนใช้แบต) |
| `power.cpu.boost-enabled` | PERFBOOSTMODE=1 | performance, gaming | Turbo ทำงานปกติ |
| `power.cpu.boost-aggressive` | PERFBOOSTMODE=2 | max | ขึ้น boost ทันที, กินไฟพุ่ง |
| `power.cpu.epp-performance` | PERFEPP=25 | performance, gaming | CPU เลือกความถี่สูงไวขึ้น |
| `power.cpu.epp-max` | PERFEPP=0 | max | ความถี่สูงสุดตลอด |
| `power.cpu.cooling-active` | SYSCOOLPOL=1 | performance, gaming, max | พัดลมนำ, clock ไม่ถูกตัดก่อนเวลา |
| `power.cpu.coreparking-off` | CPMINCORES=100 | gaming, max | ตัด wake latency ของคอร์ |
| `power.cpu.thresholds` | PERFINCTHRESHOLD=30 | performance, gaming, max | ตอบสนองงาน burst ไวขึ้น |
| `power.cpu.idle-disable` (High) | IDLEDISABLE=1 | max | latency ต่ำสุด, ร้อน/กินไฟมาก |
| `mem.priority-separation` | Win32PrioritySeparation=38 | performance, gaming, max | foreground ได้ timeslice มากกว่า |
| `win.bcd-dynamictick` (High) | disabledynamictick | max | timer jitter ต่ำลง |

### อธิบาย Win32PrioritySeparation=38

ค่านี้ไม่ใช่ "ตัวเลขวิเศษ" แต่เป็น bit field:

| Bit | ความหมาย | ค่า 38 (0x26) |
|---|---|---|
| 5:4 | Quantum type | `10` = variable (สั้น/ยาวสลับตาม foreground) |
| 3:2 | Quantum length | `01` = สั้น (เหมาะกับ interactive) |
| 1:0 | Foreground boost | `10` = 3:1 (foreground ได้เวลา CPU 3 เท่า) |

ค่าเริ่มต้นของ Windows คือ `2` (0x02) ซึ่ง boost แค่ 2:1 และ quantum ปกติ ถ้าเครื่องนี้ใช้ทำงาน batch/เรนเดอร์เป็นหลัก ให้ลอง `26` (0x1A) ซึ่งเป็น quantum แบบ fixed-long

## ค่าที่ควรตั้งใน BIOS (ไม่ใช่ใน Windows)

เข้าหน้า BIOS ด้วย `Del` หรือ `F2` ตอนบูต (AMI 1.07.11 บนเครื่องนี้) รายการที่ควรตรวจ:

| รายการ | ค่าที่แนะนำ | เหตุผล |
|---|---|---|
| Intel SpeedStep (EIST) | Enabled | ปล่อยให้ OS คุม P-state |
| Turbo Mode | Enabled | จำเป็นสำหรับ 5.0 GHz |
| C-States (C1E/C3/C6/C7) | Enabled | ให้ OS คุมผ่าน power plan แทนการปิดใน BIOS |
| Hyper-Threading | Enabled | 16 thread มีประโยชน์กับงาน multi-thread |
| XMP / DRAM Profile | Profile 1 (ถ้าแรมรองรับ) | DDR4-2666+ ให้ bandwidth มากขึ้น |
| VT-d / VT-x | ตามการใช้งาน | เปิดถ้าใช้ VM/WSL2 (แต่ VBS มีผลต่อประสิทธิภาพ) |
| Fan control | Performance mode | สำคัญที่สุดสำหรับเครื่องนี้ |
| Power limit (PL1/PL2) | ตามค่า EC ของเครื่อง | ถ้าปรับได้ ให้ PL1 ~65-75 W จะเย็นกว่าโดยเสีย performance ไม่มาก |

> เครื่อง Clevo มักซ่อนตัวเลือก fan curve และ power limit ไว้ในเมนูซ่อน หรือให้ปรับผ่านซอฟต์แวร์ของผู้ผลิต (Control Center) ถ้าหาไม่เจอ ไม่ต้องพยายามแฟลช BIOS ดัดแปลง — ความเสี่ยงสูงเกินกว่าประโยชน์

## Undervolt — ทางที่ได้ผลที่สุดแต่โปรแกรมนี้ไม่ทำ

i9-9900K ที่ -100 mV โดยทั่วไปจะเย็นลง 5-10 °C และได้ all-core clock สูงขึ้น เพราะ PL/thermal budget เหลือมากกว่าเดิม นี่คือ tweak ที่คุ้มที่สุดสำหรับเครื่องนี้ แต่ต้องทำด้วยมือ:

1. ติดตั้ง **Intel XTU** (ง่าย, มี GUI) หรือ **ThrottleStop** (ละเอียดกว่า, ไม่ต้องติดตั้ง)
2. ลด **Core Voltage Offset** ทีละ -25 mV: -25 → -50 → -75 → -100 → -125
3. ทดสอบเสถียรภาพทุกขั้นด้วย Prime95 Small FFT 15 นาที + Cinebench R23 loop 3 รอบ
4. ถ้าเจอ WHEA error, จอฟ้า, หรือโปรแกรม crash → ถอยกลับ 25 mV
5. บันทึกค่าที่เสถียรและตั้งให้โหลดตอนบูต (ThrottleStop: Task Scheduler)

**ข้อควรระวัง**: undervolt มากเกินไปทำให้เกิด "silent corruption" — เครื่องไม่ crash แต่ผลลัพธ์คำนวณผิด ถ้าใช้งานสำคัญ ให้ทดสอบด้วย OCCT หรือ y-cruncher นานขึ้น

## VBS / Memory Integrity — tradeoff ที่ต้องเลือก

Core Isolation (HVCI) และ Virtualization-Based Security เปิดโดย default บน Windows 11 และกินประสิทธิภาพ 5-15% ในเกมบางตัว (โดยเฉพาะที่เรียก syscall ถี่) การปิดเป็นทางเลือกส่วนตัว:

```
Windows Security → Device security → Core isolation → Memory integrity = Off
```

หลังจากปิด ต้อง reboot และ **ลดความปลอดภัยลงจริง** — โปรแกรมนี้ไม่ปิดให้ เพราะเป็นการตัดสินใจเชิงนโยบาย ไม่ใช่การจูน

## วิธีวัดผล CPU อย่างมีความหมาย

| เครื่องมือ | วัดอะไร | วิธีอ่าน |
|---|---|---|
| `.\Level51Tune.ps1 bench` | SHA-256 throughput 1 thread / ทุก thread | `efficiency` ต่ำกว่า ~65% ของ physical cores = ถูกจำกัดพลังงานหรือความร้อน |
| Cinebench R23 | คะแนนมาตรฐานเทียบกับคนอื่นได้ | 9900K สต็อกในเคสปกติ ~12,000-12,500 multi / ~1,250 single; ในโน้ตบุ๊กจะต่ำกว่า |
| HWiNFO64 | clock จริง, package power, อุณหภูมิ, throttle reason | ดู `Core Effective Clocks`, `CPU Package Power`, `Thermal Throttling` |
| LatencyMon | DPC/ISR latency | ค่า < 500 µs ถือว่าดี, > 1000 µs ทำให้เสียง/เฟรมสะดุด |
| Task Manager → Performance | ภาพรวมเร็ว ๆ | ดู "Speed" ว่าแตะ 4.7 GHz ได้จริงไหม |

ลำดับการทดสอบที่แนะนำ:

```powershell
.\Level51Tune.ps1 bench -Label before -Seconds 5
# ... apply profile ...
# reboot ถ้ามี tweak ที่ต้อง reboot
Start-Sleep -Seconds 120      # ให้เครื่องเย็นลงก่อนวัด (สำคัญมาก)
.\Level51Tune.ps1 bench -Label after -Seconds 5
.\Level51Tune.ps1 compare
```

`bench` ใช้ SHA-256 hash บัฟเฟอร์ 4 MB ซ้ำ ๆ เป็นภาระงาน ตัวเลขที่ได้จึงเป็น MB/s ของซีพียูจริง (448 MB/s = 1 thread, ~2,700 MB/s = 8 thread บนเครื่องนี้) ถ้าใช้ลูปคำนวณใน PowerShell เอง ผลจะสะท้อนความเร็วของ interpreter มากกว่าซีพียู

> **ทำไมต้องรอให้เย็น**: ถ้าวัด "after" ทันทีหลัง apply ขณะเครื่องยังร้อนจากงานก่อนหน้า ตัวเลขจะต่ำกว่า "before" ทั้งที่การตั้งค่าดีกว่า — thermal state มีผลมากกว่าการตั้งค่าซอฟต์แวร์เกือบทั้งหมดบนเครื่องนี้

## อาการที่บอกว่า CPU กำลัง throttling

| อาการ | ตรวจด้วย | แก้ |
|---|---|---|
| clock ตกจาก 4.7 เหลือ 2.4 GHz หลังจากเล่นเกม 5 นาที | HWiNFO `Thermal Throttling = Yes` | ทำความสะอาดพัดลม, เปลี่ยน thermal paste, ลด PL ใน BIOS |
| multi-thread scaling ต่ำกว่า 60% | `bench` | เช็คความร้อนก่อน อย่างอื่นทีหลัง |
| เครื่องดับเองตอนโหลดหนัก | Event Viewer → Kernel-Power 41 | ระบบจ่ายไฟ/ระบายความร้อนไม่พอ — หยุดใช้โปรไฟล์ max |
| เสียงพัดลมดังตลอดเวลา | `status` ดูอุณหภูมิ | เปลี่ยน cooling policy เป็น passive หรือใช้โปรไฟล์ balanced |

## สรุปสำหรับเครื่องนี้

1. เริ่มจาก `performance` — ได้ประโยชน์จริงโดยไม่ทำให้ร้อนเกิน
2. ถ้าเล่นเกมและอุณหภูมิยังต่ำกว่า 90 °C ให้ใช้ `gaming`
3. อย่าใช้ `max` ค้างไว้ — ใช้เฉพาะ benchmark สั้น
4. สิ่งที่ได้ผลที่สุดคือ **undervolt + ทำความสะอาดระบบระบายความร้อน** ซึ่งอยู่นอกขอบเขตโปรแกรมนี้
5. วัดผลทุกครั้งหลังเครื่องเย็น และอย่าเชื่อตัวเลขที่ต่างกันไม่ถึง 3-5%
