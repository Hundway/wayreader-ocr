import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';

enum WhiteBalance { auto, cloudy, sunny, fluorescent, tungsten }

class CameraPage extends StatefulWidget {
  const CameraPage(this.cameras, {super.key});
  final List<CameraDescription> cameras;

  @override
  State<CameraPage> createState() => _CameraState();
}

class _CameraState extends State<CameraPage> {
  late CameraController controller;
  int _currentCamera = 0;
  FlashMode _flashMode = FlashMode.off;
  bool _hdrEnabled = false;
  WhiteBalance _wb = WhiteBalance.auto;
  bool _showWBMenu = false;
  bool _showFlashAnim = false;
  Offset? _lastFocusPoint;

  @override
  void initState() {
    super.initState();

    // ---- HIDE STATUS BAR ----
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    _initCamera(widget.cameras[_currentCamera]);
  }

  @override
  void dispose() {
    // ---- RESTORE SYSTEM UI ----
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    controller.dispose();
    super.dispose();
  }

  Future<void> _initCamera(CameraDescription cam) async {
    controller = CameraController(
      cam,
      ResolutionPreset.max,
      enableAudio: false,
    );

    await controller.initialize();
    setState(() {});
  }

  // =====================================================
  // TAP TO FOCUS
  // =====================================================

  Future<void> _setFocus(
    TapDownDetails details,
    BoxConstraints constraints,
  ) async {
    final Offset pos = details.localPosition;

    final Offset normalized = Offset(
      pos.dx / constraints.maxWidth,
      pos.dy / constraints.maxHeight,
    );

    try {
      await controller.setFocusPoint(normalized);
      await controller.setExposurePoint(normalized);

      setState(() => _lastFocusPoint = pos);

      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => _lastFocusPoint = null);
      });
    } catch (_) {}
  }

  // =====================================================
  // TOGGLES
  // =====================================================

  Future<void> _toggleFlash() async {
    _flashMode = _flashMode == FlashMode.off
        ? FlashMode.auto
        : _flashMode == FlashMode.auto
        ? FlashMode.always
        : FlashMode.off;

    await controller.setFlashMode(_flashMode);
    setState(() {});
  }

  Future<void> _toggleHDR() async {
    // Note: HDR control is not directly supported by the camera package.
    _hdrEnabled = !_hdrEnabled;
    setState(() {});
  }

  void _toggleWBMenu() {
    setState(() => _showWBMenu = !_showWBMenu);
  }

  void _selectWB(WhiteBalance wb) async {
    _wb = wb;
    _showWBMenu = false;

    // Placeholder for real native hookup later:
    // await controller.setWhiteBalance(wb);

    setState(() {});
  }

  Future<void> _switchCamera() async {
    _currentCamera = (_currentCamera + 1) % widget.cameras.length;
    await controller.dispose();
    await _initCamera(widget.cameras[_currentCamera]);
  }

  // =====================================================
  // CAPTURE
  // =====================================================

  Future<void> _takePhoto() async {
    try {
      final XFile raw = await controller.takePicture();

      final Directory appDir = await getApplicationDocumentsDirectory();
      final Directory saveDir = Directory('${appDir.path}/bookocr');

      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }

      final String finalPath =
          '${saveDir.path}/BookOCR_${DateTime.now().month}-${DateTime.now().day}-${DateTime.now().year}_${DateTime.now().hour}${DateTime.now().minute}${DateTime.now().second}.jpg';

      await File(raw.path).copy(finalPath);
      await File(raw.path).delete();

      SystemSound.play(SystemSoundType.click);

      setState(() => _showFlashAnim = true);
      await Future.delayed(const Duration(milliseconds: 80));
      setState(() => _showFlashAnim = false);
    } catch (_) {}
  }

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final barColor = theme.colorScheme.surfaceContainer;
    final double statusBarHeight = MediaQuery.of(context).padding.top;

    if (!controller.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // =================================================
          // CAMERA PREVIEW — PROPER SCALE
          // =================================================
          LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => _setFocus(d, constraints),
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller.value.previewSize!.height,
                    height: controller.value.previewSize!.width,
                    child: CameraPreview(controller),
                  ),
                ),
              );
            },
          ),

          // =================================================
          // FOCUS INDICATOR
          // =================================================
          if (_lastFocusPoint != null)
            Positioned(
              left: _lastFocusPoint!.dx - 28,
              top: _lastFocusPoint!.dy - 28,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: theme.colorScheme.primary,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),

          // =================================================
          // FLASH ANIMATION
          // =================================================
          if (_showFlashAnim)
            Positioned.fill(
              child: AnimatedOpacity(
                opacity: _showFlashAnim ? 1 : 0,
                duration: const Duration(milliseconds: 120),
                child: Container(color: Colors.white),
              ),
            ),

          // =================================================
          // TOP TOOL BAR — BELOW STATUS BAR
          // =================================================
          Positioned(
            top: statusBarHeight,
            left: 0,
            right: 0,
            height: 64,
            child: Container(
              color: barColor.withValues(alpha: 0.35),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _showWBMenu
                    ? Row(
                        key: const ValueKey("WB"),
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: WhiteBalance.values.map((wb) {
                          final bool active = _wb == wb;
                          final icon = switch (wb) {
                            WhiteBalance.auto => Icons.autorenew,
                            WhiteBalance.cloudy => Icons.cloud,
                            WhiteBalance.sunny => Icons.wb_sunny,
                            WhiteBalance.fluorescent => Icons.lightbulb,
                            WhiteBalance.tungsten => Icons.bolt,
                          };

                          return InkWell(
                            onTap: () => _selectWB(wb),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  icon,
                                  color: active
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.secondary,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  wb.name.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: active
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.secondary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      )
                    : Row(
                        key: const ValueKey("MAIN"),
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _TopBtn(
                            icon: _flashMode == FlashMode.off
                                ? Icons.flash_off
                                : _flashMode == FlashMode.auto
                                ? Icons.flash_auto
                                : Icons.flash_on,
                            active: _flashMode != FlashMode.off,
                            onTap: _toggleFlash,
                          ),
                          _TopBtn(
                            icon: Icons.thermostat,
                            active: _wb != WhiteBalance.auto,
                            onTap: _toggleWBMenu,
                          ),
                          _TopBtn(
                            icon: Icons.hdr_on,
                            active: _hdrEnabled,
                            onTap: _toggleHDR,
                          ),
                        ],
                      ),
              ),
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            top: MediaQuery.of(context).padding.top - 80,
            height: 80,
            child: Container(color: barColor.withValues(alpha: 0.35)),
          ),

          // =================================================
          // BOTTOM BAR
          // =================================================
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: barColor.withValues(alpha: 0.35),
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    onPressed: _switchCamera,
                    icon: const Icon(Icons.cameraswitch),
                    iconSize: 36,
                  ),
                  GestureDetector(
                    onTap: _takePhoto,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: theme.colorScheme.outline,
                          width: 4,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.outline,
                            shape: BoxShape.circle,
                          ),
                          child: SizedBox(width: 54, height: 54),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 36),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================
// TOP BAR BUTTON
// =============================================================

class _TopBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  const _TopBtn({required this.icon, required this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton(
      splashRadius: 22,
      onPressed: onTap,
      icon: Icon(
        icon,
        color: active
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
