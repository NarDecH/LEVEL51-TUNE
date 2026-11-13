<#
.SYNOPSIS
    สร้างแพ็กเกจ MSIX ของ LEVEL51-TUNE (ต้องมี Windows SDK: makeappx.exe)
.DESCRIPTION
    แอปนี้เป็นสคริปต์ PowerShell ซึ่ง MSIX ต้องมี .exe เป็น entry point
    สคริปต์นี้จึงคอมไพล์ launcher ขนาดเล็ก (C#) ที่เปิด Web GUI ให้ แล้ว pack
    ทั้งหมดเป็น .msix ด้วย makeappx.exe

    ข้อจำกัดที่ตั้งใจ: MSIX รันใน container จึงไม่สามารถขอ UAC ได้
    launcher จะเปิด dashboard แบบไม่ elevated (ดูสถานะ/กราฟ/audit ได้)
    การ apply/restore ยังต้องรัน Start-LEVEL51.cmd หรือ PowerShell แบบ Administrator
    และ .msix ที่ได้ยัง "ไม่ได้ลงนาม" — ติดตั้งได้หลังลงนามด้วย certificate เท่านั้น
.EXAMPLE
    .\tools\Build-Msix.ps1
.EXAMPLE
    .\tools\Build-Msix.ps1 -Publisher 'CN=My Company' -OutDir D:\out
#>
[CmdletBinding()]
param(
    [string]$OutDir = 'dist',
    [string]$Publisher = 'CN=LEVEL51-TUNE',
    [string]$AppName = 'LEVEL51-TUNE',
    [string]$PackageName = 'NarDecH.LEVEL51TUNE',
    [string]$MakeAppxPath,
    [switch]$Unsigned,
    [string]$PfxPath,
    [string]$PfxPassword,
    [string]$TimestampServer
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'src\Level51Tune.psm1') -Force -DisableNameChecking
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }

$version = Get-L51Version
$msixVersion = "$version.0"

# MSIX ที่ไม่ลงนามต้องมี marker OID นี้ต่อท้าย Publisher เสมอ (ไม่เช่นนั้นจะได้ 0x80073D2C)
$unsignedMarker = 'OID.2.25.311729368913984317654407730594956997722=1'
if ($Unsigned -and $PfxPath) {
    throw 'เลือกอย่างใดอย่างหนึ่ง: -Unsigned (ทดสอบบนเครื่องนี้) หรือ -PfxPath (แจกจ่ายพร้อมลายเซ็น) ไม่ใช้พร้อมกัน'
}
if ($Unsigned -and $Publisher -notlike "*$unsignedMarker*") {
    $Publisher = "$Publisher, $unsignedMarker"
}

function Find-L51MakeAppx {
    param([string]$Hint)

    if ($Hint -and (Test-Path $Hint)) { return $Hint }
    $cmd = Get-Command makeappx.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $kits = @('C:\Program Files (x86)\Windows Kits\10\bin', 'C:\Program Files\Windows Kits\10\bin')
    foreach ($kit in $kits) {
        if (-not (Test-Path $kit)) { continue }
        $found = @(Get-ChildItem $kit -Directory -ErrorAction SilentlyContinue |
                Sort-Object Name -Descending |
                ForEach-Object { Join-Path $_.FullName 'x64\makeappx.exe' } |
                Where-Object { Test-Path $_ })
        if ($found.Count -gt 0) { return $found[0] }
    }
    return $null
}

function Find-L51Csc {
    $candidates = @(
        'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe',
        'C:\Windows\Microsoft.NET\Framework\v4.0.30319\csc.exe'
    )
    foreach ($c in $candidates) { if (Test-Path $c) { return $c } }
    return $null
}

$makeappx = Find-L51MakeAppx -Hint $MakeAppxPath
$csc = Find-L51Csc

if (-not $makeappx) {
    Write-Host ''
    Write-Host '  ไม่พบ makeappx.exe' -ForegroundColor Red
    Write-Host '  ต้องติดตั้ง Windows SDK (Windows App Certification / MSIX Packaging Tools)' -ForegroundColor Yellow
    Write-Host '  หรือระบุ path เอง: .\tools\Build-Msix.ps1 -MakeAppxPath "C:\...\makeappx.exe"' -ForegroundColor DarkGray
    Write-Host '  ทางเลือกที่ไม่ต้องมี SDK: ใช้ dist/*.zip จาก .\tools\Build-Package.ps1' -ForegroundColor DarkGray
    Write-Host ''
    return [pscustomobject]@{ Created = $false; Reason = 'makeappx.exe not found' }
}
if (-not $csc) { throw 'ไม่พบ csc.exe (ต้องมี .NET Framework 4.x สำหรับคอมไพล์ launcher)' }

$outRoot = Join-Path $root $OutDir
$stage = Join-Path $outRoot 'msix-stage'
$suffix = ''
if ($Unsigned) { $suffix = '-unsigned' }
$msixPath = Join-Path $outRoot ('LEVEL51-TUNE-{0}{1}.msix' -f $version, $suffix)

if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Path $stage -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $stage 'Assets') -Force | Out-Null

# ---- ไฟล์แอป (ชุดเดียวกับ Build-Package) ----------------------------------
foreach ($f in @('Level51Tune.ps1', 'Level51Tune.Web.ps1', 'Level51Tune.Tray.ps1', 'Start-LEVEL51.cmd', 'README.md', 'LICENSE')) {
    $src = Join-Path $root $f
    if (Test-Path $src) { Copy-Item $src -Destination $stage -Force }
}
foreach ($dir in @('src', 'tools', 'tests')) {
    $target = Join-Path $stage $dir
    New-Item -ItemType Directory -Path $target -Force | Out-Null
    Get-ChildItem (Join-Path $root $dir) -File | Where-Object { $_.Extension -in @('.ps1', '.psm1') } |
        ForEach-Object { Copy-Item $_.FullName -Destination $target -Force }
}
$docsSrc = Join-Path $root 'docs'
$docsDst = Join-Path $stage 'docs'
New-Item -ItemType Directory -Path (Join-Path $docsDst 'assets') -Force | Out-Null
Get-ChildItem $docsSrc -File | Where-Object { $_.Extension -in @('.md', '.html') } |
    ForEach-Object { Copy-Item $_.FullName -Destination $docsDst -Force }
if (Test-Path (Join-Path $docsSrc 'assets')) {
    Get-ChildItem (Join-Path $docsSrc 'assets') -File | ForEach-Object { Copy-Item $_.FullName -Destination (Join-Path $docsDst 'assets') -Force }
}

# ---- launcher (.exe) ------------------------------------------------------
$launcherSrc = Join-Path $outRoot 'Level51Tune.Launcher.cs'
$launcherExe = Join-Path $stage 'LEVEL51Tune.Launcher.exe'

$cs = @'
using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;

internal static class Program
{
    [STAThread]
    private static void Main()
    {
        string dir = AppDomain.CurrentDomain.BaseDirectory;
        string script = Path.Combine(dir, "Level51Tune.Web.ps1");
        if (!File.Exists(script))
        {
            MessageBox.Show("ไม่พบ Level51Tune.Web.ps1 ใน " + dir, "LEVEL51-TUNE", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return;
        }
        var psi = new ProcessStartInfo("powershell.exe",
            "-NoProfile -ExecutionPolicy Bypass -File \"" + script + "\"")
        {
            UseShellExecute = true,
            WorkingDirectory = dir
        };
        try { Process.Start(psi); }
        catch (Exception ex)
        {
            MessageBox.Show(ex.Message, "LEVEL51-TUNE", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }
}
'@
# ต้องมี BOM เพื่อให้ csc อ่านข้อความไทยในไฟล์ .cs เป็น UTF-8
[IO.File]::WriteAllText($launcherSrc, $cs, (New-Object System.Text.UTF8Encoding($true)))

$cscArgs = @('/nologo', '/target:winexe', '/platform:anycpu', "/out:$launcherExe", '/reference:System.Windows.Forms.dll', $launcherSrc)
$cscOut = & $csc $cscArgs 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host ($cscOut | Out-String) -ForegroundColor Red
    throw 'คอมไพล์ launcher ไม่สำเร็จ'
}

# ---- assets (PNG) ---------------------------------------------------------
Add-Type -AssemblyName System.Drawing
function New-L51Logo {
    param([int]$Size, [string]$Path)

    $bmp = New-Object System.Drawing.Bitmap($Size, $Size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::FromArgb(13, 17, 23))
    $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(76, 194, 160))
    $fontSize = [single]([math]::Max(8, $Size / 3.2))
    $font = New-Object System.Drawing.Font('Segoe UI', $fontSize, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    $fmt = New-Object System.Drawing.StringFormat
    $fmt.Alignment = [System.Drawing.StringAlignment]::Center
    $fmt.LineAlignment = [System.Drawing.StringAlignment]::Center
    $rect = New-Object System.Drawing.RectangleF(0, 0, $Size, $Size)
    $g.DrawString('L51', $font, $brush, $rect, $fmt)
    $g.Dispose()
    $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}

$assets = Join-Path $stage 'Assets'
New-L51Logo -Size 44 -Path (Join-Path $assets 'Square44x44Logo.png')
New-L51Logo -Size 150 -Path (Join-Path $assets 'Square150x150Logo.png')
New-L51Logo -Size 50 -Path (Join-Path $assets 'StoreLogo.png')

# ---- AppxManifest ---------------------------------------------------------
$manifest = @'
<?xml version="1.0" encoding="utf-8"?>
<Package xmlns="http://schemas.microsoft.com/appx/manifest/foundation/windows10"
         xmlns:uap="http://schemas.microsoft.com/appx/manifest/uap/windows10"
         xmlns:rescap="http://schemas.microsoft.com/appx/manifest/foundation/windows10/restrictedcapabilities"
         IgnorableNamespaces="uap rescap">
  <Identity Name="__PKGNAME__" Publisher="__PUBLISHER__" Version="__VERSION__" ProcessorArchitecture="x64" />
  <Properties>
    <DisplayName>__APPNAME__</DisplayName>
    <PublisherDisplayName>NarDecH</PublisherDisplayName>
    <Logo>Assets\StoreLogo.png</Logo>
  </Properties>
  <Dependencies>
    <TargetDeviceFamily Name="Windows.Desktop" MinVersion="10.0.19041.0" MaxVersionTested="10.0.26100.0" />
  </Dependencies>
  <Resources>
    <Resource Language="th-TH" />
    <Resource Language="en-US" />
  </Resources>
  <Applications>
    <Application Id="App" Executable="LEVEL51Tune.Launcher.exe" EntryPoint="Windows.FullTrustApplication">
      <uap:VisualElements DisplayName="__APPNAME__"
                          Description="ชุดเครื่องมือจูนประสิทธิภาพ LEVEL51 (dashboard)"
                          BackgroundColor="transparent"
                          Square150x150Logo="Assets\Square150x150Logo.png"
                          Square44x44Logo="Assets\Square44x44Logo.png" />
    </Application>
  </Applications>
  <Capabilities>
    <rescap:Capability Name="runFullTrust" />
    <Capability Name="internetClient" />
  </Capabilities>
</Package>
'@
$manifest = $manifest.Replace('__PKGNAME__', $PackageName).Replace('__PUBLISHER__', $Publisher)
$manifest = $manifest.Replace('__VERSION__', $msixVersion).Replace('__APPNAME__', $AppName)
[IO.File]::WriteAllText((Join-Path $stage 'AppxManifest.xml'), $manifest, (New-Object System.Text.UTF8Encoding($false)))

if (Test-Path $msixPath) { Remove-Item $msixPath -Force }
$packOut = & $makeappx pack /d $stage /p $msixPath /o 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host ($packOut | Out-String) -ForegroundColor Red
    throw 'makeappx pack ไม่สำเร็จ'
}

# ---- ลงนามด้วย PFX (ถ้าผู้ใช้ระบุ) ----------------------------------------
$signed = $false
if ($PfxPath) {
    $signtool = Join-Path (Split-Path -Parent $makeappx) 'signtool.exe'
    if (-not (Test-Path $signtool)) { throw 'ไม่พบ signtool.exe ข้าง ๆ makeappx.exe' }
    if (-not (Test-Path $PfxPath)) { throw "ไม่พบไฟล์ PFX: $PfxPath" }
    # ไม่ประทับเวลาโดยปริยาย: invariant 13 อนุญาตให้แตะเน็ตเฉพาะเมื่อผู้ใช้ระบุชัดเจน
    $signArgs = @('sign', '/fd', 'SHA256', '/f', (Resolve-Path $PfxPath).Path)
    if ($PfxPassword) { $signArgs += @('/p', $PfxPassword) }
    if ($TimestampServer) { $signArgs += @('/tr', $TimestampServer, '/td', 'SHA256') }
    $signArgs += @($msixPath)
    $signOut = & $signtool @signArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host ($signOut | Out-String) -ForegroundColor Red
        throw 'signtool sign ไม่สำเร็จ'
    }
    $signed = $true
}

$info = Get-Item $msixPath
Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ''
Write-Host '  สร้าง MSIX เสร็จ' -ForegroundColor Green
Write-Host ('  ไฟล์  : {0}' -f $info.FullName)
Write-Host ('  ขนาด : {0:N0} KB · เวอร์ชัน {1} · Publisher {2}' -f ($info.Length / 1KB), $msixVersion, $Publisher)
Write-Host '  launcher เปิด dashboard แบบไม่ elevated — apply/restore ใช้ Start-LEVEL51.cmd' -ForegroundColor DarkGray
if ($signed) {
    Write-Host '  ลงนามแล้วด้วย PFX ที่ระบุ — ติดตั้งได้เมื่อ cert อยู่ใน TrustedPeople ของเครื่อง' -ForegroundColor Green
    if ($TimestampServer) {
        Write-Host ('  ประทับเวลาที่ {0}' -f $TimestampServer) -ForegroundColor DarkGray
    } else {
        Write-Host '  ไม่มีการประทับเวลา (timestamp) — ใช้ภายในเครื่องเท่านั้น' -ForegroundColor DarkGray
    }
} elseif ($Unsigned) {
    Write-Host '  แพ็กเกจ unsigned (มี marker OID ใน Publisher) — ติดตั้งด้วย:' -ForegroundColor Yellow
    Write-Host ('    Add-AppxPackage -Path "{0}" -AllowUnsigned' -f $info.FullName) -ForegroundColor DarkGray
    Write-Host '  ต้องรันใน PowerShell แบบ Administrator เพราะแพ็กเกจมี .exe' -ForegroundColor DarkGray
} else {
    Write-Host '  ยังไม่ได้ลงนาม: ติดตั้งได้หลังลงนามด้วย cert ที่ Publisher ตรงกัน' -ForegroundColor Yellow
    Write-Host '  สำหรับทดสอบบนเครื่องนี้เร็ว ๆ ใช้ .\tools\Build-Msix.ps1 -Unsigned' -ForegroundColor DarkGray
}
Write-Host ''

return [pscustomobject]@{
    Created   = $true
    Path      = $info.FullName
    SizeKB    = [math]::Round($info.Length / 1KB, 0)
    Version   = $msixVersion
    Publisher = $Publisher
    Signed    = $signed
    Unsigned  = [bool]$Unsigned
}
