"""ScrapChain AI — FastAPI backend.

Run:  uvicorn main:app --host 0.0.0.0 --port 8000
Docs: /docs (Swagger)  |  Demo UI: /demo
"""
from contextlib import asynccontextmanager
from pathlib import Path

from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse
from fastapi.staticfiles import StaticFiles

load_dotenv()

from database import SessionLocal, engine  # noqa: E402
from database import Base  # noqa: E402
import db_models  # noqa: E402,F401  (register ORM models)
from routers import pricing, receipts, recyclers, users  # noqa: E402
from services.seed import seed_all  # noqa: E402


@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(bind=engine)
    with SessionLocal() as db:
        seed_all(db)
    yield


app = FastAPI(
    title="ScrapChain AI API",
    description="Real-time e-waste pricing, recycler matching, blockchain receipts — SIH26229",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # lock to app domain in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(pricing.router, prefix="/api/v1/pricing", tags=["Pricing"])
app.include_router(recyclers.router, prefix="/api/v1/recyclers", tags=["Recyclers"])
app.include_router(receipts.router, prefix="/api/v1/receipts", tags=["Receipts"])
app.include_router(users.router, prefix="/api/v1/users", tags=["Users"])

app.mount("/demo", StaticFiles(directory=Path(__file__).parent / "static" / "demo", html=True), name="demo")


@app.get("/", include_in_schema=False)
async def root():
    return RedirectResponse("/demo/")


@app.get("/health")
async def health_check():
    return {"status": "healthy", "version": "1.0.0", "fabric_mode": "simulated"}
