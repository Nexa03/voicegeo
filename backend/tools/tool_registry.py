"""
backend/tools/tool_registry.py

Controlled registry of allowed tools. Validates arguments and executes either
mock implementations (when enabled) or returns a standard 'service unavailable'
response when real adapters are not configured.
"""
from typing import Any, Dict, Callable, Optional
import os
import logging

logger = logging.getLogger(__name__)

USE_MOCK = os.getenv("USE_MOCK_SERVICES", "true").lower() in ("1", "true", "yes")


def _mock_check_market_price(crop: str, market: str, date: Optional[str] = None) -> Dict[str, Any]:
    # Clearly labeled mock data for development only
    return {
        "available": True,
        "mock": True,
        "crop": crop,
        "market": market,
        "price": 250,
        "unit": "GHS/kg",
        "source": "mock_market_data",
        "timestamp": "2026-01-01T00:00:00Z",
    }


def _mock_find_buyers(produce: str, quantity: int, location: str) -> Dict[str, Any]:
    return {
        "mock": True,
        "buyers": [
            {
                "id": "mock-buyer-1",
                "name": "Mock Foods Ltd.",
                "produce": produce,
                "min_quantity": 100,
                "unit": "kg",
                "location": location,
                "verified": False,
            }
        ],
    }


def _mock_find_transport(origin: str, destination: str, produce: str, quantity: int) -> Dict[str, Any]:
    return {
        "mock": True,
        "transports": [
            {
                "id": "mock-trans-1",
                "operator": "Mock Transport",
                "vehicle_type": "truck",
                "capacity_kg": 2000,
                "eta_minutes": 180,
                "verified": False,
            }
        ],
    }


def _mock_get_weather(location: str, date: Optional[str] = None) -> Dict[str, Any]:
    return {
        "mock": True,
        "location": location,
        "date": date,
        "forecast": {
            "temperature_c": 28,
            "rain_probability": 0.2,
            "wind_kph": 12,
        },
    }


def _mock_track_order(order_number: str) -> Dict[str, Any]:
    return {
        "mock": True,
        "order_number": order_number,
        "status": "pending",
        "eta": None,
    }


class ToolRegistry:
    def __init__(self, use_mocks: bool = True):
        self.use_mocks = use_mocks
        # Map of tool names to (callable, required_args)
        self.tools: Dict[str, Dict[str, Any]] = {
            "check_market_price": {"func": self.check_market_price, "args": ["crop", "market"]},
            "find_buyers": {"func": self.find_buyers, "args": ["produce", "quantity", "location"]},
            "find_transport": {"func": self.find_transport, "args": ["origin", "destination", "produce", "quantity"]},
            "get_weather": {"func": self.get_weather, "args": ["location"]},
            "track_order": {"func": self.track_order, "args": ["order_number"]},
        }

    def execute(self, tool_name: str, args: Dict[str, Any]) -> Dict[str, Any]:
        if tool_name not in self.tools:
            logger.warning("Requested unknown tool: %s", tool_name)
            return {"available": False, "error_code": "UNKNOWN_TOOL"}

        tool = self.tools[tool_name]
        func: Callable = tool["func"]

        # Validate required args
        required = tool.get("args", [])
        for r in required:
            if r not in args:
                return {"available": False, "error_code": "MISSING_ARGUMENT", "message": f"Missing argument: {r}"}

        try:
            return func(**args)
        except Exception as e:
            logger.exception("Tool execution failed: %s", e)
            return {"available": False, "error_code": "TOOL_ERROR", "message": str(e)}

    # Individual tool implementations
    def check_market_price(self, crop: str, market: str, date: Optional[str] = None) -> Dict[str, Any]:
        if self.use_mocks:
            return _mock_check_market_price(crop, market, date)
        # Real implementation placeholder
        return {"available": False, "error_code": "SERVICE_UNAVAILABLE"}

    def find_buyers(self, produce: str, quantity: int, location: str) -> Dict[str, Any]:
        if self.use_mocks:
            return _mock_find_buyers(produce, quantity, location)
        return {"available": False, "error_code": "SERVICE_UNAVAILABLE"}

    def find_transport(self, origin: str, destination: str, produce: str, quantity: int) -> Dict[str, Any]:
        if self.use_mocks:
            return _mock_find_transport(origin, destination, produce, quantity)
        return {"available": False, "error_code": "SERVICE_UNAVAILABLE"}

    def get_weather(self, location: str, date: Optional[str] = None) -> Dict[str, Any]:
        if self.use_mocks:
            return _mock_get_weather(location, date)
        return {"available": False, "error_code": "SERVICE_UNAVAILABLE"}

    def track_order(self, order_number: str) -> Dict[str, Any]:
        if self.use_mocks:
            return _mock_track_order(order_number)
        return {"available": False, "error_code": "SERVICE_UNAVAILABLE"}
