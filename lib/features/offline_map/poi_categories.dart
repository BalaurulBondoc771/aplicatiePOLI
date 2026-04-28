import 'package:flutter/material.dart';

/// Defines a POI (Point of Interest) category for the offline map.
class PoiCategory {
  const PoiCategory({
    required this.id,
    required this.label,
    required this.color,
    required this.iconData,
    required this.tagSnippets,
    this.minZoom = 10,
  });

  final String id;
  final String label;
  final Color color;
  final IconData iconData;

  /// Substrings searched inside the `other_tags` field from the MBTiles points layer.
  final List<String> tagSnippets;
  final int minZoom;

  /// MapLibre style layer id for this category.
  String get layerId => 'poi-$id';

  /// CSS hex color string (#rrggbb) used in MapLibre style JSON.
  String get hexColor {
    final r = color.r.toInt().toRadixString(16).padLeft(2, '0');
    final g = color.g.toInt().toRadixString(16).padLeft(2, '0');
    final b = color.b.toInt().toRadixString(16).padLeft(2, '0');
    return '#$r$g$b';
  }
}

/// All POI categories with display properties and their OSM `type` values.
const List<PoiCategory> kPoiCategories = [
  PoiCategory(
    id: 'medical',
    label: 'Medical',
    color: Color(0xFFEF4444),
    iconData: Icons.local_hospital,
    tagSnippets: [
      '"amenity"=>"hospital"',
      '"amenity"=>"clinic"',
      '"amenity"=>"pharmacy"',
      '"amenity"=>"doctors"',
      '"amenity"=>"dentist"',
      '"healthcare"=>"hospital"',
      '"healthcare"=>"clinic"',
      '"healthcare"=>"pharmacy"',
      '"amenity"=>"veterinary"',
    ],
  ),
  PoiCategory(
    id: 'food',
    label: 'Mâncare',
    color: Color(0xFFF97316),
    iconData: Icons.fastfood,
    tagSnippets: [
      '"amenity"=>"restaurant"',
      '"amenity"=>"cafe"',
      '"amenity"=>"bar"',
      '"amenity"=>"fast_food"',
      '"amenity"=>"pub"',
      '"amenity"=>"food_court"',
      '"amenity"=>"biergarten"',
      '"shop"=>"bakery"',
      '"amenity"=>"ice_cream"',
    ],
  ),
  PoiCategory(
    id: 'transport',
    label: 'Transport',
    color: Color(0xFF3B82F6),
    iconData: Icons.directions_bus,
    tagSnippets: [
      '"highway"=>"bus_stop"',
      '"railway"=>"station"',
      '"railway"=>"halt"',
      '"aeroway"=>"aerodrome"',
      '"amenity"=>"fuel"',
      '"amenity"=>"parking"',
      '"amenity"=>"taxi"',
      '"amenity"=>"ferry_terminal"',
      '"railway"=>"tram_stop"',
    ],
  ),
  PoiCategory(
    id: 'shopping',
    label: 'Cumpărături',
    color: Color(0xFFA855F7),
    iconData: Icons.shopping_cart,
    tagSnippets: [
      '"shop"=>"supermarket"',
      '"shop"=>"convenience"',
      '"shop"=>"clothes"',
      '"shop"=>"electronics"',
      '"shop"=>"hardware"',
      '"amenity"=>"marketplace"',
      '"shop"=>"mall"',
      '"shop"=>"department_store"',
      '"shop"=>"general"',
      '"shop"=>"kiosk"',
      '"shop"=>"florist"',
      '"shop"=>"gift"',
    ],
  ),
  PoiCategory(
    id: 'tourism',
    label: 'Turism',
    color: Color(0xFF10B981),
    iconData: Icons.photo_camera,
    tagSnippets: [
      '"tourism"=>"hotel"',
      '"tourism"=>"hostel"',
      '"tourism"=>"motel"',
      '"tourism"=>"guest_house"',
      '"tourism"=>"museum"',
      '"tourism"=>"attraction"',
      '"tourism"=>"viewpoint"',
      '"historic"=>"castle"',
      '"historic"=>"monument"',
      '"historic"=>"ruins"',
      '"tourism"=>"artwork"',
      '"tourism"=>"information"',
      '"tourism"=>"camp_site"',
      '"tourism"=>"caravan_site"',
    ],
  ),
  PoiCategory(
    id: 'education',
    label: 'Educație',
    color: Color(0xFFF59E0B),
    iconData: Icons.school,
    tagSnippets: [
      '"amenity"=>"school"',
      '"amenity"=>"university"',
      '"amenity"=>"college"',
      '"amenity"=>"kindergarten"',
      '"amenity"=>"library"',
      '"amenity"=>"research_institute"',
    ],
  ),
  PoiCategory(
    id: 'finance',
    label: 'Finanțe',
    color: Color(0xFF6366F1),
    iconData: Icons.account_balance,
    tagSnippets: [
      '"amenity"=>"bank"',
      '"amenity"=>"atm"',
      '"amenity"=>"bureau_de_change"',
    ],
  ),
  PoiCategory(
    id: 'emergency',
    label: 'Urgențe',
    color: Color(0xFFDC2626),
    iconData: Icons.security,
    tagSnippets: [
      '"amenity"=>"police"',
      '"amenity"=>"fire_station"',
      '"emergency"=>"ambulance_station"',
      '"emergency"=>"phone"',
      '"amenity"=>"emergency_service"',
    ],
  ),
  PoiCategory(
    id: 'religious',
    label: 'Lăcașuri',
    color: Color(0xFF92400E),
    iconData: Icons.place,
    tagSnippets: [
      '"amenity"=>"place_of_worship"',
      '"building"=>"church"',
      '"religion"=>"christian"',
      '"building"=>"cathedral"',
      '"building"=>"chapel"',
      '"monastery"=>"yes"',
    ],
  ),
  PoiCategory(
    id: 'nature',
    label: 'Natură',
    color: Color(0xFF16A34A),
    iconData: Icons.terrain,
    tagSnippets: [
      '"natural"=>"peak"',
      '"natural"=>"spring"',
      '"waterway"=>"waterfall"',
      '"natural"=>"cave_entrance"',
      '"natural"=>"tree"',
    ],
    minZoom: 11,
  ),
];
