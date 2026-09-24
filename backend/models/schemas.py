"""Pydantic schemas (API contracts)."""
from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


class SourceQuote(BaseModel):
    source: str
    price_per_kg: float


class ItemPrice(BaseModel):
    item_type: str
    material: str = ""
    price_per_kg: float
    currency: str = "INR"
    sources: list[SourceQuote] = []
    method: str = "median-of-sources"
    voice_hi: str = ""   # ready-to-speak Hindi TTS line
    updated_at: datetime


class RecyclerMatch(BaseModel):
    id: int
    name: str
    city: Optional[str] = None
    distance_km: float
    rating: float
    payment_speed_hours: float
    cpcb_authorized: bool
    epr_registered: bool
    match_score: float
    phone: str = ""


class ReceiptMintRequest(BaseModel):
    item_type: str
    material: str = ""
    weight_kg: float = Field(gt=0)
    price_per_kg: float = Field(gt=0)
    collector_id: str
    recycler_id: int


class BlockchainProof(BaseModel):
    block_index: int
    block_hash: str
    prev_hash: str
    chain_valid: bool


class DigitalReceipt(BaseModel):
    receipt_id: str
    item_type: str
    material: str = ""
    weight_kg: float
    price_per_kg: float
    total_amount: float
    collector_id: str
    recycler_id: int
    timestamp: datetime
    proof: Optional[BlockchainProof] = None


class CollectorCreate(BaseModel):
    id: str
    name: str
    phone: str = ""
    language: str = "hi"
    city: str = ""


class CollectorLedger(BaseModel):
    collector_id: str
    name: str
    eco_points: int
    total_receipts: int
    total_earnings: float
    total_weight_kg: float
    microloan_eligible: bool
    microloan_limit: float
    receipts: list[DigitalReceipt]
