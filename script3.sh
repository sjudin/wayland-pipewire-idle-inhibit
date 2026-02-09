#!/usr/bin/env bash

# Configuration
SERVICE="com.rafaelrc.WaylandPipewireIdleInhibit"
OBJECT="/com/rafaelrc/WaylandPipewireIdleInhibit"
INTERFACE="com.rafaelrc.WaylandPipewireIdleInhibit"

# Function to format and output JSON for Waybar
print_status() {
    local idle_inhibited=$1
    local manual_inhibited=$2

    local text=""
    local tooltip=""
    local class=""
    local alt=""

    if [ "$idle_inhibited" == "true" ]; then
        alt="inhibited"
        if [ "$manual_inhibited" == "true" ]; then
            text="" # Icon for Manual Inhibit (e.g., Eye)
            tooltip="Idle Inhibitor: Active (Manual)"
            class="manual"
        else
            text="" # Icon for Audio Inhibit
            tooltip="Idle Inhibitor: Active (Audio)"
            class="inhibited"
        fi
    else
        text="" # Icon for Idle (e.g., Eye Slash)
        alt="idle"
        tooltip="Idle Inhibitor: Inactive"
        class="idle"
    fi

    # Output compressed JSON line
    printf '{"text": "%s", "alt": "%s", "tooltip": "%s", "class": "%s"}\n' "$text" "$alt" "$tooltip" "$class"
}

# 1. Get Initial State
# Note: Property names match the PascalCase of the Rust functions in dbus_server.rs
IS_IDLE=$(busctl --user get-property $SERVICE $OBJECT $INTERFACE IsIdleInhibited --json=short 2>/dev/null | jq -r '.data')
IS_MANUAL=$(busctl --user get-property $SERVICE $OBJECT $INTERFACE ManualInhibit --json=short 2>/dev/null | jq -r '.data')

print_status "$IS_IDLE" "$IS_MANUAL"

# 2. Monitor for changes
busctl --user monitor --json=short --match "path='$OBJECT',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged'" | while read -r line; do
    if echo "$line" | jq -e '.member == "PropertiesChanged"' > /dev/null; then
        # Parse the specific keys from your custom signal payload
        NEW_IDLE=$(echo "$line" | jq -r '.payload.data[0].IsIdleInhibited.data')
        NEW_MANUAL=$(echo "$line" | jq -r '.payload.data[0].IsManuallyInhibited.data')
        
        print_status "$NEW_IDLE" "$NEW_MANUAL"
    fi
done
