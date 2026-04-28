import 'package:flutter/material.dart';

class OfflineVectorMapView extends StatelessWidget {
  const OfflineVectorMapView({
    super.key,
    this.mapPackPath,
    this.latitude,
    this.longitude,
    this.minHeight = 180,
    this.showMyLocation = true,
    this.interactive = true,
    this.onPreviewTap,
  });

  final String? mapPackPath;
  final double? latitude;
  final double? longitude;
  final double minHeight;
  final bool showMyLocation;
  final bool interactive;
  final VoidCallback? onPreviewTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: minHeight,
      child: const Center(
        child: Text(
          'MAP PREVIEW IS AVAILABLE ONLY ON MOBILE/DESKTOP BUILDS',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF9CA0AA),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}
