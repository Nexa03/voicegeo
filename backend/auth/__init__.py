"""
backend/auth/__init__.py

Authentication foundation for GeoHarvest API.

Current status: Structural foundation only.
JWT validation middleware is prepared but not enforced on routes yet.
Enforcement will be added when user registration is implemented.

Design:
- All authentication uses JWT Bearer tokens.
- Tokens are validated via the `require_auth` FastAPI dependency.
- The JWT_SECRET environment variable must be set in production.

Environment variables:
  JWT_SECRET      — secret key for signing/verifying JWT tokens (REQUIRED in production)
  JWT_ALGORITHM   — algorithm (default: HS256)
  JWT_EXPIRE_MINS — token lifetime in minutes (default: 60)
"""
from __future__ import annotations

import os
import logging
from typing import Optional

logger = logging.getLogger(__name__)

JWT_SECRET: str = os.getenv("JWT_SECRET", "")
JWT_ALGORITHM: str = os.getenv("JWT_ALGORITHM", "HS256")
JWT_EXPIRE_MINS: int = int(os.getenv("JWT_EXPIRE_MINS", "60"))

if not JWT_SECRET:
    logger.warning(
        "auth: JWT_SECRET is not set. "
        "Authentication will not be enforced until this is configured. "
        "This is acceptable in development; REQUIRED in production."
    )


# ── User identity model ───────────────────────────────────────────────────────

class UserIdentity:
    """
    Lightweight user identity extracted from a validated JWT.

    Fields align with the planned GeoHarvest user model.
    """

    def __init__(
        self,
        user_id: str,
        role: str = "farmer",
        language: str = "en-GH",
    ) -> None:
        self.user_id = user_id
        self.role = role  # "farmer" | "buyer" | "transporter" | "admin"
        self.language = language

    def __repr__(self) -> str:
        return f"UserIdentity(id={self.user_id}, role={self.role})"


# ── Token validation ─────────────────────────────────────────────────────────

def decode_token(token: str) -> Optional[UserIdentity]:
    """
    Validate a JWT Bearer token and return the embedded UserIdentity.

    Returns None if the token is invalid or JWT_SECRET is not configured.
    Full implementation requires PyJWT (add to requirements.txt when activating).
    """
    if not JWT_SECRET:
        return None

    try:
        import jwt  # noqa: PLC0415  lazy import
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        return UserIdentity(
            user_id=payload["sub"],
            role=payload.get("role", "farmer"),
            language=payload.get("language", "en-GH"),
        )
    except Exception as exc:
        logger.debug("Token validation failed: %s", exc)
        return None


# ── FastAPI dependency (optional — not yet enforced on routes) ────────────────

def _make_require_auth():
    """
    Return a FastAPI dependency that enforces authentication.

    Import this in route files when authentication enforcement is needed:

        from fastapi import Depends
        from backend.auth import require_auth

        @app.get("/protected")
        def protected(user: UserIdentity = Depends(require_auth)):
            ...
    """
    try:
        from fastapi import Depends, HTTPException, status  # noqa: PLC0415
        from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer  # noqa: PLC0415

        _bearer = HTTPBearer(auto_error=False)

        def _require_auth(
            credentials: Optional[HTTPAuthorizationCredentials] = Depends(_bearer),
        ) -> UserIdentity:
            if credentials is None:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Authentication required.",
                    headers={"WWW-Authenticate": "Bearer"},
                )
            identity = decode_token(credentials.credentials)
            if identity is None:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Invalid or expired token.",
                    headers={"WWW-Authenticate": "Bearer"},
                )
            return identity

        return _require_auth

    except ImportError:
        # FastAPI not available (e.g., in test environments that import auth directly)
        return lambda: None


require_auth = _make_require_auth()
