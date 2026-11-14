---
name: react-patterns
description: React + Vite patterns for the TypeScript web stack covering project setup, components, data loading with cancellation, loading/failure/loaded states, error boundaries, typed API clients, accessible status display, and client-side security. Use when writing or editing React components or hooks (*.tsx, src/web/**), vite.config.ts, or index.html. Not for general TypeScript rules (see typescript-conventions), server routes (see hono-patterns), or test code (see vitest-testing).
---

# React + Vite Patterns

## Project Setup

- Build with Vite and `@vitejs/plugin-react`. The SPA's tsconfig uses `"jsx": "react-jsx"`, `lib: ["ES2022", "DOM", "DOM.Iterable"]`, and `types: ["vite/client"]`.
- The entry point checks that the root element exists, then renders inside `StrictMode` and the router:

```tsx
const container = document.getElementById("root");
if (!container) {
  throw new Error("#root is missing from index.html");
}

createRoot(container).render(
  <StrictMode>
    <BrowserRouter>
      <App />
    </BrowserRouter>
  </StrictMode>,
);
```

- Keep `BrowserRouter` in the entry point only, so that tests can render `<App />` inside `MemoryRouter`.

## Components

- Write function components with named exports (`export function IssueList(...)`). Use a class only for an error boundary, which React requires.
- Type props with an `interface` or `type`; type children as `ReactNode`.
- Keep data fetching in hooks or page components, and keep presentational components free of `fetch`.
- Move logic that does not need React (sorting, formatting, state derivation) into plain `.ts` modules and test it without rendering.

## Data Loading

Load data in a hook that cancels the request when the component unmounts or the input changes, and that never shows a stale result:

```tsx
export type ApiData<T> =
  | { kind: "loading" }
  | { kind: "failed"; message: string }
  | { kind: "loaded"; data: T };

export function useApiData<T>(load: (signal: AbortSignal) => Promise<T>, key: string): ApiData<T> {
  const [state, setState] = useState<{ key: string; value: ApiData<T> }>({
    key,
    value: { kind: "loading" },
  });

  useEffect(() => {
    const controller = new AbortController();
    load(controller.signal)
      .then((data) => {
        if (!controller.signal.aborted) setState({ key, value: { kind: "loaded", data } });
      })
      .catch((error: unknown) => {
        if (!controller.signal.aborted) {
          const message = error instanceof Error ? error.message : String(error);
          setState({ key, value: { kind: "failed", message } });
        }
      });
    // `load` is left out on purpose: callers pass a new function on every render, so listing it would refetch on every render. The request is keyed by `key`.
    return () => controller.abort();
  }, [key]);

  return state.key === key ? state.value : { kind: "loading" };
}
```

- Render all three states. Do not show a failed request as an empty list or zero; show the error.
- Pass the `AbortSignal` through to `fetch`.
- When a hook's dependency array leaves out a value on purpose, add a comment that says why.

## API Client

- Put HTTP calls in one module (for example `src/web/api.ts`) with one function per endpoint that returns a typed response.
- Share request and response types between the server and the client from one module (for example `src/api-types.ts`).
- Check every response body with a type guard before returning it (see `typescript-conventions`).
- Convert every failure (network error, non-2xx status, invalid body) into one error class with a `kind` field, so that the UI can choose the message by `kind`.

## Error Boundary

- Wrap the routed content in an error boundary so that an exception while rendering one page does not blank the whole app.
- Show the error message and a link back to a working page. Reset the boundary when the route changes.

```tsx
class Boundary extends Component<BoundaryProps, BoundaryState> {
  state: BoundaryState = { error: null, resetKey: this.props.resetKey };

  static getDerivedStateFromError(error: unknown): Partial<BoundaryState> {
    return { error: error instanceof Error ? error : new Error(String(error)) };
  }

  static getDerivedStateFromProps(props: BoundaryProps, state: BoundaryState) {
    return props.resetKey === state.resetKey ? null : { error: null, resetKey: props.resetKey };
  }
}
```

## Accessibility

- Use elements and roles that tests can query by role and accessible name: `<button>` for actions, `<a>`/`Link` for navigation, `role="alert"` for errors.
- Give icon-only buttons an accessible name (`aria-label`).
- Do not show a status by color alone. Add an icon and a text label next to the color (for example a warning icon and the words "needs attention").

## Client-Side Security

- Do not use `dangerouslySetInnerHTML` with data that came from a user or an API. Render text through JSX so that React escapes it.
- Do not put secrets in client code or in `VITE_`-prefixed environment variables. Everything in the bundle is public.
- Treat text from external systems (Issue titles, error messages from upstream APIs) as untrusted when displaying it.

## Anti-Patterns to Avoid

| Anti-Pattern | Fix |
|---|---|
| `useEffect` fetch without cleanup | Abort with `AbortController` in the cleanup function |
| Setting state after the request was aborted | Check `signal.aborted` before `setState` |
| `catch` that leaves the list empty | Render the `failed` state with the message |
| `fetch` inside presentational components | Move it to a hook or the API client module |
| `BrowserRouter` inside `App` | Keep it in the entry point; tests use `MemoryRouter` |
| `<div onClick>` as a button | `<button type="button">` |
| Status shown only by color | Icon plus text |

## Origin

Written for this plugin (no `~/.claude` source was available). Rules come from the stack design for the TypeScript web stack (S1, React + Vite) and from the SPA of the TypeScript / React / Hono / Vitest codebase of claude-portfolio-dashboard (entry point, data-loading hook, API client, error boundary, and the TypeScript and Vite configuration). The security items follow the output-encoding and secret-management items of `dotnet-dev:dotnet-security` and `dotnet-dev:dotnet-reviewer`. The research document notes that the React official documentation was not retrieved; the rules here are limited to what the reference codebase does.
