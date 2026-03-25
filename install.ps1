#Requires -Version 7.0
<#
.SYNOPSIS
    Installs the powershell-configuration setup on a fresh Windows machine.

.PARAMETER SkipPackages
    Skip WinGet package installation.

.PARAMETER SkipFonts
    Skip 0xProto Nerd Font installation.

.PARAMETER SkipProfiles
    Skip PowerShell profile installation.

.PARAMETER SkipWindowsTerminal
    Skip Windows Terminal settings installation.
#>
[CmdletBinding()]
param(
    [switch]$SkipPackages,
    [switch]$SkipFonts,
    [switch]$SkipProfiles,
    [switch]$SkipWindowsTerminal
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function Write-Step([string]$message) {
    Write-Host ""
    Write-Host "--- $message ---" -ForegroundColor Cyan
}

function Backup-IfExists([string]$path) {
    if (Test-Path $path) {
        $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $backup = "$path.bak.$timestamp"
        Copy-Item -Path $path -Destination $backup
        Write-Host "  Backed up: $path -> $backup" -ForegroundColor DarkYellow
    }
}

function Test-CommandExists([string]$name) {
    return $null -ne (Get-Command $name -ErrorAction SilentlyContinue)
}

function Install-FontFile([string]$fontPath) {
    $fontName = [System.IO.Path]::GetFileNameWithoutExtension($fontPath)
    $destination = "C:\Windows\Fonts\$([System.IO.Path]::GetFileName($fontPath))"
    Copy-Item -Path $fontPath -Destination $destination -Force
    $regPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
    Set-ItemProperty -Path $regPath -Name "$fontName (TrueType)" -Value ([System.IO.Path]::GetFileName($fontPath))
    Write-Host "  Installed font: $fontName" -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# Platform check
# ---------------------------------------------------------------------------

if (-not $IsWindows -and $PSVersionTable.PSVersion.Major -ge 6) {
    Write-Error "This script is for Windows only."
    exit 1
}

$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

Write-Host ""
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "  powershell-configuration installer" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host ""
if (-not $IsAdmin) {
    Write-Host "  Running without admin rights." -ForegroundColor Yellow
    Write-Host "  Font installation will be skipped. Re-run as Administrator to install fonts." -ForegroundColor Yellow
}

$summary = @()

# ---------------------------------------------------------------------------
# Step 1: WinGet packages
# ---------------------------------------------------------------------------

if (-not $SkipPackages) {
    Write-Step "1/5 - Installing WinGet packages"

    if (-not (Test-CommandExists 'winget')) {
        Write-Host "  WinGet not found. Install 'App Installer' from the Microsoft Store, then re-run." -ForegroundColor Red
        exit 1
    }

    $packagesFile = Join-Path $PSScriptRoot "winget\packages.json"
    if (-not (Test-Path $packagesFile)) {
        Write-Host "  winget\packages.json not found." -ForegroundColor Red
        exit 1
    }

    winget import --import-file $packagesFile --ignore-unavailable --accept-package-agreements --accept-source-agreements
    $summary += "Packages: installed"
} else {
    $summary += "Packages: skipped"
}

# ---------------------------------------------------------------------------
# Step 2: 0xProto Nerd Font
# ---------------------------------------------------------------------------

if (-not $SkipFonts) {
    Write-Step "2/5 - Installing 0xProto Nerd Font"

    if (-not $IsAdmin) {
        Write-Host "  Skipping — admin rights required for font installation." -ForegroundColor Yellow
        $summary += "Fonts: skipped (not admin)"
    } else {
        $regPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
        $existingFont = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue |
            ForEach-Object { $_.PSObject.Properties } |
            Where-Object { $_.Name -like '0xProto*' } |
            Select-Object -First 1

        if ($existingFont) {
            Write-Host "  0xProto Nerd Font already installed. Skipping download." -ForegroundColor Green
            $summary += "Fonts: already installed"
        } else {
            $tempDir = "$env:TEMP\powershell-configuration-fonts"
            $zipPath = "$tempDir\0xProto.zip"
            $extractDir = "$tempDir\0xProto"

            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
            Write-Host "  Downloading 0xProto Nerd Font..."
            Invoke-WebRequest -Uri 'https://github.com/ryanoasis/nerd-fonts/releases/latest/download/0xProto.zip' -OutFile $zipPath -UseBasicParsing

            Write-Host "  Extracting..."
            Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force

            Get-ChildItem -Path $extractDir -Filter '*.ttf' | ForEach-Object {
                Install-FontFile $_.FullName
            }

            Remove-Item -Path $tempDir -Recurse -Force
            Write-Host "  Fonts installed. You may need to restart Windows Terminal for the font to appear." -ForegroundColor Green
            $summary += "Fonts: installed"
        }
    }
} else {
    $summary += "Fonts: skipped"
}

# ---------------------------------------------------------------------------
# Step 3: PowerShell profiles
# ---------------------------------------------------------------------------

if (-not $SkipProfiles) {
    Write-Step "3/5 - Installing PowerShell profiles"

    # PS7 profile directory (respects OneDrive folder redirect)
    $ps7Dir = Split-Path $PROFILE
    New-Item -ItemType Directory -Path $ps7Dir -Force | Out-Null
    $ps7Dest = Join-Path $ps7Dir 'Microsoft.PowerShell_profile.ps1'
    Backup-IfExists $ps7Dest
    Copy-Item -Path (Join-Path $PSScriptRoot 'config\powershell\Microsoft.PowerShell_profile.ps1') -Destination $ps7Dest -Force
    Write-Host "  Profile -> $ps7Dest" -ForegroundColor Green

    $summary += "Profiles: installed"
} else {
    $summary += "Profiles: skipped"
}

# ---------------------------------------------------------------------------
# Step 4: Starship config
# ---------------------------------------------------------------------------

if (-not $SkipProfiles) {
    Write-Step "4/5 - Installing Starship config"

    $starshipDir = Join-Path $env:USERPROFILE '.config'
    New-Item -ItemType Directory -Path $starshipDir -Force | Out-Null
    $starshipDest = Join-Path $starshipDir 'starship.toml'
    Backup-IfExists $starshipDest
    Copy-Item -Path (Join-Path $PSScriptRoot 'config\starship\starship.toml') -Destination $starshipDest -Force
    Write-Host "  Starship config -> $starshipDest" -ForegroundColor Green
    $summary += "Starship config: installed"
} else {
    $summary += "Starship config: skipped"
}

# ---------------------------------------------------------------------------
# Step 5: Windows Terminal settings
# ---------------------------------------------------------------------------

if (-not $SkipWindowsTerminal) {
    Write-Step "5/5 - Installing Windows Terminal settings"

    $wtDir = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"

    if (-not (Test-Path $wtDir)) {
        Write-Host "  Windows Terminal settings directory not found." -ForegroundColor Yellow
        Write-Host "  Launch Windows Terminal once, then re-run with -SkipPackages -SkipFonts -SkipProfiles." -ForegroundColor Yellow
        $summary += "Windows Terminal: skipped (not launched yet)"
    } else {
        $wtDest = Join-Path $wtDir 'settings.json'
        Backup-IfExists $wtDest
        Copy-Item -Path (Join-Path $PSScriptRoot 'config\windows-terminal\settings.json') -Destination $wtDest -Force
        Write-Host "  Windows Terminal settings -> $wtDest" -ForegroundColor Green
        $summary += "Windows Terminal: installed"
    }
} else {
    $summary += "Windows Terminal: skipped"
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "  Summary" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
foreach ($line in $summary) {
    Write-Host "  $line"
}
Write-Host ""
Write-Host "  Open a new terminal session for profiles to take effect." -ForegroundColor Cyan
Write-Host ""
