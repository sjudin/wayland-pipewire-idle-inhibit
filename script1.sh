#!/usr/bin/env

# Hardcoded Service Constants
SERVICE="com.rafaelrc.WaylandPipewireIdleInhibit"
INTERFACE="com.rafaelrc.WaylandPipewireIdleInhibit"
PATH_OBJ="/com/rafaelrc/WaylandPipewireIdleInhibit"

# 1. Function to fetch state and print JSON
print_state() {
    IS_ACTIVE=$(busctl --user get-property "$SERVICE" "$PATH_OBJ" "$INTERFACE" IsIdleInhibited | awk '{print $2}')
    IS_MANUAL=$(busctl --user get-property "$SERVICE" "$PATH_OBJ" "$INTERFACE" ManualInhibit | awk '{print $2}')

    if [ "$IS_ACTIVE" == "true" ]; then
        ALT="activated"
        TOOLTIP="Idle Inhibitor: Active"
    else
        ALT="deactivated"
        TOOLTIP="Idle Inhibitor: Inactive"
    fi

    CLASS=""
    if [ "$IS_MANUAL" == "true" ]; then
        CLASS="manual"
        TOOLTIP="$TOOLTIP (Manual Override)"
    fi

    printf '{"alt": "%s", "class": "%s", "tooltip": "%s"}\n' "$ALT" "$CLASS" "$TOOLTIP"
}

# 2. Print initial state immediately
print_state

# 3. Monitor for changes
# busctl --user monitor --match "type='signal',sender='$SERVICE',path='$PATH_OBJ',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged'" | \
busctl --user monitor --json=short --match "type='signal',sender='$SERVICE',path='$PATH_OBJ',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged'" "$SERVICE" | \
while read -r line; do
    print_state
done
