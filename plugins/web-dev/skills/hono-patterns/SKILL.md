---
name: hono-patterns
description: Hono API patterns for the TypeScript web stack covering the app factory with injected dependencies, typed bindings and variables, router mounting, middleware order, input validation, error responses, Web-standard runtime constraints, and Cloudflare Workers/D1 usage. Use when writing or editing Hono server code (route handlers, middleware, the Worker or server entry point, wrangler.jsonc). Not for general TypeScript rules (see typescript-conventions), React code (see react-patterns), or test code (see vitest-testing).
---

# Hono Patterns

Hono has no dependencies and uses only Web-standard APIs. The same code runs on Cloudflare Workers, AWS Lambda (through the Lambda adapter), and Node.js (through the Node adapter).

## App Factory with Injected Dependencies

Create the app in a function that takes its dependencies (clock, `fetch`, external clients). Production passes default dependencies; tests pass fakes. Do not read the current time or call external services directly inside handlers.

```ts
export type AppDeps = {
  now: () => Date;
  createGitHubReader: (env: AppEnv) => GitHubReader;
};

export const defaultDeps: AppDeps = {
  now: () => new Date(),
  createGitHubReader: (env) => createGitHubReaderForEnv(env, () => new Date()),
};

export function createApp(
  deps: AppDeps = defaultDeps,
): Hono<{ Bindings: AppEnv; Variables: AppVariables }> {
  const app = new Hono<{ Bindings: AppEnv; Variables: AppVariables }>();
  // middleware, routes, notFound, onError
  return app;
}

const app = createApp();

export default {
  fetch: app.fetch,
  scheduled,
} satisfies ExportedHandler<AppEnv>;
```

- Type `Bindings` (environment variables and platform bindings, read with `c.env`) and `Variables` (values set by middleware, read with `c.get`) through the `Hono` generics. Do not read `process.env`.
- Secrets are not written in `wrangler.jsonc`, so they do not appear in the generated `worker-configuration.d.ts`. Declare their types in a separate type and intersect it into the `Bindings` type.

## Routers and Middleware

- Build each area's routes in its own function (`createAdminRoutes(deps)`, `createReadRoutes(deps)`) and mount it with `app.route("/api", ...)`. Add one `app.route` line per router.
- Register middleware with `app.use(path, middleware)` in an explicit order, and write the order and the reason in a comment above it (for example: response headers, health check, same-origin check, authentication, authorization, routers).
- Routes that must work without authentication (a health check) are registered before the authentication middleware; everything after it receives only authenticated requests.
- Reject state-changing requests (`POST`, `PUT`, `PATCH`, `DELETE`) from other origins in middleware before authentication.

## Input Validation

Validate every request at the route boundary before it reaches business logic. On failure, throw an `HTTPException` that carries the full response:

```ts
export function invalid(field: string, message: string): HTTPException {
  const body: ValidationErrorResponse = { error: "invalid_request", field, message };
  return new HTTPException(400, { res: Response.json(body, { status: 400 }) });
}
```

- Return 400 with `error`, the `field` name, and a `message` for invalid input.
- Return 415 when a JSON endpoint receives a `Content-Type` other than `application/json` (ignore parameters such as `charset`, compare case-insensitively).
- Return 413 when the body exceeds a fixed byte limit. Read the body as a stream and stop at the limit, so that a request without `Content-Length` cannot make the server read an unlimited body.
- Parse path parameters strictly (for example, accept only positive integers for IDs) and return 404 or 400 for anything else.
- Define each response body as a named type in the module shared with the client.

## Error Responses

```ts
app.notFound((c) => c.json({ error: "not_found" }, 404));

app.onError((error, c) => {
  if (error instanceof HTTPException) {
    return error.getResponse();
  }
  return c.json({ error: "internal_error" }, 500);
});
```

- API paths that do not exist return a JSON 404, not the SPA's `index.html`.
- Unexpected exceptions return a generic 500 body. Do not put stack traces, SQL errors, upstream error text, or internal paths in the response.
- Return the same 404 for a resource that does not exist and for one the caller may not see, so that the response does not reveal which resources exist.
- Use stable machine-readable `error` codes (`invalid_request`, `not_found`, `internal_error`) that the client can switch on.

## Web-Standard Runtime

- Use only Web-standard APIs in server code: `fetch`, `Request`, `Response`, `URL`, `Headers`, `crypto.subtle`, streams.
- Do not import `node:*` in code that runs on Workers. Enforce it with ESLint `no-restricted-imports` for those directories (see `typescript-conventions`).

## Cloudflare Workers and D1

- Run D1 migrations locally with `wrangler d1 migrations apply <db> --local`. Without `--local`, the command changes the remote database.
- Regenerate binding types with `wrangler types` after changing `wrangler.jsonc`.
- Do not deploy from a Claude Code cloud session. The deployment hosts are not on the session's network allowlist; deploy from outside the cloud session.

## Anti-Patterns to Avoid

| Anti-Pattern | Fix |
|---|---|
| `new Date()` or global `fetch` inside a handler | Take them from the injected `deps` |
| `const app = new Hono()` at module top level with no factory | `createApp(deps)` so that tests can inject fakes |
| Reading `process.env` | Read `c.env` with typed `Bindings` |
| Returning `err.message` or a stack trace in a 500 | Generic `{ error: "internal_error" }` |
| Checking input deep inside business logic | Validate at the route and throw `HTTPException` |
| `await c.req.json()` with no size or content-type check | Check `Content-Type` and read with a byte limit |
| `import fs from "node:fs"` in Worker code | Web-standard APIs only |
| `wrangler d1 migrations apply` without `--local` during development | Add `--local` |

## Origin

Written for this plugin (no `~/.claude` source was available). Rules come from the TypeScript web stack (S1, Hono) in the claude-portfolio-dashboard design documents (`docs/design/otw-tech-stack-research.md` 4.2, 5.2, 6.2; `docs/design/otw-template-stack-design.md` 4.4 for "do not deploy from the cloud session") and from the claude-portfolio-dashboard Worker (`src/worker/index.ts`, `src/worker/admin/routes.ts`, `src/worker/admin/validation.ts`, `eslint.config.js`). The section layout follows `dotnet-dev:aspnet-patterns`.
