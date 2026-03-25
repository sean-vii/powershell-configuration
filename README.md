# powershell-configuration

My Windows terminal setup. Single-command install on a fresh machine.

**Includes:**
- PowerShell 7.6 profile
- [Starship](https://starship.rs/) prompt
- [Yazi](https://github.com/sxyazi/yazi) file manager + dependencies (ripgrep, fd, fzf, zoxide, jq, FFmpeg, Poppler)
- [0xProto Nerd Font](https://github.com/ryanoasis/nerd-fonts)
- Windows Terminal color scheme, theme, and font settings

---

## Prerequisites

### PowerShell 7.6

This setup requires PowerShell 7.6. If you're still on Windows PowerShell (v5, the one that ships with Windows), install 7.6 first:

```powershell
winget install --id Microsoft.PowerShell -e --accept-package-agreements --accept-source-agreements
```

Then **close and reopen your terminal**, select **PowerShell** (not "Windows PowerShell") from the dropdown, and continue.

---

## Install (fresh machine)

Open **PowerShell 7.6** and paste:

```powershell
winget install --id Git.Git -e --accept-package-agreements --accept-source-agreements; $env:PATH += ";$env:ProgramFiles\Git\cmd"; git clone https://github.com/sean-vii/powershell-configuration.git "$env:USERPROFILE\powershell-configuration"; Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force; & "$env:USERPROFILE\powershell-configuration\install.ps1"
```

> Font installation requires admin rights. If the terminal was not opened as Administrator, re-run `install.ps1` as Administrator after the initial run to install the font.

### What it does

1. Installs Git (if not present) and clones this repo
2. Runs `install.ps1` which:
   - Installs all tools via `winget import`
   - Downloads and installs 0xProto Nerd Font (admin required)
   - Copies the PowerShell 7 profile to the correct location (OneDrive-aware)
   - Copies Starship config to `~/.config/starship.toml`
   - Copies Windows Terminal settings

### Flags

```powershell
.\install.ps1 -SkipPackages        # skip winget import
.\install.ps1 -SkipFonts           # skip font download/install
.\install.ps1 -SkipProfiles        # skip PS profile + starship config
.\install.ps1 -SkipWindowsTerminal # skip Windows Terminal settings
```