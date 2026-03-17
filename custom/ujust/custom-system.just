# vim: set ft=make :
#######################
### custom-system.just
#######################
## Example system configuration commands
## These are simplified examples adapted from Bluefin

# Run a system benchmark (requires stress-ng from Homebrew)
[group('System')]
benchmark:
    #!/usr/bin/env bash
    source /usr/lib/ujust/ujust.sh
    if ! type -P "stress-ng" &>/dev/null ; then
        echo "stress-ng is not installed."
        if command -v brew &>/dev/null; then
            if gum confirm "Install stress-ng via Homebrew?" ; then
                brew install stress-ng
                brew link stress-ng
            else
                exit 0
            fi
        else
            echo "Please install stress-ng to run benchmarks."
            exit 1
        fi
    fi
    echo 'Running a 1 minute benchmark...'
    pushd $(mktemp -d) > /dev/null
    stress-ng --matrix 0 -t 1m --times
    popd > /dev/null

# Configure docker and libvirt groups for development
[group('System')]
configure-dev-groups:
    #!/usr/bin/pkexec bash
    CURRENT_USER="{{ `id -un` }}"
    echo "Adding $CURRENT_USER to docker and libvirt groups..."

    # Ensure groups exist in /etc/group
    for group in docker libvirt; do
        if ! grep -q "^$group:" /etc/group; then
            echo "Adding $group to /etc/group"
            grep "^$group:" /usr/lib/group | tee -a /etc/group > /dev/null
        fi
        usermod -aG $group $CURRENT_USER
    done

    echo "Groups configured. Log out and back in for changes to take effect."


# Clean up container images and volumes
[group('Maintenance')]
clean-containers:
    #!/usr/bin/bash
    echo "Cleaning up Podman containers, images, and volumes..."
    podman system prune -af
    podman volume prune -f
    echo "Cleanup complete!"

# Update system and reboot if needed
[group('Maintenance')]
update-and-reboot:
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    echo "Updating system..."
    sudo bootc upgrade
    if gum confirm "Reboot now to apply updates?"; then
        systemctl reboot
    else
        echo "Reboot later to apply updates."
    fi

# Update everything: brew, flatpak, system
[group('Maintenance')]
update-all:
    #!/usr/bin/bash
    echo "Updating brew packages..."
    brew update && brew upgrade
    echo ""
    echo "Updating flatpaks..."
    flatpak update -y
    echo ""
    echo "Checking for system updates..."
    sudo bootc upgrade
    echo ""
    echo "All updates complete!"

# Set fish as default shell
[group('System')]
set-fish-shell:
    #!/usr/bin/bash
    FISH_PATH=$(command -v fish)
    if [ -z "$FISH_PATH" ]; then
        echo "Fish shell not found!"
        exit 1
    fi
    if [ "$SHELL" = "$FISH_PATH" ]; then
        echo "Fish is already your default shell."
        exit 0
    fi
    echo "Setting fish ($FISH_PATH) as default shell..."
    chsh -s "$FISH_PATH"
    echo "Done! Log out and back in for the change to take effect."

# First-time setup: dotfiles + brew + gh login + fish shell
[group('System')]
setup:
    #!/usr/bin/bash
    echo "=== Lateralus First-Time Setup ==="
    echo ""
    echo "Step 1: Applying dotfiles and theme..."
    sudo /usr/libexec/lateralus-user-setup
    echo ""
    echo "Step 2: Checking Homebrew..."
    if ! command -v brew &>/dev/null && [ ! -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
        echo "Homebrew not found. Installing (this may take a while)..."
        sudo /usr/libexec/lateralus-brew-setup
    fi
    # Source brew into current shell
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    echo "Homebrew is available."
    echo ""
    echo "Step 3: GitHub authentication"
    gh auth login
    echo ""
    echo "Step 4: Setting fish as default shell..."
    FISH_PATH=$(command -v fish || echo /home/linuxbrew/.linuxbrew/bin/fish)
    chsh -s "$FISH_PATH"
    echo ""
    echo "Setup complete! Log out and back in to start using fish."
