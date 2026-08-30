"""
backend/db/__init__.py

Database configuration foundation for GeoHarvest.

Current status: Configuration scaffold only.
Full PostgreSQL/PostGIS ORM integration is a future implementation task.

Environment variables:
  DATABASE_URL — PostgreSQL connection string
  DB_POOL_SIZE — connection pool size (default: 10)
  DB_ECHO      — set to 'true' to log SQL queries (development only)
"""
import os
from typing import Any, Dict

DATABASE_URL: str = os.getenv("DATABASE_URL", "")
DB_POOL_SIZE: int = int(os.getenv("DB_POOL_SIZE", "10"))
DB_ECHO: bool = os.getenv("DB_ECHO", "false").lower() in ("1", "true", "yes")

_USE_DB: bool = bool(DATABASE_URL)


def get_db_config() -> Dict[str, Any]:
    """Return the current database configuration (no secrets exposed)."""
    return {
        "use_db": _USE_DB,
        "pool_size": DB_POOL_SIZE,
        "echo": DB_ECHO,
        "configured": _USE_DB,
        "adapter": _detect_adapter(),
    }


def _detect_adapter() -> str:
    if not DATABASE_URL:
        return "none"
    if DATABASE_URL.startswith("postgresql+asyncpg"):
        return "asyncpg"
    if DATABASE_URL.startswith("postgresql"):
        return "psycopg2"
    if DATABASE_URL.startswith("sqlite"):
        return "sqlite"
    return "unknown"
