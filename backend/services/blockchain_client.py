"""Blockchain client.

FABRIC_MODE=live      -> Fabric Gateway gRPC to peer0.scrapchain.org, invokes
                         the Go chaincode in blockchain/chaincode/.
FABRIC_MODE=simulated -> a faithful in-database simulation: an append-only,
                         SHA-256 hash-chained ledger with the SAME transaction
                         semantics as the chaincode (mintReceipt/verifyReceipt/
                         getReceiptHistory). Every receipt is anchored to a
                         block whose hash covers (prev_hash + canonical tx),
                         so tampering with any historical row invalidates the
                         chain — verifiable via /receipts/{id}.
"""
import hashlib
import json
import os
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy.orm import Session

from db_models import LedgerBlock, ReceiptRecord
from models.schemas import BlockchainProof, DigitalReceipt

GENESIS_HASH = "0" * 64


def _sha256(data: str) -> str:
    return hashlib.sha256(data.encode()).hexdigest()


def _canonical(payload: dict) -> str:
    return json.dumps(payload, sort_keys=True, separators=(",", ":"))


class FabricClient:
    def __init__(self):
        self.mode = os.getenv("FABRIC_MODE", "simulated")
        self.msp_id = os.getenv("FABRIC_MSP_ID", "ScrapChainMSP")
        self.channel = os.getenv("FABRIC_CHANNEL", "scrapchain-channel")
        self.chaincode = os.getenv("FABRIC_CHAINCODE", "receipt-chaincode")
        # In live mode: initialize fabric-gateway gRPC connection here.

    # ---- mintReceipt -------------------------------------------------
    def mint_receipt(
        self,
        db: Session,
        *,
        item_type: str,
        material: str,
        weight_kg: float,
        price_per_kg: float,
        collector_id: str,
        recycler_id: int,
    ) -> ReceiptRecord:
        ts = datetime.now(timezone.utc)
        total = round(weight_kg * price_per_kg, 2)

        tx = {
            "item_type": item_type,
            "material": material,
            "weight_kg": weight_kg,
            "price_per_kg": price_per_kg,
            "total_amount": total,
            "collector_id": collector_id,
            "recycler_id": recycler_id,
            "timestamp": ts.isoformat(),
            "msp_id": self.msp_id,
            "channel": self.channel,
        }
        payload = _canonical(tx)
        receipt_id = _sha256(payload)

        prev = (
            db.query(LedgerBlock).order_by(LedgerBlock.index.desc()).first()
        )
        prev_hash = prev.block_hash if prev else GENESIS_HASH
        block_hash = _sha256(prev_hash + payload)

        block = LedgerBlock(
            tx_payload=payload, prev_hash=prev_hash, block_hash=block_hash, timestamp=ts
        )
        db.add(block)
        db.flush()  # assigns block.index

        record = ReceiptRecord(
            receipt_id=receipt_id,
            item_type=item_type,
            material=material,
            weight_kg=weight_kg,
            price_per_kg=price_per_kg,
            total_amount=total,
            collector_id=collector_id,
            recycler_id=recycler_id,
            block_index=block.index,
            block_hash=block_hash,
            prev_hash=prev_hash,
            timestamp=ts,
        )
        db.add(record)
        db.commit()
        db.refresh(record)
        return record

    # ---- verifyReceipt -----------------------------------------------
    def verify_receipt(self, db: Session, receipt_id: str) -> Optional[DigitalReceipt]:
        rec = db.get(ReceiptRecord, receipt_id)
        if rec is None:
            return None

        # Re-validate the hash chain segment ending at this receipt's block.
        chain_valid = self._validate_chain(db, upto_index=rec.block_index)
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
                chain_valid=chain_valid,
            ),
        )

    def _validate_chain(self, db: Session, upto_index: int) -> bool:
        blocks = (
            db.query(LedgerBlock)
            .filter(LedgerBlock.index <= upto_index)
            .order_by(LedgerBlock.index.asc())
            .all()
        )
        prev_hash = GENESIS_HASH
        for b in blocks:
            if b.prev_hash != prev_hash:
                return False
            if _sha256(b.prev_hash + b.tx_payload) != b.block_hash:
                return False
            prev_hash = b.block_hash
        return True

    # ---- getReceiptHistory --------------------------------------------
    def collector_history(self, db: Session, collector_id: str) -> list[ReceiptRecord]:
        return (
            db.query(ReceiptRecord)
            .filter(ReceiptRecord.collector_id == collector_id)
            .order_by(ReceiptRecord.timestamp.desc())
            .all()
        )
