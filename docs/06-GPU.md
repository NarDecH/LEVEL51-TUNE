# จูน GPU (GTX 1060 + UHD 630)

## สถาปัตยกรรมกราฟิกของเครื่องนี้

เครื่อง N95TP6 ใช้ระบบ **NVIDIA Optimus** — มี GPU สองตัวทำงานร่วมกันโดยไม่มีสวิตช์ MUX:

```
                    ┌──────────────────────────┐
Display (eDP/LVDS) ─│ Intel UHD Graphics 630   │◄── แสดงผลทุกอย่าง
                    └──────────▲───────────────┘
                               │ copy framebuffer
                    ┌──────────┴───────────────┐
                    │ NVIDIA GTX 1060 (GP106)  │◄── เรนเดอร์เมื่อถูกเลือก
                    └──────────────────────────┘
```

ผลที่ตามมาที่สำคัญมาก:

- **ทุกเฟรมต้องผ่าน iGPU** แม้จะเรนเดอร์บน GTX 1060 → มี overhead และเพิ่ม latency เล็กน้อย เป็นข้อจำกัดของฮาร์ดแวร์ แก้ด้วยซอฟต์แวร์ไม่ได้
- **ถ้าโปรแกรมไม่ได้ลงทะเบียน ระบบอาจเลือก iGPU** ซึ่งทำให้เกมวิ่ง 15-25 fps แทน 100+ fps — นี่คือปัญหาที่พบบ่อยที่สุดและ tweak `gpu.prefer-dgpu-global` แก้ให้
- **HDMI/DisplayPort บางพอร์ตต่อตรงกับ NVIDIA** (ถ้าเครื่องมี) ทำให้ต่อจอภายนอกแล้วได้เส้นทางลัดและ latency ต่ำลง

## ฮาร์ดแวร์ที่ได้จาก `nvidia-smi`

```
NVIDIA GeForce GTX 1060, driver 582.78
temp 49 C · util 1% · 164 MHz core / 4006 MHz mem · 23.91 W · 6144 MiB
power.default_limit = 88.00 W
```

| ค่า | ความหมาย |
|---|---|
| 164 MHz @ idle | P8/P0 low state — ปกติเมื่อไม่มีงาน |
| 4006 MHz mem | GDDR5 effective clock ที่ idle |
| 88 W limit | เพดานไฟของไดรเวอร์ในเครื่องนี้ (การ์ดเดสก์ท็อปอยู่ที่ 120 W) — แสดงว่า EC/BIOS จำกัดไว้ |
| 6144 MiB | VRAM 6 GB |
| 23.91 W ตอน idle | ค่อนข้างสูงสำหรับ idle; ปกติ 8-15 W — ถ้าสูงค้างอาจมีโปรเซสใช้ GPU อยู่ |
| `power.limit` = N/A | ไดรเวอร์ไม่เปิดให้อ่าน/ตั้งผ่าน `nvidia-smi` บนโมบายล์ |

ตรวจแบบละเอียด:

```powershell
nvidia-smi -q -d CLOCK,POWER,TEMPERATURE,UTILIZATION
nvidia-smi --query-gpu=clocks.gr,clocks.mem,pstate,power.draw,temperature.gpu --format=csv -l 1
```

## tweaks ของโปรเจกต์ที่เกี่ยวกับ GPU

| Tweak | กลไก | โปรไฟล์ | ผล |
|---|---|---|---|
| `gpu.hags` | `HwSchMode=2` | balanced, performance, gaming, max | GPU จัดคิวงานเองในฮาร์ดแวร์ ลด CPU overhead |
| `gpu.gamedvr-off` | `GameDVR_Enabled=0` | balanced+ | ปิด encoder พื้นหลัง คืน fps 2-8% ในบางเกม |
| `gpu.gamedvr-policy` | policy `AllowGameDVR=0` | gaming, max | ปิดทั้งเครื่อง (กันบัญชีอื่นเปิดค้าง) |
| `gpu.fullscreen-opt-off` | `GameDVR_FSEBehaviorMode=2` | gaming, max | exclusive fullscreen, input lag ต่ำลง |
| `gpu.fullscreen-opt-honor` | `GameDVR_HonorUserFSEBehaviorMode=1` | gaming, max | เคารพการตั้งรายโปรแกรม |
| `gpu.prefer-dgpu-global` | `GpuPreference=2` | gaming, max | default GPU = GTX 1060 |
| `gpu.nvidia-telemetry-off` | Service `NvTelemetryContainer=Disabled` | gaming, max | ไม่มี service ส่งข้อมูลของไดรเวอร์ |
| `gpu.nvlddmkm-pstate` (High) | `DisableDynamicPstate=1` | max | clock ไม่แกว่ง แต่ GPU ร้อนตลอด |

### HAGS (Hardware-Accelerated GPU Scheduling)

Windows ปกติให้ CPU driver จัดคิว command buffer ให้ GPU ทุกเฟรม HAGS ย้ายงานนี้ไปทำในฮาร์ดแวร์ GPU scheduler ทำให้ CPU มีเวลาเหลือและ latency ลดลงเล็กน้อย

- ต้องมีไดรเวอร์ WDDM 2.7+ (ไดรเวอร์ 582.78 ของเครื่องนี้รองรับ)
- ต้อง reboot
- ผลจริงขึ้นกับเกม: 0-5% ในเกมส่วนใหญ่, บางเกมไม่มีผล
- ตรวจว่าทำงานจริง: Task Manager → Performance → GPU → ดูว่า "Hardware-accelerated GPU scheduling" เปิดอยู่

### ทำไม per-app GPU preference ถึงสำคัญบน Optimus

Windows เลือก GPU จาก 3 แหล่ง เรียงตามลำดับความสำคัญ:

1. `HKCU\Software\Microsoft\DirectX\UserGpuPreferences\<ชื่อ exe>` (per-app)
2. `DirectXUserGlobalSettings` (global)
3. ไดรเวอร์/ผู้ผลิตเลือกเอง (มักเลือก iGPU เพื่อประหยัดไฟ)

ถ้าตั้ง global แล้วยังไม่พอ ให้ตั้ง per-app เพิ่มสำหรับเกมที่ยังวิ่งช้า:

```powershell
# ตั้งให้เกมหนึ่งใช้ GTX 1060 (GpuPreference=2 = high performance)
$key = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'
Set-ItemProperty -Path $key -Name 'C:\Games\Example\game.exe' -Value 'GpuPreference=2;' -Type String
```

หรือผ่าน UI: **Settings → System → Display → Graphics → เลือกแอป → Options → High performance**

> เคล็ดลับตรวจสอบ: ถ้า Task Manager แสดง GPU 0 (Intel) ทำงาน 30-60% พร้อม GPU 1 (NVIDIA) ทำงานต่ำ ๆ ตอนเล่นเกม = เกมกำลังใช้ iGPU

## การตั้งค่า NVIDIA Control Panel ที่แนะนำ

| การตั้งค่า | ค่า | เหตุผล |
|---|---|---|
| Power management mode | Prefer maximum performance (ตอนเล่นเกม) / Optimal power (ตอนใช้งานทั่วไป) | ลดการ downclock ระหว่างเล่น แต่ร้อนขึ้น |
| Low latency mode | On (หรือ Ultra ถ้าเกมไม่กระตุก) | ลดคิวเฟรมล่วงหน้า 1 เฟรม |
| Texture filtering - Quality | High performance | ได้ fps เพิ่มเล็กน้อย |
| Threaded optimization | Auto | เปิดสำหรับเกม DX9/11 เก่า, ปิดถ้าเกมมีปัญหา |
| Vertical sync | Off (ใช้ในเกมแทน) | ลด input lag |
| Max frame rate | ตั้งเท่ารีเฟรชเรตจอ หรือ 141 (ถ้าจอ 144) | ลดความร้อนโดยไม่ต้องใช้ V-Sync |
| Antialiasing - FXAA | Off | เบลอภาพ |
| Shader cache size | 10 GB (ถ้าดิสก์เหลือ) | ลดการ compile shader ซ้ำ |
| Preferred graphics processor | High-performance NVIDIA processor | ค่าเริ่มต้นที่ปลอดภัย |

**สิ่งที่ควรระวัง**: การตั้ง "Prefer maximum performance" ค้างไว้ทำให้ GPU ไม่ downclock ตอน idle → อุณหภูมิและไฟสูงตลอดเวลา ตั้งเฉพาะตอนเล่นเกมหรือใช้ per-app profile

## Undervolt GPU ด้วย MSI Afterburner (curve editor)

GTX 1060 ในโน้ตบุ๊กได้ประโยชน์มากจาก undervolt เพราะติดเพดานไฟ 88 W:

1. เปิด MSI Afterburner (ต้องปิด Secure Boot บางกรณี? ไม่ต้อง — Afterburner ทำงานผ่านไดรเวอร์ปกติ)
2. กด `Ctrl+F` เปิด Voltage/Frequency curve
3. เลือกจุดที่ ~1,900-2,000 MHz แล้วลากจุดนั้นขึ้นไปที่แรงดันต่ำกว่าเดิม (เช่น 0.950 V → 0.900 V)
4. กด `L` เพื่อ lock จุดนั้น แล้ว Apply
5. ทดสอบด้วย Unigine Heaven 20 นาที หรือเกมจริง 30 นาที
6. ถ้า crash/artifact → เพิ่มแรงดันกลับ 25 mV

ผลที่ได้: clock สูงขึ้น ~50-100 MHz ที่ watt เท่าเดิม หรือ watt ลดลง ~10 W ที่ clock เท่าเดิม (เย็นลง 5-8 °C)

**ทดสอบ artifact ให้ดี**: GTX 1060 ที่ undervolt เกินจะแสดงจุดสี/เส้นแปลก ๆ ก่อน crash — ต้องดูด้วยตา ไม่ใช่รอ crash

## การติดตั้งไดรเวอร์ที่สะอาด (DDU)

อาการที่บ่งบอกว่าต้องลงไดรเวอร์ใหม่แบบสะอาด:

- เกม crash เฉพาะเมื่อใช้ GTX 1060
- `nvidia-smi` ตอบช้า/ไม่ตอบ
- มี error `nvlddmkm` ใน Event Viewer
- หลัง Windows Update อัปเดตไดรเวอร์ทับแล้วมีปัญหา

ขั้นตอน:

1. ดาวน์โหลดไดรเวอร์ล่าสุดจาก NVIDIA + ดาวน์โหลด DDU
2. บูตเข้า Safe Mode
3. รัน DDU → Clean and restart (เลือก NVIDIA)
4. ติดตั้งไดรเวอร์ที่ดาวน์โหลดไว้ (เลือก Custom → ทำเครื่องหมาย Clean install)
5. รีบูต แล้วตรวจด้วย `.\Level51Tune.ps1 status`

> ไดรเวอร์ 582.78 บนเครื่องนี้ค่อนข้างใหม่ (มิถุนายน 2026) — ถ้าไม่มีปัญหา ไม่ต้องอัปเดต "เพราะมีเวอร์ชันใหม่" เพราะไดรเวอร์ใหม่บนการ์ดเก่ามักไม่ได้ดีขึ้นและอาจแย่ลง

## Intel UHD Graphics 630

iGPU ไม่ใช่ของ useless — มันทำงานตลอดเวลาเพราะเป็นตัวขับจอ:

| การตั้งค่า | ที่ไหน | คำแนะนำ |
|---|---|---|
| Power plan | Intel Graphics Command Center | Balanced |
| Video post-processing | IGCC → Video | เปิดเฉพาะตอนดูวิดีโอ |
| Xe/QuickSync | เปิดไว้ | ช่วย decode วิดีโอในเบราว์เซอร์และ OBS |
| Display refresh rate | Settings → Display → Advanced | ตรวจว่าได้ 60 Hz (หรือสูงกว่า ถ้าจอรองรับ) |

ถ้าใช้ OBS/Streamlabs ให้ใช้ QuickSync ของ iGPU เป็น encoder จะลดภาระ GTX 1060 ได้มาก — นี่คือประโยชน์จริงของการมี iGPU

## อาการที่พบบ่อยและวิธีแก้

| อาการ | สาเหตุที่เป็นไปได้ | วิธีแก้ |
|---|---|---|
| เกมได้ 20 fps ทั้งที่การ์ดแรง | ใช้ iGPU | ตั้ง per-app GPU preference |
| ภาพกระตุกทุก 2-3 วินาที | P-State แกว่ง + Optimus | ตั้ง Power management = Prefer maximum performance |
| จอดำแล้วกลับมา + Event 4101 | TDR (ไดรเวอร์ reset) | DDU + ไดรเวอร์เสถียร, ตรวจ undervolt/overclock |
| อุณหภูมิ GPU 86 °C+ ตลอด | fan curve ไม่พอ / dust | ทำความสะอาด, ตั้ง fan curve, ลด max frame rate |
| เฟรมเรตต่ำลงหลังอัปเดต Windows | HAGS/GameDVR ถูกเปิดใหม่ | `audit -Category GPU` แล้ว apply ซ้ำ |
| `nvidia-smi` ขึ้น "NVIDIA-SMI has failed" | ไดรเวอร์หลุด/ชนกับ driver update | DDU + ติดตั้งใหม่ |

## ตรวจสอบหลัง apply

```powershell
.\Level51Tune.ps1 audit -Category GPU
.\Level51Tune.ps1 gpu
```

ค่าที่ควรเห็นหลัง `gaming`:

- `gpu.hags` = YES (และ Task Manager แสดง HAGS เปิด)
- `gpu.gamedvr-off` = YES
- `gpu.prefer-dgpu-global` = YES
- `gpu.nvidia-telemetry-off` = YES (ถ้ามี service นี้ในเครื่อง)

## สรุป

1. ปัญหา GPU อันดับหนึ่งบนเครื่อง Optimus คือ "เกมไปใช้ iGPU" — แก้ด้วย per-app preference ก่อนเสมอ
2. HAGS + ปิด GameDVR = ของฟรีที่ได้ผลเล็กน้อยแต่ปลอดภัย
3. undervolt เป็น tweak ที่คุ้มที่สุด แต่ต้องทำด้วย Afterburner เอง
4. อย่าใช้ `Prefer maximum performance` ค้างไว้ 24/7
5. 88 W คือเพดานจริงของเครื่องนี้ — ซอฟต์แวร์ไม่สามารถทำให้เกินได้
