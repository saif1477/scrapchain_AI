from fastapi import APIRouter, HTTPException

from models.schemas import ItemPrice
from services.pricing_oracle import PricingOracle

router = APIRouter()
oracle = PricingOracle()


@router.get("/", response_model=list[ItemPrice])
async def list_prices():
    """All 20 e-waste categories with current median ₹/kg."""
    return await oracle.all_prices()


@router.get("/{item_type}", response_model=ItemPrice)
async def get_price(item_type: str):
    """Real-time price/kg aggregated from 5 sources (median, outlier-robust)."""
    price = await oracle.fetch_price(item_type)
    if price is None:
        raise HTTPException(status_code=404, detail=f"Unknown item type: {item_type}")
    return price
