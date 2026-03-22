import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Map screen using flutter_map + OpenStreetMap tiles (free, no API key).
///
/// Shows itinerary stop markers. Pass stops as a list of maps with
/// 'lat', 'lng', 'name', and optionally 'stop_type'.
class MapScreen extends StatelessWidget {
  final List<Map<String, dynamic>> stops;

  const MapScreen({super.key, this.stops = const []});

  @override
  Widget build(BuildContext context) {
    // Default centre: Chennai
    const defaultLat = 13.0827;
    const defaultLng = 80.2707;

    final center = stops.isNotEmpty
        ? LatLng(
            (stops.first['lat'] as num?)?.toDouble() ?? defaultLat,
            (stops.first['lng'] as num?)?.toDouble() ?? defaultLng,
          )
        : const LatLng(defaultLat, defaultLng);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text('Route Map',
            style: GoogleFonts.outfit(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 18)),
        iconTheme: const IconThemeData(color: AppColors.neonBlue),
      ),
      body: FlutterMap(
        options: MapOptions(initialCenter: center, initialZoom: 13),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.carta.app',
          ),
          MarkerLayer(
            markers: stops.map((s) {
              final lat = (s['lat'] as num?)?.toDouble() ?? defaultLat;
              final lng = (s['lng'] as num?)?.toDouble() ?? defaultLng;
              final name = s['name'] as String? ?? '';
              return Marker(
                point: LatLng(lat, lng),
                width: 36,
                height: 36,
                child: Tooltip(
                  message: name,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.neonBlue,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.neonBlue.withValues(alpha: 0.5),
                            blurRadius: 10),
                      ],
                    ),
                    child: const Icon(Icons.place_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
