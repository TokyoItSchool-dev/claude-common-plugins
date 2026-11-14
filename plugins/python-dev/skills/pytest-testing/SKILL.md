---
name: pytest-testing
description: pytest testing patterns for the Python API stack covering test layout, pytest configuration in pyproject.toml, fixtures and conftest.py, FastAPI tests with TestClient, replacing dependencies with dependency_overrides, parametrized tests, controlling time and environment variables, SQLite test databases, and running tests with uv. Use when writing or editing test files (test_*.py, conftest.py), the [tool.pytest] section of pyproject.toml, or test fixtures in a Python project. Not for general Python rules (see python-conventions) or production FastAPI code (see fastapi-patterns).
---

# pytest Testing

The TDD cycle and the coverage target (80%) are in `core-dev:tdd-testing`. How to run tests and report results is in `core-dev:test-run-discipline`. This skill covers how to write the tests with pytest. Versions checked: pytest 9.2.0, FastAPI 0.162.7 with Starlette 1.10.0.

## Test Tool Stack

| Tool | Purpose |
|---|---|
| **pytest** | Test runner, fixtures, `parametrize`, `monkeypatch`, `tmp_path`. Python version floor: see `python-conventions` |
| **FastAPI `TestClient`** | API tests without starting a server |
| **`app.dependency_overrides`** | Replace the clock, settings, repositories, and clients in API tests |
| **httpx2** or **httpx** | The HTTP client `TestClient` is built on. FastAPI's testing page says to install `httpx`. Starlette 1.10.0 (installed with FastAPI 0.162.7) prefers `httpx2` and emits `StarletteDeprecationWarning` when only `httpx` is installed. Add the package the installed Starlette asks for (`uv add --dev httpx2`), and check for that warning after upgrading FastAPI |

## Configuration

pytest 9.0 and later read native TOML from `[tool.pytest]`:

```toml
[tool.pytest]
minversion = "9.0"
testpaths = ["tests"]
addopts = ["--import-mode=importlib"]
strict = true
```

- `--import-mode=importlib` is what pytest's good-practices page recommends for new projects; test files are then imported without changing `sys.path`, and test file names do not have to be unique.
- `strict = true` (pytest 9.0 or later) turns on pytest's strictness options, such as failing on unregistered markers. The set grows in later pytest versions; when pytest is not pinned and a new strict option breaks the suite, fix the tests rather than turning `strict` off.
- With pytest older than 9.0, use `[tool.pytest.ini_options]`, where values are INI-style strings (`addopts = "--import-mode=importlib"`).

## Test Organization

- Put tests under `tests/`, mirroring the package: `src/app/domain.py` and `tests/test_domain.py`.
- Put shared fixtures in `tests/conftest.py`. pytest finds them without an import.
- Name each test after the behavior it checks, not after the implementation. When a test checks an acceptance criterion, start the name with its ID (`test_ac001_...`) so that `pytest -k ac001` selects it.
- Annotate test functions and fixtures (`-> None`, `-> Iterator[TestClient]`); mypy checks tests too (see `python-conventions`).

```python
from datetime import UTC, datetime

from app.domain import is_stale

NOW = datetime(2026, 11, 20, tzinfo=UTC)


def test_ac001_stale_when_last_update_is_at_least_threshold_old() -> None:
    # Arrange
    last_updated_at = datetime(2026, 11, 13, tzinfo=UTC)

    # Act
    result = is_stale(last_updated_at, now=NOW, threshold_days=7)

    # Assert
    assert result is True
```

## Parametrized Tests

Use `pytest.mark.parametrize` for the same behavior over several inputs, and give each case an `id`:

```python
@pytest.mark.parametrize(
    ("last_updated_at", "expected"),
    [
        pytest.param(datetime(2026, 11, 13, tzinfo=UTC), True, id="exactly-threshold"),
        pytest.param(datetime(2026, 11, 14, tzinfo=UTC), False, id="one-day-short"),
        pytest.param(datetime(2026, 1, 1, tzinfo=UTC), True, id="long-ago"),
    ],
)
def test_is_stale_boundaries(last_updated_at: datetime, expected: bool) -> None:
    assert is_stale(last_updated_at, now=NOW, threshold_days=7) is expected
```

## FastAPI Tests with TestClient

Create a new app per test from the app factory (`fastapi-patterns`), replace its dependencies, and call it through `TestClient`:

```python
from collections.abc import Iterator
from datetime import UTC, datetime

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.dependencies import get_now
from app.main import create_app

FIXED_NOW = datetime(2026, 10, 20, 12, 0, tzinfo=UTC)


@pytest.fixture
def app() -> FastAPI:
    app = create_app()
    app.dependency_overrides[get_now] = lambda: FIXED_NOW
    return app


@pytest.fixture
def client(app: FastAPI) -> Iterator[TestClient]:
    # The with block runs the lifespan (startup before, shutdown after).
    with TestClient(app) as client:
        yield client
```

```python
def test_create_project_returns_201_with_fixed_time(client: TestClient) -> None:
    response = client.post("/projects", json={"name": "alpha"})

    assert response.status_code == 201
    assert response.json() == {
        "id": 1,
        "name": "alpha",
        "created_at": "2026-10-20T12:00:00Z",
    }


def test_empty_name_returns_422_with_field_location(client: TestClient) -> None:
    response = client.post("/projects", json={"name": ""})

    assert response.status_code == 422
    assert response.json()["detail"][0]["loc"] == ["body", "name"]
```

- Test functions that use `TestClient` are plain `def`, and client calls are not awaited (FastAPI testing page).
- Use `with TestClient(app) as client:` when the app has a `lifespan`. Without the `with` block, the lifespan does not run.
- Because each test gets a new app from `create_app()`, overrides do not leak between tests. If a module-level `app` is used instead, reset with `app.dependency_overrides.clear()` at the end of the test.
- Test validation, authentication, and error responses through HTTP, not by calling path operation functions directly. Check both the status code and the body.
- `TestClient` re-raises exceptions from the app by default. To test the generic 500 response, create the client with `TestClient(app, raise_server_exceptions=False)` and check that the body has no internal text.
- To call `async` functions in a test other than through `TestClient` (for example an async database function), follow FastAPI's "Async Tests" page.

## Fixtures, Environment, and Files

- Use `monkeypatch.setenv` / `monkeypatch.delenv` for environment variables; pytest restores them after the test. Clear cached settings (`get_settings.cache_clear()`) before and after a test that changes them.
- Use the `tmp_path` fixture for files and SQLite databases, so that each test gets its own directory:

```python
import sqlite3
from collections.abc import Iterator
from pathlib import Path

import pytest


@pytest.fixture
def db(tmp_path: Path) -> Iterator[sqlite3.Connection]:
    connection = sqlite3.connect(tmp_path / "test.db")
    yield connection
    connection.close()
```

- Put cleanup after `yield` in the fixture, not in the test.
- Tests do not call external services. Replace HTTP clients and other services with fakes through `dependency_overrides`.

## Controlling Time

- Pass a fixed `now` to pure functions, and override the clock dependency (`get_now`) in API tests.
- Do not use `time.sleep` to wait for something in a test. Make the code under test take the clock or a timeout as a parameter.

## Common Anti-Patterns

| Anti-Pattern | Fix |
|---|---|
| Starting uvicorn for API tests | `TestClient(app)` |
| `TestClient(app)` without `with` for an app that has a lifespan | `with TestClient(app) as client:` |
| `app.dependency_overrides[...] = ...` on a shared app without reset | New app per test from `create_app()`, or `clear()` in teardown |
| `os.environ["X"] = ...` in a test | `monkeypatch.setenv` |
| Writing test files to the working directory | `tmp_path` |
| `datetime.now()` in code under test with no override | Pass `now` or override `get_now` |
| `time.sleep` to wait | Inject the clock or the timeout |
| Unannotated test functions and fixtures | Annotate; mypy checks tests |

## Running Tests

```bash
uv run pytest                                  # all tests
uv run pytest tests/test_domain.py             # one file
uv run pytest -k ac001                         # tests whose name matches
uv run pytest -x --lf                          # stop at the first failure, rerun last failures
uv run --locked pytest                         # in checks: fail if uv.lock does not match
```

Run them through `core-dev:test-run-discipline` (`run-tests.sh uv run pytest`) and report the result as that skill specifies.

## Origin

Written for this plugin without a prior Python rule set. Rules come from the template stack design and the technology stack research for the Python API stack (S2: `uv run pytest`, FastAPI `TestClient` without a server, SQLite for tests) and from the documentation of FastAPI (testing, testing dependencies with overrides, settings, async tests) and pytest (configuration, good integration practices), checked on 2026-11-14 with pytest 9.2.0, FastAPI 0.162.7, and Starlette 1.10.0. AC IDs in test names follow the `AC-001` numbering used in Issues. The section layout follows `web-dev:vitest-testing`.
