# 🎬 90-Second Demo Script (judge-facing)

Open `http://localhost:8000/demo` (or the Flutter app on a phone).

| Time | Action | What judges see |
|---|---|---|
| 0:00–0:15 | Point camera at a PCB / tap **PCB** | YOLOv8 bounding box "PCB · 0.93", material "Gold-Plated" |
| 0:15–0:30 | Price appears + voice | "यह पीसीबी ₹380 प्रति किलो है।" — median of 5 live source quotes shown |
| 0:30–0:40 | **Find recyclers** | Top-3 CPCB-authorized recyclers: GreenTech Pvt Ltd, 1.2 km, pays in 3h, 96% match |
| 0:40–0:55 | Tap recycler → receipt minted | SHA-256 receipt ID, block #, QR code; tap **Re-verify** → "chain intact ✓" |
| 0:55–1:10 | **AR Safety** step | Red overlay "Acid-Container · 0.94" + Hindi audio alert "सावधान! एसिड कंटेनर" |
| 1:10–1:25 | **Green Ledger** | Receipts, ₹ earnings, EcoPoints, "Micro-loan eligible: ₹10,000+" |
| 1:25–1:30 | Close | Impact banner: 2 lakh collectors · 60% safer · 70–80% EPR traceability |

**Talking points**
1. AI runs **on-device** (6 MB TFLite) — works in a scrap yard with zero network.
2. Every receipt is **hash-anchored**: tamper with one row and verification fails live (demo it!).
3. Voice-first in 4 languages — built for users who may not read or type.
4. The receipt trail doubles as a **credit history** → formal micro-finance access.
