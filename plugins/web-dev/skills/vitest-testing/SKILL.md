---
name: vitest-testing
description: Vitest testing patterns for the TypeScript web stack covering test layout, per-environment Vitest projects, Hono route tests with app.request, React component tests with Testing Library and jsdom, mocking fetch and modules, controlling time, Cloudflare Workers tests, and running tests. Use when writing or editing test files (*.test.ts, *.test.tsx), vitest.config.ts, or test helpers and fixtures in a TypeScript project. Not for general TypeScript rules (see typescript-conventions) or production React/Hono code (see react-patterns, hono-patterns).
---

# Vitest Testing

The TDD cycle and the coverage target (80%) are in `core-dev:tdd-testing`. How to run tests and report results is in `core-dev:test-run-discipline`. This skill covers how to write the tests with Vitest.

## Test Tool Stack

| Tool | Purpose |
|---|---|
| **Vitest** | Test runner and assertions (`describe`, `it`, `expect`, `vi`). Needs Node 22.12.0 or later |
| **Hono `app.request`** | API tests without starting a server |
| **@testing-library/react** + **jsdom** | React component tests |
| **@cloudflare/vitest-plugin** | Tests that run inside the Workers runtime with local D1 (Miniflare) |

## Test Organization

- Put the test next to the code it tests: `stale.ts` and `stale.test.ts`, `App.tsx` and `App.test.tsx`.
- Put shared builders and helpers in a `test-helpers.ts` or a `test/` directory next to the code, and JSON fixtures under `test/fixtures/`.
- Name `describe` after the unit under test, and name each `it` after the behavior it checks, not after the implementation.
- When a test checks an acceptance criterion, start the test name with its ID (`AC-033: ...`) so that the criterion can be traced to the test.

```ts
describe("isStale", () => {
  it("AC-033: becomes stale when the last update is at least the threshold old", () => {
    // Arrange
    const now = new Date("2026-11-20T00:00:00Z");

    // Act
    const result = isStale({ lastUpdatedAt: "2026-11-13T00:00:00Z", now, thresholdDays: 7 });

    // Assert
    expect(result).toBe(true);
  });
});
```

## Vitest Projects per Environment

Use `test.projects` in `vitest.config.ts` to give each kind of code the environment it runs in:

```ts
export default defineConfig({
  test: {
    projects: [
      { test: { name: "domain", environment: "node", include: ["src/domain/**/*.test.ts"] } },
      {
        plugins: [react()],
        test: { name: "web", environment: "jsdom", include: ["src/web/**/*.test.{ts,tsx}"] },
      },
      {
        plugins: [cloudflareTest({ wrangler: { configPath: "./wrangler.jsonc" } })],
        test: { name: "worker", include: ["src/worker/**/*.test.ts"] },
      },
    ],
  },
});
```

- Pure logic runs in `node`, React components in `jsdom`, and Worker code inside the Workers runtime.
- Add a comment to each project that says what it tests and what it uses (local D1, mocked `fetch`, fixtures).

## Table Tests

Use `it.each` for the same behavior over several inputs:

```ts
it.each([["abc"], [""], ["-1"], ["0"], [null]])("uses the default for invalid value %s", (value) => {
  expect(staleThresholdDays(value)).toBe(7);
});
```

## Hono Route Tests

Call the app with `app.request` instead of starting a server. Pass fakes through the app factory and the environment as the third argument:

```ts
function setup() {
  const now = () => new Date("2026-10-20T12:00:00.000Z");
  const app = createApp({ createGitHubReader: () => fixtureReader(), now });
  const call = (method: string, path: string, body?: unknown) =>
    app.request(
      path,
      {
        method,
        ...(body === undefined
          ? {}
          : { headers: { "content-type": "application/json" }, body: JSON.stringify(body) }),
      },
      env,
    );
  return { call };
}

it("returns 400 with the field name when the name is empty", async () => {
  const { call } = setup();

  const response = await call("POST", "/api/projects", { name: "" });

  expect(response.status).toBe(400);
  expect(await response.json()).toMatchObject({ error: "invalid_request", field: "name" });
});
```

- Test validation, authentication, and error responses through HTTP, not by calling handler internals.
- Check both the status code and the `error` code in the body.

## React Component Tests

```tsx
afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
});

it("shows the error and a link back to the dashboard", () => {
  vi.spyOn(console, "error").mockImplementation(() => undefined);

  render(
    <MemoryRouter initialEntries={["/broken"]}>
      <ErrorBoundary>
        <Routes>
          <Route path="/broken" element={<Thrower />} />
        </Routes>
      </ErrorBoundary>
    </MemoryRouter>,
  );

  expect(screen.getByRole("alert").textContent).toContain("failed while rendering");
  expect(screen.getByRole("link", { name: "Back to dashboard" }).getAttribute("href")).toBe("/");
});
```

- Render inside `MemoryRouter` with `initialEntries`; put a `renderAt(path)` helper in `test/`.
- Query by role and accessible name (`getByRole("button", { name: ... })`). Use `getByText` only for plain text content.
- Wait for asynchronous updates with `findBy*` or `waitFor`, not with a fixed `setTimeout` delay.
- Call `cleanup()` in `afterEach`.

## Mocking

- Replace `fetch` with `vi.stubGlobal("fetch", vi.fn(...))` and undo it with `vi.unstubAllGlobals()` in `afterEach`.
- Mock part of a module and keep the rest real with `importOriginal`:

```ts
vi.mock("./navigation", async (importOriginal) => ({
  ...(await importOriginal<typeof import("./navigation")>()),
  navigateTo: vi.fn(),
}));
```

- Silence expected `console.error` output with `vi.spyOn(console, "error").mockImplementation(() => undefined)` and restore it with `vi.restoreAllMocks()`.
- Tests do not call external services. Use fixtures or fake implementations injected through the app factory.

## Controlling Time

- Pass a fixed clock (`now: () => new Date("2026-10-20T12:00:00.000Z")`) through dependencies.
- When code under test reads `Date` directly, use `vi.useFakeTimers({ toFake: ["Date"] })` and restore with `vi.useRealTimers()`.

## Common Anti-Patterns

| Anti-Pattern | Fix |
|---|---|
| Starting a real HTTP server for API tests | `app.request(path, init, env)` |
| Calling a real external API from a test | Fixture or injected fake |
| `await new Promise((r) => setTimeout(r, 50))` to wait for the UI | `findBy*` or `waitFor` |
| `new Date()` in code under test with no fixed clock | Inject `now` or use fake timers |
| `vi.stubGlobal` without `vi.unstubAllGlobals()` | Undo in `afterEach` |
| Querying by CSS class or test ID when a role exists | `getByRole` with the accessible name |
| Testing a private helper instead of the behavior | Test through the public function or route |

## Running Tests

```bash
npm test                                   # vitest run (all projects, once)
npx vitest run src/domain/stale.test.ts    # one file
npx vitest run --project web               # one project
npx vitest run -t "AC-033"                 # tests whose name matches
```

Run them through `core-dev:test-run-discipline` (`run-tests.sh npm test`) and report the result as that skill specifies.

## Origin

Written for this plugin (no `~/.claude` source was available). Rules come from the TypeScript web stack (S1, Vitest and Hono testing) in the claude-portfolio-dashboard design documents (`docs/design/otw-tech-stack-research.md` 4.2 and 6.2; `docs/design/otw-template-stack-design.md` 4.4 and 5.1) and from the claude-portfolio-dashboard tests (`vitest.config.ts`, `src/domain/*.test.ts`, `src/worker/admin/routes.test.ts`, `src/web/ErrorBoundary.test.tsx`, `src/web/auth/AccountMenu.test.tsx`, `src/web/test/render.tsx`). AC IDs in test names follow the `AC-001` numbering of `.claude/rules/dashboard-contract.md` 4. The section layout follows `dotnet-dev:dotnet-testing`.
