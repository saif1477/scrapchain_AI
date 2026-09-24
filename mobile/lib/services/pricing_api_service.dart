import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

import '../models/models.dart';

/// Backend client with offline-first caching:
/// - live: GET /api/v1/pricing/{item}
/// - offline: last cached price from Hive (refreshed every 6h background sync)
class PricingApiService {
  PricingApiService._();
  static final PricingApiService instance = PricingApiService._();

  // 10.0.2.2 = host loopback from Android emulator; override per env.
  static const String baseUrl =
      String.fromEnvironment('API_BASE', defaultValue: 'http://10.0.2.2:8000');

  Box get _cache => Hive.box('price_cache');

  Future<ItemPrice?> fetchPrice(String itemType) async {
    try {
      final resp = await http
          .get(Uri.parse('$baseUrl/api/v1/pricing/$itemType'))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final price = ItemPrice.fromJson(jsonDecode(resp.body));
        await _cache.put(itemType, jsonEncode(price.toJson()));
        return price;
      }
    } catch (_) {
      // fall through to cache
    }
    final cached = _cache.get(itemType);
    return cached == null ? null : ItemPrice.fromJson(jsonDecode(cached));
  }

  Future<List<RecyclerMatch>> nearbyRecyclers(
      double lat, double lng, String itemType) async {
    try {
      final resp = await http
          .get(Uri.parse(
              '$baseUrl/api/v1/recyclers/nearby?lat=$lat&lng=$lng&limit=3&item_type=$itemType'))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        return (jsonDecode(resp.body) as List)
            .map((j) => RecyclerMatch.fromJson(j))
            .toList();
      }
    } catch (_) {}
    return const [];
  }
}
