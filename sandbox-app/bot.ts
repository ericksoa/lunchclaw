// LunchClaw Telegram bot — runs inside a NemoClaw sandbox.
// Uses hungry-cli as the backend for food delivery automation.

import { Telegraf } from "telegraf";
import { extractKeywords } from "./keywords.js";
import { hungrySearch, hungryCartAdd, hungryCartClear, hungryOrder, type SearchResult } from "./hungry.js";
import { recordOrder, getRecentRestaurants } from "./history.js";

// Health-biased keywords for filtering search results
const HEALTHY_KEYWORDS = new Set([
  "salad", "bowl", "poke", "grain", "quinoa", "kale", "mediterranean",
  "sushi", "japanese", "korean", "thai", "vietnamese", "grilled",
  "healthy", "organic", "protein", "tofu", "seafood", "fish",
]);
const UNHEALTHY_KEYWORDS = new Set([
  "fried", "burger", "pizza", "donut", "wings", "nachos", "fries",
  "milkshake", "mcdonald", "burger king", "wendy", "taco bell",
  "jack in the box", "kfc", "popeye", "domino",
]);

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
const BUDGET_MAX = Number(process.env.BUDGET_MAX || "30");

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

/** Score a search result for health. Higher = healthier. */
function healthScore(r: SearchResult): number {
  const text = `${r.restaurant} ${r.description}`.toLowerCase();
  let score = 50;
  for (const kw of HEALTHY_KEYWORDS) {
    if (text.includes(kw)) score += 8;
  }
  for (const kw of UNHEALTHY_KEYWORDS) {
    if (text.includes(kw)) score -= 12;
  }
  const rating = parseFloat(r.rating);
  if (rating >= 4.7) score += 10;
  else if (rating >= 4.5) score += 5;
  return score;
}

/** Filter and rank results: healthy bias + variety. */
function rankResults(results: SearchResult[]): FoodOption[] {
  const recentRestaurants = new Set(getRecentRestaurants(3));

  return results
    .map((r) => ({
      result: r,
      score: healthScore(r) + (recentRestaurants.has(r.restaurant.toLowerCase()) ? -20 : 10),
    }))
    .filter((x) => x.score >= 40)
    .sort((a, b) => b.score - a.score)
    .slice(0, 3)
    .map((x) => ({
      itemName: x.result.restaurant,
      restaurant: x.result.restaurant,
      restaurantUrl: x.result.restaurantUrl,
      price: x.result.price,
      eta: x.result.eta,
    }));
}

function formatOptions(options: FoodOption[]): string {
  return options
    .map((o, i) =>
      `${i + 1}. *${o.restaurant}*\n   ${[o.price, o.eta, o.itemName !== o.restaurant ? o.itemName : ""].filter(Boolean).join(" · ")}`,
    )
    .join("\n\n");
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
      "healthy nearby.\n\n" +
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

  // --- Confirming: user says yes/no to place order ---
  if (session.state === "confirming") {
    const lower = text.toLowerCase().trim();
    if (["yes", "y", "yeah", "yep", "confirm", "do it"].includes(lower)) {
      const s = session.selected;
      if (!s) {
        resetSession();
        return ctx.reply("Something went wrong. Let's start over.");
      }

      try {
        await ctx.reply("Placing your order...");

        // Clear any previous cart, add the selected item, and order
        await hungryCartClear();
        await hungryCartAdd(s.restaurantUrl, s.itemName);
        const result = await hungryOrder(true);

        // Record for variety tracking
        recordOrder({
          item: s.itemName,
          restaurant: s.restaurant,
          price: result.total || s.price,
          eta: result.eta,
        });

        await ctx.reply(
          `Order placed!\n\n` +
            `*${s.itemName}* from ${s.restaurant}\n` +
            `Total: ${result.total}\n` +
            `ETA: ${result.eta || "~30 min"}\n` +
            `Delivering to: ${DELIVERY_ADDRESS}`,
          { parse_mode: "Markdown" as const },
        );
      } catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        await ctx.reply(`Failed to place order: ${msg}\nTry again or /cancel.`);
      }

      resetSession();
      return;
    }

    resetSession();
    return ctx.reply("Order cancelled. Let me know when you're hungry!");
  }

  // --- Choosing: user picks a number ---
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

  // --- New food request ---
  const keywords = extractKeywords(text);
  const query = keywords.join(" ");
  session.state = "searching";

  try {
    await ctx.reply(`Looking for: ${keywords.join(", ")}...`);
    const results = await hungrySearch(query);

    if (results.length === 0) {
      resetSession();
      return ctx.reply("Didn't find anything for that. Try different keywords?");
    }

    const options = rankResults(results);
    if (options.length === 0) {
      resetSession();
      return ctx.reply("Found some places but nothing that looks great. Try being more specific?");
    }

    session.options = options;
    session.state = "choosing";

    await ctx.reply(
      `Here are my top picks:\n\n${formatOptions(options)}\n\n` +
        `Pick a number, or say "more" to search again.`,
      { parse_mode: "Markdown" as const },
    );
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    await ctx.reply(`Search failed: ${msg}`);
    resetSession();
  }
});

process.once("SIGINT", () => bot.stop("SIGINT"));
process.once("SIGTERM", () => bot.stop("SIGTERM"));

bot.launch().then(() => {
  console.log("LunchClaw is running! Waiting for messages...");
});
