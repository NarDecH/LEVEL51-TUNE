# เครือข่ายและ latency

## ฮาร์ดแวร์เครือข่ายในเครื่องนี้

```
Network Card(s): 3
 [01] Intel(R) Wireless-AC 9260 160MHz   (Wi-Fi)
```

| อุปกรณ์ | สเปก |
|---|---|
| Intel Wireless-AC 9260 | Wi-Fi 5 (802.11ac) 2x2, 160 MHz, Bluetooth 5.0, เพดาน ~1.73 Gbps |
| Gigabit Ethernet | ตามรุ่น barebone (มักเป็น Intel I219-V หรือ Realtek) |

ตรวจสถานะจริง:

```powershell
Get-NetAdapter | Select-Object Name, InterfaceDescription, Status, LinkSpeed, MacAddress
Get-NetAdapterStatistics | Select-Object Name, ReceivedBytes, SentBytes, ReceivedPacketsDiscarded
```

## stack เครือข่ายของ Windows — จุดที่ปรับได้

### 1. Receive Window Auto-Tuning

Windows ปรับ receive window ขนาดอัตโนมัติตาม latency และ throughput:

```powershell
netsh int tcp show global
```

| ค่า | แนะนำ | เหตุผล |
|---|---|---|
| Receive Window Auto-Tuning Level | `normal` | `disabled` ทำให้ throughput ตกบนเน็ตความเร็วสูง; `restricted` ช่วยเฉพาะเครื่องที่ router เก่า |
| Add-On Congestion Control Provider | `default` (CUBIC บน Win11) | อย่าเปลี่ยนเป็น `ctcp` โดยไม่มีเหตุ |
| ECN Capability | `disabled` | router จำนวนมากมีปัญหา ECN — ปิดเพื่อความเสถียร |
| RFC 1323 Timestamps | `disabled` | ลด overhead ต่อแพ็กเก็ต |
| Receive-Side Scaling (RSS) | `enabled` | กระจาย interrupt หลายคอร์ |
| NetDMA | `enabled` (ถ้ามี) | — |
| Initial RTO / Min RTO | ค่า default | อย่าแตะ |

tweak `net.tcp-global` ตั้ง 4 ค่าแรกให้ตามตารางนี้

### 2. NetworkThrottlingIndex

`HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\NetworkThrottlingIndex`

Windows จำกัดแพ็กเก็ตของงาน multimedia ที่ ~10 แพ็กเก็ต/ms (ค่า 10) เพื่อไม่ให้ audio/video ถูกแย่ง bandwidth ค่า `0xFFFFFFFF` = ปิดการจำกัด

**ผลจริง**: ในเกมที่มี packet rate สูง (>10,000 pps) การปิดช่วยลด ping spike ได้ แต่ในเน็ตบ้านทั่วไปผลน้อยมาก — เป็น tweak ที่ปลอดภัยและต้นทุนต่ำ จึงอยู่ใน `balanced` ด้วย

### 3. Nagle Algorithm และ Delayed ACK

สองกลไกที่ทำงานคู่กันและเพิ่ม latency:

| กลไก | ทำอะไร | ผลข้างเคียง |
|---|---|---|
| Nagle | รวมแพ็กเก็ตเล็กที่ยังไม่ได้รับ ACK | เพิ่มดีเลย์ได้ถึง 200 ms ในงาน interactive |
| Delayed ACK | ชะลอ ACK สูงสุด 200 ms | ทำงานร่วมกับ Nagle ทำให้แย่ลง |

ตั้งค่าปิด (tweak `net.nagle-off`):

```
HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\<GUID>
  TcpAckFrequency = 1     (DWord)
  TCPNoDelay      = 1     (DWord)
```

ผล: เกมออนไลน์/Remote Desktop/SSH ตอบสนองไวขึ้นชัดเจน (ใน Valorant/CS2 วัดได้ 3-15 ms) แบนด์วิดท์ใช้เพิ่มขึ้นเล็กน้อยเพราะแพ็กเก็ตเล็กถูกส่งแยก

**ต้อง reboot** และต้องตั้งในทุก interface GUID (โปรแกรมวนให้ทุกตัว รวมVPN adapters)

### 4. MMCSS (Multimedia Class Scheduler Service)

MMCSS ให้ priority พิเศษกับ thread ที่ลงทะเบียนเป็น "Games", "Audio", "Playback"

```
HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile
  SystemResponsiveness = 10        (default 20)
  NetworkThrottlingIndex = 0xFFFFFFFF
  Tasks\Games
    GPU Priority       = 8         (default 8)
    Priority           = 6         (default 2)
    Scheduling Category = High     (default Medium)
    SFIO Priority      = High      (default Normal)
```

tweak `net.mmcss-games` ตั้งค่าทั้งชุดนี้ ค่า `Priority=6` + `Scheduling Category=High` ทำให้ thread ของเกมได้ time slice จาก scheduler ก่อนงานทั่วไป

### 5. QoS และ DSCP tagging

ถ้าเกม/โปรแกรมรองรับ DSCP (เช่น VoiceMeeter, SQM tools) Windows จะ tag แพ็กเก็ตด้วยค่า 0 โดย default และ **รีเซ็ตค่า DSCP ที่โปรแกรมตั้ง**

```powershell
# เปิดให้โปรแกรมตั้ง DSCP ได้
New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters' `
  -Name 'DisableUserTOSSetting' -Value 0 -PropertyType DWord -Force
```

หรือใช้ Group Policy: `Computer Configuration → Administrative Templates → Network → QoS Packet Scheduler → Limit reservable bandwidth` = 0 (ค่าตำนานที่จริง ๆ แล้ว Windows ไม่เคยกัน 20% จริง การตั้งค่านี้จึงแทบไม่มีผล — แต่ไม่ harm)

router ที่รองรับ SQM/fq_codel มีผลต่อ latency มากกว่าการตั้งค่า Windows ทั้งหมดรวมกัน

## Wi-Fi 9260 — จุดที่มักเป็นคอขวดจริง

| ปัญหา | อาการ | วิธีแก้ |
|---|---|---|
| คลื่น 2.4 GHz แออัด | ping แกว่ง 20-200 ms | ใช้ 5 GHz ให้ได้ |
| กำลังส่งลดลงเพราะประหยัดไฟ | throughput ตกเป็นช่วง | Device Manager → adapter → Power Management → ปิด "Allow the computer to turn off this device" |
| Roaming ระหว่าง AP | ขาดการเชื่อมต่อชั่วขณะ | ตั้ง roaming aggressiveness ต่ำลง |
| ไดรเวอร์เก่า | ping spike, หลุด | อัปเดตไดรเวอร์ Intel PROSet |
| 160 MHz ไม่เสถียร | หลุดบ่อย | ตั้ง channel width เป็น 80 MHz |

ตั้งค่า adapter ด้วย PowerShell:

```powershell
Get-NetAdapterAdvancedProperty -Name 'Wi-Fi' |
  Select-Object DisplayName, DisplayValue, RegistryKeyword
```

ปิดการประหยัดไฟของ adapter:

```powershell
$wifi = Get-NetAdapter -Name 'Wi-Fi'
Disable-NetAdapterPowerManagement -Name $wifi.Name -ErrorAction SilentlyContinue
```

## tweaks ของโปรเจกต์ที่เกี่ยวกับเครือข่าย

| Tweak | โปรไฟล์ | ต้อง reboot | ผล |
|---|---|---|---|
| `net.throttling-off` | balanced, gaming, max | ใช่ | ปิดการจำกัดแพ็กเก็ต multimedia |
| `net.mmcss-responsiveness` | gaming, max | ใช่ | สำรอง CPU ให้พื้นหลังน้อยลง |
| `net.mmcss-games` | gaming, max | ใช่ | priority สูงสำหรับ thread เกม |
| `net.nagle-off` | gaming, max | ใช่ | ลดดีเลย์แพ็กเก็ตเล็ก |
| `net.tcp-global` | performance, gaming, max | ใช่ | stack พารามิเตอร์มาตรฐาน |

## การวัด latency อย่างถูกวิธี

| เครื่องมือ | วัดอะไร | วิธีใช้ |
|---|---|---|
| `ping -t 1.1.1.1` | RTT ต่อ router/เน็ต | ดู jitter (ค่าเบี่ยงเบน) ไม่ใช่ค่าเฉลี่ย |
| `pathping 1.1.1.1` | packet loss ต่อ hop | หาว่าต้นเหตุอยู่ที่ router หรือ ISP |
| LatencyMon | DPC/ISR ของไดรเวอร์ | ใช้หา latency ที่ไม่เกี่ยวกับเน็ต |
| PingPlotter | กราฟ RTT ต่อเนื่อง | ดู packet loss เป็นช่วง ๆ |
| เกม in-game netgraph | ping/jitter จริง | ตัวชี้วัดที่มีความหมายที่สุด |

คำสั่ง PowerShell วัด jitter แบบง่าย:

```powershell
$r = 1..50 | ForEach-Object {
  (Test-Connection 1.1.1.1 -Count 1).ResponseTime
}
"min={0} max={1} avg={2} jitter={3}" -f ($r | Measure-Object -Minimum).Minimum,
  ($r | Measure-Object -Maximum).Maximum,
  [math]::Round(($r | Measure-Object -Average).Average,1),
  [math]::Round((($r | Measure-Object -Maximum).Maximum - ($r | Measure-Object -Minimum).Minimum),1)
```

jitter ที่ดีคือ < 5 ms บน LAN, < 15 ms บนเน็ตบ้าน

## DNS — ตัวที่คนมองข้าม

DNS ไม่กระทบ ping ในเกม แต่กระทบ "เวลาเปิดเว็บ/เข้าเกมครั้งแรก"

```powershell
Get-DnsClientServerAddress -AddressFamily IPv4 | Select-Object InterfaceAlias, ServerAddresses
Resolve-DnsName www.google.com | Select-Object Name, IPAddress, QueryType
```

| ตัวเลือก | ข้อดี | ข้อเสีย |
|---|---|---|
| DNS ผู้ให้บริการ | เร็วที่สุดในประเทศ มักมี CDN ในเครือข่ายเดียวกัน | อาจมี tracking |
| 1.1.1.1 (Cloudflare) | เร็ว, เป็นส่วนตัว | บางครั้งช้ากว่า CDN ในประเทศ |
| 8.8.8.8 (Google) | เสถียร | อาจถูก route ไกล |

**ไม่ได้อยู่ในเครื่องมือนี้** เพราะเป็นการเลือกของผู้ใช้ ไม่ใช่การจูนประสิทธิภาพ — เปลี่ยนเองได้ใน Settings → Network → DNS

## สรุป

1. Wi-Fi 5 บน 5 GHz คือทางเลือกที่ดีที่สุดสำหรับเครื่องนี้ — สาย LAN ดีกว่าถ้าเป็นไปได้
2. Nagle + Delayed ACK เป็นสาเหตุ latency ที่แก้ได้จริงและวัดผลได้
3. NetworkThrottlingIndex และ MMCSS เป็น tweak ปลอดภัย ต้นทุนต่ำ
4. autotuning/ECN/timestamps ควรอยู่ที่ค่ามาตรฐาน — อย่าไปยุ่งถ้าไม่มีปัญหา
5. router (SQM, bufferbloat) มีผลมากกว่าการตั้งค่า Windows ทั้งหมด
