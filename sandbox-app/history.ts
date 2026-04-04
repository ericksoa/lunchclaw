// Order history tracker — writes to daily memory notes in the workspace.
// This integrates with OpenClaw's memory system so the agent remembers
// what was ordered and can avoid repeats.

import { readFileSync, writeFileSync, existsSync, mkdirSync } from "fs";
import { join } from "path";

export interface OrderRecord {
  item: string;
  restaurant: string;
  price: string;
  eta?: string;
  healthNote?: string;
  timestamp: string;
}

// Allow overriding paths for testing
let memoryDir = "/sandbox/.openclaw/workspace/memory";
let historyFile = "/sandbox/lunchclaw/order-history.json";

export function setPaths(opts: { memoryDir?: string; historyFile?: string }): void {
  if (opts.memoryDir) memoryDir = opts.memoryDir;
  if (opts.historyFile) historyFile = opts.historyFile;
}

export function recordOrder(order: Omit<OrderRecord, "timestamp">): void {
  const history = loadHistory();
  history.push({
    ...order,
    timestamp: new Date().toISOString(),
  });
  writeFileSync(historyFile, JSON.stringify(history, null, 2));

  const today = new Date().toISOString().split("T")[0];
  const memoryFile = join(memoryDir, `${today}.md`);

  if (!existsSync(memoryDir)) {
    mkdirSync(memoryDir, { recursive: true });
  }

  const entry = `\n## Lunch Order\n- **${order.item}** from ${order.restaurant}\n- $${order.price} · ${order.eta || "~30 min"}\n- ${order.healthNote || ""}\n`;

  if (existsSync(memoryFile)) {
    const existing = readFileSync(memoryFile, "utf-8");
    writeFileSync(memoryFile, existing + entry);
  } else {
    writeFileSync(memoryFile, `# ${today}\n${entry}`);
  }
}

export function getRecentOrders(days = 7): OrderRecord[] {
  const history = loadHistory();
  const cutoff = new Date();
  cutoff.setDate(cutoff.getDate() - days);

  return history.filter((o) => new Date(o.timestamp) > cutoff);
}

export function getRecentRestaurants(count = 5): string[] {
  const history = loadHistory();
  const restaurants: string[] = [];
  for (let i = history.length - 1; i >= 0 && restaurants.length < count; i--) {
    if (!restaurants.includes(history[i].restaurant)) {
      restaurants.push(history[i].restaurant);
    }
  }
  return restaurants;
}

function loadHistory(): OrderRecord[] {
  if (!existsSync(historyFile)) return [];
  try {
    return JSON.parse(readFileSync(historyFile, "utf-8")) as OrderRecord[];
  } catch {
    return [];
  }
}
