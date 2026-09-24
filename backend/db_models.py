"""SQLAlchemy ORM models."""
from datetime import datetime, timezone

from sqlalchemy import Boolean, Column, DateTime, Float, Integer, String, Text

from database import Base


def utcnow():
    return datetime.now(timezone.utc)


class Recycler(Base):
    __tablename__ = "recyclers"

    id = Column(Integer, primary_key=True)
    name = Column(String(120), nullable=False)
    city = Column(String(60))
    lat = Column(Float, nullable=False)
    lng = Column(Float, nullable=False)
    rating = Column(Float, default=4.0)              # 1-5
    payment_speed_hours = Column(Float, default=24)  # avg hours to pay
    cpcb_authorized = Column(Boolean, default=True)  # CPCB/SPCB authorization
    epr_registered = Column(Boolean, default=True)
    accepted_items = Column(Text, default="")        # comma-separated labels
    phone = Column(String(20), default="")


class Collector(Base):
    __tablename__ = "collectors"

    id = Column(String(40), primary_key=True)  # e.g. KBD-BLR-0042
    name = Column(String(120), nullable=False)
    phone = Column(String(20))
    language = Column(String(10), default="hi")  # hi | mr | ta | bn
    city = Column(String(60))
    eco_points = Column(Integer, default=0)
    created_at = Column(DateTime, default=utcnow)


class ReceiptRecord(Base):
    """Off-chain mirror of on-chain receipts (fast queries; chain is source of truth)."""
    __tablename__ = "receipts"

    receipt_id = Column(String(64), primary_key=True)  # SHA-256 hex
    item_type = Column(String(60), nullable=False)
    material = Column(String(60), default="")
    weight_kg = Column(Float, nullable=False)
    price_per_kg = Column(Float, nullable=False)
    total_amount = Column(Float, nullable=False)
    collector_id = Column(String(40), nullable=False)
    recycler_id = Column(Integer, nullable=False)
    block_index = Column(Integer)
    block_hash = Column(String(64))
    prev_hash = Column(String(64))
    timestamp = Column(DateTime, default=utcnow)


class LedgerBlock(Base):
    """Simulated Hyperledger Fabric world-state: an append-only hash chain.

    In FABRIC_MODE=live this table is unused and FabricClient talks gRPC
    to peer0.scrapchain.org via the Fabric Gateway.
    """
    __tablename__ = "ledger_blocks"

    index = Column(Integer, primary_key=True, autoincrement=True)
    tx_payload = Column(Text, nullable=False)   # canonical JSON of the receipt
    prev_hash = Column(String(64), nullable=False)
    block_hash = Column(String(64), nullable=False, unique=True)
    timestamp = Column(DateTime, default=utcnow)


class PriceQuote(Base):
    """Time-series price quotes (hypertable under TimescaleDB in production)."""
    __tablename__ = "price_quotes"

    id = Column(Integer, primary_key=True, autoincrement=True)
    item_type = Column(String(60), nullable=False, index=True)
    source = Column(String(60), nullable=False)
    price_per_kg = Column(Float, nullable=False)
    quoted_at = Column(DateTime, default=utcnow, index=True)
