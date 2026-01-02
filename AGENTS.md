# Repository Guidelines

## Project Structure

- `lua/mdbuf/`: Neovim plugin implementation (Lua modules).
- `plugin/mdbuf.vim`: Vimscript entrypoint that registers commands.
- `server/`: TypeScript render server (Playwright + marked).
  - `server/src/`: Source of the server and CLI.
  - `server/dist/`: Build output (generated; avoid hand-editing).
- `docs/`: Design notes and architecture (`docs/DESIGN.md`).

## Build, Test, and Development Commands

Run Node tasks from `server/`:

- `npm ci`: Install exact dependencies for reproducible builds (CI parity).
- `npm run build`: Compile TypeScript to `server/dist/` via `tsc`.
- `npm run dev`: Run the server from source with `tsx` (fast iteration).
- `npm run render -- <in.md> <out.png>`: Render Markdown to a PNG using the CLI.
- `npm run lint` / `npm run lint:fix`: Lint (and optionally fix) `server/src/` with Biome.
- `npm run format`: Format `server/src/` with Biome.

Lua lint (repo root):

- `luacheck lua/ --globals vim`: Lint plugin code (matches CI).

## Coding Style & Naming Conventions

- Lua: 2-space indentation; keep lines ≤120 chars (see `.luacheckrc`). Modules live under `lua/mdbuf/` and are required as `require('mdbuf.<name>')`.
- TypeScript: formatted by Biome (2 spaces, single quotes, line width 100). Prefer `server/src/*.ts` edits and regenerate `server/dist/` via `npm run build`.

## Testing Guidelines

- There is no unit test suite currently. CI validates:
  - TypeScript lint (`npm run lint`) and typecheck (`npx tsc --noEmit`).
  - A render smoke test via the CLI (requires Playwright + Chromium).
- Local smoke test:
  - `cd server && npx playwright install chromium`
  - `npm run render -- ../README.md /tmp/mdbuf.png`
  - In Neovim, open a Markdown file and try `:MdbufOpen` / `:MdbufRefresh`.

## Commit & Pull Request Guidelines

- Commits follow an imperative, concise subject line (examples: “Fix …”, “Add …”); include issue/PR references when relevant (e.g., `(#7)`).
- PRs should include: a clear description, reproduction/verification steps, and any UI/UX notes (screenshots/GIFs when behavior changes). Ensure CI passes and avoid committing generated artifacts unintentionally.
