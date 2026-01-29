---
publish: true
created: 2026-01-28T23:28:04.224-06:00
modified: 2026-01-28T23:28:04.225-06:00
cssclasses: ""
---

# LaunchAgent Configuration

Moltbot runs as a macOS LaunchAgent, which means it starts automatically on login and stays running.

## File Location

```
~/Library/LaunchAgents/com.clawdbot.gateway.plist
```

## Current Configuration

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>com.clawdbot.gateway</string>
    
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    
    <key>ProgramArguments</key>
    <array>
      <string>/opt/homebrew/bin/node</string>
      <string>/opt/homebrew/lib/node_modules/clawdbot/dist/entry.js</string>
      <string>gateway</string>
      <string>--port</string>
      <string>18789</string>
    </array>
    
    <key>StandardOutPath</key>
    <string>/Users/YOUR_USERNAME/.clawdbot/logs/gateway.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/YOUR_USERNAME/.clawdbot/logs/gateway.err.log</string>
    
    <key>EnvironmentVariables</key>
    <dict>
      <key>HOME</key>
      <string>/Users/YOUR_USERNAME</string>
      <key>PATH</key>
      <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
      <key>CLAWDBOT_GATEWAY_PORT</key>
      <string>18789</string>
      <key>CLAWDBOT_GATEWAY_TOKEN</key>
      <string>[REDACTED]</string>
      <key>OP_SERVICE_ACCOUNT_TOKEN</key>
      <string>[REDACTED]</string>
    </dict>
  </dict>
</plist>
```

## Key Environment Variables

| Variable | Purpose |
|----------|---------|
| `CLAWDBOT_GATEWAY_PORT` | Port the gateway listens on |
| `CLAWDBOT_GATEWAY_TOKEN` | Auth token for gateway API |
| `OP_SERVICE_ACCOUNT_TOKEN` | 1Password service account token (for credential access) |

## Managing the LaunchAgent

### Check status
```bash
launchctl list | grep moltbot
```

### Stop
```bash
launchctl unload ~/Library/LaunchAgents/com.clawdbot.gateway.plist
```

### Start
```bash
launchctl load ~/Library/LaunchAgents/com.clawdbot.gateway.plist
```

### Restart (via Moltbot)
```bash
clawdbot gateway restart
```

### View logs
```bash
tail -f ~/.clawdbot/logs/gateway.log
tail -f ~/.clawdbot/logs/gateway.err.log
```

## After Editing the Plist

If you modify the plist file directly:

```bash
# Unload the old version
launchctl unload ~/Library/LaunchAgents/com.clawdbot.gateway.plist

# Load the new version
launchctl load ~/Library/LaunchAgents/com.clawdbot.gateway.plist
```

Or use: `clawdbot gateway restart`

## Common Issues

### Gateway not starting
1. Check syntax: `plutil ~/Library/LaunchAgents/com.clawdbot.gateway.plist`
2. Check logs: `~/.clawdbot/logs/gateway.err.log`
3. Verify node path: `which node`

### Environment variables not working
- launchd loads env vars at boot time
- After editing, must unload/reload the plist
- Use `launchctl setenv` for session-wide vars (less reliable)

---

*Last updated: 2026-02-01*
