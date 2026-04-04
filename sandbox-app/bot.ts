// LunchClaw Telegram bot — runs inside a NemoClaw sandbox.
// Will be rewritten in phase 3 to use hungry-cli as the backend.
// This is a placeholder showing the conversation state machine.

import { Telegraf } from "telegraf";
import { extractKeywords } from "./keywords.js";

interface FoodOption {
  itemName: string;
  restaurant: string;
  restaurantUrl: string;
  price: string;
  eta: string;
}

interface Session {
  state: "idle" | "searching" | "choosing" | "confirming";
  options: FoodOption[];
  selected: FoodOption | null;
}

const TELEGRAM_TOKEN = process.env.TELEGRAM_BOT_TOKEN;
const ALLOWED_USER = Number(process.env.TELEGRAM_ALLOWED_USER_ID);
const DELIVERY_ADDRESS = process.env.DELIVERY_ADDRESS || "your address";

if (!TELEGRAM_TOKEN) {
  console.error("TELEGRAM_BOT_TOKEN is required");
  process.exit(1);
}
if (!ALLOWED_USER) {
  console.error("TELEGRAM_ALLOWED_USER_ID is required");
  process.exit(1);
}

const bot = new Telegraf(TELEGRAM_TOKEN);

let session: Session = {
  state: "idle",
  options: [],
  selected: null,
};

function resetSession(): void {
  session = { state: "idle", options: [], selected: null };
}

// Only respond to the owner
bot.use((ctx, next) => {
  if (ctx.from?.id !== ALLOWED_USER) {
    return ctx.reply("Sorry, I only take orders from my human.");
  }
  return next();
});

bot.command("start", (ctx) =>
  ctx.reply(
    "Hey! I'm LunchClaw.\n\n" +
      "Just tell me what you're in the mood for and I'll find something " +
      "healthy on Uber Eats.\n\n" +
      'Try: "hungry, something with salmon"\n' +
      'Or: "light salad maybe"\n' +
      'Or just: "feed me"',
  ),
);

bot.command("cancel", (ctx) => {
  resetSession();
  ctx.reply("Cancelled. Ping me when you're hungry.");
});

bot.on("text", async (ctx) => {
  const text = ctx.message.text;

  if (session.state === "confirming") {
    const lower = text.toLowerCase().trim();
    if (["yes", "y", "yeah", "yep", "confirm", "do it"].includes(lower)) {
      // TODO: Wire to hungry-cli order in phase 3
      ctx.reply("Placing your order... (not yet wired to hungry-cli)");
      resetSession();
      return;
    }
    resetSession();
    return ctx.reply("Order cancelled. Let me know when you're hungry!");
  }

  if (session.state === "choosing") {
    const lower = text.toLowerCase().trim();
    if (lower === "more" || lower === "nah") {
      resetSession();
      return ctx.reply("Got it. Tell me more about what you want and I'll search again.");
    }

    const pick = parseInt(text, 10);
    if (pick >= 1 && pick <= session.options.length) {
      const s = session.options[pick - 1];
      session.selected = s;
      session.state = "confirming";
      return ctx.reply(
        `Got it:\n\n` +
          `*${s.itemName}*\n` +
          `From: ${s.restaurant}\n` +
          `Price: ${s.price}\n` +
          `ETA: ${s.eta || "~30 min"}\n` +
          `Delivering to: ${DELIVERY_ADDRESS}\n\n` +
          `Are you home to receive it?`,
        { parse_mode: "Markdown" as const },
      );
    }

    resetSession();
  }

  // New food request
  const keywords = extractKeywords(text);
  ctx.reply(`Looking for: ${keywords.join(", ")}...\n(hungry-cli search not yet wired)`);
  resetSession();
});

process.once("SIGINT", () => bot.stop("SIGINT"));
process.once("SIGTERM", () => bot.stop("SIGTERM"));

bot.launch().then(() => {
  console.log("LunchClaw is running! Waiting for messages...");
});
