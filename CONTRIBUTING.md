# Contributing to LunchClaw

## Language

All source code must be **TypeScript**. No `.js` files in `sandbox-app/` — ever.

## Development

```bash
cd sandbox-app
npm install
npm run build          # compile once
npm run dev            # watch mode
npm test               # run tests
npm run test:coverage  # run tests with coverage
```

## Tests

Every new feature needs tests. We use Vitest.

- Tests live alongside source as `*.test.ts` files
- Run the full suite before pushing: `npm test`

## Code Style

- Strict TypeScript (`strict: true` in tsconfig)
- ESM (`"type": "module"` in package.json)
- Node 22+
