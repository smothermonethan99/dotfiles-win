#!/bin/bash
# One-time Starship setup

MARKER="$HOME/.starship_configured"

if [ -f "$MARKER" ]; then
    exit 0
fi

echo ""
echo "========================================="
echo "  Installing Starship Prompt..."
echo "========================================="
echo ""

# Install Starship
curl -sS https://starship.rs/install.sh | sh -s -- -y

# Create config directory
mkdir -p ~/.config

# Create starship config
cat > ~/.config/starship.toml << 'EOF'
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

[terraform]
format = "via [ terraform $version]($style) 壟 [$workspace]($style) "

[vagrant]
format = "via [ vagrant $version]($style) "

[docker_context]
format = "via [ $context](bold blue) "

[helm]
format = "via [ $version](bold purple) "

[python]
symbol = " "
python_binary = "python3"

[nodejs]
format = "via [ $version](bold green) "
disabled = true

[ruby]
format = "via [ $version]($style) "

[kubernetes]
format = 'via [ﴱ $context\($namespace\)](bold purple) '
disabled = false

[kubernetes.context_aliases]
"do-fra1-prod-k8s-clcreative" = " lgcy-1"
"infra-home-kube-prod-1" = " prod-1"
"infra-home-kube-prod-2" = " prod-2"
"infra-cloud-kube-prod-1" = " prod-1"
"infra-cloud-kube-test-1" = " test-1"
EOF

# Add to bashrc if not already there
if ! grep -q 'eval "$(starship init bash)"' ~/.bashrc 2>/dev/null; then
    echo '' >> ~/.bashrc
    echo '# Starship prompt' >> ~/.bashrc
    echo 'eval "$(starship init bash)"' >> ~/.bashrc
fi

# Create marker file
touch "$MARKER"

echo ""
echo "✓ Starship installed and configured!"
echo ""
echo "Reloading shell configuration..."
source ~/.bashrc

echo ""
echo "Done! Your prompt should now be active."
echo ""
