---
name: typescript-conventions
description: TypeScript coding conventions for the TypeScript web stack (React + Vite, Hono, Vitest) covering compiler options, project references, type safety, module syntax, pure domain modules, ESLint, Prettier, and npm usage. Use when writing or editing TypeScript files (*.ts, *.tsx), tsconfig*.json, eslint.config.js, or package.json in a Node/TypeScript project. Not for React components (see react-patterns), Hono routes and middleware (see hono-patterns), or test code (see vitest-testing).
---

# TypeScript Coding Conventions

Language-agnostic rules (naming, file size, immutability, error handling, input validation) are in `core-dev:coding-standards`. This skill adds the TypeScript-specific rules.

## Package and Tooling

- Use npm. Commit `package-lock.json` and install with `npm ci`.
- Do not use bun in a Claude Code cloud session. The Claude Code documentation reviewed for the stack design lists a known proxy compatibility problem between bun and the session's network proxy; recheck it against the current documentation before relaxing this rule.
- Set `"type": "module"` in `package.json` and write ES modules only.
- Declare the Node version in `engines.node`. Vitest needs Node 22.12.0 or later (the requirement recorded in the stack design; a newer Vitest major version can raise it); check with `node -v`.
- Put every check command in `package.json` scripts so that local runs and CI call the same commands:

```json
{
  "scripts": {
    "typecheck": "tsc -b",
    "lint": "eslint .",
    "format": "prettier --write .",
    "format:check": "prettier --check .",
    "test": "vitest run"
  }
}
```

- The full pre-PR check is `npm run typecheck`, `npm run lint`, `npm test`, and `npm audit --audit-level=high`, in that order.

## Compiler Options

Keep these options in a shared `tsconfig.base.json`:

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "moduleDetection": "force",
    "verbatimModuleSyntax": true,
    "noEmit": true,
    "skipLibCheck": true,
    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true,
    "noUncheckedIndexedAccess": true
  }
}
```

- Do not turn off `strict` or any of the options above to make an error go away.
- `noUncheckedIndexedAccess` makes `array[i]` and `record[key]` return `T | undefined`. Handle the `undefined` case; do not add `!`.
- `verbatimModuleSyntax` requires type-only imports to be written as `import type { X }` or `import { type X }`.

## Project References per Runtime

Code that runs in different runtimes gets its own `tsconfig.*.json` with its own `lib` and `types`, so that browser APIs cannot be used in server code and the reverse:

| File | Includes | `lib` / `types` |
|---|---|---|
| `tsconfig.web.json` | `src/web` | `["ES2022", "DOM", "DOM.Iterable"]`, `"jsx": "react-jsx"`, `types: ["vite/client"]` |
| `tsconfig.worker.json` | server code | `["ES2022"]`, the runtime's types (for Cloudflare Workers: `@cloudflare/workers-types`) |
| `tsconfig.domain.json` | pure domain code | `["ES2022"]`, `types: []` |
| `tsconfig.node.json` | `vite.config.ts`, `vitest.config.ts` | `["ES2023"]`, `types: []` |

The root `tsconfig.json` has `"files": []` and lists each file in `references`. Type-check with `tsc -b`.

## Type Safety

- Do not use `any`. Use `unknown` for values whose shape is not known yet, and narrow with `typeof`, `instanceof`, or a type guard.
- Caught errors are `unknown`. Narrow before reading properties:

```ts
.catch((error: unknown) => {
  const message = error instanceof Error ? error.message : String(error);
});
```

- Check external data (HTTP response bodies, JSON files, environment variables) with a type guard instead of an `as` cast:

```ts
function isRepositoryRef(value: unknown): value is RepositoryRef {
  return isObject(value) && isString(value.owner) && isString(value.name);
}

export async function getJson<T>(path: string, guard: (value: unknown) => value is T): Promise<T> {
  const body: unknown = await (await fetch(path)).json();
  if (!guard(body)) {
    throw new ApiError("unexpected response shape");
  }
  return body;
}
```

- Model states that have different data as a discriminated union with a `kind` field, not as several optional fields:

```ts
export type ApiData<T> =
  | { kind: "loading" }
  | { kind: "failed"; message: string }
  | { kind: "loaded"; data: T };
```

- Use `satisfies` to check an object against a type without widening it (for example `export default { fetch: app.fetch } satisfies ExportedHandler<Env>`).
- Do not use `@ts-ignore`. Use `@ts-expect-error` or `eslint-disable-next-line` only with a comment on the same or preceding line that states the reason.
- Do not use the non-null assertion `!` to silence a possible `undefined`; check the value and throw or return early.

## Pure Domain Modules

Keep business rules (state derivation, calculations, validation rules) in a module that does no I/O and does not read the current time:

- The current time is a parameter (`now: Date`), not `Date.now()` or `new Date()` without arguments.
- No `fetch`, storage, database, or framework imports (`hono`, `react`, `node:*`, runtime-specific modules).
- Enforce it with ESLint `no-restricted-globals`, `no-restricted-properties`, and `no-restricted-syntax` rules scoped to the domain directory, and with `types: []` in its tsconfig.

```js
{
  files: ["src/domain/**/*.ts"],
  ignores: ["src/domain/**/*.test.ts"],
  rules: {
    "no-restricted-properties": [
      "error",
      { object: "Date", property: "now", message: "Pass the current time as an argument." },
    ],
    "no-restricted-syntax": [
      "error",
      {
        selector: "NewExpression[callee.name='Date'][arguments.length=0]",
        message: "Pass the current time as an argument.",
      },
    ],
  },
}
```

Code that runs on a Web-standard runtime (Cloudflare Workers, the browser) must not import `node:*`. Enforce it with `"no-restricted-imports": ["error", { patterns: ["node:*"] }]` for those directories.

## Comments

- Put a `/** ... */` comment on exported functions, types, and constants that states what it is for and any rule it implements.
- When code implements an acceptance criterion or an Issue, cite it in the comment (`AC-007`, `#12`).

## Linting and Formatting

- ESLint uses the flat config `eslint.config.js` with `js.configs.recommended` and `tseslint.configs.recommended` (`typescript-eslint`), and ignores build output (`dist/`) and generated directories.
- Prettier formats all files. Keep the configuration in `.prettierrc.json` (the reference project uses `{ "printWidth": 100 }`). Do not hand-format against Prettier.

## Anti-Patterns to Avoid

| Anti-Pattern | Fix |
|---|---|
| `any` in parameters, return types, or casts | `unknown` plus narrowing, or a precise type |
| `value as T` on external data | A type guard `(value: unknown) => value is T` |
| `array[0]!` | Check for `undefined` and handle it |
| `import { SomeType }` used only as a type | `import type { SomeType }` |
| `Date.now()` inside business logic | Pass `now` as an argument |
| Several optional fields describing one state | Discriminated union with `kind` |
| `bun install` / `bun run` | `npm ci` / `npm run` |
| Weakening `tsconfig` options to pass `tsc` | Fix the code |

## Recommended Hooks (configure in your project settings)

These are suggestions to wire up as PostToolUse/Stop hooks in your own settings, not something this plugin installs:

- After editing `.ts`/`.tsx` files: run `npx prettier --write <file>`.
- After editing `.ts`/`.tsx`/`tsconfig*.json` files: run `npm run typecheck`.
- Before ending a session with broad TypeScript changes: run `npm run lint` and `npm test`.

## Origin

Written for this plugin (no `~/.claude` source was available). Rules come from the stack design for the TypeScript web stack (S1) and from the TypeScript / React / Hono / Vitest codebase of claude-portfolio-dashboard (its tsconfig, ESLint, Prettier, and package configuration and its API client code). The section layout follows `dotnet-dev:dotnet-conventions`.
