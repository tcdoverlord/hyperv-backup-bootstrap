# =========================================================
# HV-LazyBackup Bootstrap Installer (ANGEL v5 - FINAL)
# =========================================================

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "🔵 HV-LazyBackup Bootstrap ANGEL v5" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# -----------------------------------------
# INSTALL LOCATION (USER SELECTABLE)
# -----------------------------------------
Write-Host ""
Write-Host "📦 INSTALL LOCATION SETUP" -ForegroundColor Yellow

$defaultInstall = "C:\HV-LazyBackup"
$installRoot = Read-Host "Enter install path (ENTER for default: C:\HV-LazyBackup)"

if ([string]::IsNullOrWhiteSpace($installRoot)) {
    $installRoot = $defaultInstall
}

# safety check
if ($installRoot -match "System32|Windows\\System32") {
    Write-Host "❌ INVALID INSTALL LOCATION" -ForegroundColor Red
    exit
}

$configPath  = "$installRoot\config.json"
$scriptPath  = "$installRoot\scripts"
$logPath     = "$installRoot\logs"

Write-Host "📍 Installing to: $installRoot" -ForegroundColor Green

# -----------------------------------------
# CREATE CORE STRUCTURE
# -----------------------------------------
New-Item -ItemType Directory -Force -Path $installRoot | Out-Null
New-Item -ItemType Directory -Force -Path $scriptPath  | Out-Null
New-Item -ItemType Directory -Force -Path $logPath     | Out-Null

# -----------------------------------------
# SELECT VM
# -----------------------------------------
Write-Host ""
Write-Host "🖥️ AVAILABLE VMs:" -ForegroundColor Yellow
Get-VM | Select Name, State

Write-Host ""
$vmName = Read-Host "Enter VM name (ENTER = first VM)"

if ([string]::IsNullOrWhiteSpace($vmName)) {
    $vmName = (Get-VM | Select-Object -First 1).Name
}

$vm = Get-VM -Name $vmName -ErrorAction SilentlyContinue
if (-not $vm) {
    Write-Host "❌ VM NOT FOUND" -ForegroundColor Red
    exit
}

Write-Host "✅ VM Selected: $vmName" -ForegroundColor Green

# -----------------------------------------
# SELECT BACKUP DRIVE
# -----------------------------------------
Write-Host ""
Write-Host "📦 AVAILABLE DRIVES:" -ForegroundColor Yellow
Get-PSDrive -PSProvider FileSystem | ForEach-Object {
    Write-Host "$($_.Name): $($_.Root)"
}

Write-Host ""
$drive = (Read-Host "Select backup drive letter (e.g. G)").Trim().ToUpper()

if ($drive -eq "C") {
    Write-Host "❌ C: DRIVE NOT ALLOWED" -ForegroundColor Red
    exit
}

if (-not (Test-Path "$drive`:\")) {
    Write-Host "❌ DRIVE NOT FOUND" -ForegroundColor Red
    exit
}

$backupRoot = "$drive`:\VM_MASTER_BACKUP"
New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null

# -----------------------------------------
# CONFIG
# -----------------------------------------
$config = @{
    SystemName = "HV-LazyBackup"
    Version    = "ANGEL-5.0"
    VMName     = $vmName
    BackupPath = $backupRoot
    InstallPath = $installRoot
    Created    = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$config | ConvertTo-Json -Depth 10 | Out-File $configPath -Encoding UTF8

# -----------------------------------------
# BACKUP SCRIPT
# -----------------------------------------
@"
`$config = Get-Content "$configPath" | ConvertFrom-Json

`$vm = `$config.VMName
`$dest = Join-Path `$config.BackupPath "`$vm-MASTER-`$(Get-Date -Format yyyy-MM-dd_HH-mm)"

Write-Host "🚀 Checking VM state..." -ForegroundColor Cyan

`$state = (Get-VM -Name `$vm).State
if (`$state -ne "Off") {
    Write-Host "⚠️ VM running - shutting down safely..." -ForegroundColor Yellow
    Stop-VM -Name `$vm -TurnOff -Force
    Start-Sleep -Seconds 5
}

Write-Host "🚀 Exporting VM..." -ForegroundColor Cyan
Export-VM -Name `$vm -Path `$dest

Write-Host "✅ BACKUP COMPLETE: `$dest" -ForegroundColor Green
"@ | Out-File "$scriptPath\Backup-VM.ps1" -Encoding UTF8

# -----------------------------------------
# VERIFY SCRIPT
# -----------------------------------------
@"
`$config = Get-Content "$configPath" | ConvertFrom-Json

`$vhdx = Get-ChildItem -Path `$config.BackupPath -Recurse -Filter *.vhdx -ErrorAction SilentlyContinue

Write-Host "--------------------------------"

if (`$vhdx) {
    Write-Host "✅ BACKUP VALID" -ForegroundColor Green
    Write-Host "📦 VHDX: `$(`$vhdx.FullName)"
} else {
    Write-Host "❌ BACKUP FAILED" -ForegroundColor Red
}

Write-Host "--------------------------------"
"@ | Out-File "$scriptPath\Verify-Backup.ps1" -Encoding UTF8

# -----------------------------------------
# COMPLETE
# -----------------------------------------
Write-Host ""
Write-Host "🧠 INSTALL COMPLETE" -ForegroundColor Green
Write-Host "📍 INSTALL: $installRoot"
Write-Host "📍 BACKUP:  $backupRoot"
Write-Host ""
Write-Host "▶ Run Backup-VM.ps1"
Write-Host "▶ Run Verify-Backup.ps1"
Write-Host ""
Write-Host "🔵 ANGEL v5 READY" -ForegroundColor Cyan
