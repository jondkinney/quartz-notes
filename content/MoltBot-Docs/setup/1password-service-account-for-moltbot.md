---
publish: true
created: 2026-01-28T23:28:04.212-06:00
modified: 2026-01-28T23:28:04.213-06:00
cssclasses: ""
---

# 1Password setup for Moltbot (Service Account + scoped vault)

This document describes how we configured Moltbot to pull an OpenAI API key from 1Password **without storing the key in Moltbot config** and **without granting Moltbot access to your full 1Password account**.

The goal is:
- Moltbot can resolve `OPENAI_API_KEY` at runtime (for embeddings / memory search).
- Access is limited to **one vault** (least privilege).
- No secrets are pasted into chat or committed to disk outside of 1Password.

---

## Overview (what we built)

- A dedicated 1Password vault named: **`Moltbot`**
- A 1Password **Service Account** with access to **only that vault**
- A LaunchAgent-managed Moltbot Gateway that starts via:

```text
op run --env-file ~/.clawdbot/env/gateway.env.tpl -- node ... gateway
```

- A template env file containing only an `op://...` reference (no secret values):

```bash
OPENAI_API_KEY=op://Moltbot/<ITEM_ID>/password
```

- The Service Account token stored as an environment variable for the LaunchAgent:

```text
OP_SERVICE_ACCOUNT_TOKEN=...  # scoped to the Moltbot vault
```

- (Optional, recommended) Disabled desktop app integration so personal auth can’t be used accidentally.

---

## Prerequisites

### Software
- **Moltbot** installed and running as a macOS LaunchAgent gateway.
- **1Password CLI** (`op`) installed.
  - Check with: `op --version`
- A 1Password account with access to the **Admin Console** for creating Service Accounts.

### 1Password items
- A vault named **`Moltbot`** (or whatever you choose).
- An item inside that vault containing your **OpenAI API key** stored in the **Password** field.
  - Item title can be anything (special characters are fine if you use item ID references, see below).

### OpenAI billing
- OpenAI embeddings for memory search require **API billing/quota**.
- A ChatGPT subscription (e.g., ChatGPT Pro) **does not** grant API quota.
- Ensure the OpenAI project that owns the API key has pay-as-you-go enabled or credits.

---

## Step-by-step setup

### 1) Create the vault
Create a vault in 1Password:
- Name: **Moltbot**
- Put only the secrets you want Moltbot to access.

### 2) Create a Service Account scoped to that vault
In the 1Password Admin Console:
1. Go to **Developer Tools → Service Accounts**
2. Create a new service account (e.g., “Moltbot”).
3. Grant access to **only** the **Moltbot** vault.
4. Copy the **Service Account Auth Token** (treat like a password).

### 3) Store the service account token for the gateway (LaunchAgent)
Moltbot’s gateway runs as a LaunchAgent:

- File: `~/Library/LaunchAgents/com.clawdbot.gateway.plist`

Add the token under `EnvironmentVariables`:

```xml
<key>OP_SERVICE_ACCOUNT_TOKEN</key>
<string>PASTE_TOKEN_HERE</string>
```

Notes:
- This token is **scoped** to the vault you granted. That’s the primary safety property.
- Anyone with access to your user account and that plist could read it; keep local access secure.

### 4) Create an env template file (no secrets)
Create:

- `~/.clawdbot/env/gateway.env.tpl`

Containing:

```bash
# No secrets here; op resolves them at runtime.
OPENAI_API_KEY=op://Moltbot/<ITEM_ID>/password
```

Why item ID instead of title?
- Item titles can include characters (like parentheses) that break `op://...` parsing.
- Item IDs are stable and safe.

### 5) Get the item ID for the OpenAI key item
From a terminal on the Mac (with `OP_SERVICE_ACCOUNT_TOKEN` available):

```bash
op item get "<Item Title>" --vault "Moltbot" --format json \
  | python3 -c 'import sys,json; print(json.load(sys.stdin)["id"])'
```

Use that ID in the env template:

```bash
OPENAI_API_KEY=op://Moltbot/<ITEM_ID>/password
```

### 6) Update the gateway LaunchAgent to run through `op run`
Edit `~/Library/LaunchAgents/com.clawdbot.gateway.plist` so the `ProgramArguments` look like:

```text
/opt/homebrew/bin/op
run
--env-file
~/.clawdbot/env/gateway.env.tpl
--
/opt/homebrew/bin/node
/opt/homebrew/lib/node_modules/clawdbot/dist/entry.js
gateway
--port
18789
```

This ensures the gateway inherits `OPENAI_API_KEY` at startup.

### 7) Restart the gateway
If gateway RPC restart is disabled, use the CLI:

```bash
clawdbot gateway restart
```

Verify:

```bash
clawdbot gateway status
```

You should see the command line includes `op run --env-file ...`.

### 8) Verify the service account works (without leaking secrets)
Sanity check that the service account can access only the intended vault:

```bash
op vault list
op item list --vault "Moltbot"
```

To confirm the OpenAI key is being injected (without printing it), check for presence/length only:

```bash
op run --env-file ~/.clawdbot/env/gateway.env.tpl -- \
  python3 -c 'import os; k=os.environ.get("OPENAI_API_KEY",""); print(bool(k), len(k))'
```

### 9) Confirm Moltbot memory embeddings work
In Moltbot, a `memory_search` call should no longer fail with `insufficient_quota`.
If it still fails:
- your OpenAI API key’s project likely has **no billing/quota** enabled.

---

## Security best practices

### Least privilege
- Prefer a **Service Account** token over desktop app integration.
- Scope the service account to **only the vault** Moltbot needs.

### Avoid printing secrets
- Never run commands that print `OP_SERVICE_ACCOUNT_TOKEN`.
- Never paste tokens/keys into chat, logs, or code.

### Token rotation
- Rotate/revoke the service account token if it is ever exposed.
- After rotation, update the LaunchAgent env var and restart the gateway.

### File permissions
- Restrict access to:
  - `~/Library/LaunchAgents/com.clawdbot.gateway.plist`
  - `~/.clawdbot/env/gateway.env.tpl` (not secret, but still sensitive metadata)

### Disable personal auth path (optional but recommended)
To reduce the chance of using your full personal account via CLI:
- In 1Password desktop app: disable **Integrate with 1Password CLI**.

Expected result:
- `op whoami` should *not* authenticate as you.
- `op vault list` should still work when `OP_SERVICE_ACCOUNT_TOKEN` is set.

---

## Troubleshooting

### “invalid character in secret reference”
Use item IDs in `op://` references instead of titles.

### “account is not signed in” / “no account found for filter”
That’s expected if you disabled desktop app integration and are not using personal auth.
Service accounts should still work via `OP_SERVICE_ACCOUNT_TOKEN`.

### OpenAI error: `insufficient_quota`
- Add billing / enable pay-as-you-go for the OpenAI API project.
- ChatGPT subscriptions do not apply to API usage.

---

## Notes about our specific setup (for this Mac)

- Vault name: **Moltbot**
- The OpenAI key is referenced via item ID (recommended).
- Gateway is managed by LaunchAgent: `com.clawdbot.gateway`
- Gateway now starts via `op run --env-file ~/.clawdbot/env/gateway.env.tpl -- ...`

