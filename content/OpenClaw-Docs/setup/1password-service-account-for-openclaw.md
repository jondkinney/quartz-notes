---
publish: true
created: 2026-01-28T23:28:04.212-06:00
modified: 2026-02-07T16:30:02.258-06:00
cssclasses: ""
---

# 1Password Service Account Setup for OpenClaw

How to securely manage API keys for OpenClaw using a scoped 1Password Service Account. No secrets stored in config files — keys are pulled from 1Password at startup and injected into the OpenClaw config automatically.

## Goals

- **Least privilege** — Service Account is scoped to a single vault
- **No plaintext secrets on disk** — only the SA token lives in a `.env` file; all API keys live in 1Password
- **Automatic injection** — a LaunchAgent resolves keys on boot and after updates
- **Rotation-friendly** — update a key in 1Password, restart, done

---

## Architecture

```
┌─────────────────────────────────────┐
│  1Password Vault (e.g. "Clawdbot")  │
│  ┌───────────────────────────┐      │
│  │ Brave Search API Key      │      │
│  │ OpenAI API Key            │      │
│  │ Google AI API Key         │      │
│  │ (any future keys...)      │      │
│  └───────────────────────────┘      │
└──────────────┬──────────────────────┘
               │ op:// references
               ▼
┌──────────────────────────────────────┐
│  gateway.env.tpl                     │
│  (no secrets — just op:// refs)      │
└──────────────┬───────────────────────┘
               │ resolved by inject-secrets.sh
               ▼
┌──────────────────────────────────────┐
│  openclaw.json                       │
│  (config patched with real values)   │
└──────────────────────────────────────┘
```

**Components:**

| File | Purpose | Contains secrets? |
|------|---------|:-:|
| `~/.openclaw/.env` | Service Account token | Yes (scoped token only) |
| `~/.openclaw/env/gateway.env.tpl` | `op://` references for each key | No |
| `~/.openclaw/bin/inject-secrets.sh` | Resolves refs → patches config | No |
| `ai.openclaw.inject-secrets.plist` | LaunchAgent: runs on boot + watches for updates | No |

---

## Prerequisites

- **1Password CLI** (`op`) — `brew install 1password-cli`
- **1Password account** with Admin Console access (for creating Service Accounts)
- **OpenClaw** installed and running as a macOS LaunchAgent
- **jq** — `brew install jq`

---

## Step-by-step Setup

### 1. Create a dedicated vault

In 1Password, create a new vault (e.g., "Clawdbot"). Only put secrets here that OpenClaw should access.

### 2. Create a Service Account

In the [1Password Admin Console](https://start.1password.com):

1. Go to **Developer Tools → Service Accounts**
2. Create a new account (e.g., "Clawdbot")
3. Grant access to **only** the vault from step 1
4. Copy the Service Account Auth Token

### 3. Store the SA token

Create `~/.openclaw/.env`:

```bash
OP_SERVICE_ACCOUNT_TOKEN=<YOUR_SERVICE_ACCOUNT_TOKEN>
```

This is the only secret stored on disk. It's scoped to the single vault — even if compromised, it can't access your other vaults or accounts.

### 4. Add API keys to the vault

Store each API key as a Password item in the vault. For example:
- "Brave Search API Key" with the key in the Password field
- "OpenAI API Key" with the key in the Password field
- "Google AI API Key" with the key in the Password field

### 5. Get item IDs

For each item, get the stable ID (safer than titles for `op://` references):

```bash
export OP_SERVICE_ACCOUNT_TOKEN=$(cat ~/.openclaw/.env | cut -d= -f2-)
op item get "Brave Search API Key" --vault <VAULT_NAME> --format json | jq -r '.id'
```

### 6. Create the env template

Create `~/.openclaw/env/gateway.env.tpl`:

```bash
# No secrets here; values are resolved at runtime via `op inject`.
OPENAI_API_KEY=op://<VAULT_NAME>/<ITEM_ID>/password
BRAVE_SEARCH_API_KEY=op://<VAULT_NAME>/<ITEM_ID>/password
GOOGLE_AI_API_KEY=op://<VAULT_NAME>/<ITEM_ID>/password
```

Replace `<VAULT_NAME>` and `<ITEM_ID>` with your actual vault name and item IDs.

### 7. Create the injection script

Create `~/.openclaw/bin/inject-secrets.sh`:

```bash
#!/usr/bin/env bash
# Resolves 1Password op:// refs and patches OpenClaw config.
set -euo pipefail

ENV_TPL="$HOME/.openclaw/env/gateway.env.tpl"
CONFIG="$HOME/.openclaw/openclaw.json"
DOTENV="$HOME/.openclaw/.env"

# Load SA token if not already in environment
if [[ -z "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]] && [[ -f "$DOTENV" ]]; then
  export OP_SERVICE_ACCOUNT_TOKEN=$(grep '^OP_SERVICE_ACCOUNT_TOKEN=' "$DOTENV" | cut -d= -f2-)
fi

if [[ -z "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]]; then
  echo "[inject-secrets] No OP_SERVICE_ACCOUNT_TOKEN found, skipping" >&2
  exit 0
fi

if [[ ! -f "$ENV_TPL" ]]; then
  echo "[inject-secrets] No env template at $ENV_TPL, skipping" >&2
  exit 0
fi

echo "[inject-secrets] Resolving secrets from 1Password..." >&2

# Resolve all op:// references
RESOLVED=$(op inject -i "$ENV_TPL" 2>&1) || {
  echo "[inject-secrets] op inject failed: $RESOLVED" >&2
  exit 1
}

# Parse resolved values
BRAVE_KEY=$(echo "$RESOLVED" | grep '^BRAVE_SEARCH_API_KEY=' | cut -d= -f2-)
OPENAI_KEY=$(echo "$RESOLVED" | grep '^OPENAI_API_KEY=' | cut -d= -f2-)
GOOGLE_AI_KEY=$(echo "$RESOLVED" | grep '^GOOGLE_AI_API_KEY=' | cut -d= -f2-)

# Build jq expression to patch config
JQ_EXPR="."
[[ -n "$BRAVE_KEY" ]] && JQ_EXPR="$JQ_EXPR | .tools.web.search.apiKey = \"$BRAVE_KEY\""
[[ -n "$OPENAI_KEY" ]] && JQ_EXPR="$JQ_EXPR | .skills.entries[\"openai-image-gen\"].apiKey = \"$OPENAI_KEY\" | .skills.entries[\"openai-whisper-api\"].apiKey = \"$OPENAI_KEY\""
[[ -n "$GOOGLE_AI_KEY" ]] && JQ_EXPR="$JQ_EXPR | .skills.entries[\"nano-banana-pro\"].apiKey = \"$GOOGLE_AI_KEY\""

if [[ "$JQ_EXPR" == "." ]]; then
  echo "[inject-secrets] No keys resolved, config unchanged" >&2
  exit 0
fi

# Only patch if values actually changed (avoids unnecessary restarts)
TEMP=$(mktemp)
jq "$JQ_EXPR" "$CONFIG" > "$TEMP"

if diff -q "$TEMP" "$CONFIG" >/dev/null 2>&1; then
  echo "[inject-secrets] All keys already current, no patch needed ✓" >&2
  rm -f "$TEMP"
  exit 0
fi

mv "$TEMP" "$CONFIG"
echo "[inject-secrets] Config patched with fresh secrets from 1Password ✓" >&2
```

Make it executable:

```bash
chmod +x ~/.openclaw/bin/inject-secrets.sh
```

### 8. Create the LaunchAgent

Create `~/Library/LaunchAgents/ai.openclaw.inject-secrets.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>ai.openclaw.inject-secrets</string>
  <key>Comment</key>
  <string>Injects 1Password secrets into OpenClaw config on boot
  and when the gateway plist changes (e.g., after updates)</string>
  <key>ProgramArguments</key>
  <array>
    <string>/Users/YOUR_USERNAME/.openclaw/bin/inject-secrets.sh</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>HOME</key>
    <string>/Users/YOUR_USERNAME</string>
    <key>PATH</key>
    <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
  </dict>
  <key>RunAtLoad</key>
  <true/>
  <key>WatchPaths</key>
  <array>
    <string>/Users/YOUR_USERNAME/Library/LaunchAgents/ai.openclaw.gateway.plist</string>
  </array>
  <key>ThrottleInterval</key>
  <integer>30</integer>
  <key>StandardOutPath</key>
  <string>/Users/YOUR_USERNAME/.openclaw/logs/inject-secrets.log</string>
  <key>StandardErrorPath</key>
  <string>/Users/YOUR_USERNAME/.openclaw/logs/inject-secrets.log</string>
</dict>
</plist>
```

Replace `YOUR_USERNAME` with your macOS username.

**How it works:**
- **`RunAtLoad`** — runs on boot/login, injecting secrets before the gateway fully initializes
- **`WatchPaths`** — if OpenClaw regenerates its gateway plist (e.g., after an update), this fires again to re-inject keys
- **`ThrottleInterval: 30`** — prevents rapid-fire re-runs
- **Diff check in script** — skips patching if keys haven't changed, avoiding unnecessary gateway restarts

Load it:

```bash
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/ai.openclaw.inject-secrets.plist
```

### 9. Verify

Check the log:

```bash
cat ~/.openclaw/logs/inject-secrets.log
```

You should see:

```
[inject-secrets] Resolving secrets from 1Password...
[inject-secrets] Config patched with fresh secrets from 1Password ✓
```

Or if keys are already current:

```
[inject-secrets] All keys already current, no patch needed ✓
```

---

## Adding a New Key

1. Store the key in 1Password in your OpenClaw vault
2. Get the item ID: `op item get "<TITLE>" --vault <VAULT> --format json | jq -r '.id'`
3. Add an `op://` line to `gateway.env.tpl`
4. Add parsing + jq patching logic to `inject-secrets.sh` for the new env var
5. Run `~/.openclaw/bin/inject-secrets.sh` to apply immediately

## Rotating a Key

1. Update the key in 1Password
2. Run `~/.openclaw/bin/inject-secrets.sh` (or reboot — it runs automatically)
3. Restart OpenClaw if needed: `openclaw gateway restart`

## Troubleshooting

### `op` CLI hangs

macOS may prompt for a security approval the first time `op` runs from a LaunchAgent context. Check for a system dialog and approve it. This typically only happens once.

### "a vault query must be provided"

Service accounts require `--vault <name>` on all commands. Make sure your `op://` references include the vault name: `op://<VAULT>/<ITEM>/password`

### "invalid character in secret reference"

Use item IDs instead of titles in `op://` references. Titles with special characters (parentheses, etc.) can break parsing.

### Keys not updating after rotation

Check the inject-secrets log. If it says "no patch needed," the diff check may be comparing against already-patched values. Run the script manually:

```bash
~/.openclaw/bin/inject-secrets.sh
```

---

## Security Notes

- **SA token scope** — the Service Account can only access the one vault you granted. Even if the token leaks, your personal vaults are safe.
- **Why not 1Password Environments/desktop app?** — Desktop app integration uses your full session, which has access to all vaults across all accounts. The SA token approach is strictly least-privilege.
- **File permissions** — ensure `~/.openclaw/.env` is readable only by your user (`chmod 600`).
- **Git safety** — add `.env`, `env/`, and `*.env` to `.gitignore` in your workspace.
- **Never paste tokens into chat** — use `op` CLI or 1Password directly.

---

*Last updated: 2026-02-07*

---
*Part of [[index|Jonokasten]]*
