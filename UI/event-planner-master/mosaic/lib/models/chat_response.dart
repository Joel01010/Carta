// Dart models matching the Carta backend JSON responses.

class ChatResponse {
  final String reply;
  final ItineraryModel? itinerary;

  const ChatResponse({required this.reply, this.itinerary});

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    return ChatResponse(
      reply: json['reply'] as String? ?? '',
      itinerary: json['itinerary'] != null
          ? ItineraryModel.fromJson(json['itinerary'] as Map<String, dynamic>)
          : null,
    );
  }
}

class ItineraryModel {
  final String title;
  final String date;
  final int totalCostEstimate;
  final String summary;
  final List<StopModel> stops;

  const ItineraryModel({
    required this.title,
    required this.date,
    required this.totalCostEstimate,
    required this.summary,
    required this.stops,
  });

  factory ItineraryModel.fromJson(Map<String, dynamic> json) {
    return ItineraryModel(
      title: json['title'] as String? ?? '',
      date: json['date'] as String? ?? '',
      totalCostEstimate: json['total_cost_estimate'] as int? ?? 0,
      summary: json['summary'] as String? ?? '',
      stops: (json['stops'] as List<dynamic>?)
              ?.map((s) => StopModel.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'date': date,
        'total_cost_estimate': totalCostEstimate,
        'summary': summary,
        'stops': stops.map((s) => s.toJson()).toList(),
      };
}

class StopModel {
  final String time;
  final String stopType;
  final String name;
  final String? address;
  final double? lat;
  final double? lng;
  final int costEstimate;
  final int durationMins;
  final String? notes;
  final String? externalUrl;

  const StopModel({
    required this.time,
    required this.stopType,
    required this.name,
    this.address,
    this.lat,
    this.lng,
    this.costEstimate = 0,
    this.durationMins = 60,
    this.notes,
    this.externalUrl,
  });

  factory StopModel.fromJson(Map<String, dynamic> json) {
    return StopModel(
      time: json['time'] as String? ?? '',
      stopType: json['stop_type'] as String? ?? 'event',
      name: json['name'] as String? ?? '',
      address: json['address'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      costEstimate: json['cost_estimate'] as int? ?? 0,
      durationMins: json['duration_mins'] as int? ?? 60,
      notes: json['notes'] as String?,
      externalUrl: json['external_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'time': time,
        'stop_type': stopType,
        'name': name,
        'address': address,
        'lat': lat,
        'lng': lng,
        'cost_estimate': costEstimate,
        'duration_mins': durationMins,
        'notes': notes,
        'external_url': externalUrl,
      };

  String get emoji => switch (stopType) {
        'meal' => '🍽️',
        'event' => '🎭',
        'drinks' => '🍹',
        'fuel' => '⛽',
        _ => '📍',
      };
}
