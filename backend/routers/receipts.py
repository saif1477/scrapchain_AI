import io

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import Response
from sqlalchemy.orm import Session

from database import get_db
from db_models import Collector
from models.schemas import BlockchainProof, DigitalReceipt, ReceiptMintRequest
from services.blockchain_client import FabricClient

router = APIRouter()
fabric = FabricClient()

ECO_POINTS_PER_KG = 10


@router.post("/mint", response_model=DigitalReceipt, status_code=201)
async def mint_receipt(req: ReceiptMintRequest, db: Session = Depends(get_db)):
    """Mint a blockchain-anchored digital receipt for an e-waste handover."""
    rec = fabric.mint_receipt(
        db,
        item_type=req.item_type,
        material=req.material,
        weight_kg=req.weight_kg,
        price_per_kg=req.price_per_kg,
        collector_id=req.collector_id,
        recycler_id=req.recycler_id,
    )
    # Award EcoPoints
    collector = db.get(Collector, req.collector_id)
    if collector:
        collector.eco_points += int(req.weight_kg * ECO_POINTS_PER_KG)
        db.commit()

    return DigitalReceipt(
        receipt_id=rec.receipt_id,
        item_type=rec.item_type,
        material=rec.material or "",
        weight_kg=rec.weight_kg,
        price_per_kg=rec.price_per_kg,
        total_amount=rec.total_amount,
        collector_id=rec.collector_id,
        recycler_id=rec.recycler_id,
        timestamp=rec.timestamp,
        proof=BlockchainProof(
            block_index=rec.block_index,
            block_hash=rec.block_hash,
            prev_hash=rec.prev_hash,
            chain_valid=True,
        ),
    )


@router.get("/{receipt_id}", response_model=DigitalReceipt)
async def verify_receipt(receipt_id: str, db: Session = Depends(get_db)):
    """Verify a receipt against the ledger: recomputes the hash chain up to its block."""
    receipt = fabric.verify_receipt(db, receipt_id)
    if receipt is None:
        raise HTTPException(status_code=404, detail="Receipt not found on ledger")
    return receipt


@router.get("/{receipt_id}/qr")
async def receipt_qr(receipt_id: str, db: Session = Depends(get_db)):
    """PNG QR code encoding the verification URL for this receipt."""
    if fabric.verify_receipt(db, receipt_id) is None:
        raise HTTPException(status_code=404, detail="Receipt not found on ledger")
    try:
        import qrcode
    except ImportError:
        raise HTTPException(status_code=501, detail="qrcode package not installed")

    img = qrcode.make(f"scrapchain://verify/{receipt_id}")
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return Response(content=buf.getvalue(), media_type="image/png")
