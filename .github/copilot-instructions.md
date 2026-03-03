# Copilot Instructions

## Project Overview

**Web Speed Hackathon 2025 — AREMA** is a performance optimization competition. The codebase is a fictional video streaming service ("AREMA") that participants tune for maximum Lighthouse scores. All code in the repository is fair game to modify.

## Commands

```bash
# Install dependencies
corepack enable pnpm && pnpm install

# Start server (serves at http://localhost:8000)
pnpm run start

# Build client only
pnpm run build

# Run all Playwright VRT/E2E tests
pnpm run test

# Run tests against a remote URL
E2E_BASE_URL=https://your-app.example.com pnpm run test

# Install Playwright Chromium (required before first test run)
pnpm --filter "@wsh-2025/test" exec playwright install chromium

# Format a specific workspace
pnpm --filter "@wsh-2025/client" run format
pnpm --filter "@wsh-2025/server" run format

# Reset database to initial seed data
pnpm --filter "@wsh-2025/server" run database:reset

# Run DB migrations (after schema changes)
pnpm --filter "@wsh-2025/server" run database:migrate
```

> Build orchestration uses **wireit** — task results are cached in `.wireit/`. Delete the cache to force a full rebuild.

## Architecture

### Monorepo (pnpm workspaces)

| Workspace | Purpose |
|---|---|
| `workspaces/client` | React 19 SPA, bundled with Webpack + Babel |
| `workspaces/server` | Fastify 5 server: API, SSR, HLS streaming |
| `workspaces/schema` | Shared API + DB schemas |
| `workspaces/configs` | Shared ESLint, Prettier, TypeScript configs |
| `workspaces/test` | Playwright E2E + Visual Regression Tests |

### Server (`workspaces/server`)

- **Fastify 5** serves three main concerns registered as plugins: `registerApi` (`/api/*`), `registerStreams` (HLS), `registerSsr` (all other routes)
- **Database**: Drizzle ORM + libSQL over a SQLite file (`database.sqlite`). On startup, the DB is **copied to a temp file** before use — the original file is the seed source.
- **SSR**: The server calls React's `renderToString` to pre-run route loaders (populating the Zustand store), then sends a minimal HTML shell with `window.__staticRouterHydrationData` inlined. The actual HTML content is rendered client-side via `hydrateRoot`.
- **HLS Streams**: Playlists are generated dynamically at `/streams/episode/:episodeId/playlist.m3u8`. Time is stored as `HH:mm:ss` in SQLite and resolved to today's date at runtime (competition quirk).
- **Competition requirement**: `POST /api/initialize` must reset the DB to initial state.

### Client (`workspaces/client`)

- **React 19** + **React Router 7** (file-based lazy routes via `createRoutes`)
- **State management**: Zustand vanilla store composed of feature slices using `@dhmk/zustand-lens`. The store is created once and injected via `zustand-di` context (`StoreProvider` / `useStore`).
- **API layer**: `@better-fetch/fetch` with a typed schema (`workspaces/schema/src/api/schema.ts`). All requests pass through `schedulePlugin`, which delays them via `scheduler.postTask` (or `queueMicrotask` as fallback) — this is an intentional performance bottleneck to tune.
- **Styling**: **UnoCSS** (runtime mode) with `preset-wind3` (Tailwind-compatible utility classes). Styles are generated at runtime in the browser.
- **Video**: `shaka-player` (patched in `patches/shaka-player.patch`) for HLS playback; `@ffmpeg/ffmpeg` (WASM) for client-side video processing.
- **Routing**: Each page is code-split with `p-min-delay` (forces minimum 1000ms load time — a deliberate bottleneck).

### Schema (`workspaces/schema`)

- OpenAPI types defined in `src/openapi/schema.ts` (Zod + `zod-openapi`)
- Compiled to validator functions in `src/api/schema.ts` using `@sinclair/typemap` — different validators per entity: TypeBox for channels/episodes, Valibot for series/timetable/programs, Zod for auth
- DB schema in `src/database/schema.ts` (Drizzle + SQLite)

## Key Conventions

### Feature structure (client)
Each feature under `src/features/<name>/` follows the same layout:
```
components/   React components
constants/    Enums and constants
hooks/        React hooks (typically call useStore)
logics/       Pure functions / business logic
services/     API call wrappers using @better-fetch/fetch
stores/       Zustand lens slice (createXxxStoreSlice)
```

### Adding a new API endpoint
1. Define the Zod/OpenAPI schema in `workspaces/schema/src/openapi/schema.ts`
2. Export a compiled validator in `workspaces/schema/src/api/schema.ts`
3. Implement the route handler in `workspaces/server/src/`
4. Add to the `$fetch` schema in the client service file

### Linting
ESLint enforces `eslint-plugin-sort` — **imports and object properties must be sorted alphabetically**. Run `format` before committing.

### Competition constraints
- VRT snapshots (in `workspaces/test/src/`) must continue to pass — avoid layout/visual changes
- The app must work in the latest Google Chrome (used for scoring)
- Lighthouse Performance metrics drive the score: FCP, LCP, TBT, CLS, Speed Index
