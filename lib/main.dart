import 'package:flutter/material.dart';
import 'package:namer_app/pages/camera.dart';
import 'package:namer_app/pages/home.dart';
import 'package:namer_app/pages/settings.dart';
import 'package:camera/camera.dart';
import 'controller/theme.dart';

late List<CameraDescription> cameras;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  cameras = await availableCameras();
  runApp(OCRApp());
}

class OCRApp extends StatefulWidget {
  @override
  State<OCRApp> createState() => _OCRAppState();
}

class _OCRAppState extends State<OCRApp> {
  late ThemeController themeController = ThemeController(setState: setState);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WayReader OCR',
      theme: themeController.getTheme(),
      home: NavigationPage(themeController),
    );
  }
}

class NavigationPage extends StatefulWidget {
  final ThemeController themeController;

  NavigationPage(this.themeController);

  @override
  State<NavigationPage> createState() => _NavigationPageState();
}

class _NavigationPageState extends State<NavigationPage> {
  int currentPageIndex = 1;
  PageController pageController = PageController(initialPage: 1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ---------- Page View ----------
      body: PageView(
        controller: pageController,
        children: [
          CameraPage(cameras),
          HomePage(),
          SettingsPage(themeController: widget.themeController),
        ],
      ),
      // ---------- Bottom Navigation Bar ----------
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentPageIndex,
        onDestinationSelected: (int pageIndex) {
          setState(() {
            currentPageIndex = pageIndex;
          });
          pageController.animateToPage(
            pageIndex,
            duration: Duration(milliseconds: 350),
            curve: Curves.easeInOut,
          );
        },
        destinations: [
          NavigationDestination(icon: Icon(Icons.camera_alt), label: 'Camera'),
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
