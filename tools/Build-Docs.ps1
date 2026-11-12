<#
.SYNOPSIS
    สร้าง docs/*.html จาก docs/*.md (ไม่ต้องติดตั้งอะไรเพิ่ม)
.EXAMPLE
    .\tools\Build-Docs.ps1
.EXAMPLE
    .\tools\Build-Docs.ps1 -Open
#>
[CmdletBinding()]
param([switch]$Open)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'src\Level51Tune.psm1') -Force -DisableNameChecking

$result = Build-L51Docs
Write-Host ("[+] สร้าง {0} หน้า + index.html" -f $result.Written) -ForegroundColor Green
Write-Host ("    {0}" -f $result.Index) -ForegroundColor DarkGray
if ($Open) { Start-Process $result.Index }
