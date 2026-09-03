---
name: dotnet-testing
description: C# and .NET testing patterns with xUnit, FluentAssertions, mocking, integration tests, and test organization. Use when writing or reviewing test code in a .NET project (test *.cs files, *.csproj test projects). Not for general coding style (see dotnet-conventions) or security (see dotnet-security).
---

# C# Testing

## Test Framework Stack

| Tool | Purpose |
|---|---|
| **xUnit** | Test framework (preferred for .NET) |
| **FluentAssertions** | Readable assertion syntax |
| **NSubstitute** or **Moq** | Mocking dependencies |
| **Testcontainers** | Real infrastructure in integration tests |
| **WebApplicationFactory** | ASP.NET Core integration tests |
| **Bogus** | Realistic test data generation |

## Test Organization

- Mirror `src/` structure under `tests/`.
- Separate unit, integration, and end-to-end coverage clearly.
- Name tests by behavior, not implementation details: `Method_ExpectedResult_WhenCondition`.

```
tests/
  MyApp.UnitTests/
    Services/
      OrderServiceTests.cs
  MyApp.IntegrationTests/
    Api/
      OrderApiTests.cs
  MyApp.TestHelpers/
    Builders/
      OrderBuilder.cs
```

## Unit Test Structure (Arrange-Act-Assert)

```csharp
public sealed class OrderServiceTests
{
    private readonly IOrderRepository _repository = Substitute.For<IOrderRepository>();
    private readonly OrderService _sut;

    public OrderServiceTests() => _sut = new OrderService(_repository);

    [Fact]
    public async Task PlaceOrderAsync_ReturnsSuccess_WhenRequestIsValid()
    {
        // Arrange
        var request = new CreateOrderRequest
        {
            CustomerId = "cust-123",
            Items = [new OrderItem("SKU-001", 2, 29.99m)]
        };

        // Act
        var result = await _sut.PlaceOrderAsync(request, CancellationToken.None);

        // Assert
        result.IsSuccess.Should().BeTrue();
        result.Value!.CustomerId.Should().Be("cust-123");
    }
}
```

## Parameterized Tests with Theory

```csharp
[Theory]
[InlineData("", false)]
[InlineData("user@example.com", true)]
public void IsValidEmail_ReturnsExpected(string email, bool expected)
{
    EmailValidator.IsValid(email).Should().Be(expected);
}

[Theory]
[MemberData(nameof(InvalidOrderCases))]
public async Task PlaceOrderAsync_RejectsInvalidOrders(CreateOrderRequest request, string expectedError)
{
    var result = await _sut.PlaceOrderAsync(request, CancellationToken.None);

    result.IsSuccess.Should().BeFalse();
    result.Error.Should().Contain(expectedError);
}

public static TheoryData<CreateOrderRequest, string> InvalidOrderCases => new()
{
    { new() { CustomerId = "", Items = [ValidItem()] }, "CustomerId" },
    { new() { CustomerId = "c1", Items = [] }, "at least one item" },
};
```

## Mocking with NSubstitute

```csharp
[Fact]
public async Task GetOrderAsync_ReturnsNull_WhenNotFound()
{
    var orderId = Guid.NewGuid();
    _repository.FindByIdAsync(orderId, Arg.Any<CancellationToken>()).Returns((Order?)null);

    var result = await _sut.GetOrderAsync(orderId, CancellationToken.None);

    result.Should().BeNull();
}

[Fact]
public async Task PlaceOrderAsync_PersistsOrder()
{
    var request = ValidOrderRequest();

    await _sut.PlaceOrderAsync(request, CancellationToken.None);

    await _repository.Received(1).AddAsync(
        Arg.Is<Order>(o => o.CustomerId == request.CustomerId),
        Arg.Any<CancellationToken>());
}
```

## ASP.NET Core Integration Tests

- Use `WebApplicationFactory<TEntryPoint>` for API integration coverage.
- Test auth, validation, and serialization through HTTP, not by bypassing middleware.

```csharp
public sealed class OrderApiTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;

    public OrderApiTests(WebApplicationFactory<Program> factory)
    {
        _client = factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                services.RemoveAll<DbContextOptions<AppDbContext>>();
                services.AddDbContext<AppDbContext>(options =>
                    options.UseInMemoryDatabase("TestDb"));
            });
        }).CreateClient();
    }

    [Fact]
    public async Task GetOrder_Returns404_WhenNotFound()
    {
        var response = await _client.GetAsync($"/api/orders/{Guid.NewGuid()}");

        response.StatusCode.Should().Be(HttpStatusCode.NotFound);
    }
}
```

## Testing with Testcontainers

Use when integration tests need real infrastructure (e.g. Postgres) rather than an in-memory stand-in.

```csharp
public sealed class PostgresOrderRepositoryTests : IAsyncLifetime
{
    private readonly PostgreSqlContainer _postgres = new PostgreSqlBuilder()
        .WithImage("postgres:16-alpine")
        .Build();

    public async Task InitializeAsync() => await _postgres.StartAsync();
    public async Task DisposeAsync() => await _postgres.DisposeAsync();

    [Fact]
    public async Task AddAsync_PersistsOrder()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseNpgsql(_postgres.GetConnectionString())
            .Options;
        await using var db = new AppDbContext(options);
        await db.Database.MigrateAsync();

        var repo = new SqlOrderRepository(db);
        var order = Order.Create("cust-1", [new OrderItem("SKU-001", 2, 10m)]);
        await repo.AddAsync(order, CancellationToken.None);

        (await repo.FindByIdAsync(order.Id, CancellationToken.None)).Should().NotBeNull();
    }
}
```

## Test Data Builders

```csharp
public sealed class OrderBuilder
{
    private string _customerId = "cust-default";
    private readonly List<OrderItem> _items = [new("SKU-001", 1, 10m)];

    public OrderBuilder WithCustomer(string customerId)
    {
        _customerId = customerId;
        return this;
    }

    public Order Build() => Order.Create(_customerId, _items);
}
```

## Common Anti-Patterns

| Anti-Pattern | Fix |
|---|---|
| Testing implementation details | Test behavior and outcomes |
| Shared mutable test state | Fresh instance per test (xUnit constructors) |
| `Thread.Sleep` in async tests | Use `Task.Delay` with timeout, or polling helpers |
| Asserting on `ToString()` output | Assert on typed properties |
| One giant assertion per test | One logical assertion per test |
| Ignoring `CancellationToken` | Always pass and verify cancellation |

## Coverage

- Target 80%+ line coverage.
- Focus coverage on domain logic, validation, auth, and failure paths.

## Running Tests

```bash
dotnet test
dotnet test --collect:"XPlat Code Coverage"
dotnet test tests/MyApp.UnitTests/
dotnet test --filter "FullyQualifiedName~OrderService"
dotnet watch test --project tests/MyApp.UnitTests/
```

## Origin

Derived from the open-source ECC plugin (https://github.com/affaan-m/ECC, v2.0.0) `rules/csharp/testing.md` and `skills/csharp-testing/SKILL.md`, adapted.
