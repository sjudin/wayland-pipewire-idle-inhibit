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
        echo '{"alt": "off", "tooltip": "wayland-pipewire-idle-inhibit not running", "class": "off"}'
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

# Function to fetch and print the current state
get_and_print_state() {
    # Check if the service exists on the bus
    if busctl --user status "$SERVICE" &>/dev/null; then
        # Fetch properties defined in dbus_server.rs
        local idle=$(busctl --user get-property "$SERVICE" "$OBJECT" "$INTERFACE" IsIdleInhibited --json=short 2>/dev/null | jq -r '.data // "false"')
        local manual=$(busctl --user get-property "$SERVICE" "$OBJECT" "$INTERFACE" ManualInhibit --json=short 2>/dev/null | jq -r '.data // "false"')
        print_status "$idle" "$manual"
    else
        print_status "off" "off"
    fi
}

# 1. Output Initial State
get_and_print_state

# 2. Monitor for changes. 
# We monitor our service for signals it sends, and org.freedesktop.DBus for name owner changes.
busctl --user monitor "$SERVICE" "org.freedesktop.DBus" --json=short | while read -r line; do
    # Detect if our service starts or stops (NameOwnerChanged signal from the bus)
    if echo "$line" | jq -e ".member == \"NameOwnerChanged\" and .payload.data[0] == \"$SERVICE\"" >/dev/null; then
        get_and_print_state
    
    # Detect property changes emitted by the main loop
    elif echo "$line" | jq -e ".member == \"PropertiesChanged\" and .path == \"$OBJECT\"" >/dev/null; then
        # Parse the custom payload keys emitted in main.rs
        NEW_IDLE=$(echo "$line" | jq -r '.payload.data[0].IsIdleInhibited.data // empty')
        NEW_MANUAL=$(echo "$line" | jq -r '.payload.data[0].IsManuallyInhibited.data // empty')
        
        if [[ -n "$NEW_IDLE" && -n "$NEW_MANUAL" ]]; then
            print_status "$NEW_IDLE" "$NEW_MANUAL"
        else
            # Fallback to manual poll if payload parsing fails
            get_and_print_state
        fi
    fi
done
