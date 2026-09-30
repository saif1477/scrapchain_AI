import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/models.dart';
import '../services/blockchain_service.dart';
import '../services/pricing_api_service.dart';
import '../services/voice_service.dart';
import 'receipt_screen.dart';

/// Shows detected item, live price, voice announcement, top-3 recyclers.
class ValuationScreen extends StatefulWidget {
  final Detection detection;
  const ValuationScreen({super.key, required this.detection});

  @override
  State<ValuationScreen> createState() => _ValuationScreenState();
}

class _ValuationScreenState extends State<ValuationScreen> {
  ItemPrice? _price;
  List<RecyclerMatch> _recyclers = const [];
  RecyclerMatch? _selected;
  final _weightCtrl = TextEditingController(text: '2.5');
  bool _minting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final price =
        await PricingApiService.instance.fetchPrice(widget.detection.label);
    setState(() => _price = price);
    if (price != null) {
      await VoiceService.instance
          .announcePrice(price.itemType, price.pricePerKg);
    }

    double lat = 12.9752, lng = 77.6057; // fallback: MG Road, Bengaluru
    try {
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low);
      lat = pos.latitude;
      lng = pos.longitude;
    } catch (_) {}
    final recs = await PricingApiService.instance
        .nearbyRecyclers(lat, lng, widget.detection.label);
    setState(() {
      _recyclers = recs;
      _selected = recs.isNotEmpty ? recs.first : null;
    });
  }

  Future<void> _mint() async {
    if (_price == null || _selected == null) return;
    setState(() => _minting = true);
    final receipt = await BlockchainService.instance.mintReceipt(
      itemType: _price!.itemType,
      material: _price!.material,
      weightKg: double.tryParse(_weightCtrl.text) ?? 1.0,
      pricePerKg: _price!.pricePerKg,
      collectorId: 'KBD-BLR-0042',
      recyclerId: _selected!.id,
    );
    setState(() => _minting = false);
    if (!mounted) return;
    if (receipt != null) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => ReceiptScreen(receipt: receipt)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('📴 Offline — receipt queued, will sync automatically')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.detection;
    return Scaffold(
      appBar: AppBar(title: const Text('Valuation')),
      body: _price == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.memory, size: 40),
                  title: Text('${d.label} — ${_price!.material}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      'Confidence ${(d.confidence * 100).toStringAsFixed(0)}% · on-device YOLOv8n'),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                  child: Text('₹${_price!.pricePerKg}/kg',
                      style: TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.w800,
                          color: Colors.greenAccent.shade400))),
              Center(
                  child: Text('median of ${_price!.sources.length} sources',
                      style: const TextStyle(color: Colors.white54))),
              const SizedBox(height: 16),
              TextField(
                controller: _weightCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Weight (kg)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              const Text('Top recyclers near you',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              ..._recyclers.map((r) => Card(
                    color: r == _selected
                        ? Colors.green.withOpacity(.18)
                        : null,
                    child: ListTile(
                      onTap: () => setState(() => _selected = r),
                      title: Text(r.name),
                      subtitle: Text(
                          '${r.distanceKm} km · ⭐${r.rating} · pays in ${r.paymentSpeedHours.toStringAsFixed(0)}h'
                          '${r.cpcbAuthorized ? " · CPCB ✓" : ""}'),
                      trailing:
                          Text('${(r.matchScore * 100).toStringAsFixed(0)}%'),
                    ),
                  )),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _minting ? null : _mint,
                icon: const Icon(Icons.receipt_long),
                label: Text(_minting
                    ? 'Anchoring to blockchain…'
                    : 'Generate Receipt (⛓ blockchain)'),
              ),
            ]),
    );
  }
}
