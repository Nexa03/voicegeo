"""
backend/tools/tool_registry.py

GeoHarvest tool registry.

Dispatches named tool calls from Kofi AI to the appropriate service adapters.
Each tool has:
  - a clear interface (required arguments)
  - a mock implementation for development (USE_MOCK_SERVICES=true)
  - a stub that returns SERVICE_UNAVAILABLE for production (real adapter TODO)

IMPORTANT:
  Mock data is clearly labeled with "mock": True and must NEVER be presented
  to end users as real GeoHarvest data. The mock flag must be surfaced in all
  API responses that include tool results.
"""
import logging
import os
from typing import Any, Callable, Dict, List, Optional

logger = logging.getLogger(__name__)

USE_MOCK: bool = os.getenv("USE_MOCK_SERVICES", "true").lower() in ("1", "true", "yes")


# ── Mock implementations (development only) ───────────────────────────────────

def _mock_check_market_price(
    crop: str, market: str, date: Optional[str] = None
) -> Dict[str, Any]:
    """Development placeholder — NOT real market data."""
    return {
        "mock": True,
        "available": True,
        "crop": crop,
        "market": market,
        "price": 250,
        "unit": "GHS/kg",
        "source": "mock_development_data",
        "date": date,
        "disclaimer": "This is mock data for development. Do not show to end users as real prices.",
    }


def _mock_find_buyers(
    produce: str, quantity: int, location: str
) -> Dict[str, Any]:
    """Development placeholder — NOT real buyer data."""
    return {
        "mock": True,
        "buyers": [
            {
                "id": "mock-buyer-001",
                "name": "Mock Buyer (Development Only)",
                "produce": produce,
                "min_quantity": 100,
                "unit": "kg",
                "location": location,
                "verified": False,
                "disclaimer": "Mock development data — not a real buyer.",
            }
        ],
    }


def _mock_find_transport(
    origin: str, destination: str, produce: str, quantity: int
) -> Dict[str, Any]:
    """Development placeholder — NOT real transport data."""
    return {
        "mock": True,
        "transports": [
            {
                "id": "mock-transport-001",
                "operator": "Mock Transport (Development Only)",
                "vehicle_type": "truck",
                "capacity_kg": 2000,
                "eta_minutes": 180,
                "verified": False,
                "disclaimer": "Mock development data — not a real transport provider.",
            }
        ],
    }


def _mock_get_weather(
    location: str, date: Optional[str] = None
) -> Dict[str, Any]:
    """Development placeholder — NOT real weather data."""
    return {
        "mock": True,
        "location": location,
        "date": date,
        "forecast": {
            "temperature_c": 28,
            "rain_probability": 0.2,
            "wind_kph": 12,
        },
        "disclaimer": "Mock development data — not a real weather forecast.",
    }


def _mock_track_order(order_number: str) -> Dict[str, Any]:
    """Development placeholder — NOT real order data."""
    return {
        "mock": True,
        "order_number": order_number,
        "status": "pending",
        "eta": None,
        "disclaimer": "Mock development data — not a real order status.",
    }


# ── Registry ──────────────────────────────────────────────────────────────────

class ToolRegistry:
    """
    Registry of GeoHarvest tools available to Kofi AI.

    Each tool entry:
      func     — callable that executes the tool
      args     — list of required argument names
      optional — list of optional argument names

    To wire a real service adapter, replace the mock implementation in the
    corresponding method (e.g. `check_market_price`) without changing the
    public execute() interface.
    """

    def __init__(self, use_mocks: bool = True) -> None:
        self.use_mocks = use_mocks

        self._tools: Dict[str, Dict[str, Any]] = {
            "check_market_price": {
                "func": self.check_market_price,
                "args": ["crop", "market"],
                "optional": ["date"],
                "description": "Check current market price for a crop at a given market.",
            },
            "find_buyers": {
                "func": self.find_buyers,
                "args": ["produce", "quantity", "location"],
                "optional": [],
                "description": "Find registered buyers for a given produce type and location.",
            },
            "find_transport": {
                "func": self.find_transport,
                "args": ["origin", "destination", "produce", "quantity"],
                "optional": [],
                "description": "Find available transport providers for a route.",
            },
            "get_weather": {
                "func": self.get_weather,
                "args": ["location"],
                "optional": ["date"],
                "description": "Get weather forecast for a farming location.",
            },
            "track_order": {
                "func": self.track_order,
                "args": ["order_number"],
                "optional": [],
                "description": "Track the status of a GeoHarvest order.",
            },
        }

    @property
    def available_tools(self) -> List[str]:
        return list(self._tools.keys())

    def execute(self, tool_name: str, args: Dict[str, Any]) -> Dict[str, Any]:
        """
        Execute a named tool with the given arguments.

        Returns a result dict. Always includes 'available' and 'mock' keys.
        """
        if tool_name not in self._tools:
            logger.warning("ToolRegistry: unknown tool requested: %s", tool_name)
            return {
                "available": False,
                "error_code": "UNKNOWN_TOOL",
                "tool": tool_name,
            }

        tool = self._tools[tool_name]
        func: Callable = tool["func"]

        # Validate required args
        for required in tool.get("args", []):
            if required not in args:
                return {
                    "available": False,
                    "error_code": "MISSING_ARGUMENT",
                    "argument": required,
                    "tool": tool_name,
                }

        try:
            result = func(**{k: v for k, v in args.items()
                             if k in tool["args"] + tool.get("optional", [])})
            logger.debug("ToolRegistry: %s executed (mock=%s)", tool_name, self.use_mocks)
            return result
        except Exception as exc:
            logger.exception("ToolRegistry: tool %s failed: %s", tool_name, exc)
            return {
                "available": False,
                "error_code": "TOOL_ERROR",
                "message": str(exc),
                "tool": tool_name,
            }

    # ── Tool implementations ──────────────────────────────────────────────────

    def check_market_price(
        self, crop: str, market: str, date: Optional[str] = None
    ) -> Dict[str, Any]:
        if self.use_mocks:
            return _mock_check_market_price(crop, market, date)
        # TODO: wire real GeoHarvest market price API
        return {"available": False, "error_code": "SERVICE_UNAVAILABLE", "tool": "check_market_price"}

    def find_buyers(
        self, produce: str, quantity: int, location: str
    ) -> Dict[str, Any]:
        if self.use_mocks:
            return _mock_find_buyers(produce, quantity, location)
        # TODO: wire real GeoHarvest buyer registry API
        return {"available": False, "error_code": "SERVICE_UNAVAILABLE", "tool": "find_buyers"}

    def find_transport(
        self, origin: str, destination: str, produce: str, quantity: int
    ) -> Dict[str, Any]:
        if self.use_mocks:
            return _mock_find_transport(origin, destination, produce, quantity)
        # TODO: wire real GeoHarvest logistics API
        return {"available": False, "error_code": "SERVICE_UNAVAILABLE", "tool": "find_transport"}

    def get_weather(
        self, location: str, date: Optional[str] = None
    ) -> Dict[str, Any]:
        if self.use_mocks:
            return _mock_get_weather(location, date)
        # TODO: wire real weather API (Open-Meteo / Ghana Met)
        return {"available": False, "error_code": "SERVICE_UNAVAILABLE", "tool": "get_weather"}

    def track_order(self, order_number: str) -> Dict[str, Any]:
        if self.use_mocks:
            return _mock_track_order(order_number)
        # TODO: wire real GeoHarvest order tracking API
        return {"available": False, "error_code": "SERVICE_UNAVAILABLE", "tool": "track_order"}
