#!/usr/bin/env bash

# Configuration
SERVICE="com.rafaelrc.WaylandPipewireIdleInhibit"
OBJECT="/com/rafaelrc/WaylandPipewireIdleInhibit"
INTERFACE="com.rafaelrc.WaylandPipewireIdleInhibit"

# Function to format and output JSON for Waybar
print_status() {
    local idle_inhibited=$1
    local manual_inhibited=$2

    local tooltip=""
    local class=""
    local alt=""

    # Output if the inhibitor is not running
    if [ "$idle_inhibited" == "off" ]; then
        echo '{"alt": "off", "tooltip": "Service not running", "class": "off"}\n'
        return
    fi

    if [ "$idle_inhibited" == "true" ]; then
        alt="inhibited"
        if [ "$manual_inhibited" == "true" ]; then
            tooltip="Idle Inhibitor: Active (Manual)"
            class="manual"
        else
            tooltip="Idle Inhibitor: Active (Audio)"
            class="inhibited"
        fi
    else
        alt="idle"
        tooltip="Idle Inhibitor: Inactive"
        class="idle"
    fi

    # Output compressed JSON line
    printf '{"alt": "%s", "tooltip": "%s", "class": "%s"}\n' "$alt" "$tooltip" "$class"
}

# Get Initial State
# Use 'status' to check if the name exists on the bus to avoid the "not activatable" error
if busctl --user status "$SERVICE" &>/dev/null; then
    # Properties are PascalCase by default in zbus
    IS_IDLE=$(busctl --user get-property $SERVICE $OBJECT $INTERFACE IsIdleInhibited --json=short 2>/dev/null | jq -r '.data // "false"')
    IS_MANUAL=$(busctl --user get-property $SERVICE $OBJECT $INTERFACE ManualInhibit --json=short 2>/dev/null | jq -r '.data // "false"')
else
    IS_IDLE="off"
    IS_MANUAL="off"
fi

print_status "$IS_IDLE" "$IS_MANUAL"

# Monitor for changes
busctl --user monitor --json=short --match "path='$OBJECT',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged'" | while read -r line; do
    NEW_IDLE=$(echo "$line" | jq -r '.payload.data[0].IsIdleInhibited.data')
    NEW_MANUAL=$(echo "$line" | jq -r '.payload.data[0].IsManuallyInhibited.data')
    
    print_status "$NEW_IDLE" "$NEW_MANUAL"
done
