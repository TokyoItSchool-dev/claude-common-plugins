---
name: fastapi-patterns
description: FastAPI and Pydantic patterns for the Python API stack covering the app factory with lifespan, dependencies with Depends and Annotated, settings with pydantic-settings, routers, separate request and response models, input validation, error responses, def versus async def, and database access. Use when writing or editing FastAPI application code (path operations, routers, dependencies, Pydantic models, settings, the app entry point). Not for general Python rules (see python-conventions) or test code (see pytest-testing).
---

# FastAPI Patterns

The Python version floor and the uv commands are in `python-conventions`. Endpoint naming, status codes, and pagination rules that do not depend on the framework are in `core-dev:api-design`. Versions checked for this skill: FastAPI 0.162.7, Pydantic 2.14, pydantic-settings 2.16.

## App Factory with Lifespan

Create the app in a function so that each test gets a new app with its own `dependency_overrides`. Create and release long-lived resources (database connections, HTTP clients) in a `lifespan` context manager, not at import time.

```python
import logging
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

from app.repository import InMemoryProjectRepository
from app.routes import projects

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    # Runs before the first request and after the last one.
    app.state.repository = InMemoryProjectRepository()
    yield


async def unhandled_error(request: Request, exc: Exception) -> JSONResponse:
    logger.exception("unhandled error on %s %s", request.method, request.url.path)
    return JSONResponse(status_code=500, content={"detail": "internal_error"})


def create_app() -> FastAPI:
    app = FastAPI(lifespan=lifespan)
    app.include_router(projects.router)
    app.add_exception_handler(Exception, unhandled_error)

    @app.get("/health")
    def health() -> dict[str, str]:
        return {"status": "ok"}

    return app


app = create_app()
```

- Use `lifespan`, not `@app.on_event("startup")`. The FastAPI documentation lists startup and shutdown events as deprecated, and when `lifespan` is given, event handlers are not called.
- Code before `yield` runs before the app receives requests; code after `yield` runs after it has finished handling them.

## Dependencies

Everything a path operation needs from outside (the clock, settings, a repository or database session, an HTTP client) comes in through `Depends`. Tests replace them with `app.dependency_overrides` (see `pytest-testing`).

```python
from datetime import UTC, datetime
from functools import lru_cache

from fastapi import Request
from pydantic_settings import BaseSettings, SettingsConfigDict

from app.repository import InMemoryProjectRepository


class Settings(BaseSettings):
    """Settings read from environment variables with the APP_ prefix."""

    model_config = SettingsConfigDict(env_prefix="APP_")

    stale_threshold_days: int = 7


@lru_cache
def get_settings() -> Settings:
    return Settings()


def get_now() -> datetime:
    """The only place that reads the clock. Tests override it."""
    return datetime.now(UTC)


def get_repository(request: Request) -> InMemoryProjectRepository:
    repository: InMemoryProjectRepository = request.app.state.repository
    return repository
```

The example shows only the dependencies. A path operation takes settings the same way as the others: `Annotated[Settings, Depends(get_settings)]`.

- Declare dependencies with `Annotated[T, Depends(fn)]`, which the FastAPI documentation prefers, and give repeated ones a name (`Now = Annotated[datetime, Depends(get_now)]`).
- Read settings with `pydantic-settings` through a cached `get_settings()` dependency, not with `os.environ` in handlers. Settings classes validate types, so a non-numeric `APP_STALE_THRESHOLD_DAYS` raises a validation error when the settings are first read instead of producing a wrong value. To fail at startup, call `get_settings()` in `lifespan`.
- Do not put secrets as default values in the settings class or in a committed `.env` file. Keep `.env` in `.gitignore`.

## Routers

- Put each area's path operations in its own module with an `APIRouter(prefix=..., tags=[...])` and add it with `app.include_router(...)`. Add one `include_router` line per router.
- Register routes that must work without authentication (a health check) separately from the routers that require it, and state the order in the factory.

```python
from datetime import datetime
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Path

from app.dependencies import get_now, get_repository
from app.models import ProjectCreate, ProjectOut
from app.repository import InMemoryProjectRepository, ProjectNotFoundError

router = APIRouter(prefix="/projects", tags=["projects"])

Repository = Annotated[InMemoryProjectRepository, Depends(get_repository)]
Now = Annotated[datetime, Depends(get_now)]


@router.post("", status_code=201)
def create_project(body: ProjectCreate, repository: Repository, now: Now) -> ProjectOut:
    project = repository.add(name=body.name, created_at=now)
    return ProjectOut(id=project.id, name=project.name, created_at=project.created_at)


@router.get("/{project_id}")
def read_project(
    project_id: Annotated[int, Path(gt=0)], repository: Repository
) -> ProjectOut:
    try:
        project = repository.get(project_id)
    except ProjectNotFoundError:
        raise HTTPException(status_code=404, detail="not_found") from None
    return ProjectOut(id=project.id, name=project.name, created_at=project.created_at)
```

## Request and Response Models

```python
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class ProjectCreate(BaseModel):
    """Request body for POST /projects."""

    model_config = ConfigDict(extra="forbid")

    name: str = Field(min_length=1, max_length=100)


class ProjectOut(BaseModel):
    """Response body for a project. Has no internal fields."""

    id: int
    name: str
    created_at: datetime
```

- Use separate models for input and output. FastAPI filters the response to the return type (or `response_model`), so a field that is not in the output model (a password hash, an internal token) is not sent. Do not return the input model or the database row type.
- Declare the return type on every path operation. When both a return type and `response_model` are given, `response_model` wins; use `response_model` only when the function must return a different type.
- Set `extra="forbid"` on request models so that unknown fields are rejected instead of ignored.
- Put constraints on the field (`Field(min_length=1)`, `Path(gt=0)`, `Query(le=100)`) so that FastAPI rejects invalid input before the function runs. Use `@field_validator` only for rules that a constraint cannot express.
- Validate other external data (responses from other services, JSON files) with `Model.model_validate(data)` or `TypeAdapter(T).validate_python(data)`.

## Input Validation and Error Responses

- FastAPI returns 422 with `{"detail": [...]}` when a body, path, or query parameter fails validation. Each item has `loc` (for example `["body", "name"]`), `msg`, and `type`. Keep this format unless the project defines its own error format; if it does, register handlers for `RequestValidationError` and `HTTPException` that produce it (`core-dev:api-design`).
- Raise `HTTPException(status_code=..., detail=...)` for expected failures, with a stable machine-readable `detail` (`"not_found"`). Convert domain exceptions at the route, not inside the domain module.
- Register a handler for `Exception` that logs the error and returns a generic 500 body. Do not put stack traces, SQL errors, upstream error text, or internal paths in the response.
- Return the same 404 for a resource that does not exist and for one the caller may not see.

## def or async def

Follow the FastAPI documentation on concurrency:

- If the function calls a library that must be awaited, declare it `async def` and `await` the call.
- If the function calls a library that blocks (most database drivers, `requests`, file I/O), declare it `def`. FastAPI runs `def` path operations and dependencies in a thread pool.
- Never call blocking code from inside an `async def` function. It stops the event loop for every request.
- When unsure, use `def`.

## Database

- The stack design uses SQLite by default (including for tests) and PostgreSQL as an option.
- Build SQL with bound parameters (`cursor.execute("SELECT ... WHERE id = ?", (project_id,))` for `sqlite3`, `%s` for psycopg), never with f-strings or `+`.
- Provide the connection or session through a dependency created from the lifespan's resources, so that tests can replace it.
- PostgreSQL is installed but not started in a Claude Code cloud session. When the project uses it, start it with `service postgresql start` before tests (if the project defines them, the stack design puts this in the SessionStart hook and in the preparation line of `.claude/rules/stack.md`).

## Anti-Patterns to Avoid

| Anti-Pattern | Fix |
|---|---|
| `app = FastAPI()` at module level with routes and resources created at import | `create_app()` and `lifespan` |
| `@app.on_event("startup")` | `lifespan` |
| `datetime.now()`, `os.environ`, or a global client inside a path operation | Take them through `Depends` |
| Returning the input model or the database row | A separate output model as the return type |
| Request model without `extra="forbid"` | Add it |
| Checking input deep inside business logic | Field constraints and `Path`/`Query` constraints |
| `str(exc)` or a traceback in an error response | Generic 500 body; log the exception |
| `time.sleep`, `requests.get`, or a blocking driver inside `async def` | Declare the function `def`, or use an async library |
| SQL built with f-strings | Bound parameters |

## Origin

Written for this plugin without a prior Python rule set. Rules come from the template stack design and the technology stack research for the Python API stack (S2: FastAPI, SQLite by default and PostgreSQL as an option, `service postgresql start` in a cloud session) and from the FastAPI documentation (lifespan events, dependencies, settings and environment variables, response model, handling errors, concurrency and async / await) and the Pydantic documentation, checked on 2026-11-14 with FastAPI 0.162.7, Pydantic 2.14, and pydantic-settings 2.16. The section layout follows `web-dev:hono-patterns`.
