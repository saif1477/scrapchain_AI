import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';
import 'offline_queue_service.dart';
import 'pricing_api_service.dart';

/// Blockchain receipts via the backend Fabric gateway.
/// Offline: mint requests are queued in Hive and synced when connectivity returns.
class BlockchainService {
  BlockchainService._();
  static final BlockchainService instance = BlockchainService._();

  static String get baseUrl => PricingApiService.baseUrl;

  Future<DigitalReceipt?> mintReceipt({
    required String itemType,
    required String material,
    required double weightKg,
    required double pricePerKg,
    required String collectorId,
    required int recyclerId,
  }) async {
    final body = {
      'item_type': itemType,
      'material': material,
      'weight_kg': weightKg,
      'price_per_kg': pricePerKg,
      'collector_id': collectorId,
      'recycler_id': recyclerId,
    };
    try {
      final resp = await http
          .post(Uri.parse('$baseUrl/api/v1/receipts/mint'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body))
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode == 201) {
        return DigitalReceipt.fromJson(jsonDecode(resp.body));
      }
    } catch (_) {
      // Offline: queue for background sync — collector still gets a local
      // provisional receipt; the chain anchor is added on sync.
      await OfflineQueueService.instance.enqueueMint(body);
    }
    return null;
  }

  Future<DigitalReceipt?> verifyReceipt(String receiptId) async {
    try {
      final resp = await http
          .get(Uri.parse('$baseUrl/api/v1/receipts/$receiptId'))
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        return DigitalReceipt.fromJson(jsonDecode(resp.body));
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> collectorLedger(String collectorId) async {
    try {
      final resp = await http
          .get(Uri.parse('$baseUrl/api/v1/users/$collectorId/ledger'))
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) return jsonDecode(resp.body);
    } catch (_) {}
    return null;
  }
}
