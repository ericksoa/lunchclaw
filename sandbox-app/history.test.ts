import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { mkdtempSync, rmSync, readFileSync, existsSync, writeFileSync } from "fs";
import { join } from "path";
import { tmpdir } from "os";
import {
  setPaths,
  recordOrder,
  getRecentOrders,
  getRecentRestaurants,
} from "./history.js";

describe("history", () => {
  let tempDir: string;
  let memoryDir: string;
  let historyFile: string;

  beforeEach(() => {
    tempDir = mkdtempSync(join(tmpdir(), "lunchclaw-hist-"));
    memoryDir = join(tempDir, "memory");
    historyFile = join(tempDir, "order-history.json");
    setPaths({ memoryDir, historyFile });
  });

  afterEach(() => {
    rmSync(tempDir, { recursive: true, force: true });
  });

  describe("recordOrder", () => {
    it("creates history file with first order", () => {
      recordOrder({ item: "Salmon Bowl", restaurant: "Sweetgreen", price: "14.95" });
      expect(existsSync(historyFile)).toBe(true);
      const history = JSON.parse(readFileSync(historyFile, "utf-8"));
      expect(history).toHaveLength(1);
      expect(history[0].item).toBe("Salmon Bowl");
      expect(history[0].restaurant).toBe("Sweetgreen");
      expect(history[0].timestamp).toBeTruthy();
    });

    it("appends to existing history", () => {
      recordOrder({ item: "Salmon Bowl", restaurant: "Sweetgreen", price: "14.95" });
      recordOrder({ item: "Chicken Wrap", restaurant: "Cava", price: "12.50" });
      const history = JSON.parse(readFileSync(historyFile, "utf-8"));
      expect(history).toHaveLength(2);
      expect(history[1].item).toBe("Chicken Wrap");
    });

    it("creates a daily memory note", () => {
      recordOrder({ item: "Salmon Bowl", restaurant: "Sweetgreen", price: "14.95" });
      const today = new Date().toISOString().split("T")[0];
      const memoryFile = join(memoryDir, `${today}.md`);
      expect(existsSync(memoryFile)).toBe(true);
      const content = readFileSync(memoryFile, "utf-8");
      expect(content).toContain("## Lunch Order");
      expect(content).toContain("Salmon Bowl");
      expect(content).toContain("Sweetgreen");
    });

    it("appends to existing memory note for same day", () => {
      recordOrder({ item: "Salmon Bowl", restaurant: "Sweetgreen", price: "14.95" });
      recordOrder({ item: "Chicken Wrap", restaurant: "Cava", price: "12.50" });
      const today = new Date().toISOString().split("T")[0];
      const memoryFile = join(memoryDir, `${today}.md`);
      const content = readFileSync(memoryFile, "utf-8");
      expect(content).toContain("Salmon Bowl");
      expect(content).toContain("Chicken Wrap");
    });

    it("includes eta and healthNote when provided", () => {
      recordOrder({
        item: "Poke Bowl",
        restaurant: "Pokeworks",
        price: "16.00",
        eta: "25 min",
        healthNote: "high protein, fresh fish",
      });
      const today = new Date().toISOString().split("T")[0];
      const memoryFile = join(memoryDir, `${today}.md`);
      const content = readFileSync(memoryFile, "utf-8");
      expect(content).toContain("25 min");
      expect(content).toContain("high protein, fresh fish");
    });

    it("uses defaults for missing eta and healthNote", () => {
      recordOrder({ item: "Salad", restaurant: "Place", price: "10" });
      const today = new Date().toISOString().split("T")[0];
      const memoryFile = join(memoryDir, `${today}.md`);
      const content = readFileSync(memoryFile, "utf-8");
      expect(content).toContain("~30 min");
    });
  });

  describe("getRecentOrders", () => {
    it("returns empty array when no history exists", () => {
      expect(getRecentOrders(7)).toEqual([]);
    });

    it("returns orders from within the time window", () => {
      recordOrder({ item: "Bowl", restaurant: "A", price: "10" });
      const recent = getRecentOrders(7);
      expect(recent).toHaveLength(1);
      expect(recent[0].item).toBe("Bowl");
    });

    it("excludes orders older than the time window", () => {
      // Write a fake old order directly
      const oldOrder = {
        item: "Old Salad",
        restaurant: "OldPlace",
        price: "8",
        timestamp: new Date(Date.now() - 10 * 24 * 60 * 60 * 1000).toISOString(),
      };
      writeFileSync(historyFile, JSON.stringify([oldOrder]));

      const recent = getRecentOrders(7);
      expect(recent).toHaveLength(0);
    });

    it("handles corrupted history file", () => {
      writeFileSync(historyFile, "not json{{{");
      expect(getRecentOrders(7)).toEqual([]);
    });
  });

  describe("getRecentRestaurants", () => {
    it("returns empty array when no history exists", () => {
      expect(getRecentRestaurants(5)).toEqual([]);
    });

    it("returns unique restaurants in reverse chronological order", () => {
      recordOrder({ item: "A", restaurant: "Sweetgreen", price: "10" });
      recordOrder({ item: "B", restaurant: "Cava", price: "12" });
      recordOrder({ item: "C", restaurant: "Sweetgreen", price: "11" });
      recordOrder({ item: "D", restaurant: "Chipotle", price: "9" });

      const restaurants = getRecentRestaurants(5);
      expect(restaurants).toEqual(["Chipotle", "Sweetgreen", "Cava"]);
    });

    it("respects the count limit", () => {
      recordOrder({ item: "A", restaurant: "Place1", price: "10" });
      recordOrder({ item: "B", restaurant: "Place2", price: "10" });
      recordOrder({ item: "C", restaurant: "Place3", price: "10" });

      const restaurants = getRecentRestaurants(2);
      expect(restaurants).toHaveLength(2);
      expect(restaurants).toEqual(["Place3", "Place2"]);
    });
  });
});
