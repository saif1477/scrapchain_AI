import 'dart:ui';

/// A single YOLOv8 detection.
class Detection {
  final String label;
  final double confidence;
  final Rect boundingBox; // normalized 0..1
  const Detection({
    required this.label,
    required this.confidence,
    required this.boundingBox,
  });

  bool get isHazard => label == 'Acid-Container' || label == 'Battery' || label == 'CRT';
}

class ItemPrice {
  final String itemType;
  final String material;
  final double pricePerKg;
  final String voiceHi;
  final List<Map<String, dynamic>> sources;

  const ItemPrice({
    required this.itemType,
    required this.material,
    required this.pricePerKg,
    this.voiceHi = '',
    this.sources = const [],
  });

  factory ItemPrice.fromJson(Map<String, dynamic> j) => ItemPrice(
        itemType: j['item_type'] as String,
        material: (j['material'] ?? '') as String,
        pricePerKg: (j['price_per_kg'] as num).toDouble(),
        voiceHi: (j['voice_hi'] ?? '') as String,
        sources: List<Map<String, dynamic>>.from(j['sources'] ?? const []),
      );

  Map<String, dynamic> toJson() => {
        'item_type': itemType,
        'material': material,
        'price_per_kg': pricePerKg,
        'voice_hi': voiceHi,
        'sources': sources,
      };
}

class RecyclerMatch {
  final int id;
  final String name;
  final double distanceKm;
  final double rating;
  final double paymentSpeedHours;
  final bool cpcbAuthorized;
  final double matchScore;
  final String phone;

  const RecyclerMatch({
    required this.id,
    required this.name,
    required this.distanceKm,
    required this.rating,
    required this.paymentSpeedHours,
    required this.cpcbAuthorized,
    required this.matchScore,
    this.phone = '',
  });

  factory RecyclerMatch.fromJson(Map<String, dynamic> j) => RecyclerMatch(
        id: j['id'] as int,
        name: j['name'] as String,
        distanceKm: (j['distance_km'] as num).toDouble(),
        rating: (j['rating'] as num).toDouble(),
        paymentSpeedHours: (j['payment_speed_hours'] as num).toDouble(),
        cpcbAuthorized: j['cpcb_authorized'] as bool,
        matchScore: (j['match_score'] as num).toDouble(),
        phone: (j['phone'] ?? '') as String,
      );
}

class DigitalReceipt {
  final String receiptId;
  final String itemType;
  final double weightKg;
  final double pricePerKg;
  final double totalAmount;
  final String collectorId;
  final int recyclerId;
  final DateTime timestamp;
  final int? blockIndex;
  final bool chainValid;

  const DigitalReceipt({
    required this.receiptId,
    required this.itemType,
    required this.weightKg,
    required this.pricePerKg,
    required this.totalAmount,
    required this.collectorId,
    required this.recyclerId,
    required this.timestamp,
    this.blockIndex,
    this.chainValid = true,
  });

  factory DigitalReceipt.fromJson(Map<String, dynamic> j) => DigitalReceipt(
        receiptId: j['receipt_id'] as String,
        itemType: j['item_type'] as String,
        weightKg: (j['weight_kg'] as num).toDouble(),
        pricePerKg: (j['price_per_kg'] as num).toDouble(),
        totalAmount: (j['total_amount'] as num).toDouble(),
        collectorId: j['collector_id'] as String,
        recyclerId: j['recycler_id'] as int,
        timestamp: DateTime.parse(j['timestamp'] as String),
        blockIndex: j['proof']?['block_index'] as int?,
        chainValid: (j['proof']?['chain_valid'] ?? true) as bool,
      );
}
