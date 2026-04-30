import 'package:flutter/material.dart';

import 'offline_vector_map_view.dart';

Future<void> showOfflineMapDialog({
  required BuildContext context,
  String? mapPackPath,
  double? latitude,
  double? longitude,
  bool showMyLocation = true,
  String title = 'MAP',
}) {
  return showDialog<void>(
    context: context,
    barrierColor: const Color(0xDD020304),
    builder: (context) {
      return Dialog.fullscreen(
        backgroundColor: const Color(0xFF050608),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                height: 68,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                color: const Color(0xFF0F1218),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Icon(Icons.close, color: Color(0xFFA8ADB8), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFFF7B21A),
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const Text(
                      'PAN + ZOOM',
                      style: TextStyle(
                        color: Color(0xFF8F939D),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: OfflineVectorMapView(
                  mapPackPath: mapPackPath,
                  latitude: latitude,
                  longitude: longitude,
                  minHeight: double.infinity,
                  showMyLocation: showMyLocation,
                  interactive: true,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}