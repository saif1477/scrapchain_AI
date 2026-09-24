"""Pricing Oracle.

Production design: aggregates live quotes from 5+ sources (CPCB rates, MoM EPR
portal, Recykal, Karopadi, ScrapApp) via httpx, caches in Redis, stores the
time-series in TimescaleDB.

Demo mode: those portals expose no public JSON APIs, so we run a deterministic
market simulator seeded with real 2025-26 Indian scrap-market base rates.
Each "source" applies its own spread + daily drift, and we return the MEDIAN
(robust to outliers) — exactly the aggregation the live oracle uses.
"""
import asyncio
import hashlib
import os
from datetime import date, datetime, timezone
from typing import Optional

from models.schemas import ItemPrice, SourceQuote

try:
    import redis.asyncio as aioredis  # optional
except ImportError:
    aioredis = None

# Base ₹/kg rates — informal-sector indicative rates, India 2025-26
BASE_RATES: dict[str, dict] = {
    "PCB":            {"price": 380.0, "material": "Gold-Plated", "hi": "पीसीबी"},
    "Battery":        {"price": 120.0, "material": "Lithium",     "hi": "बैटरी"},
    "CRT":            {"price": 18.0,  "material": "CRT-Glass",   "hi": "सीआरटी"},
    "Cable":          {"price": 145.0, "material": "Copper",      "hi": "केबल"},
    "Motor":          {"price": 95.0,  "material": "Copper",      "hi": "मोटर"},
    "Gold-Plated":    {"price": 620.0, "material": "Gold-Plated", "hi": "गोल्ड प्लेटेड"},
    "Lithium":        {"price": 210.0, "material": "Lithium",     "hi": "लिथियम"},
    "Acid-Container": {"price": 8.0,   "material": "Hazardous",   "hi": "एसिड कंटेनर"},
    "Transformer":    {"price": 110.0, "material": "Copper",      "hi": "ट्रांसफार्मर"},
    "Heat-Sink":      {"price": 130.0, "material": "Aluminum",    "hi": "हीट सिंक"},
    "Fan":            {"price": 55.0,  "material": "Aluminum",    "hi": "पंखा"},
    "Speaker":        {"price": 42.0,  "material": "Magnet-Cu",   "hi": "स्पीकर"},
    "Display":        {"price": 35.0,  "material": "LCD-Panel",   "hi": "डिस्प्ले"},
    "Keyboard":       {"price": 22.0,  "material": "ABS-Plastic", "hi": "कीबोर्ड"},
    "Mouse":          {"price": 25.0,  "material": "ABS-Plastic", "hi": "माउस"},
    "Charger":        {"price": 85.0,  "material": "Copper",      "hi": "चार्जर"},
    "USB-Cable":      {"price": 95.0,  "material": "Copper",      "hi": "यूएसबी केबल"},
    "RAM":            {"price": 950.0, "material": "Gold-Plated", "hi": "रैम"},
    "HDD":            {"price": 160.0, "material": "Neodymium",   "hi": "हार्ड डिस्क"},
    "SSD":            {"price": 340.0, "material": "Gold-Plated", "hi": "एसएसडी"},
}

SOURCES = [
    ("CPCB-Official", 0.94),    # conservative floor rates
    ("MoM-EPR-Portal", 0.98),
    ("Recykal", 1.03),          # marketplace premium
    ("Karopadi-B2B", 1.06),
    ("ScrapApp", 1.00),
]

CACHE_TTL = 6 * 3600  # refresh every 6 hours


def _daily_drift(item: str, source: str) -> float:
    """Deterministic pseudo-random daily drift in [-4%, +4%]."""
    seed = f"{date.today().isoformat()}:{item}:{source}"
    h = int(hashlib.sha256(seed.encode()).hexdigest()[:8], 16)
    return 1.0 + ((h % 800) - 400) / 10000.0


class PricingOracle:
    def __init__(self):
        self._redis = None
        url = os.getenv("REDIS_URL")
        if url and aioredis is not None:
            try:
                self._redis = aioredis.from_url(url, socket_connect_timeout=1)
            except Exception:
                self._redis = None
        self._mem_cache: dict[str, tuple[float, ItemPrice]] = {}

    def normalize(self, item_type: str) -> Optional[str]:
        for key in BASE_RATES:
            if key.lower().replace("-", "") == item_type.lower().replace("-", "").replace("_", "").replace(" ", ""):
                return key
        return None

    async def fetch_price(self, item_type: str) -> Optional[ItemPrice]:
        key = self.normalize(item_type)
        if key is None:
            return None

        # cache hit?
        now = datetime.now(timezone.utc).timestamp()
        cached = self._mem_cache.get(key)
        if cached and now - cached[0] < CACHE_TTL:
            return cached[1]

        base = BASE_RATES[key]
        quotes = [
            SourceQuote(source=src, price_per_kg=round(base["price"] * spread * _daily_drift(key, src), 2))
            for src, spread in SOURCES
        ]
        # tiny stagger to emulate concurrent source fetches
        await asyncio.sleep(0)

        prices = sorted(q.price_per_kg for q in quotes)
        median = prices[len(prices) // 2]

        result = ItemPrice(
            item_type=key,
            material=base["material"],
            price_per_kg=round(median, 2),
            sources=quotes,
            voice_hi=f"यह {base['hi']} ₹{round(median)} प्रति किलो है।",
            updated_at=datetime.now(timezone.utc),
        )
        self._mem_cache[key] = (now, result)
        return result

    async def all_prices(self) -> list[ItemPrice]:
        out = []
        for k in BASE_RATES:
            p = await self.fetch_price(k)
            if p:
                out.append(p)
        return out
