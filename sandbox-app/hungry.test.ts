import { describe, it, expect, vi, beforeEach } from "vitest";

// Mock child_process before importing hungry.ts
vi.mock("child_process", () => {
  const mockExecFile = vi.fn();
  return {
    execFile: mockExecFile,
  };
});

// Must import after mock setup
const { hungrySearch, hungryMenu, hungryCartAdd, hungryCartView, hungryCartClear, hungryOrder, hungryAuthCheck } = await import("./hungry.js");
const { execFile } = await import("child_process");
const mockExecFile = vi.mocked(execFile);

function mockStdout(stdout: string): void {
  // promisify wraps execFile: calls it with (cmd, args, opts, callback)
  // The callback signature is (err, stdout, stderr)
  mockExecFile.mockImplementation((...args: any[]) => {
    const cb = args[args.length - 1];
    if (typeof cb === "function") {
      cb(null, stdout, "");
    }
    return undefined as any;
  });
}

function mockError(msg: string): void {
  mockExecFile.mockImplementation((...args: any[]) => {
    const cb = args[args.length - 1];
    if (typeof cb === "function") {
      cb(new Error(msg), "", msg);
    }
    return undefined as any;
  });
}

beforeEach(() => {
  vi.clearAllMocks();
});

describe("hungrySearch", () => {
  it("parses JSON search results", async () => {
    const results = [
      { restaurant: "Taco Place", restaurantUrl: "https://example.com/store/taco", itemName: "Taco Place", description: "4.7", price: "Low fee", eta: "13 min", rating: "4.7" },
    ];
    mockStdout(JSON.stringify(results));
    const data = await hungrySearch("tacos");
    expect(data).toHaveLength(1);
    expect(data[0].restaurant).toBe("Taco Place");
  });

  it("returns empty array for no results", async () => {
    mockStdout("[]");
    const data = await hungrySearch("nonexistent");
    expect(data).toHaveLength(0);
  });
});

describe("hungryMenu", () => {
  it("parses JSON menu items", async () => {
    const items = [
      { itemName: "Bowl", description: "Healthy", price: "$12.00", category: "Bowls" },
    ];
    mockStdout(JSON.stringify(items));
    const data = await hungryMenu("https://example.com/store/test");
    expect(data).toHaveLength(1);
    expect(data[0].itemName).toBe("Bowl");
  });
});

describe("hungryCartAdd", () => {
  it("parses cart add result", async () => {
    mockStdout(JSON.stringify({ success: true, cartTotal: "$12.00", itemCount: 1 }));
    const result = await hungryCartAdd("https://example.com/store/test", "Bowl");
    expect(result.success).toBe(true);
    expect(result.cartTotal).toBe("$12.00");
  });
});

describe("hungryCartView", () => {
  it("parses cart state", async () => {
    const cart = { items: [{ name: "Bowl", price: "$12.00", qty: 1 }], total: "$12.00", deliveryFee: "", serviceFee: "" };
    mockStdout(JSON.stringify(cart));
    const result = await hungryCartView();
    expect(result.items).toHaveLength(1);
    expect(result.total).toBe("$12.00");
  });
});

describe("hungryCartClear", () => {
  it("does not throw", async () => {
    mockStdout("Cart cleared.");
    await expect(hungryCartClear()).resolves.not.toThrow();
  });
});

describe("hungryOrder", () => {
  it("parses order result without confirm", async () => {
    mockStdout(JSON.stringify({ success: false, total: "$18.95", eta: "22 min", orderId: "" }));
    const result = await hungryOrder(false);
    expect(result.success).toBe(false);
    expect(result.total).toBe("$18.95");
  });

  it("parses order result with confirm", async () => {
    mockStdout(JSON.stringify({ success: true, total: "$18.95", eta: "22 min", orderId: "confirmed" }));
    const result = await hungryOrder(true);
    expect(result.success).toBe(true);
    expect(result.orderId).toBe("confirmed");
  });
});

describe("hungryAuthCheck", () => {
  it("returns true when auth succeeds", async () => {
    mockStdout("Session is valid.");
    expect(await hungryAuthCheck()).toBe(true);
  });

  it("returns false when auth fails", async () => {
    mockError("Not logged in");
    expect(await hungryAuthCheck()).toBe(false);
  });
});
