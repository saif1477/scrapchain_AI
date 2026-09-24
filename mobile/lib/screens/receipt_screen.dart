import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';
import '../services/blockchain_service.dart';

/// Blockchain receipt: QR, details, share, Green Ledger.
class ReceiptScreen extends StatefulWidget {
  final DigitalReceipt receipt;
  const ReceiptScreen({super.key, required this.receipt});

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  bool? _verified;

  Future<void> _verify() async {
    final v = await BlockchainService.instance
        .verifyReceipt(widget.receipt.receiptId);
    setState(() => _verified = v?.chainValid ?? false);
  }

  Future<void> _showLedger() async {
    final ledger = await BlockchainService.instance
        .collectorLedger(widget.receipt.collectorId);
    if (!mounted || ledger == null) return;
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🌱 Green Ledger',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _stat('${ledger['total_receipts']}', 'Receipts'),
            _stat('₹${ledger['total_earnings']}', 'Earnings'),
            _stat('${ledger['eco_points']}', 'EcoPoints'),
          ]),
          const SizedBox(height: 12),
          Chip(
            label: Text(ledger['microloan_eligible'] == true
                ? '✅ Micro-loan eligible: ₹${(ledger['microloan_limit'] as num).round()}'
                : 'Micro-loan unlocks at 5 receipts'),
            backgroundColor: ledger['microloan_eligible'] == true
                ? Colors.green.shade900
                : Colors.grey.shade800,
          ),
        ]),
      ),
    );
  }

  Widget _stat(String v, String k) => Column(children: [
        Text(v,
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.greenAccent)),
        Text(k, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ]);

  @override
  Widget build(BuildContext context) {
    final r = widget.receipt;
    final fmt = DateFormat('dd MMM yyyy, hh:mm a');
    return Scaffold(
      appBar: AppBar(title: const Text('⛓ Digital Receipt')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Center(
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: QrImageView(
                data: 'scrapchain://verify/${r.receiptId}', size: 200),
          ),
        ),
        const SizedBox(height: 8),
        Center(
            child: Text(
                '${r.receiptId.substring(0, 20)}…  ·  block #${r.blockIndex}',
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 11, color: Colors.white54))),
        const Divider(height: 32),
        _row('Item', r.itemType),
        _row('Weight', '${r.weightKg} kg'),
        _row('Rate', '₹${r.pricePerKg}/kg'),
        _row('Total', '₹${r.totalAmount}'),
        _row('Collector', r.collectorId),
        _row('Recycler', '#${r.recyclerId}'),
        _row('Time', fmt.format(r.timestamp.toLocal())),
        const SizedBox(height: 16),
        if (_verified != null)
          Chip(
            label: Text(_verified!
                ? '⛓ VERIFIED — hash chain intact'
                : '⚠ Verification failed'),
            backgroundColor:
                _verified! ? Colors.green.shade900 : Colors.red.shade900,
          ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: OutlinedButton.icon(
                  onPressed: _verify,
                  icon: const Icon(Icons.verified),
                  label: const Text('Verify'))),
          const SizedBox(width: 8),
          Expanded(
              child: OutlinedButton.icon(
                  onPressed: () => Share.share(
                      'ScrapChain receipt: ${r.itemType} ${r.weightKg}kg = ₹${r.totalAmount}\nVerify: scrapchain://verify/${r.receiptId}'),
                  icon: const Icon(Icons.share),
                  label: const Text('Share'))),
        ]),
        const SizedBox(height: 8),
        FilledButton.icon(
            onPressed: _showLedger,
            icon: const Icon(Icons.eco),
            label: const Text('View Green Ledger')),
      ]),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(k, style: const TextStyle(color: Colors.white54)),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
      );
}
