import 'package:flutter/material.dart';
import 'app_display_settings.dart';
import 'app_routes.dart';
import 'chat.dart';
import 'dashboard.dart';
import 'features/offline_map/offline_map_screen.dart';
import 'power.dart';
import 'sos.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDisplaySettings.syncFromPowerSettings();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppDisplaySettings.grayscaleEnabled,
      builder: (context, grayscaleOn, _) {
        return MaterialApp(
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
            if (settings.name == AppRoutes.chat) {
              final args = AppRoutes.chatArgsOf(settings.arguments);
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => ChatPage(initialArgs: args),
              );
            }
            return null;
          },
          routes: {
            AppRoutes.dashboard: (_) => const DashboardPage(),
            AppRoutes.power: (_) => const PowerPage(),
            AppRoutes.sos: (_) => const SosPage(),
            AppRoutes.offlineMap: (_) => const OfflineMapScreen(),
          },
        );
      },
    );
  }
}
