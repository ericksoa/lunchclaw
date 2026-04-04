import { describe, it, expect } from "vitest";
import { extractKeywords } from "./keywords.js";

describe("extractKeywords", () => {
  it("extracts meaningful food words from a casual request", () => {
    const result = extractKeywords("hungry, something light with fish maybe");
    expect(result).toContain("light");
    expect(result).toContain("fish");
    expect(result).not.toContain("hungry");
    expect(result).not.toContain("something");
    expect(result).not.toContain("maybe");
  });

  it("strips punctuation", () => {
    const result = extractKeywords("I want salmon! And rice?");
    expect(result).toContain("salmon");
    expect(result).toContain("rice");
  });

  it("filters short words (< 3 chars)", () => {
    const result = extractKeywords("go to a Thai place");
    expect(result).not.toContain("go");
    expect(result).not.toContain("to");
    expect(result).toContain("thai");
    expect(result).toContain("place");
  });

  it("returns healthy defaults when no meaningful words found", () => {
    const result = extractKeywords("I'm hungry, feed me something");
    expect(result).toEqual(["healthy", "bowl", "salad"]);
  });

  it("returns healthy defaults for empty string", () => {
    const result = extractKeywords("");
    expect(result).toEqual(["healthy", "bowl", "salad"]);
  });

  it("handles cuisine types", () => {
    const result = extractKeywords("something japanese or korean");
    expect(result).toContain("japanese");
    expect(result).toContain("korean");
  });

  it("handles specific dish names", () => {
    const result = extractKeywords("poke bowl with salmon");
    expect(result).toContain("poke");
    expect(result).toContain("bowl");
    expect(result).toContain("salmon");
  });

  it("is case-insensitive", () => {
    const result = extractKeywords("CHICKEN Salad");
    expect(result).toContain("chicken");
    expect(result).toContain("salad");
  });
});
