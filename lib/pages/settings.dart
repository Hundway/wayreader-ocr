import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../controller/theme.dart';

class SettingsPage extends StatefulWidget {
  final ThemeController themeController;
  const SettingsPage({super.key, required this.themeController});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const List<Color> accentColors = [
    Colors.blueAccent,
    Colors.teal,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.red,
  ];

  void openColorWheel() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Select a color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: widget.themeController.seedColor,
            onColorChanged: (color) {
              widget.themeController.changeSeedColor(color);
            },
            enableAlpha: true,
            displayThumbColor: true,
            labelTypes: [],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        color: theme.colorScheme.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Appearance', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),

            // ---------- Dark Mode ----------
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Dark mode'),
                Switch(
                  value: widget.themeController.brightness == Brightness.dark,
                  onChanged: widget.themeController.changeBrightness,
                ),
              ],
            ),

            // ---------- Accent Color ----------
            Text('Accent color'),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ...accentColors.map((color) {
                  final isSelected = color == widget.themeController.seedColor;
                  return GestureDetector(
                    onTap: () {
                      widget.themeController.changeSeedColor(color);
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.onSurface
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                  );
                }),

                // ---------- Color Wheel Button ----------
                GestureDetector(
                  onTap: openColorWheel,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const SweepGradient(
                        colors: [
                          Colors.red,
                          Colors.yellow,
                          Colors.green,
                          Colors.cyan,
                          Colors.blue,
                          Colors.purple,
                          Colors.red,
                        ],
                      ),
                      border: Border.all(
                        color:
                            widget.themeController.seedColor,
                        width: 3,
                      ),
                    ),
                    child: const Icon(
                      Icons.palette,
                      size: 26,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
