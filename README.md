# LunchClaw

A NemoClaw-based agent that orders healthy lunch via Telegram.

Tell it what you're in the mood for. It searches for healthy options, checks variety against your recent orders, and places the order after confirming you're home.

## How It Works

```
You (Telegram) → LunchClaw (OpenClaw agent in OpenShell sandbox)
                      ↓
              hungry-cli searches restaurants
                      ↓
              Filters for healthy options + variety
                      ↓
              Presents 2-3 picks via Telegram
                      ↓
              You pick one, confirm you're home
                      ↓
              Places the order
```

## Quick Start

```bash
git clone https://github.com/ericksoa/lunchclaw.git && cd lunchclaw
./lunchclaw setup
```

The setup wizard handles everything:
- Builds hungry-cli and the bot
- Creates a secure NemoClaw sandbox
- Applies network policy
- Deploys code and installs dependencies
- Prompts for your Telegram bot token and delivery address
- Opens a browser for delivery service auth
- Starts the bot

After setup, manage the bot with:

```bash
./lunchclaw status    # Check health
./lunchclaw logs      # Stream logs
./lunchclaw stop      # Stop the bot
./lunchclaw start     # Start the bot
./lunchclaw update    # Rebuild and redeploy
./lunchclaw auth      # Re-authenticate delivery service
./lunchclaw destroy   # Remove sandbox (permanent)
```

## Prerequisites

- [NemoClaw](https://github.com/NVIDIA/NemoClaw) installed (includes OpenShell)
- Docker running
- Node.js 22+
- A Telegram bot token (from [@BotFather](https://t.me/BotFather))
- Your Telegram user ID (from [@userinfobot](https://t.me/userinfobot))

## NemoClaw Deployment

LunchClaw runs inside an [OpenShell](https://github.com/NVIDIA/OpenShell) sandbox provisioned via [NemoClaw](https://github.com/NVIDIA/NemoClaw). This provides:

- **Sandbox isolation** — filesystem restricted to `/sandbox`, no host access
- **Network policy** — only delivery service, Telegram API, and npm registry are reachable
- **Binary-level restrictions** — only `node` and `chromium` can make outbound connections
- **Process isolation** — no privilege escalation, no root
- **OpenClaw workspace** — agent personality and memory at `/sandbox/.openclaw/workspace/`

### How Primitives Are Used

| Primitive | What We Use It For |
|-----------|-------------------|
| `openshell sandbox create --from openclaw` | Create isolated sandbox from OpenClaw community image |
| `openshell sandbox upload` | Deploy hungry-cli + bot code into sandbox |
| `openshell policy set --policy network.yaml` | Apply restrictive network whitelist |
| OpenClaw workspace files | Agent personality (SOUL.md), identity, preferences, safety rules |
| `openshell sandbox connect` | Interactive access for auth and debugging |

### What We Don't Do

- No workarounds to bypass sandbox security
- No credentials stored on disk (injected as env vars at runtime)
- No root access or privileged operations
- No outbound connections to unauthorized hosts

## Manual Setup (Advanced)

If you prefer manual control over each step, read the `./lunchclaw` script source — it's well-commented bash.

## Project Structure

```
lunchclaw/
├── workspace/           # OpenClaw workspace files (uploaded to sandbox)
│   ├── SOUL.md          # Agent personality + health philosophy
│   ├── IDENTITY.md      # Name, emoji, vibe
│   ├── USER.md          # Your address, preferences, budget
│   └── AGENTS.md        # Tool descriptions, safety rules
├── policies/
│   ├── network.yaml     # Hardened network policy (delivery + Telegram only)
│   └── ubereats.yaml    # Legacy policy (superseded by network.yaml)
├── sandbox-app/         # Code that runs INSIDE the sandbox
│   ├── bot.ts           # Telegram bot + conversation state machine
│   ├── hungry.ts        # Thin wrapper — shells out to hungry-cli
│   ├── history.ts       # Order tracking + OpenClaw memory integration
│   ├── keywords.ts      # Food keyword extraction from casual messages
│   └── package.json
├── scripts/
│   └── setup.sh         # Automated provisioning script
├── CLAUDE.md            # Build plan
└── README.md
```

## Security

- **Sandbox isolation** — runs inside OpenShell container, filesystem limited to `/sandbox`
- **Network whitelist** — only delivery service + Telegram API reachable, with binary-level restrictions
- **Owner-only access** — only your Telegram user ID can interact with the bot
- **No payment storage** — delivery service handles all payment; LunchClaw never sees card details
- **Session isolation** — browser session is sandboxed, not accessible from host
- **Budget enforcement** — configurable max per order (default $30)

## License

[Apache 2.0](../hungry-cli/LICENSE)
