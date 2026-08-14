import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'ui/shell/app_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BonnieCadApp());
}

class BonnieCadApp extends StatelessWidget {
  const BonnieCadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BonnieCAD',
      debugShowCheckedModeBanner: false,
      // Trackpads / mice on Mac and Windows both drag-scroll panels.
      scrollBehavior: const _BonnieScrollBehavior(),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5D4037),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const AppShell(),
    );
  }
}

/// Enable drag-to-scroll with mouse and trackpad on all platforms.
class _BonnieScrollBehavior extends MaterialScrollBehavior {
  const _BonnieScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.unknown,
      };
}
