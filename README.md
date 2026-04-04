# LunchClaw 🦀

A NemoClaw-based agent that orders healthy lunch from Uber Eats via Telegram.

Tell it what you're in the mood for. It browses Uber Eats, filters for healthy
options, checks variety against your recent orders, and places the order after
confirming you're home.

## How It Works

```
You (Telegram) → LunchClaw (OpenClaw agent in NemoClaw sandbox)
                      ↓
              Playwright browses Uber Eats
                      ↓
              Filters for healthy options
                      ↓
              Presents 2-3 picks via Telegram
                      ↓
              You pick one, confirm you're home
                      ↓
              Places the order
```

## Prerequisites

- [NemoClaw](https://github.com/NVIDIA/NemoClaw) installed and working
- A Telegram bot token (from [@BotFather](https://t.me/BotFather))
- Your Telegram user ID (from [@userinfobot](https://t.me/userinfobot))
- An Uber Eats account (you'll log in inside the sandbox)

## Setup

1. Edit `workspace/USER.md` with your delivery address.

2. Run the setup script:
   ```bash
   ./scripts/setup.sh
   ```

3. Set environment variables inside the sandbox:
   ```bash
   openshell sandbox exec lunchclaw -- bash -c '
     echo "TELEGRAM_BOT_TOKEN=your-token-here" >> /sandbox/.env
     echo "TELEGRAM_ALLOWED_USER_ID=your-id-here" >> /sandbox/.env
     echo "DELIVERY_ADDRESS=your-address-here" >> /sandbox/.env
   '
   ```

4. Log into Uber Eats (one-time, saves session):
   ```bash
   openshell sandbox exec lunchclaw -- npm run --prefix /sandbox/lunchclaw auth
   ```

5. Start the bot:
   ```bash
   openshell sandbox exec lunchclaw -- npm start --prefix /sandbox/lunchclaw
   ```

6. Message your bot on Telegram: "hungry, something with chicken"

## Project Structure

```
lunchclaw/
├── workspace/           # OpenClaw workspace files (uploaded to sandbox)
│   ├── SOUL.md          # Agent personality + health philosophy
│   ├── IDENTITY.md      # Name, emoji, vibe
│   ├── USER.md          # Your address, preferences, budget
│   └── AGENTS.md        # Tool descriptions, safety rules
├── policies/
│   └── ubereats.yaml    # Network policy allowing Uber Eats access
├── sandbox-app/         # Code that runs INSIDE the sandbox
│   ├── bot.js           # Telegram bot + conversation state machine
│   ├── ubereats.js      # Playwright automation for Uber Eats
│   ├── history.js       # Order tracking + OpenClaw memory integration
│   └── package.json
├── scripts/
│   └── setup.sh         # One-shot provisioning script
└── README.md
```

## Security

- Runs inside a NemoClaw sandbox (filesystem isolation, network policy)
- Only `www.ubereats.com`, `*.uber.com`, and Telegram API are network-accessible
- Only YOUR Telegram user ID can interact with the bot
- Uber Eats session is sandboxed — no access to host browser cookies
- Payment details are never stored or logged by LunchClaw
