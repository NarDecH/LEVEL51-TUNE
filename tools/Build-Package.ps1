<#
.SYNOPSIS
    สร้างไฟล์ zip สำหรับแจกจ่าย LEVEL51-TUNE (ไม่ต้องมี dependency ภายนอก)
.DESCRIPTION
    รวมสคริปต์, engine, docs (md + html) และ tests ไว้ใน dist/LEVEL51-TUNE-<version>.zip
    ผู้รับแตกไฟล์แล้วดับเบิลคลิก Start-LEVEL51.cmd ได้ทันที
    หมายเหตุ: ไม่ได้ทำ code signing / MSIX — ต้องมี certificate ของผู้พัฒนาเอง
.EXAMPLE
    .\tools\Build-Package.ps1
.EXAMPLE
    .\tools\Build-Package.ps1 -OutDir D:\release
#>
[CmdletBinding()]
param([string]$OutDir = 'dist')

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'src\Level51Tune.psm1') -Force -DisableNameChecking
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }

$version = Get-L51Version
$name = "LEVEL51-TUNE-$version"
$outRoot = Join-Path $root $OutDir
$staging = Join-Path $outRoot $name
$zip = Join-Path $outRoot "$name.zip"

if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
New-Item -ItemType Directory -Path $staging -Force | Out-Null

# ไฟล์ระดับบนสุด
foreach ($f in @('Level51Tune.ps1', 'Level51Tune.Web.ps1', 'Level51Tune.Tray.ps1', 'Start-LEVEL51.cmd', 'README.md', 'LICENSE')) {
    $src = Join-Path $root $f
    if (Test-Path $src) { Copy-Item $src -Destination $staging -Force }
}

# โฟลเดอร์ที่ต้องแจกจ่าย
foreach ($dir in @('src', 'tools', 'tests')) {
    $target = Join-Path $staging $dir
    New-Item -ItemType Directory -Path $target -Force | Out-Null
    Get-ChildItem (Join-Path $root $dir) -File | Where-Object { $_.Extension -in @('.ps1', '.psm1') } |
        ForEach-Object { Copy-Item $_.FullName -Destination $target -Force }
}

# เอกสาร md + html + assets
$docsSrc = Join-Path $root 'docs'
$docsDst = Join-Path $staging 'docs'
New-Item -ItemType Directory -Path (Join-Path $docsDst 'assets') -Force | Out-Null
Get-ChildItem $docsSrc -File | Where-Object { $_.Extension -in @('.md', '.html') } |
    ForEach-Object { Copy-Item $_.FullName -Destination $docsDst -Force }
$assetsSrc = Join-Path $docsSrc 'assets'
if (Test-Path $assetsSrc) {
    Get-ChildItem $assetsSrc -File | ForEach-Object { Copy-Item $_.FullName -Destination (Join-Path $docsDst 'assets') -Force }
}

if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path $staging -DestinationPath $zip -CompressionLevel Optimal
Remove-Item $staging -Recurse -Force

$info = Get-Item $zip
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::OpenRead($zip)
$count = $archive.Entries.Count
$archive.Dispose()

Write-Host ''
Write-Host '  สร้างแพ็กเกจเสร็จ' -ForegroundColor Green
Write-Host ('  ไฟล์ : {0}' -f $info.FullName)
Write-Host ('  ขนาด: {0:N0} KB · เวอร์ชัน: {1}' -f ($info.Length / 1KB), $version)
Write-Host '  ผู้รับแตกไฟล์แล้วดับเบิลคลิก Start-LEVEL51.cmd ได้เลย' -ForegroundColor DarkGray
Write-Host '  ยังไม่ได้ code signing — Windows SmartScreen อาจเตือน' -ForegroundColor Yellow
Write-Host ''

return [pscustomobject]@{
    Path    = $info.FullName
    SizeKB  = [math]::Round($info.Length / 1KB, 0)
    Version = $version
    Files   = $count
}
