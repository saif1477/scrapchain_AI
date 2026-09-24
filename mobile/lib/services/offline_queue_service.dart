import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

import 'pricing_api_service.dart';

/// Offline-first queue: receipt mints made without connectivity are stored in
/// Hive and flushed automatically when the network returns.
class OfflineQueueService {
  OfflineQueueService._();
  static final OfflineQueueService instance = OfflineQueueService._();

  late Box _queue;

  Future<void> init() async {
    _queue = await Hive.openBox('mint_queue');
    await Hive.openBox('price_cache');

    // Auto-flush on connectivity change
    Connectivity().onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) flush();
    });
  }

  int get pendingCount => _queue.length;

  Future<void> enqueueMint(Map<String, dynamic> body) async {
    await _queue.add(jsonEncode(body));
  }

  Future<void> flush() async {
    final keys = _queue.keys.toList();
    for (final k in keys) {
      try {
        final resp = await http.post(
          Uri.parse('${PricingApiService.baseUrl}/api/v1/receipts/mint'),
          headers: {'Content-Type': 'application/json'},
          body: _queue.get(k),
        );
        if (resp.statusCode == 201) await _queue.delete(k);
      } catch (_) {
        break; // still offline, retry later
      }
    }
  }
}
