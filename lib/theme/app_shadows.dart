import 'package:flutter/material.dart';

class AppShadows {
  const AppShadows._();

  static const List<BoxShadow> none = [];

  static const List<BoxShadow> subtle = [
    BoxShadow(
      color: Color(0x06000000), // Rất nhẹ (1.5% opacity)
      blurRadius: 4,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Color(0x04000000), // Rất nhẹ (1% opacity)
      blurRadius: 10,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> medium = [
    BoxShadow(
      color: Color(0x08000000), // Nhẹ (2% opacity)
      blurRadius: 8,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x05000000), // Nhẹ (1.2% opacity)
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> glow = [
    BoxShadow(
      color: Color(0x0A5B0000), // 3.9% màu accent (đỏ rượu)
      blurRadius: 12,
      spreadRadius: 2,
    ),
  ];
}
