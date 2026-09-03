---
name: dotnet-conventions
description: C# and .NET coding conventions covering nullable reference types, immutability, async/await, error handling, guard clauses, and formatting. Use when writing or editing C# files (*.cs), *.csproj, *.sln, or any .NET project code. Not for ASP.NET Core/EF Core-specific patterns (see aspnet-patterns), security (see dotnet-security), or test code (see dotnet-testing).
---

# C# Coding Conventions

## Standards

- Follow current .NET conventions and enable nullable reference types.
- Prefer explicit access modifiers on public and internal APIs.
- Keep files aligned with the primary type they define.

## Types and Models

- Prefer `record` or `record struct` for immutable value-like models.
- Use `class` for entities or types with identity and lifecycle.
- Use `interface` for service boundaries and abstractions.
- Avoid `dynamic` in application code; prefer generics or explicit models.

```csharp
public sealed record UserDto(Guid Id, string Email);

public interface IUserRepository
{
    Task<UserDto?> FindByIdAsync(Guid id, CancellationToken cancellationToken);
}
```

## Immutability

- Prefer `init` setters, constructor parameters, and immutable collections for shared state.
- Do not mutate input models in-place when producing updated state.

```csharp
public sealed record PersonProfile(string Name, string Email);

public static PersonProfile Rename(PersonProfile profile, string name) =>
    profile with { Name = name };
```

## Async and Error Handling

- Prefer `async`/`await` over blocking calls like `.Result` or `.Wait()`.
- Pass `CancellationToken` through public async APIs.
- Throw specific exceptions and log with structured properties.

```csharp
public async Task<Order> LoadOrderAsync(
    Guid orderId,
    CancellationToken cancellationToken)
{
    try
    {
        return await repository.FindAsync(orderId, cancellationToken)
            ?? throw new InvalidOperationException($"Order {orderId} was not found.");
    }
    catch (Exception ex)
    {
        logger.LogError(ex, "Failed to load order {OrderId}", orderId);
        throw;
    }
}
```

## Guard Clauses

Use early returns and explicit validation instead of deep nesting.

```csharp
public async Task<ProcessResult> ProcessPaymentAsync(
    PaymentRequest request,
    CancellationToken cancellationToken)
{
    ArgumentNullException.ThrowIfNull(request);

    if (request.Amount <= 0)
        throw new ArgumentOutOfRangeException(nameof(request.Amount), "Amount must be positive");

    if (string.IsNullOrWhiteSpace(request.Currency))
        throw new ArgumentException("Currency is required", nameof(request.Currency));

    // Happy path continues here without nesting
    var gateway = _gatewayFactory.Create(request.Currency);
    return await gateway.ChargeAsync(request, cancellationToken);
}
```

## Anti-Patterns to Avoid

| Anti-Pattern | Fix |
|---|---|
| `async void` methods | Return `Task` (except event handlers) |
| `.Result` or `.Wait()` | Use `await` |
| `catch (Exception) { }` | Handle or rethrow with context |
| `new Service()` in constructors | Use constructor injection |
| `public` fields | Use properties with appropriate accessors |
| `dynamic` in business logic | Use generics or explicit types |
| Mutable `static` state | Use DI scoping or `ConcurrentDictionary` |
| `string.Format` in loops | Use `StringBuilder` or interpolated string handlers |

## Formatting

- Use `dotnet format` for formatting and analyzer fixes.
- Keep `using` directives organized and remove unused imports.
- Prefer expression-bodied members only when they stay readable.

## Recommended Hooks (configure in your project settings)

These are suggestions to wire up as PostToolUse/Stop hooks in your own settings, not something this plugin installs:

- After editing `.cs` files: run `dotnet format` to auto-format and apply analyzer fixes.
- After editing `.cs`/`.csproj`/`.sln` files: run `dotnet build` to verify the project still compiles.
- After behavior changes: run `dotnet test --no-build` on the nearest relevant test project.
- Before ending a session with broad C# changes: run a final `dotnet build`.
- Warn on modified `appsettings*.json` files so secrets do not get committed.

## Origin

Derived from the open-source ECC plugin (https://github.com/affaan-m/ECC, v2.0.0) `rules/csharp/coding-style.md` and `rules/csharp/hooks.md` (adapted; hooks folded into recommendations rather than shipped as a hooks.json).
