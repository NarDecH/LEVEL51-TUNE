# เชิงลึก: BIOS, ฮาร์ดแวร์ และการวัดผล

## สิ่งที่รู้เกี่ยวกับเครื่องนี้

| รายการ | ค่าที่ตรวจได้ |
|---|---|
| รุ่น | Notebook N95TP6 (Clevo barebone, ขายผ่านผู้ประกอบในไทย) |
| BIOS | American Megatrends 1.07.11, 2019-08-08 |
| CPU | Intel Core i9-9900K (LGA1151 v2, 95W) |
| GPU | NVIDIA GTX 1060 6 GB (GP106) + Intel UHD 630 (Optimus, ไม่มี MUX) |
| RAM | 32 GB DDR4 (ตรวจ `ConfiguredClockSpeed` เพื่อดูว่าวิ่งที่ความเร็วเท่าไร) |
| Storage | Samsung 990 EVO Plus 1 TB NVMe (PCIe 3.0 x4 จากชิปเซ็ต) |
| Wi-Fi | Intel Wireless-AC 9260 |
| OS | Windows 11 Pro build 26200 |
| Power limit GPU | 88 W (อ่านจาก `nvidia-smi`) |

เครื่องยุค 2019 ที่ใส่ซีพียูเดสก์ท็อป: จุดแข็งคือยังแรงได้ในปี 2026 จุดอ่อนคือระบบระบายความร้อนและการจ่ายไฟออกแบบมาสำหรับภาระงานที่เบากว่าซีพียู 95W เต็มรูปแบบ

## BIOS: สิ่งที่ควรและไม่ควรทำ

### เข้า BIOS

`Del` หรือ `F2` ทันทีหลังกดเปิดเครื่อง (AMI) — ถ้าเข้าไม่ได้ อาจต้องปิด Fast Startup ก่อน (`powercfg -h off`)

### ค่าที่ควรตรวจ (ตามลำดับความสำคัญ)

| ลำดับ | รายการ | ค่าที่แนะนำ | หมายเหตุ |
|---|---|---|---|
| 1 | Fan control / Thermal profile | Performance | ถ้ามีเมนูนี้ นี่คือการตั้งค่าที่สำคัญที่สุด |
| 2 | Intel SpeedStep (EIST) | Enabled | ให้ OS คุม P-state |
| 3 | Turbo Mode | Enabled | จำเป็นสำหรับ 5.0 GHz |
| 4 | C-States (C1E, C3, C6, C7) | Enabled | ให้ Windows คุมผ่าน power plan |
| 5 | Hyper-Threading | Enabled | 16 threads |
| 6 | XMP / DRAM profile | Profile 1 | ถ้าแรมรองรับ และทดสอบเสถียรภาพ |
| 7 | VT-x / VT-d | ตามการใช้งาน | เปิดถ้าใช้ WSL2/VM |
| 8 | Secure Boot | Enabled | เปิดไว้ ปลอดภัยกว่า |
| 9 | Power limit PL1/PL2 | ลดถ้าปรับได้ (PL1 ~65-75 W) | แลก performance กับความเย็น |
| 10 | Boot order / Fast Boot | ตามต้องการ | — |

### สิ่งที่ไม่ควรทำ

| การกระทำ | ความเสี่ยง |
|---|---|
| แฟลช BIOS ดัดแปลง (modded) | เครื่อง brick, EC เพี้ยน, ประกันหลุด |
| เพิ่มไฟ CPU (overvoltage) | ซีพียูเสื่อมเร็ว, เครื่องดับ |
| Overclock ผ่าน BIOS | ระบบจ่ายไฟของโน้ตบุ๊กไม่รองรับ |
| ปิด fan / ตั้ง fan curve ต่ำสุด | ความร้อนสะสมถาวร |
| อัปเดต BIOS โดยไม่ต่อไฟ | ไฟดับกลางทาง = brick |

> ถ้า BIOS ไม่มีเมนู fan control ให้ใช้ซอฟต์แวร์ของผู้ผลิต (Control Center) หรือปล่อยให้ EC จัดการ — อย่าพยายามแฟลช BIOS ดัดแปลงเพื่อให้ได้เมนูนั้น

## การระบายความร้อน: งานที่ได้ผลที่สุด

### ลำดับความคุ้มค่า

| งาน | ลดอุณหภูมิได้ | ความยาก | ความเสี่ยง |
|---|---|---|---|
| เป่าฝุ่นออกจากพัดลม/ฮีตซิงก์ | 5-15 °C | ง่าย (เปิดฝาล่าง) | ต่ำ |
| เปลี่ยน thermal paste (CPU+GPU) | 5-12 °C | ปานกลาง | ปานกลาง (ต้องถอดฮีตซิงก์) |
| Undervolt CPU | 5-10 °C | ง่าย (ซอฟต์แวร์) | ต่ำ (ถ้าทดสอบดี) |
| Undervolt GPU | 5-8 °C | ง่าย | ต่ำ |
| Cooling pad / ยกเครื่องสูงขึ้น | 3-6 °C | ง่ายมาก | ไม่มี |
| จำกัด fps | 5-15 °C (GPU) | ง่าย | ไม่มี |
| ลด PL1 ใน BIOS | 5-10 °C | ปานกลาง | ต่ำ |

### Thermal paste

- ชนิดที่แนะนำ: non-conductive, ความหนืดปานกลาง (เช่น Arctic MX-6, Thermal Grizzly Kryonaut)
- **ห้ามใช้ liquid metal** บนโน้ตบุ๊กที่ฮีตซิงก์เป็นอะลูมิเนียม — จะกัดกร่อน
- ปริมาณ: เม็ดถั่วเขียวตรงกลาง แล้วกดฮีตซิงก์ลง (วิธี spread ก็ได้ ถ้าฮีตซิงก์มีพื้นที่แบน)
- ระวัง: สาย ribbon, ขั้วต่อพัดลม, และสกรูที่มีลำดับการขัน

### Undervolt CPU ด้วย ThrottleStop (ละเอียด)

1. ดาวน์โหลด ThrottleStop (techpowerup) — ไม่ต้องติดตั้ง
2. เปิด → กด `FIVR`
3. เลือก `CPU Core` และ `CPU Cache` → ตั้ง `Offset Voltage` เป็น **-50 mV** ก่อน
4. Apply → ทดสอบด้วย Cinebench R23 3 รอบ
5. ถ้าผ่าน เพิ่มเป็น -75, -100, -125 mV ทีละขั้น
6. ทดสอบหนักด้วย Prime95 Small FFT 15 นาที หรือ OCCT 10 นาที
7. ค่าที่เสถียร: ตั้ง `Task Scheduler` ให้ ThrottleStop เริ่มตอน login (Options → Start Minimized, Add to Task Scheduler)

**สัญญาณว่า undervolt มากเกินไป**: จอฟ้า, โปรแกรม crash แบบไม่มีเหตุผล, WHEA-Logger error ใน Event Viewer, ผลคำนวณผิด (เช่น ไฟล์บีบอัดเสีย)

>`CPU Core` และ `CPU Cache` ควรตั้งค่าใกล้กัน (cache มักทนได้น้อยกว่า) ถ้าตั้ง core -125 แต่ cache -50 ระบบมักไม่เสถียร

## การวัดผลอย่างมีความหมาย

### ปัญหาของการวัดแบบnaive

- วัดทันทีหลัง apply ขณะเครื่องยังร้อน → ตัวเลขแย่ลงทั้งที่ค่าดีขึ้น
- วัดครั้งเดียว → noise
- วัดด้วย benchmark ที่ไม่เกี่ยวกับงานจริง → ไม่มีความหมาย
- ไม่ได้ปิดโปรแกรมพื้นหลัง → ผลแกว่ง

### ระเบียบวิธีที่แนะนำ

| ขั้น | ทำอะไร |
|---|---|
| 1 | ปิดโปรแกรมทั้งหมดที่ไม่จำเป็น (เบราว์เซอร์, Discord, OBS) |
| 2 | ต่อไฟ AC และตั้งโปรไฟล์ที่ต้องการวัด |
| 3 | พักเครื่อง 2 นาที (หรือ reboot แล้วรอ 2 นาที) |
| 4 | รัน `bench -Label X -Seconds 5` |
| 5 | ทำซ้ำ 3 ครั้ง ใช้ค่ากลาง (median) |
| 6 | เปรียบเทียบด้วย `compare` |

### เครื่องมือวัดที่ควรมี

| เครื่องมือ | วัด | ฟรี |
|---|---|---|
| HWiNFO64 | อุณหภูมิ, clock, power, throttle reason ทุกเซนเซอร์ | ใช่ |
| Cinebench R23 | CPU score มาตรฐาน | ใช่ |
| 3DMark (Time Spy) | GPU/CPU combined | มีเวอร์ชันฟรี |
| LatencyMon | DPC/ISR latency | ใช่ |
| PresentMon / CapFrameX | frametime, 1% low | ใช่ |
| CrystalDiskMark | disk throughput | ใช่ |
| `.\Level51Tune.ps1 bench` | ภาพรวมเร็ว ๆ ในเครื่อง | ใช่ |

### อ่านค่า frametime ให้เป็น

| ค่า | ความหมาย |
|---|---|
| avg fps | ค่าเฉลี่ย — หลอกได้ง่าย |
| 1% low | fps ที่แย่ที่สุด 1% ของเฟรม — สำคัญกว่าค่าเฉลี่ย |
| 0.1% low | เฟรมกระตุกหนัก |
| frametime graph | ดูว่าเป็นเส้นเรียบหรือมี spike |

เกมที่ 1% low ต่ำแต่ avg สูง = มี stutter ซึ่งมักมาจาก CPU/RAM/IO ไม่ใช่ GPU

## อาการฮาร์ดแวร์ที่ควรระวัง

| อาการ | ความหมาย | ควรทำ |
|---|---|---|
| เครื่องดับเองตอนโหลดหนัก + Event ID 41 | ไฟไม่พอ / ร้อนเกิน | หยุดใช้ max, ตรวจฝุ่น/พัดลม, พิจารณาอะแดปเตอร์ |
| จอภาพมีเส้น/จุดสีตอนร้อน | GPU artifact (อาจ undervolt เกิน) | คืนค่า GPU, ทดสอบ stock |
| เสียงพัดลมดังผิดปกติ (เสียดสี) | ลูกปืนพัดลมเสื่อม | เปลี่ยนพัดลม |
| อุณหภูมิ idle สูงขึ้นเรื่อย ๆ ใน 1 ปี | ฝุ่น/paste เสื่อม | ทำความสะอาด/เปลี่ยน paste |
| SSD temperature > 70 °C | NVMe throttle | ใส่ thermal pad, ตรวจ airflow |
| แบตบวม | อันตราย | หยุดใช้ เปลี่ยนแบตทันที |

## การ backup ระดับระบบ

ก่อนแก้อะไรเชิงลึก ควรมี:

| ระดับ | วิธี |
|---|---|
| ไฟล์ส่วนตัว | OneDrive/ดิสก์ภายนอก |
| ทั้งระบบ | System Image (Control Panel → Backup and Restore → Create a system image) |
| จุดคืนค่า | `Checkpoint-Computer -Description 'before tuning'` (ต้องเปิด System Protection) |
| ค่า registry/power | `.\Level51Tune.ps1 backup` |

## สรุป

1. บนเครื่องนี้ ฮาร์ดแวร์และความร้อนคือคอขวด ไม่ใช่การตั้งค่า Windows
2. สิ่งที่ได้ผลที่สุดเรียงตามลำดับ: ทำความสะอาด → เปลี่ยน paste → undervolt → จำกัด fps → fan curve
3. BIOS: ตั้งแค่ค่าพื้นฐาน อย่าแฟลชมอด
4. วัดผลแบบมีระเบียบวิธี ไม่งั้นตัวเลขหลอกคุณ
5. 1% low และ frametime สำคัญกว่า avg fps
