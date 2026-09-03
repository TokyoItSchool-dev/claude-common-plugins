---
name: java-conventions
description: Java coding conventions covering naming, immutability, modern language features, Optional/streams, exceptions, generics, project layout, and common architecture patterns (repository, service layer, DTOs, builder). Use when writing or editing Java files (*.java), pom.xml, build.gradle, or build.gradle.kts. Not for Spring Boot-specific REST/JPA patterns (see springboot-patterns), security (see java-security), or test code (see java-testing).
---

# Java Coding Conventions

Standards for readable, maintainable Java (17+) code.

## Core Principles

- Prefer clarity over cleverness
- Immutable by default; minimize shared mutable state
- Fail fast with meaningful exceptions
- Consistent naming and package structure

## Formatting

- **google-java-format** or **Checkstyle** (Google or Sun style) for enforcement
- One public top-level type per file
- Consistent indent: 2 or 4 spaces (match project standard)
- Member order: constants, fields, constructors, public methods, protected, private

## Naming

- `PascalCase` for classes, interfaces, records, enums
- `camelCase` for methods, fields, parameters, local variables
- `SCREAMING_SNAKE_CASE` for `static final` constants
- Packages: all lowercase, reverse domain (`com.example.app.service`)

```java
public class MarketService {}
public record Money(BigDecimal amount, Currency currency) {}
private static final int MAX_PAGE_SIZE = 100;
```

## Immutability

- Prefer `record` for value types (Java 16+)
- Mark fields `final` by default; use mutable state only when required
- Return defensive copies from public APIs: `List.copyOf()`, `Map.copyOf()`, `Set.copyOf()`
- Copy-on-write: return new instances rather than mutating existing ones

```java
public record OrderSummary(Long id, String customerName, BigDecimal total) {}

public class Order {
    private final Long id;
    private final List<LineItem> items;

    public List<LineItem> getItems() {
        return List.copyOf(items);
    }
}
```

## Modern Java Features

Use modern language features where they improve clarity:
- **Records** for DTOs and value types (Java 16+)
- **Sealed classes** for closed type hierarchies (Java 17+)
- **Pattern matching** with `instanceof` (no explicit cast, Java 16+)
- **Text blocks** for multi-line strings (SQL, JSON templates, Java 15+)
- **Switch expressions** with arrow syntax (Java 14+)
- **Pattern matching in switch** for exhaustive sealed type handling (Java 21+)

```java
if (shape instanceof Circle c) {
    return Math.PI * c.radius() * c.radius();
}

public sealed interface PaymentMethod permits CreditCard, BankTransfer, Wallet {}

String label = switch (status) {
    case ACTIVE -> "Active";
    case SUSPENDED -> "Suspended";
    case CLOSED -> "Closed";
};
```

## Optional Usage

- Return `Optional<T>` from finder methods that may have no result
- Use `map()`, `flatMap()`, `orElseThrow()`; never call `get()` without `isPresent()`
- Never use `Optional` as a field type or method parameter

```java
// GOOD
return repository.findById(id)
    .map(ResponseDto::from)
    .orElseThrow(() -> new OrderNotFoundException(id));

// BAD - Optional as parameter
public void process(Optional<String> name) {}
```

## Streams

- Use streams for transformations; keep pipelines short (3-4 operations max)
- Prefer method references when readable: `.map(Order::getTotal)`
- Avoid side effects in stream operations
- For complex logic, prefer a loop over a convoluted stream pipeline

```java
List<String> names = markets.stream()
    .map(Market::name)
    .filter(Objects::nonNull)
    .toList();
```

## Error Handling

- Prefer unchecked exceptions for domain errors
- Create domain-specific exceptions extending `RuntimeException`
- Avoid broad `catch (Exception e)` unless at top-level handlers
- Include context in exception messages

```java
public class OrderNotFoundException extends RuntimeException {
    public OrderNotFoundException(Long id) {
        super("Order not found: id=" + id);
    }
}
```

## Generics and Type Safety

- Avoid raw types; declare generic parameters
- Prefer bounded generics for reusable utilities

```java
public <T extends Identifiable> Map<Long, T> indexById(Collection<T> items) { /* ... */ }
```

## Architecture Patterns

For the repository pattern, service layer with constructor injection, DTO mapping, the builder
pattern, sealed types for domain results, and the API response envelope pattern, see
`references/architecture-patterns.md`.

## Project Structure (Maven/Gradle)

```
src/main/java/com/example/app/
  config/
  controller/
  service/
  repository/
  domain/
  dto/
  util/
src/main/resources/
  application.yml
src/test/java/... (mirrors main)
```

## Logging

```java
private static final Logger log = LoggerFactory.getLogger(MarketService.class);
log.info("fetch_market slug={}", slug);
log.error("failed_fetch_market slug={}", slug, ex);
```

## Null Handling

- Accept `@Nullable` only when unavoidable; otherwise use `@NonNull`
- Use Bean Validation (`@NotNull`, `@NotBlank`) on inputs

## Code Smells to Avoid

- Long parameter lists: use DTO/builders
- Deep nesting: prefer early returns
- Magic numbers: use named constants
- Static mutable state: prefer dependency injection
- Silent catch blocks: log and act, or rethrow

## Recommended Hooks (configure in your project settings)

These are suggestions to wire up as PostToolUse hooks in your own settings, not something this plugin installs:

- **google-java-format**: auto-format `.java` files after edit
- **checkstyle**: run style checks after editing Java files
- **./mvnw compile** or **./gradlew compileJava**: verify compilation after changes

## Origin

Derived from the open-source ECC plugin (https://github.com/affaan-m/ECC, v2.0.0) `rules/java/coding-style.md`, `rules/java/patterns.md`, and `rules/java/hooks.md`, plus skill `java-coding-standards`, adapted and merged.
