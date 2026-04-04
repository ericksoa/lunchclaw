// Thin wrapper around the hungry-cli. Shells out to the CLI binary
// and parses JSON responses. Runs inside the NemoClaw sandbox.

import { execFile as execFileCb } from "child_process";

// Path to the hungry CLI inside the sandbox.
// Override via HUNGRY_CLI_PATH env var for local dev/testing.
const CLI = process.env.HUNGRY_CLI_PATH || "/sandbox/hungry-cli/dist/cli.js";

function execFileAsync(cmd: string, args: string[], opts: { timeout: number; maxBuffer: number }): Promise<{ stdout: string }> {
  return new Promise((resolve, reject) => {
    execFileCb(cmd, args, opts, (err, stdout) => {
      if (err) reject(err);
      else resolve({ stdout: stdout as string });
    });
  });
}

export interface SearchResult {
  restaurant: string;
  restaurantUrl: string;
  itemName: string;
  description: string;
  price: string;
  eta: string;
  rating: string;
}

export interface MenuItem {
  itemName: string;
  description: string;
  price: string;
  category: string;
}

export interface CartAddResult {
  success: boolean;
  cartTotal: string;
  itemCount: number;
}

export interface CartState {
  items: { name: string; price: string; qty: number }[];
  total: string;
  deliveryFee: string;
  serviceFee: string;
}

export interface OrderResult {
  success: boolean;
  total: string;
  eta: string;
  orderId: string;
}

async function run(...args: string[]): Promise<string> {
  const { stdout } = await execFileAsync("node", [CLI, ...args], {
    timeout: 60000,
    maxBuffer: 1024 * 1024,
  });
  return stdout;
}

async function runJson<T>(...args: string[]): Promise<T> {
  const stdout = await run(...args, "--json");
  return JSON.parse(stdout) as T;
}

export async function hungrySearch(query: string): Promise<SearchResult[]> {
  return runJson<SearchResult[]>("search", query);
}

export async function hungryMenu(url: string): Promise<MenuItem[]> {
  return runJson<MenuItem[]>("menu", url);
}

export async function hungryCartAdd(url: string, item: string): Promise<CartAddResult> {
  const stdout = await run("cart", "add", url, item, "--json");
  return JSON.parse(stdout) as CartAddResult;
}

export async function hungryCartView(): Promise<CartState> {
  return runJson<CartState>("cart", "view");
}

export async function hungryCartClear(): Promise<void> {
  await run("cart", "clear");
}

export async function hungryOrder(confirm = false): Promise<OrderResult> {
  const args = ["order", "--json"];
  if (confirm) args.push("--confirm");
  const stdout = await run(...args);
  return JSON.parse(stdout) as OrderResult;
}

export async function hungryAuthCheck(): Promise<boolean> {
  try {
    await run("auth", "--check");
    return true;
  } catch {
    return false;
  }
}
