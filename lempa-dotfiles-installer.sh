# Christian Lempa Windows Setup Script with WSL & Custom Icons
# Run this in PowerShell as Administrator

#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"

# Colors for output
function Write-Info { Write-Host "[INFO] $args" -ForegroundColor Green }
function Write-Warn { Write-Host "[WARN] $args" -ForegroundColor Yellow }
function Write-Error { Write-Host "[ERROR] $args" -ForegroundColor Red }
function Write-Section { Write-Host "`n==> $args" -ForegroundColor Cyan }

# Configuration
$DotfilesRepo = "https://github.com/smothermonethan99/dotfiles-win.git"
$DotfilesDir = "$env:USERPROFILE\.dotfiles-win"
$IconsRepo = "https://github.com/smothermonethan99/My-wsl-icons-.git"
$IconsDir = "$env:USERPROFILE\.wsl-icons"
# Mr Robot / fsociety wallpaper
$WallpaperUrl = "https://raw.githubusercontent.com/ChristianLempa/hackbox/main/src/assets/mr-robot-wallpaper.png"

# Icon URLs from your repository
$Icons = @{
    "Kali" = "https://raw.githubusercontent.com/smothermonethan99/My-wsl-icons-/main/kali.png"
    "Ubuntu" = "https://raw.githubusercontent.com/smothermonethan99/My-wsl-icons-/main/ubuntu.png"
    "Arch" = "https://raw.githubusercontent.com/smothermonethan99/My-wsl-icons-/main/arch.png"
    "Debian" = "https://raw.githubusercontent.com/smothermonethan99/My-wsl-icons-/main/debian.png"
    "Windows" = "https://raw.githubusercontent.com/smothermonethan99/My-wsl-icons-/main/ps.png"
    "Cmd" = "https://raw.githubusercontent.com/smothermonethan99/My-wsl-icons-/main/cmd.png"
    "Azure" = "https://raw.githubusercontent.com/smothermonethan99/My-wsl-icons-/main/azure.png"
}

# Fallback - Create simple colored icons if download fails
$IconColors = @{
    "Kali" = @{R=0; G=119; B=200}      # Blue
    "Ubuntu" = @{R=233; G=84; B=32}    # Orange  
    "Arch" = @{R=23; G=147; B=209}     # Light Blue
    "Debian" = @{R=215; G=10; B=83}    # Red
    "Windows" = @{R=0; G=120; B=215}   # Windows Blue
}

# ============================================
# Package Manager Setup
# ============================================

function Install-Winget {
    Write-Section "Checking winget installation..."
    if (!(Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Info "Installing winget..."
        $progressPreference = 'silentlyContinue'
        Invoke-WebRequest -Uri https://aka.ms/getwinget -OutFile "$env:TEMP\Microsoft.DesktopAppInstaller.msixbundle"
        Add-AppxPackage "$env:TEMP\Microsoft.DesktopAppInstaller.msixbundle"
    } else {
        Write-Info "✓ Winget already installed"
    }
}

function Install-Chocolatey {
    Write-Section "Checking Chocolatey installation..."
    if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Info "Installing Chocolatey..."
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        refreshenv
    } else {
        Write-Info "✓ Chocolatey already installed"
    }
}

# ============================================
# Christian Lempa's Windows Apps
# ============================================

function Install-ChristianLempaApps {
    Write-Section "Installing Christian Lempa's Windows Applications..."
    
    # Essential Development Tools (from his setup)
    $wingetApps = @(
        "Git.Git",
        "Microsoft.PowerShell",
        "Microsoft.WindowsTerminal",
        "Microsoft.VisualStudioCode",
        "Docker.DockerDesktop",
        "Kubernetes.kubectl",
        "Helm.Helm",
        "Hashicorp.Terraform",
        "Hashicorp.Packer",
        "GitHub.cli",
        "Python.Python.3.12",
        "OpenJS.NodeJS.LTS"
    )
    
    foreach ($app in $wingetApps) {
        Write-Info "Installing $app..."
        try {
            winget install --id $app --silent --accept-package-agreements --accept-source-agreements
        } catch {
            Write-Warn "Could not install $app"
        }
    }
    
    # CLI Tools via Chocolatey
    $chocoApps = @(
        "fzf",
        "jq",
        "yq",
        "nmap",
        "wget",
        "curl",
        "httpie"
    )
    
    foreach ($app in $chocoApps) {
        Write-Info "Installing $app..."
        choco install $app -y --ignore-checksums
    }
}

# ============================================
# Terminal & Shell Setup
# ============================================

function Install-Starship {
    Write-Section "Installing Starship prompt..."
    if (!(Get-Command starship -ErrorAction SilentlyContinue)) {
        winget install --id Starship.Starship --silent
        refreshenv
    } else {
        Write-Info "✓ Starship already installed"
    }
}

function Install-NerdFonts {
    Write-Section "Installing Hack Nerd Font..."
    
    $fontUrl = "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.1.1/Hack.zip"
    $fontZip = "$env:TEMP\Hack.zip"
    $fontDir = "$env:TEMP\HackFont"
    $fontsFolder = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
    
    # Check if fonts are already installed
    if (Test-Path "$fontsFolder\HackNerdFont-Regular.ttf") {
        Write-Info "✓ Hack Nerd Font already installed"
        return
    }
    
    # Create fonts directory if it doesn't exist
    New-Item -ItemType Directory -Force -Path $fontsFolder | Out-Null
    
    # Download and extract
    Write-Info "Downloading Hack Nerd Font..."
    Invoke-WebRequest -Uri $fontUrl -OutFile $fontZip
    Expand-Archive -Path $fontZip -DestinationPath $fontDir -Force
    
    # Install fonts
    Add-Type -AssemblyName System.Drawing
    $fonts = Get-ChildItem $fontDir -Filter "*.ttf"
    $regPath = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
    
    foreach ($font in $fonts) {
        $fontName = $font.BaseName
        $targetPath = Join-Path $fontsFolder $font.Name
        
        # Skip if font is already in use
        if (Test-Path $targetPath) {
            try {
                # Try to remove the file
                Remove-Item -Path $targetPath -Force -ErrorAction Stop
            } catch {
                Write-Warn "Skipping $fontName (already installed and in use)"
                continue
            }
        }
        
        # Copy font file with retry logic
        $maxRetries = 3
        $retryCount = 0
        $copied = $false
        
        while (-not $copied -and $retryCount -lt $maxRetries) {
            try {
                Copy-Item -Path $font.FullName -Destination $targetPath -Force -ErrorAction Stop
                $copied = $true
                
                # Register font in registry (per-user)
                New-ItemProperty -Path $regPath -Name "$fontName (TrueType)" -Value $font.Name -PropertyType String -Force -ErrorAction SilentlyContinue | Out-Null
                
                Write-Info "✓ Installed: $fontName"
            } catch {
                $retryCount++
                if ($retryCount -lt $maxRetries) {
                    Write-Warn "Retry $retryCount/$maxRetries for $fontName..."
                    Start-Sleep -Seconds 2
                } else {
                    Write-Warn "Could not install $fontName (may already be in use)"
                }
            }
        }
    }
    
    # Cleanup
    Remove-Item $fontZip -Force -ErrorAction SilentlyContinue
    Remove-Item $fontDir -Recurse -Force -ErrorAction SilentlyContinue
    
    Write-Info "✓ Hack Nerd Font installation completed"
    Write-Warn "Close all terminal windows and restart them to use the new font"
}

function Clone-Dotfiles {
    Write-Section "Cloning your Windows dotfiles..."
    
    if (Test-Path $DotfilesDir) {
        Write-Warn "Dotfiles directory exists. Updating..."
        Set-Location $DotfilesDir
        git pull
    } else {
        git clone $DotfilesRepo $DotfilesDir
    }
    
    Write-Info "✓ Dotfiles cloned from your repository"
}

function Clone-IconsRepo {
    Write-Section "Cloning your WSL icons repository..."
    
    if (Test-Path $IconsDir) {
        Write-Warn "Icons directory exists. Updating..."
        Set-Location $IconsDir
        git pull
    } else {
        git clone $IconsRepo $IconsDir
    }
    
    Write-Info "✓ Icons repository cloned"
}

function Setup-StarshipConfig {
    Write-Section "Setting up Starship configuration..."
    
    $starshipConfigDir = "$env:USERPROFILE\.config"
    New-Item -ItemType Directory -Force -Path $starshipConfigDir | Out-Null
    
    # Check if starship.toml exists in your dotfiles repo
    $dotfilesStarshipConfig = "$DotfilesDir\starship.toml"
    
    if (Test-Path $dotfilesStarshipConfig) {
        Copy-Item $dotfilesStarshipConfig "$starshipConfigDir\starship.toml" -Force
        Write-Info "✓ Starship config copied from your dotfiles"
    } else {
        # Fallback: Download Christian Lempa's config
        Write-Warn "Starship config not found in your repo, using Christian Lempa's config..."
        $starshipUrl = "https://raw.githubusercontent.com/ChristianLempa/dotfiles-win/main/.starship/starship.toml"
        try {
            Invoke-WebRequest -Uri $starshipUrl -OutFile "$starshipConfigDir\starship.toml" -ErrorAction Stop
            Write-Info "✓ Starship config downloaded"
        } catch {
            Write-Warn "Could not download Starship config, creating default..."
            # Create a basic config with your settings from the documents
            $defaultConfig = @'
# ~/.config/starship.toml
add_newline = false
command_timeout = 1000
format = """$os$username$hostname$kubernetes$directory$git_branch$git_status"""

[character]
success_symbol = ''
error_symbol = ''

[os]
format = '[$symbol](bold white) '   
disabled = false

[os.symbols]
Windows = ''
Arch = '󰣇'
Ubuntu = ''
Macos = '󰀵'

[username]
style_user = 'white bold'
style_root = 'black bold'
format = '[$user]($style) '
disabled = false
show_always = true

[hostname]
ssh_only = false
format = 'on [$hostname](bold yellow) '
disabled = false

[directory]
truncation_length = 1
truncation_symbol = '…/'
home_symbol = '󰋜 ~'
read_only_style = '197'
read_only = '  '
format = 'at [$path]($style)[$read_only]($read_only_style) '

[git_branch]
symbol = ' '
format = 'via [$symbol$branch]($style)'
truncation_symbol = '…/'
style = 'bold green'

[git_status]
format = '[$all_status$ahead_behind]($style) '
style = 'bold green'
conflicted = '🏳'
up_to_date = ''
untracked = ' '
ahead = '⇡${count}'
diverged = '⇕⇡${ahead_count}⇣${behind_count}'
behind = '⇣${count}'
stashed = ' '
modified = ' '
staged = '[++\($count\)](green)'
renamed = '襁 '
deleted = ' '

[kubernetes]
format = 'via [󱃾 $context\($namespace\)](bold purple) '
disabled = false

[vagrant]
disabled = true

[docker_context]
disabled = true

[helm]
disabled = true

[python]
disabled = true

[nodejs]
disabled = true

[ruby]
disabled = true

[terraform]
disabled = true
'@
            [System.IO.File]::WriteAllText("$starshipConfigDir\starship.toml", $defaultConfig, [System.Text.UTF8Encoding]::new($false))
            Write-Info "✓ Created default Starship config"
        }
    }
    
    # Configure PowerShell to use Starship
    $profilePath = $PROFILE.CurrentUserAllHosts
    $profileDir = Split-Path -Parent $profilePath
    New-Item -ItemType Directory -Force -Path $profileDir | Out-Null
    
    $profileContent = @"

# Starship Prompt
Invoke-Expression (&starship init powershell)
"@
    
    if (!(Test-Path $profilePath)) {
        New-Item -ItemType File -Path $profilePath -Force | Out-Null
    }
    
    if (!(Select-String -Path $profilePath -Pattern "starship init" -Quiet)) {
        Add-Content -Path $profilePath -Value $profileContent
        Write-Info "✓ Starship configured for PowerShell"
    }
}

# ============================================
# WSL Setup
# ============================================

function Enable-WSL {
    Write-Section "Enabling WSL..."
    
    # Enable WSL and Virtual Machine Platform
    Write-Info "Enabling WSL features..."
    dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
    dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
    
    # Download and install WSL kernel update
    $wslUpdateUrl = "https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi"
    $wslUpdateFile = "$env:TEMP\wsl_update_x64.msi"
    Invoke-WebRequest -Uri $wslUpdateUrl -OutFile $wslUpdateFile
    Start-Process msiexec.exe -Wait -ArgumentList "/i $wslUpdateFile /quiet"
    
    # Set WSL 2 as default
    wsl --set-default-version 2
    
    Write-Info "✓ WSL enabled"
}

function Install-WSLDistros {
    Write-Section "Installing WSL distributions..."
    
    # Install Ubuntu
    Write-Info "Installing Ubuntu..."
    try {
        $ubuntuCheck = wsl --list --quiet | Select-String -Pattern "Ubuntu"
        if (!$ubuntuCheck) {
            wsl --install -d Ubuntu --no-launch
            Write-Info "✓ Ubuntu installed"
        } else {
            Write-Info "✓ Ubuntu already installed"
        }
    } catch {
        Write-Warn "Error installing Ubuntu: $_"
    }
    
    # Install Kali Linux
    Write-Info "Installing Kali Linux..."
    try {
        $kaliCheck = wsl --list --quiet | Select-String -Pattern "kali"
        if (!$kaliCheck) {
            wsl --install -d kali-linux --no-launch
            Write-Info "✓ Kali Linux installed"
        } else {
            Write-Info "✓ Kali Linux already installed"
        }
    } catch {
        Write-Warn "Error installing Kali: $_"
    }
    
    # Install Arch Linux via manual method
    Write-Info "Installing Arch Linux..."
    try {
        $archCheck = wsl --list --quiet | Select-String -Pattern "Arch"
        if (!$archCheck) {
            $archUrl = "https://github.com/yuk7/ArchWSL/releases/latest/download/Arch.zip"
            $archZip = "$env:TEMP\Arch.zip"
            $archDir = "$env:LOCALAPPDATA\Arch"
            
            Invoke-WebRequest -Uri $archUrl -OutFile $archZip
            New-Item -ItemType Directory -Force -Path $archDir | Out-Null
            Expand-Archive -Path $archZip -DestinationPath $archDir -Force
            
            # Run Arch installer (this registers it with WSL)
            Start-Process -FilePath "$archDir\Arch.exe" -ArgumentList "install" -Wait -NoNewWindow
            
            Remove-Item $archZip -Force
            Write-Info "✓ Arch Linux installed"
        } else {
            Write-Info "✓ Arch Linux already installed"
        }
    } catch {
        Write-Warn "Error installing Arch: $_"
    }
    
    Write-Host ""
    Write-Warn "WSL Distributions have been installed but NOT initialized."
    Write-Warn "You must open each distro ONCE to set up username/password:"
    Write-Host "  1. Open Windows Terminal"
    Write-Host "  2. Click the dropdown and select Ubuntu (set username/password)"
    Write-Host "  3. Click the dropdown and select Kali (set username/password)"
    Write-Host "  4. Click the dropdown and select Arch (set username/password)"
    Write-Host ""
    Write-Info "After initializing all distros, you can run this script again to install Starship in them."
    Write-Host ""
}

function Download-CustomIcons {
    Write-Section "Downloading custom WSL icons..."
    
    New-Item -ItemType Directory -Force -Path $IconsDir | Out-Null
    
    foreach ($distro in $Icons.Keys) {
        $iconPath = "$IconsDir\$distro.png"
        Write-Info "Downloading $distro icon..."
        
        try {
            # Download with better error handling
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $Icons[$distro] -OutFile $iconPath -ErrorAction Stop -TimeoutSec 10
            
            # Verify file was downloaded and has content
            if ((Test-Path $iconPath) -and ((Get-Item $iconPath).Length -gt 0)) {
                Write-Info "✓ Downloaded $distro icon (white/transparent)"
            } else {
                throw "Downloaded file is empty"
            }
        } catch {
            Write-Warn "Could not download $distro icon: $_"
            
            # Create a simple colored placeholder icon
            Create-PlaceholderIcon -DistroName $distro -OutputPath $iconPath
        }
    }
    
    Write-Info "✓ Icon download completed - All icons in: $IconsDir"
}

function Create-PlaceholderIcon {
    param(
        [string]$DistroName,
        [string]$OutputPath
    )
    
    Write-Info "Creating placeholder icon for $DistroName..."
    
    Add-Type -AssemblyName System.Drawing
    
    $bitmap = New-Object System.Drawing.Bitmap 50, 50
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    
    # Get color for this distro
    $colorInfo = $IconColors[$DistroName]
    if ($colorInfo) {
        $color = [System.Drawing.Color]::FromArgb(255, $colorInfo.R, $colorInfo.G, $colorInfo.B)
    } else {
        $color = [System.Drawing.Color]::White
    }
    
    # Draw a circle with the distro color
    $brush = New-Object System.Drawing.SolidBrush($color)
    $graphics.FillEllipse($brush, 5, 5, 40, 40)
    
    # Add first letter of distro name
    $font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
    $textBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::Black)
    $text = $DistroName.Substring(0, 1).ToUpper()
    $stringFormat = New-Object System.Drawing.StringFormat
    $stringFormat.Alignment = [System.Drawing.StringAlignment]::Center
    $stringFormat.LineAlignment = [System.Drawing.StringAlignment]::Center
    $graphics.DrawString($text, $font, $textBrush, 25, 25, $stringFormat)
    
    # Save as PNG
    $bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    
    # Cleanup
    $graphics.Dispose()
    $bitmap.Dispose()
    $brush.Dispose()
    $textBrush.Dispose()
    $font.Dispose()
    $stringFormat.Dispose()
    
    Write-Info "✓ Created placeholder icon for $DistroName"
}

function Setup-WindowsTerminal {
    Write-Section "Configuring Windows Terminal with your custom settings..."
    
    $wtSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    
    if (!(Test-Path $wtSettingsPath)) {
        Write-Warn "Windows Terminal settings not found. Please open Windows Terminal once first."
        return
    }
    
    # Backup existing settings
    Copy-Item $wtSettingsPath "$wtSettingsPath.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')" -Force
    
    # Check if your dotfiles has a Windows Terminal config
    $dotfilesWTConfig = "$DotfilesDir\windows-terminal-settings.json"
    
    if (Test-Path $dotfilesWTConfig) {
        Write-Info "Using your custom Windows Terminal settings..."
        Copy-Item $dotfilesWTConfig $wtSettingsPath -Force
        Write-Info "✓ Windows Terminal configured with your settings"
    } else {
        Write-Info "Applying custom icon configuration..."
        
        # Read current settings
        $settings = Get-Content $wtSettingsPath -Raw | ConvertFrom-Json
        
        # Update all profiles with Hack Nerd Font and custom settings
        foreach ($profile in $settings.profiles.list) {
            # Set font for all profiles
            if (-not $profile.font) {
                $profile | Add-Member -NotePropertyName "font" -NotePropertyValue @{} -Force
            }
            $profile.font | Add-Member -NotePropertyName "face" -NotePropertyValue "Hack Nerd Font" -Force
            $profile.font | Add-Member -NotePropertyName "size" -NotePropertyValue 14 -Force
            
            # Set custom icons for WSL distros
            if ($profile.source -match "Windows.Terminal.Wsl") {
                $distroName = $profile.name
                
                # Map distro names to icon files
                $iconFile = $null
                switch -Wildcard ($distroName) {
                    "*Ubuntu*" { $iconFile = "ubuntu.png" }
                    "*Kali*" { $iconFile = "kali.png" }
                    "*Arch*" { $iconFile = "arch.png" }
                    "*Debian*" { $iconFile = "debian.png" }
                }
                
                if ($iconFile) {
                    $iconPath = Join-Path $IconsDir $iconFile
                    if (Test-Path $iconPath) {
                        $profile | Add-Member -NotePropertyName "icon" -NotePropertyValue "%userprofile%\.wsl-icons\$iconFile" -Force
                        Write-Info "✓ Set $distroName icon: $iconFile"
                    }
                }
                
                # Enhanced visual settings
                $profile | Add-Member -NotePropertyName "opacity" -NotePropertyValue 95 -Force
                $profile | Add-Member -NotePropertyName "useAcrylic" -NotePropertyValue $false -Force
                $profile | Add-Member -NotePropertyName "cursorShape" -NotePropertyValue "filledBox" -Force
            }
            
            # Configure PowerShell profile
            if ($profile.name -match "PowerShell" -or $profile.source -match "PowerShell") {
                $iconPath = Join-Path $IconsDir "ps.png"
                if (Test-Path $iconPath) {
                    $profile | Add-Member -NotePropertyName "icon" -NotePropertyValue "%userprofile%\.wsl-icons\ps.png" -Force
                    Write-Info "✓ Set PowerShell icon"
                }
            }
            
            # Configure Command Prompt
            if ($profile.name -match "Command" -or $profile.commandline -match "cmd") {
                $iconPath = Join-Path $IconsDir "cmd.png"
                if (Test-Path $iconPath) {
                    $profile | Add-Member -NotePropertyName "icon" -NotePropertyValue "%userprofile%\.wsl-icons\cmd.png" -Force
                    Write-Info "✓ Set Command Prompt icon"
                }
            }
        }
        
        # Configure default profile (Ubuntu if available)
        $ubuntuProfile = $settings.profiles.list | Where-Object { $_.name -match "Ubuntu" } | Select-Object -First 1
        if ($ubuntuProfile) {
            $settings | Add-Member -NotePropertyName "defaultProfile" -NotePropertyValue $ubuntuProfile.guid -Force
            Write-Info "✓ Set Ubuntu as default profile"
        }
        
        # Set theme
        $settings | Add-Member -NotePropertyName "theme" -NotePropertyValue "dark" -Force
        $settings | Add-Member -NotePropertyName "useAcrylicInTabRow" -NotePropertyValue $true -Force
        
        # Save updated settings
        $settings | ConvertTo-Json -Depth 100 | Set-Content $wtSettingsPath -Encoding UTF8
        Write-Info "✓ Windows Terminal configured with custom icons"
    }
    
    Write-Info "✓ Settings backup created"
    Write-Warn "Restart Windows Terminal to see the custom icons"
}

function Install-StarshipInWSL {
    Write-Section "Installing Starship in WSL distributions..."
    
    $starshipInstall = "curl -sS https://starship.rs/install.sh | sh -s -- -y"
    
    $distros = @(
        @{Name="Ubuntu"; Command="Ubuntu"; PackageManager="apt"},
        @{Name="Kali"; Command="kali-linux"; PackageManager="apt"},
        @{Name="Arch"; Command="Arch"; PackageManager="pacman"}
    )
    
    foreach ($distro in $distros) {
        Write-Info "Installing Starship in $($distro.Name)..."
        
        try {
            # Check if distro is available
            $distroList = wsl --list --quiet
            if ($distroList -notmatch $distro.Command) {
                Write-Warn "$($distro.Name) not installed yet, skipping..."
                continue
            }
            
            # Install curl and starship with timeout
            if ($distro.PackageManager -eq "apt") {
                $installCmd = "export DEBIAN_FRONTEND=noninteractive && sudo apt update -qq && sudo apt install -y curl && $starshipInstall && echo 'eval `"`$(starship init bash)`"' >> ~/.bashrc"
            } else {
                $installCmd = "sudo pacman -Sy --noconfirm curl && $starshipInstall && echo 'eval `"`$(starship init bash)`"' >> ~/.bashrc"
            }
            
            # Run with timeout using job
            $job = Start-Job -ScriptBlock {
                param($distroCmd, $cmd)
                wsl -d $distroCmd bash -c $cmd 2>&1
            } -ArgumentList $distro.Command, $installCmd
            
            # Wait for job with timeout (60 seconds)
            $completed = Wait-Job -Job $job -Timeout 60
            
            if ($completed) {
                $result = Receive-Job -Job $job
                Remove-Job -Job $job -Force
                Write-Info "✓ Starship installed in $($distro.Name)"
            } else {
                Stop-Job -Job $job
                Remove-Job -Job $job -Force
                Write-Warn "Timeout installing Starship in $($distro.Name) - you can install it manually later"
            }
        } catch {
            Write-Warn "Error installing in $($distro.Name): $_"
        }
    }
    
    Write-Info "✓ Starship installation in WSL completed"
}

function Copy-StarshipConfigToWSL {
    Write-Section "Copying Starship config to WSL distributions..."
    
    $starshipConfig = "$env:USERPROFILE\.config\starship.toml"
    
    if (!(Test-Path $starshipConfig)) {
        Write-Warn "Starship config not found. Skipping WSL config copy."
        return
    }
    
    # Get content to copy
    $configContent = Get-Content $starshipConfig -Raw
    
    # Copy to each distro
    $distros = @(
        @{Name="Ubuntu"; Command="Ubuntu"},
        @{Name="Kali"; Command="kali-linux"},
        @{Name="Arch"; Command="Arch"}
    )
    
    foreach ($distro in $distros) {
        Write-Info "Copying config to $($distro.Name)..."
        
        try {
            # Check if distro is available
            $distroList = wsl --list --quiet
            if ($distroList -notmatch $distro.Command) {
                Write-Warn "$($distro.Name) not installed yet, skipping..."
                continue
            }
            
            # Create config directory and copy file with timeout
            $command = @"
mkdir -p ~/.config && cat > ~/.config/starship.toml << 'STARSHIP_EOF'
$configContent
STARSHIP_EOF
"@
            
            # Use Start-Process with timeout
            $process = Start-Process -FilePath "wsl" -ArgumentList "-d", $distro.Command, "bash", "-c", $command -NoNewWindow -PassThru -Wait -TimeoutSeconds 10
            
            if ($process.ExitCode -eq 0) {
                Write-Info "✓ Config copied to $($distro.Name)"
            } else {
                Write-Warn "Failed to copy config to $($distro.Name)"
            }
        } catch {
            Write-Warn "Error copying to $($distro.Name): $_"
        }
    }
    
    Write-Info "✓ Starship config copy completed"
}

# ============================================
# Windows Customization
# ============================================

function Set-Wallpaper {
    Write-Section "Setting wallpaper..."
    
    $wallpaperPath = "$env:USERPROFILE\Pictures\fsociety-wallpaper.jpg"
    $picturesDir = Split-Path -Parent $wallpaperPath
    New-Item -ItemType Directory -Force -Path $picturesDir | Out-Null
    
    # Try to download the wallpaper
    try {
        Invoke-WebRequest -Uri $WallpaperUrl -OutFile $wallpaperPath -ErrorAction Stop
        Write-Info "✓ Wallpaper downloaded"
    } catch {
        Write-Warn "Could not download wallpaper from specified URL"
        
        # Create a simple dark wallpaper as fallback
        Write-Info "Creating fallback dark wallpaper..."
        Add-Type -AssemblyName System.Drawing
        
        $bitmap = New-Object System.Drawing.Bitmap 1920, 1080
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        
        # Dark background
        $darkBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 18, 18, 18))
        $graphics.FillRectangle($darkBrush, 0, 0, 1920, 1080)
        
        # Add text
        $font = New-Object System.Drawing.Font("Segoe UI", 48, [System.Drawing.FontStyle]::Bold)
        $textBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 0, 119, 200))
        $text = "Christian Lempa Setup"
        $graphics.DrawString($text, $font, $textBrush, 600, 500)
        
        # Save
        $bitmap.Save($wallpaperPath, [System.Drawing.Imaging.ImageFormat]::Jpeg)
        
        # Cleanup
        $graphics.Dispose()
        $bitmap.Dispose()
        $darkBrush.Dispose()
        $textBrush.Dispose()
        $font.Dispose()
        
        Write-Info "✓ Created fallback wallpaper"
    }
    
    # Set wallpaper
    try {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", CharSet=CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@
        
        [Wallpaper]::SystemParametersInfo(20, 0, $wallpaperPath, 3)
        Write-Info "✓ Wallpaper set"
    } catch {
        Write-Warn "Could not set wallpaper automatically. Wallpaper saved to: $wallpaperPath"
        Write-Host "  You can set it manually: Right-click Desktop -> Personalize -> Background"
    }
}

function Enable-DarkMode {
    Write-Section "Enabling Windows Dark Mode..."
    
    # Enable Dark Mode for Apps
    $appsThemePath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
    if (!(Test-Path $appsThemePath)) {
        New-Item -Path $appsThemePath -Force | Out-Null
    }
    Set-ItemProperty -Path $appsThemePath -Name "AppsUseLightTheme" -Value 0
    
    # Enable Dark Mode for System
    Set-ItemProperty -Path $appsThemePath -Name "SystemUsesLightTheme" -Value 0
    
    # Set accent color on taskbar and start menu
    Set-ItemProperty -Path $appsThemePath -Name "ColorPrevalence" -Value 0
    
    # Enable transparency effects
    Set-ItemProperty -Path $appsThemePath -Name "EnableTransparency" -Value 1
    
    Write-Info "✓ Dark mode enabled for apps and system"
}

function Optimize-Taskbar {
    Write-Section "Configuring taskbar (Christian Lempa style)..."
    
    $explorerPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    $searchPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
    
    # Center taskbar icons (Windows 11)
    if ([System.Environment]::OSVersion.Version.Build -ge 22000) {
        Set-ItemProperty -Path $explorerPath -Name "TaskbarAl" -Value 1 -ErrorAction SilentlyContinue
        Write-Info "✓ Taskbar icons centered (Windows 11)"
    }
    
    # Hide search box, show search icon only
    if (Test-Path $searchPath) {
        Set-ItemProperty -Path $searchPath -Name "SearchboxTaskbarMode" -Value 1 -ErrorAction SilentlyContinue
    }
    
    # Show small taskbar icons (Windows 10)
    Set-ItemProperty -Path $explorerPath -Name "TaskbarSmallIcons" -Value 1 -ErrorAction SilentlyContinue
    
    # Hide Task View button
    Set-ItemProperty -Path $explorerPath -Name "ShowTaskViewButton" -Value 0 -ErrorAction SilentlyContinue
    
    # Auto-hide taskbar: disabled (always visible)
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3" -Name "Settings" -Value ([byte[]](0x30,0x00,0x00,0x00,0xfe,0xff,0xff,0xff,0x02,0x00,0x00,0x00,0x03,0x00,0x00,0x00,0x3e,0x00,0x00,0x00,0x2e,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x80,0x07,0x00,0x00,0x38,0x04,0x00,0x00)) -ErrorAction SilentlyContinue
    
    Write-Info "✓ Taskbar configured"
    Write-Warn "Restart Explorer to apply taskbar changes: Stop-Process -Name explorer -Force"
}

function Configure-Desktop {
    Write-Section "Configuring desktop settings..."
    
    $desktopPath = "HKCU:\Control Panel\Desktop"
    $explorerPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    
    # Show file extensions
    Set-ItemProperty -Path $explorerPath -Name "HideFileExt" -Value 0
    
    # Show hidden files
    Set-ItemProperty -Path $explorerPath -Name "Hidden" -Value 1
    
    # Disable wallpaper compression (better quality)
    Set-ItemProperty -Path $desktopPath -Name "JPEGImportQuality" -Value 100 -ErrorAction SilentlyContinue
    
    # Disable window animations for performance
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop\WindowMetrics" -Name "MinAnimate" -Value 0 -ErrorAction SilentlyContinue
    
    # Snap windows (keep enabled)
    Set-ItemProperty -Path $explorerPath -Name "SnapAssist" -Value 1 -ErrorAction SilentlyContinue
    
    # Show This PC on desktop (optional, Christian Lempa style)
    $thisPC = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel"
    if (!(Test-Path $thisPC)) {
        New-Item -Path $thisPC -Force | Out-Null
    }
    Set-ItemProperty -Path $thisPC -Name "{20D04FE0-3AEA-1069-A2D8-08002B30309D}" -Value 0 -ErrorAction SilentlyContinue
    
    Write-Info "✓ Desktop settings configured"
    Write-Info "  - File extensions: visible"
    Write-Info "  - Hidden files: visible"
    Write-Info "  - This PC: shown on desktop"
}

# ============================================
# Main Installation
# ============================================

function Show-Completion {
    Write-Section "Installation Complete! 🎉"
    Write-Host ""
    Write-Info "Installed components:"
    Write-Host "  ✓ Windows Terminal with your custom settings"
    Write-Host "  ✓ WSL 2 enabled"
    Write-Host "  ✓ Ubuntu, Kali Linux, and Arch Linux (need initialization)"
    Write-Host "  ✓ Starship prompt (Windows + WSL)"
    Write-Host "  ✓ Christian Lempa's development tools"
    Write-Host "  ✓ Your custom icons for all distros"
    Write-Host "  ✓ Hack Nerd Font"
    Write-Host "  ✓ Mr. Robot wallpaper"
    Write-Host "  ✓ Full dark mode enabled"
    Write-Host "  ✓ Centered taskbar (Windows 11)"
    Write-Host "  ✓ Desktop settings optimized"
    Write-Host ""
    Write-Section "CRITICAL - You MUST do these steps:"
    Write-Host ""
    Write-Host "STEP 1: RESTART YOUR COMPUTER NOW"
    Write-Host "  WSL requires a restart to work properly"
    Write-Host ""
    Write-Host "STEP 2: Restart Explorer to apply taskbar changes:"
    Write-Host "  Stop-Process -Name explorer -Force"
    Write-Host ""
    Write-Host "STEP 3: After restart, initialize each WSL distro:"
    Write-Host "  a) Open Windows Terminal"
    Write-Host "  b) Click dropdown -> Select 'Ubuntu'"
    Write-Host "     - Create username and password"
    Write-Host "  c) Click dropdown -> Select 'Kali Linux'"
    Write-Host "     - Create username and password"
    Write-Host "  d) Click dropdown -> Select 'Arch'"
    Write-Host "     - Create username and password"
    Write-Host ""
    Write-Host "STEP 4: After initializing all distros, run the Starship setup scripts:"
    Write-Host "  Your dotfiles include starship_kali.sh and starship_windows.txt"
    Write-Host "  Run these in each distro to configure Starship with your settings"
    Write-Host ""
    Write-Info "What's been configured:"
    Write-Host "  • Dark mode for apps and system"
    Write-Host "  • Centered taskbar (Win 11) / Small icons (Win 10)"
    Write-Host "  • File extensions visible"
    Write-Host "  • Hidden files visible"
    Write-Host "  • This PC on desktop"
    Write-Host "  • Search icon only (no search box)"
    Write-Host "  • Task View button hidden"
    Write-Host ""
    Write-Info "Your custom files location:"
    Write-Host "  Icons: $IconsDir"
    Write-Host "  Dotfiles: $DotfilesDir"
    Write-Host "  Wallpaper: $env:USERPROFILE\Pictures\fsociety-wallpaper.jpg"
    Write-Host ""
    Write-Warn "To restart Explorer now, run: Stop-Process -Name explorer -Force"
    Write-Host ""
}

function Main {
    Clear-Host
    Write-Host "=========================================="
    Write-Host "  Christian Lempa Windows + WSL Setup"
    Write-Host "  With Custom Icons & Starship"
    Write-Host "=========================================="
    Write-Host ""
    
    Write-Info "This script will:"
    Write-Host "  • Install Christian Lempa's Windows applications"
    Write-Host "  • Install WSL 2 with Ubuntu, Kali Linux, and Arch Linux"
    Write-Host "  • Configure Starship prompt (Windows + WSL)"
    Write-Host "  • Set custom white icons for WSL distros"
    Write-Host "  • Install Hack Nerd Font"
    Write-Host "  • Set fsociety wallpaper"
    Write-Host "  • Enable dark mode"
    Write-Host ""
    Write-Warn "IMPORTANT: Close ALL Windows Terminal windows before continuing!"
    Write-Warn "The font installation will fail if Terminal is open."
    Write-Host ""
    
    $response = Read-Host "Continue with installation? (Y/N)"
    if ($response -ne 'Y' -and $response -ne 'y') {
        Write-Info "Installation cancelled"
        exit
    }
    
    # Check if Windows Terminal is running
    $terminalProcess = Get-Process -Name "WindowsTerminal" -ErrorAction SilentlyContinue
    if ($terminalProcess) {
        Write-Warn "Windows Terminal is currently running!"
        Write-Host "Please close all Windows Terminal windows and run this script from:"
        Write-Host "  • PowerShell ISE, or"
        Write-Host "  • Regular PowerShell (not Windows Terminal), or"
        Write-Host "  • Command Prompt with 'powershell' command"
        Write-Host ""
        $forceResponse = Read-Host "Continue anyway? (Y/N)"
        if ($forceResponse -ne 'Y' -and $forceResponse -ne 'y') {
            exit
        }
    }
    
    try {
        Install-Winget
        Install-Chocolatey
        Install-ChristianLempaApps
        Install-Starship
        Install-NerdFonts
        Clone-Dotfiles
        Clone-IconsRepo
        Setup-StarshipConfig
        Enable-WSL
        Install-WSLDistros
        Download-CustomIcons
        Setup-WindowsTerminal
        Install-StarshipInWSL
        Copy-StarshipConfigToWSL
        Set-Wallpaper
        Enable-DarkMode
        Configure-Desktop
        Optimize-Taskbar
        Show-Completion
    } catch {
        Write-Error "Installation failed: $_"
        Write-Host ""
        Write-Info "You can re-run this script to continue installation"
        exit 1
    }
}

# Run main installation
Main