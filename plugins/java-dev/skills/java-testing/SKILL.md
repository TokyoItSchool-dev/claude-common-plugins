---
name: java-testing
description: Java and Spring Boot testing practices covering JUnit 5, Mockito, AssertJ, MockMvc, Testcontainers, TDD workflow, and JaCoCo coverage. Use when writing or editing test files under src/test/java, or when adding features/bug fixes that need accompanying tests. Not for general coding style (see java-conventions), security (see java-security), or REST/JPA architecture (see springboot-patterns).
---

# Java Testing

## Test Framework

- **JUnit 5** (`@Test`, `@ParameterizedTest`, `@Nested`, `@DisplayName`)
- **AssertJ** for fluent assertions (`assertThat(result).isEqualTo(expected)`)
- **Mockito** for mocking dependencies
- **Testcontainers** for integration tests requiring databases or services

## Test Organization

```
src/test/java/com/example/app/
  service/           # Unit tests for service layer
  controller/        # Web layer / API tests
  repository/        # Data access tests
  integration/       # Cross-layer integration tests
```

Mirror the `src/main/java` package structure in `src/test/java`.

## TDD Workflow

1. Write tests first (they should fail)
2. Implement minimal code to pass
3. Refactor with tests green
4. Enforce coverage (JaCoCo)

## Unit Test Pattern (JUnit 5 + Mockito)

```java
@ExtendWith(MockitoExtension.class)
class OrderServiceTest {

    @Mock
    private OrderRepository orderRepository;

    private OrderService orderService;

    @BeforeEach
    void setUp() {
        orderService = new OrderService(orderRepository);
    }

    @Test
    @DisplayName("findById returns order when exists")
    void findById_existingOrder_returnsOrder() {
        var order = new Order(1L, "Alice", BigDecimal.TEN);
        when(orderRepository.findById(1L)).thenReturn(Optional.of(order));

        var result = orderService.findById(1L);

        assertThat(result.customerName()).isEqualTo("Alice");
        verify(orderRepository).findById(1L);
    }

    @Test
    @DisplayName("findById throws when order not found")
    void findById_missingOrder_throws() {
        when(orderRepository.findById(99L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> orderService.findById(99L))
            .isInstanceOf(OrderNotFoundException.class)
            .hasMessageContaining("99");
    }
}
```

Patterns: Arrange-Act-Assert, avoid partial mocks (prefer explicit stubbing), use `@InjectMocks` for simple wiring.

## Parameterized Tests

```java
@ParameterizedTest
@CsvSource({
    "100.00, 10, 90.00",
    "50.00, 0, 50.00",
    "200.00, 25, 150.00"
})
@DisplayName("discount applied correctly")
void applyDiscount(BigDecimal price, int pct, BigDecimal expected) {
    assertThat(PricingUtils.discount(price, pct)).isEqualByComparingTo(expected);
}
```

## Web Layer Tests (MockMvc)

```java
@WebMvcTest(OrderController.class)
class OrderControllerTest {
    @Autowired MockMvc mockMvc;
    @MockBean OrderService orderService;

    @Test
    void returnsOrders() throws Exception {
        when(orderService.list(any())).thenReturn(Page.empty());

        mockMvc.perform(get("/api/orders"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.content").isArray());
    }

    @Test
    void createOrder_invalidInput_returns400() throws Exception {
        mockMvc.perform(post("/api/orders")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"customerName\": \"\"}"))
            .andExpect(status().isBadRequest());
    }
}
```

## Integration Tests (SpringBootTest + Testcontainers)

```java
@SpringBootTest
@AutoConfigureMockMvc
@Testcontainers
class OrderIntegrationTest {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine");

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }

    @Autowired MockMvc mockMvc;

    @Test
    void createsOrder() throws Exception {
        mockMvc.perform(post("/api/orders")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {"customerName":"Alice","amount":10.00}
                """))
            .andExpect(status().isCreated());
    }
}
```

Use reusable Testcontainers instances for Postgres/Redis to mirror production; wire via `@DynamicPropertySource`.

## Persistence Tests (DataJpaTest)

```java
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Import(TestContainersConfig.class)
class OrderRepositoryTest {
    @Autowired OrderRepository repo;

    @Test
    void savesAndFinds() {
        var saved = repo.save(new Order(null, "Bob", BigDecimal.ONE));
        var found = repo.findById(saved.getId());
        assertThat(found).isPresent();
    }
}
```

## Test Data Builders

```java
class OrderBuilder {
    private String customerName = "Test";
    OrderBuilder withCustomerName(String name) { this.customerName = name; return this; }
    Order build() { return new Order(null, customerName, BigDecimal.TEN); }
}
```

## Test Naming

Use descriptive names with `@DisplayName`:
- `methodName_scenario_expectedBehavior()` for method names
- `@DisplayName("human-readable description")` for reports

## Coverage (JaCoCo)

Target 80%+ line coverage. Focus on service and domain logic; skip trivial getters/config classes.

```xml
<plugin>
  <groupId>org.jacoco</groupId>
  <artifactId>jacoco-maven-plugin</artifactId>
  <version>0.8.14</version>
  <executions>
    <execution>
      <goals><goal>prepare-agent</goal></goals>
    </execution>
    <execution>
      <id>report</id>
      <phase>verify</phase>
      <goals><goal>report</goal></goals>
    </execution>
  </executions>
</plugin>
```

## CI Commands

- Maven: `./mvnw -T 4 test` or `./mvnw verify`
- Gradle: `./gradlew test jacocoTestReport`

## Origin

Derived from the open-source ECC plugin (https://github.com/affaan-m/ECC, v2.0.0) `rules/java/testing.md` and skill `springboot-tdd`, adapted and merged.
