from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from database import get_db
from db_models import Collector
from models.schemas import (
    BlockchainProof,
    CollectorCreate,
    CollectorLedger,
    DigitalReceipt,
)
from services.blockchain_client import FabricClient

router = APIRouter()
fabric = FabricClient()

MICROLOAN_MIN_RECEIPTS = 5
MICROLOAN_BASE = 10_000.0


@router.post("/", status_code=201)
async def register_collector(body: CollectorCreate, db: Session = Depends(get_db)):
    if db.get(Collector, body.id):
        raise HTTPException(status_code=409, detail="Collector already exists")
    c = Collector(**body.model_dump())
    db.add(c)
    db.commit()
    return {"id": c.id, "status": "registered"}


@router.get("/{collector_id}/ledger", response_model=CollectorLedger)
async def green_ledger(collector_id: str, db: Session = Depends(get_db)):
    """The collector's Green Ledger: receipts, EcoPoints, microloan eligibility."""
    collector = db.get(Collector, collector_id)
    if collector is None:
        raise HTTPException(status_code=404, detail="Collector not found")

    records = fabric.collector_history(db, collector_id)
    receipts = [
        DigitalReceipt(
            receipt_id=r.receipt_id, item_type=r.item_type, material=r.material or "",
            weight_kg=r.weight_kg, price_per_kg=r.price_per_kg, total_amount=r.total_amount,
            collector_id=r.collector_id, recycler_id=r.recycler_id, timestamp=r.timestamp,
            proof=BlockchainProof(
                block_index=r.block_index, block_hash=r.block_hash,
                prev_hash=r.prev_hash, chain_valid=True,
            ),
        )
        for r in records
    ]
    total_earnings = sum(r.total_amount for r in records)
    eligible = len(records) >= MICROLOAN_MIN_RECEIPTS
    return CollectorLedger(
        collector_id=collector.id,
        name=collector.name,
        eco_points=collector.eco_points,
        total_receipts=len(records),
        total_earnings=round(total_earnings, 2),
        total_weight_kg=round(sum(r.weight_kg for r in records), 2),
        microloan_eligible=eligible,
        microloan_limit=MICROLOAN_BASE + (total_earnings * 0.5 if eligible else 0),
        receipts=receipts,
    )
