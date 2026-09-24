from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from database import get_db
from models.schemas import RecyclerMatch
from services.matcher import RecyclerMatcher

router = APIRouter()
matcher = RecyclerMatcher()


@router.get("/nearby", response_model=list[RecyclerMatch])
async def get_nearby_recyclers(
    lat: float = Query(..., description="Collector latitude"),
    lng: float = Query(..., description="Collector longitude"),
    limit: int = Query(3, ge=1, le=10),
    item_type: str | None = Query(None, description="Filter by accepted item"),
    db: Session = Depends(get_db),
):
    """Top-N verified recyclers ranked by distance, rating, payment speed, authorization."""
    return matcher.find_nearby(db, lat, lng, limit, item_type)
