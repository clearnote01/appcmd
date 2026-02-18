#!/bin/bash

# Script to install AppSwitch as a Launch Agent for auto-start at login

APP_NAME="AppCmd"
LAUNCH_AGENT_NAME="com.appcmd.launchagent"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_PATH="$SCRIPT_DIR/.build/release/appcmd"

# Check if app exists
if [ ! -f "$APP_PATH" ]; then
    echo "Error: AppSwitch not found at $APP_PATH"
    echo "Please build the app first with: swift build -c release"
    exit 1
fi

# Create LaunchAgents directory if it doesn't exist
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
mkdir -p "$LAUNCH_AGENTS_DIR"

# Create plist file
PLIST_FILE="$LAUNCH_AGENTS_DIR/$LAUNCH_AGENT_NAME.plist"

cat > "$PLIST_FILE" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LAUNCH_AGENT_NAME</string>
    <key>ProgramArguments</key>
    <array>
        <string>$APP_PATH</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
    <key>ProcessType</key>
    <string>Background</string>
</dict>
</plist>
EOF

# Load the launch agent
launchctl unload "$PLIST_FILE" 2>/dev/null
launchctl load "$PLIST_FILE"

echo "✓ Launch Agent installed successfully!"
echo "  AppCmd will now start automatically at login."
echo ""
echo "To uninstall, run: launchctl unload $PLIST_FILE && rm $PLIST_FILE"
