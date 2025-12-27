import 'package:flutter/material.dart';

class ThemeController {
  Color seedColor;
  Brightness brightness = Brightness.dark;
  double contrastLevel = 1;

  late Function setState;

  ThemeController({
    required this.setState,
    this.brightness = Brightness.dark,
    this.seedColor = Colors.blueAccent,
  });

  void changeSeedColor(Color color) {
    setState(() {
      seedColor = color;
    });
  }

  void changeBrightness(bool isDark) {
    setState(() {
      brightness = isDark ? Brightness.dark : Brightness.light;
    });
  }

  ThemeData getTheme() => ThemeData.from(
    colorScheme: ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
      contrastLevel: contrastLevel,
      dynamicSchemeVariant: DynamicSchemeVariant.content,
    ),
  );
}
