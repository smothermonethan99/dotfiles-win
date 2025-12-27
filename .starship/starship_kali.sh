#!/bin/bash
# Starship Setup Script for Kali Linux
# Run this script with: bash starship_setup.sh

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo "Installing Starship..."
curl -sS https://starship.rs/install.sh | sh

echo -e "\nConfiguring bash profile..."

# Add Starship initialization to .bashrc
STARSHIP_INIT='eval "$(starship init bash)"'

if ! grep -q "starship init bash" ~/.bashrc; then
    echo "" >> ~/.bashrc
    echo "$STARSHIP_INIT" >> ~/.bashrc
    echo "✓ Added Starship initialization to ~/.bashrc"
else
    echo "✓ Starship already configured in ~/.bashrc"
fi

echo -e "\nCreating Starship config..."

# Create config directory and file
mkdir -p ~/.config
touch ~/.config/starship.toml

# Write config to starship.toml
cat > ~/.config/starship.toml << 'EOF'
# ~/.config/starship.toml
add_newline = false
command_timeout = 1000
format = """$os$username$hostname$kubernetes$directory$git_branch$git_status"""
# Drop ugly default prompt characters
[character]
success_symbol = ''
error_symbol = ''
# ---
[os]
format = '[$symbol](bold white) '   
disabled = false
[os.symbols]
Windows = ''
Arch = '󰣇'
Ubuntu = ''
Macos = '󰀵'
# ---
# Shows the username
[username]
style_user = 'white bold'
style_root = 'black bold'
format = '[$user]($style) '
disabled = false
show_always = true
# Shows the hostname
[hostname]
ssh_only = false
format = 'on [$hostname](bold yellow) '
disabled = false
# Shows current directory
[directory]
truncation_length = 1
truncation_symbol = '…/'
home_symbol = '󰋜 ~'
read_only_style = '197'
read_only = '  '
format = 'at [$path]($style)[$read_only]($read_only_style) '
# Shows current git branch
[git_branch]
symbol = ' '
format = 'via [$symbol$branch]($style)'
# truncation_length = 4
truncation_symbol = '…/'
style = 'bold green'
# Shows current git status
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
# Shows kubernetes context and namespace
[kubernetes]
format = 'via [󱃾 $context\($namespace\)](bold purple) '
disabled = false
# ---
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
EOF

echo "✓ Created Starship config at: ~/.config/starship.toml"

echo -e "\n${YELLOW}IMPORTANT: Make sure you have a Nerd Font installed!${NC}"
echo -e "${YELLOW}Recommended fonts: JetBrainsMono Nerd Font, FiraCode Nerd Font${NC}"
echo -e "${CYAN}Download from: https://www.nerdfonts.com/font-downloads${NC}"

echo -e "\n✓ Setup complete!"
echo "Please restart your terminal or run: source ~/.bashrc"