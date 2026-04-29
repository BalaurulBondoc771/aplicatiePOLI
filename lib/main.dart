import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'app_display_settings.dart';
import 'app_routes.dart';
import 'chat.dart';
import 'dashboard.dart';
import 'features/offline_map/offline_map_screen.dart';
import 'power.dart';
import 'services/app_settings_service.dart';
import 'settings.dart';
import 'sos.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await AppSettingsService.load();
  await AppSettingsService.syncToNative(settings);
  await AppDisplaySettings.syncFromPowerSettings();
  await _initializeOfflineMap();
  runApp(const MyApp());
}

Future<void> _initializeOfflineMap() async {
  try {
    final Directory docs = await getApplicationDocumentsDirectory();
    final Directory mapsDir = Directory('${docs.path}${Platform.pathSeparator}maps');
    if (!mapsDir.existsSync()) {
      mapsDir.createSync(recursive: true);
    }
    
    final File mapFile = File('${mapsDir.path}${Platform.pathSeparator}romania.mbtiles');
    if (!mapFile.existsSync()) {
      try {
        final ByteData data = await rootBundle.load('map-host/romania.mbtiles');
        await mapFile.writeAsBytes(data.buffer.asUint8List());
      } catch (_) {
        // Asset may not be available
      }
    }
  } catch (_) {
    // Silently fail if offline map initialization fails
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Route<void> _smoothRoute({
    required RouteSettings settings,
    required Widget child,
  }) {
    return PageRouteBuilder<void>(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final fade = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        final slide = Tween<Offset>(
          begin: const Offset(0.035, 0),
          end: Offset.zero,
        ).animate(fade);
        return FadeTransition(
          opacity: fade,
          child: SlideTransition(position: slide, child: child),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppDisplaySettings.grayscaleEnabled,
      builder: (context, grayscaleOn, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Blackout Dashboard',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
          ),
          builder: (context, child) {
            if (!grayscaleOn || child == null) {
              return child ?? const SizedBox.shrink();
            }
            return ColorFiltered(
              colorFilter: const ColorFilter.matrix(<double>[
                0.2126, 0.7152, 0.0722, 0, 0,
                0.2126, 0.7152, 0.0722, 0, 0,
                0.2126, 0.7152, 0.0722, 0, 0,
                0, 0, 0, 1, 0,
              ]),
              child: child,
            );
          },
          initialRoute: AppRoutes.dashboard,
          onGenerateRoute: (settings) {
            switch (settings.name) {
              case AppRoutes.dashboard:
                return _smoothRoute(
                  settings: settings,
                  child: const DashboardPage(),
                );
              case AppRoutes.chat:
                final args = AppRoutes.chatArgsOf(settings.arguments);
                return _smoothRoute(
                  settings: settings,
                  child: ChatPage(initialArgs: args),
                );
              case AppRoutes.power:
                return _smoothRoute(
                  settings: settings,
                  child: const PowerPage(),
                );
              case AppRoutes.sos:
                return _smoothRoute(
                  settings: settings,
                  child: const SosPage(),
                );
              case AppRoutes.settings:
                return _smoothRoute(
                  settings: settings,
                  child: const SettingsPage(),
                );
              case AppRoutes.offlineMap:
                return _smoothRoute(
                  settings: settings,
                  child: const OfflineMapScreen(),
                );
              default:
                return _smoothRoute(
                  settings: settings,
                  child: const DashboardPage(),
                );
            }
          },
        );
      },
    );
  }
}
