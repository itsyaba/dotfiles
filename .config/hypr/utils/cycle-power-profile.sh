#!/bin/bash
current=$(powerprofilesctl get 2>/dev/null)

if powerprofilesctl list 2>/dev/null | grep -q 'performance:'; then
    case "$current" in
        power-saver)
            next="balanced"
            title="Balanced"
            icon="balance"
            ;;
        balanced)
            next="performance"
            title="Performance"
            icon="rocket_launch"
            ;;
        performance|*)
            next="power-saver"
            title="Power Saver"
            icon="energy_savings_leaf"
            ;;
    esac
else
    case "$current" in
        power-saver)
            next="balanced"
            title="Balanced"
            icon="balance"
            ;;
        balanced|*)
            next="power-saver"
            title="Power Saver"
            icon="energy_savings_leaf"
            ;;
    esac
fi

powerprofilesctl set "$next" 2>/dev/null
caelestia shell toaster info "Power Profile" "Switched to $title" "$icon" 2>/dev/null
