# lunchclaw

NemoClaw-hosted Telegram bot that orders healthy lunch from Uber Eats.

## Sister Project

**hungry-cli** (`../hungry-cli`) is the core Uber Eats automation engine. This project consumes it.

## Build Plan

### Phase 1: hungry-cli core (in `../hungry-cli`)

Steps 1-6 build the CLI. Steps 1-2 are done. Step 3 (search) is next. See `../hungry-cli/CLAUDE.md` for details.

### Phase 2: Wire lunchclaw to hungry-cli (this repo)

| Step | What | Status |
|------|------|--------|
| 7 | Create hungry.ts CLI wrapper (shells out to hungry CLI) | Done |
| 8 | Wire bot.ts search to hungrySearch + health filter + variety | Done |
| 9 | Wire bot.ts order to hungryCartAdd + hungryOrder + recordOrder | Done |
| 10 | End-to-end: Telegram msg -> search -> pick -> confirm -> order | Pending (needs sandbox) |

#### Validation checkpoints (Phase 2)

- **Step 7**: `npm run build` in sandbox-app succeeds, can import from hungry-cli
- **Step 8**: Unit tests for bot.ts pass with mocked adapter
- **Step 9**: Unit tests for history integration pass
- **Step 10**: Manual end-to-end via real Telegram. Walk through full flow together, verify each step.

### Phase 3: Deploy

| Step | What | Status |
|------|------|--------|
| 11 | Test setup.sh against real NemoClaw sandbox | Pending |
| 12 | Auth flow inside sandbox | Pending |
| 13 | Bot live on Telegram | Pending |

#### Validation checkpoints (Phase 3)

- **Step 11**: setup.sh runs clean, `openshell sandbox list` shows lunchclaw
- **Step 12**: `hungry auth` inside sandbox works, `hungry auth --check` confirms
- **Step 13**: Full Telegram conversation from phone, end-to-end

### Rule: No step advances until its manual smoke test is reviewed together.

## Architecture

```
User (Telegram) -> bot.ts (state machine) -> hungry-cli (Playwright) -> Uber Eats
                                           -> history.ts (order memory)
```

## Key Files

- `sandbox-app/bot.ts` — Telegram bot + conversation state machine (has TODO placeholders for hungry-cli wiring)
- `sandbox-app/keywords.ts` — Extracts food keywords from casual messages
- `sandbox-app/history.ts` — Order tracking + OpenClaw memory integration
- `workspace/SOUL.md` — Agent personality, health philosophy, ordering protocol
- `workspace/USER.md` — Delivery address, preferences, budget
- `policies/ubereats.yaml` — Network policy for sandbox
- `scripts/setup.sh` — NemoClaw sandbox provisioning

## Dev

- TypeScript, vitest for tests
- Bot runs inside NemoClaw sandbox at `/sandbox/lunchclaw/`
- Workspace files upload to `/sandbox/.openclaw/workspace/`
