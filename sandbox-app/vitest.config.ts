import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    include: ["*.test.ts"],
    coverage: {
      provider: "v8",
      include: ["*.ts"],
      exclude: [
        "*.test.ts",
        "vitest.config.ts",
        "bot.ts", // Telegram bot entry point — requires running bot, tested in E2E
      ],
      reporter: ["text", "text-summary"],
      thresholds: {
        statements: 95,
        branches: 90,
        functions: 95,
        lines: 95,
      },
    },
  },
});
