---
name: aspnet-patterns
description: ASP.NET Core and EF Core patterns covering options binding, dependency injection lifetimes, minimal APIs, middleware, the result pattern, and EF Core repositories. Use when writing or editing ASP.NET Core/EF Core C# code (Program.cs, minimal API endpoints, DbContext/repository classes, middleware). Not for general C# style (see dotnet-conventions), security (see dotnet-security), or test code (see dotnet-testing).
---

# ASP.NET Core / EF Core Patterns

## API Response Pattern

```csharp
public sealed record ApiResponse<T>(
    bool Success,
    T? Data = default,
    string? Error = null,
    object? Meta = null);
```

## Repository Pattern

```csharp
public interface IRepository<T>
{
    Task<IReadOnlyList<T>> FindAllAsync(CancellationToken cancellationToken);
    Task<T?> FindByIdAsync(Guid id, CancellationToken cancellationToken);
    Task<T> CreateAsync(T entity, CancellationToken cancellationToken);
    Task<T> UpdateAsync(T entity, CancellationToken cancellationToken);
    Task DeleteAsync(Guid id, CancellationToken cancellationToken);
}
```

EF Core implementation:

```csharp
public sealed class SqlOrderRepository : IOrderRepository
{
    private readonly AppDbContext _db;

    public SqlOrderRepository(AppDbContext db) => _db = db;

    public async Task<Order?> FindByIdAsync(Guid id, CancellationToken cancellationToken) =>
        await _db.Orders
            .Include(o => o.Items)
            .AsNoTracking()
            .FirstOrDefaultAsync(o => o.Id == id, cancellationToken);

    public async Task AddAsync(Order order, CancellationToken cancellationToken)
    {
        _db.Orders.Add(order);
        await _db.SaveChangesAsync(cancellationToken);
    }
}
```

- Use `AsNoTracking()` for read-only queries.
- Use `Include`/`ThenInclude` for eager loading; avoid lazy-loading N+1 queries in loops.

## Options Pattern

Bind configuration sections to strongly typed options instead of reading raw config strings throughout the codebase.

```csharp
public sealed class PaymentsOptions
{
    public const string SectionName = "Payments";
    public required string BaseUrl { get; init; }
    public required string ApiKeySecretName { get; init; }
}

// Registration
builder.Services.Configure<PaymentsOptions>(
    builder.Configuration.GetSection(PaymentsOptions.SectionName));

// Usage via injection
public class PaymentsService(IOptions<PaymentsOptions> options)
{
    private readonly PaymentsOptions _payments = options.Value;
}
```

## Dependency Injection

- Depend on interfaces at service boundaries.
- Keep constructors focused; if a service needs too many dependencies, split responsibilities.
- Register lifetimes intentionally: singleton for stateless/shared services, scoped for request data, transient for lightweight pure workers.

```csharp
builder.Services.AddScoped<IOrderRepository, SqlOrderRepository>();
```

## Result Pattern

Return explicit success/failure instead of throwing for expected failures.

```csharp
public sealed record Result<T>
{
    public bool IsSuccess { get; }
    public T? Value { get; }
    public string? Error { get; }

    private Result(T value) { IsSuccess = true; Value = value; }
    private Result(string error) { IsSuccess = false; Error = error; }

    public static Result<T> Success(T value) => new(value);
    public static Result<T> Failure(string error) => new(error);
}
```

## Minimal API Patterns

```csharp
var orders = app.MapGroup("/api/orders")
    .RequireAuthorization()
    .WithTags("Orders");

orders.MapGet("/{id:guid}", async (
    Guid id,
    IOrderRepository repository,
    CancellationToken cancellationToken) =>
{
    var order = await repository.FindByIdAsync(id, cancellationToken);
    return order is not null ? TypedResults.Ok(order) : TypedResults.NotFound();
});

orders.MapPost("/", async (
    CreateOrderRequest request,
    IOrderService service,
    CancellationToken cancellationToken) =>
{
    var result = await service.PlaceOrderAsync(request, cancellationToken);
    return result.IsSuccess
        ? TypedResults.Created($"/api/orders/{result.Value!.Id}", result.Value)
        : TypedResults.BadRequest(result.Error);
});
```

## Middleware

```csharp
public sealed class RequestTimingMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<RequestTimingMiddleware> _logger;

    public RequestTimingMiddleware(RequestDelegate next, ILogger<RequestTimingMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        var stopwatch = Stopwatch.StartNew();
        try
        {
            await _next(context);
        }
        finally
        {
            stopwatch.Stop();
            _logger.LogInformation(
                "Request {Method} {Path} completed in {ElapsedMs}ms with status {StatusCode}",
                context.Request.Method, context.Request.Path,
                stopwatch.ElapsedMilliseconds, context.Response.StatusCode);
        }
    }
}
```

## Origin

Derived from the open-source ECC plugin (https://github.com/affaan-m/ECC, v2.0.0) `rules/csharp/patterns.md` and `skills/dotnet-patterns/SKILL.md`, adapted.
