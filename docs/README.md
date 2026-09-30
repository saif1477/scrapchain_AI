# ♻️ ScrapChain AI — SIH 2026 Prototype

**Problem Statement SIH26229: "Kabadiwala Connect — Bringing the Informal Collector into the Formal Recycling Chain"**

A multimodal e-waste intelligence platform for India's 2,00,000+ informal collectors:

| Capability | Tech | Where |
|---|---|---|
| On-device e-waste detection (20 classes) | YOLOv8n → TFLite, EfficientNet-B0 material head | `mobile/lib/services/ai_inference_service.dart`, `ai_models/` |
| Real-time pricing (median of 5 sources) | FastAPI oracle + Redis cache + TimescaleDB series | `backend/services/pricing_oracle.py` |
| Recycler matching (50 seeded, 6 metros) | Weighted graph scoring (GNN-ready features) | `backend/services/matcher.py` |
| Blockchain digital receipts | Hyperledger Fabric 2.5 Go chaincode + simulated hash-chain ledger | `blockchain/`, `backend/services/blockchain_client.py` |
| Voice-first UI (hi/mr/ta/bn) | speech_to_text + flutter_tts + whisper.cpp offline path | `mobile/lib/services/voice_service.dart`, `voice_ar/` |
| AR hazard detection | Hazard-class YOLO + overlay + audio alerts | `mobile/lib/screens/ar_safety_screen.dart` |
| Offline-first | Hive queue + auto background sync | `mobile/lib/services/offline_queue_service.dart` |

## Quick start

### Backend + live browser demo (zero external deps — SQLite + simulated Fabric)
```bash
cd backend
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000
# → http://localhost:8000/demo  (90-second interactive demo)
# → http://localhost:8000/docs  (Swagger)
```

### Full stack (PostgreSQL 16 + TimescaleDB + Redis)
```bash
cd docker && docker compose up -d
```

### Real Fabric network (optional; demo runs without it)
```bash
bash blockchain/scripts/network_up.sh   # needs fabric-samples binaries
# then set FABRIC_MODE=live in backend/.env
```

### Mobile app
```bash
cd mobile
flutter pub get
flutter run --dart-define=API_BASE=http://10.0.2.2:8000   # Android emulator
```
> TFLite weights are produced by `ai_models/training/train_yolov8.py` (GPU, ~3h).
> Without weights the app runs in demo-detection mode so every flow is testable.

## API (v1)
| Endpoint | Description |
|---|---|
| `GET /api/v1/pricing/{item}` | Median ₹/kg + 5 source quotes + Hindi TTS line |
| `GET /api/v1/recyclers/nearby?lat&lng&limit&item_type` | Top-N ranked recyclers |
| `POST /api/v1/receipts/mint` | Mint hash-anchored receipt (+EcoPoints) |
| `GET /api/v1/receipts/{id}` | Verify — recomputes the hash chain |
| `GET /api/v1/receipts/{id}/qr` | QR PNG for the receipt |
| `GET /api/v1/users/{id}/ledger` | Green Ledger: earnings, EcoPoints, micro-loan |

## Blockchain design
- **Live mode:** Fabric 2.5, etcdraft orderer, `ScrapChainMSP`, Go chaincode
  (`MintReceipt` / `VerifyReceipt` / `GetReceiptHistory`) with composite keys
  for per-collector history.
- **Simulated mode (default):** append-only SHA-256 hash chain in the DB with
  identical transaction semantics — `verify` re-hashes every block up to the
  receipt's block, so any tampering flips `chain_valid=false`. This is what
  makes the prototype demo-able on a single laptop in 90 seconds.

## Impact metrics
- **Income:** ₹10–15k → ₹22–30k/month per collector (price transparency + direct matching)
- **Safety:** targeted 60% reduction in acid leaching / open burning (AR alerts + training nudges)
- **EPR compliance:** 70–80% traceability of informal-channel e-waste via on-chain receipts
- **Environment:** 5,00,000+ tons/yr diverted from landfills at national scale
- **Finance:** receipt history = credit rail → ₹10,000+ micro-loans (5+ verified receipts)

