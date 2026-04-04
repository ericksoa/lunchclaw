// Simple keyword extraction from casual food requests.
// "hungry, something light with fish maybe" → ["light", "fish"]

const STOPWORDS = new Set([
  "i", "im", "am", "hungry", "want", "something", "maybe",
  "like", "some", "need", "food", "get", "me", "please",
  "could", "can", "you", "find", "order", "grab", "the",
  "a", "an", "with", "and", "or", "but", "for", "really",
  "very", "just", "kinda", "sorta", "idk", "hmm", "feed",
]);

const HEALTHY_DEFAULTS = ["healthy", "bowl", "salad"];

export function extractKeywords(text: string): string[] {
  const words = text
    .toLowerCase()
    .replace(/[^a-z\s]/g, "")
    .split(/\s+/)
    .filter((w) => w.length > 2 && !STOPWORDS.has(w));

  return words.length > 0 ? words : HEALTHY_DEFAULTS;
}
