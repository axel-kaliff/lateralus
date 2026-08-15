# vim: set ft=make :
########################
### custom-omarchy.just
########################
## Omarchy desktop management (Hyprland + Quickshell alongside COSMIC)

# Enable SDDM autologin into the Omarchy session for the current user
[group('Omarchy')]
omarchy-autologin:
    #!/usr/bin/pkexec bash
    /usr/libexec/lateralus-sddm-autologin enable "{{ `id -un` }}"
    rm -f /etc/lateralus/no-autologin
    echo "Autologin takes effect on next boot."

# Disable SDDM autologin and stop the LUKS auto-enable from re-adding it
[group('Omarchy')]
omarchy-autologin-off:
    #!/usr/bin/pkexec bash
    /usr/libexec/lateralus-sddm-autologin disable
    mkdir -p /etc/lateralus
    touch /etc/lateralus/no-autologin
    echo "The SDDM greeter will be shown on next boot."

# Switch the display manager: sddm (Omarchy) or cosmic (COSMIC greeter)
[group('Omarchy')]
omarchy-greeter greeter:
    #!/usr/bin/pkexec bash
    # No --now: never kill the running session; takes effect on reboot
    case "{{ greeter }}" in
    sddm)
        systemctl disable cosmic-greeter.service
        systemctl enable sddm.service
        ;;
    cosmic)
        systemctl disable sddm.service
        systemctl enable cosmic-greeter.service
        ;;
    *)
        echo "Usage: ujust omarchy-greeter <sddm|cosmic>"
        exit 1
        ;;
    esac
    echo "Display manager set to {{ greeter }} — reboot to apply."

# Re-seed the Omarchy default configs for the current user (never overwrites your files)
[group('Omarchy')]
omarchy-setup:
    #!/usr/bin/bash
    sudo /usr/libexec/lateralus-omarchy-user-setup --force --user "$(id -un)"
    echo ""
    echo "Done. Pick the 'Omarchy' session at the login screen (or run"
    echo "'ujust omarchy-autologin' to boot straight into it)."

# Reset Omarchy configs in $HOME to shipped defaults (destructive, confirms first)
[group('Omarchy')]
omarchy-reset-configs:
    #!/usr/bin/bash
    omarchy-reinstall-configs

# Open the LocalSend firewall port (firewalld replaces Omarchy's ufw rule)
[group('Omarchy')]
omarchy-localsend-firewall:
    #!/usr/bin/pkexec bash
    firewall-cmd --permanent --add-service=localsend
    firewall-cmd --reload
    echo "LocalSend port 53317 (tcp+udp) opened."
