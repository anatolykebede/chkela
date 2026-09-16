import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../core/theme/app_colors.dart';

class MapCityPin {
  const MapCityPin({
    required this.name,
    required this.location,
    required this.subjectStrength,
    required this.pinColor,
  });

  final String name;
  final LatLng location;
  final String subjectStrength;
  final Color pinColor;
}

const ethiopiaMapCenter = LatLng(9.15, 39.8);
const ethiopiaMapZoom = 5.8;

const ethiopiaCityPins = [
  MapCityPin(
    name: 'Bahir Dar',
    location: LatLng(11.5936, 37.3908),
    subjectStrength: 'Physics',
    pinColor: AppColors.info,
  ),
  MapCityPin(
    name: 'Dire Dawa',
    location: LatLng(9.5931, 41.8661),
    subjectStrength: 'Chemistry',
    pinColor: AppColors.teal,
  ),
  MapCityPin(
    name: 'Addis',
    location: LatLng(9.0320, 38.7469),
    subjectStrength: 'Mathematics',
    pinColor: AppColors.accent,
  ),
  MapCityPin(
    name: 'Harar',
    location: LatLng(9.3133, 42.1164),
    subjectStrength: 'Biology',
    pinColor: AppColors.teal,
  ),
  MapCityPin(
    name: 'Jimma',
    location: LatLng(7.6667, 36.8333),
    subjectStrength: 'English',
    pinColor: AppColors.amber,
  ),
  MapCityPin(
    name: 'Hawassa',
    location: LatLng(7.0621, 38.4764),
    subjectStrength: 'Physics',
    pinColor: AppColors.info,
  ),
];
