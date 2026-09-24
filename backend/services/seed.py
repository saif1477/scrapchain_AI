"""Seed 50 authorized recyclers across 6 Indian metros + demo collectors."""
import hashlib

from sqlalchemy.orm import Session

from db_models import Collector, Recycler

CITIES = {
    "Bengaluru": (12.9716, 77.5946),
    "Delhi NCR": (28.6139, 77.2090),
    "Mumbai": (19.0760, 72.8777),
    "Chennai": (13.0827, 80.2707),
    "Hyderabad": (17.3850, 78.4867),
    "Kolkata": (22.5726, 88.3639),
}

NAMES = [
    "GreenTech Recyclers", "EcoVerva E-Waste", "Attero Partner Hub", "Cerebra Green",
    "E-Parisaraa", "Saahas Zero Waste", "Namo eWaste", "EcoReco Solutions",
    "Virogreen India", "Zolopik Recycling", "Earth Sense Recycle", "GreenZone eCycle",
]

ITEMS = "PCB,Battery,CRT,Cable,Motor,Gold-Plated,Lithium,Transformer,Heat-Sink,Fan,Speaker,Display,Keyboard,Mouse,Charger,USB-Cable,RAM,HDD,SSD"


def _det(seed: str, lo: float, hi: float) -> float:
    h = int(hashlib.sha256(seed.encode()).hexdigest()[:8], 16)
    return lo + (h % 10000) / 10000.0 * (hi - lo)


def seed_all(db: Session) -> None:
    if db.query(Recycler).count() > 0:
        return

    idx = 0
    for city, (clat, clng) in CITIES.items():
        for i in range(9 if city == "Bengaluru" else 8):  # 9+8*5 = 49 -> +1 below = 50
            idx += 1
            name = f"{NAMES[idx % len(NAMES)]} ({city.split()[0]}-{i+1})"
            db.add(Recycler(
                id=idx,
                name=name,
                city=city,
                lat=clat + _det(f"lat{idx}", -0.12, 0.12),
                lng=clng + _det(f"lng{idx}", -0.12, 0.12),
                rating=round(_det(f"r{idx}", 3.4, 4.9), 1),
                payment_speed_hours=round(_det(f"p{idx}", 2, 48), 0),
                cpcb_authorized=_det(f"a{idx}", 0, 1) > 0.1,
                epr_registered=_det(f"e{idx}", 0, 1) > 0.15,
                accepted_items=ITEMS,
                phone=f"+91-98{int(_det(f'ph{idx}', 10000000, 99999999))}",
            ))
    # 50th: the demo star, close to MG Road Bengaluru
    db.add(Recycler(
        id=50, name="GreenTech Pvt Ltd (Flagship)", city="Bengaluru",
        lat=12.9852, lng=77.6094, rating=4.8, payment_speed_hours=3,
        cpcb_authorized=True, epr_registered=True, accepted_items=ITEMS,
        phone="+91-9845012345",
    ))

    db.add(Collector(
        id="KBD-BLR-0042", name="Ravi Kumar", phone="+91-9900112233",
        language="hi", city="Bengaluru", eco_points=250,
    ))
    db.commit()
