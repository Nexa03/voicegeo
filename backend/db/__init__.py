from typing import Optional
import os

# Simple DB scaffolding. If DATABASE_URL is set, applications can wire a SQLModel/SQLAlchemy engine here.
# For Phase 2, we provide a fallback in-memory session which higher-level services can use.

DATABASE_URL = os.getenv("DATABASE_URL", "")
USE_DB = bool(DATABASE_URL)


def get_db_config() -> dict:
    return {
        "use_db": USE_DB,
        "database_url": DATABASE_URL,
    }


# Placeholders for integration with SQLModel/SQLAlchemy later.


if __name__ == "__main__":
    print(get_db_config())
