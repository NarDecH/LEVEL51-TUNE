<#
.SYNOPSIS
    สร้าง self-signed code signing certificate สำหรับลงนาม MSIX ของ LEVEL51-TUNE (ฟรี ไม่ต้องซื้อ cert)
.DESCRIPTION
    สร้าง certificate ใน CurrentUser\My แล้ว export เป็น
      - <OutDir>\l51-signing.pfx  (private key — ห้ามแชร์ ห้าม commit)
      - <OutDir>\l51-signing.cer  (public key — แจกให้เครื่องปลายทางติดตั้ง)

    ผู้รับปลายทางต้องติดตั้ง .cer เข้า TrustedPeople ก่อน แพ็กเกจที่ลงนามด้วย cert นี้
    จึงติดตั้งได้ (ต่างจาก cert จาก CA ที่ Windows เชื่อถืออยู่แล้ว)

    ข้อจำกัด: cert นี้ไม่ถูก Windows เชื่อถือโดยปริยาย และไม่ช่วยเรื่อง SmartScreen
    เหมาะกับการแจกจ่ายให้ตัวเอง/ทีมที่ติดตั้ง cert ได้ ไม่ใช่แจกสาธารณะ
.EXAMPLE
    .\tools\New-SigningCert.ps1
.EXAMPLE
    .\tools\New-SigningCert.ps1 -Subject 'CN=My Studio' -Years 2
#>
[CmdletBinding()]
param(
    [string]$Subject = 'CN=LEVEL51-TUNE',
    [string]$OutDir = 'cert',
    [int]$Years = 3,
    [string]$Password
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }
$root = Split-Path -Parent $PSScriptRoot

if ($Years -lt 1 -or $Years -gt 10) { throw '-Years ต้องอยู่ระหว่าง 1 ถึง 10' }

$outPath = Join-Path $root $OutDir
if (-not (Test-Path $outPath)) { New-Item -ItemType Directory -Path $outPath -Force | Out-Null }

$pfxPath = Join-Path $outPath 'l51-signing.pfx'
$cerPath = Join-Path $outPath 'l51-signing.cer'
$pwPath = Join-Path $outPath 'pfx-password.txt'

$plain = $Password
if (-not $plain) {
    $bytes = New-Object byte[] 24
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $rng.GetBytes($bytes)
    $rng.Dispose()
    $plain = [Convert]::ToBase64String($bytes)
}

$secure = ConvertTo-SecureString -String $plain -AsPlainText -Force

$cert = New-SelfSignedCertificate -Type CodeSigningCert `
    -Subject $Subject `
    -KeyUsage DigitalSignature `
    -FriendlyName 'LEVEL51-TUNE signing' `
    -CertStoreLocation 'Cert:\CurrentUser\My' `
    -NotAfter (Get-Date).AddYears($Years) `
    -TextExtension @('2.5.29.37={text}1.3.6.1.5.5.7.3.3')

Export-PfxCertificate -Cert $cert -FilePath $pfxPath -Password $secure | Out-Null
Export-Certificate -Cert $cert -FilePath $cerPath -Type CERT | Out-Null
if (-not $Password) { [IO.File]::WriteAllText($pwPath, $plain) }

$thumb = $cert.Thumbprint

Write-Host ''
Write-Host '  สร้าง certificate สำหรับลงนามแล้ว' -ForegroundColor Green
Write-Host ('  Subject : {0}' -f $Subject)
Write-Host ('  Thumb   : {0}' -f $thumb)
Write-Host ('  PFX     : {0}' -f $pfxPath)
Write-Host ('  CER     : {0}' -f $cerPath)
if (-not $Password) {
    Write-Host ('  รหัส PFX: {0}' -f $pwPath) -ForegroundColor Yellow
    Write-Host '  (เก็บไฟล์นี้เป็นความลับ — อยู่ใน cert/ ซึ่งถูก ignore แล้ว)' -ForegroundColor DarkGray
}
Write-Host ''
Write-Host '  ขั้นต่อไป — ลงนามแพ็กเกจ:' -ForegroundColor Cyan
Write-Host '    .\tools\Build-Msix.ps1 -PfxPath .\cert\l51-signing.pfx -PfxPassword (รหัสจากไฟล์) -TimestampServer http://timestamp.digicert.com'
Write-Host ''
Write-Host '  เครื่องปลายทาง — เชื่อถือ cert ก่อนติดตั้ง (Administrator):' -ForegroundColor Cyan
Write-Host '    Import-Certificate -FilePath .\cert\l51-signing.cer -CertStoreLocation Cert:\LocalMachine\TrustedPeople'
Write-Host '    Add-AppxPackage -Path .\dist\LEVEL51-TUNE-<version>.msix'
Write-Host ''
Write-Host '  หมายเหตุ: cert ประเภทนี้ Windows ไม่ได้เชื่อถือโดยปริยาย และไม่ช่วยเรื่อง SmartScreen' -ForegroundColor DarkGray
Write-Host ''

return [pscustomobject]@{
    Subject    = $Subject
    Thumbprint = $thumb
    PfxPath    = $pfxPath
    CerPath    = $cerPath
    PasswordFile = $pwPath
    NotAfter   = $cert.NotAfter
}
