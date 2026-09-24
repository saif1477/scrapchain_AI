"""Recycler matcher.

Production design: a GraphSAGE GNN over the (collector, recycler) transaction
graph, retrained nightly. The demo uses the same scoring features with an
interpretable weighted model — identical API, explainable output, no GPU needed.

score = 0.40 * distance_score + 0.25 * rating + 0.20 * payment_speed
      + 0.15 * authorization
"""
import math

from sqlalchemy.orm import Session

from db_models import Recycler
from models.schemas import RecyclerMatch


def haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    r = 6371.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp = math.radians(lat2 - lat1)
    dl = math.radians(lng2 - lng1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(a))


class RecyclerMatcher:
    MAX_RADIUS_KM = 25.0

    def find_nearby(
        self,
        db: Session,
        lat: float,
        lng: float,
        limit: int = 3,
        item_type: str | None = None,
    ) -> list[RecyclerMatch]:
        candidates = db.query(Recycler).all()
        scored: list[RecyclerMatch] = []

        for r in candidates:
            d = haversine_km(lat, lng, r.lat, r.lng)
            if d > self.MAX_RADIUS_KM:
                continue
            if item_type and r.accepted_items and item_type not in r.accepted_items.split(","):
                continue

            distance_score = max(0.0, 1.0 - d / self.MAX_RADIUS_KM)
            rating_score = (r.rating - 1.0) / 4.0
            speed_score = max(0.0, 1.0 - r.payment_speed_hours / 72.0)
            auth_score = (0.7 if r.cpcb_authorized else 0.0) + (0.3 if r.epr_registered else 0.0)

            score = (
                0.40 * distance_score
                + 0.25 * rating_score
                + 0.20 * speed_score
                + 0.15 * auth_score
            )
            scored.append(
                RecyclerMatch(
                    id=r.id,
                    name=r.name,
                    city=r.city,
                    distance_km=round(d, 1),
                    rating=r.rating,
                    payment_speed_hours=r.payment_speed_hours,
                    cpcb_authorized=r.cpcb_authorized,
                    epr_registered=r.epr_registered,
                    match_score=round(score, 3),
                    phone=r.phone or "",
                )
            )

        scored.sort(key=lambda m: m.match_score, reverse=True)
        return scored[:limit]
