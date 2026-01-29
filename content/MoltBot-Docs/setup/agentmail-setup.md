---
publish: true
created: 2026-01-28T23:28:04.232-06:00
modified: 2026-01-28T23:28:04.234-06:00
cssclasses: ""
---

# AgentMail Integration with Moltbot

> **Purpose:** Give your agent a dedicated email address that forwards to your chat (Telegram, Discord, etc.)

## Overview

**Flow:**
```
Email sent to agent@agentmail.to
    ↓
AgentMail receives it
    ↓
Webhook fires to your Moltbot instance (via Tailscale Funnel)
    ↓
Transform filters by allowlist
    ↓
Hook session processes the email (can check calendar, search, etc.)
    ↓
Response delivered to your chat channel
```

**Why AgentMail over Gmail webhooks?**
- Purpose-built for agents (simple API, webhooks just work)
- No OAuth complexity
- Webhook contains full email content (Gmail Pub/Sub only sends notification, requires separate fetch)
- Free tier is generous

---

## Prerequisites

1. **Moltbot running** with Tailscale Funnel enabled (`gateway.tailscale.mode: "funnel"`)
2. **Python 3.x** with a virtual environment
3. **AgentMail account** at [agentmail.dev](https://agentmail.dev)

---

## Step 1: Get AgentMail API Key

1. Sign up at [agentmail.dev](https://agentmail.dev)
2. Go to Settings → API Keys
3. Create a new API key
4. Save it securely (you'll need it for all API calls)

---

## Step 2: Install AgentMail SDK

```bash
cd ~/clawd
python3 -m venv .venv
source .venv/bin/activate
pip install agentmail
```

---

## Step 3: Create Your Inbox

```python
from agentmail import AgentMail

client = AgentMail(api_key="am_your_api_key_here")

inbox = client.inboxes.create(
    username="mybot",  # becomes mybot@agentmail.to
    display_name="My Bot"
)
print(f"Created: {inbox.inbox_id}")
```

---

## Step 4: Configure Moltbot Webhook Endpoint

### 4.1 Create the transform file

Create `~/.clawdbot/hooks/email-allowlist.ts`:

```typescript
/**
 * AgentMail webhook transform - allowlist trusted senders
 */

const ALLOWLIST = [
  'youremail@gmail.com',
  'you@work.com',
  // Add trusted senders here
];

const TELEGRAM_USER_ID = 'YOUR_TELEGRAM_USER_ID';  // Find via @userinfobot

function extractEmail(from: any): string | null {
  if (!from) return null;
  
  // Handle array format: [{email: "...", name: "..."}]
  if (Array.isArray(from) && from[0]?.email) {
    return from[0].email;
  }
  
  // Handle string format: "Name <email@example.com>"
  if (typeof from === 'string') {
    const match = from.match(/<([^>]+)>/) || from.match(/([^\s<>]+@[^\s<>]+)/);
    return match ? match[1] : null;
  }
  
  return null;
}

export default function(input: any) {
  // ⚠️ IMPORTANT: Moltbot wraps the webhook body in input.payload
  const payload = input?.payload;
  const message = payload?.message;
  
  // Try both 'from' and 'from_' (AgentMail SDK uses from_)
  const from = extractEmail(message?.from || message?.from_);
  
  if (!from || !ALLOWLIST.some(addr => addr.toLowerCase() === from.toLowerCase())) {
    console.log(`[email-allowlist] ❌ Blocked email from: ${from || 'unknown'}`);
    return null;  // Drop the webhook
  }
  
  console.log(`[email-allowlist] ✅ Allowed email from: ${from}`);
  
  const subject = message?.subject || '(no subject)';
  const body = message?.text || message?.preview || '';
  
  // Return format for hook wake action
  return {
    message: `📬 Email from ${from}:\n\nSubject: ${subject}\n\n${body}`,
    channel: 'telegram',
    to: `telegram:${TELEGRAM_USER_ID}`,
    accountId: 'default',
    deliver: true
  };
}
```

### 4.2 Add hooks config to clawdbot.json

```json
{
  "hooks": {
    "enabled": true,
    "path": "/hooks",
    "token": "hooks_generate_a_random_token_here",
    "transformsDir": "~/.clawdbot/hooks",
    "mappings": [
      {
        "id": "agentmail",
        "match": {
          "path": "/agentmail"
        },
        "transform": {
          "module": "email-allowlist.ts"
        }
      }
    ]
  }
}
```

### 4.3 Restart Moltbot

The gateway needs to restart to load the new hooks config. Either:
- Use `clawdbot gateway restart`
- Or patch the config (which triggers auto-restart)

---

## Step 5: Register the Webhook with AgentMail

Get your Tailscale Funnel URL (check `clawdbot status` or logs for the URL).

```python
from agentmail import AgentMail

client = AgentMail(api_key="am_your_api_key_here")

webhook = client.webhooks.create(
    url="https://YOUR-MACHINE.tailXXXXX.ts.net/hooks/agentmail?token=hooks_your_token_here",
    event_types=["message.received"]
)
print(f"Webhook ID: {webhook.webhook_id}")
```

---

## Step 6: Test It

1. **Test locally first:**
```bash
curl -s "http://127.0.0.1:18789/hooks/agentmail?token=hooks_your_token" \
  -X POST -H "Content-Type: application/json" \
  -d '{"type":"event","message":{"from":"youremail@gmail.com","subject":"Test","text":"Hello!"}}'
```

Should return: `{"ok":true,"runId":"..."}`

2. **Test via Tailscale Funnel:**
```bash
curl -s "https://YOUR-MACHINE.tailXXXXX.ts.net/hooks/agentmail?token=hooks_your_token" \
  -X POST -H "Content-Type: application/json" \
  -d '{"type":"event","message":{"from":"youremail@gmail.com","subject":"Test","text":"Hello!"}}'
```

3. **Send a real email** to your AgentMail address and check your Telegram.

---

## Gotchas & Fixes

### ❌ "hook mapping failed" or "requires message"
**Cause:** Transform return format is wrong.
**Fix:** Return `{ message: "...", channel: "telegram" }` — not `{ action: "wake", text: "..." }`

### ❌ Blocked email from: unknown
**Cause:** The `from` field extraction is failing.
**Fix:** AgentMail sends `from` as a **string** like `"Name <email@example.com>"`, not an array. Use the `extractEmail()` helper that handles both formats.

### ❌ 404 on webhook endpoint
**Cause:** The `hooks.path` config or `match.path` is wrong.
**Fix:** 
- Set `hooks.path: "/hooks"` in config
- Set `match.path: "/agentmail"` in the mapping (NOT `/hooks/agentmail`)
- Final URL becomes: `/hooks` + `/agentmail` = `/hooks/agentmail`

### ❌ Transform changes not taking effect
**Cause:** Transforms don't hot-reload.
**Fix:** Restart the gateway after editing transform files.

### ❌ Webhook fires but no Telegram notification
**Cause:** The hook session runs but doesn't know where to deliver.
**Fix:** Include `to: "telegram:USER_ID"` in the transform return object.

### ❌ Email arrives in AgentMail but webhook doesn't fire
**Cause:** Webhook URL is unreachable from the internet.
**Fix:** 
1. Ensure Tailscale Funnel is enabled and running
2. Test the URL with curl from outside your network
3. Check AgentMail webhook logs (if available)

---

## Payload Reference

### AgentMail webhook payload (message.received)
```json
{
  "type": "event",
  "event_type": "message.received",
  "event_id": "evt_xxx",
  "message": {
    "inbox_id": "mybot@agentmail.to",
    "thread_id": "thd_xxx",
    "message_id": "msg_xxx",
    "from": "Sender Name <sender@example.com>",
    "to": ["mybot@agentmail.to"],
    "subject": "Email subject",
    "text": "Plain text body",
    "html": "<p>HTML body</p>",
    "preview": "First 200 chars...",
    "attachments": [...],
    "timestamp": "2026-01-28T23:00:00Z"
  }
}
```

### Moltbot transform input (what your function receives)
```json
{
  "payload": { ... the webhook body above ... },
  "headers": { "host": "...", "content-type": "...", ... },
  "url": "http://...",
  "path": "agentmail"
}
```

⚠️ **Key insight:** Moltbot wraps the incoming webhook body in `input.payload`, so access the message via `input.payload.message`.

---

## Useful Commands

### List messages in inbox
```python
messages = client.inboxes.messages.list(inbox_id="mybot@agentmail.to", limit=10)
for msg in messages.messages:
    print(f"{msg.subject} from {msg.from_}")
```

### Check webhook status
```python
webhooks = client.webhooks.list()
for wh in webhooks.webhooks:
    print(f"{wh.webhook_id}: {wh.url}")
```

### Send email from your agent
```python
client.inboxes.messages.send(
    inbox_id="mybot@agentmail.to",
    to="recipient@example.com",
    subject="Hello from My Bot",
    text="This is an automated message."
)
```

---

## File Locations

| File | Purpose |
|------|---------|
| `~/.clawdbot/clawdbot.json` | Main config (hooks section) |
| `~/.clawdbot/hooks/email-allowlist.ts` | Transform that filters & formats emails |
| `~/.clawdbot/logs/gateway.log` | Check for `[email-allowlist]` log entries |

---

## Security Notes

1. **Always use an allowlist** — don't process emails from unknown senders
2. **Use a random token** in the webhook URL — prevents unauthorized webhook calls
3. **Tailscale Funnel** provides the HTTPS endpoint — no need for ngrok or port forwarding

---

*Last updated: 2026-01-28*
*Setup time: ~30 minutes (once you know the gotchas)*

---
*Part of [[index|Jonokasten]]*
