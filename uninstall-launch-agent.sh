#!/bin/bash

# Script to uninstall AppSwitch Launch Agent

LAUNCH_AGENT_NAME="com.appcmd.launchagent"
PLIST_FILE="$HOME/Library/LaunchAgents/$LAUNCH_AGENT_NAME.plist"

if [ -f "$PLIST_FILE" ]; then
    launchctl unload "$PLIST_FILE" 2>/dev/null
    rm "$PLIST_FILE"
    echo "✓ Launch Agent uninstalled successfully!"
    echo "  AppCmd will no longer start automatically at login."
else
    echo "Launch Agent not found. Nothing to uninstall."
fi
